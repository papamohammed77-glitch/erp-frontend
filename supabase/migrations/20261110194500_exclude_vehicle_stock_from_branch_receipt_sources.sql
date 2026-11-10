CREATE OR REPLACE FUNCTION public.create_branch_receipt_request_atomic(p_company_id uuid, p_source_branch_id uuid, p_reference text, p_notes text, p_created_by text, p_items jsonb, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_home_branch_id uuid;
  v_home_count integer:=0;
  v_source public.branches%ROWTYPE;
  v_destination public.branches%ROWTYPE;
  v_item jsonb;
  v_item_id uuid;
  v_voucher_id uuid;
  v_voucher_code text;
  v_last_num bigint;
  v_fingerprint text;
  v_existing public.stock_voucher_operations%ROWTYPE;
  v_operation_id text:=NULLIF(BTRIM(p_operation_id),'');
BEGIN
  IF NULLIF(BTRIM(p_reference),'') IS NULL THEN RAISE EXCEPTION 'مرجع طلب الاستلام مطلوب'; END IF;
  IF v_operation_id IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لمنع تكرار طلب الاستلام'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN
    RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل';
  END IF;

  PERFORM set_config('app.user_email',COALESCE(p_created_by,''),true);
  PERFORM set_config('app.operation_id',v_operation_id,true);

  SELECT * INTO v_actor FROM public.users u
  WHERE u.company_id=p_company_id AND lower(u.email)=lower(p_created_by)
    AND COALESCE(u.status,'Active')='Active' LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'مستخدم طلب الاستلام غير صالح ضمن الشركة'; END IF;

  IF v_actor.role NOT IN ('مخزني','أمين مخزن','امين مخزن')
     OR COALESCE(v_actor.active_warehouse_role,'') NOT IN ('مخزن شامل','أذونات')
     OR NOT (
       COALESCE(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
       OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
     )
  THEN RAISE EXCEPTION 'صلاحية طلب الاستلام من مخزن فرع غير متاحة لهذا المستخدم'; END IF;

  IF v_actor.default_branch_id IS NOT NULL THEN
    SELECT b.id INTO v_home_branch_id FROM public.branches b
    WHERE b.id=v_actor.default_branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true)=true;
    IF v_home_branch_id IS NULL THEN RAISE EXCEPTION 'الفرع الأساسي للمستخدم غير نشط أو لا يتبع الشركة'; END IF;
  ELSE
    IF jsonb_typeof(v_actor.allowed_branch_ids)='array' AND jsonb_array_length(v_actor.allowed_branch_ids)=1 THEN
      SELECT count(*),min(b.id::text)::uuid INTO v_home_count,v_home_branch_id
      FROM public.branches b
      WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true)=true
        AND (
          v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
          OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
        );
    END IF;
    IF v_home_count<>1 OR v_home_branch_id IS NULL THEN
      RAISE EXCEPTION 'يجب تحديد فرع أساسي واحد لأمين المخزن من النظام الأم قبل طلب الاستلام';
    END IF;
  END IF;

  SELECT * INTO v_destination FROM public.branches b
  WHERE b.id=v_home_branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true)=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'فرع أمين المخزن غير صالح'; END IF;

  SELECT * INTO v_source FROM public.branches b
  WHERE b.id=p_source_branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true)=true AND b.branch_code NOT LIKE 'VAN-%';
  IF NOT FOUND THEN RAISE EXCEPTION 'فرع المصدر غير موجود أو غير نشط ضمن الشركة'; END IF;
  IF v_source.id=v_destination.id THEN RAISE EXCEPTION 'اختر فرع مصدر مختلفًا عن فرع أمين المخزن'; END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_items) AS x(value)
    GROUP BY lower(BTRIM(value->>'itemCode')) HAVING count(*)>1
  ) THEN RAISE EXCEPTION 'لا يمكن تكرار الصنف داخل طلب الاستلام'; END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    IF NULLIF(BTRIM(v_item->>'itemCode'),'') IS NULL OR COALESCE((v_item->>'qty')::numeric,0)<=0 THEN
      RAISE EXCEPTION 'كود الصنف والكمية الموجبة مطلوبان';
    END IF;
    SELECT i.id INTO v_item_id FROM public.items i
    WHERE i.company_id=p_company_id AND i.item_code=v_item->>'itemCode'
      AND COALESCE(i.is_active,true)=true LIMIT 1;
    IF v_item_id IS NULL THEN RAISE EXCEPTION 'الصنف غير موجود أو غير نشط: %',v_item->>'itemCode'; END IF;
  END LOOP;

  v_fingerprint:=md5(jsonb_build_object(
    'request_origin','WarehouseBranchReceipt','company_id',p_company_id,
    'type','Transfer','reference',BTRIM(p_reference),'from_id',v_source.id,
    'to_id',v_destination.id,'receiver_user_id',v_actor.id,'notes',COALESCE(p_notes,''),'items',p_items
  )::text);

  SELECT * INTO v_existing FROM public.stock_voucher_operations o
  WHERE o.company_id=p_company_id AND o.operation_id=v_operation_id FOR UPDATE;
  IF FOUND THEN
    IF v_existing.fingerprint<>v_fingerprint THEN RAISE EXCEPTION 'operation_id مستخدم مع بيانات مختلفة'; END IF;
    IF v_existing.voucher_id IS NOT NULL THEN
      RETURN jsonb_build_object('success',true,'duplicate',true,'voucher_id',v_existing.voucher_id,
        'voucher_code',(SELECT v.voucher_code FROM public.stock_vouchers v WHERE v.id=v_existing.voucher_id),
        'status','Draft','request_origin','WarehouseBranchReceipt','operation_id',v_operation_id);
    END IF;
  ELSE
    INSERT INTO public.stock_voucher_operations(company_id,operation_id,fingerprint)
    VALUES(p_company_id,v_operation_id,v_fingerprint);
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('rawaea:stock-voucher-code'));
  SELECT COALESCE(max(substring(voucher_code from '[0-9]+$')::bigint),0) INTO v_last_num
  FROM public.stock_vouchers WHERE company_id=p_company_id;
  v_voucher_code:='IN-'||(v_last_num+1)::text;

  INSERT INTO public.stock_vouchers(
    voucher_code,voucher_date,type,status,reference,from_type,from_id,to_type,to_id,notes,
    receiver_user_id,receiver_assigned_at,created_by,source,company_id,request_origin
  ) VALUES(
    v_voucher_code,current_date,'Transfer','Draft',BTRIM(p_reference),'Branch',v_source.id,
    'Branch',v_destination.id,COALESCE(p_notes,''),v_actor.id,now(),p_created_by,'Manual',
    p_company_id,'WarehouseBranchReceipt'
  ) RETURNING id INTO v_voucher_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT i.id INTO v_item_id FROM public.items i
    WHERE i.company_id=p_company_id AND i.item_code=v_item->>'itemCode' LIMIT 1;
    INSERT INTO public.stock_voucher_details(voucher_id,item_id,item_code,item_name,unit,qty,unit_price,notes)
    VALUES(v_voucher_id,v_item_id,v_item->>'itemCode',
      COALESCE(NULLIF(v_item->>'itemName',''),v_item->>'itemCode'),
      COALESCE(NULLIF(v_item->>'unit',''),'حبة'),(v_item->>'qty')::numeric,
      COALESCE((v_item->>'unitPrice')::numeric,0),COALESCE(v_item->>'notes',''));
  END LOOP;

  UPDATE public.stock_voucher_operations SET voucher_id=v_voucher_id
  WHERE company_id=p_company_id AND operation_id=v_operation_id;

  RETURN jsonb_build_object('success',true,'duplicate',false,'voucher_id',v_voucher_id,
    'voucher_code',v_voucher_code,'status','Draft','request_origin','WarehouseBranchReceipt',
    'source_branch_id',v_source.id,'destination_branch_id',v_destination.id,
    'receiver_user_id',v_actor.id,'operation_id',v_operation_id);
END;
$function$
;
