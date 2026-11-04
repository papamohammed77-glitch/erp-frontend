-- REVIEW DRAFT ONLY — DO NOT APPLY WITHOUT OWNER APPROVAL
-- Source: live Production SMART ERP at 2026-11-04; exact existing signatures preserved.
-- 1) Prevent cash-custody settlement while employee-funded Quick Market invoices remain reserved.
CREATE OR REPLACE FUNCTION public.buyer_custody_settle_atomic(p_company_id uuid, p_custody_id uuid, p_treasury_id uuid, p_cash_returned numeric, p_finance_reference text, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_employee public.users%rowtype;
 v_approved numeric(14,2); v_pending integer; v_expected_return numeric(14,2); v_unacknowledged integer; v_open_qmp integer;
 v_settlement public.buyer_custody_settlements%rowtype; v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; end if;
 select * into v_employee from public.users where id=v_custody.employee_id and company_id=p_company_id;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select count(*) into v_unacknowledged from public.buyer_custody_advances where custody_id=p_custody_id and company_id=p_company_id and acknowledged_at is null;
 if v_unacknowledged>0 then raise exception 'CUSTODY_ADVANCES_NOT_ACKNOWLEDGED'; end if;
 select count(*) into v_open_qmp
 from public.purchase_invoices
 where company_id=p_company_id
   and cash_custody_id=p_custody_id
   and purchase_source='QUICK_MARKET'
   and settlement_source='EMPLOYEE_CUSTODY'
   and status in ('Draft','Posted','PartiallyPaid')
   and settlement_status in ('UNSETTLED','PENDING_FINANCE','AP_OPEN','PARTIALLY_SETTLED');
 if v_open_qmp>0 then
   raise exception 'CUSTODY_QUICK_MARKET_RESERVATIONS_OPEN:%',v_open_qmp;
 end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 v_expected_return:=greatest(v_custody.issued_amount-v_approved,0);
 if coalesce(p_cash_returned,0)<>v_expected_return then raise exception 'CUSTODY_CASH_RETURN_MUST_RECONCILE'; end if;
 if v_expected_return>0 then
  if p_treasury_id is null then raise exception 'CUSTODY_RETURN_TREASURY_REQUIRED'; end if;
  select id into v_cash_account from public.chart_of_accounts where company_id=p_company_id and account_code='121' and is_active;
  select id into v_custody_account from public.chart_of_accounts where company_id=p_company_id and account_code='127' and is_active;
  if v_cash_account is null or v_custody_account is null then raise exception 'CUSTODY_ACCOUNT_MAPPING_MISSING'; end if;
  v_cash_result:=public.post_cash_receipt_atomic(p_company_id,gen_random_uuid(),p_treasury_id,v_cash_account,v_custody_account,v_expected_return,
   current_date,coalesce(nullif(btrim(p_finance_reference),''),v_custody.custody_code),'رد نقدية متبقية من عهدة مشتريات',
   v_actor.email,v_employee.name,'BuyerCustodySettlement',v_custody.id,nullif(btrim(p_notes),''),null);
 end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by,treasury_id,cash_box_id,journal_entry_id)
 values(p_company_id,p_custody_id,v_approved,v_expected_return,greatest(v_approved-v_custody.issued_amount,0),0,
 nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_treasury_id,
 nullif(v_cash_result->>'cash_box_id','')::uuid,nullif(v_cash_result->>'entry_id','')::uuid)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;
$function$
;

