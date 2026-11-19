-- Consolidated finality/approval contract for CountFlow.
-- This is the final state reached by the incremental migrations
-- 20261119192305..20261119192509 in the live project.

ALTER TABLE public.count_reconciliation_runs
  ADD COLUMN IF NOT EXISTS entry_count_snapshot bigint NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_factor numeric; v_session_status text;
BEGIN
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=NEW.session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs r WHERE r.session_id=NEW.session_id AND r.status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  IF v_session_status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.set_count_entry_unit_factor() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=p_session_id AND status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;
  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
    FROM public.count_expected_balances WHERE session_id=p_session_id GROUP BY product_id,location_id
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at)
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_qty IS NULL THEN 'not_expected' WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched' WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,now()
  FROM enriched e;
  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    entry_count_snapshot=(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    computed_at=now() WHERE r.id=v_run_id;
  PERFORM public.count_evaluate_session_alerts(p_session_id);
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,
      'unit_normalization','base_quantity_snapshot','alerts_evaluated',true,
      'entry_count_snapshot',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id)));
  RETURN v_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_session_status text;
  v_open_tasks integer;
  v_critical_alerts integer;
  v_later_runs integer;
  v_current_entry_count bigint;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=v_run.session_id FOR UPDATE;
  IF NOT FOUND OR v_session_status NOT IN ('active','paused','review') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_APPROVAL'; END IF;
  SELECT count(*) INTO v_later_runs FROM public.count_reconciliation_runs WHERE session_id=v_run.session_id AND run_number>v_run.run_number;
  IF v_later_runs>0 THEN RAISE EXCEPTION 'RECONCILIATION_NOT_LATEST'; END IF;
  SELECT count(*) INTO v_current_entry_count FROM public.count_entries WHERE session_id=v_run.session_id;
  IF v_current_entry_count<>v_run.entry_count_snapshot THEN RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%',v_current_entry_count-v_run.entry_count_snapshot; END IF;
  IF v_run.uncounted_rows>0 THEN RAISE EXCEPTION 'UNCOUNTED_POSITIONS_REMAINING:%',v_run.uncounted_rows; END IF;
  SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
  SELECT count(*) INTO v_critical_alerts FROM public.count_alerts WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
  IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
  IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;
  UPDATE public.count_reconciliation_runs SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now() WHERE id=p_run_id;
  UPDATE public.count_sessions SET status='review' WHERE id=v_run.session_id AND status IN ('active','paused');
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
    jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number,'session_frozen',true,'entry_count_snapshot',v_run.entry_count_snapshot));
  RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now(),'session_status','review');
END;
$function$;
