CREATE INDEX IF NOT EXISTS count_entries_repeat_scan_idx
  ON public.count_entries(session_id,member_id,product_id,location_id,counted_at DESC);
CREATE INDEX IF NOT EXISTS count_alerts_open_entry_rule_idx
  ON public.count_alerts(session_id,rule_id,entry_id)
  WHERE status IN ('open','acknowledged');
CREATE INDEX IF NOT EXISTS count_alerts_open_rule_member_product_idx
  ON public.count_alerts(session_id,rule_id,(details->>'member_id'),(details->>'product_id'))
  WHERE status IN ('open','acknowledged');

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  WITH effective AS MATERIALIZED (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  effective_metrics AS (
    SELECT count(*)::bigint counted_positions,count(DISTINCT product_id)::bigint counted_products,
      count(DISTINCT location_id) FILTER (WHERE location_id IS NOT NULL)::bigint counted_locations,
      coalesce(sum(counted_qty),0)::numeric quantity_total FROM effective
  ),
  unit_totals AS (SELECT unit,sum(counted_qty)::numeric total_qty FROM effective GROUP BY unit),
  unit_metrics AS (SELECT coalesce(jsonb_object_agg(unit,total_qty),'{}'::jsonb) quantity_by_unit FROM unit_totals)
  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
    'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
    'counted_positions',em.counted_positions,'counted_products',em.counted_products,'counted_locations',em.counted_locations,
    'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    'quantity_total',em.quantity_total,'quantity_by_unit',um.quantity_by_unit,
    'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
    'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
    'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
    'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
    'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
    'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
  ) INTO v_result FROM effective_metrics em CROSS JOIN unit_metrics um;
  RETURN v_result;
END;
$function$;
