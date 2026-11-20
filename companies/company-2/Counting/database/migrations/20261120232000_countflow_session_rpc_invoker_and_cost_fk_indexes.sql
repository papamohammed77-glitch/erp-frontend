-- CountFlow: transition RPC operates with caller privileges and supervisor RLS.
-- Lifecycle integrity remains enforced by the security-definer trigger function in counting_private.
CREATE OR REPLACE FUNCTION public.count_transition_session(p_session_id uuid, p_target_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
BEGIN
  IF p_target_status NOT IN ('active','paused','completed') THEN
    RAISE EXCEPTION 'UNSUPPORTED_SESSION_TARGET_STATUS';
  END IF;

  SELECT * INTO v_session
  FROM public.count_sessions
  WHERE id=p_session_id
  FOR UPDATE;

  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  IF v_session.status=p_target_status THEN
    RETURN jsonb_build_object(
      'session_id',v_session.id,
      'status',v_session.status,
      'idempotent',true,
      'started_at',v_session.started_at,
      'closed_at',v_session.closed_at
    );
  END IF;

  UPDATE public.count_sessions
  SET status=p_target_status
  WHERE id=p_session_id
  RETURNING * INTO v_session;

  RETURN jsonb_build_object(
    'session_id',v_session.id,
    'status',v_session.status,
    'started_at',v_session.started_at,
    'closed_at',v_session.closed_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.count_transition_session(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_transition_session(uuid,text) TO authenticated;

-- Cover all newly introduced foreign keys for the operation-scoped cost snapshot.
CREATE INDEX IF NOT EXISTS count_session_product_costs_product_project_idx
  ON public.count_session_product_costs(product_id,project_id);
CREATE INDEX IF NOT EXISTS count_session_product_costs_session_project_idx
  ON public.count_session_product_costs(session_id,project_id);
CREATE INDEX IF NOT EXISTS count_session_product_costs_source_batch_idx
  ON public.count_session_product_costs(source_batch_id)
  WHERE source_batch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS count_session_product_costs_created_by_idx
  ON public.count_session_product_costs(created_by)
  WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS count_session_product_costs_updated_by_idx
  ON public.count_session_product_costs(updated_by)
  WHERE updated_by IS NOT NULL;
