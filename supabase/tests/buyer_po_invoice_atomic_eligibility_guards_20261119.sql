-- Transactional QA for buyer PO invoice guards.
-- All fixture rows and history are enclosed in an exception subtransaction and rolled back.
DO $buyer_po_invoice_guard_test$
DECLARE
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_auth uuid := '0a6089e6-0c33-4cf9-9aa0-31fc42774b89';
  v_supplier uuid;
  v_branch uuid;
  v_item_id uuid;
  v_item_code text;
  v_item_unit text;
  v_other_code text;
  v_po1 jsonb;
  v_po2 jsonb;
  v_po3 jsonb;
  v_invoice jsonb;
  v_updated jsonb;
  v_po1_id uuid;
  v_po2_id uuid;
  v_po3_id uuid;
  v_invoice_id uuid;
  v_operation text;
  v_invoice_no text;
  v_wrong_invoice_id uuid := 'd5aa7330-0033-4e0e-8b31-733000000001';
  v_received record;
  v_before record;
  v_after record;
  v_items jsonb;
  v_wrong_items jsonb;
  v_over_items jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_auth::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_auth::text,'role','authenticated')::text,true);
  IF auth.uid() IS DISTINCT FROM v_auth
     OR NOT app_private.current_user_has_effective_permission('purchases') THEN
    RAISE EXCEPTION 'QA_BUYER_PO_AUTH_CONTEXT_INVALID';
  END IF;

  -- All committed-style fixture work is intentionally rolled back below.
  BEGIN
    SELECT id INTO v_supplier
    FROM public.suppliers
    WHERE company_id=v_company AND COALESCE(is_active,false)=true
    ORDER BY id LIMIT 1;
    IF v_supplier IS NULL THEN RAISE EXCEPTION 'QA_SUPPLIER_MISSING'; END IF;

    SELECT id INTO v_branch
    FROM public.branches
    WHERE company_id=v_company AND COALESCE(is_active,true)=true
    ORDER BY id LIMIT 1;
    IF v_branch IS NULL THEN RAISE EXCEPTION 'QA_BRANCH_MISSING'; END IF;

    SELECT id,item_code,unit INTO v_item_id,v_item_code,v_item_unit
    FROM public.items
    WHERE company_id=v_company AND COALESCE(is_active,true)=true
    ORDER BY item_code LIMIT 1;
    IF v_item_id IS NULL THEN RAISE EXCEPTION 'QA_ITEM_MISSING'; END IF;

    SELECT item_code INTO v_other_code
    FROM public.items
    WHERE company_id=v_company AND COALESCE(is_active,true)=true AND id<>v_item_id
    ORDER BY item_code LIMIT 1;
    IF v_other_code IS NULL THEN RAISE EXCEPTION 'QA_SECOND_ITEM_MISSING'; END IF;

    SELECT p.supplier_id,p.branch_id,d.item_code,d.unit,d.unit_price
      INTO v_received
    FROM public.purchase_orders p
    JOIN public.purchase_order_details d ON d.po_id=p.id
    WHERE p.id='967e9cfa-01c7-42ac-90c7-dad16b3b4de3'
      AND p.status='Approved' AND COALESCE(d.qty_received,0)>0
    ORDER BY d.item_code LIMIT 1;
    IF v_received.item_code IS NULL THEN RAISE EXCEPTION 'QA_RECEIVED_APPROVED_PO_NOT_FOUND'; END IF;

    SELECT
      COALESCE((SELECT SUM(sb.qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) stock_qty,
      COALESCE((SELECT SUM(sb.allocated_qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) allocated_qty,
      COALESCE((SELECT SUM(sb.available_qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) available_qty,
      (SELECT count(*) FROM public.journal_entries je WHERE je.company_id=v_company) journal_count,
      COALESCE((SELECT SUM(jl.debit) FROM public.journal_entries je JOIN public.journal_lines jl ON jl.entry_id=je.id WHERE je.company_id=v_company),0) journal_debit,
      COALESCE((SELECT SUM(jl.credit) FROM public.journal_entries je JOIN public.journal_lines jl ON jl.entry_id=je.id WHERE je.company_id=v_company),0) journal_credit,
      (SELECT count(*) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company) supplier_ledger_count,
      COALESCE((SELECT SUM(sl.debit) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company),0) supplier_debit,
      COALESCE((SELECT SUM(sl.credit) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company),0) supplier_credit,
      COALESCE((SELECT SUM(t.current_balance) FROM public.treasury t WHERE t.company_id=v_company),0) treasury_balance,
      (SELECT count(*) FROM public.cash_box WHERE company_id=v_company) cash_box_count,
      COALESCE((SELECT SUM(amount) FROM public.cash_box WHERE company_id=v_company),0) cash_box_amount,
      (SELECT count(*) FROM public.inventory_log WHERE company_id=v_company) inventory_log_count,
      (SELECT count(*) FROM public.buyer_goods_custody_events WHERE company_id=v_company) custody_event_count
    INTO v_before;

    v_operation:='QA-LVE734-PO-'||gen_random_uuid()::text;
    v_items:=jsonb_build_array(jsonb_build_object(
      'item_code',v_item_code,'unit',v_item_unit,'qty',5,
      'unit_price',123.45,'discount_percent',0,'tax_rate',0
    ));
    v_wrong_items:=jsonb_build_array(jsonb_build_object(
      'item_code',v_other_code,'unit',v_item_unit,'qty',1,
      'unit_price',123.45,'discount_percent',0,'tax_rate',0
    ));
    v_over_items:=jsonb_build_array(jsonb_build_object(
      'item_code',v_item_code,'unit',v_item_unit,'qty',5.0001,
      'unit_price',123.45,'discount_percent',0,'tax_rate',0
    ));

    -- PO -> Approval -> Buyer Draft creation; no receipt/posting is executed.
    v_po1:=public.purchase_create_po_atomic(
      v_company,v_supplier,v_branch,current_date+7,NULL,'QA-LVE734 valid create',
      jsonb_build_array(jsonb_build_object('item_code',v_item_code,'qty',5,'unit_price',123.45)),
      'QA-LVE734-PO-'||gen_random_uuid()::text
    );
    v_po1_id:=(v_po1->>'id')::uuid;
    PERFORM public.purchase_approve_po_atomic(v_po1_id);

    v_invoice_no:='QA-LVE734-'||gen_random_uuid()::text;
    v_invoice:=public.purchase_create_po_invoice_atomic(
      v_company,v_supplier,v_po1_id,v_branch,current_date+30,v_invoice_no,
      'QA-LVE734 transactional rollback only',v_items,v_operation
    );
    IF COALESCE((v_invoice->>'success')::boolean,false)=false
       OR v_invoice->>'status'<>'Draft'
       OR NULLIF(v_invoice->>'id','') IS NULL THEN
      RAISE EXCEPTION 'QA_VALID_PO_INVOICE_DRAFT_CREATE_FAILED:%',v_invoice;
    END IF;
    v_invoice_id:=(v_invoice->>'id')::uuid;

    IF NOT EXISTS (
      SELECT 1 FROM public.purchase_invoices
      WHERE id=v_invoice_id AND company_id=v_company AND status='Draft'
        AND purchase_source='PURCHASE_ORDER' AND settlement_source='SUPPLIER_CREDIT'
        AND COALESCE(paid_amount,0)=0 AND NOT COALESCE(is_received,false)
    ) THEN
      RAISE EXCEPTION 'QA_INVOICE_DRAFT_STATE_INVALID';
    END IF;

    -- Exact retry must return the same Draft, not create a second one.
    v_updated:=public.purchase_create_po_invoice_atomic(
      v_company,v_supplier,v_po1_id,v_branch,current_date+30,v_invoice_no,
      'QA-LVE734 transactional rollback only',v_items,v_operation
    );
    IF COALESCE((v_updated->>'duplicate')::boolean,false) IS NOT TRUE
       OR (v_updated->>'id')::uuid IS DISTINCT FROM v_invoice_id THEN
      RAISE EXCEPTION 'QA_CREATE_IDEMPOTENCY_FAILED:%',v_updated;
    END IF;

    -- Update the original Draft on the same PO remains supported.
    v_updated:=public.purchase_update_po_invoice_atomic(
      v_company,v_invoice_id,v_supplier,v_po1_id,v_branch,current_date+30,
      v_invoice_no,'QA-LVE734 update',v_items,'QA-LVE734-UPD-'||gen_random_uuid()::text
    );
    IF COALESCE((v_updated->>'success')::boolean,false)=false
       OR v_updated->>'status'<>'Draft' THEN
      RAISE EXCEPTION 'QA_VALID_PO_INVOICE_DRAFT_UPDATE_FAILED:%',v_updated;
    END IF;

    -- Non-PO item is rejected by CREATE and UPDATE server-side.
    BEGIN
      PERFORM public.purchase_create_po_invoice_atomic(
        v_company,v_supplier,v_po1_id,v_branch,current_date+30,
        'QA-LVE734-WRONG-'||gen_random_uuid()::text,'QA wrong item',v_wrong_items,
        'QA-LVE734-WRONG-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_CREATE_ITEM_MEMBERSHIP_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'BUYER_PO_INVOICE_ITEM_NOT_IN_PO:%' THEN RAISE; END IF;
    END;

    BEGIN
      PERFORM public.purchase_update_po_invoice_atomic(
        v_company,v_invoice_id,v_supplier,v_po1_id,v_branch,current_date+30,
        v_invoice_no,'QA wrong update item',v_wrong_items,
        'QA-LVE734-UPD-WRONG-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_UPDATE_ITEM_MEMBERSHIP_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'BUYER_PO_INVOICE_ITEM_NOT_IN_PO:%' THEN RAISE; END IF;
    END;

    -- Over-invoicing is rejected on both create and update.
    BEGIN
      PERFORM public.purchase_create_po_invoice_atomic(
        v_company,v_supplier,v_po1_id,v_branch,current_date+30,
        'QA-LVE734-OVER-'||gen_random_uuid()::text,'QA over qty',v_over_items,
        'QA-LVE734-OVER-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_CREATE_OVERINVOICE_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'BUYER_PO_INVOICE_QTY_EXCEEDS_UNINVOICED_ORDERED:%' THEN RAISE; END IF;
    END;

    BEGIN
      PERFORM public.purchase_update_po_invoice_atomic(
        v_company,v_invoice_id,v_supplier,v_po1_id,v_branch,current_date+30,
        v_invoice_no,'QA over update qty',v_over_items,
        'QA-LVE734-UPD-OVER-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_UPDATE_OVERINVOICE_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'BUYER_PO_INVOICE_QTY_EXCEEDS_UNINVOICED_ORDERED:%' THEN RAISE; END IF;
    END;

    -- Price deviation is rejected server-side for a new PO invoice draft.
    v_po2:=public.purchase_create_po_atomic(
      v_company,v_supplier,v_branch,current_date+7,NULL,'QA-LVE734 price guard',
      jsonb_build_array(jsonb_build_object('item_code',v_item_code,'qty',5,'unit_price',123.45)),
      'QA-LVE734-PO2-'||gen_random_uuid()::text
    );
    v_po2_id:=(v_po2->>'id')::uuid;
    PERFORM public.purchase_approve_po_atomic(v_po2_id);
    BEGIN
      PERFORM public.purchase_create_po_invoice_atomic(
        v_company,v_supplier,v_po2_id,v_branch,current_date+30,
        'QA-LVE734-PRICE-'||gen_random_uuid()::text,'QA price deviation',
        jsonb_build_array(jsonb_build_object(
          'item_code',v_item_code,'unit',v_item_unit,'qty',1,
          'unit_price',99,'discount_percent',0,'tax_rate',0
        )),
        'QA-LVE734-PRICE-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_PRICE_MISMATCH_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE 'BUYER_PO_INVOICE_PRICE_MISMATCH:%' THEN RAISE; END IF;
    END;

    -- Draft (unapproved) PO must not accept a new Buyer invoice draft.
    v_po3:=public.purchase_create_po_atomic(
      v_company,v_supplier,v_branch,current_date+7,NULL,'QA-LVE734 approval guard',
      jsonb_build_array(jsonb_build_object('item_code',v_item_code,'qty',5,'unit_price',123.45)),
      'QA-LVE734-PO3-'||gen_random_uuid()::text
    );
    v_po3_id:=(v_po3->>'id')::uuid;
    BEGIN
      PERFORM public.purchase_create_po_invoice_atomic(
        v_company,v_supplier,v_po3_id,v_branch,current_date+30,
        'QA-LVE734-DRAFT-'||gen_random_uuid()::text,'QA unapproved PO',
        v_items,'QA-LVE734-DRAFT-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_UNAPPROVED_PO_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'BUYER_PO_INVOICE_REQUIRES_APPROVED_PO' THEN RAISE; END IF;
    END;

    -- Approved but already received PO must not accept a new Buyer invoice draft.
    BEGIN
      PERFORM public.purchase_create_po_invoice_atomic(
        v_company,v_received.supplier_id,
        '967e9cfa-01c7-42ac-90c7-dad16b3b4de3'::uuid,
        v_received.branch_id,current_date+30,
        'QA-LVE734-RECEIVED-'||gen_random_uuid()::text,'QA received PO',
        jsonb_build_array(jsonb_build_object(
          'item_code',v_received.item_code,'unit',v_received.unit,
          'qty',1,'unit_price',v_received.unit_price,'discount_percent',0,'tax_rate',0
        )),
        'QA-LVE734-RECEIVED-'||gen_random_uuid()::text
      );
      RAISE EXCEPTION 'QA_EXPECTED_RECEIVED_PO_REJECTION_MISSING';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM<>'BUYER_PO_INVOICE_REQUIRES_PO_WITHOUT_RECEIPT' THEN RAISE; END IF;
    END;

    -- Draft create/update must not touch stock, journals, supplier ledger, Treasury, cash-box or custody.
    SELECT
      COALESCE((SELECT SUM(sb.qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) stock_qty,
      COALESCE((SELECT SUM(sb.allocated_qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) allocated_qty,
      COALESCE((SELECT SUM(sb.available_qty) FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id WHERE b.company_id=v_company),0) available_qty,
      (SELECT count(*) FROM public.journal_entries je WHERE je.company_id=v_company) journal_count,
      COALESCE((SELECT SUM(jl.debit) FROM public.journal_entries je JOIN public.journal_lines jl ON jl.entry_id=je.id WHERE je.company_id=v_company),0) journal_debit,
      COALESCE((SELECT SUM(jl.credit) FROM public.journal_entries je JOIN public.journal_lines jl ON jl.entry_id=je.id WHERE je.company_id=v_company),0) journal_credit,
      (SELECT count(*) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company) supplier_ledger_count,
      COALESCE((SELECT SUM(sl.debit) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company),0) supplier_debit,
      COALESCE((SELECT SUM(sl.credit) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company),0) supplier_credit,
      COALESCE((SELECT SUM(t.current_balance) FROM public.treasury t WHERE t.company_id=v_company),0) treasury_balance,
      (SELECT count(*) FROM public.cash_box WHERE company_id=v_company) cash_box_count,
      COALESCE((SELECT SUM(amount) FROM public.cash_box WHERE company_id=v_company),0) cash_box_amount,
      (SELECT count(*) FROM public.inventory_log WHERE company_id=v_company) inventory_log_count,
      (SELECT count(*) FROM public.buyer_goods_custody_events WHERE company_id=v_company) custody_event_count
    INTO v_after;

    IF v_after IS DISTINCT FROM v_before THEN
      RAISE EXCEPTION 'QA_DRAFT_FLOW_CHANGED_STOCK_OR_FINANCE_BASELINE';
    END IF;

    -- Explicit sentinel rolls back PO, invoices, details, status history, operation registry and audit.
    RAISE EXCEPTION USING ERRCODE='PZ001', MESSAGE='QA_LVE734_ROLLED_BACK';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN
    NULL;
  END;
END
$buyer_po_invoice_guard_test$;
