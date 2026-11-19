DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
           p.prorettype = 'trigger'::regtype AS is_trigger,
           p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (left(p.proname,6) = 'count_' OR p.proname = 'countflow_broadcast_changes')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.oid::regprocedure);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', r.oid::regprocedure);
    IF NOT r.is_trigger AND NOT r.prosecdef THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.oid::regprocedure);
    END IF;
  END LOOP;
END $$;

REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_audit_log FROM authenticated, anon;
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_reconciliation_lines FROM authenticated, anon;
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_entries FROM authenticated, anon;
