-- Restore least-privilege read access needed by the assigned delivery driver's vehicle balance and item images.
-- This migration adds SELECT-only policies; it does not modify operational rows or write permissions.

CREATE POLICY run_sheet_details_select_assigned_delivery
ON public.run_sheet_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.runsheets r
    JOIN public.users u
      ON u.id = r.deliverer_id
     AND u.company_id = r.company_id
    WHERE r.id = run_sheet_details.runsheet_id
      AND r.company_id = app_private.current_user_company_id()
      AND app_private.current_user_has_permission('delivery'::text)
      AND u.auth_id = auth.uid()
      AND COALESCE(u.status, 'Active') = 'Active'
      AND u.role = 'مندوب توصيل'
  )
);

CREATE POLICY items_select_assigned_delivery
ON public.items
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND app_private.current_user_has_permission('delivery'::text)
  AND (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_details rsd
      JOIN public.runsheets r
        ON r.id = rsd.runsheet_id
      JOIN public.users u
        ON u.id = r.deliverer_id
       AND u.company_id = r.company_id
      WHERE rsd.item_code = items.item_code
        AND r.company_id = items.company_id
        AND r.company_id = app_private.current_user_company_id()
        AND u.auth_id = auth.uid()
        AND COALESCE(u.status, 'Active') = 'Active'
        AND u.role = 'مندوب توصيل'
    )
    OR EXISTS (
      SELECT 1
      FROM public.order_details od
      JOIN public.orders o
        ON o.id = od.order_id
       AND o.company_id = items.company_id
      JOIN public.runsheets r
        ON r.id = o.runsheet_id
       AND r.company_id = o.company_id
      JOIN public.users u
        ON u.id = r.deliverer_id
       AND u.company_id = r.company_id
      WHERE od.item_code = items.item_code
        AND r.company_id = app_private.current_user_company_id()
        AND app_private.current_user_has_permission('delivery'::text)
        AND u.auth_id = auth.uid()
        AND COALESCE(u.status, 'Active') = 'Active'
        AND u.role = 'مندوب توصيل'
    )
  )
);

COMMENT ON POLICY run_sheet_details_select_assigned_delivery ON public.run_sheet_details
IS 'Allows an active authenticated delivery user to read run-sheet item quantities only for a run sheet assigned to that user in the same company.';

COMMENT ON POLICY items_select_assigned_delivery ON public.items
IS 'Allows an active authenticated delivery user to read item rows (including image_url and description) only for items on their assigned run sheets/orders in the same company.';
