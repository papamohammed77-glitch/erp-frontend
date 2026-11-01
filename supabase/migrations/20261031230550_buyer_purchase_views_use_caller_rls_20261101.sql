
DROP POLICY IF EXISTS supplier_ledger_select_current_tenant ON public.supplier_ledger;
CREATE POLICY supplier_ledger_select_current_tenant
ON public.supplier_ledger
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.suppliers s
    WHERE s.id = public.supplier_ledger.supplier_id
      AND s.company_id = app_private.current_user_company_id()
      AND (
        app_private.current_user_has_effective_permission('suppliers')
        OR app_private.current_user_has_effective_permission('purchases')
        OR app_private.current_user_has_effective_permission('finance')
        OR app_private.current_user_has_effective_permission('reports')
      )
  )
);
ALTER VIEW public.purchase_supplier_balance SET (security_invoker = true);
ALTER VIEW public.purchase_invoice_aging SET (security_invoker = true);
ALTER VIEW public.purchase_quotation_comparison SET (security_invoker = true);
