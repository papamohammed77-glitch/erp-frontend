-- Rollback-only test for Quick Market handover evidence and virtual custody balance.
-- Creates a synthetic Supplier-Credit draft and storage metadata row inside a
-- nested transaction; all fixture rows/events are rolled back by the sentinel.
DO $buyer_handover_progress_test$
DECLARE
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_auth uuid := 'b0894a25-6a0a-484a-a730-4f64c88e23a4';
  v_actor_id uuid := '7d0f21ed-8952-45c1-b00f-e58c61607d56';
  v_supplier uuid;
  v_branch uuid := 'a38332b6-6cea-480a-ada1-6eb6ab0590db';
  v_item_id uuid;
  v_item_code text;
  v_unit text;
  v_invoice jsonb;
  v_invoice_id uuid;
  v_invoice_line_id uuid;
  v_qty numeric := 2;
  v_handover jsonb;
  v_duplicate jsonb;
  v_progress_before jsonb;
  v_progress_after jsonb;
  v_balances_before jsonb;
  v_balances_after jsonb;
  v_line_before jsonb;
  v_line_after jsonb;
  v_balance_before numeric;
  v_balance_after numeric;
  v_remaining_before numeric;
  v_remaining_after numeric;
  v_handed_before numeric;
  v_handed_after numeric;
  v_operation text := 'QA-LVE735-HANDOVER-'||gen_random_uuid()::text;
  v_invoice_op text := 'QA-LVE735-INVOICE-'||gen_random_uuid()::text;
  v_path text;
  v_before record;
  v_after record;
BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_auth::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_auth::text,'role','authenticated')::text,true);
  IF auth.uid() IS DISTINCT FROM v_auth
     OR NOT app_private.current_user_has_effective_permission('purchases') THEN
    RAISE EXCEPTION 'QA_BUYER_HANDOVER_AUTH_CONTEXT_INVALID';
  END IF;

  BEGIN
    SELECT id INTO v_supplier
    FROM public.suppliers
    WHERE company_id=v_company AND COALESCE(is_active,false)=true
    ORDER BY id LIMIT 1;
    IF v_supplier IS NULL THEN RAISE EXCEPTION 'QA_SUPPLIER_MISSING'; END IF;

    SELECT id,item_code,unit INTO v_item_id,v_item_code,v_unit
    FROM public.items
    WHERE company_id=v_company AND COALESCE(is_active,true)=true
      AND NULLIF(btrim(unit),'') IS NOT NULL
    ORDER BY item_code LIMIT 1;
    IF v_item_id IS NULL THEN RAISE EXCEPTION 'QA_ITEM_MISSING'; END IF;

    SELECT
      (SELECT count(*) FROM public.journal_entries WHERE company_id=v_company) journals,
      COALESCE((SELECT sum(t.current_balance) FROM public.treasury t WHERE t.company_id=v_company),0) treasury,
      (SELECT count(*) FROM public.cash_box WHERE company_id=v_company) cash_vouchers,
      (SELECT count(*) FROM public.inventory_log WHERE company_id=v_company) inventory_logs,
      (SELECT count(*) FROM public.stock_branches) stock_rows,
      COALESCE((SELECT sum(sb.qty) FROM public.stock_branches sb JOIN public.branches br ON br.id=sb.branch_id WHERE br.company_id=v_company),0) stock_qty,
      (SELECT count(*) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company) supplier_ledger_rows,
      (SELECT count(*) FROM public.buyer_goods_custody_events WHERE company_id=v_company) custody_events
    INTO v_before;

    v_invoice:=public.purchase_create_quick_market_invoice_atomic(
      v_company,v_supplier,v_branch,current_date+30,
      'QA-LVE735-'||replace(gen_random_uuid()::text,'-',''),
      'QA LVE735 rollback-only handover evidence test',
      jsonb_build_array(jsonb_build_object(
        'item_code',v_item_code,'unit',v_unit,'qty',v_qty,
        'unit_price',10,'discount_percent',0,'tax_rate',0
      )),
      'SUPPLIER_CREDIT',NULL,v_invoice_op
    );
    IF COALESCE((v_invoice->>'success')::boolean,false)=false
       OR NULLIF(v_invoice->>'id','') IS NULL THEN
      RAISE EXCEPTION 'QA_QMP_DRAFT_CREATE_FAILED:%',v_invoice;
    END IF;
    v_invoice_id:=(v_invoice->>'id')::uuid;

    SELECT id INTO v_invoice_line_id
    FROM public.purchase_invoice_details
    WHERE invoice_id=v_invoice_id AND item_code=v_item_code;
    IF v_invoice_line_id IS NULL THEN RAISE EXCEPTION 'QA_QMP_INVOICE_LINE_MISSING'; END IF;

    v_progress_before:=public.buyer_goods_custody_get_invoice_handover_progress_atomic(v_company,v_invoice_id);
    SELECT value INTO v_line_before
    FROM jsonb_array_elements(v_progress_before->'lines') WHERE value->>'invoice_detail_id'=v_invoice_line_id::text;
    IF v_line_before IS NULL THEN RAISE EXCEPTION 'QA_PROGRESS_LINE_MISSING_BEFORE'; END IF;

    v_handed_before:=COALESCE((v_line_before->>'handed_over_qty')::numeric,-1);
    v_remaining_before:=COALESCE((v_line_before->>'remaining_qty')::numeric,-1);
    IF v_handed_before<>0 OR abs(v_remaining_before-v_qty)>0.0001 THEN
      RAISE EXCEPTION 'QA_PROGRESS_BEFORE_INVALID: handed=% remaining=% expected=%',v_handed_before,v_remaining_before,v_qty;
    END IF;

    v_balances_before:=public.buyer_goods_custody_get_balances_atomic(v_company,v_actor_id);
    SELECT value INTO v_line_before
    FROM jsonb_array_elements(v_balances_before->'balances')
    WHERE value->>'source_document_id'=v_invoice_id::text
      AND value->>'item_id'=v_item_id::text
      AND value->>'custodian_user_id'=v_actor_id::text;
    IF v_line_before IS NULL THEN RAISE EXCEPTION 'QA_VIRTUAL_CUSTODY_BALANCE_MISSING'; END IF;
    v_balance_before:=(v_line_before->>'balance_qty')::numeric;
    IF abs(v_balance_before-v_qty)>0.0001 THEN
      RAISE EXCEPTION 'QA_INITIAL_CUSTODY_PROJECTION_INVALID:%',v_balance_before;
    END IF;

    -- A metadata-only storage object row is sufficient for the RPC contract check;
    -- it is transactionally rolled back and no physical object is uploaded.
    v_path:=v_company::text||'/'||v_actor_id::text||'/buyer-goods/'||v_invoice_id::text||
      '/handover-1799999999000_qa-evidence.pdf';
    INSERT INTO storage.objects(bucket_id,name,owner,owner_id,metadata)
    VALUES('employee-documents',v_path,v_auth,v_auth::text,
      jsonb_build_object('size',256,'mimetype','application/pdf'));

    v_handover:=public.buyer_goods_custody_register_handover_atomic(
      v_company,v_invoice_id,NULL,
      jsonb_build_array(jsonb_build_object('item_code',v_item_code,'qty',v_qty)),
      v_path,'QA إثبات استلام المورد من اختبار LVE735',v_operation
    );
    IF COALESCE((v_handover->>'success')::boolean,false)=false
       OR COALESCE((v_handover->>'event_count')::integer,0)<>1 THEN
      RAISE EXCEPTION 'QA_HANDOVER_REGISTER_FAILED:%',v_handover;
    END IF;

    -- Exact retry must return the same evidence event and not duplicate it.
    v_duplicate:=public.buyer_goods_custody_register_handover_atomic(
      v_company,v_invoice_id,NULL,
      jsonb_build_array(jsonb_build_object('item_code',v_item_code,'qty',v_qty)),
      v_path,'QA إثبات استلام المورد من اختبار LVE735',v_operation
    );
    IF COALESCE((v_duplicate->>'duplicate')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'QA_HANDOVER_IDEMPOTENCY_FAILED:%',v_duplicate;
    END IF;

    v_progress_after:=public.buyer_goods_custody_get_invoice_handover_progress_atomic(v_company,v_invoice_id);
    SELECT value INTO v_line_after
    FROM jsonb_array_elements(v_progress_after->'lines') WHERE value->>'invoice_detail_id'=v_invoice_line_id::text;
    IF v_line_after IS NULL THEN RAISE EXCEPTION 'QA_PROGRESS_LINE_MISSING_AFTER'; END IF;

    v_handed_after:=COALESCE((v_line_after->>'handed_over_qty')::numeric,-1);
    v_remaining_after:=COALESCE((v_line_after->>'remaining_qty')::numeric,-1);
    IF abs(v_handed_after-v_qty)>0.0001 OR abs(v_remaining_after)>0.0001 THEN
      RAISE EXCEPTION 'QA_PROGRESS_AFTER_INVALID: handed=% remaining=%',v_handed_after,v_remaining_after;
    END IF;

    v_balances_after:=public.buyer_goods_custody_get_balances_atomic(v_company,v_actor_id);
    SELECT value INTO v_line_after
    FROM jsonb_array_elements(v_balances_after->'balances')
    WHERE value->>'source_document_id'=v_invoice_id::text
      AND value->>'item_id'=v_item_id::text
      AND value->>'custodian_user_id'=v_actor_id::text;
    IF v_line_after IS NULL THEN RAISE EXCEPTION 'QA_CUSTODY_BALANCE_MISSING_AFTER'; END IF;
    v_balance_after:=(v_line_after->>'balance_qty')::numeric;
    IF abs(v_balance_after-v_balance_before)>0.0001 THEN
      RAISE EXCEPTION 'QA_HANDOVER_CHANGED_NET_CUSTODY_BALANCE: before=% after=%',v_balance_before,v_balance_after;
    END IF;

    SELECT
      (SELECT count(*) FROM public.journal_entries WHERE company_id=v_company) journals,
      COALESCE((SELECT sum(t.current_balance) FROM public.treasury t WHERE t.company_id=v_company),0) treasury,
      (SELECT count(*) FROM public.cash_box WHERE company_id=v_company) cash_vouchers,
      (SELECT count(*) FROM public.inventory_log WHERE company_id=v_company) inventory_logs,
      (SELECT count(*) FROM public.stock_branches) stock_rows,
      COALESCE((SELECT sum(sb.qty) FROM public.stock_branches sb JOIN public.branches br ON br.id=sb.branch_id WHERE br.company_id=v_company),0) stock_qty,
      (SELECT count(*) FROM public.supplier_ledger sl JOIN public.suppliers s ON s.id=sl.supplier_id WHERE s.company_id=v_company) supplier_ledger_rows
    INTO v_after;

    IF v_after.journals<>v_before.journals
       OR v_after.treasury<>v_before.treasury
       OR v_after.cash_vouchers<>v_before.cash_vouchers
       OR v_after.inventory_logs<>v_before.inventory_logs
       OR v_after.stock_rows<>v_before.stock_rows
       OR v_after.stock_qty<>v_before.stock_qty
       OR v_after.supplier_ledger_rows<>v_before.supplier_ledger_rows THEN
      RAISE EXCEPTION 'QA_HANDOVER_CHANGED_STOCK_OR_FINANCIAL_BASELINE';
    END IF;

    -- Event/invoice/storage fixture intentionally rolled back.
    RAISE EXCEPTION USING ERRCODE='PZ002', MESSAGE='QA_LVE735_ROLLED_BACK';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN
    NULL;
  END;
END
$buyer_handover_progress_test$;
