-- Restrict delivery-driver liability reads to the owner or authorized company supervisors.
-- Writes stay centralized in service_role-only posting and settlement functions.
REVOKE ALL ON TABLE public.driver_liabilities FROM PUBLIC;
REVOKE ALL ON TABLE public.driver_liabilities FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.driver_liabilities FROM authenticated;
GRANT SELECT ON TABLE public.driver_liabilities TO authenticated;

DROP POLICY IF EXISTS allow_read_driver_liabilities ON public.driver_liabilities;
DROP POLICY IF EXISTS driver_liabilities_select_company_authorized ON public.driver_liabilities;

CREATE POLICY driver_liabilities_select_company_authorized
ON public.driver_liabilities
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id = driver_liabilities.company_id
      AND COALESCE(u.status, 'Active') = 'Active'
      AND (
        u.id = driver_liabilities.driver_id
        OR u.role IN (
          'مدير عام',
          'مدير مالي',
          'مدير مخازن',
          'مشرف مخازن',
          'مشرف توصيل'
        )
        OR app_private.current_user_has_effective_permission('finance')
        OR app_private.current_user_has_effective_permission('finance_manager')
        OR app_private.current_user_has_effective_permission('delivery_supervisor')
        OR app_private.current_user_has_effective_permission('warehouse_manager')
        OR app_private.current_user_has_effective_permission('warehouse_supervisor')
        OR app_private.current_user_has_effective_permission('fleet.read')
        OR app_private.current_user_has_effective_permission('fleet.manage')
        OR app_private.current_user_has_effective_permission('reports')
      )
  )
);

