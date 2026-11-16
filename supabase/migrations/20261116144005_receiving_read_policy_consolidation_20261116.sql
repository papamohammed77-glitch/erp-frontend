-- Consolidate receipt SELECT access into one permissive policy per table.
-- This preserves the original tenant, warehouse, finance, reports and buyer-owned
-- Quick Market access while adding purchasing and actor-email access without
-- accumulating permissive RLS policies.

DROP POLICY IF EXISTS receiving_select_current_tenant ON public.receiving;
DROP POLICY IF EXISTS receiving_select_buyer_own_quick_market ON public.receiving;
DROP POLICY IF EXISTS receiving_select_purchases_permission ON public.receiving;
DROP POLICY IF EXISTS receiving_select_actor_email ON public.receiving;

DROP POLICY IF EXISTS receiving_details_select_current_tenant ON public.receiving_details;
DROP POLICY IF EXISTS receiving_details_select_buyer_own_quick_market ON public.receiving_details;
DROP POLICY IF EXISTS receiving_details_select_purchases_permission ON public.receiving_details;
DROP POLICY IF EXISTS receiving_details_select_actor_email ON public.receiving_details;

CREATE POLICY receiving_select_scoped_combined
ON public.receiving
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND (
    app_private.current_user_has_permission('reports')
    OR app_private.current_user_has_permission('warehouse')
    OR app_private.current_user_has_permission('finance')
    OR responsible = (
      SELECT u.name::text
      FROM public.users u
      WHERE u.auth_id = auth.uid()
      LIMIT 1
    )
    OR lower(btrim(coalesce(responsible,''))) =
       lower(btrim(coalesce((select auth.jwt()->>'email'),'')))
    OR app_private.current_user_has_effective_permission('purchases')
    OR EXISTS (
      SELECT 1
      FROM public.purchase_invoices i
      WHERE i.id = receiving.purchase_invoice_id
        AND i.company_id = receiving.company_id
        AND i.purchase_source = 'QUICK_MARKET'
        AND i.settlement_source = 'EMPLOYEE_CUSTODY'
        AND i.cash_custody_id IS NOT NULL
        AND i.purchaser_user_id = ((public.get_my_effective_profile()->>'id')::uuid)
    )
  )
);

CREATE POLICY receiving_details_select_scoped_combined
ON public.receiving_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.receiving r
    WHERE r.operation_id = receiving_details.operation_id
      AND r.company_id = app_private.current_user_company_id()
      AND (
        app_private.current_user_has_permission('reports')
        OR app_private.current_user_has_permission('warehouse')
        OR app_private.current_user_has_permission('finance')
        OR r.responsible = (
          SELECT u.name::text
          FROM public.users u
          WHERE u.auth_id = auth.uid()
          LIMIT 1
        )
        OR lower(btrim(coalesce(r.responsible,''))) =
           lower(btrim(coalesce((select auth.jwt()->>'email'),'')))
        OR app_private.current_user_has_effective_permission('purchases')
        OR EXISTS (
          SELECT 1
          FROM public.purchase_invoices i
          WHERE i.id = r.purchase_invoice_id
            AND i.company_id = r.company_id
            AND i.purchase_source = 'QUICK_MARKET'
            AND i.settlement_source = 'EMPLOYEE_CUSTODY'
            AND i.cash_custody_id IS NOT NULL
            AND i.purchaser_user_id = ((public.get_my_effective_profile()->>'id')::uuid)
        )
      )
  )
);
