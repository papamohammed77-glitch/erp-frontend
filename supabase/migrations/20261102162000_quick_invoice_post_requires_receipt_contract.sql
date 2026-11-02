-- LVE-582: fail closed for quick invoices until a direct warehouse-receipt contract exists.
-- PO-linked invoices keep their existing receiving/quantity/price validation path.
-- This guard prevents unlinked invoices from posting stock, supplier liability, or journals
-- without an approved warehouse receiving record. It changes no existing balances.

CREATE OR REPLACE FUNCTION public.purchase_post_invoice_atomic(p_company_id uuid, p_invoice_id uuid, p_actor text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  i public.purchase_invoices%rowtype;
  d public.purchase_invoice_details%rowtype;
  po public.purchase_orders%rowtype;
  pd public.purchase_order_details%rowtype;
  branch_id uuid;
  inv_acc uuid;
  sup_acc uuid;
  je jsonb;
  v_previous_invoiced numeric(14,3);
  v_po_invoice_total numeric(14,2) := 0;
  v_system_currency text;
BEGIN
  SELECT * INTO i
  FROM public.purchase_invoices
  WHERE id = p_invoice_id AND company_id = p_company_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_INVOICE_NOT_FOUND'; END IF;
  IF i.status <> 'Draft' THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true,
      'id', i.id, 'code', i.invoice_code, 'status', i.status);
  END IF;

  SELECT upper(nullif(btrim(s.currency), ''))
    INTO v_system_currency
  FROM public.app_settings s
  WHERE s.company_id = p_company_id
  ORDER BY s.created_at, s.id
  LIMIT 1;

  IF v_system_currency IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_SYSTEM_CURRENCY_NOT_CONFIGURED';
  END IF;
  IF upper(COALESCE(i.currency, '')) <> v_system_currency THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_SYSTEM_CURRENCY_MISMATCH:%', v_system_currency;
  END IF;

  IF i.purchase_order_id IS NOT NULL THEN
    SELECT * INTO po
    FROM public.purchase_orders
    WHERE id = i.purchase_order_id AND company_id = p_company_id
      AND supplier_id = i.supplier_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_PO_SUPPLIER_MISMATCH'; END IF;
    IF upper(COALESCE(po.currency, '')) <> v_system_currency THEN
      RAISE EXCEPTION 'PURCHASE_PO_SYSTEM_CURRENCY_MISMATCH:%', v_system_currency;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.receiving r
      WHERE r.company_id = p_company_id
        AND r.po_number = po.po_code
        AND r.status IN ('مكتمل', 'Completed')
    ) THEN
      RAISE EXCEPTION 'PURCHASE_RECEIVING_REQUIRED_BEFORE_POSTING_PO_INVOICE';
    END IF;

    FOR d IN
      SELECT * FROM public.purchase_invoice_details
      WHERE invoice_id = i.id
    LOOP
      SELECT * INTO pd
      FROM public.purchase_order_details x
      WHERE x.po_id = po.id
        AND x.item_id = d.item_id
        AND x.item_code = d.item_code
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_NOT_IN_PO:%', d.item_code;
      END IF;

      SELECT COALESCE(SUM(other_detail.qty), 0)
        INTO v_previous_invoiced
      FROM public.purchase_invoice_details other_detail
      JOIN public.purchase_invoices other_invoice
        ON other_invoice.id = other_detail.invoice_id
      WHERE other_invoice.company_id = p_company_id
        AND other_invoice.purchase_order_id = po.id
        AND other_invoice.id <> i.id
        AND other_invoice.status <> 'Cancelled'
        AND other_detail.item_code = d.item_code;

      IF COALESCE(d.qty, 0) <= 0
         OR COALESCE(pd.qty_received, 0) < COALESCE(d.qty, 0) + COALESCE(v_previous_invoiced, 0) THEN
        RAISE EXCEPTION 'PURCHASE_INVOICE_QTY_EXCEEDS_RECEIVED:%', d.item_code;
      END IF;

      IF abs(COALESCE(d.unit_price, 0) - COALESCE(pd.unit_price, 0)) > 0.01
         OR COALESCE(d.discount_percent, 0) <> 0
         OR COALESCE(d.tax_rate, 0) <> 0 THEN
        RAISE EXCEPTION 'PURCHASE_INVOICE_PO_PRICE_OR_TAX_MISMATCH:%', d.item_code;
      END IF;

      v_po_invoice_total := v_po_invoice_total + (d.qty * pd.unit_price);
    END LOOP;

    IF abs(v_po_invoice_total - COALESCE(i.total_amount, 0)) > 0.01 THEN
      RAISE EXCEPTION 'PURCHASE_INVOICE_PO_TOTAL_MISMATCH';
    END IF;

    UPDATE public.purchase_invoices
    SET status = 'Posted',
        is_received = true,
        received_date = COALESCE(received_date, current_date),
        posted_by = p_actor,
        posted_at = now(),
        updated_at = now()
    WHERE id = i.id AND company_id = p_company_id;

    RETURN jsonb_build_object(
      'success', true, 'id', i.id, 'code', i.invoice_code, 'status', 'Posted',
      'accounting_source', 'PurchaseReceiving',
      'stock_posted_by_invoice', false,
      'supplier_liability_posted_by_invoice', false
    );
  END IF;

  IF i.purchase_order_id IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_QUICK_INVOICE_RECEIPT_REQUIRED: لا يمكن ترحيل فاتورة شراء سريعة غير مرتبطة بأمر شراء قبل تسجيل الاستلام الفعلي واعتماده من المخزن.';
  END IF;

  branch_id := COALESCE(
    i.branch_id,
    (SELECT a.main_branch_id
     FROM public.app_settings a
     WHERE a.company_id = p_company_id
     ORDER BY a.created_at, a.id
     LIMIT 1)
  );

  IF branch_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.branches
    WHERE id = branch_id AND company_id = p_company_id
  ) THEN
    RAISE EXCEPTION 'PURCHASE_BRANCH_INVALID';
  END IF;

  SELECT id INTO inv_acc
  FROM public.chart_of_accounts
  WHERE company_id = p_company_id AND account_code = '124' AND is_active
  LIMIT 1;
  SELECT id INTO sup_acc
  FROM public.chart_of_accounts
  WHERE company_id = p_company_id AND account_code = '211' AND is_active
  LIMIT 1;

  IF inv_acc IS NULL OR sup_acc IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_ACCOUNTS_NOT_CONFIGURED';
  END IF;

  FOR d IN
    SELECT * FROM public.purchase_invoice_details
    WHERE invoice_id = i.id
  LOOP
    PERFORM public.post_stock_movement(
      p_company_id, 'PurchaseIn', NULL, branch_id, d.item_id, d.qty,
      i.invoice_code, i.invoice_code, p_actor,
      'PurchaseInvoice:' || i.id::text || ':' || d.id::text
    );
    UPDATE public.purchase_invoice_details
    SET received_qty = d.qty
    WHERE id = d.id;
  END LOOP;

  je := public.post_journal_entry(
    p_company_id, gen_random_uuid(), i.invoice_date, 'PurchaseInvoice',
    i.invoice_code, 'فاتورة شراء ' || i.invoice_code, p_actor,
    jsonb_build_array(
      jsonb_build_object('account_id', inv_acc,
        'account_name', (SELECT account_name FROM public.chart_of_accounts WHERE id = inv_acc),
        'debit', i.total_amount, 'credit', 0),
      jsonb_build_object('account_id', sup_acc,
        'account_name', (SELECT account_name FROM public.chart_of_accounts WHERE id = sup_acc),
        'debit', 0, 'credit', i.total_amount)
    ), NULL, now(), NULL
  );

  INSERT INTO public.supplier_ledger(
    supplier_id, entry_date, reference, description,
    debit, credit, balance, due_date, user_email
  )
  VALUES(
    i.supplier_id, i.invoice_date, i.invoice_code,
    'فاتورة شراء - ' || i.invoice_code, 0, i.total_amount,
    COALESCE((
      SELECT balance FROM public.supplier_ledger
      WHERE supplier_id = i.supplier_id
      ORDER BY created_at DESC LIMIT 1
    ), 0) + i.total_amount,
    i.due_date, p_actor
  );

  UPDATE public.purchase_invoices
  SET status = 'Posted',
      is_received = true,
      received_date = current_date,
      posted_by = p_actor,
      posted_at = now(),
      updated_at = now()
  WHERE id = i.id AND company_id = p_company_id;

  RETURN jsonb_build_object(
    'success', true, 'id', i.id, 'code', i.invoice_code,
    'status', 'Posted', 'journal', je
  );
END;
$function$


COMMENT ON FUNCTION public.purchase_post_invoice_atomic(uuid, uuid, text)
IS 'PO-linked invoices require completed receiving and three-way checks. Unlinked quick invoices are blocked until an approved direct warehouse-receipt contract exists.';
