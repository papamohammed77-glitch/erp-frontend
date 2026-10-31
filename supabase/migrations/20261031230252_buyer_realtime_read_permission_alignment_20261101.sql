CREATE OR REPLACE FUNCTION app_private.current_user_has_effective_permission(p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT auth.uid() IS NOT NULL
     AND NULLIF(btrim(p_permission), '') IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM (SELECT public.get_my_effective_profile() AS profile) effective
       WHERE COALESCE(effective.profile->'permissions', '[]'::jsonb) ? '*'
          OR COALESCE(effective.profile->'permissions', '[]'::jsonb) ? p_permission
     );
$function$;

REVOKE ALL ON FUNCTION app_private.current_user_has_effective_permission(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.current_user_has_effective_permission(text) FROM anon;
GRANT EXECUTE ON FUNCTION app_private.current_user_has_effective_permission(text) TO authenticated, service_role;

DROP POLICY IF EXISTS suppliers_select_company ON public.suppliers;
CREATE POLICY suppliers_select_company ON public.suppliers FOR SELECT TO authenticated
USING (company_id = app_private.current_user_company_id()
AND (app_private.current_user_has_effective_permission('suppliers')
OR app_private.current_user_has_effective_permission('purchases')
OR EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id=auth.uid()
AND u.company_id=public.suppliers.company_id AND COALESCE(u.status,'Active')='Active'
AND COALESCE(u.active_warehouse_role,'')='أذونات')));

DROP POLICY IF EXISTS items_select_company ON public.items;
CREATE POLICY items_select_company ON public.items FOR SELECT TO authenticated
USING (company_id=app_private.current_user_company_id()
AND (app_private.current_user_has_effective_permission('items')
OR app_private.current_user_has_effective_permission('warehouse')
OR app_private.current_user_has_effective_permission('data-entry')
OR app_private.current_user_has_effective_permission('purchases')));

DROP POLICY IF EXISTS branches_select_company ON public.branches;
CREATE POLICY branches_select_company ON public.branches FOR SELECT TO authenticated
USING (company_id=app_private.current_user_company_id()
AND (app_private.current_user_has_effective_permission('branches')
OR app_private.current_user_has_effective_permission('warehouse')
OR app_private.current_user_has_effective_permission('purchases')));

DROP POLICY IF EXISTS stock_branches_select_company ON public.stock_branches;
CREATE POLICY stock_branches_select_company ON public.stock_branches FOR SELECT TO authenticated
USING ((app_private.current_user_has_effective_permission('warehouse')
OR app_private.current_user_has_effective_permission('runsheets')
OR app_private.current_user_has_effective_permission('reports')
OR app_private.current_user_has_effective_permission('purchases'))
AND EXISTS (SELECT 1 FROM public.branches b WHERE b.id=public.stock_branches.branch_id
AND b.company_id=app_private.current_user_company_id()));
