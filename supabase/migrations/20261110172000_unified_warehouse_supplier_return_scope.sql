-- RAWAEA: align the manual SupplierReturn contract and draft-delete scope with the unified warehouse role.
-- This migration changes function definitions only. It does not insert/update/delete business rows,
-- post stock, change supplier balances, create journal entries, or alter inventory quantities.
DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  IF to_regprocedure('app_private.user_can_access_warehouse_branch(uuid,uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Required warehouse branch-scope helper is missing';
  END IF;

  v_def := pg_get_functiondef('public.get_supplier_return_contract(uuid,text)'::regprocedure);
  v_old := $old_get$  IF NOT (COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb OR COALESCE(v_actor.active_warehouse_role,'')='أذونات' OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')) THEN
    RAISE EXCEPTION 'المستخدم غير مخول بقراءة عقد مرتجع المورد';
  END IF;
  SELECT * INTO v FROM public.stock_vouchers WHERE company_id=p_company_id AND voucher_code=BTRIM(p_voucher_code);
  IF NOT FOUND OR v.type<>'SupplierReturn' THEN RAISE EXCEPTION 'SupplierReturn document not found'; END IF;$old_get$;
  v_new := $new_get$  SELECT * INTO v FROM public.stock_vouchers WHERE company_id=p_company_id AND voucher_code=BTRIM(p_voucher_code);
  IF NOT FOUND OR v.type<>'SupplierReturn' THEN RAISE EXCEPTION 'SupplierReturn document not found'; END IF;

  IF NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR COALESCE(v_actor.active_warehouse_role,'')='أذونات'
    OR COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN
    RAISE EXCEPTION 'المستخدم غير مخول بقراءة عقد مرتجع المورد';
  END IF;

  IF COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
     AND NOT (COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb)
     AND (
       v.source<>'Manual'
       OR lower(COALESCE(v.created_by,''))<>lower(COALESCE(v_actor.email,''))
       OR v.from_type<>'Branch'
       OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v.from_id)
     ) THEN
    RAISE EXCEPTION 'SUPPLIER_RETURN_CONTRACT_BRANCH_OR_CREATOR_FORBIDDEN';
  END IF;$new_get$;
  IF position(v_old IN v_def)=0 OR length(v_def)-length(replace(v_def,v_old,''))<>length(v_old) THEN
    RAISE EXCEPTION 'Unexpected get_supplier_return_contract definition; refusing patch';
  END IF;
  EXECUTE replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.save_supplier_return_contract(uuid,text,jsonb,text)'::regprocedure);
  v_old := $old_save$  IF NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR COALESCE(v_actor.active_warehouse_role,'')='أذونات'
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN RAISE EXCEPTION 'المستخدم غير مخول بإدارة عقد مرتجع المورد'; END IF;

  SELECT * INTO v
  FROM public.stock_vouchers
  WHERE company_id=p_company_id AND voucher_code=TRIM(p_voucher_code)
  FOR UPDATE;
  IF NOT FOUND OR v.source<>'Manual' OR v.type<>'SupplierReturn' THEN RAISE EXCEPTION 'إذن SupplierReturn اليدوي غير موجود'; END IF;
  IF v.status<>'Draft' THEN RAISE EXCEPTION 'لا يمكن تعديل عقد مرتجع بعد الإرسال'; END IF;$old_save$;
  v_new := $new_save$  SELECT * INTO v
  FROM public.stock_vouchers
  WHERE company_id=p_company_id AND voucher_code=TRIM(p_voucher_code)
  FOR UPDATE;
  IF NOT FOUND OR v.source<>'Manual' OR v.type<>'SupplierReturn' THEN RAISE EXCEPTION 'إذن SupplierReturn اليدوي غير موجود'; END IF;
  IF v.status<>'Draft' THEN RAISE EXCEPTION 'لا يمكن تعديل عقد مرتجع بعد الإرسال'; END IF;

  IF NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR COALESCE(v_actor.active_warehouse_role,'')='أذونات'
    OR COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN RAISE EXCEPTION 'المستخدم غير مخول بإدارة عقد مرتجع المورد'; END IF;

  IF COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
     AND NOT (COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb)
     AND (
       lower(COALESCE(v.created_by,''))<>lower(COALESCE(v_actor.email,''))
       OR v.from_type<>'Branch'
       OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v.from_id)
     ) THEN
    RAISE EXCEPTION 'SUPPLIER_RETURN_CONTRACT_BRANCH_OR_CREATOR_FORBIDDEN';
  END IF;$new_save$;
  IF position(v_old IN v_def)=0 OR length(v_def)-length(replace(v_def,v_old,''))<>length(v_old) THEN
    RAISE EXCEPTION 'Unexpected save_supplier_return_contract definition; refusing patch';
  END IF;
  EXECUTE replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.delete_manual_stock_voucher_atomic(uuid,text,text)'::regprocedure);
  v_old := $old_delete$  IF v_movement_count>0 THEN
    RAISE EXCEPTION 'لا يمكن حذف إذن سبق أن أنشأ حركة مخزنية';
  END IF;

  IF NOT(
    coalesce(v_actor.permissions,'[]'::jsonb) @> '[ "*" ]'::jsonb
    OR v_actor.allowed_branch_ids IS NULL
    OR v_actor.allowed_branch_ids='[]'::jsonb
    OR coalesce(trim(both '"' from v_actor.allowed_branch_ids::text),'')='*'
    OR (
      v.type='Transfer'
      AND v_actor.role='مخزني'
      AND coalesce(v_actor.active_warehouse_role,'')='أذونات'
    )
  ) THEN$old_delete$;
  v_new := $new_delete$  IF v_movement_count>0 THEN
    RAISE EXCEPTION 'لا يمكن حذف إذن سبق أن أنشأ حركة مخزنية';
  END IF;

  IF COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
     AND NOT (COALESCE(v_actor.permissions,'[]'::jsonb) @> '[ "*" ]'::jsonb)
  THEN
    v_branch_id:=CASE WHEN v.type='DirectReturn' THEN v.to_id ELSE v.from_id END;
    IF v_branch_id IS NULL
       OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_branch_id) THEN
      RAISE EXCEPTION 'الإذن خارج نطاق فروع المستخدم المسموح بها';
    END IF;
  END IF;

  IF NOT($new_delete$;
  IF position(v_old IN v_def)=0 OR length(v_def)-length(replace(v_def,v_old,''))<>length(v_old) THEN
    RAISE EXCEPTION 'Unexpected delete_manual_stock_voucher_atomic definition; refusing patch';
  END IF;
  EXECUTE replace(v_def,v_old,v_new);

  IF position('SUPPLIER_RETURN_CONTRACT_BRANCH_OR_CREATOR_FORBIDDEN' IN pg_get_functiondef('public.get_supplier_return_contract(uuid,text)'::regprocedure))=0
     OR position('SUPPLIER_RETURN_CONTRACT_BRANCH_OR_CREATOR_FORBIDDEN' IN pg_get_functiondef('public.save_supplier_return_contract(uuid,text,jsonb,text)'::regprocedure))=0
     OR position('app_private.user_can_access_warehouse_branch' IN pg_get_functiondef('public.delete_manual_stock_voucher_atomic(uuid,text,text)'::regprocedure))=0 THEN
    RAISE EXCEPTION 'Post-migration verification failed';
  END IF;
END;
$migration$;
