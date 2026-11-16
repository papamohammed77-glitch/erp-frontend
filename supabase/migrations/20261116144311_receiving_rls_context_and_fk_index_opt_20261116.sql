-- Optimize the receipt read policies for statement-level auth context evaluation.
-- Preserve the same four access paths and keep one SELECT policy per table.
DROP POLICY IF EXISTS receiving_select_scoped_combined ON public.receiving;
DROP POLICY IF EXISTS receiving_details_select_scoped_combined ON public.receiving_details;

CREATE POLICY receiving_select_scoped_combined
ON public.receiving
FOR SELECT
TO authenticated
USING (
  company_id = (SELECT app_private.current_user_company_id())
  AND (
    (SELECT app_private.current_user_has_permission('reports'))
    OR (SELECT app_private.current_user_has_permission('warehouse'))
    OR (SELECT app_private.current_user_has_permission('finance'))
    OR responsible = (
      SELECT u.name::text
      FROM public.users u
      WHERE u.auth_id = (SELECT auth.uid())
      LIMIT 1
    )
    OR lower(btrim(coalesce(responsible,''))) =
       lower(btrim(coalesce((SELECT auth.jwt()->>'email'),'')))
    OR (SELECT app_private.current_user_has_effective_permission('purchases'))
    OR EXISTS (
      SELECT 1
      FROM public.purchase_invoices i
      WHERE i.id = receiving.purchase_invoice_id
        AND i.company_id = receiving.company_id
        AND i.purchase_source = 'QUICK_MARKET'
        AND i.settlement_source = 'EMPLOYEE_CUSTODY'
        AND i.cash_custody_id IS NOT NULL
        AND i.purchaser_user_id = (((SELECT public.get_my_effective_profile())->>'id')::uuid)
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
      AND r.company_id = (SELECT app_private.current_user_company_id())
      AND (
        (SELECT app_private.current_user_has_permission('reports'))
        OR (SELECT app_private.current_user_has_permission('warehouse'))
        OR (SELECT app_private.current_user_has_permission('finance'))
        OR r.responsible = (
          SELECT u.name::text
          FROM public.users u
          WHERE u.auth_id = (SELECT auth.uid())
          LIMIT 1
        )
        OR lower(btrim(coalesce(r.responsible,''))) =
           lower(btrim(coalesce((SELECT auth.jwt()->>'email'),'')))
        OR (SELECT app_private.current_user_has_effective_permission('purchases'))
        OR EXISTS (
          SELECT 1
          FROM public.purchase_invoices i
          WHERE i.id = r.purchase_invoice_id
            AND i.company_id = r.company_id
            AND i.purchase_source = 'QUICK_MARKET'
            AND i.settlement_source = 'EMPLOYEE_CUSTODY'
            AND i.cash_custody_id IS NOT NULL
            AND i.purchaser_user_id = (((SELECT public.get_my_effective_profile())->>'id')::uuid)
        )
      )
  )
);

-- Standalone covering indexes for the FK columns. Existing composite/partial
-- indexes remain in place for the application's compound reads.
CREATE INDEX IF NOT EXISTS receiving_purchase_invoice_fk_idx
  ON public.receiving (purchase_invoice_id);

CREATE INDEX IF NOT EXISTS receiving_details_purchase_invoice_detail_fk_idx
  ON public.receiving_details (purchase_invoice_detail_id);
