CREATE OR REPLACE FUNCTION public.post_manual_stock_voucher_atomic_core_20260828(p_company_id uuid, p_voucher_code text, p_operation text, p_user_email text, p_effects jsonb, p_operation_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v public.stock_vouchers%ROWTYPE;
  e record;
  v_detail_qty numeric;
  v_received_before numeric;
  movement text;
  idem text;
  src uuid;
  tgt uuid;
  vehicle_branch uuid;
  remain integer:=0;
  movement_result jsonb;
  requested_fp text;
  existing_fp text;
BEGIN
  SELECT * INTO v_actor FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(p_user_email)
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN RAISE EXCEPTION 'سياق الشركة غير متسق مع المستخدم المنفذ'; END IF;

  IF NOT (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR coalesce(v_actor.active_warehouse_role,'')='أذونات'
    OR (
      v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
      AND coalesce(v_actor.active_warehouse_role,'')='مخزن شامل'
      AND coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
    )
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN
    RAISE EXCEPTION 'المستخدم غير مخول بتنفيذ دورة الأذونات المخزنية';
  END IF;

  IF p_operation NOT IN ('SEND','RECEIVE') THEN RAISE EXCEPTION 'عملية مخزنية غير مدعومة'; END IF;
  IF p_effects IS NULL OR jsonb_typeof(p_effects)<>'array' OR jsonb_array_length(p_effects)=0 THEN RAISE EXCEPTION 'لا توجد حركات مخزنية للتنفيذ'; END IF;
  IF EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_effects) AS x(direction text,branch_id uuid,item_id uuid,item_code text,qty numeric)
    GROUP BY x.item_id HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'لا يجوز تكرار الصنف داخل نفس عملية الحركة';
  END IF;

  SELECT * INTO v
  FROM public.stock_vouchers
  WHERE company_id=p_company_id AND voucher_code=p_voucher_code
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'الإذن غير موجود'; END IF;

  IF p_operation='RECEIVE' THEN
    IF v.type NOT IN ('Transfer','DirectReturn') THEN
      RAISE EXCEPTION 'هذا النوع من الأذونات لا يملك مرحلة استلام: %',v.type;
    END IF;
    IF v.type='Transfer' AND v.receiver_user_id IS DISTINCT FROM v_actor.id THEN
      RAISE EXCEPTION 'لا يملك هذا المستخدم مسؤولية استلام تحويل الفرع';
    END IF;

    IF NULLIF(btrim(p_operation_id),'') IS NULL THEN
      RAISE EXCEPTION 'operation_id مطلوب للاستلام';
    END IF;

    SELECT string_agg(
      x.item_id::text||':'||(x.qty::double precision)::text,
      '|' ORDER BY x.item_id
    )
    INTO requested_fp
    FROM jsonb_to_recordset(p_effects) AS x(
      direction text,branch_id uuid,item_id uuid,item_code text,qty numeric
    );

    SELECT string_agg(
      il.item_id::text||':'||(il.qty::double precision)::text,
      '|' ORDER BY il.item_id
    )
    INTO existing_fp
    FROM public.inventory_log il
    WHERE il.company_id=p_company_id
      AND il.idempotency_key LIKE
        'ManualVoucher:RECEIVE:'||p_company_id::text||':'||
        v.id::text||':'||p_operation_id||':%';

    IF existing_fp IS NOT NULL THEN
      IF existing_fp<>requested_fp THEN
        RAISE EXCEPTION 'idempotency key conflict: نفس operation_id استُخدم مع حركة مختلفة';
      END IF;

      RETURN jsonb_build_object(
        'success',true,'duplicate',true,
        'voucher_code',p_voucher_code,
        'operation','RECEIVE',
        'status',v.status,
        'operation_id',p_operation_id
      );
    END IF;

    IF v.status<>'Sent' THEN
      RAISE EXCEPTION 'حالة الإذن لا تسمح بالاستلام';
    END IF;
  ELSE
    IF v.status<>'Draft' THEN
      RAISE EXCEPTION 'حالة الإذن لا تسمح بالإرسال';
    END IF;
  END IF;

  FOR e IN
    SELECT * FROM jsonb_to_recordset(p_effects) AS x(
      direction text,branch_id uuid,item_id uuid,item_code text,qty numeric
    )
  LOOP
    IF e.qty IS NULL OR e.qty<=0 OR e.branch_id IS NULL
       OR e.item_id IS NULL OR e.item_code IS NULL THEN
      RAISE EXCEPTION 'بيانات حركة مخزنية غير صالحة';
    END IF;

    IF NOT EXISTS(
      SELECT 1 FROM public.branches b
      WHERE b.id=e.branch_id AND b.company_id=p_company_id
    ) THEN
      RAISE EXCEPTION 'الفرع غير موجود أو لا يتبع الشركة';
    END IF;

    IF NOT EXISTS(
      SELECT 1 FROM public.items i
      WHERE i.id=e.item_id AND i.item_code=e.item_code
    ) THEN
      RAISE EXCEPTION 'الصنف غير متسق مع دليل الأصناف';
    END IF;

    SELECT d.qty,coalesce(d.received_qty,0)
      INTO v_detail_qty,v_received_before
    FROM public.stock_voucher_details d
    WHERE d.voucher_id=v.id
      AND d.item_id=e.item_id
      AND d.item_code=e.item_code
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'الصنف غير موجود في تفاصيل الإذن';
    END IF;

    IF p_operation='SEND' THEN
      IF e.direction<>'OUT'
         OR v.type NOT IN('Transfer','DirectSale','DirectReturn','SupplierReturn') THEN
        RAISE EXCEPTION 'اتجاه الإرسال لا يطابق الإذن';
      END IF;

      IF e.qty<>v_detail_qty THEN
        RAISE EXCEPTION 'كمية الإرسال لا تطابق تفاصيل الإذن';
      END IF;

      IF v.type='DirectReturn' THEN
        IF v.from_type<>'Vehicle' THEN
          RAISE EXCEPTION 'مصدر المرتجع المباشر يجب أن يكون مركبة';
        END IF;

        SELECT coalesce(
          (
            SELECT mb.id
            FROM public.vehicles vv
            JOIN public.branches mb
              ON mb.id=vv.mobile_branch_id
             AND mb.company_id=p_company_id
             AND mb.is_active=true
            WHERE vv.id=v.from_id
              AND vv.company_id=p_company_id
              AND coalesce(vv.status,'Active')='Active'
              AND coalesce(vv.mobile_stock_enabled,true)=true
          ),
          (
            SELECT lb.id
            FROM public.vehicles vv
            JOIN public.branches lb
              ON lb.company_id=vv.company_id
             AND upper(lb.branch_code)=upper('VAN-'||vv.vehicle_code)
             AND lb.is_active=true
            WHERE vv.id=v.from_id
              AND vv.company_id=p_company_id
              AND coalesce(vv.status,'Active')='Active'
              AND coalesce(vv.mobile_stock_enabled,true)=true
          )
        )
        INTO vehicle_branch;

        IF vehicle_branch IS NULL THEN
          RAISE EXCEPTION 'المركبة المصدر ليست مرتبطة بمخزن متنقل صالح';
        END IF;

        IF e.branch_id<>vehicle_branch THEN
          RAISE EXCEPTION 'فرع مخزون المركبة غير متسق مع الإذن';
        END IF;

        movement:='InventoryDecrease';
        src:=vehicle_branch;
        tgt:=NULL;
        idem:='DirectReturnOut:'||p_company_id::text||':'||v.id::text||':'||e.item_id::text;

      ELSE
        IF v.from_type<>'Branch' OR e.branch_id<>v.from_id THEN
          RAISE EXCEPTION 'اتجاه المصدر لا يطابق الإذن';
        END IF;

        src:=v.from_id;
        tgt:=NULL;
        movement:=CASE v.type
          WHEN 'Transfer' THEN 'TransferOut'
          WHEN 'DirectSale' THEN 'DirectSale'
          WHEN 'SupplierReturn' THEN 'SupplierReturn'
        END;
        idem:='StockVoucherSend:'||p_company_id::text||':'||v.id::text||':'||e.item_id::text;
      END IF;

    ELSE
      IF e.direction<>'IN' THEN
        RAISE EXCEPTION 'اتجاه الاستلام لا يطابق الإذن';
      END IF;

      IF e.qty>(v_detail_qty-v_received_before) THEN
        RAISE EXCEPTION 'الكمية المستلمة أكبر من المتبقي';
      END IF;

      IF v.to_type<>'Branch' OR e.branch_id<>v.to_id THEN
        RAISE EXCEPTION 'وجهة الاستلام لا تطابق الإذن';
      END IF;

      tgt:=v.to_id;
      src:=NULL;
      movement:=CASE v.type
        WHEN 'Transfer' THEN 'TransferIn'
        WHEN 'DirectReturn' THEN 'InventoryIncrease'
      END;
      idem:='ManualVoucher:RECEIVE:'||p_company_id::text||':'||v.id::text||':'||p_operation_id::text||':'||e.item_id::text;
    END IF;

    movement_result:=public.post_stock_movement(
      p_company_id,movement,src,tgt,e.item_id,e.qty,
      p_voucher_code,p_voucher_code,p_user_email,idem
    );

    IF p_operation='RECEIVE'
       AND coalesce((movement_result->>'duplicate')::boolean,false)=false THEN
      UPDATE public.stock_voucher_details
      SET received_qty=coalesce(received_qty,0)+e.qty
      WHERE voucher_id=v.id AND item_id=e.item_id AND item_code=e.item_code;

      IF NOT FOUND THEN RAISE EXCEPTION 'تعذر تحديث الكمية المستلمة'; END IF;
    END IF;
  END LOOP;

  IF p_operation='SEND' THEN
    UPDATE public.stock_vouchers
    SET status='Sent',sent_date=now(),updated_at=now()
    WHERE id=v.id AND company_id=p_company_id AND status='Draft';
  ELSE
    SELECT count(*) INTO remain
    FROM public.stock_voucher_details sd
    WHERE sd.voucher_id=v.id
      AND coalesce(sd.received_qty,0)<sd.qty;

    UPDATE public.stock_vouchers
    SET status=CASE WHEN remain=0 THEN 'Received' ELSE 'Sent' END,
        received_date=CASE WHEN remain=0 THEN now() ELSE received_date END,
        updated_at=now()
    WHERE id=v.id AND company_id=p_company_id AND status='Sent';
  END IF;

  IF NOT FOUND THEN RAISE EXCEPTION 'فشل انتقال حالة الإذن'; END IF;

  RETURN jsonb_build_object(
    'success',true,
    'duplicate',false,
    'voucher_code',p_voucher_code,
    'operation',p_operation,
    'status',(SELECT status FROM public.stock_vouchers WHERE id=v.id),
    'operation_id',p_operation_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.send_stock_voucher_atomic_core_20260828(p_company_id uuid, p_voucher_code text, p_user_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_voucher public.stock_vouchers%ROWTYPE;
  d record;
  v_source uuid;
  v_target uuid;
  v_vehicle_branch uuid;
  v_mobile_branch uuid;
  movement text;
  key text;
  r jsonb;
  expected_count integer:=0;
  existing_count integer:=0;
  idem_prefix text;
BEGIN
  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(p_user_email)
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'سياق الشركة غير متسق مع المستخدم المنفذ';
  END IF;

  IF NOT (
    (coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb)
    OR coalesce(v_actor.active_warehouse_role,'')='أذونات'
    OR (
      v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
      AND coalesce(v_actor.active_warehouse_role,'')='مخزن شامل'
      AND coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
    )
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN
    RAISE EXCEPTION 'المستخدم غير مخول بإرسال الأذونات المخزنية';
  END IF;

  SELECT * INTO v_voucher
  FROM public.stock_vouchers
  WHERE company_id=p_company_id
    AND voucher_code=p_voucher_code
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voucher not found';
  END IF;

  SELECT count(*) INTO expected_count
  FROM (
    SELECT svd.item_id,svd.item_code
    FROM public.stock_voucher_details svd
    WHERE svd.voucher_id=v_voucher.id
      AND COALESCE(svd.qty,0)>0
    GROUP BY svd.item_id,svd.item_code
  ) g;

  idem_prefix:=
    CASE
      WHEN v_voucher.type='DirectReturn'
        THEN 'DirectReturnOut:'
      ELSE
        'StockVoucherSend:'
    END;

  SELECT count(*) INTO existing_count
  FROM public.inventory_log il
  WHERE il.company_id=p_company_id
    AND il.idempotency_key LIKE
      idem_prefix||
      p_company_id::text||':'||
      v_voucher.id::text||':%';

  IF expected_count>0 AND existing_count=expected_count THEN
    RETURN jsonb_build_object(
      'success',true,
      'duplicate',true,
      'voucher_id',v_voucher.id,
      'voucher_code',p_voucher_code,
      'status',v_voucher.status,
      'movement_count',existing_count
    );
  END IF;

  IF v_voucher.status<>'Draft' THEN
    RAISE EXCEPTION 'Voucher is not Draft';
  END IF;

  IF v_voucher.type NOT IN('Transfer','DirectSale','DirectReturn','SupplierReturn') THEN
    RAISE EXCEPTION 'Unsupported send movement type: %',v_voucher.type;
  END IF;

  IF v_voucher.from_type='Branch' THEN
    v_source:=v_voucher.from_id;
  ELSIF v_voucher.from_type='Vehicle' THEN
    SELECT coalesce(
      (
        SELECT mb.id
        FROM public.branches mb
        WHERE mb.id=v_vehicle.mobile_branch_id
          AND mb.company_id=p_company_id
          AND mb.is_active=true
      ),
      (
        SELECT lb.id
        FROM public.branches lb
        WHERE lb.company_id=p_company_id
          AND upper(lb.branch_code)=upper('VAN-'||v_vehicle.vehicle_code)
          AND lb.is_active=true
      )
    )
    INTO v_source
    FROM public.vehicles v_vehicle
    WHERE v_vehicle.id=v_voucher.from_id
      AND v_vehicle.company_id=p_company_id
      AND coalesce(v_vehicle.status,'Active')='Active'
      AND coalesce(v_vehicle.mobile_stock_enabled,true)=true;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'Vehicle source stock context invalid';
    END IF;
  END IF;

  IF v_source IS NULL OR NOT EXISTS(
    SELECT 1
    FROM public.branches b
    WHERE b.id=v_source
      AND b.company_id=p_company_id
      AND b.is_active=true
  ) THEN
    RAISE EXCEPTION 'Source stock context invalid';
  END IF;

  v_target:=NULL;

  IF v_voucher.type='DirectSale' THEN
    SELECT coalesce(
      (
        SELECT mb.id
        FROM public.branches mb
        WHERE mb.id=v.mobile_branch_id
          AND mb.company_id=p_company_id
          AND mb.is_active=true
      ),
      (
        SELECT lb.id
        FROM public.branches lb
        WHERE lb.company_id=p_company_id
          AND upper(lb.branch_code)=upper('VAN-'||v.vehicle_code)
          AND lb.is_active=true
      )
    )
    INTO v_target
    FROM public.vehicles v
    WHERE v.id=v_voucher.to_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;

    IF v_target IS NULL THEN
      RAISE EXCEPTION 'Destination vehicle stock branch is not initialized';
    END IF;

    movement:='DirectSale';

  ELSIF v_voucher.type='DirectReturn' THEN
    IF v_voucher.from_type<>'Vehicle'
       OR v_voucher.to_type<>'Branch'
       OR v_voucher.to_id IS NULL THEN
      RAISE EXCEPTION 'DirectReturn requires Vehicle source and Branch destination';
    END IF;

    IF NOT EXISTS(
      SELECT 1
      FROM public.branches b
      WHERE b.id=v_voucher.to_id
        AND b.company_id=p_company_id
        AND b.is_active=true
    ) THEN
      RAISE EXCEPTION 'DirectReturn destination branch context invalid';
    END IF;

    v_target:=NULL;
    movement:='InventoryDecrease';

  ELSE
    movement:=CASE
      WHEN v_voucher.type='Transfer' THEN 'TransferOut'
      WHEN v_voucher.type='SupplierReturn' THEN 'SupplierReturn'
    END;
  END IF;

  FOR d IN
    SELECT svd.item_id,svd.item_code,SUM(svd.qty) qty
    FROM public.stock_voucher_details svd
    WHERE svd.voucher_id=v_voucher.id
    GROUP BY svd.item_id,svd.item_code
    ORDER BY svd.item_id
  LOOP
    IF COALESCE(d.qty,0)<=0 THEN CONTINUE; END IF;

    IF NOT EXISTS(
      SELECT 1
      FROM public.items i
      WHERE i.id=d.item_id
        AND i.item_code=d.item_code
    ) THEN
      RAISE EXCEPTION 'Item identity invalid: %',d.item_code;
    END IF;

    key:=
      CASE
        WHEN v_voucher.type='DirectReturn'
          THEN 'DirectReturnOut:'
        ELSE
          'StockVoucherSend:'
      END
      ||p_company_id::text||':'||
      v_voucher.id::text||':'||
      d.item_id::text;

    SELECT public.post_stock_movement(
      p_company_id,movement,v_source,v_target,d.item_id,d.qty,
      p_voucher_code,p_voucher_code,p_user_email,key
    ) INTO r;
  END LOOP;

  UPDATE public.stock_vouchers
  SET status='Sent',
      sent_date=now(),
      updated_at=now()
  WHERE id=v_voucher.id
    AND company_id=p_company_id
    AND status='Draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update voucher state';
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'duplicate',false,
    'voucher_id',v_voucher.id,
    'voucher_code',p_voucher_code,
    'status','Sent',
    'movement_count',expected_count
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_manual_stock_voucher_atomic_core_12_20260828(p_company_id uuid, p_type text, p_reference text, p_from_type text, p_from_id uuid, p_to_type text, p_to_id uuid, p_notes text, p_created_by text, p_items jsonb, p_rep_id uuid, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_voucher_id uuid;
  v_voucher_code text;
  v_item jsonb;
  v_item_id uuid;
  v_last_num bigint;
  v_valid boolean;
  v_actor public.users%ROWTYPE;
  v_rep public.users%ROWTYPE;
  v_vehicle public.vehicles%ROWTYPE;
  v_fingerprint text;
  v_existing public.stock_voucher_operations%ROWTYPE;
  v_allowed boolean;
BEGIN
  IF NOT EXISTS(
    SELECT 1 FROM public.companies
    WHERE id=p_company_id
  ) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود';
  END IF;

  IF NULLIF(btrim(p_reference),'') IS NULL THEN
    RAISE EXCEPTION 'المرجع مطلوب';
  END IF;

  IF p_items IS NULL
     OR jsonb_typeof(p_items)<>'array'
     OR jsonb_array_length(p_items)=0 THEN
    RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل';
  END IF;

  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(p_created_by)
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'منشئ الإذن غير صالح ضمن الشركة';
  END IF;

  IF p_type NOT IN('Transfer','DirectSale','DirectReturn','SupplierReturn') THEN
    RAISE EXCEPTION 'نوع الإذن غير مدعوم في دورة الأذونات الحالية';
  END IF;

  IF p_type='Transfer'
     AND (
       p_from_type<>'Branch'
       OR p_from_id IS NULL
       OR p_to_type<>'Branch'
       OR p_to_id IS NULL
     ) THEN
    RAISE EXCEPTION 'تحويل الفرع يتطلب فرع مصدر ووجهة';
  END IF;

  IF p_type='DirectSale' THEN
    IF p_from_type<>'Branch' OR p_from_id IS NULL OR p_to_type<>'Vehicle' THEN
      RAISE EXCEPTION 'الصرف المباشر يتطلب فرع مصدر';
    END IF;

    IF v_actor.role='مندوب بيع مباشر' THEN
      IF p_rep_id IS NULL THEN p_rep_id:=v_actor.id; END IF;
    ELSIF coalesce(v_actor.active_warehouse_role,'')='أذونات'
       OR (
         v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
         AND coalesce(v_actor.active_warehouse_role,'')='مخزن شامل'
         AND coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
       ) THEN
      IF p_rep_id IS NULL THEN RAISE EXCEPTION 'مندوب البيع المباشر مطلوب للصرف المباشر'; END IF;
    ELSE
      RAISE EXCEPTION 'منشئ الصرف المباشر غير مخول بإنشاء إذن الصرف';
    END IF;

    SELECT * INTO v_rep
    FROM public.users u
    WHERE u.id=p_rep_id
      AND u.company_id=p_company_id
      AND coalesce(u.status,'Active')='Active'
      AND u.role='مندوب بيع مباشر'
      AND COALESCE(u.permissions,'[]'::jsonb) @> '["van-sales"]'::jsonb;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'مندوب البيع المباشر غير صالح ضمن الشركة';
    END IF;

    IF p_to_id IS NULL THEN
      SELECT a.vehicle_id INTO p_to_id
      FROM public.fleet_vehicle_sales_rep_assignments a
      JOIN public.vehicles v ON v.id=a.vehicle_id AND v.company_id=p_company_id
      WHERE a.company_id=p_company_id
        AND a.sales_rep_user_id=p_rep_id
        AND a.end_at IS NULL
        AND a.is_primary=true
        AND coalesce(v.status,'Active')='Active'
        AND coalesce(v.mobile_stock_enabled,true)=true
      ORDER BY a.start_at DESC,a.created_at DESC,a.id DESC
      LIMIT 1;
      IF p_to_id IS NULL THEN
        RAISE EXCEPTION 'لا توجد مركبة نشطة مرتبطة بمندوب البيع المباشر';
      END IF;
    END IF;

    IF v_actor.role='مندوب بيع مباشر' THEN
      p_rep_id:=v_actor.id;
    ELSIF coalesce(v_actor.active_warehouse_role,'')='أذونات'
       OR (
         v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
         AND coalesce(v_actor.active_warehouse_role,'')='مخزن شامل'
         AND coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
       ) THEN
      NULL;
    ELSE
      RAISE EXCEPTION 'منشئ الصرف المباشر غير مخول بإنشاء إذن الصرف';
    END IF;

    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_to_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'المركبة الوجهة غير مهيأة كمخزن متنقل';
    END IF;

    IF v_rep.default_branch_id IS NOT NULL THEN
      v_allowed:=v_rep.default_branch_id=p_from_id;
    ELSE
      v_allowed:=NULLIF(btrim(v_rep.allowed_branch_ids::text),'') IS NULL OR v_rep.allowed_branch_ids='[]'::jsonb;
    END IF;
    IF NOT v_allowed THEN
      SELECT EXISTS(
        SELECT 1 FROM public.branches b WHERE b.id=p_from_id AND b.company_id=p_company_id AND (
          (jsonb_typeof(v_rep.allowed_branch_ids)='array' AND (v_rep.allowed_branch_ids @> jsonb_build_array(b.branch_code) OR v_rep.allowed_branch_ids @> jsonb_build_array(b.id::text)))
          OR
          (jsonb_typeof(v_rep.allowed_branch_ids)='string' AND lower(trim(both '"' from v_rep.allowed_branch_ids::text))=lower(b.branch_code))
        )
      ) INTO v_allowed;
    END IF;
    IF NOT v_allowed THEN
      RAISE EXCEPTION 'الفرع المصدر غير مسموح لمندوب البيع المباشر';
    END IF;

  ELSIF p_type='DirectReturn' THEN
    IF p_from_type<>'Vehicle'
       OR p_from_id IS NULL
       OR p_to_type<>'Branch'
       OR p_to_id IS NULL THEN
      RAISE EXCEPTION 'المرتجع المباشر يتطلب مركبة مصدر وفرع وجهة';
    END IF;

    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_from_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'المركبة المصدر غير موجودة أو غير نشطة أو ليست مهيأة كمخزن متنقل';
    END IF;

    IF NOT (
      (
        v_vehicle.mobile_branch_id IS NOT NULL
        AND EXISTS(
          SELECT 1
          FROM public.branches b
          WHERE b.id=v_vehicle.mobile_branch_id
            AND b.company_id=p_company_id
            AND b.is_active=true
        )
      )
      OR EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.company_id=p_company_id
          AND upper(b.branch_code)=upper('VAN-'||v_vehicle.vehicle_code)
          AND b.is_active=true
      )
    ) THEN
      RAISE EXCEPTION 'المركبة المصدر ليست مهيأة كمخزن متنقل صالح';
    END IF;

    IF p_rep_id IS NULL THEN
      RAISE EXCEPTION 'مندوب البيع المباشر مطلوب';
    END IF;

    IF NOT (
      EXISTS(
        SELECT 1
        FROM public.fleet_vehicle_sales_rep_assignments a
        WHERE a.company_id=p_company_id
          AND a.vehicle_id=p_from_id
          AND a.sales_rep_user_id=p_rep_id
          AND a.end_at IS NULL
          AND a.is_primary=true
      )
      OR EXISTS(
        SELECT 1
        FROM public.vehicles v
        WHERE v.id=p_from_id
          AND v.company_id=p_company_id
          AND v.driver_id=p_rep_id
      )
    ) THEN
      RAISE EXCEPTION 'المركبة المصدر لا تتبع مندوب البيع المباشر المحدد';
    END IF;

  ELSIF p_type='SupplierReturn' THEN
    IF p_from_type<>'Branch'
       OR p_from_id IS NULL
       OR p_to_type<>'Supplier'
       OR p_to_id IS NULL THEN
      RAISE EXCEPTION 'مرتجع المورد يتطلب فرع مصدر ومورد وجهة';
    END IF;

    IF NOT EXISTS(
      SELECT 1
      FROM public.suppliers s
      WHERE s.id=p_to_id
        AND s.company_id=p_company_id
        AND coalesce(s.is_active,true)
    ) THEN
      RAISE EXCEPTION 'المورد غير موجود أو غير نشط ضمن الشركة';
    END IF;

    -- SupplierReturn is a standalone warehouse operation.
    -- Supplier master is the authoritative destination; purchase-order history
    -- must not block a physical return that is intentionally independent of orders.
  END IF;

  IF p_from_type='Branch'
     AND NOT EXISTS(
       SELECT 1
       FROM public.branches b
       WHERE b.id=p_from_id
         AND b.company_id=p_company_id
     ) THEN
    RAISE EXCEPTION 'فرع المصدر غير موجود أو لا يتبع الشركة الحالية';
  END IF;

  IF p_from_type='Vehicle' THEN
    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_from_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'المركبة المصدر غير موجودة أو غير نشطة';
    END IF;

    IF NOT (
      (
        v_vehicle.mobile_branch_id IS NOT NULL
        AND EXISTS(
          SELECT 1
          FROM public.branches b
          WHERE b.id=v_vehicle.mobile_branch_id
            AND b.company_id=p_company_id
            AND b.is_active=true
        )
      )
      OR EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.company_id=p_company_id
          AND upper(b.branch_code)=upper('VAN-'||v_vehicle.vehicle_code)
          AND b.is_active=true
      )
    ) THEN
      RAISE EXCEPTION 'المركبة المصدر غير مهيأة كمخزن متنقل';
    END IF;
  END IF;

  IF p_to_type='Branch'
     AND NOT EXISTS(
       SELECT 1
       FROM public.branches b
       WHERE b.id=p_to_id
         AND b.company_id=p_company_id
     ) THEN
    RAISE EXCEPTION 'فرع الوجهة غير موجود أو لا يتبع الشركة الحالية';
  END IF;

  IF p_to_type='Vehicle' THEN
    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_to_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'المركبة الوجهة غير موجودة أو غير نشطة';
    END IF;

    IF NOT (
      (
        v_vehicle.mobile_branch_id IS NOT NULL
        AND EXISTS(
          SELECT 1
          FROM public.branches b
          WHERE b.id=v_vehicle.mobile_branch_id
            AND b.company_id=p_company_id
            AND b.is_active=true
        )
      )
      OR EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.company_id=p_company_id
          AND upper(b.branch_code)=upper('VAN-'||v_vehicle.vehicle_code)
          AND b.is_active=true
      )
    ) THEN
      RAISE EXCEPTION 'المركبة الوجهة غير مهيأة كمخزن متنقل';
    END IF;
  END IF;

  v_fingerprint:=md5(
    jsonb_build_object(
      'type',p_type,
      'reference',btrim(p_reference),
      'from_type',p_from_type,
      'from_id',p_from_id,
      'to_type',p_to_type,
      'to_id',p_to_id,
      'notes',coalesce(p_notes,''),
      'rep_id',p_rep_id,
      'items',p_items
    )::text
  );

  IF NULLIF(btrim(p_operation_id),'') IS NOT NULL THEN
    SELECT * INTO v_existing
    FROM public.stock_voucher_operations
    WHERE company_id=p_company_id
      AND operation_id=btrim(p_operation_id)
    FOR UPDATE;

    IF FOUND THEN
      IF v_existing.fingerprint<>v_fingerprint THEN
        RAISE EXCEPTION 'operation_id مستخدم مع بيانات مختلفة';
      END IF;

      IF v_existing.voucher_id IS NOT NULL THEN
        RETURN jsonb_build_object(
          'success',true,
          'duplicate',true,
          'voucher_id',v_existing.voucher_id,
          'voucher_code',(
            SELECT voucher_code
            FROM public.stock_vouchers
            WHERE id=v_existing.voucher_id
          ),
          'company_id',p_company_id,
          'rep_id',p_rep_id,
          'operation_id',btrim(p_operation_id)
        );
      END IF;
    ELSE
      INSERT INTO public.stock_voucher_operations(
        company_id,operation_id,fingerprint
      )
      VALUES(
        p_company_id,btrim(p_operation_id),v_fingerprint
      );
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtext('rawaea:stock-voucher-code')
  );

  SELECT coalesce(
    max(substring(voucher_code from '[0-9]+$')::bigint),
    0
  )
  INTO v_last_num
  FROM public.stock_vouchers
  WHERE company_id=p_company_id;

  v_voucher_code:='IN-'||(v_last_num+1)::text;

  INSERT INTO public.stock_vouchers(
    voucher_code,
    voucher_date,
    type,
    status,
    reference,
    from_type,
    from_id,
    to_type,
    to_id,
    notes,
    custodian_user_id,
    created_by,
    source,
    company_id
  )
  VALUES(
    v_voucher_code,
    current_date,
    p_type,
    'Draft',
    btrim(p_reference),
    p_from_type,
    p_from_id,
    p_to_type,
    p_to_id,
    coalesce(p_notes,''),
    CASE
      WHEN p_type IN ('DirectSale','DirectReturn') THEN p_rep_id
      ELSE NULL
    END,
    p_created_by,
    'Manual',
    p_company_id
  )
  RETURNING id INTO v_voucher_id;

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_items)
  LOOP
    IF coalesce(nullif(v_item->>'itemCode',''),'')='' THEN
      RAISE EXCEPTION 'كود الصنف مطلوب';
    END IF;

    IF coalesce((v_item->>'qty')::numeric,0)<=0 THEN
      RAISE EXCEPTION 'كمية الصنف يجب أن تكون أكبر من صفر';
    END IF;

    SELECT i.id INTO v_item_id
    FROM public.items i
    WHERE i.item_code=v_item->>'itemCode';

    IF v_item_id IS NULL THEN
      RAISE EXCEPTION 'الصنف غير موجود: %',v_item->>'itemCode';
    END IF;

    IF EXISTS(
      SELECT 1
      FROM public.stock_voucher_details d
      WHERE d.voucher_id=v_voucher_id
        AND d.item_id=v_item_id
    ) THEN
      RAISE EXCEPTION 'لا يمكن تكرار الصنف داخل نفس الإذن: %',v_item->>'itemCode';
    END IF;

    INSERT INTO public.stock_voucher_details(
      voucher_id,
      item_id,
      item_code,
      item_name,
      unit,
      qty,
      unit_price,
      notes
    )
    VALUES(
      v_voucher_id,
      v_item_id,
      v_item->>'itemCode',
      coalesce(
        nullif(v_item->>'itemName',''),
        v_item->>'itemCode'
      ),
      coalesce(
        nullif(v_item->>'unit',''),
        'حبة'
      ),
      (v_item->>'qty')::numeric,
      coalesce(
        (v_item->>'unitPrice')::numeric,
        0
      ),
      coalesce(
        v_item->>'notes',
        ''
      )
    );
  END LOOP;

  IF NULLIF(btrim(p_operation_id),'') IS NOT NULL THEN
    UPDATE public.stock_voucher_operations
    SET voucher_id=v_voucher_id
    WHERE company_id=p_company_id
      AND operation_id=btrim(p_operation_id);
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'voucher_id',v_voucher_id,
    'voucher_code',v_voucher_code,
    'company_id',p_company_id,
    'rep_id',p_rep_id,
    'operation_id',nullif(btrim(p_operation_id),'')
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.post_manual_stock_voucher_atomic(p_company_id uuid, p_voucher_code text, p_operation text, p_user_email text, p_effects jsonb, p_operation_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.users%rowtype;
  v_allowed boolean;
  v_voucher public.stock_vouchers%rowtype;
  v_is_transfer boolean:=false;
  v_result jsonb;
  v_custodian_email text;
  v_credit_value numeric:=0;
  v_driver_operation uuid;
  v_hash text;
begin
  perform set_config('app.user_email',coalesce(p_user_email,''),true);
  perform set_config('app.operation_id',coalesce(btrim(p_operation_id),''),true);

  select * into v_actor
  from public.users u
  where u.company_id=p_company_id and lower(u.email)=lower(p_user_email)
    and coalesce(u.status,'Active')='Active'
  limit 1;
  if not found then raise exception 'سياق الشركة غير متسق مع المستخدم المنفذ'; end if;

  select type='Transfer'
  into v_is_transfer
  from public.stock_vouchers
  where company_id=p_company_id and voucher_code=p_voucher_code
  limit 1;

  if not (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    or v_actor.allowed_branch_ids is null
    or v_actor.allowed_branch_ids='[]'::jsonb
    or coalesce(trim(both '"' from v_actor.allowed_branch_ids::text),'')='*'
    or (
      v_is_transfer
      and v_actor.role='مخزني'
      and coalesce(v_actor.active_warehouse_role,'')='أذونات'
    )
  ) then
    select not exists(
      select 1 from jsonb_to_recordset(p_effects) as x(branch_id uuid)
      where not exists(
        select 1 from public.branches b
        where b.id=x.branch_id and b.company_id=p_company_id
          and (
            (jsonb_typeof(v_actor.allowed_branch_ids)='array' and (
              v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
              or v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
            ))
            or
            (jsonb_typeof(v_actor.allowed_branch_ids)='string'
             and trim(both '"' from v_actor.allowed_branch_ids::text) in (b.branch_code,b.id::text,'*'))
          )
      )
    ) into v_allowed;
    if not v_allowed then raise exception 'أحد فروع الحركة خارج نطاق فروع المستخدم المسموح بها'; end if;
  end if;

  select * into v_voucher from public.stock_vouchers
  where company_id=p_company_id and voucher_code=p_voucher_code
  limit 1;
  if not found then raise exception 'الإذن غير موجود'; end if;

  /*
   * Transfer receiving is a bound custody operation.
   * The receiver is assigned atomically when the transfer is sent.
   * Every partial/full RECEIVE must be executed by that exact user;
   * checking only the final Sent->Received transition is insufficient
   * because partial receives legitimately keep the voucher in Sent.
   */
  if p_operation='RECEIVE' and v_voucher.type='Transfer' then
    if v_voucher.receiver_user_id is null
       or v_actor.id is distinct from v_voucher.receiver_user_id then
      raise exception 'لا يملك هذا المستخدم مسؤولية استلام تحويل الفرع';
    end if;
  end if;

  /*
   * DirectReturn receiving is a warehouse-custody operation.
   * UI hiding is not sufficient because the receive Edge executes
   * through the service role. Enforce the same responsibility contract
   * in the existing central RPC before any stock mutation.
   */
  if p_operation='RECEIVE' and v_voucher.type='DirectReturn' then
    if not (
      coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
      or v_actor.role in ('مدير النظام','مدير عام','مدير مخازن','مشرف مخازن')
    ) then
      if v_actor.role not in ('مخزني','أمين مخزن','امين مخزن')
         or coalesce(v_actor.active_warehouse_role,'') not in ('أذونات','مخزن شامل')
         or (
           coalesce(v_actor.active_warehouse_role,'')='مخزن شامل'
           and not (coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb)
         ) then
        raise exception 'لا يملك هذا المستخدم صلاحية استلام المرتجع المباشر';
      end if;

      if v_voucher.to_type<>'Branch'
         or v_voucher.to_id is null then
        raise exception 'وجهة المرتجع المباشر غير صالحة';
      end if;

      if not exists (
        select 1
        from public.branches b
        where b.id=v_voucher.to_id
          and b.company_id=p_company_id
          and b.is_active=true
          and (
            v_actor.default_branch_id=b.id
            or v_actor.allowed_branch_ids is null
            or v_actor.allowed_branch_ids='[]'::jsonb
            or coalesce(trim(both '"' from v_actor.allowed_branch_ids::text),'')='*'
            or (
              jsonb_typeof(v_actor.allowed_branch_ids)='array'
              and (
                v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
                or v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
              )
            )
            or (
              jsonb_typeof(v_actor.allowed_branch_ids)='string'
              and trim(both '"' from v_actor.allowed_branch_ids::text)
                  in (b.id::text,b.branch_code,'*')
            )
          )
      ) then
        raise exception 'فرع المرتجع المباشر خارج نطاق مسؤول المستخدم';
      end if;
    end if;
  end if;

  v_result:=public.post_manual_stock_voucher_atomic_core_20260828(
    p_company_id,p_voucher_code,p_operation,p_user_email,p_effects,p_operation_id
  );
  if coalesce((v_result->>'duplicate')::boolean,false) then return v_result; end if;

  if p_operation='RECEIVE' and v_voucher.type='DirectReturn' then
    if v_voucher.custodian_user_id is null then raise exception 'DirectReturn custodian context missing'; end if;

    select u.email into v_custodian_email
    from public.users u
    where u.id=v_voucher.custodian_user_id and u.company_id=p_company_id
      and coalesce(u.status,'Active')='Active' and u.role='مندوب بيع مباشر';
    if v_custodian_email is null then raise exception 'مندوب عهدة DirectReturn غير صالح'; end if;

    select coalesce(sum(
      x.qty * coalesce(NULLIF(svd.unit_price,0),i.sales_price,i.cost_price,0)
    ),0) into v_credit_value
    from jsonb_to_recordset(p_effects) as x(direction text,branch_id uuid,item_id uuid,item_code text,qty numeric)
    join public.stock_voucher_details svd
      on svd.voucher_id=v_voucher.id and svd.item_id=x.item_id and svd.item_code=x.item_code
    join public.items i on i.id=x.item_id;

    if v_credit_value>0 then
      v_hash:=md5('VoucherCustodyCredit:'||p_company_id::text||':'||v_voucher.id::text||':'||coalesce(btrim(p_operation_id),''));
      v_driver_operation:=(
        substr(v_hash,1,8)||'-'||substr(v_hash,9,4)||'-'||substr(v_hash,13,4)||'-'||substr(v_hash,17,4)||'-'||substr(v_hash,21,12)
      )::uuid;

      perform public.post_driver_ledger_entry(
        p_company_id,v_driver_operation,v_custodian_email,current_date,p_voucher_code,
        'تخفيض عهدة مرتجع مباشر – '||p_voucher_code,0,v_credit_value
      );

      v_result:=v_result||jsonb_build_object(
        'custody_ledger',true,'custody_credit',v_credit_value,'custodian_user_id',v_voucher.custodian_user_id
      );
    end if;
  end if;

  return v_result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_manual_stock_voucher_atomic(p_company_id uuid, p_type text, p_reference text, p_from_type text, p_from_id uuid, p_to_type text, p_to_id uuid, p_notes text, p_created_by text, p_items jsonb, p_rep_id uuid, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_rep public.users%ROWTYPE;
  v_branch_id uuid;
  v_ok boolean;
  v_admin_override boolean := false;
  v_home_branch uuid;
  v_home_count integer:=0;
BEGIN
  PERFORM set_config('app.user_email',coalesce(p_created_by,''),true);
  PERFORM set_config('app.operation_id',coalesce(btrim(p_operation_id),''),true);

  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(p_created_by)
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'منشئ الإذن غير صالح ضمن الشركة';
  END IF;

  v_home_branch:=v_actor.default_branch_id;
  IF v_home_branch IS NULL THEN
    IF jsonb_typeof(v_actor.allowed_branch_ids)='array'
       AND jsonb_array_length(v_actor.allowed_branch_ids)=1 THEN
      SELECT count(*),min(b.id::text)::uuid INTO v_home_count,v_home_branch
      FROM public.branches b
      WHERE b.company_id=p_company_id AND coalesce(b.is_active,true)=true
        AND (
          v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
          OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
        );
    ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string'
          AND trim(both '"' from v_actor.allowed_branch_ids::text)<>'' THEN
      SELECT count(*),min(b.id::text)::uuid INTO v_home_count,v_home_branch
      FROM public.branches b
      WHERE b.company_id=p_company_id AND coalesce(b.is_active,true)=true
        AND trim(both '"' from v_actor.allowed_branch_ids::text) IN (b.branch_code,b.id::text);
    END IF;
    IF v_home_count<>1 THEN v_home_branch:=NULL; END IF;
  END IF;

  v_admin_override :=
    v_actor.role IN ('مدير النظام','مدير عام')
    OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '[ "*" ]'::jsonb;

  /*
   * Transfer source is the exact home/default branch of a warehouse keeper.
   * Destination remains freely selectable and is resolved to a receiver on Send.
   */
  IF p_type='Transfer'
     AND p_from_type='Branch'
     AND NOT v_admin_override
     AND v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
     AND COALESCE(v_actor.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
  THEN
    IF p_from_id IS NULL
       OR v_home_branch IS NULL
       OR p_from_id IS DISTINCT FROM v_home_branch
    THEN
      RAISE EXCEPTION 'فرع مصدر التحويل يجب أن يطابق الفرع الأساسي لمسؤول المخزن';
    END IF;
  END IF;

  IF p_type IN('DirectSale','DirectReturn') THEN
    IF p_rep_id IS NULL THEN
      RAISE EXCEPTION 'مندوب البيع المباشر مطلوب';
    END IF;

    SELECT * INTO v_rep
    FROM public.users u
    WHERE u.company_id=p_company_id
      AND u.id=p_rep_id
      AND coalesce(u.status,'Active')='Active'
      AND u.role='مندوب بيع مباشر'
      AND coalesce(u.permissions,'[]'::jsonb) @> '["van-sales"]'::jsonb
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'مندوب البيع المباشر غير صالح أو لا يملك صلاحية تطبيق البيع المباشر';
    END IF;
  END IF;

  IF NOT(
    coalesce(v_actor.permissions,'[]'::jsonb) @> '[ "*" ]'::jsonb
    OR v_actor.allowed_branch_ids IS NULL
    OR v_actor.allowed_branch_ids='[]'::jsonb
    OR coalesce(trim(both '"' from v_actor.allowed_branch_ids::text),'')='*'
    OR (
      p_type IN('Transfer','DirectReturn')
      AND v_actor.role='مخزني'
      AND coalesce(v_actor.active_warehouse_role,'')='أذونات'
      AND p_to_type='Branch'
    )
  ) THEN
    IF p_type='Transfer' THEN
      /*
       * Legacy/general scoped users keep their existing branch-scope contract.
       * The dedicated warehouse keeper exact-source rule was already enforced above.
       */
      IF NOT (
        v_actor.role IN ('مخزني','أمين مخزن','امين مخزن')
        AND coalesce(v_actor.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
      ) THEN
        FOR v_branch_id IN SELECT unnest(array[p_from_id,p_to_id]) LOOP
          SELECT EXISTS(
            SELECT 1
            FROM public.branches b
            WHERE b.id=v_branch_id
              AND b.company_id=p_company_id
              AND (
                (
                  jsonb_typeof(v_actor.allowed_branch_ids)='array'
                  AND (
                    v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                    OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
                  )
                )
                OR
                (
                  jsonb_typeof(v_actor.allowed_branch_ids)='string'
                  AND trim(both '"' from v_actor.allowed_branch_ids::text)
                    IN(b.branch_code,b.id::text,'*')
                )
              )
          ) INTO v_ok;

          IF NOT v_ok THEN
            RAISE EXCEPTION 'الفرع خارج نطاق فروع المستخدم المسموح بها';
          END IF;
        END LOOP;
      END IF;

    ELSIF p_type IN('DirectSale','SupplierReturn') THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.id=p_from_id
          AND b.company_id=p_company_id
          AND (
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='array'
              AND (
                v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='string'
              AND trim(both '"' from v_actor.allowed_branch_ids::text)
                IN(b.branch_code,b.id::text,'*')
            )
          )
      ) INTO v_ok;

      IF NOT v_ok THEN
        RAISE EXCEPTION 'فرع المصدر خارج نطاق فروع المستخدم المسموح بها';
      END IF;

    ELSIF p_type='DirectReturn' THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.id=p_to_id
          AND b.company_id=p_company_id
          AND (
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='array'
              AND (
                v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='string'
              AND trim(both '"' from v_actor.allowed_branch_ids::text)
                IN(b.branch_code,b.id::text,'*')
            )
          )
      ) INTO v_ok;

      IF NOT v_ok THEN
        RAISE EXCEPTION 'فرع استلام المرتجع المباشر خارج نطاق فروع المستخدم المسموح بها';
      END IF;
    END IF;
  END IF;

  RETURN public.create_manual_stock_voucher_atomic_core_12_20260828(
    p_company_id,p_type,p_reference,p_from_type,p_from_id,p_to_type,p_to_id,
    p_notes,p_created_by,p_items,p_rep_id,p_operation_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_transfer_responsibility_contract()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  actor public.users%ROWTYPE;
  actor_email text;
  actor_id uuid;
  receiver_id uuid;
  receiver_count integer;
  branch_code text;
  admin_override boolean := false;
  source_scope_ok boolean := false;
  v_receiver_home_branch uuid;
BEGIN
  IF COALESCE(OLD.type, NEW.type) <> 'Transfer' THEN
    RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
  END IF;

  actor_email := NULLIF(BTRIM(current_setting('app.user_email', true)), '');

  IF actor_email IS NOT NULL THEN
    SELECT * INTO actor
    FROM public.users u
    WHERE u.company_id = COALESCE(OLD.company_id, NEW.company_id)
      AND lower(u.email) = lower(actor_email)
      AND COALESCE(u.status,'Active')='Active'
    LIMIT 1;
  ELSIF auth.uid() IS NOT NULL THEN
    SELECT * INTO actor
    FROM public.users u
    WHERE u.company_id = COALESCE(OLD.company_id, NEW.company_id)
      AND u.auth_id = auth.uid()
      AND COALESCE(u.status,'Active')='Active'
    LIMIT 1;
  END IF;

  IF FOUND THEN
    actor_id := actor.id;
    admin_override :=
      actor.role IN ('مدير النظام','مدير عام')
      OR COALESCE(actor.permissions,'[]'::jsonb) @> '[ "*" ]'::jsonb;
  END IF;

  IF actor_id IS NULL THEN
    IF auth.uid() IS NULL AND actor_email IS NULL THEN
      RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
    END IF;
    RAISE EXCEPTION 'هوية منفذ العملية غير صالحة';
  END IF;

  IF TG_OP='DELETE' THEN
    IF OLD.status <> 'Draft' THEN
      RAISE EXCEPTION 'لا يمكن حذف تحويل بعد إرساله';
    END IF;
    IF NOT admin_override
       AND lower(COALESCE(OLD.created_by,'')) <> lower(COALESCE(actor.email,'')) THEN
      RAISE EXCEPTION 'حذف تحويل الفرع متاح لمنشئ الإذن فقط';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP<>'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.request_origin IS DISTINCT FROM OLD.request_origin THEN
    RAISE EXCEPTION 'مصدر طلب الإذن غير قابل للتغيير بعد الإنشاء';
  END IF;

  IF NEW.receiver_user_id IS DISTINCT FROM OLD.receiver_user_id
     AND NOT (OLD.status='Draft' AND NEW.status='Sent') THEN
    RAISE EXCEPTION 'مسؤول الاستلام لا يمكن تغييره بعد تثبيته';
  END IF;

  IF OLD.status='Draft' THEN
    IF OLD.request_origin='WarehouseBranchReceipt' THEN
      IF NEW.type<>'Transfer'
         OR NEW.from_type<>'Branch'
         OR NEW.to_type<>'Branch'
         OR NEW.from_id IS DISTINCT FROM OLD.from_id
         OR NEW.to_id IS DISTINCT FROM OLD.to_id
         OR NEW.receiver_user_id IS DISTINCT FROM OLD.receiver_user_id
      THEN
        RAISE EXCEPTION 'طلب الاستلام لا يسمح بتغيير المصدر أو الوجهة أو مسؤول الاستلام';
      END IF;

      IF NEW.status='Sent' THEN
        IF NOT admin_override THEN
          source_scope_ok :=
            NEW.from_id IS NOT NULL
            AND (
              actor.default_branch_id=NEW.from_id
              OR actor.allowed_branch_ids IS NULL
              OR actor.allowed_branch_ids='[]'::jsonb
              OR COALESCE(TRIM(BOTH '"' FROM actor.allowed_branch_ids::text),'')='*'
              OR EXISTS (
                SELECT 1 FROM public.branches sb
                WHERE sb.id=NEW.from_id AND sb.company_id=NEW.company_id
                  AND (
                    (
                      jsonb_typeof(actor.allowed_branch_ids)='array'
                      AND (
                        actor.allowed_branch_ids @> jsonb_build_array(sb.branch_code)
                        OR actor.allowed_branch_ids @> jsonb_build_array(sb.id::text)
                      )
                    )
                    OR (
                      jsonb_typeof(actor.allowed_branch_ids)='string'
                      AND TRIM(BOTH '"' FROM actor.allowed_branch_ids::text)
                          IN (sb.branch_code,sb.id::text,'*')
                    )
                  )
              )
            );
          IF NOT source_scope_ok THEN
            RAISE EXCEPTION 'مرسل طلب الاستلام غير مخول للعمل على فرع المصدر';
          END IF;
        END IF;

        IF NEW.receiver_user_id IS NULL OR NEW.receiver_user_id=actor.id THEN
          RAISE EXCEPTION 'مسؤول الاستلام المثبت غير صالح';
        END IF;

        SELECT b.id INTO v_receiver_home_branch
        FROM public.users ru
        JOIN public.branches b
          ON b.id=NEW.to_id AND b.company_id=NEW.company_id AND b.is_active=true
        WHERE ru.id=NEW.receiver_user_id
          AND ru.company_id=NEW.company_id
          AND COALESCE(ru.status,'Active')='Active'
          AND ru.role IN ('مخزني','أمين مخزن','امين مخزن')
          AND COALESCE(ru.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
          AND (
            ru.default_branch_id=b.id
            OR (
              ru.default_branch_id IS NULL
              AND (
                (
                  jsonb_typeof(ru.allowed_branch_ids)='array'
                  AND jsonb_array_length(ru.allowed_branch_ids)=1
                  AND (
                    ru.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                    OR ru.allowed_branch_ids @> jsonb_build_array(b.id::text)
                  )
                )
                OR (
                  jsonb_typeof(ru.allowed_branch_ids)='string'
                  AND trim(both '"' from ru.allowed_branch_ids::text) IN (b.branch_code,b.id::text)
                )
              )
            )
          )
          AND (
            ru.allowed_branch_ids IS NULL
            OR ru.allowed_branch_ids='[]'::jsonb
            OR COALESCE(TRIM(BOTH '"' FROM ru.allowed_branch_ids::text),'')='*'
            OR (
              jsonb_typeof(ru.allowed_branch_ids)='array'
              AND (
                ru.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR ru.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR (
              jsonb_typeof(ru.allowed_branch_ids)='string'
              AND TRIM(BOTH '"' FROM ru.allowed_branch_ids::text)
                  IN (b.branch_code,b.id::text,'*')
            )
          )
        LIMIT 1;

        IF v_receiver_home_branch IS NULL THEN
          RAISE EXCEPTION 'مسؤول الاستلام غير مرتبط بفرع الوجهة أو غير نشط';
        END IF;

        NEW.receiver_assigned_at:=COALESCE(OLD.receiver_assigned_at,now());
        RETURN NEW;
      END IF;

      IF NOT admin_override
         AND lower(COALESCE(OLD.created_by,'')) <> lower(COALESCE(actor.email,'')) THEN
        RAISE EXCEPTION 'طلب الاستلام في المسودة متاح لمنشئ الطلب أو الإدارة فقط';
      END IF;

      RETURN NEW;
    END IF;
    IF NOT admin_override
       AND lower(COALESCE(OLD.created_by,'')) <> lower(COALESCE(actor.email,'')) THEN
      RAISE EXCEPTION 'تحويل الفرع في المسودة لا يعدله أو يرسله إلا منشئه';
    END IF;

    /*
     * Warehouse keeper source branch is immutable to the keeper's home branch
     * throughout the whole Draft lifecycle, not only at Send.
     */
    IF NOT admin_override
       AND actor.role='مخزني'
       AND COALESCE(actor.active_warehouse_role,'')='أذونات'
       AND (
         NEW.from_type<>'Branch'
         OR NEW.from_id IS NULL
         OR actor.default_branch_id IS NULL
         OR actor.default_branch_id IS DISTINCT FROM NEW.from_id
       ) THEN
      RAISE EXCEPTION 'فرع مصدر التحويل يجب أن يطابق الفرع الأساسي لمسؤول المخزن';
    END IF;

    IF NEW.status='Sent' THEN
      IF NEW.from_type<>'Branch' OR NEW.to_type<>'Branch' THEN
        RAISE EXCEPTION 'تحويل الفرع يجب أن يكون من فرع إلى فرع';
      END IF;

      /*
       * Source responsibility:
       * - warehouse keeper "أذونات": exact default/home branch only.
       * - other non-admin actors: preserve the existing allowed-branch contract.
       * Destination is intentionally NOT constrained to sender scope here.
       */
      IF NOT admin_override THEN
        IF actor.role='مخزني'
           AND COALESCE(actor.active_warehouse_role,'')='أذونات' THEN
          source_scope_ok :=
            NEW.from_id IS NOT NULL
            AND actor.default_branch_id IS NOT NULL
            AND actor.default_branch_id=NEW.from_id;
        ELSE
          source_scope_ok :=
            NEW.from_id IS NOT NULL
            AND (
              actor.default_branch_id = NEW.from_id
              OR actor.allowed_branch_ids IS NULL
              OR actor.allowed_branch_ids='[]'::jsonb
              OR COALESCE(TRIM(BOTH '"' FROM actor.allowed_branch_ids::text),'')='*'
              OR EXISTS (
                SELECT 1
                FROM public.branches sb
                WHERE sb.id=NEW.from_id
                  AND sb.company_id=NEW.company_id
                  AND (
                    (
                      jsonb_typeof(actor.allowed_branch_ids)='array'
                      AND (
                        actor.allowed_branch_ids @> jsonb_build_array(sb.branch_code)
                        OR actor.allowed_branch_ids @> jsonb_build_array(sb.id::text)
                      )
                    )
                    OR (
                      jsonb_typeof(actor.allowed_branch_ids)='string'
                      AND TRIM(BOTH '"' FROM actor.allowed_branch_ids::text)
                          IN (sb.branch_code,sb.id::text,'*')
                    )
                  )
              )
            );
        END IF;

        IF NOT source_scope_ok THEN
          RAISE EXCEPTION 'مرسل التحويل غير مخول للعمل على فرع المصدر';
        END IF;
      END IF;

      SELECT b.branch_code
      INTO branch_code
      FROM public.branches b
      WHERE b.id=NEW.to_id
        AND b.company_id=NEW.company_id
        AND b.is_active=true;

      IF branch_code IS NULL THEN
        RAISE EXCEPTION 'فرع الوجهة غير صالح';
      END IF;

      SELECT count(*)
      INTO receiver_count
      FROM public.users u
      WHERE u.company_id=NEW.company_id
        AND COALESCE(u.status,'Active')='Active'
        AND u.role IN ('مخزني','أمين مخزن','امين مخزن')
        AND COALESCE(u.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
        AND (
          u.default_branch_id=NEW.to_id
          OR (
            u.default_branch_id IS NULL
            AND (
              (
                jsonb_typeof(u.allowed_branch_ids)='array'
                AND jsonb_array_length(u.allowed_branch_ids)=1
                AND EXISTS (
                  SELECT 1 FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                    AND (
                      u.allowed_branch_ids @> jsonb_build_array(hb.branch_code)
                      OR u.allowed_branch_ids @> jsonb_build_array(hb.id::text)
                    )
                )
              )
              OR (
                jsonb_typeof(u.allowed_branch_ids)='string'
                AND trim(both '"' from u.allowed_branch_ids::text) IN (
                  SELECT hb.branch_code FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                  UNION
                  SELECT hb.id::text FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                )
              )
            )
          )
        )
        AND u.id<>actor.id
        AND (
          u.allowed_branch_ids IS NULL
          OR u.allowed_branch_ids='[]'::jsonb
          OR COALESCE(TRIM(BOTH '"' FROM u.allowed_branch_ids::text),'')='*'
          OR (
            jsonb_typeof(u.allowed_branch_ids)='array'
            AND (
              u.allowed_branch_ids @> jsonb_build_array(NEW.to_id::text)
              OR u.allowed_branch_ids @> jsonb_build_array(branch_code)
            )
          )
          OR (
            jsonb_typeof(u.allowed_branch_ids)='string'
            AND TRIM(BOTH '"' FROM u.allowed_branch_ids::text)
                IN (branch_code, NEW.to_id::text, '*')
          )
        );

      IF receiver_count=0 THEN
        RAISE EXCEPTION 'لا يوجد مسؤول استلام مخزني مفعّل ومحدد للفرع الوجهة';
      END IF;

      IF receiver_count>1 THEN
        RAISE EXCEPTION 'يوجد أكثر من مسؤول استلام للفرع الوجهة؛ عيّن مسؤولًا واحدًا من النظام الأم';
      END IF;

      SELECT u.id
      INTO receiver_id
      FROM public.users u
      WHERE u.company_id=NEW.company_id
        AND COALESCE(u.status,'Active')='Active'
        AND u.role IN ('مخزني','أمين مخزن','امين مخزن')
        AND COALESCE(u.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
        AND (
          u.default_branch_id=NEW.to_id
          OR (
            u.default_branch_id IS NULL
            AND (
              (
                jsonb_typeof(u.allowed_branch_ids)='array'
                AND jsonb_array_length(u.allowed_branch_ids)=1
                AND EXISTS (
                  SELECT 1 FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                    AND (
                      u.allowed_branch_ids @> jsonb_build_array(hb.branch_code)
                      OR u.allowed_branch_ids @> jsonb_build_array(hb.id::text)
                    )
                )
              )
              OR (
                jsonb_typeof(u.allowed_branch_ids)='string'
                AND trim(both '"' from u.allowed_branch_ids::text) IN (
                  SELECT hb.branch_code FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                  UNION
                  SELECT hb.id::text FROM public.branches hb
                  WHERE hb.id=NEW.to_id AND hb.company_id=NEW.company_id
                )
              )
            )
          )
        )
        AND u.id<>actor.id
        AND (
          u.allowed_branch_ids IS NULL
          OR u.allowed_branch_ids='[]'::jsonb
          OR COALESCE(TRIM(BOTH '"' FROM u.allowed_branch_ids::text),'')='*'
          OR (
            jsonb_typeof(u.allowed_branch_ids)='array'
            AND (
              u.allowed_branch_ids @> jsonb_build_array(NEW.to_id::text)
              OR u.allowed_branch_ids @> jsonb_build_array(branch_code)
            )
          )
          OR (
            jsonb_typeof(u.allowed_branch_ids)='string'
            AND TRIM(BOTH '"' FROM u.allowed_branch_ids::text)
                IN (branch_code, NEW.to_id::text, '*')
          )
        )
      LIMIT 1;

      IF receiver_id IS NULL OR receiver_id=actor.id THEN
        RAISE EXCEPTION 'مسؤول الاستلام غير صالح أو مطابق لمرسل التحويل';
      END IF;

      NEW.receiver_user_id:=receiver_id;
      NEW.receiver_assigned_at:=COALESCE(OLD.receiver_assigned_at,now());
    END IF;

    RETURN NEW;
  END IF;

  IF OLD.status='Sent' THEN
    IF NEW.status IN ('Sent','Received') THEN
      IF OLD.receiver_user_id IS NULL THEN
        RAISE EXCEPTION 'تحويل الفرع بلا مسؤول استلام مثبت';
      END IF;
      IF actor.id<>OLD.receiver_user_id THEN
        RAISE EXCEPTION 'لا يملك هذا المستخدم مسؤولية استلام تحويل الفرع';
      END IF;
    END IF;

    IF NEW.status='Cancelled'
       AND NOT admin_override
       AND actor.id<>OLD.receiver_user_id
       AND lower(COALESCE(OLD.created_by,''))<>lower(COALESCE(actor.email,'')) THEN
      RAISE EXCEPTION 'إلغاء التحويل المرسل غير مصرح لهذا المستخدم';
    END IF;

    RETURN NEW;
  END IF;

  IF OLD.status='Received' AND NEW.status='Completed' THEN
    IF NOT admin_override
       AND actor.role NOT IN ('مدير مخازن','مشرف مخازن')
       AND lower(COALESCE(OLD.created_by,''))<>lower(COALESCE(actor.email,'')) THEN
      RAISE EXCEPTION 'إكمال تحويل الفرع متاح لمنشئ الإذن أو للإدارة المخزنية';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

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
    ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string'
          AND trim(both '"' from v_actor.allowed_branch_ids::text)<>'' THEN
      SELECT count(*),min(b.id::text)::uuid INTO v_home_count,v_home_branch_id
      FROM public.branches b
      WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true)=true
        AND trim(both '"' from v_actor.allowed_branch_ids::text) IN (b.branch_code,b.id::text);
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