-- 2) Require the exact uploaded private evidence object before recording Supplier→Buyer custody.
CREATE OR REPLACE FUNCTION public.buyer_goods_custody_register_handover_atomic(p_company_id uuid, p_invoice_id uuid, p_vehicle_id uuid, p_items jsonb, p_evidence_path text, p_notes text, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_detail public.purchase_invoice_details%ROWTYPE;
  v_item jsonb;
  v_qty numeric(14,4);
  v_already numeric(14,4);
  v_fingerprint text;
  v_existing_count integer;
  v_inserted integer:=0;
  v_event_id uuid;
  v_events jsonb:='[]'::jsonb;
BEGIN
  SELECT * INTO v_actor FROM public.users
  WHERE auth_id=auth.uid() AND company_id=p_company_id AND COALESCE(status,'Active')='Active';
  IF NOT FOUND OR NOT app_private.current_user_has_effective_permission('purchases') THEN
    RAISE EXCEPTION 'BUYER_PURCHASE_PERMISSION_REQUIRED';
  END IF;

  IF NULLIF(btrim(p_evidence_path),'') IS NULL THEN
    RAISE EXCEPTION 'BUYER_GOODS_EVIDENCE_REQUIRED';
  END IF;

  IF split_part(p_evidence_path,'/',1) <> p_company_id::text
     OR split_part(p_evidence_path,'/',2) <> v_actor.id::text
     OR split_part(p_evidence_path,'/',3) <> 'buyer-goods'
     OR split_part(p_evidence_path,'/',4) <> p_invoice_id::text THEN
    RAISE EXCEPTION 'BUYER_GOODS_EVIDENCE_PATH_INVALID';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id='employee-documents'
      AND o.name=p_evidence_path
  ) THEN
    RAISE EXCEPTION 'BUYER_GOODS_EVIDENCE_OBJECT_NOT_FOUND';
  END IF;

  IF NULLIF(btrim(p_operation_id),'') IS NULL THEN RAISE EXCEPTION 'BUYER_GOODS_OPERATION_ID_REQUIRED'; END IF;
  IF COALESCE(jsonb_typeof(p_items),'')<>'array' THEN
    RAISE EXCEPTION 'BUYER_GOODS_ITEMS_MUST_BE_ARRAY';
  END IF;
  IF jsonb_array_length(p_items)<1 THEN
    RAISE EXCEPTION 'BUYER_GOODS_ITEMS_REQUIRED';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('RAWAEA:BUYER-GOODS:'||p_company_id::text||':'||btrim(p_operation_id),0)
  );

  SELECT * INTO v_invoice FROM public.purchase_invoices
  WHERE id=p_invoice_id AND company_id=p_company_id FOR UPDATE;

  IF NOT FOUND OR v_invoice.purchase_source<>'QUICK_MARKET'
     OR v_invoice.purchaser_user_id<>v_actor.id
     OR v_invoice.status<>'Draft'
     OR COALESCE(v_invoice.is_received,false)
     OR v_invoice.received_date IS NOT NULL
     OR v_invoice.branch_id IS NULL
     OR NULLIF(btrim(v_invoice.supplier_invoice_no),'') IS NULL THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_ELIGIBLE_FOR_HANDOVER';
  END IF;

  IF p_vehicle_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.vehicles
    WHERE id=p_vehicle_id AND company_id=p_company_id AND COALESCE(status,'Active')='Active'
  ) THEN
    RAISE EXCEPTION 'BUYER_GOODS_VEHICLE_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text,qty numeric)
    GROUP BY btrim(item_code) HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'BUYER_GOODS_DUPLICATE_ITEM';
  END IF;

  v_fingerprint:=md5(jsonb_build_object(
    'invoice_id',p_invoice_id,'vehicle_id',p_vehicle_id,
    'items',p_items,'evidence_path',p_evidence_path,'notes',p_notes
  )::text);

  SELECT count(*) INTO v_existing_count
  FROM public.buyer_goods_custody_events
  WHERE company_id=p_company_id AND operation_id=p_operation_id;

  IF v_existing_count>0 THEN
    IF EXISTS (
      SELECT 1 FROM public.buyer_goods_custody_events
      WHERE company_id=p_company_id AND operation_id=p_operation_id
        AND payload_fingerprint IS DISTINCT FROM v_fingerprint
    ) THEN
      RAISE EXCEPTION 'BUYER_GOODS_OPERATION_ID_PAYLOAD_CONFLICT';
    END IF;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',id,'item_id',item_id,'qty_delta',qty_delta,'event_type',event_type
    ) ORDER BY created_at),'[]'::jsonb)
    INTO v_events
    FROM public.buyer_goods_custody_events
    WHERE company_id=p_company_id AND operation_id=p_operation_id;

    RETURN jsonb_build_object('success',true,'duplicate',true,'invoice_id',p_invoice_id,'events',v_events);
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_qty:=NULLIF(btrim(v_item->>'qty'),'')::numeric;
    IF v_qty IS NULL OR v_qty<=0 THEN
      RAISE EXCEPTION 'BUYER_GOODS_QTY_INVALID:%',v_item->>'item_code';
    END IF;

    SELECT * INTO v_detail
    FROM public.purchase_invoice_details
    WHERE invoice_id=p_invoice_id AND item_code=btrim(v_item->>'item_code')
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'BUYER_GOODS_ITEM_NOT_IN_INVOICE:%',v_item->>'item_code'; END IF;

    SELECT COALESCE(SUM(qty_delta),0) INTO v_already
    FROM public.buyer_goods_custody_events
    WHERE company_id=p_company_id
      AND source_document_type='PurchaseInvoice'
      AND source_document_id=p_invoice_id
      AND source_line_id=v_detail.id
      AND event_type='SUPPLIER_TO_BUYER_QUICK_MARKET';

    IF v_already+v_qty>v_detail.qty+0.0001 THEN
      RAISE EXCEPTION 'BUYER_GOODS_HANDOVER_EXCEEDS_INVOICE_QTY:%',v_detail.item_code;
    END IF;

    INSERT INTO public.buyer_goods_custody_events(
      company_id,branch_id,custodian_user_id,item_id,vehicle_id,event_type,qty_delta,
      source_document_type,source_document_id,source_line_id,operation_id,payload_fingerprint,
      evidence_path,actor_user_id,notes
    )
    VALUES(
      p_company_id,v_invoice.branch_id,v_actor.id,v_detail.item_id,p_vehicle_id,'SUPPLIER_TO_BUYER_QUICK_MARKET',v_qty,
      'PurchaseInvoice',p_invoice_id,v_detail.id,p_operation_id,v_fingerprint,
      NULLIF(btrim(p_evidence_path),''),v_actor.id,NULLIF(btrim(p_notes),'')
    )
    RETURNING id INTO v_event_id;

    v_inserted:=v_inserted+1;
  END LOOP;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',id,'item_id',item_id,'qty_delta',qty_delta,'event_type',event_type
  ) ORDER BY created_at),'[]'::jsonb)
  INTO v_events
  FROM public.buyer_goods_custody_events
  WHERE company_id=p_company_id AND operation_id=p_operation_id;

  RETURN jsonb_build_object(
    'success',true,'duplicate',false,'invoice_id',p_invoice_id,
    'event_count',v_inserted,'events',v_events,
    'warehouse_stock_changed',false,'supplier_balance_changed',false
  );
END;
$function$
;

-- 3) Defense-in-depth: prohibit generic draft deletion after any goods-custody event.
CREATE OR REPLACE FUNCTION public.purchase_delete_draft_invoice_atomic(p_company_id uuid, p_invoice_id uuid, p_actor text, p_reason text, p_operation_id text)
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

  IF EXISTS (
    SELECT 1 FROM public.buyer_goods_custody_events e
    WHERE e.company_id=p_company_id
      AND e.source_document_type='PurchaseInvoice'
      AND e.source_document_id=p_invoice_id
  ) THEN
    RAISE EXCEPTION 'INVOICE_HAS_GOODS_CUSTODY_EVENTS';
  END IF;

  IF v_invoice.status <> 'Draft'
     OR COALESCE(v_invoice.is_received, false)
     OR COALESCE(v_invoice.paid_amount, 0) <> 0
     OR v_invoice.received_date IS NOT NULL
     OR v_invoice.posted_at IS NOT NULL THEN
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
$function$
;
