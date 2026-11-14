-- RAWAEA ERP: extend the same scoped display lookup to loaders.
-- Preserve picker and return-handler attribution; no business data is written.
CREATE OR REPLACE FUNCTION public.get_picking_display_users(p_picker_ids uuid[])
RETURNS TABLE(id uuid, name text, email text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_company_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  v_company_id := app_private.current_user_company_id();
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'company context is not available';
  END IF;

  IF NOT (
    app_private.current_user_has_permission('warehouse')
    OR app_private.current_user_has_permission('runsheets')
  ) THEN
    RAISE EXCEPTION 'not authorized to read picking metadata';
  END IF;

  IF COALESCE(cardinality(p_picker_ids), 0) > 500 THEN
    RAISE EXCEPTION 'too many picker IDs';
  END IF;

  RETURN QUERY
  SELECT u.id,
         COALESCE(NULLIF(btrim(u.name), ''), u.email)::text AS name,
         u.email::text AS email
  FROM public.users AS u
  WHERE u.company_id = v_company_id
    AND u.id = ANY(COALESCE(p_picker_ids, ARRAY[]::uuid[]))
    AND EXISTS (
      SELECT 1
      FROM public.runsheets AS rs
      WHERE rs.company_id = v_company_id
        AND (
          rs.picker_id = u.id
          OR rs.loader_id = u.id
          OR rs.return_handler_id = u.id
        )
    )
  ORDER BY u.id;
END;
$function$;
