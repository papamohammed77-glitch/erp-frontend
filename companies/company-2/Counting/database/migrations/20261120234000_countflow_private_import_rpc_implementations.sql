-- CountFlow: keep public RPCs SECURITY INVOKER and move privileged import internals
-- into the non-PostgREST counting_private schema. The private implementations still
-- validate the supervisor and validate every row again at commit time.

ALTER FUNCTION public.count_stage_import_rows(uuid,jsonb,integer)
  SET SCHEMA counting_private;
ALTER FUNCTION counting_private.count_stage_import_rows(uuid,jsonb,integer)
  RENAME TO count_stage_import_rows_impl;

ALTER FUNCTION public.count_commit_import_batch(uuid)
  SET SCHEMA counting_private;
ALTER FUNCTION counting_private.count_commit_import_batch(uuid)
  RENAME TO count_commit_import_batch_impl;

REVOKE ALL ON SCHEMA counting_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA counting_private TO authenticated;

REVOKE ALL ON FUNCTION counting_private.count_stage_import_rows_impl(uuid,jsonb,integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION counting_private.count_stage_import_rows_impl(uuid,jsonb,integer)
  TO authenticated;

REVOKE ALL ON FUNCTION counting_private.count_commit_import_batch_impl(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION counting_private.count_commit_import_batch_impl(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.count_stage_import_rows(
  p_batch_id uuid,
  p_rows jsonb,
  p_row_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT counting_private.count_stage_import_rows_impl(p_batch_id,p_rows,p_row_offset);
$function$;

CREATE OR REPLACE FUNCTION public.count_commit_import_batch(p_batch_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT counting_private.count_commit_import_batch_impl(p_batch_id);
$function$;

REVOKE ALL ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) TO authenticated;

REVOKE ALL ON FUNCTION public.count_commit_import_batch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_commit_import_batch(uuid) TO authenticated;

COMMENT ON FUNCTION counting_private.count_stage_import_rows_impl(uuid,jsonb,integer)
  IS 'Private validated CountFlow import staging implementation. Called by public SECURITY INVOKER RPC.';
COMMENT ON FUNCTION counting_private.count_commit_import_batch_impl(uuid)
  IS 'Private validated CountFlow import commit implementation. Called by public SECURITY INVOKER RPC.';
