
CREATE OR REPLACE FUNCTION app_private.sync_supplier_accounts_payable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_supplier_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_supplier_id := OLD.supplier_id;
  ELSE
    v_supplier_id := NEW.supplier_id;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.supplier_id IS DISTINCT FROM NEW.supplier_id THEN
    UPDATE public.suppliers s
       SET accounts_payable = COALESCE((
         SELECT SUM(sl.credit - sl.debit)
         FROM public.supplier_ledger sl
         WHERE sl.supplier_id = OLD.supplier_id
       ), 0),
       updated_at = now()
     WHERE s.id = OLD.supplier_id;
  END IF;

  UPDATE public.suppliers s
     SET accounts_payable = COALESCE((
       SELECT SUM(sl.credit - sl.debit)
       FROM public.supplier_ledger sl
       WHERE sl.supplier_id = v_supplier_id
     ), 0),
     updated_at = now()
   WHERE s.id = v_supplier_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION app_private.sync_supplier_accounts_payable() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS supplier_ledger_sync_accounts_payable ON public.supplier_ledger;
CREATE TRIGGER supplier_ledger_sync_accounts_payable
AFTER INSERT OR UPDATE OR DELETE ON public.supplier_ledger
FOR EACH ROW EXECUTE FUNCTION app_private.sync_supplier_accounts_payable();

