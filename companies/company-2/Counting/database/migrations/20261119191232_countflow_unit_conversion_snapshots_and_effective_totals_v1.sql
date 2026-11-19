ALTER TABLE public.count_entries
  ADD COLUMN unit_factor_to_base numeric(18,8) NOT NULL DEFAULT 1
    CHECK (unit_factor_to_base > 0 AND unit_factor_to_base <= 1000000000),
  ADD COLUMN base_quantity numeric(24,8)
    GENERATED ALWAYS AS (quantity * unit_factor_to_base) STORED;

CREATE OR REPLACE FUNCTION counting_private.unit_factor_to_base(p_product_id uuid,p_unit text)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_base_unit text; v_units jsonb; v_factor_text text; v_factor numeric;
BEGIN
  SELECT base_unit,units INTO v_base_unit,v_units FROM public.count_products WHERE id=p_product_id;
  IF NOT FOUND OR nullif(btrim(p_unit),'') IS NULL THEN RETURN NULL; END IF;
  IF p_unit=v_base_unit THEN RETURN 1; END IF;
  SELECT coalesce(u.value->>'factor_to_base',u.value->>'conversion_factor',u.value->>'factor')
  INTO v_factor_text
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_units)='array' THEN v_units ELSE '[]'::jsonb END) AS u(value)
  WHERE coalesce(u.value->>'name',u.value#>>'{}')=p_unit LIMIT 1;
  IF v_factor_text IS NULL OR v_factor_text !~ '^[0-9]+([.][0-9]{1,8})?$' THEN RETURN NULL; END IF;
  v_factor:=v_factor_text::numeric;
  IF v_factor<=0 OR v_factor>1000000000 THEN RETURN NULL; END IF;
  RETURN v_factor;
END;
$function$;

REVOKE ALL ON FUNCTION counting_private.unit_factor_to_base(uuid,text) FROM PUBLIC,anon;
GRANT USAGE ON SCHEMA counting_private TO authenticated;
GRANT EXECUTE ON FUNCTION counting_private.unit_factor_to_base(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
DECLARE v_factor numeric;
BEGIN
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS count_entries_unit_conversion_guard ON public.count_entries;
CREATE TRIGGER count_entries_unit_conversion_guard BEFORE INSERT ON public.count_entries
FOR EACH ROW EXECUTE FUNCTION counting_private.set_count_entry_unit_factor();

CREATE OR REPLACE FUNCTION counting_private.guard_product_unit_change_during_count()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
BEGIN
  IF (OLD.base_unit IS DISTINCT FROM NEW.base_unit OR OLD.units IS DISTINCT FROM NEW.units)
     AND EXISTS (
       SELECT 1 FROM public.count_entries e
       JOIN public.count_sessions s ON s.id=e.session_id
       WHERE e.product_id=OLD.id AND s.status IN ('active','paused','review')
     ) THEN
    RAISE EXCEPTION 'PRODUCT_UNITS_LOCKED_DURING_ACTIVE_COUNT';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS count_products_unit_change_guard ON public.count_products;
CREATE TRIGGER count_products_unit_change_guard BEFORE UPDATE OF base_unit,units ON public.count_products
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_product_unit_change_during_count();

CREATE OR REPLACE FUNCTION counting_private.session_effective_counts(p_session_id uuid)
RETURNS TABLE(product_id uuid,location_id uuid,counted_qty numeric,unit text,events bigint,counters integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $function$
  WITH base AS (
    SELECT e.product_id,e.location_id,sum(e.base_quantity)::numeric AS counted_qty,max(p.base_unit) AS unit
    FROM public.count_entries e JOIN public.count_products p ON p.id=e.product_id
    WHERE e.session_id=p_session_id AND e.recount_task_id IS NULL
    GROUP BY e.product_id,e.location_id
  ),
  latest_reviewed_recount AS (
    SELECT DISTINCT ON (t.product_id,t.location_id)
      t.product_id,t.location_id,re.base_quantity AS counted_qty,p.base_unit AS unit
    FROM public.count_recount_tasks t
    JOIN public.count_products p ON p.id=t.product_id
    JOIN LATERAL (
      SELECT e.base_quantity FROM public.count_entries e
      WHERE e.recount_task_id=t.id ORDER BY e.counted_at DESC,e.id DESC LIMIT 1
    ) re ON true
    WHERE t.session_id=p_session_id AND t.status='reviewed' AND t.second_count_quantity IS NOT NULL
    ORDER BY t.product_id,t.location_id,t.reviewed_at DESC NULLS LAST,t.created_at DESC,t.id DESC
  ),
  metrics AS (
    SELECT e.product_id,e.location_id,count(*)::bigint AS events,count(DISTINCT e.member_id)::integer AS counters
    FROM public.count_entries e WHERE e.session_id=p_session_id GROUP BY e.product_id,e.location_id
  )
  SELECT coalesce(b.product_id,r.product_id),coalesce(b.location_id,r.location_id),
    coalesce(r.counted_qty,b.counted_qty),coalesce(r.unit,b.unit,'وحدة'),
    coalesce(m.events,0),coalesce(m.counters,0)
  FROM base b
  FULL OUTER JOIN latest_reviewed_recount r
    ON r.product_id=b.product_id AND r.location_id IS NOT DISTINCT FROM b.location_id
  LEFT JOIN metrics m
    ON m.product_id=coalesce(b.product_id,r.product_id)
   AND m.location_id IS NOT DISTINCT FROM coalesce(b.location_id,r.location_id);
$function$;

REVOKE ALL ON FUNCTION counting_private.session_effective_counts(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION counting_private.session_effective_counts(uuid) TO authenticated;

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
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,
      coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c
      ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id
    LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(
    project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at
  )
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,
    e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_qty IS NULL THEN 'not_expected' WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched' WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,
    now()
  FROM enriched e;
  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    computed_at=now() WHERE r.id=v_run_id;
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,'unit_normalization','base_quantity_snapshot'));
  RETURN v_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
    'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
    'counted_positions',(SELECT count(*) FROM counting_private.session_effective_counts(p_session_id)),
    'counted_products',(SELECT count(DISTINCT product_id) FROM counting_private.session_effective_counts(p_session_id)),
    'counted_locations',(SELECT count(DISTINCT location_id) FROM counting_private.session_effective_counts(p_session_id) WHERE location_id IS NOT NULL),
    'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    'quantity_total',(SELECT coalesce(sum(counted_qty),0) FROM counting_private.session_effective_counts(p_session_id)),
    'quantity_by_unit',(SELECT coalesce(jsonb_object_agg(unit,total_qty),'{}'::jsonb) FROM
      (SELECT unit,sum(counted_qty) total_qty FROM counting_private.session_effective_counts(p_session_id) GROUP BY unit) q),
    'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
    'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
    'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
    'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
    'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
    'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;
