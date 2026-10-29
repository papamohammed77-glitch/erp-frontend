-- Permit authenticated delivery users to read only orders assigned through their own runsheet.
-- No INSERT/UPDATE/DELETE privileges are added; existing policies remain unchanged.
CREATE POLICY orders_select_assigned_delivery
ON public.orders
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND app_private.current_user_has_permission('delivery')
  AND EXISTS (
    SELECT 1
    FROM public.runsheets r
    JOIN public.users u
      ON u.id = r.deliverer_id
     AND u.company_id = r.company_id
    WHERE r.id = orders.runsheet_id
      AND r.company_id = orders.company_id
      AND u.auth_id = auth.uid()
      AND u.status IS DISTINCT FROM 'Inactive'
      AND u.role = 'مندوب توصيل'
  )
);

-- Order lines are readable only when their parent order belongs to a runsheet
-- currently assigned to this same active delivery user in the same company.
CREATE POLICY order_details_select_assigned_delivery
ON public.order_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.runsheets r
      ON r.id = o.runsheet_id
     AND r.company_id = o.company_id
    JOIN public.users u
      ON u.id = r.deliverer_id
     AND u.company_id = r.company_id
    WHERE o.id = order_details.order_id
      AND o.company_id = app_private.current_user_company_id()
      AND app_private.current_user_has_permission('delivery')
      AND u.auth_id = auth.uid()
      AND u.status IS DISTINCT FROM 'Inactive'
      AND u.role = 'مندوب توصيل'
  )
);

COMMENT ON POLICY orders_select_assigned_delivery ON public.orders IS
'SELECT-only access for an active delivery user to orders on runsheets assigned to that same user in the same company.';
COMMENT ON POLICY order_details_select_assigned_delivery ON public.order_details IS
'SELECT-only access for an active delivery user to order lines whose parent order belongs to a runsheet assigned to that same user in the same company.';
