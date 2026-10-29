-- Allow an authenticated delivery user to read only customers on that user's assigned runsheets.
-- This is a SELECT-only contract required for driver map coordinates/address; it grants no customer writes.
CREATE POLICY customers_select_assigned_delivery
ON public.customers
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND app_private.current_user_has_permission('delivery'::text)
  AND EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.runsheets r
      ON r.id = o.runsheet_id
     AND r.company_id = o.company_id
    JOIN public.users u
      ON u.id = r.deliverer_id
     AND u.company_id = r.company_id
    WHERE o.company_id = customers.company_id
      AND o.customer_id = customers.id
      AND u.auth_id = auth.uid()
      AND coalesce(u.status, 'Active') = 'Active'
      AND u.role = 'مندوب توصيل'
  )
);
