-- LVE-582: safe draft-only edit/delete for Buyer purchase invoices.
-- This migration changes no stock, treasury, supplier ledger, or journal balances.
-- All write access is restricted to the existing save-purchase-order Edge Function service role.

CREATE OR REPLACE FUNCTION public.purchase_update_draft_invoice_atomic(
  p_company_id uuid,
  p_invoice_id uuid,
  p_supplier_id uuid,
  p_purchase_order_id uuid,
  p_branch_id uuid,
  p_due_date date,
  p_currency text,
  p_actor text,
  p_supplier_invoice_no text,
  p_notes text,
  p_items jsonb,
  p_operation_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_invoice public.purchase_invoices%rowtype;
  v_po public.purchase_orders%rowtype;
  v_item public.items%rowtype;
  v_system_currency text;
  v_require_receiving boolean := false;
  v_item_count integer;
  v_line jsonb;
  v_qty numeric;
  v_price numeric;
  v_discount_percent numeric;
  v_tax_rate numeric;
  v_gross numeric;
  v_discount_amount numeric;
  v_tax_amount numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_total_discount numeric := 0;
  v_total_tax numeric := 0;
  v_total numeric := 0;
BEGIN
  IF NULLIF(btrim(p_operation_id), '') IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_OPERATION_ID_REQUIRED';
  END IF;

  IF NULLIF(btrim(p_actor), '') IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.company_id = p_company_id
      AND lower(u.email) = lower(btrim(p_actor))
      AND u.status = 'Active'
  ) THEN
    RAISE EXCEPTION 'PURCHASE_ACTOR_INVALID';
  END IF;

  SELECT COALESCE(NULLIF(upper(btrim(a.currency)), ''), 'EGP')
    INTO v_system_currency
  FROM public.app_settings a
  WHERE a.company_id = p_company_id
  ORDER BY a.created_at, a.id
  LIMIT 1;

  IF v_system_currency IS NULL OR v_system_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'SYSTEM_CURRENCY_NOT_CONFIGURED';
  END IF;
  IF p_currency IS NOT NULL AND upper(btrim(p_currency)) <> v_system_currency THEN
    RAISE EXCEPTION 'PURCHASE_CURRENCY_MUST_MATCH_SYSTEM';
  END IF;

  SELECT *
    INTO v_invoice
  FROM public.purchase_invoices
  WHERE id = p_invoice_id
    AND company_id = p_company_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_NOT_FOUND';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.purchase_status_history h
    WHERE h.company_id = p_company_id
      AND h.document_type = 'PurchaseInvoice'
      AND h.document_id = p_invoice_id
      AND h.action = 'UPDATED_DRAFT'
      AND h.note = 'operation_id=' || p_operation_id
  ) THEN
    RETURN jsonb_build_object(
      'success', true, 'duplicate', true,
      'id', v_invoice.id, 'code', v_invoice.invoice_code,
      'status', v_invoice.status, 'total_amount', v_invoice.total_amount
    );
  END IF;

  IF v_invoice.status <> 'Draft'
     OR COALESCE(v_invoice.is_received, false)
     OR COALESCE(v_invoice.paid_amount, 0) <> 0
     OR v_invoice.posted_at IS NOT NULL
     OR v_invoice.journal_entry_id IS NOT NULL
     OR v_invoice.supplier_ledger_id IS NOT NULL THEN
    RAISE EXCEPTION 'ONLY_UNRECEIVED_UNPOSTED_DRAFT_INVOICES_CAN_BE_EDITED';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.purchase_invoice_details d
    WHERE d.invoice_id = p_invoice_id
      AND COALESCE(d.received_qty, 0) > 0
  ) THEN
    RAISE EXCEPTION 'INVOICE_HAS_RECEIVED_QUANTITY';
  END IF;

  IF EXISTS (SELECT 1 FROM public.buyer_custody_expenses e WHERE e.purchase_invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.purchase_payment_allocations a WHERE a.invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.purchase_returns r WHERE r.purchase_invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.stock_vouchers v WHERE v.purchase_invoice_id = p_invoice_id) THEN
    RAISE EXCEPTION 'INVOICE_HAS_DOWNSTREAM_FINANCIAL_OR_STOCK_REFERENCES';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.suppliers s
    WHERE s.id = p_supplier_id
      AND s.company_id = p_company_id
      AND s.is_active
  ) THEN
    RAISE EXCEPTION 'PURCHASE_SUPPLIER_INVALID';
  END IF;

  IF p_branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches b
    WHERE b.id = p_branch_id
      AND b.company_id = p_company_id
  ) THEN
    RAISE EXCEPTION 'PURCHASE_BRANCH_INVALID';
  END IF;

  IF p_purchase_order_id IS NOT NULL THEN
    SELECT *
      INTO v_po
    FROM public.purchase_orders
    WHERE id = p_purchase_order_id
      AND company_id = p_company_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PURCHASE_PO_NOT_FOUND';
    END IF;
    IF v_po.supplier_id IS DISTINCT FROM p_supplier_id THEN
      RAISE EXCEPTION 'PURCHASE_PO_SUPPLIER_MISMATCH';
    END IF;
    IF upper(COALESCE(v_po.currency, v_system_currency)) <> v_system_currency THEN
      RAISE EXCEPTION 'PURCHASE_PO_CURRENCY_MISMATCH';
    END IF;

    SELECT COALESCE(ps.require_receiving_before_invoice, false)
      INTO v_require_receiving
    FROM public.purchase_settings ps
    WHERE ps.company_id = p_company_id;

    IF v_require_receiving AND v_po.status NOT IN ('Partially Received', 'Received') THEN
      RAISE EXCEPTION 'PURCHASE_RECEIVING_REQUIRED_BEFORE_INVOICE';
    END IF;
  END IF;

  IF COALESCE(jsonb_typeof(p_items), '') <> 'array' THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_ITEMS_MUST_BE_ARRAY';
  END IF;
  v_item_count := jsonb_array_length(p_items);
  IF v_item_count < 1 OR v_item_count > 500 THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_COUNT_INVALID';
  END IF;

  DELETE FROM public.purchase_invoice_details
  WHERE invoice_id = p_invoice_id;

  FOR v_line IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT *
      INTO v_item
    FROM public.items
    WHERE company_id = p_company_id
      AND item_code = btrim(v_line->>'item_code');

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_INVALID:%', v_line->>'item_code';
    END IF;

    v_qty := NULLIF(btrim(v_line->>'qty'), '')::numeric;
    v_price := NULLIF(btrim(v_line->>'unit_price'), '')::numeric;
    v_discount_percent := COALESCE(NULLIF(btrim(v_line->>'discount_percent'), '')::numeric, 0);
    v_tax_rate := COALESCE(NULLIF(btrim(v_line->>'tax_rate'), '')::numeric, 0);

    IF v_qty IS NULL OR v_qty <= 0
       OR v_price IS NULL OR v_price < 0
       OR v_discount_percent < 0 OR v_discount_percent > 100
       OR v_tax_rate < 0 OR v_tax_rate > 100 THEN
      RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_VALUES_INVALID:%', v_line->>'item_code';
    END IF;

    v_gross := v_qty * v_price;
    v_discount_amount := v_gross * v_discount_percent / 100;
    v_tax_amount := (v_gross - v_discount_amount) * v_tax_rate / 100;
    v_line_total := (v_gross - v_discount_amount) * (1 + v_tax_rate / 100);

    INSERT INTO public.purchase_invoice_details(
      invoice_id, item_id, item_code, item_name, unit, qty, unit_price,
      discount_percent, discount_amount, tax_rate, tax_amount, line_total
    )
    VALUES(
      p_invoice_id, v_item.id, v_item.item_code, v_item.name, v_item.unit,
      v_qty, v_price, v_discount_percent, v_discount_amount,
      v_tax_rate, v_tax_amount, v_line_total
    );

    v_subtotal := v_subtotal + v_gross;
    v_total_discount := v_total_discount + v_discount_amount;
    v_total_tax := v_total_tax + v_tax_amount;
    v_total := v_total + v_line_total;
  END LOOP;

  UPDATE public.purchase_invoices
  SET supplier_id = p_supplier_id,
      purchase_order_id = p_purchase_order_id,
      branch_id = p_branch_id,
      due_date = p_due_date,
      currency = v_system_currency,
      supplier_invoice_no = NULLIF(btrim(p_supplier_invoice_no), ''),
      notes = NULLIF(btrim(p_notes), ''),
      subtotal = v_subtotal,
      discount_amount = v_total_discount,
      tax_amount = v_total_tax,
      total_amount = v_total
  WHERE id = p_invoice_id
    AND company_id = p_company_id
    AND status = 'Draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_DRAFT_UPDATE_FAILED';
  END IF;

  INSERT INTO public.purchase_status_history(
    company_id, document_type, document_id, from_status, to_status,
    action, actor_email, note
  )
  VALUES(
    p_company_id, 'PurchaseInvoice', p_invoice_id, 'Draft', 'Draft',
    'UPDATED_DRAFT', p_actor, 'operation_id=' || p_operation_id
  );

  RETURN jsonb_build_object(
    'success', true, 'id', p_invoice_id,
    'code', v_invoice.invoice_code, 'status', 'Draft',
    'total_amount', v_total, 'currency', v_system_currency
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.purchase_delete_draft_invoice_atomic(
  p_company_id uuid,
  p_invoice_id uuid,
  p_actor text,
  p_reason text,
  p_operation_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_invoice public.purchase_invoices%rowtype;
  v_note text;
BEGIN
  IF NULLIF(btrim(p_operation_id), '') IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_OPERATION_ID_REQUIRED';
  END IF;

  IF NULLIF(btrim(p_actor), '') IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.company_id = p_company_id
      AND lower(u.email) = lower(btrim(p_actor))
      AND u.status = 'Active'
  ) THEN
    RAISE EXCEPTION 'PURCHASE_ACTOR_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.purchase_status_history h
    WHERE h.company_id = p_company_id
      AND h.document_type = 'PurchaseInvoice'
      AND h.document_id = p_invoice_id
      AND h.action = 'DELETED_DRAFT'
      AND h.note LIKE 'operation_id=' || p_operation_id || ';%'
  ) THEN
    RETURN jsonb_build_object(
      'success', true, 'duplicate', true,
      'id', p_invoice_id, 'status', 'Deleted'
    );
  END IF;

  SELECT *
    INTO v_invoice
  FROM public.purchase_invoices
  WHERE id = p_invoice_id
    AND company_id = p_company_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_NOT_FOUND';
  END IF;

  IF v_invoice.status <> 'Draft'
     OR COALESCE(v_invoice.is_received, false)
     OR COALESCE(v_invoice.paid_amount, 0) <> 0
     OR v_invoice.posted_at IS NOT NULL
     OR v_invoice.journal_entry_id IS NOT NULL
     OR v_invoice.supplier_ledger_id IS NOT NULL THEN
    RAISE EXCEPTION 'ONLY_UNRECEIVED_UNPOSTED_DRAFT_INVOICES_CAN_BE_DELETED';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.purchase_invoice_details d
    WHERE d.invoice_id = p_invoice_id
      AND COALESCE(d.received_qty, 0) > 0
  ) THEN
    RAISE EXCEPTION 'INVOICE_HAS_RECEIVED_QUANTITY';
  END IF;

  IF EXISTS (SELECT 1 FROM public.buyer_custody_expenses e WHERE e.purchase_invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.purchase_payment_allocations a WHERE a.invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.purchase_returns r WHERE r.purchase_invoice_id = p_invoice_id)
     OR EXISTS (SELECT 1 FROM public.stock_vouchers v WHERE v.purchase_invoice_id = p_invoice_id) THEN
    RAISE EXCEPTION 'INVOICE_HAS_DOWNSTREAM_FINANCIAL_OR_STOCK_REFERENCES';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.purchase_attachments a
    WHERE a.company_id = p_company_id
      AND a.document_id = p_invoice_id
      AND a.document_type IN ('PurchaseInvoice', 'purchase_invoice', 'invoice')
  ) OR EXISTS (
    SELECT 1 FROM public.purchase_document_links l
    WHERE l.company_id = p_company_id
      AND (
        (l.source_id = p_invoice_id AND l.source_type IN ('PurchaseInvoice', 'purchase_invoice', 'invoice'))
        OR
        (l.target_id = p_invoice_id AND l.target_type IN ('PurchaseInvoice', 'purchase_invoice', 'invoice'))
      )
  ) THEN
    RAISE EXCEPTION 'INVOICE_HAS_DOCUMENT_OR_ATTACHMENT_LINKS';
  END IF;

  v_note := 'operation_id=' || p_operation_id || '; reason=' || COALESCE(NULLIF(btrim(p_reason), ''), 'Draft deleted by authorized Buyer user');

  INSERT INTO public.purchase_status_history(
    company_id, document_type, document_id, from_status, to_status,
    action, actor_email, note
  )
  VALUES(
    p_company_id, 'PurchaseInvoice', p_invoice_id, 'Draft', 'Deleted',
    'DELETED_DRAFT', p_actor, v_note
  );

  DELETE FROM public.purchase_invoices
  WHERE id = p_invoice_id
    AND company_id = p_company_id
    AND status = 'Draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_DRAFT_DELETE_FAILED';
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'id', p_invoice_id,
    'code', v_invoice.invoice_code, 'status', 'Deleted'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.purchase_update_draft_invoice_atomic(uuid, uuid, uuid, uuid, uuid, date, text, text, text, text, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_update_draft_invoice_atomic(uuid, uuid, uuid, uuid, uuid, date, text, text, text, text, jsonb, text) TO service_role;

REVOKE ALL ON FUNCTION public.purchase_delete_draft_invoice_atomic(uuid, uuid, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_delete_draft_invoice_atomic(uuid, uuid, text, text, text) TO service_role;
