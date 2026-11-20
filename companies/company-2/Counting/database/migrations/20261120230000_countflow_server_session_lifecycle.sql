-- CountFlow: central, server-authoritative lifecycle transitions for count sessions.
-- Keep the existing review/approval flow, but prevent direct DML from bypassing it.

CREATE OR REPLACE FUNCTION counting_private.guard_session_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_latest public.count_reconciliation_runs;
  v_current_entries bigint;
  v_open_tasks bigint;
  v_critical_alerts bigint;
  v_uncovered_products bigint;
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.status<>'planned' OR NEW.started_at IS NOT NULL OR NEW.closed_at IS NOT NULL THEN
      RAISE EXCEPTION 'SESSION_MUST_BE_CREATED_AS_PLANNED';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    IF NEW.started_at IS DISTINCT FROM OLD.started_at
       OR NEW.closed_at IS DISTINCT FROM OLD.closed_at THEN
      RAISE EXCEPTION 'SESSION_LIFECYCLE_TIMESTAMPS_ARE_SERVER_MANAGED';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status='planned' AND NEW.status='active' THEN
    NEW.started_at:=coalesce(OLD.started_at,now());
    NEW.closed_at:=NULL;
    RETURN NEW;
  ELSIF OLD.status='active' AND NEW.status='paused' THEN
    NEW.started_at:=OLD.started_at;
    NEW.closed_at:=NULL;
    RETURN NEW;
  ELSIF OLD.status='paused' AND NEW.status='active' THEN
    NEW.started_at:=OLD.started_at;
    NEW.closed_at:=NULL;
    RETURN NEW;
  ELSIF OLD.status IN ('active','paused') AND NEW.status='review' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.count_reconciliation_runs r
      WHERE r.session_id=OLD.id
        AND r.status='approved'
        AND r.approved_at IS NOT NULL
        AND r.run_number=(SELECT max(x.run_number) FROM public.count_reconciliation_runs x WHERE x.session_id=OLD.id)
    ) THEN
      RAISE EXCEPTION 'SESSION_REVIEW_REQUIRES_LATEST_APPROVED_RECONCILIATION';
    END IF;
    NEW.started_at:=OLD.started_at;
    NEW.closed_at:=NULL;
    RETURN NEW;
  ELSIF OLD.status IN ('active','paused','review') AND NEW.status='completed' THEN
    SELECT * INTO v_latest
    FROM public.count_reconciliation_runs r
    WHERE r.session_id=OLD.id
    ORDER BY r.run_number DESC
    LIMIT 1;

    IF NOT FOUND OR v_latest.status<>'approved' OR v_latest.approved_at IS NULL THEN
      RAISE EXCEPTION 'SESSION_CLOSE_REQUIRES_LATEST_APPROVED_RECONCILIATION';
    END IF;

    SELECT count(*) INTO v_current_entries
    FROM public.count_entries e
    WHERE e.session_id=OLD.id;
    IF v_current_entries<>v_latest.entry_count_snapshot THEN
      RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_APPROVED_RECONCILIATION';
    END IF;
    IF v_latest.uncounted_rows>0 THEN
      RAISE EXCEPTION 'SESSION_HAS_UNCOUNTED_POSITIONS:%',v_latest.uncounted_rows;
    END IF;

    SELECT count(*) INTO v_open_tasks
    FROM public.count_recount_tasks t
    WHERE t.session_id=OLD.id AND t.status NOT IN ('reviewed','cancelled');
    IF v_open_tasks>0 THEN
      RAISE EXCEPTION 'SESSION_HAS_OPEN_RECOUNT_TASKS:%',v_open_tasks;
    END IF;

    SELECT count(*) INTO v_critical_alerts
    FROM public.count_alerts a
    WHERE a.session_id=OLD.id AND a.severity='critical' AND a.status IN ('open','acknowledged');
    IF v_critical_alerts>0 THEN
      RAISE EXCEPTION 'SESSION_HAS_UNRESOLVED_CRITICAL_ALERTS:%',v_critical_alerts;
    END IF;

    SELECT count(*) INTO v_uncovered_products
    FROM (
      SELECT DISTINCT r.product_id
      FROM public.count_import_rows r
      JOIN public.count_import_batches b ON b.id=r.batch_id
      WHERE b.session_id=OLD.id AND r.row_status='committed' AND r.product_id IS NOT NULL
    ) imported
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.count_reconciliation_lines l
      WHERE l.run_id=v_latest.id
        AND l.product_id=imported.product_id
        AND l.counted_quantity IS NOT NULL
    );
    IF v_uncovered_products>0 THEN
      RAISE EXCEPTION 'SESSION_HAS_IMPORTED_PRODUCTS_WITHOUT_ANY_COUNT:%',v_uncovered_products;
    END IF;

    NEW.started_at:=OLD.started_at;
    NEW.closed_at:=now();
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'INVALID_SESSION_STATUS_TRANSITION:%->%',OLD.status,NEW.status;
  END IF;
END;
$function$;

DROP TRIGGER IF EXISTS count_sessions_lifecycle_guard ON public.count_sessions;
CREATE TRIGGER count_sessions_lifecycle_guard
BEFORE INSERT OR UPDATE ON public.count_sessions
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_session_lifecycle();

CREATE OR REPLACE FUNCTION public.count_transition_session(
  p_session_id uuid,
  p_target_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
REVOKE ALL ON FUNCTION counting_private.guard_session_lifecycle() FROM PUBLIC, anon, authenticated;
