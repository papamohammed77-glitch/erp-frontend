CREATE OR REPLACE FUNCTION public.count_evaluate_session_alerts(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO ''
AS $function$
DECLARE v_project uuid; r public.count_anomaly_rules; v_inserted integer:=0; v_n integer:=0; v_run uuid;
BEGIN
 SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
 IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
 FOR r IN SELECT * FROM public.count_anomaly_rules WHERE project_id=v_project AND is_active ORDER BY created_at LOOP
  IF r.rule_type='quantity_above' THEN
   INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
   SELECT v_project,p_session_id,e.id,r.id,r.rule_type,r.severity,'كمية عد غير معتادة',
    jsonb_build_object('quantity',e.quantity,'quantity_base',e.base_quantity,'unit',e.unit,'threshold_base',r.threshold,'product_id',e.product_id,'member_id',e.member_id)
   FROM public.count_entries e WHERE e.session_id=p_session_id AND e.base_quantity>r.threshold
    AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id AND a.rule_id=r.id AND a.entry_id=e.id AND a.status IN ('open','acknowledged'));
   GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;
  ELSIF r.rule_type='repeat_scan_window' THEN
   INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
   SELECT v_project,p_session_id,max(e.id),r.id,r.rule_type,r.severity,'تكرار مسح الصنف في فترة قصيرة',
    jsonb_build_object('member_id',e.member_id,'product_id',e.product_id,'location_id',e.location_id,'event_count',count(*),'threshold',r.threshold,'window_minutes',coalesce(nullif(r.config->>'window_minutes','')::integer,5))
   FROM public.count_entries e WHERE e.session_id=p_session_id AND e.counted_at>=now()-make_interval(mins=>coalesce(nullif(r.config->>'window_minutes','')::integer,5))
   GROUP BY e.member_id,e.product_id,e.location_id
   HAVING count(*)>r.threshold AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id AND a.rule_id=r.id
    AND a.details->>'member_id'=e.member_id::text AND a.details->>'product_id'=e.product_id::text AND a.status IN ('open','acknowledged'));
   GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;
  ELSIF r.rule_type='variance_percent_above' THEN
   SELECT id INTO v_run FROM public.count_reconciliation_runs WHERE session_id=p_session_id AND status IN ('computed','approved') ORDER BY run_number DESC LIMIT 1;
   IF v_run IS NOT NULL THEN
    INSERT INTO public.count_alerts(project_id,session_id,rule_id,alert_type,severity,title,details)
    SELECT v_project,p_session_id,r.id,r.rule_type,r.severity,'فرق جرد يتجاوز حد التنبيه',
     jsonb_build_object('line_id',l.id,'product_id',l.product_id,'location_id',l.location_id,'variance_percent',l.variance_percent,'threshold',r.threshold,'run_id',v_run)
    FROM public.count_reconciliation_lines l WHERE l.run_id=v_run AND l.variance_percent IS NOT NULL AND abs(l.variance_percent)>r.threshold
     AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id AND a.rule_id=r.id AND a.details->>'line_id'=l.id::text AND a.status IN ('open','acknowledged'));
    GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;
   END IF;
  END IF;
 END LOOP;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_project,(SELECT auth.uid()),'alerts.evaluated','session',p_session_id,jsonb_build_object('created',v_inserted));
 RETURN jsonb_build_object('session_id',p_session_id,'created_alerts',v_inserted);
END;
$function$;

CREATE OR REPLACE FUNCTION counting_private.emit_count_entry_alerts()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE r public.count_anomaly_rules; v_count integer; v_window integer;
BEGIN
 FOR r IN SELECT * FROM public.count_anomaly_rules WHERE project_id=NEW.project_id AND is_active AND rule_type IN ('quantity_above','repeat_scan_window') ORDER BY created_at LOOP
  IF r.rule_type='quantity_above' AND NEW.base_quantity>r.threshold THEN
   INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
   SELECT NEW.project_id,NEW.session_id,NEW.id,r.id,r.rule_type,r.severity,'كمية عد غير معتادة',
    jsonb_build_object('quantity',NEW.quantity,'quantity_base',NEW.base_quantity,'unit',NEW.unit,'threshold_base',r.threshold,'product_id',NEW.product_id,'member_id',NEW.member_id)
   WHERE NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=NEW.session_id AND a.rule_id=r.id AND a.entry_id=NEW.id AND a.status IN ('open','acknowledged'));
  ELSIF r.rule_type='repeat_scan_window' THEN
   v_window:=greatest(1,least(120,coalesce(nullif(r.config->>'window_minutes','')::integer,5)));
   SELECT count(*) INTO v_count FROM public.count_entries e WHERE e.session_id=NEW.session_id AND e.member_id=NEW.member_id AND e.product_id=NEW.product_id
    AND e.location_id IS NOT DISTINCT FROM NEW.location_id AND e.counted_at>=now()-make_interval(mins=>v_window);
   IF v_count>r.threshold AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=NEW.session_id AND a.rule_id=r.id
    AND a.details->>'member_id'=NEW.member_id::text AND a.details->>'product_id'=NEW.product_id::text AND a.status IN ('open','acknowledged')) THEN
    INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
    VALUES(NEW.project_id,NEW.session_id,NEW.id,r.id,r.rule_type,r.severity,'تكرار مسح الصنف في فترة قصيرة',
     jsonb_build_object('member_id',NEW.member_id,'product_id',NEW.product_id,'location_id',NEW.location_id,'event_count',v_count,'threshold',r.threshold,'window_minutes',v_window));
   END IF;
  END IF;
 END LOOP;
 RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.emit_count_entry_alerts() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS count_entries_auto_anomaly_alerts ON public.count_entries;
CREATE TRIGGER count_entries_auto_anomaly_alerts AFTER INSERT ON public.count_entries
FOR EACH ROW EXECUTE FUNCTION counting_private.emit_count_entry_alerts();

-- Updated reconciliation uses counting_private.session_effective_counts and evaluates variance rules after run computation.
-- Full definition is preserved in the next migration file, where this function is redefined together with the alert fix.

-- Reconciliation also evaluates variance alerts before returning to the supervisor.
CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
 SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
 IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
 SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
 INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
 VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;
 WITH expected AS (
  SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
  FROM public.count_expected_balances WHERE session_id=p_session_id GROUP BY product_id,location_id
 ), counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
 merged AS (
  SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
   e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,coalesce(c.events,0) events,coalesce(c.counters,0) counters
  FROM expected e FULL OUTER JOIN counted c ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
 ), enriched AS (
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
  total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),computed_at=now()
 WHERE r.id=v_run_id;
 PERFORM public.count_evaluate_session_alerts(p_session_id);
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
  jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,
   'unit_normalization','base_quantity_snapshot','alerts_evaluated',true));
 RETURN v_run_id;
END;
$function$;
