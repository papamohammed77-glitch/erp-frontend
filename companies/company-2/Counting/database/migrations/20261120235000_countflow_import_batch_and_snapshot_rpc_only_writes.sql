-- CountFlow: route import batch creation and baseline/cost writes through validated RPCs only.
-- Existing import screens only update mapping_id and metadata on the batch header.

CREATE OR REPLACE FUNCTION counting_private.count_create_import_batch_impl(p_project_id uuid, p_session_id uuid, p_source_name text, p_source_format text DEFAULT 'csv'::text, p_source_checksum text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid;
BEGIN
 IF NOT counting_private.is_supervisor(p_project_id) THEN
  RAISE EXCEPTION 'SUPERVISOR_REQUIRED';
 END IF;
 IF nullif(btrim(p_source_name),'') IS NULL OR p_source_format NOT IN ('csv','xlsx','json') THEN
  RAISE EXCEPTION 'INVALID_IMPORT_METADATA';
 END IF;
 IF p_session_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.count_sessions s
  WHERE s.id=p_session_id AND s.project_id=p_project_id
    AND s.status IN ('planned','active','paused','review')
 ) THEN
  RAISE EXCEPTION 'INVALID_IMPORT_SESSION';
 END IF;
 INSERT INTO public.count_import_batches(
  project_id,imported_by,source_name,row_count,accepted_count,rejected_count,
  status,error_report,session_id,source_format,source_checksum
 ) VALUES(
  p_project_id,(SELECT auth.uid()),btrim(p_source_name),0,0,0,
  'uploading','{}'::jsonb,p_session_id,p_source_format,p_source_checksum
 ) RETURNING id INTO v_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(p_project_id,(SELECT auth.uid()),'import.created','import_batch',v_id,
  jsonb_build_object('source_name',p_source_name,'source_format',p_source_format,'session_id',p_session_id));
 RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION counting_private.count_create_import_batch_impl(uuid,uuid,text,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION counting_private.count_create_import_batch_impl(uuid,uuid,text,text,text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.count_create_import_batch(
  p_project_id uuid,
  p_session_id uuid,
  p_source_name text,
  p_source_format text DEFAULT 'csv',
  p_source_checksum text DEFAULT NULL
)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT counting_private.count_create_import_batch_impl(
    p_project_id,p_session_id,p_source_name,p_source_format,p_source_checksum
  );
$function$;

REVOKE ALL ON FUNCTION public.count_create_import_batch(uuid,uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_create_import_batch(uuid,uuid,text,text,text) TO authenticated;

-- Keep the batch header readable; allow only mapping metadata changes from the UI.
REVOKE INSERT, UPDATE, DELETE ON public.count_import_batches FROM authenticated;
GRANT UPDATE(mapping_id,metadata) ON public.count_import_batches TO authenticated;

-- Product/location baselines and operation cost snapshots are written only by validated import commit.
REVOKE INSERT, UPDATE, DELETE ON public.count_expected_balances FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.count_session_product_costs FROM authenticated;

