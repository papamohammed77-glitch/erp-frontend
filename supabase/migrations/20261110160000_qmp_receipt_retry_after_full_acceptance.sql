-- Preserve idempotent retry when a previous full Quick Market receipt committed
-- but the client lost the HTTP response. User/permission/branch gates remain before this.
CREATE OR REPLACE FUNCTION public.receive_quick_market_purchase_atomic(p_company_id uuid, p_invoice_id uuid, p_user_email text, p_items jsonb, p_operation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_detail public.purchase_invoice_details%ROWTYPE;
  v_item public.items%ROWTYPE;
  v_input record;
  v_branch_code text;
  v_branch_allowed boolean:=false;
  v_owner boolean:=false;
  v_allowed_value text;
  v_operation text;
  v_fingerprint text;
  v_existing public.receiving%ROWTYPE;
  v_existing_fp text;
  v_balance numeric(14,4);
  v_total_value numeric(14,2):=0;
  v_total_qty numeric(14,4):=0;
  v_all_received boolean:=true;
  v_stock_result jsonb;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND COALESCE(c.is_active,true)) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط';
  END IF;
  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id AND lower(u.email)=lower(COALESCE(p_user_email,''))
    AND COALESCE(u.status,'Active')='Active'
  FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو غير نشط'; END IF;

  v_owner:=EXISTS(SELECT 1 FROM auth.users au
      JOIN public.owner_profile op ON op.auth_user_id=au.id
      WHERE au.id=v_actor.auth_id
        AND COALESCE(au.raw_user_meta_data->>'isOwner','false')='true'
        AND jsonb_typeof(v_actor.permissions)='array'
        AND v_actor.permissions ? '*');
  IF NOT v_owner AND NOT (
    v_actor.active_warehouse_role='استلام'
    AND (public.hr_user_has_permission(v_actor.id,'warehouse')
      OR public.hr_user_has_permission(v_actor.id,'receiving'))
  ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية استلام فواتير السوق السريع';
  END IF;
  IF p_operation_id IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لاستلام فاتورة السوق'; END IF;
  IF p_invoice_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array'
     OR jsonb_array_length(p_items)=0 THEN
    RAISE EXCEPTION 'بيانات استلام فاتورة السوق غير مكتملة';
  END IF;

  SELECT * INTO v_invoice
  FROM public.purchase_invoices i
  WHERE i.id=p_invoice_id AND i.company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_invoice.purchase_source<>'QUICK_MARKET'
     OR v_invoice.settlement_source<>'EMPLOYEE_CUSTODY'
     OR v_invoice.cash_custody_id IS NULL
     OR v_invoice.branch_id IS NULL THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_FOUND_OR_INVALID_SOURCE';
  END IF;

  SELECT b.branch_code INTO v_branch_code
  FROM public.branches b
  WHERE b.id=v_invoice.branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true);
  IF NOT FOUND THEN RAISE EXCEPTION 'فرع استلام فاتورة السوق غير صالح'; END IF;

  v_branch_allowed:=v_owner OR v_actor.default_branch_id=v_invoice.branch_id;
  IF NOT v_owner THEN
    IF jsonb_typeof(v_actor.allowed_branch_ids)='array' THEN
      v_branch_allowed:=v_branch_allowed
        OR v_actor.allowed_branch_ids ? '*'
        OR v_actor.allowed_branch_ids ? v_invoice.branch_id::text
        OR v_actor.allowed_branch_ids ? COALESCE(v_branch_code,'');
    ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string' THEN
      v_allowed_value:=v_actor.allowed_branch_ids #>> '{}';
      v_branch_allowed:=v_branch_allowed OR v_allowed_value IN ('*',v_invoice.branch_id::text,v_branch_code);
    END IF;
  END IF;
  IF NOT v_branch_allowed THEN RAISE EXCEPTION 'لا تملك صلاحية الاستلام في فرع فاتورة السوق'; END IF;

  IF EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric)
    GROUP BY btrim(item_code) HAVING count(*)>1
  ) THEN RAISE EXCEPTION 'لا يجوز تكرار الصنف داخل استلام الفاتورة'; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text,sent_qty numeric,received_qty numeric)
    WHERE COALESCE(x.sent_qty,x.received_qty,0)>0
  ) THEN RAISE EXCEPTION 'يجب تسجيل كمية مرسلة موجبة واحدة على الأقل'; END IF;

  v_operation:='QMP-RECEIVE:'||p_company_id::text||':'||p_invoice_id::text||':'||p_operation_id::text;
  SELECT md5(COALESCE(string_agg(
    btrim(x.item_code)||':'||COALESCE(x.sent_qty,x.received_qty,0)::text||':'||
    COALESCE(x.received_qty,0)::text||':'||COALESCE(NULLIF(btrim(x.reason),''),''),
    '|' ORDER BY btrim(x.item_code)
  ),''))
  INTO v_fingerprint
  FROM jsonb_to_recordset(p_items)
    x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  WHERE COALESCE(x.sent_qty,x.received_qty,0)>0;

  SELECT * INTO v_existing
  FROM public.receiving r
  WHERE r.company_id=p_company_id AND r.operation_id=v_operation
  FOR UPDATE;
  IF FOUND THEN
    IF v_existing.purchase_invoice_id IS DISTINCT FROM p_invoice_id
       OR v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'QMP_RECEIVE_OPERATION_ID_CONFLICT';
    END IF;
    RETURN jsonb_build_object('success',true,'duplicate',true,'invoice_id',p_invoice_id,
      'invoice_code',v_invoice.invoice_code,'operation_id',v_operation,'status',v_invoice.receipt_status);
  END IF;

  IF v_invoice.status NOT IN ('Draft','PartiallyPaid')
     OR COALESCE(v_invoice.is_received,false)
     OR v_invoice.received_date IS NOT NULL THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_RECEIVABLE';
  END IF;

  FOR v_input IN
    SELECT * FROM jsonb_to_recordset(p_items)
      x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    IF NULLIF(btrim(v_input.item_code),'') IS NULL
       OR v_input.received_qty IS NULL
       OR COALESCE(v_input.sent_qty,v_input.received_qty) IS NULL
       OR v_input.received_qty::text IN ('NaN','Infinity','-Infinity')
       OR COALESCE(v_input.sent_qty,v_input.received_qty)::text IN ('NaN','Infinity','-Infinity') THEN
      RAISE EXCEPTION 'بيانات الصنف وكميتا الشحنة والاستلام غير صالحة';
    END IF;
    IF COALESCE(v_input.sent_qty,v_input.received_qty)<=0
       OR v_input.received_qty<0
       OR v_input.received_qty>COALESCE(v_input.sent_qty,v_input.received_qty)
       OR round(COALESCE(v_input.sent_qty,v_input.received_qty),4)<>COALESCE(v_input.sent_qty,v_input.received_qty)
       OR round(v_input.received_qty,4)<>v_input.received_qty THEN
      RAISE EXCEPTION 'كميات الشحنة والاستلام غير صالحة للصنف: %',v_input.item_code;
    END IF;
    IF v_input.received_qty<>COALESCE(v_input.sent_qty,v_input.received_qty)
       AND NULLIF(btrim(COALESCE(v_input.reason,'')),'') IS NULL THEN
      RAISE EXCEPTION 'سبب اختلاف الكمية المرسلة والمقبولة مطلوب للصنف: %',v_input.item_code;
    END IF;
    SELECT * INTO v_detail
    FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND d.item_code=btrim(v_input.item_code)
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود في فاتورة السوق: %',v_input.item_code; END IF;
    SELECT * INTO v_item FROM public.items i
    WHERE i.id=v_detail.item_id AND i.company_id=p_company_id AND i.item_code=v_detail.item_code;
    IF NOT FOUND THEN RAISE EXCEPTION 'هوية الصنف غير متسقة مع دليل الأصناف: %',v_input.item_code; END IF;
    IF COALESCE(v_input.sent_qty,v_input.received_qty)>
       GREATEST(0,v_detail.qty-COALESCE(v_detail.received_qty,0))+0.0001 THEN
      RAISE EXCEPTION 'الكمية المرسلة تتجاوز المتبقي في الفاتورة: %',v_input.item_code;
    END IF;
    SELECT GREATEST(
      v_detail.qty
      -GREATEST(COALESCE(v_detail.received_qty,0),CASE WHEN COALESCE(v_invoice.is_received,false) THEN v_detail.qty ELSE 0 END,COALESCE(w.warehouse_event_qty,0))
      -COALESCE(r.supplier_returned_qty,0),0
    ) INTO v_balance
    FROM (SELECT 1) seed
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_event_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
        AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
        AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) w ON true
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS supplier_returned_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
        AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
        AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) r ON true;
    IF v_balance+0.0001<COALESCE(v_input.sent_qty,v_input.received_qty) THEN
      RAISE EXCEPTION 'الكمية المرسلة أكبر من الكمية المتاحة في حيازة المشتري: %',v_input.item_code;
    END IF;
  END LOOP;

  INSERT INTO public.receiving(
    id,operation_id,date,po_number,responsible,start_time,end_time,status,company_id,
    purchase_invoice_id,request_fingerprint
  )
  VALUES(gen_random_uuid(),v_operation,current_date,v_invoice.invoice_code,p_user_email,now(),now(),
    'مكتمل',p_company_id,p_invoice_id,v_fingerprint);

  FOR v_input IN
    SELECT * FROM jsonb_to_recordset(p_items)
      x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    SELECT * INTO v_detail
    FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND d.item_code=btrim(v_input.item_code)
    FOR UPDATE;

    IF COALESCE(v_input.received_qty,0)>0 THEN
      SELECT * INTO v_item FROM public.items i
      WHERE i.id=v_detail.item_id AND i.company_id=p_company_id;
      SELECT public.post_stock_movement(
        p_company_id,'PurchaseIn',NULL,v_invoice.branch_id,v_item.id,v_input.received_qty,
        v_invoice.invoice_code,v_invoice.invoice_code,p_user_email,
        'QMP-RECEIPT:'||p_company_id::text||':'||p_invoice_id::text||':'||p_operation_id::text||':'||v_item.id::text
      ) INTO v_stock_result;

      UPDATE public.purchase_invoice_details
      SET received_qty=COALESCE(received_qty,0)+v_input.received_qty
      WHERE id=v_detail.id AND invoice_id=p_invoice_id;

      INSERT INTO public.buyer_goods_custody_events(
        company_id,branch_id,custodian_user_id,item_id,vehicle_id,event_type,qty_delta,
        source_document_type,source_document_id,source_line_id,operation_id,payload_fingerprint,
        actor_user_id,notes
      )
      VALUES(
        p_company_id,v_invoice.branch_id,v_invoice.purchaser_user_id,v_detail.item_id,NULL,
        'BUYER_TO_WAREHOUSE_ACCEPTED',-v_input.received_qty,
        'PurchaseInvoice',p_invoice_id,v_detail.id,v_operation,v_fingerprint,
        v_actor.id,'استلام المخزن من فاتورة السوق السريع '||v_invoice.invoice_code
      );
      v_total_qty:=v_total_qty+v_input.received_qty;
      v_total_value:=v_total_value+ROUND(
        v_input.received_qty*COALESCE(v_detail.unit_price,0)
        *(1-COALESCE(v_detail.discount_percent,0)/100)
        *(1+COALESCE(v_detail.tax_rate,0)/100),2
      );
    END IF;

    INSERT INTO public.receiving_details(
      id,operation_id,item_code,item_name,unit,qty_expected,qty_received,difference,reason,purchase_invoice_detail_id
    )
    VALUES(
      gen_random_uuid(),v_operation,v_detail.item_code,
      COALESCE(v_detail.item_name,v_detail.item_code),
      COALESCE(v_detail.unit,'حبة'),
      COALESCE(v_input.sent_qty,v_input.received_qty),v_input.received_qty,
      v_input.received_qty-COALESCE(v_input.sent_qty,v_input.received_qty),
      NULLIF(btrim(COALESCE(v_input.reason,'')),''),
      v_detail.id
    );
  END LOOP;

  IF EXISTS(
    SELECT 1 FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND COALESCE(d.received_qty,0)+0.0001<d.qty
  ) THEN
    v_all_received:=false;
  END IF;

  IF v_total_qty>0 THEN
    UPDATE public.purchase_invoices
    SET receipt_status=CASE WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
        is_received=v_all_received,
        received_date=CASE WHEN v_all_received THEN COALESCE(received_date,current_date) ELSE NULL END,
        updated_at=now()
    WHERE id=p_invoice_id AND company_id=p_company_id;
  END IF;

  INSERT INTO public.audit_log(user_email,action,table_name,record_id,new_data)
  VALUES(p_user_email,'receive','purchase_invoices',p_invoice_id::text,
    jsonb_build_object('invoice_code',v_invoice.invoice_code,'operation_id',v_operation,
      'receipt_status',CASE WHEN v_total_qty<=0 THEN v_invoice.receipt_status WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
      'received_qty',v_total_qty,'received_value',v_total_value));

  RETURN jsonb_build_object('success',true,'duplicate',false,'invoice_id',p_invoice_id,
    'invoice_code',v_invoice.invoice_code,'operation_id',v_operation,
    'receipt_status',CASE WHEN v_total_qty<=0 THEN v_invoice.receipt_status WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
    'total_received_qty',v_total_qty,'total_received_value',v_total_value,
    'journal_posted',false,'supplier_balance_changed',false);
END;
$function$
;