CREATE OR REPLACE FUNCTION public.purchase_create_invoice_atomic(
  p_company_id uuid,
  p_supplier_id uuid,
  p_purchase_order_id uuid,
  p_branch_id uuid,
  p_due_date date,
  p_currency text,
  p_created_by text,
  p_items jsonb,
  p_operation_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  iid uuid;
  code text;
  x jsonb;
  im public.items%rowtype;
  inv public.purchase_invoices%rowtype;
  po public.purchase_orders%rowtype;
  total numeric := 0;
  require_receiving boolean := false;
  v_system_currency text;
BEGIN
  IF NULLIF(btrim(p_operation_id), '') IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_OPERATION_ID_REQUIRED';
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

  SELECT * INTO inv
  FROM public.purchase_invoices
  WHERE company_id = p_company_id AND operation_id = p_operation_id
  FOR UPDATE;
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true,
      'id', inv.id, 'code', inv.invoice_code, 'status', inv.status);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.suppliers
    WHERE id = p_supplier_id AND company_id = p_company_id AND is_active
  ) THEN
    RAISE EXCEPTION 'PURCHASE_SUPPLIER_INVALID';
  END IF;

  IF p_branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches
    WHERE id = p_branch_id AND company_id = p_company_id
  ) THEN
    RAISE EXCEPTION 'PURCHASE_BRANCH_INVALID';
  END IF;

  SELECT COALESCE(ps.require_receiving_before_invoice, false)
    INTO require_receiving
  FROM public.purchase_settings ps
  WHERE ps.company_id = p_company_id;

  IF p_purchase_order_id IS NOT NULL THEN
    SELECT * INTO po
    FROM public.purchase_orders
    WHERE id = p_purchase_order_id AND company_id = p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_PO_NOT_FOUND'; END IF;
    IF po.supplier_id IS DISTINCT FROM p_supplier_id THEN
      RAISE EXCEPTION 'PURCHASE_PO_SUPPLIER_MISMATCH';
    END IF;
    IF upper(COALESCE(po.currency, v_system_currency)) <> v_system_currency THEN
      RAISE EXCEPTION 'PURCHASE_PO_CURRENCY_MISMATCH';
    END IF;
    IF require_receiving AND po.status NOT IN ('Partially Received', 'Received') THEN
      RAISE EXCEPTION 'PURCHASE_RECEIVING_REQUIRED_BEFORE_INVOICE';
    END IF;
  END IF;

  code := public.purchase_next_code(p_company_id, 'invoice');
  INSERT INTO public.purchase_invoices(
    company_id, invoice_code, supplier_id, purchase_order_id, branch_id,
    due_date, currency, status, created_by, operation_id
  )
  VALUES(
    p_company_id, code, p_supplier_id, p_purchase_order_id, p_branch_id,
    p_due_date, v_system_currency, 'Draft', p_created_by, p_operation_id
  )
  RETURNING id INTO iid;

  FOR x IN SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) LOOP
    SELECT * INTO im
    FROM public.items
    WHERE item_code = btrim(x->>'item_code') AND company_id = p_company_id;

    IF NOT FOUND
       OR COALESCE((x->>'qty')::numeric, 0) <= 0
       OR COALESCE((x->>'unit_price')::numeric, 0) < 0 THEN
      RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_INVALID:%', x->>'item_code';
    END IF;

    INSERT INTO public.purchase_invoice_details(
      invoice_id, item_id, item_code, item_name, unit, qty, unit_price,
      discount_percent, discount_amount, tax_rate, tax_amount, line_total
    )
    VALUES(
      iid, im.id, im.item_code, im.name, im.unit,
      (x->>'qty')::numeric, (x->>'unit_price')::numeric,
      COALESCE((x->>'discount_percent')::numeric, 0),
      ((x->>'qty')::numeric * (x->>'unit_price')::numeric *
        COALESCE((x->>'discount_percent')::numeric, 0) / 100),
      COALESCE((x->>'tax_rate')::numeric, 0),
      ((((x->>'qty')::numeric * (x->>'unit_price')::numeric) *
        (1 - COALESCE((x->>'discount_percent')::numeric, 0) / 100)) *
        COALESCE((x->>'tax_rate')::numeric, 0) / 100),
      (((x->>'qty')::numeric * (x->>'unit_price')::numeric) *
        (1 - COALESCE((x->>'discount_percent')::numeric, 0) / 100)) *
        (1 + COALESCE((x->>'tax_rate')::numeric, 0) / 100)
    );

    total := total +
      (((x->>'qty')::numeric * (x->>'unit_price')::numeric) *
       (1 - COALESCE((x->>'discount_percent')::numeric, 0) / 100)) *
      (1 + COALESCE((x->>'tax_rate')::numeric, 0) / 100);
  END LOOP;

  UPDATE public.purchase_invoices
  SET subtotal = (
        SELECT COALESCE(SUM(qty * unit_price), 0)
        FROM public.purchase_invoice_details WHERE invoice_id = iid
      ),
      discount_amount = (
        SELECT COALESCE(SUM(discount_amount), 0)
        FROM public.purchase_invoice_details WHERE invoice_id = iid
      ),
      tax_amount = (
        SELECT COALESCE(SUM(tax_amount), 0)
        FROM public.purchase_invoice_details WHERE invoice_id = iid
      ),
      total_amount = total
  WHERE id = iid;

  RETURN jsonb_build_object(
    'success', true, 'id', iid, 'code', code, 'status', 'Draft',
    'total_amount', total, 'currency', v_system_currency
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.purchase_post_invoice_atomic(
  p_company_id uuid,
  p_invoice_id uuid,
  p_actor text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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

  IF i.purchase_order_id IS NOT NULL THEN
    SELECT * INTO po
    FROM public.purchase_orders
    WHERE id = i.purchase_order_id AND company_id = p_company_id
      AND supplier_id = i.supplier_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_PO_SUPPLIER_MISMATCH'; END IF;

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
$function$;

CREATE OR REPLACE FUNCTION public.buyer_custody_review_expense_atomic(
  p_company_id uuid,
  p_expense_id uuid,
  p_decision text,
  p_review_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor public.users%rowtype;
  v_expense public.buyer_custody_expenses%rowtype;
  v_row public.buyer_custody_expenses%rowtype;
  v_custody public.buyer_custodies%rowtype;
  v_invoice public.purchase_invoices%rowtype;
  v_po public.purchase_orders%rowtype;
  v_po_line public.purchase_order_details%rowtype;
  v_invoice_line public.purchase_invoice_details%rowtype;
  v_supplier_account uuid;
  v_custody_account uuid;
  v_balance numeric(14,2);
  v_po_credit numeric(14,2);
  v_previous_invoiced numeric(14,3);
  v_po_invoice_total numeric(14,2) := 0;
  v_journal jsonb;
  v_payment_id uuid;
  v_payment_code text;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id = auth.uid()
    AND company_id = p_company_id
    AND COALESCE(status, 'Active') = 'Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;

  IF NOT (
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN
    RAISE EXCEPTION 'CUSTODY_FINANCE_PERMISSION_REQUIRED';
  END IF;

  IF p_decision NOT IN ('Approved', 'Rejected') THEN
    RAISE EXCEPTION 'CUSTODY_REVIEW_DECISION_INVALID';
  END IF;

  SELECT * INTO v_expense
  FROM public.buyer_custody_expenses
  WHERE id = p_expense_id AND company_id = p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_expense.status <> 'Submitted' THEN
    RAISE EXCEPTION 'CUSTODY_EXPENSE_NOT_PENDING';
  END IF;
  IF v_expense.employee_id = v_actor.id THEN
    RAISE EXCEPTION 'CUSTODY_SELF_REVIEW_FORBIDDEN';
  END IF;

  IF p_decision = 'Rejected' THEN
    UPDATE public.buyer_custody_expenses
    SET status = 'Rejected', reviewed_by = v_actor.id, reviewed_at = now(),
        review_note = NULLIF(btrim(p_review_note), '')
    WHERE id = p_expense_id AND company_id = p_company_id
    RETURNING * INTO v_row;
    RETURN to_jsonb(v_row);
  END IF;

  SELECT * INTO v_custody
  FROM public.buyer_custodies
  WHERE id = v_expense.custody_id AND company_id = p_company_id
  FOR UPDATE;

  SELECT * INTO v_invoice
  FROM public.purchase_invoices
  WHERE id = v_expense.purchase_invoice_id
    AND company_id = p_company_id
    AND supplier_id = v_expense.supplier_id
  FOR UPDATE;

  IF NOT FOUND OR v_invoice.status <> 'Draft'
     OR abs(COALESCE(v_invoice.total_amount, 0) - v_expense.amount) > 0.01 THEN
    RAISE EXCEPTION 'CUSTODY_INVOICE_NOT_READY_FOR_PAYMENT';
  END IF;

  IF NULLIF(btrim(v_invoice.supplier_invoice_no), '') IS NOT NULL
     AND NULLIF(btrim(v_expense.invoice_number), '') IS DISTINCT FROM btrim(v_invoice.supplier_invoice_no) THEN
    RAISE EXCEPTION 'CUSTODY_SUPPLIER_INVOICE_NUMBER_MISMATCH';
  END IF;

  SELECT * INTO v_po
  FROM public.purchase_orders
  WHERE id = v_invoice.purchase_order_id
    AND company_id = p_company_id
    AND supplier_id = v_expense.supplier_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_PURCHASE_ORDER_INVALID'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.receiving r
    WHERE r.company_id = p_company_id
      AND r.operation_id = v_expense.receiving_operation_id
      AND r.po_number = v_po.po_code
      AND r.status IN ('مكتمل', 'Completed')
  ) OR NOT EXISTS (
    SELECT 1 FROM public.receiving_details rd
    WHERE rd.operation_id = v_expense.receiving_operation_id
  ) THEN
    RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_INVALID';
  END IF;

  FOR v_invoice_line IN
    SELECT * FROM public.purchase_invoice_details
    WHERE invoice_id = v_invoice.id
  LOOP
    SELECT * INTO v_po_line
    FROM public.purchase_order_details d
    WHERE d.po_id = v_po.id
      AND d.item_id = v_invoice_line.item_id
      AND d.item_code = v_invoice_line.item_code
    FOR SHARE;

    IF NOT FOUND
       OR NOT EXISTS (
         SELECT 1 FROM public.receiving_details rd
         WHERE rd.operation_id = v_expense.receiving_operation_id
           AND rd.item_code = v_invoice_line.item_code
           AND rd.qty_received >= v_invoice_line.qty
       ) THEN
      RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_ITEMS_MISMATCH:%', v_invoice_line.item_code;
    END IF;

    IF abs(COALESCE(v_invoice_line.unit_price, 0) - COALESCE(v_po_line.unit_price, 0)) > 0.01
       OR COALESCE(v_invoice_line.discount_percent, 0) <> 0
       OR COALESCE(v_invoice_line.tax_rate, 0) <> 0 THEN
      RAISE EXCEPTION 'CUSTODY_INVOICE_PO_PRICE_OR_TAX_MISMATCH:%', v_invoice_line.item_code;
    END IF;

    SELECT COALESCE(SUM(other_detail.qty), 0)
      INTO v_previous_invoiced
    FROM public.purchase_invoice_details other_detail
    JOIN public.purchase_invoices other_invoice
      ON other_invoice.id = other_detail.invoice_id
    WHERE other_invoice.company_id = p_company_id
      AND other_invoice.purchase_order_id = v_po.id
      AND other_invoice.id <> v_invoice.id
      AND other_invoice.status <> 'Cancelled'
      AND other_detail.item_code = v_invoice_line.item_code;

    IF COALESCE(v_po_line.qty_received, 0) <
       COALESCE(v_invoice_line.qty, 0) + COALESCE(v_previous_invoiced, 0) THEN
      RAISE EXCEPTION 'CUSTODY_INVOICE_QTY_EXCEEDS_RECEIVED:%', v_invoice_line.item_code;
    END IF;

    v_po_invoice_total := v_po_invoice_total + (v_invoice_line.qty * v_po_line.unit_price);
  END LOOP;

  IF abs(v_po_invoice_total - v_expense.amount) > 0.01
     OR abs(v_po_invoice_total - v_invoice.total_amount) > 0.01 THEN
    RAISE EXCEPTION 'CUSTODY_INVOICE_PO_TOTAL_MISMATCH';
  END IF;

  SELECT COALESCE(SUM(credit - debit), 0)
    INTO v_po_credit
  FROM public.supplier_ledger
  WHERE supplier_id = v_expense.supplier_id
    AND reference = v_po.po_code;
  IF v_po_credit + 0.005 < v_expense.amount THEN
    RAISE EXCEPTION 'CUSTODY_PO_SUPPLIER_LIABILITY_NOT_POSTED';
  END IF;

  SELECT COALESCE(SUM(credit - debit), 0)
    INTO v_balance
  FROM public.supplier_ledger
  WHERE supplier_id = v_expense.supplier_id;
  IF v_balance + 0.005 < v_expense.amount THEN
    RAISE EXCEPTION 'CUSTODY_SUPPLIER_BALANCE_INSUFFICIENT';
  END IF;

  SELECT id INTO v_supplier_account
  FROM public.chart_of_accounts
  WHERE company_id = p_company_id AND account_code = '211' AND is_active;
  SELECT id INTO v_custody_account
  FROM public.chart_of_accounts
  WHERE company_id = p_company_id AND account_code = '127' AND is_active;
  IF v_supplier_account IS NULL OR v_custody_account IS NULL THEN
    RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING';
  END IF;

  v_payment_code := 'BCP-' || to_char(current_date, 'YYYYMMDD') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  v_journal := public.post_journal_entry(
    p_company_id, gen_random_uuid(), current_date, 'PurchasePayment',
    v_invoice.invoice_code, 'سداد فاتورة المورد من عهدة الموظف', v_actor.email,
    jsonb_build_array(
      jsonb_build_object('account_id', v_supplier_account, 'debit', v_expense.amount,
        'credit', 0, 'notes', 'سداد مورد من عهدة الموظف'),
      jsonb_build_object('account_id', v_custody_account, 'debit', 0,
        'credit', v_expense.amount, 'notes', 'تسوية مصروف عهدة معتمد')
    ), NULL, now(), NULL
  );

  INSERT INTO public.buyer_custody_payments(
    company_id, custody_id, expense_id, purchase_invoice_id, supplier_id,
    payment_code, payment_date, amount, currency, reference, recorded_by,
    journal_entry_id, operation_id
  )
  VALUES(
    p_company_id, v_expense.custody_id, v_expense.id, v_invoice.id,
    v_expense.supplier_id, v_payment_code, current_date, v_expense.amount,
    v_expense.currency, v_invoice.invoice_code, v_actor.id,
    (v_journal->>'entry_id')::uuid, gen_random_uuid()
  )
  RETURNING id INTO v_payment_id;

  UPDATE public.purchase_invoices
  SET paid_amount = total_amount,
      status = 'Paid',
      is_received = true,
      received_date = COALESCE(received_date, current_date),
      posted_by = v_actor.email,
      posted_at = now(),
      updated_at = now()
  WHERE id = v_invoice.id AND company_id = p_company_id;

  INSERT INTO public.supplier_ledger(
    supplier_id, entry_date, reference, description,
    debit, credit, balance, user_email
  )
  VALUES(
    v_expense.supplier_id, current_date, v_invoice.invoice_code,
    'سداد فاتورة من عهدة الموظف - ' || v_payment_code,
    v_expense.amount, 0, v_balance - v_expense.amount, v_actor.email
  );

  UPDATE public.buyer_custody_expenses
  SET status = 'Approved', reviewed_by = v_actor.id, reviewed_at = now(),
      review_note = NULLIF(btrim(p_review_note), ''),
      payment_id = v_payment_id,
      journal_entry_id = (v_journal->>'entry_id')::uuid
  WHERE id = p_expense_id AND company_id = p_company_id
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row) || jsonb_build_object(
    'payment_code', v_payment_code,
    'journal_entry_id', v_journal->'entry_id'
  );
END;
$function$;
