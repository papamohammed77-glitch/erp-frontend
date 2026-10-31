ALTER TABLE public.audit_log
  DROP CONSTRAINT audit_log_action_check;
ALTER TABLE public.audit_log
  ADD CONSTRAINT audit_log_action_check
  CHECK (action = ANY (ARRAY[
    'create'::text,
    'update'::text,
    'delete'::text,
    'login'::text,
    'logout'::text,
    'failed_login'::text,
    'receive'::text
  ]));
