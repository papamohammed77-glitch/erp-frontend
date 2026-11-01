-- LVE-575: keep Buyer PO invoice posting on the configured company currency
-- and bind custody-payment visibility to the same company's custody.
-- No new tables, Edge Functions, or data mutations are introduced.

DO $migration$
DECLARE
  v_definition text;
  v_decl_anchor text := '  v_po_invoice_total numeric(14,2) := 0;';
  v_decl_replacement text;
  v_po_branch_anchor text := '  IF i.purchase_order_id IS NOT NULL THEN';
  v_po_branch_replacement text;
  v_po_supplier_anchor text := '    IF NOT FOUND THEN RAISE EXCEPTION ''PURCHASE_PO_SUPPLIER_MISMATCH''; END IF;';
  v_po_supplier_replacement text;
BEGIN
  SELECT pg_get_functiondef(
    'public.purchase_post_invoice_atomic(uuid,uuid,text)'::regprocedure
  ) INTO v_definition;

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'LVE575_PURCHASE_POST_FUNCTION_NOT_FOUND';
  END IF;

  IF position('v_system_currency text;' IN v_definition) > 0
     OR position('PURCHASE_INVOICE_SYSTEM_CURRENCY_MISMATCH' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'LVE575_PURCHASE_POST_FUNCTION_ALREADY_OR_PARTIALLY_PATCHED';
  END IF;

  IF position(v_decl_anchor IN v_definition) = 0
     OR position(v_po_branch_anchor IN v_definition) = 0
     OR position(v_po_supplier_anchor IN v_definition) = 0 THEN
    RAISE EXCEPTION 'LVE575_PURCHASE_POST_SOURCE_ANCHOR_MISMATCH';
  END IF;

  v_decl_replacement := v_decl_anchor || E'\n  v_system_currency text;';
  v_definition := replace(v_definition, v_decl_anchor, v_decl_replacement);

  v_po_branch_replacement :=
    E'  SELECT upper(nullif(btrim(s.currency), ''''))\n' ||
    E'    INTO v_system_currency\n' ||
    E'  FROM public.app_settings s\n' ||
    E'  WHERE s.company_id = p_company_id\n' ||
    E'  ORDER BY s.created_at, s.id\n' ||
    E'  LIMIT 1;\n\n' ||
    E'  IF v_system_currency IS NULL THEN\n' ||
    E'    RAISE EXCEPTION ''PURCHASE_SYSTEM_CURRENCY_NOT_CONFIGURED'';\n' ||
    E'  END IF;\n' ||
    E'  IF upper(COALESCE(i.currency, '''')) <> v_system_currency THEN\n' ||
    E'    RAISE EXCEPTION ''PURCHASE_INVOICE_SYSTEM_CURRENCY_MISMATCH:%'', v_system_currency;\n' ||
    E'  END IF;\n\n' ||
    v_po_branch_anchor;

  v_definition := replace(v_definition, v_po_branch_anchor, v_po_branch_replacement);

  v_po_supplier_replacement :=
    v_po_supplier_anchor ||
    E'\n    IF upper(COALESCE(po.currency, '''')) <> v_system_currency THEN\n' ||
    E'      RAISE EXCEPTION ''PURCHASE_PO_SYSTEM_CURRENCY_MISMATCH:%'', v_system_currency;\n' ||
    E'    END IF;';

  v_definition := replace(v_definition, v_po_supplier_anchor, v_po_supplier_replacement);

  EXECUTE v_definition;
END;
$migration$;

DROP POLICY IF EXISTS buyer_custody_payments_scoped_select
  ON public.buyer_custody_payments;

CREATE POLICY buyer_custody_payments_scoped_select
ON public.buyer_custody_payments
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND EXISTS (
    SELECT 1
    FROM public.buyer_custodies c
    WHERE c.id = buyer_custody_payments.custody_id
      AND c.company_id = buyer_custody_payments.company_id
      AND (
        c.employee_id = (
          SELECT u.id
          FROM public.users u
          WHERE u.auth_id = auth.uid()
          LIMIT 1
        )
        OR app_private.current_user_has_effective_permission('finance')
        OR app_private.current_user_has_effective_permission('finance_manager')
      )
  )
);

COMMENT ON POLICY buyer_custody_payments_scoped_select
ON public.buyer_custody_payments
IS 'Employee/finance visibility requires the payment and linked custody to belong to the same current company.';
