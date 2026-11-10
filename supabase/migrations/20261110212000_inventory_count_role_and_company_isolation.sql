-- Allow the dedicated inventory-count role to complete all three count workflows.
-- Keep the same branch scope guard as the unified warehouse role.
-- Fence every catalog lookup/population to the authenticated company.

CREATE OR REPLACE FUNCTION public.inventory_count_engine(p_company_id uuid, p_user_email text, p_operation text, p_payload jsonb DEFAULT '{}'::jsonb, p_operation_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_op text:=upper(btrim(coalesce(p_operation,'')));
  v_count public.inventory_counts%ROWTYPE;
  v_detail public.inventory_count_details%ROWTYPE;
  v_branch_id uuid;
  v_vehicle_id uuid;
  v_item_id uuid;
  v_item_code text;
  v_qty numeric;
  v_system_qty numeric;
  v_variance numeric;
  v_rows integer:=0;
  v_response jsonb;
  v_refresh_mode text:=upper(coalesce(p_payload->>'mode','UNCOUNTED'));
BEGIN
  SELECT * INTO v_actor FROM public.users u
  WHERE u.company_id=p_company_id AND lower(u.email)=lower(coalesce(p_user_email,'')) AND COALESCE(u.status,'Active')='Active' LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو غير نشط'; END IF;
  IF NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
    OR COALESCE(v_actor.active_warehouse_role,'') IN ('مخزن شامل','جرد')
    OR (v_op IN ('GET','LIST') AND COALESCE(v_actor.permissions,'[]'::jsonb) @> '["reports"]'::jsonb)
    OR (v_op IN ('CREATE','POPULATE') AND (COALESCE(v_actor.permissions,'[]'::jsonb) @> '["general-count"]'::jsonb OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["branch-count"]'::jsonb OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["vehicle-count"]'::jsonb))
  ) THEN RAISE EXCEPTION 'غير مصرح بإدارة الجرد'; END IF;

  IF v_op='CREATE' THEN
    IF NULLIF(btrim(p_operation_id),'') IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لإنشاء جلسة جرد'; END IF;
    IF EXISTS (SELECT 1 FROM public.inventory_counts c WHERE c.company_id=p_company_id AND c.operation_id=p_operation_id) THEN
      SELECT * INTO v_count FROM public.inventory_counts c WHERE c.company_id=p_company_id AND c.operation_id=p_operation_id FOR UPDATE;
      RETURN jsonb_build_object('success',true,'duplicate',true,'count_id',v_count.id,'status',v_count.status,'operation_id',p_operation_id);
    END IF;
    IF p_payload->>'type' NOT IN ('branch','vehicle','general') THEN RAISE EXCEPTION 'نوع الجرد يجب أن يكون branch أو vehicle أو general'; END IF;
    v_branch_id:=NULL;
    IF p_payload->>'type'='branch' THEN
      v_branch_id:=(p_payload->>'entity_id')::uuid;
      IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true)) THEN RAISE EXCEPTION 'فرع الجرد غير صالح'; END IF;
    ELSIF p_payload->>'type'='vehicle' THEN
      v_vehicle_id:=(p_payload->>'entity_id')::uuid;
      SELECT mobile_branch_id INTO v_branch_id
      FROM public.vehicles v
      WHERE v.id=v_vehicle_id
        AND v.company_id=p_company_id
        AND COALESCE(v.status,'Active')='Active'
        AND COALESCE(v.mobile_stock_enabled,true);
      IF v_branch_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.branches b
        WHERE b.id=v_branch_id
          AND b.company_id=p_company_id
          AND COALESCE(b.is_active,true)=true
      ) THEN
        RAISE EXCEPTION 'مخزون السيارة غير مهيأ على فرع نشط تابع للشركة';
      END IF;
      IF v_branch_id IS NULL THEN RAISE EXCEPTION 'مخزون السيارة غير مهيأ للجرد'; END IF;
    END IF;
    IF COALESCE(v_actor.active_warehouse_role,'') IN ('مخزن شامل','جرد') THEN
      IF p_payload->>'type'='general' THEN
        IF EXISTS (SELECT 1 FROM public.branches b WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true) AND NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,b.id)) THEN RAISE EXCEPTION 'الجرد العام يتضمن فروعًا خارج نطاق المستخدم'; END IF;
      ELSIF v_branch_id IS NULL OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_branch_id) THEN
        RAISE EXCEPTION 'فرع الجرد خارج نطاق المستخدم';
      END IF;
    END IF;
    INSERT INTO public.inventory_counts(type,entity_id,reference,created_by,company_id,status,count_date,branch_id,notes,operation_id,started_at,updated_at)
    VALUES(p_payload->>'type',CASE WHEN NULLIF(p_payload->>'entity_id','') IS NULL THEN NULL ELSE (p_payload->>'entity_id')::uuid END,COALESCE(p_payload->>'reference',''),p_user_email,p_company_id,'InProgress',COALESCE((p_payload->>'count_date')::date,current_date),v_branch_id,p_payload->>'notes',p_operation_id,now(),now()) RETURNING * INTO v_count;
    RETURN jsonb_build_object('success',true,'duplicate',false,'count_id',v_count.id,'status',v_count.status,'operation_id',p_operation_id);
  END IF;

  IF p_payload->>'count_id' IS NULL THEN RAISE EXCEPTION 'count_id مطلوب'; END IF;
  SELECT * INTO v_count FROM public.inventory_counts c WHERE c.id=(p_payload->>'count_id')::uuid AND c.company_id=p_company_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'جلسة الجرد غير موجودة'; END IF;
  IF COALESCE(v_actor.active_warehouse_role,'') IN ('مخزن شامل','جرد') THEN
    IF v_count.type = 'general' THEN
      IF EXISTS (SELECT 1 FROM public.branches b WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true) AND NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,b.id)) THEN RAISE EXCEPTION 'الجرد العام يتضمن فروعًا خارج نطاق المستخدم'; END IF;
    ELSIF v_count.branch_id IS NULL OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_count.branch_id) THEN
      RAISE EXCEPTION 'جلسة الجرد خارج نطاق الفروع المسموح بها للمستخدم';
    END IF;
  END IF;
  IF v_count.status IN ('Adjusted','Cancelled') AND v_op NOT IN ('GET','LIST') THEN RAISE EXCEPTION 'جلسة الجرد مغلقة'; END IF;

  IF v_op='GET' THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.branch_code,x.item_code),'[]'::jsonb) INTO v_response
    FROM (
      SELECT d.id,d.branch_id,b.branch_code,b.name AS branch_name,d.item_id,d.item_code,d.item_name,d.unit,d.system_qty,d.counted_qty,d.variance_qty,d.adjusted,d.notes,d.updated_at
      FROM public.inventory_count_details d LEFT JOIN public.branches b ON b.id=d.branch_id AND b.company_id=p_company_id WHERE d.count_id=v_count.id
    ) x;
    RETURN jsonb_build_object('success',true,'count',to_jsonb(v_count),'details',v_response);
  END IF;

  IF v_op='POPULATE' THEN
    IF v_count.type='general' THEN
      INSERT INTO public.inventory_count_details(count_id,branch_id,item_id,item_code,item_name,unit,system_qty,variance_qty,updated_at)
      SELECT v_count.id,b.id,i.id,i.item_code,i.name,i.unit,COALESCE(sb.qty,0),0,now()
      FROM public.branches b CROSS JOIN public.items i
      LEFT JOIN public.stock_branches sb ON sb.branch_id=b.id AND sb.item_id=i.id
      WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true)
        AND i.company_id=p_company_id
        AND COALESCE(i.is_active,true)
        AND NOT EXISTS (SELECT 1 FROM public.inventory_count_details d WHERE d.count_id=v_count.id AND d.branch_id=b.id AND d.item_id=i.id);
    ELSE
      v_branch_id:=v_count.branch_id;
      IF v_branch_id IS NULL THEN RAISE EXCEPTION 'فرع الجرد غير محدد'; END IF;
      INSERT INTO public.inventory_count_details(count_id,branch_id,item_id,item_code,item_name,unit,system_qty,variance_qty,updated_at)
      SELECT v_count.id,v_branch_id,i.id,i.item_code,i.name,i.unit,COALESCE(sb.qty,0),0,now()
      FROM public.items i
      LEFT JOIN public.stock_branches sb ON sb.branch_id=v_branch_id AND sb.item_id=i.id
      WHERE i.company_id=p_company_id
        AND COALESCE(i.is_active,true)
        AND NOT EXISTS (SELECT 1 FROM public.inventory_count_details d WHERE d.count_id=v_count.id AND d.branch_id=v_branch_id AND d.item_id=i.id);
    END IF;
    GET DIAGNOSTICS v_rows=ROW_COUNT;
    UPDATE public.inventory_counts SET updated_at=now() WHERE id=v_count.id;
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'added_lines',v_rows);
  END IF;

  IF v_op='UPSERT_LINE' THEN
    v_branch_id:=(p_payload->>'branch_id')::uuid;
    v_item_code:=btrim(p_payload->>'item_code');
    IF v_branch_id IS NULL OR NULLIF(v_item_code,'') IS NULL THEN RAISE EXCEPTION 'branch_id و item_code مطلوبان'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_branch_id AND b.company_id=p_company_id) THEN RAISE EXCEPTION 'الفرع غير صالح'; END IF;
    IF COALESCE(v_actor.active_warehouse_role,'') IN ('مخزن شامل','جرد') THEN
      IF NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_branch_id) THEN RAISE EXCEPTION 'فرع بند الجرد خارج نطاق المستخدم'; END IF;
      IF v_count.type<>'general' AND v_branch_id IS DISTINCT FROM v_count.branch_id THEN RAISE EXCEPTION 'فرع بند الجرد لا يطابق فرع جلسة الجرد'; END IF;
    END IF;
    SELECT i.id INTO v_item_id FROM public.items i WHERE i.company_id=p_company_id AND i.item_code=v_item_code;
    IF v_item_id IS NULL THEN RAISE EXCEPTION 'الصنف غير موجود: %',v_item_code; END IF;
    v_qty:=(p_payload->>'counted_qty')::numeric;
    IF v_qty IS NULL OR v_qty<0 THEN RAISE EXCEPTION 'الكمية الفعلية غير صالحة'; END IF;
    SELECT COALESCE(sb.qty,0) INTO v_system_qty FROM public.stock_branches sb WHERE sb.branch_id=v_branch_id AND sb.item_id=v_item_id;
    v_system_qty:=COALESCE(v_system_qty,0); v_variance:=v_qty-v_system_qty;
    INSERT INTO public.inventory_count_details(count_id,branch_id,item_id,item_code,item_name,unit,system_qty,counted_qty,variance_qty,notes,updated_at)
    SELECT v_count.id,v_branch_id,i.id,i.item_code,i.name,i.unit,v_system_qty,v_qty,v_variance,p_payload->>'notes',now() FROM public.items i WHERE i.id=v_item_id AND i.company_id=p_company_id
    ON CONFLICT(count_id,branch_id,item_id) DO UPDATE SET counted_qty=EXCLUDED.counted_qty,variance_qty=EXCLUDED.variance_qty,item_code=EXCLUDED.item_code,item_name=EXCLUDED.item_name,unit=EXCLUDED.unit,notes=EXCLUDED.notes,updated_at=now();
    UPDATE public.inventory_counts SET status='InProgress',updated_at=now() WHERE id=v_count.id;
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'branch_id',v_branch_id,'item_id',v_item_id,'item_code',v_item_code,'system_qty',v_system_qty,'counted_qty',v_qty,'variance_qty',v_variance);
  END IF;

  IF v_op='REFRESH' THEN
    IF v_refresh_mode NOT IN ('ALL','UNCOUNTED') THEN RAISE EXCEPTION 'mode يجب أن يكون ALL أو UNCOUNTED'; END IF;
    UPDATE public.inventory_count_details d
    SET system_qty=COALESCE(sb.qty,0),
        variance_qty=CASE WHEN d.counted_qty IS NULL THEN 0 ELSE d.counted_qty-COALESCE(sb.qty,0) END,
        updated_at=now()
    FROM public.stock_branches sb
    WHERE d.count_id=v_count.id AND sb.branch_id=d.branch_id AND sb.item_id=d.item_id
      AND (v_refresh_mode='ALL' OR d.counted_qty IS NULL);
    GET DIAGNOSTICS v_rows=ROW_COUNT;
    UPDATE public.inventory_counts SET updated_at=now() WHERE id=v_count.id;
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'refresh_mode',v_refresh_mode,'refreshed_lines',v_rows);
  END IF;

  IF v_op='FINALIZE' THEN
    IF NOT EXISTS (SELECT 1 FROM public.inventory_count_details d WHERE d.count_id=v_count.id) THEN RAISE EXCEPTION 'لا توجد بنود للجرد'; END IF;
    IF EXISTS (SELECT 1 FROM public.inventory_count_details d WHERE d.count_id=v_count.id AND d.counted_qty IS NULL) THEN RAISE EXCEPTION 'يوجد بند بدون كمية فعلية'; END IF;
    FOR v_detail IN SELECT * FROM public.inventory_count_details d WHERE d.count_id=v_count.id ORDER BY d.branch_id,d.item_id FOR UPDATE LOOP
      v_variance:=COALESCE(v_detail.counted_qty,0)-COALESCE(v_detail.system_qty,0);
      IF v_variance<>0 AND COALESCE(v_detail.adjusted,false)=false THEN
        PERFORM public.post_stock_movement(p_company_id,CASE WHEN v_variance>0 THEN 'InventoryIncrease' ELSE 'InventoryDecrease' END,CASE WHEN v_variance<0 THEN v_detail.branch_id ELSE NULL END,CASE WHEN v_variance>0 THEN v_detail.branch_id ELSE NULL END,v_detail.item_id,abs(v_variance),'COUNT-'||v_count.id::text,COALESCE(v_count.reference,'Inventory Count'),p_user_email,'InventoryCount:'||p_company_id::text||':'||v_count.id::text||':'||v_detail.branch_id::text||':'||v_detail.item_id::text);
      END IF;
      UPDATE public.inventory_count_details SET variance_qty=v_variance,adjusted=true,updated_at=now() WHERE id=v_detail.id;
    END LOOP;
    UPDATE public.inventory_counts SET status='Adjusted',completed_at=now(),updated_at=now() WHERE id=v_count.id AND status<>'Adjusted';
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'status','Adjusted');
  END IF;

  IF v_op='CANCEL' THEN
    UPDATE public.inventory_counts SET status='Cancelled',completed_at=COALESCE(completed_at,now()),updated_at=now() WHERE id=v_count.id AND status NOT IN ('Adjusted','Cancelled');
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'status','Cancelled');
  END IF;

  RAISE EXCEPTION 'عملية جرد غير مدعومة: %',v_op;
END;
$function$
;

-- CREATE OR REPLACE preserves the existing service-role-only EXECUTE contract.
