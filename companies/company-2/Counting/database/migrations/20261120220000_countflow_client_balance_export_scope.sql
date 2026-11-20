-- CountFlow only: distinguish the client-facing stock balance from internal operational exports.
ALTER TABLE public.count_exports
  DROP CONSTRAINT count_exports_export_scope_check;

ALTER TABLE public.count_exports
  ADD CONSTRAINT count_exports_export_scope_check
  CHECK (export_scope = ANY (ARRAY['full'::text,'summary'::text,'variance'::text,'client_balance'::text]));