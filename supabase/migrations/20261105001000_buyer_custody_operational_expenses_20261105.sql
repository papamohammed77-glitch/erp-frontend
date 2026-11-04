-- RAWAEA Buyer: cash custody operational expenses and QMP reservation-safe settlement.
-- Reuses buyer_custody_expenses, app_settings currency, private employee-documents and post_journal_entry.
-- No new Edge Function, no stock/AP/treasury posting at expense submission.

ALTER TABLE public.buyer_custody_expenses
  ADD COLUMN IF NOT EXISTS expense_type text NOT NULL DEFAULT 'PURCHASE_INVOICE',
  ADD COLUMN IF NOT EXISTS expense_category text,
  ADD COLUMN IF NOT EXISTS expense_reference text,
  ADD COLUMN IF NOT EXISTS expense_account_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.buyer_custody_expenses'::regclass AND conname='buyer_custody_expenses_expense_type_ck') THEN
    ALTER TABLE public.buyer_custody_expenses
      ADD CONSTRAINT buyer_custody_expenses_expense_type_ck
      CHECK (expense_type IN ('PURCHASE_INVOICE','OPERATIONAL'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.buyer_custody_expenses'::regclass AND conname='buyer_custody_expenses_operational_category_ck') THEN
    ALTER TABLE public.buyer_custody_expenses
      ADD CONSTRAINT buyer_custody_expenses_operational_category_ck
      CHECK (
        (expense_type='PURCHASE_INVOICE' AND expense_category IS NULL)
        OR
        (expense_type='OPERATIONAL' AND expense_category IS NOT NULL AND expense_category IN ('TRANSPORTATION','FUEL','TOLLS_PARKING','OTHER'))
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.buyer_custody_expenses'::regclass AND conname='buyer_custody_expenses_operational_document_scope_ck') THEN
    ALTER TABLE public.buyer_custody_expenses
      ADD CONSTRAINT buyer_custody_expenses_operational_document_scope_ck
      CHECK (
        expense_type <> 'OPERATIONAL'
        OR (supplier_id IS NULL AND purchase_invoice_id IS NULL AND receiving_operation_id IS NULL)
      );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.buyer_custody_expenses'::regclass AND conname='buyer_custody_expenses_expense_account_fk') THEN
    ALTER TABLE public.buyer_custody_expenses
      ADD CONSTRAINT buyer_custody_expenses_expense_account_fk
      FOREIGN KEY (expense_account_id) REFERENCES public.chart_of_accounts(id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.buyer_custody_expenses'::regclass AND conname='buyer_custody_expenses_operational_approved_journal_ck') THEN
    ALTER TABLE public.buyer_custody_expenses
      ADD CONSTRAINT buyer_custody_expenses_operational_approved_journal_ck
      CHECK (
        expense_type <> 'OPERATIONAL'
        OR status <> 'Approved'
        OR (expense_account_id IS NOT NULL AND journal_entry_id IS NOT NULL)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS buyer_custody_expenses_expense_account_id_fk_idx
  ON public.buyer_custody_expenses(expense_account_id) WHERE expense_account_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS buyer_custody_expenses_operational_review_idx
  ON public.buyer_custody_expenses(company_id,custody_id,status,expense_date DESC)
  WHERE expense_type='OPERATIONAL';

CREATE OR REPLACE FUNCTION public.buyer_custody_submit_expense_atomic(
  p_company_id uuid,p_custody_id uuid,p_expense_date date,p_supplier_name text,p_invoice_number text,
  p_description text,p_amount numeric,p_currency text,p_document_name text,p_document_path text,
  p_mime_type text,p_supplier_id uuid,p_purchase_invoice_id uuid,p_receiving_operation_id text,
  p_receipt_document_name text,p_receipt_document_path text,p_receipt_mime_type text,p_operation_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_custody public.buyer_custodies%ROWTYPE;
  v_row public.buyer_custody_expenses%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_po public.purchase_orders%ROWTYPE;
  v_currency text;
  v_acknowledged numeric(14,2);
  v_committed numeric(14,2);
  v_qmp_reserved numeric(14,2);
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;

  SELECT * INTO v_custody
  FROM public.buyer_custodies
  WHERE id=p_custody_id AND company_id=p_company_id AND employee_id=v_actor.id
  FOR UPDATE;
  IF NOT FOUND OR v_custody.status NOT IN ('Issued','UnderReview') THEN RAISE EXCEPTION 'CUSTODY_NOT_OPEN'; END IF;
  IF v_custody.acknowledged_at IS NULL THEN RAISE EXCEPTION 'CUSTODY_NOT_ACKNOWLEDGED'; END IF;

  v_currency:=upper(v_custody.currency);
  IF COALESCE(NULLIF(upper(btrim(p_currency)),''),v_currency)<>v_currency THEN RAISE EXCEPTION 'CUSTODY_CURRENCY_MISMATCH'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR NULLIF(btrim(p_description),'') IS NULL
     OR NULLIF(btrim(p_document_name),'') IS NULL OR NULLIF(btrim(p_document_path),'') IS NULL
     OR NULLIF(btrim(p_receipt_document_name),'') IS NULL OR NULLIF(btrim(p_receipt_document_path),'') IS NULL
     OR NULLIF(btrim(p_operation_id),'') IS NULL OR p_supplier_id IS NULL
     OR p_purchase_invoice_id IS NULL OR NULLIF(btrim(p_receiving_operation_id),'') IS NULL THEN
    RAISE EXCEPTION 'CUSTODY_EXPENSE_INVALID';
  END IF;

  SELECT * INTO v_row
  FROM public.buyer_custody_expenses
  WHERE company_id=p_company_id AND operation_id=p_operation_id
  FOR UPDATE;
  IF FOUND THEN
    IF v_row.expense_type='PURCHASE_INVOICE'
       AND v_row.custody_id=p_custody_id AND v_row.employee_id=v_actor.id
       AND v_row.purchase_invoice_id=p_purchase_invoice_id AND v_row.supplier_id=p_supplier_id
       AND abs(v_row.amount-p_amount)<=0.005
       AND v_row.document_name=p_document_name AND v_row.document_path=p_document_path
       AND v_row.receipt_document_path=p_receipt_document_path
       AND v_row.receiving_operation_id=p_receiving_operation_id THEN
      RETURN to_jsonb(v_row)||jsonb_build_object('duplicate',true);
    END IF;
    RAISE EXCEPTION 'CUSTODY_OPERATION_ID_CONFLICT';
  END IF;

  IF p_document_path NOT LIKE p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
     OR p_receipt_document_path NOT LIKE p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
     OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='employee-documents' AND o.name=p_document_path)
     OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='employee-documents' AND o.name=p_receipt_document_path) THEN
    RAISE EXCEPTION 'CUSTODY_DOCUMENT_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  SELECT * INTO v_invoice
  FROM public.purchase_invoices i
  WHERE i.id=p_purchase_invoice_id AND i.company_id=p_company_id
    AND i.supplier_id=p_supplier_id AND i.status='Draft'
  FOR SHARE;
  IF NOT FOUND OR v_invoice.purchase_order_id IS NULL THEN RAISE EXCEPTION 'CUSTODY_PURCHASE_INVOICE_NOT_LINKED_TO_PO'; END IF;
  IF upper(v_invoice.currency)<>v_currency THEN RAISE EXCEPTION 'CUSTODY_INVOICE_CURRENCY_MISMATCH'; END IF;
  IF abs(COALESCE(v_invoice.total_amount,0)-p_amount)>0.01 THEN RAISE EXCEPTION 'CUSTODY_INVOICE_AMOUNT_MISMATCH'; END IF;

  SELECT * INTO v_po
  FROM public.purchase_orders po
  WHERE po.id=v_invoice.purchase_order_id AND po.company_id=p_company_id AND po.supplier_id=p_supplier_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_PURCHASE_ORDER_INVALID'; END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.receiving r
    WHERE r.company_id=p_company_id AND r.operation_id=p_receiving_operation_id
      AND r.po_number=v_po.po_code AND r.status IN ('مكتمل','Completed')
  ) OR NOT EXISTS(SELECT 1 FROM public.receiving_details rd WHERE rd.operation_id=p_receiving_operation_id) THEN
    RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_INVALID';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.purchase_invoice_details d
    WHERE d.invoice_id=v_invoice.id
      AND NOT EXISTS(
        SELECT 1 FROM public.receiving_details rd
        WHERE rd.operation_id=p_receiving_operation_id AND rd.item_code=d.item_code AND rd.qty_received>=d.qty
      )
  ) THEN RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_ITEMS_MISMATCH'; END IF;
  IF NULLIF(btrim(p_invoice_number),'') IS NOT NULL
     AND v_invoice.supplier_invoice_no IS NOT NULL
     AND btrim(p_invoice_number)<>btrim(v_invoice.supplier_invoice_no) THEN
    RAISE EXCEPTION 'CUSTODY_SUPPLIER_INVOICE_NUMBER_MISMATCH';
  END IF;

  SELECT COALESCE(SUM(a.amount),0) INTO v_acknowledged
  FROM public.buyer_custody_advances a
  WHERE a.company_id=p_company_id AND a.custody_id=p_custody_id AND a.acknowledged_at IS NOT NULL;

  SELECT COALESCE(SUM(e.amount),0) INTO v_committed
  FROM public.buyer_custody_expenses e
  WHERE e.company_id=p_company_id AND e.custody_id=p_custody_id AND e.status IN ('Submitted','Approved');

  SELECT COALESCE(SUM(GREATEST(COALESCE(i.total_amount,0)-COALESCE(i.paid_amount,0)-COALESCE(linked.amount,0),0)),0)
  INTO v_qmp_reserved
  FROM public.purchase_invoices i
  LEFT JOIN LATERAL (
    SELECT SUM(e.amount) amount
    FROM public.buyer_custody_expenses e
    WHERE e.company_id=p_company_id AND e.custody_id=p_custody_id
      AND e.purchase_invoice_id=i.id AND e.status IN ('Submitted','Approved')
  ) linked ON true
  WHERE i.company_id=p_company_id AND i.cash_custody_id=p_custody_id
    AND i.purchase_source='QUICK_MARKET' AND i.settlement_source='EMPLOYEE_CUSTODY'
    AND i.status IN ('Draft','Posted','PartiallyPaid')
    AND i.settlement_status IN ('UNSETTLED','PENDING_FINANCE','AP_OPEN','PARTIALLY_SETTLED');

  IF v_committed+p_amount+v_qmp_reserved>v_acknowledged+0.005 THEN
    RAISE EXCEPTION 'CUSTODY_AVAILABLE_FUNDS_EXCEEDED: committed %, quick-market reserved %, requested %, acknowledged %',
      v_committed,v_qmp_reserved,p_amount,v_acknowledged;
  END IF;

  INSERT INTO public.buyer_custody_expenses(
    company_id,custody_id,employee_id,expense_date,supplier_name,invoice_number,description,
    amount,currency,document_name,document_path,mime_type,supplier_id,purchase_invoice_id,
    receiving_operation_id,receipt_document_name,receipt_document_path,receipt_mime_type,
    operation_id,expense_type
  )
  VALUES(
    p_company_id,p_custody_id,v_actor.id,COALESCE(p_expense_date,current_date),
    NULLIF(btrim(p_supplier_name),''),NULLIF(btrim(p_invoice_number),''),btrim(p_description),
    p_amount,v_currency,btrim(p_document_name),btrim(p_document_path),NULLIF(btrim(p_mime_type),''),
    p_supplier_id,p_purchase_invoice_id,p_receiving_operation_id,
    btrim(p_receipt_document_name),btrim(p_receipt_document_path),NULLIF(btrim(p_receipt_mime_type),''),
    p_operation_id,'PURCHASE_INVOICE'
  )
  RETURNING * INTO v_row;

  UPDATE public.buyer_custodies SET status='UnderReview',updated_at=now()
  WHERE id=p_custody_id AND company_id=p_company_id;

  RETURN to_jsonb(v_row)||jsonb_build_object('duplicate',false,'quick_market_reserved',v_qmp_reserved);
END;
$function$;

CREATE OR REPLACE FUNCTION public.buyer_custody_submit_other_expense_atomic(
  p_company_id uuid,p_custody_id uuid,p_expense_date date,p_expense_category text,
  p_expense_reference text,p_description text,p_amount numeric,p_currency text,
  p_document_name text,p_document_path text,p_mime_type text,p_operation_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_custody public.buyer_custodies%ROWTYPE;
  v_row public.buyer_custody_expenses%ROWTYPE;
  v_currency text;
  v_acknowledged numeric(14,2);
  v_committed numeric(14,2);
  v_qmp_reserved numeric(14,2);
  v_file_size bigint;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;

  SELECT * INTO v_custody
  FROM public.buyer_custodies
  WHERE id=p_custody_id AND company_id=p_company_id AND employee_id=v_actor.id
  FOR UPDATE;
  IF NOT FOUND OR v_custody.status NOT IN ('Issued','UnderReview') THEN RAISE EXCEPTION 'CUSTODY_NOT_OPEN'; END IF;
  IF v_custody.acknowledged_at IS NULL THEN RAISE EXCEPTION 'CUSTODY_NOT_ACKNOWLEDGED'; END IF;

  v_currency:=upper(v_custody.currency);
  IF COALESCE(NULLIF(upper(btrim(p_currency)),''),v_currency)<>v_currency THEN RAISE EXCEPTION 'CUSTODY_CURRENCY_MISMATCH'; END IF;
  IF COALESCE(p_expense_category,'') NOT IN ('TRANSPORTATION','FUEL','TOLLS_PARKING','OTHER')
     OR p_amount IS NULL OR p_amount<=0
     OR NULLIF(btrim(p_description),'') IS NULL
     OR NULLIF(btrim(p_document_name),'') IS NULL
     OR NULLIF(btrim(p_document_path),'') IS NULL
     OR NULLIF(btrim(p_operation_id),'') IS NULL
     OR upper(COALESCE(NULLIF(btrim(p_mime_type),''),'')) NOT IN ('APPLICATION/PDF','IMAGE/JPEG','IMAGE/PNG','IMAGE/WEBP') THEN
    RAISE EXCEPTION 'CUSTODY_OPERATIONAL_EXPENSE_INVALID';
  END IF;

  SELECT * INTO v_row
  FROM public.buyer_custody_expenses
  WHERE company_id=p_company_id AND operation_id=p_operation_id
  FOR UPDATE;
  IF FOUND THEN
    IF v_row.expense_type='OPERATIONAL'
       AND v_row.custody_id=p_custody_id AND v_row.employee_id=v_actor.id
       AND v_row.expense_category=p_expense_category
       AND v_row.expense_reference IS NOT DISTINCT FROM NULLIF(btrim(p_expense_reference),'')
       AND v_row.description=btrim(p_description)
       AND abs(v_row.amount-p_amount)<=0.005
       AND v_row.document_name=p_document_name AND v_row.document_path=p_document_path
       AND upper(COALESCE(v_row.mime_type,''))=upper(COALESCE(p_mime_type,'')) THEN
      RETURN to_jsonb(v_row)||jsonb_build_object('duplicate',true);
    END IF;
    RAISE EXCEPTION 'CUSTODY_OPERATION_ID_CONFLICT';
  END IF;

  IF p_document_path NOT LIKE p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%' THEN
    RAISE EXCEPTION 'CUSTODY_DOCUMENT_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  SELECT CASE WHEN COALESCE(o.metadata->>'size','') ~ '^[0-9]+$'
              THEN (o.metadata->>'size')::bigint ELSE NULL END
  INTO v_file_size
  FROM storage.objects o
  WHERE o.bucket_id='employee-documents'
    AND o.name=p_document_path
    AND lower(COALESCE(o.metadata->>'mimetype',p_mime_type))=lower(p_mime_type);
  IF v_file_size IS NULL OR v_file_size<=0 OR v_file_size>10485760 THEN
    RAISE EXCEPTION 'CUSTODY_DOCUMENT_MISSING_OR_SIZE_INVALID';
  END IF;

  SELECT COALESCE(SUM(a.amount),0) INTO v_acknowledged
  FROM public.buyer_custody_advances a
  WHERE a.company_id=p_company_id AND a.custody_id=p_custody_id AND a.acknowledged_at IS NOT NULL;

  SELECT COALESCE(SUM(e.amount),0) INTO v_committed
  FROM public.buyer_custody_expenses e
  WHERE e.company_id=p_company_id AND e.custody_id=p_custody_id AND e.status IN ('Submitted','Approved');

  SELECT COALESCE(SUM(GREATEST(COALESCE(i.total_amount,0)-COALESCE(i.paid_amount,0)-COALESCE(linked.amount,0),0)),0)
  INTO v_qmp_reserved
  FROM public.purchase_invoices i
  LEFT JOIN LATERAL (
    SELECT SUM(e.amount) amount
    FROM public.buyer_custody_expenses e
    WHERE e.company_id=p_company_id AND e.custody_id=p_custody_id
      AND e.purchase_invoice_id=i.id AND e.status IN ('Submitted','Approved')
  ) linked ON true
  WHERE i.company_id=p_company_id AND i.cash_custody_id=p_custody_id
    AND i.purchase_source='QUICK_MARKET' AND i.settlement_source='EMPLOYEE_CUSTODY'
    AND i.status IN ('Draft','Posted','PartiallyPaid')
    AND i.settlement_status IN ('UNSETTLED','PENDING_FINANCE','AP_OPEN','PARTIALLY_SETTLED');

  IF v_committed+p_amount+v_qmp_reserved>v_acknowledged+0.005 THEN
    RAISE EXCEPTION 'CUSTODY_AVAILABLE_FUNDS_EXCEEDED: committed %, quick-market reserved %, requested %, acknowledged %',
      v_committed,v_qmp_reserved,p_amount,v_acknowledged;
  END IF;

  INSERT INTO public.buyer_custody_expenses(
    company_id,custody_id,employee_id,expense_date,description,amount,currency,
    document_name,document_path,mime_type,operation_id,expense_type,expense_category,expense_reference
  )
  VALUES(
    p_company_id,p_custody_id,v_actor.id,COALESCE(p_expense_date,current_date),
    btrim(p_description),p_amount,v_currency,btrim(p_document_name),btrim(p_document_path),
    lower(btrim(p_mime_type)),p_operation_id,'OPERATIONAL',p_expense_category,NULLIF(btrim(p_expense_reference),'')
  )
  RETURNING * INTO v_row;

  UPDATE public.buyer_custodies SET status='UnderReview',updated_at=now()
  WHERE id=p_custody_id AND company_id=p_company_id;

  RETURN to_jsonb(v_row)||jsonb_build_object('duplicate',false,'quick_market_reserved',v_qmp_reserved);
END;
$function$;

CREATE OR REPLACE FUNCTION public.buyer_custody_review_expense_atomic(
  p_company_id uuid,p_expense_id uuid,p_decision text,p_review_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_expense public.buyer_custody_expenses%ROWTYPE;
  v_row public.buyer_custody_expenses%ROWTYPE;
  v_custody public.buyer_custodies%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_po public.purchase_orders%ROWTYPE;
  v_po_line public.purchase_order_details%ROWTYPE;
  v_invoice_line public.purchase_invoice_details%ROWTYPE;
  v_supplier_account uuid;
  v_custody_account uuid;
  v_balance numeric(14,2);
  v_po_credit numeric(14,2);
  v_previous_invoiced numeric(14,3);
  v_po_invoice_total numeric(14,2):=0;
  v_journal jsonb;
  v_payment_id uuid;
  v_payment_code text;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;
  IF NOT (
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN RAISE EXCEPTION 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; END IF;
  IF COALESCE(p_decision,'') NOT IN ('Approved','Rejected') THEN RAISE EXCEPTION 'CUSTODY_REVIEW_DECISION_INVALID'; END IF;

  SELECT * INTO v_expense
  FROM public.buyer_custody_expenses
  WHERE id=p_expense_id AND company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_expense.status<>'Submitted' THEN RAISE EXCEPTION 'CUSTODY_EXPENSE_NOT_PENDING'; END IF;
  IF v_expense.expense_type<>'PURCHASE_INVOICE' THEN RAISE EXCEPTION 'CUSTODY_EXPENSE_USE_OPERATIONAL_REVIEW'; END IF;
  IF v_expense.employee_id=v_actor.id THEN RAISE EXCEPTION 'CUSTODY_SELF_REVIEW_FORBIDDEN'; END IF;

  IF p_decision='Rejected' THEN
    UPDATE public.buyer_custody_expenses
    SET status='Rejected',reviewed_by=v_actor.id,reviewed_at=now(),review_note=NULLIF(btrim(p_review_note),'')
    WHERE id=p_expense_id AND company_id=p_company_id RETURNING * INTO v_row;
    RETURN to_jsonb(v_row);
  END IF;

  SELECT * INTO v_custody FROM public.buyer_custodies
  WHERE id=v_expense.custody_id AND company_id=p_company_id FOR UPDATE;
  SELECT * INTO v_invoice FROM public.purchase_invoices
  WHERE id=v_expense.purchase_invoice_id AND company_id=p_company_id AND supplier_id=v_expense.supplier_id
  FOR UPDATE;
  IF NOT FOUND OR v_invoice.status<>'Draft' OR abs(COALESCE(v_invoice.total_amount,0)-v_expense.amount)>0.01 THEN
    RAISE EXCEPTION 'CUSTODY_INVOICE_NOT_READY_FOR_PAYMENT';
  END IF;
  IF NULLIF(btrim(v_invoice.supplier_invoice_no),'') IS NOT NULL
     AND NULLIF(btrim(v_expense.invoice_number),'') IS DISTINCT FROM btrim(v_invoice.supplier_invoice_no) THEN
    RAISE EXCEPTION 'CUSTODY_SUPPLIER_INVOICE_NUMBER_MISMATCH';
  END IF;

  SELECT * INTO v_po FROM public.purchase_orders
  WHERE id=v_invoice.purchase_order_id AND company_id=p_company_id AND supplier_id=v_expense.supplier_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_PURCHASE_ORDER_INVALID'; END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.receiving r
    WHERE r.company_id=p_company_id AND r.operation_id=v_expense.receiving_operation_id
      AND r.po_number=v_po.po_code AND r.status IN ('مكتمل','Completed')
  ) OR NOT EXISTS(SELECT 1 FROM public.receiving_details rd WHERE rd.operation_id=v_expense.receiving_operation_id) THEN
    RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_INVALID';
  END IF;

  FOR v_invoice_line IN SELECT * FROM public.purchase_invoice_details WHERE invoice_id=v_invoice.id
  LOOP
    SELECT * INTO v_po_line FROM public.purchase_order_details d
    WHERE d.po_id=v_po.id AND d.item_id=v_invoice_line.item_id AND d.item_code=v_invoice_line.item_code FOR SHARE;
    IF NOT FOUND OR NOT EXISTS(
      SELECT 1 FROM public.receiving_details rd
      WHERE rd.operation_id=v_expense.receiving_operation_id AND rd.item_code=v_invoice_line.item_code
        AND rd.qty_received>=v_invoice_line.qty
    ) THEN RAISE EXCEPTION 'CUSTODY_WAREHOUSE_RECEIPT_ITEMS_MISMATCH:%',v_invoice_line.item_code; END IF;
    IF abs(COALESCE(v_invoice_line.unit_price,0)-COALESCE(v_po_line.unit_price,0))>0.01
       OR COALESCE(v_invoice_line.discount_percent,0)<>0 OR COALESCE(v_invoice_line.tax_rate,0)<>0 THEN
      RAISE EXCEPTION 'CUSTODY_INVOICE_PO_PRICE_OR_TAX_MISMATCH:%',v_invoice_line.item_code;
    END IF;
    SELECT COALESCE(SUM(other_detail.qty),0) INTO v_previous_invoiced
    FROM public.purchase_invoice_details other_detail
    JOIN public.purchase_invoices other_invoice ON other_invoice.id=other_detail.invoice_id
    WHERE other_invoice.company_id=p_company_id AND other_invoice.purchase_order_id=v_po.id
      AND other_invoice.id<>v_invoice.id AND other_invoice.status<>'Cancelled'
      AND other_detail.item_code=v_invoice_line.item_code;
    IF COALESCE(v_po_line.qty_received,0)<COALESCE(v_invoice_line.qty,0)+COALESCE(v_previous_invoiced,0) THEN
      RAISE EXCEPTION 'CUSTODY_INVOICE_QTY_EXCEEDS_RECEIVED:%',v_invoice_line.item_code;
    END IF;
    v_po_invoice_total:=v_po_invoice_total+(v_invoice_line.qty*v_po_line.unit_price);
  END LOOP;

  IF abs(v_po_invoice_total-v_expense.amount)>0.01 OR abs(v_po_invoice_total-v_invoice.total_amount)>0.01 THEN
    RAISE EXCEPTION 'CUSTODY_INVOICE_PO_TOTAL_MISMATCH';
  END IF;

  SELECT COALESCE(SUM(credit-debit),0) INTO v_po_credit
  FROM public.supplier_ledger WHERE supplier_id=v_expense.supplier_id AND reference=v_po.po_code;
  IF v_po_credit+0.005<v_expense.amount THEN RAISE EXCEPTION 'CUSTODY_PO_SUPPLIER_LIABILITY_NOT_POSTED'; END IF;
  SELECT COALESCE(SUM(credit-debit),0) INTO v_balance
  FROM public.supplier_ledger WHERE supplier_id=v_expense.supplier_id;
  IF v_balance+0.005<v_expense.amount THEN RAISE EXCEPTION 'CUSTODY_SUPPLIER_BALANCE_INSUFFICIENT'; END IF;

  SELECT id INTO v_supplier_account FROM public.chart_of_accounts
  WHERE company_id=p_company_id AND account_code='211' AND is_active;
  SELECT id INTO v_custody_account FROM public.chart_of_accounts
  WHERE company_id=p_company_id AND account_code='127' AND is_active;
  IF v_supplier_account IS NULL OR v_custody_account IS NULL THEN RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING'; END IF;

  v_payment_code:='BCP-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  v_journal:=public.post_journal_entry(
    p_company_id,gen_random_uuid(),current_date,'PurchasePayment',v_invoice.invoice_code,
    'سداد فاتورة المورد من عهدة الموظف',v_actor.email,
    jsonb_build_array(
      jsonb_build_object('account_id',v_supplier_account,'debit',v_expense.amount,'credit',0,'notes','سداد مورد من عهدة الموظف'),
      jsonb_build_object('account_id',v_custody_account,'debit',0,'credit',v_expense.amount,'notes','تسوية مصروف عهدة معتمد')
    ),NULL,now(),NULL
  );

  INSERT INTO public.buyer_custody_payments(
    company_id,custody_id,expense_id,purchase_invoice_id,supplier_id,payment_code,
    payment_date,amount,currency,reference,recorded_by,journal_entry_id,operation_id
  ) VALUES(
    p_company_id,v_expense.custody_id,v_expense.id,v_invoice.id,v_expense.supplier_id,
    v_payment_code,current_date,v_expense.amount,v_expense.currency,v_invoice.invoice_code,
    v_actor.id,(v_journal->>'entry_id')::uuid,gen_random_uuid()
  ) RETURNING id INTO v_payment_id;

  UPDATE public.purchase_invoices
  SET paid_amount=total_amount,status='Paid',is_received=true,
      received_date=COALESCE(received_date,current_date),posted_by=v_actor.email,posted_at=now(),updated_at=now()
  WHERE id=v_invoice.id AND company_id=p_company_id;

  INSERT INTO public.supplier_ledger(supplier_id,entry_date,reference,description,debit,credit,balance,user_email)
  VALUES(
    v_expense.supplier_id,current_date,v_invoice.invoice_code,
    'سداد فاتورة من عهدة الموظف - '||v_payment_code,
    v_expense.amount,0,v_balance-v_expense.amount,v_actor.email
  );

  UPDATE public.buyer_custody_expenses
  SET status='Approved',reviewed_by=v_actor.id,reviewed_at=now(),
      review_note=NULLIF(btrim(p_review_note),''),payment_id=v_payment_id,
      journal_entry_id=(v_journal->>'entry_id')::uuid
  WHERE id=p_expense_id AND company_id=p_company_id RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)||jsonb_build_object('payment_code',v_payment_code,'journal_entry_id',v_journal->'entry_id');
END;
$function$;

CREATE OR REPLACE FUNCTION public.buyer_custody_review_other_expense_atomic(
  p_company_id uuid,p_expense_id uuid,p_decision text,p_expense_account_id uuid,p_review_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_expense public.buyer_custody_expenses%ROWTYPE;
  v_custody public.buyer_custodies%ROWTYPE;
  v_row public.buyer_custody_expenses%ROWTYPE;
  v_account public.chart_of_accounts%ROWTYPE;
  v_custody_account uuid;
  v_journal jsonb;
  v_note text;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;
  IF NOT (
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN RAISE EXCEPTION 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; END IF;
  IF p_decision NOT IN ('Approved','Rejected') THEN RAISE EXCEPTION 'CUSTODY_REVIEW_DECISION_INVALID'; END IF;

  SELECT * INTO v_expense
  FROM public.buyer_custody_expenses
  WHERE id=p_expense_id AND company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_EXPENSE_NOT_FOUND'; END IF;
  IF v_expense.expense_type<>'OPERATIONAL' THEN RAISE EXCEPTION 'CUSTODY_EXPENSE_NOT_OPERATIONAL'; END IF;
  IF v_expense.employee_id=v_actor.id THEN RAISE EXCEPTION 'CUSTODY_SELF_REVIEW_FORBIDDEN'; END IF;

  IF v_expense.status='Approved' AND p_decision='Approved'
     AND v_expense.expense_account_id=p_expense_account_id AND v_expense.journal_entry_id IS NOT NULL THEN
    RETURN to_jsonb(v_expense)||jsonb_build_object('duplicate',true);
  END IF;
  IF v_expense.status='Rejected' AND p_decision='Rejected' THEN
    RETURN to_jsonb(v_expense)||jsonb_build_object('duplicate',true);
  END IF;
  IF v_expense.status<>'Submitted' THEN RAISE EXCEPTION 'CUSTODY_EXPENSE_NOT_PENDING'; END IF;

  IF p_decision='Rejected' THEN
    UPDATE public.buyer_custody_expenses
    SET status='Rejected',reviewed_by=v_actor.id,reviewed_at=now(),
        review_note=NULLIF(btrim(p_review_note),'')
    WHERE id=p_expense_id AND company_id=p_company_id
    RETURNING * INTO v_row;
    RETURN to_jsonb(v_row);
  END IF;

  IF p_expense_account_id IS NULL THEN RAISE EXCEPTION 'CUSTODY_OPERATIONAL_EXPENSE_ACCOUNT_REQUIRED'; END IF;
  SELECT * INTO v_account
  FROM public.chart_of_accounts a
  WHERE a.id=p_expense_account_id AND a.company_id=p_company_id AND a.is_active=true;
  IF NOT FOUND OR v_account.account_type IS DISTINCT FROM 'expense'
     OR v_account.account_code IN ('51','52')
     OR EXISTS(
       SELECT 1 FROM public.chart_of_accounts child
       WHERE child.company_id=p_company_id AND child.parent_account_id=v_account.id
     ) THEN
    RAISE EXCEPTION 'CUSTODY_OPERATIONAL_EXPENSE_ACCOUNT_INVALID';
  END IF;

  SELECT * INTO v_custody
  FROM public.buyer_custodies
  WHERE id=v_expense.custody_id AND company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_custody.currency<>v_expense.currency THEN
    RAISE EXCEPTION 'CUSTODY_CURRENCY_MISMATCH';
  END IF;
  SELECT id INTO v_custody_account
  FROM public.chart_of_accounts
  WHERE company_id=p_company_id AND account_code='127' AND is_active=true;
  IF v_custody_account IS NULL THEN RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING'; END IF;

  v_note:=CASE v_expense.expense_category
    WHEN 'TRANSPORTATION' THEN 'انتقالات ومواصلات'
    WHEN 'FUEL' THEN 'وقود'
    WHEN 'TOLLS_PARKING' THEN 'رسوم طرق ومواقف'
    ELSE 'مصروف تشغيلي آخر'
  END||' — '||v_expense.description;

  v_journal:=public.post_journal_entry(
    p_company_id,gen_random_uuid(),v_expense.expense_date,'BuyerCustodyOperationalExpense',
    v_expense.expense_reference,v_note,v_actor.email,
    jsonb_build_array(
      jsonb_build_object('account_id',v_account.id,'debit',v_expense.amount,'credit',0,'notes',v_note),
      jsonb_build_object('account_id',v_custody_account,'debit',0,'credit',v_expense.amount,'notes','تسوية مصروف تشغيلي من عهدة الموظف')
    ),NULL,now(),NULL
  );

  UPDATE public.buyer_custody_expenses
  SET status='Approved',expense_account_id=v_account.id,
      reviewed_by=v_actor.id,reviewed_at=now(),
      review_note=NULLIF(btrim(p_review_note),''),
      journal_entry_id=(v_journal->>'entry_id')::uuid
  WHERE id=p_expense_id AND company_id=p_company_id
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)||jsonb_build_object(
    'duplicate',false,'journal_entry_id',v_journal->'entry_id','expense_account_code',v_account.account_code
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.buyer_custody_settle_atomic(
  p_company_id uuid,p_custody_id uuid,p_treasury_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_custody public.buyer_custodies%ROWTYPE;
  v_employee public.users%ROWTYPE;
  v_approved numeric(14,2);
  v_pending integer;
  v_expected_return numeric(14,2);
  v_unacknowledged integer;
  v_open_qmp integer;
  v_settlement public.buyer_custody_settlements%ROWTYPE;
  v_cash_account uuid;
  v_custody_account uuid;
  v_cash_result jsonb;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;
  IF NOT (
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN RAISE EXCEPTION 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; END IF;
  SELECT * INTO v_custody
  FROM public.buyer_custodies
  WHERE id=p_custody_id AND company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_custody.status NOT IN ('Issued','UnderReview') THEN RAISE EXCEPTION 'CUSTODY_NOT_SETTLEABLE'; END IF;
  IF v_custody.employee_id=v_actor.id THEN RAISE EXCEPTION 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; END IF;
  SELECT * INTO v_employee FROM public.users WHERE id=v_custody.employee_id AND company_id=p_company_id;

  SELECT count(*) INTO v_pending
  FROM public.buyer_custody_expenses
  WHERE custody_id=p_custody_id AND company_id=p_company_id AND status='Submitted';
  IF v_pending>0 THEN RAISE EXCEPTION 'CUSTODY_EXPENSES_PENDING_REVIEW'; END IF;

  SELECT count(*) INTO v_unacknowledged
  FROM public.buyer_custody_advances
  WHERE custody_id=p_custody_id AND company_id=p_company_id AND acknowledged_at IS NULL;
  IF v_unacknowledged>0 THEN RAISE EXCEPTION 'CUSTODY_ADVANCES_NOT_ACKNOWLEDGED'; END IF;

  SELECT count(*) INTO v_open_qmp
  FROM public.purchase_invoices
  WHERE company_id=p_company_id AND cash_custody_id=p_custody_id
    AND purchase_source='QUICK_MARKET' AND settlement_source='EMPLOYEE_CUSTODY'
    AND status IN ('Draft','Posted','PartiallyPaid')
    AND settlement_status IN ('UNSETTLED','PENDING_FINANCE','AP_OPEN','PARTIALLY_SETTLED');
  IF v_open_qmp>0 THEN RAISE EXCEPTION 'CUSTODY_QUICK_MARKET_RESERVATIONS_OPEN:%',v_open_qmp; END IF;

  SELECT COALESCE(SUM(amount),0) INTO v_approved
  FROM public.buyer_custody_expenses
  WHERE custody_id=p_custody_id AND company_id=p_company_id AND status='Approved';

  IF v_approved>v_custody.issued_amount+0.005 THEN
    RAISE EXCEPTION 'CUSTODY_APPROVED_EXPENSES_EXCEED_ISSUED_FUNDS_EMPLOYEE_PAYABLE_NOT_CONFIGURED';
  END IF;
  v_expected_return:=greatest(v_custody.issued_amount-v_approved,0);
  IF COALESCE(p_cash_returned,0)<>v_expected_return THEN RAISE EXCEPTION 'CUSTODY_CASH_RETURN_MUST_RECONCILE'; END IF;

  IF v_expected_return>0 THEN
    IF p_treasury_id IS NULL THEN RAISE EXCEPTION 'CUSTODY_RETURN_TREASURY_REQUIRED'; END IF;
    SELECT id INTO v_cash_account FROM public.chart_of_accounts
    WHERE company_id=p_company_id AND account_code='121' AND is_active;
    SELECT id INTO v_custody_account FROM public.chart_of_accounts
    WHERE company_id=p_company_id AND account_code='127' AND is_active;
    IF v_cash_account IS NULL OR v_custody_account IS NULL THEN RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING'; END IF;
    v_cash_result:=public.post_cash_receipt_atomic(
      p_company_id,gen_random_uuid(),p_treasury_id,v_cash_account,v_custody_account,v_expected_return,
      current_date,COALESCE(NULLIF(btrim(p_finance_reference),''),v_custody.custody_code),
      'رد نقدية متبقية من عهدة مشتريات',v_actor.email,v_employee.name,'BuyerCustodySettlement',
      v_custody.id,NULLIF(btrim(p_notes),''),NULL
    );
  END IF;

  INSERT INTO public.buyer_custody_settlements(
    company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,
    finance_reference,notes,recorded_by,treasury_id,cash_box_id,journal_entry_id
  )
  VALUES(
    p_company_id,p_custody_id,v_approved,v_expected_return,0,0,
    NULLIF(btrim(p_finance_reference),''),NULLIF(btrim(p_notes),''),v_actor.id,p_treasury_id,
    NULLIF(v_cash_result->>'cash_box_id','')::uuid,NULLIF(v_cash_result->>'entry_id','')::uuid
  )
  RETURNING * INTO v_settlement;

  UPDATE public.buyer_custodies SET status='Settled',updated_at=now()
  WHERE id=p_custody_id AND company_id=p_company_id;

  RETURN to_jsonb(v_settlement);
END;
$function$;

REVOKE ALL ON FUNCTION public.buyer_custody_submit_other_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.buyer_custody_submit_other_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,text) TO authenticated,service_role,postgres;

REVOKE ALL ON FUNCTION public.buyer_custody_review_other_expense_atomic(uuid,uuid,text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.buyer_custody_review_other_expense_atomic(uuid,uuid,text,uuid,text) TO authenticated,service_role,postgres;
