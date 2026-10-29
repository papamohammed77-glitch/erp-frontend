-- Allow an authenticated delivery user to read only runsheets assigned to that exact application user.
-- This is a SELECT-only policy. It does not grant writes or broaden access to other drivers/company data.
DROP POLICY IF EXISTS runsheets_select_assigned_delivery ON public.runsheets;

CREATE POLICY runsheets_select_assigned_delivery
ON public.runsheets
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND app_private.current_user_has_permission('delivery')
  AND deliverer_id = (
    SELECT u.id
    FROM public.users AS u
    WHERE u.auth_id = auth.uid()
      AND u.company_id = app_private.current_user_company_id()
      AND coalesce(u.status, 'Active') = 'Active'
      AND u.role = 'مندوب توصيل'
    LIMIT 1
  )
);
