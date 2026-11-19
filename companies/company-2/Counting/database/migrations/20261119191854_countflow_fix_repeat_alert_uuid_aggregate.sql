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
   SELECT v_project,p_session_id,(array_agg(e.id ORDER BY e.counted_at DESC,e.id DESC))[1],r.id,r.rule_type,r.severity,'تكرار مسح الصنف في فترة قصيرة',
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
