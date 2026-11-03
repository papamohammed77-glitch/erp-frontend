-- Server-side authorization for purchase receiving.
-- Captured production definition is the exact deployed 5-argument contract.
CREATE OR REPLACE FUNCTION public.receive_purchase_atomic(p_company_id uuid, p_po_code text, p_user_email text, p_items jsonb, p_operation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  po public.purchase_orders%ROWTYPE;
  e record;
  pd public.purchase_order_details%ROWTYPE;
  item_master public.items%ROWTYPE;
  main_branch uuid;
  receiving_branch uuid;
  op text;
  existing public.receiving%ROWTYPE;
  total_value numeric:=0;
  total_received_qty numeric:=0;
  all_received boolean:=true;
  requested_fp text;
  existing_fp text;
  supplier_account uuid;
  inventory_account uuid;
  entry_id uuid;
  previous_balance numeric:=0;
  actor public.users%ROWTYPE;
  actor_permissions jsonb := '[]'::jsonb;
  actor_is_owner boolean := false;
  receiving_branch_code text;
  branch_allowed boolean := false;
  allowed_branch_value text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.companies WHERE id=p_company_id AND COALESCE(is_active,true)) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط';
  END IF;
  SELECT u.* INTO actor
  FROM public.users u
  WHERE u.company_id = p_company_id
    AND lower(u.email) = lower(coalesce(p_user_email,''))
    AND coalesce(u.status,'Active') = 'Active'
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو غير نشط';
  END IF;

  SELECT coalesce(jsonb_agg(DISTINCT source.permission), '[]'::jsonb)
    INTO actor_permissions
  FROM (
    SELECT jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(actor.permissions) = 'array'
        THEN actor.permissions ELSE '[]'::jsonb END
    ) AS permission
    UNION ALL
    SELECT jsonb_array_elements_text(
      CASE WHEN jsonb_typeof(r.permissions) = 'array'
        THEN r.permissions ELSE '[]'::jsonb END
    ) AS permission
    FROM public.roles r
    WHERE r.id = actor.role_id
      AND r.company_id = p_company_id
    UNION ALL
    SELECT rp.permission_key
    FROM public.role_permissions rp
    WHERE rp.role_id = actor.role_id
  ) source
  WHERE nullif(btrim(source.permission), '') IS NOT NULL;

  SELECT EXISTS (
    SELECT 1
    FROM auth.users au
    JOIN public.owner_profile op ON op.auth_user_id = au.id
    WHERE au.id = actor.auth_id
      AND coalesce(au.raw_user_meta_data->>'isOwner', 'false') = 'true'
      AND jsonb_typeof(actor.permissions) = 'array'
      AND actor.permissions ? '*'
  ) INTO actor_is_owner;

  -- RECEIVE_PERMISSION_GUARD:
  -- Receiver UI allows only Owner or the active warehouse role "استلام".
  IF NOT actor_is_owner
     AND NOT (
       actor.active_warehouse_role = 'استلام'
       AND (
         actor_permissions ? '*'
         OR actor_permissions ? 'warehouse'
         OR actor_permissions ? 'receiving'
       )
     ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية استلام أوامر الشراء';
  END IF;
  IF p_operation_id IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لاستلام الشراء'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'لا توجد أصناف للاستلام'; END IF;

  SELECT * INTO po FROM public.purchase_orders WHERE company_id=p_company_id AND po_code=p_po_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'أمر الشراء غير موجود'; END IF;

  op:='PO-RECEIVE:'||p_company_id::text||':'||po.id::text||':'||p_operation_id::text;
  SELECT md5(coalesce(string_agg(btrim(x.item_code)||':'||coalesce(x.received_qty,0)::text,'|' ORDER BY btrim(x.item_code)),''))
    INTO requested_fp
  FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric,item_name text,unit text,reason text)
  WHERE coalesce(x.received_qty,0)>0;

  SELECT * INTO existing FROM public.receiving WHERE company_id=p_company_id AND operation_id=op FOR UPDATE;
  IF FOUND THEN
    SELECT md5(coalesce(string_agg(btrim(rd.item_code)||':'||coalesce(rd.qty_received,0)::text,'|' ORDER BY btrim(rd.item_code)),''))
      INTO existing_fp
    FROM public.receiving_details rd WHERE rd.operation_id=op;
    IF coalesce(existing_fp,'') IS DISTINCT FROM coalesce(requested_fp,'') THEN
      RAISE EXCEPTION 'idempotency key conflict: نفس operation_id استُخدم مع استلام مختلف';
    END IF;
    RETURN jsonb_build_object('success',true,'duplicate',true,'operation_id',p_operation_id,'po_code',p_po_code,'status',(SELECT status FROM public.purchase_orders WHERE id=po.id));
  END IF;

  SELECT main_branch_id INTO STRICT main_branch FROM public.app_settings WHERE company_id=p_company_id ORDER BY created_at ASC,id LIMIT 1;
  receiving_branch:=coalesce(po.branch_id,main_branch);
  SELECT b.branch_code INTO receiving_branch_code
  FROM public.branches b
  WHERE b.id = receiving_branch
    AND b.company_id = p_company_id
    AND coalesce(b.is_active,true);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'فرع الاستلام غير صالح للشركة';
  END IF;

  -- RECEIVE_BRANCH_SCOPE_GUARD:
  -- allowed_branch_ids may be an array of UUIDs/codes or a legacy scalar branch code.
  IF NOT actor_is_owner THEN
    branch_allowed := actor.default_branch_id = receiving_branch;

    IF jsonb_typeof(actor.allowed_branch_ids) = 'array' THEN
      branch_allowed := branch_allowed
        OR actor.allowed_branch_ids ? '*'
        OR actor.allowed_branch_ids ? receiving_branch::text
        OR actor.allowed_branch_ids ? coalesce(receiving_branch_code,'');
    ELSIF jsonb_typeof(actor.allowed_branch_ids) = 'string' THEN
      allowed_branch_value := actor.allowed_branch_ids #>> '{}';
      branch_allowed := branch_allowed
        OR allowed_branch_value IN ('*', receiving_branch::text, receiving_branch_code);
    END IF;

    IF NOT branch_allowed THEN
      RAISE EXCEPTION 'لا تملك صلاحية الاستلام في فرع أمر الشراء';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_to_recordset(p_items) AS x(item_code text,received_qty numeric,item_name text,unit text,reason text) GROUP BY x.item_code HAVING count(*)>1) THEN
    RAISE EXCEPTION 'لا يجوز تكرار الصنف داخل نفس عملية الاستلام';
  END IF;

  FOR e IN SELECT * FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric,item_name text,unit text,reason text) LOOP
    IF COALESCE(e.received_qty,0)<=0 THEN CONTINUE; END IF;
    IF NULLIF(btrim(e.item_code),'') IS NULL THEN RAISE EXCEPTION 'كود الصنف مطلوب'; END IF;
    SELECT * INTO pd FROM public.purchase_order_details d WHERE d.po_id=po.id AND d.item_code=e.item_code FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود داخل أمر الشراء: %',e.item_code; END IF;
    SELECT * INTO item_master FROM public.items i WHERE i.id=pd.item_id AND i.item_code=e.item_code;
    IF NOT FOUND THEN RAISE EXCEPTION 'هوية الصنف غير متسقة مع دليل الأصناف: %',e.item_code; END IF;
    IF e.received_qty > GREATEST(0,COALESCE(pd.qty_ordered,0)-COALESCE(pd.qty_received,0)) THEN
      RAISE EXCEPTION 'الكمية المستلمة تتجاوز المتبقي للصنف: %',e.item_code;
    END IF;
  END LOOP;

  INSERT INTO public.receiving(id,operation_id,date,po_number,responsible,start_time,end_time,status,company_id)
  VALUES(gen_random_uuid(),op,current_date,p_po_code,p_user_email,now(),now(),'مكتمل',p_company_id);

  FOR e IN SELECT * FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric,item_name text,unit text,reason text) LOOP
    IF COALESCE(e.received_qty,0)<=0 THEN CONTINUE; END IF;
    SELECT * INTO pd FROM public.purchase_order_details d WHERE d.po_id=po.id AND d.item_code=e.item_code FOR UPDATE;
    SELECT * INTO item_master FROM public.items i WHERE i.id=pd.item_id AND i.item_code=e.item_code;
    PERFORM public.post_stock_movement(p_company_id,'PurchaseIn',NULL,receiving_branch,item_master.id,e.received_qty,p_po_code,p_po_code,p_user_email,'PurchaseReceipt:'||op||':'||item_master.id::text);
    UPDATE public.purchase_order_details SET qty_received=COALESCE(pd.qty_received,0)+e.received_qty WHERE id=pd.id;
    INSERT INTO public.receiving_details(id,operation_id,item_code,item_name,unit,qty_expected,qty_received,difference,reason)
    VALUES(gen_random_uuid(),op,e.item_code,coalesce(e.item_name,e.item_code),coalesce(e.unit,'حبة'),pd.qty_ordered,e.received_qty,e.received_qty-pd.qty_ordered,NULLIF(COALESCE(e.reason,CASE WHEN e.received_qty<pd.qty_ordered THEN 'نقص في الاستلام' WHEN e.received_qty>pd.qty_ordered THEN 'زيادة في الاستلام' ELSE '' END),''));
    total_value:=total_value+(e.received_qty*coalesce(pd.unit_price,0));
    total_received_qty:=total_received_qty+e.received_qty;
  END LOOP;

  FOR pd IN SELECT * FROM public.purchase_order_details WHERE po_id=po.id LOOP
    IF coalesce(pd.qty_received,0)<coalesce(pd.qty_ordered,0) THEN all_received:=false; EXIT; END IF;
  END LOOP;
  PERFORM set_config('rawaea.purchase_actor',p_user_email,true);
  UPDATE public.purchase_orders SET status=CASE WHEN all_received THEN 'Received' ELSE 'Partially Received' END,updated_at=now() WHERE id=po.id AND company_id=p_company_id;

  IF total_value>0 THEN
    SELECT id INTO inventory_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='124' AND is_active=true LIMIT 1;
    SELECT id INTO supplier_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='211' AND is_active=true LIMIT 1;
    IF inventory_account IS NULL OR supplier_account IS NULL THEN RAISE EXCEPTION 'حسابات استلام المشتريات غير مكتملة للشركة'; END IF;
    INSERT INTO public.journal_entries(id,company_id,entry_code,entry_date,reference,description,entry_type,status,created_by,posting_date)
    VALUES(gen_random_uuid(),p_company_id,'JE-RCV-'||replace(gen_random_uuid()::text,'-',''),current_date,p_po_code,'استلام بضاعة – أمر الشراء '||p_po_code,'PurchaseReceiving','Posted',p_user_email,now()) RETURNING id INTO entry_id;
    INSERT INTO public.journal_lines(entry_id,account_id,account_name,debit,credit)
    SELECT entry_id,inventory_account,account_name,total_value,0 FROM public.chart_of_accounts WHERE id=inventory_account
    UNION ALL
    SELECT entry_id,supplier_account,account_name,0,total_value FROM public.chart_of_accounts WHERE id=supplier_account;
    IF po.supplier_id IS NOT NULL THEN
      SELECT COALESCE(SUM(credit-debit),0) INTO previous_balance FROM public.supplier_ledger WHERE supplier_id=po.supplier_id;
      INSERT INTO public.supplier_ledger(supplier_id,entry_date,reference,description,debit,credit,balance,due_date,user_email)
      VALUES(po.supplier_id,current_date,p_po_code,'استلام بضاعة - '||p_po_code,0,total_value,previous_balance+total_value,current_date,p_user_email);
    END IF;
  END IF;

  INSERT INTO public.audit_log(user_email,action,table_name,record_id,new_data)
  VALUES(p_user_email,'receive','purchase_orders',po.id::text,jsonb_build_object('po_code',p_po_code,'operation_id',p_operation_id,'status',(SELECT status FROM public.purchase_orders WHERE id=po.id),'total_received_value',total_value,'total_received_qty',total_received_qty));

  RETURN jsonb_build_object('success',true,'duplicate',false,'operation_id',p_operation_id,'po_code',p_po_code,'status',(SELECT status FROM public.purchase_orders WHERE id=po.id),'total_received_value',total_value,'total_received_qty',total_received_qty);
END;
$function$

REVOKE ALL ON FUNCTION public.receive_purchase_atomic(uuid,text,text,jsonb,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.receive_purchase_atomic(uuid,text,text,jsonb,uuid) TO service_role;
-- The compatibility overload remains service-role-only and delegates to the guarded 5-argument contract.
REVOKE ALL ON FUNCTION public.receive_purchase_atomic(uuid,text,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.receive_purchase_atomic(uuid,text,text,jsonb) TO service_role;
