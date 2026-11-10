-- Unified warehouse role parity; preserve all branch, creator, receiver, and idempotency contracts.
CREATE OR REPLACE FUNCTION public.complete_manual_stock_voucher_atomic(p_company_id uuid, p_voucher_code text, p_user_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v public.stock_vouchers%ROWTYPE;
  v_auth_branch uuid;
  v_allowed boolean;
BEGIN
  PERFORM set_config('app.user_email',coalesce(p_user_email,''),true);
  PERFORM set_config('app.operation_id',
    'VoucherComplete:'||p_company_id::text||':'||coalesce(btrim(p_voucher_code),''),
    true);

  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(p_user_email)
    AND COALESCE(u.status,'Active')='Active'
  ORDER BY u.id LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'سياق الشركة غير متسق مع المستخدم المنفذ'; END IF;

  SELECT * INTO v
  FROM public.stock_vouchers
  WHERE company_id=p_company_id AND voucher_code=p_voucher_code
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'الإذن غير موجود'; END IF;

  IF v.type='SupplierReturn' THEN
    IF NOT (
      COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
      OR COALESCE(v_actor.active_warehouse_role,'')='أذونات'
      OR (
        COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
        AND lower(COALESCE(v.created_by,''))=lower(COALESCE(v_actor.email,''))
      )
      OR v_actor.role IN ('مدير عام','مدير مخازن','مشرف مخازن')
    ) THEN
      RAISE EXCEPTION 'SUPPLIER_RETURN_COMPLETE_PERMISSION_REQUIRED';
    END IF;

    IF v.from_type='Branch' THEN
      v_auth_branch:=v.from_id;
    ELSIF v.from_type='Vehicle' THEN
      SELECT COALESCE(
        (SELECT mb.id FROM public.branches mb
          WHERE mb.id=veh.mobile_branch_id AND mb.company_id=p_company_id AND mb.is_active=true),
        (SELECT lb.id FROM public.branches lb
          WHERE lb.company_id=p_company_id
            AND upper(lb.branch_code)=upper('VAN-'||veh.vehicle_code)
            AND lb.is_active=true)
      ) INTO v_auth_branch
      FROM public.vehicles veh
      WHERE veh.id=v.from_id AND veh.company_id=p_company_id
        AND COALESCE(veh.status,'Active')='Active'
        AND COALESCE(veh.mobile_stock_enabled,true)=true;
    END IF;

    IF v_auth_branch IS NULL OR NOT EXISTS(
      SELECT 1 FROM public.branches b
      WHERE b.id=v_auth_branch AND b.company_id=p_company_id AND b.is_active=true
    ) THEN
      RAISE EXCEPTION 'SUPPLIER_RETURN_BRANCH_CONTEXT_INVALID';
    END IF;

    IF NOT (
      COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
      OR v_actor.allowed_branch_ids IS NULL
      OR v_actor.allowed_branch_ids='[]'::jsonb
      OR COALESCE(TRIM(BOTH '"' FROM v_actor.allowed_branch_ids::text),'')='*'
    ) THEN
      SELECT EXISTS(
        SELECT 1 FROM public.branches b
        WHERE b.id=v_auth_branch AND b.company_id=p_company_id AND b.is_active=true
          AND (
            (jsonb_typeof(v_actor.allowed_branch_ids)='array' AND (
              v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
              OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
            ))
            OR (jsonb_typeof(v_actor.allowed_branch_ids)='string'
              AND TRIM(BOTH '"' FROM v_actor.allowed_branch_ids::text) IN(b.branch_code,b.id::text,'*'))
          )
      ) INTO v_allowed;
      IF NOT v_allowed THEN RAISE EXCEPTION 'SUPPLIER_RETURN_BRANCH_SCOPE_FORBIDDEN'; END IF;
    END IF;
  END IF;

  RETURN public.complete_manual_stock_voucher_atomic_core_20260828(
    p_company_id,p_voucher_code,p_user_email
  );
END;
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
     AND v_actor.role='مخزني'
     AND COALESCE(v_actor.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
  THEN
    IF p_from_id IS NULL
       OR v_actor.default_branch_id IS NULL
       OR p_from_id IS DISTINCT FROM v_actor.default_branch_id
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
        v_actor.role='مخزني'
        AND coalesce(v_actor.active_warehouse_role,'')='أذونات'
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
      if v_actor.role<>'مخزني'
         or coalesce(v_actor.active_warehouse_role,'') not in ('أذونات','مخزن شامل') then
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
       (
         actor.active_warehouse_role = 'استلام'
         AND (
           actor_permissions ? '*'
           OR actor_permissions ? 'warehouse'
           OR actor_permissions ? 'receiving'
         )
       )
       OR (
         actor.active_warehouse_role = 'مخزن شامل'
         AND (actor_permissions ? '*' OR actor_permissions ? 'warehouse')
       )
     ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية استلام أوامر الشراء';
  END IF;
  IF p_operation_id IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لاستلام الشراء'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'لا توجد أصناف للاستلام'; END IF;

  SELECT * INTO po FROM public.purchase_orders WHERE company_id=p_company_id AND po_code=p_po_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'أمر الشراء غير موجود'; END IF;

  op:='PO-RECEIVE:'||p_company_id::text||':'||po.id::text||':'||p_operation_id::text;
  SELECT md5(coalesce(string_agg(
      btrim(x.item_code)||':'||COALESCE(x.sent_qty,x.received_qty,0)::text||':'||
      COALESCE(x.received_qty,0)::text||':'||COALESCE(NULLIF(btrim(x.reason),''),''),
      '|' ORDER BY btrim(x.item_code)
    ),''))
    INTO requested_fp
  FROM jsonb_to_recordset(p_items)
    x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  WHERE COALESCE(x.sent_qty,x.received_qty,0)>0;

  SELECT * INTO existing FROM public.receiving WHERE company_id=p_company_id AND operation_id=op FOR UPDATE;
  IF FOUND THEN
    SELECT md5(coalesce(string_agg(
        btrim(rd.item_code)||':'||COALESCE(rd.qty_expected,0)::text||':'||
        COALESCE(rd.qty_received,0)::text||':'||COALESCE(NULLIF(btrim(rd.reason),''),''),
        '|' ORDER BY btrim(rd.item_code)
      ),''))
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

  IF NOT EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_items)
      x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
    WHERE COALESCE(x.sent_qty,x.received_qty,0)>0
  ) THEN RAISE EXCEPTION 'يجب تسجيل كمية مرسلة موجبة واحدة على الأقل'; END IF;

  FOR e IN SELECT * FROM jsonb_to_recordset(p_items)
    x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    IF NULLIF(btrim(e.item_code),'') IS NULL
       OR e.received_qty IS NULL
       OR COALESCE(e.sent_qty,e.received_qty) IS NULL
       OR e.received_qty::text IN ('NaN','Infinity','-Infinity')
       OR COALESCE(e.sent_qty,e.received_qty)::text IN ('NaN','Infinity','-Infinity') THEN
      RAISE EXCEPTION 'كود الصنف وكميتا الشحنة والاستلام مطلوبة';
    END IF;
    IF COALESCE(e.sent_qty,e.received_qty)<=0
       OR e.received_qty<0
       OR e.received_qty>COALESCE(e.sent_qty,e.received_qty)
       OR round(COALESCE(e.sent_qty,e.received_qty),4)<>COALESCE(e.sent_qty,e.received_qty)
       OR round(e.received_qty,4)<>e.received_qty THEN
      RAISE EXCEPTION 'كميات الشحنة والاستلام غير صالحة للصنف: %',e.item_code;
    END IF;
    IF e.received_qty<>COALESCE(e.sent_qty,e.received_qty)
       AND NULLIF(btrim(COALESCE(e.reason,'')),'') IS NULL THEN
      RAISE EXCEPTION 'سبب اختلاف الكمية المرسلة والمقبولة مطلوب للصنف: %',e.item_code;
    END IF;
    SELECT * INTO pd FROM public.purchase_order_details d
    WHERE d.po_id=po.id AND d.item_code=e.item_code FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود داخل أمر الشراء: %',e.item_code; END IF;
    SELECT * INTO item_master FROM public.items i
    WHERE i.id=pd.item_id AND i.company_id=p_company_id AND i.item_code=e.item_code;
    IF NOT FOUND THEN RAISE EXCEPTION 'هوية الصنف غير متسقة مع دليل الأصناف: %',e.item_code; END IF;
    IF COALESCE(e.sent_qty,e.received_qty) >
       GREATEST(0,COALESCE(pd.qty_ordered,0)-COALESCE(pd.qty_received,0))+0.0001 THEN
      RAISE EXCEPTION 'الكمية المرسلة تتجاوز المتبقي في أمر الشراء للصنف: %',e.item_code;
    END IF;
  END LOOP;

  INSERT INTO public.receiving(id,operation_id,date,po_number,responsible,start_time,end_time,status,company_id)
  VALUES(gen_random_uuid(),op,current_date,p_po_code,p_user_email,now(),now(),'مكتمل',p_company_id);

  FOR e IN SELECT * FROM jsonb_to_recordset(p_items)
    x(item_code text,sent_qty numeric,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    SELECT * INTO pd FROM public.purchase_order_details d
    WHERE d.po_id=po.id AND d.item_code=e.item_code FOR UPDATE;
    IF COALESCE(e.received_qty,0)>0 THEN
      SELECT * INTO item_master FROM public.items i
      WHERE i.id=pd.item_id AND i.company_id=p_company_id AND i.item_code=e.item_code;
      PERFORM public.post_stock_movement(
        p_company_id,'PurchaseIn',NULL,receiving_branch,item_master.id,e.received_qty,
        p_po_code,p_po_code,p_user_email,
        'PurchaseReceipt:'||op||':'||item_master.id::text
      );
      UPDATE public.purchase_order_details
      SET qty_received=COALESCE(pd.qty_received,0)+e.received_qty
      WHERE id=pd.id;
      total_value:=total_value+(e.received_qty*COALESCE(pd.unit_price,0));
      total_received_qty:=total_received_qty+e.received_qty;
    END IF;
    INSERT INTO public.receiving_details(
      id,operation_id,item_code,item_name,unit,qty_expected,qty_received,difference,reason
    )
    VALUES(
      gen_random_uuid(),op,e.item_code,COALESCE(pd.item_name,e.item_code),COALESCE(pd.unit,'حبة'),
      COALESCE(e.sent_qty,e.received_qty),e.received_qty,
      e.received_qty-COALESCE(e.sent_qty,e.received_qty),
      NULLIF(btrim(COALESCE(e.reason,'')),'')
    );
  END LOOP;

  FOR pd IN SELECT * FROM public.purchase_order_details WHERE po_id=po.id LOOP
    IF coalesce(pd.qty_received,0)<coalesce(pd.qty_ordered,0) THEN all_received:=false; EXIT; END IF;
  END LOOP;
  IF total_received_qty>0 THEN
    PERFORM set_config('rawaea.purchase_actor',p_user_email,true);
    UPDATE public.purchase_orders
    SET status=CASE WHEN all_received THEN 'Received' ELSE 'Partially Received' END,updated_at=now()
    WHERE id=po.id AND company_id=p_company_id;
  END IF;

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
;

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
    (
      v_actor.active_warehouse_role='استلام'
      AND (public.hr_user_has_permission(v_actor.id,'warehouse')
        OR public.hr_user_has_permission(v_actor.id,'receiving'))
    )
    OR (
      v_actor.active_warehouse_role='مخزن شامل'
      AND public.hr_user_has_permission(v_actor.id,'warehouse')
    )
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

CREATE OR REPLACE FUNCTION public.send_stock_voucher_atomic(p_company_id uuid, p_voucher_code text, p_user_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v public.stock_vouchers%ROWTYPE;
  v_source uuid; v_auth_branch uuid; v_allowed boolean; v_result jsonb; v_custodian_email text; v_custody_value numeric:=0;
BEGIN
  PERFORM set_config('app.user_email',COALESCE(p_user_email,''),true);
  PERFORM set_config('app.operation_id','VoucherSend:'||p_company_id::text||':'||COALESCE(BTRIM(p_voucher_code),''),true);

  SELECT * INTO v_actor FROM public.users u WHERE u.company_id=p_company_id AND lower(u.email)=lower(p_user_email) AND COALESCE(u.status,'Active')='Active' LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'سياق الشركة غير متسق مع المستخدم المنفذ'; END IF;
  SELECT * INTO v FROM public.stock_vouchers WHERE company_id=p_company_id AND voucher_code=p_voucher_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'الإذن غير موجود'; END IF;

  IF v.type='SupplierReturn' THEN PERFORM public.assert_supplier_return_contract(p_company_id,v.id); END IF;
  IF v.type='SupplierReturn' AND NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR COALESCE(v_actor.active_warehouse_role,'')='أذونات'
    OR (
      COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
      AND lower(COALESCE(v.created_by,''))=lower(COALESCE(v_actor.email,''))
    )
    OR v_actor.role IN ('مدير عام','مدير مخازن','مشرف مخازن')
  ) THEN
    RAISE EXCEPTION 'SUPPLIER_RETURN_SEND_PERMISSION_REQUIRED';
  END IF;

  IF v.from_type='Branch' THEN
    v_source:=v.from_id;
  ELSIF v.from_type='Vehicle' THEN
    SELECT COALESCE(
      (SELECT mb.id FROM public.branches mb WHERE mb.id=v_vehicle.mobile_branch_id AND mb.company_id=p_company_id AND mb.is_active=true),
      (SELECT lb.id FROM public.branches lb WHERE lb.company_id=p_company_id AND upper(lb.branch_code)=upper('VAN-'||v_vehicle.vehicle_code) AND lb.is_active=true)
    ) INTO v_source
    FROM public.vehicles v_vehicle
    WHERE v_vehicle.id=v.from_id AND v_vehicle.company_id=p_company_id AND COALESCE(v_vehicle.status,'Active')='Active' AND COALESCE(v_vehicle.mobile_stock_enabled,true)=true;
  END IF;

  IF v.type='DirectReturn' AND v.to_type='Branch' THEN v_auth_branch:=v.to_id; ELSE v_auth_branch:=v_source; END IF;
  IF v_auth_branch IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.branches b WHERE b.id=v_auth_branch AND b.company_id=p_company_id AND b.is_active=true
  ) THEN RAISE EXCEPTION 'سياق الفرع التشغيلي للإذن غير صالح'; END IF;

  IF NOT (
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR v_actor.allowed_branch_ids IS NULL OR v_actor.allowed_branch_ids='[]'::jsonb
    OR COALESCE(TRIM(BOTH '"' FROM v_actor.allowed_branch_ids::text),'')='*'
    OR (v.type='Transfer' AND v_actor.role='مخزني' AND COALESCE(v_actor.active_warehouse_role,'')='أذونات')
  ) THEN
    SELECT EXISTS(
      SELECT 1 FROM public.branches b WHERE b.id=v_auth_branch AND b.company_id=p_company_id AND b.is_active=true
      AND (
        (jsonb_typeof(v_actor.allowed_branch_ids)='array' AND (
          v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code) OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
        ))
        OR (jsonb_typeof(v_actor.allowed_branch_ids)='string' AND TRIM(BOTH '"' FROM v_actor.allowed_branch_ids::text) IN(b.branch_code,b.id::text,'*'))
      )
    ) INTO v_allowed;
    IF NOT v_allowed THEN RAISE EXCEPTION 'الفرع التشغيلي للإذن خارج نطاق فروع المستخدم المسموح بها'; END IF;
  END IF;

  v_result:=public.send_stock_voucher_atomic_core_20260828(p_company_id,p_voucher_code,p_user_email);
  IF COALESCE((v_result->>'duplicate')::boolean,false) THEN RETURN v_result; END IF;

  IF v.type='DirectSale' THEN
    IF v.custodian_user_id IS NULL THEN RAISE EXCEPTION 'DirectSale custodian context missing'; END IF;
    SELECT u.email INTO v_custodian_email FROM public.users u
    WHERE u.id=v.custodian_user_id AND u.company_id=p_company_id AND COALESCE(u.status,'Active')='Active' AND u.role='مندوب بيع مباشر';
    IF v_custodian_email IS NULL THEN RAISE EXCEPTION 'مندوب عهدة DirectSale غير صالح'; END IF;
    SELECT COALESCE(SUM(svd.qty*COALESCE(NULLIF(svd.unit_price,0),i.sales_price,i.cost_price,0)),0) INTO v_custody_value
    FROM public.stock_voucher_details svd JOIN public.items i ON i.id=svd.item_id WHERE svd.voucher_id=v.id;
    IF v_custody_value>0 THEN
      PERFORM public.post_driver_ledger_entry(p_company_id,v.id,v_custodian_email,current_date,p_voucher_code,'تحميل عهدة مبيعات مباشرة – '||p_voucher_code,v_custody_value,0);
      v_result:=v_result||jsonb_build_object('custody_ledger',true,'custodian_user_id',v.custodian_user_id,'custody_value',v_custody_value);
    ELSE
      v_result:=v_result||jsonb_build_object('custody_ledger',false,'custody_value',0);
    END IF;
  END IF;
  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_manual_stock_voucher_atomic(p_company_id uuid, p_voucher_code text, p_operation_id text, p_reference text, p_from_type text, p_from_id uuid, p_to_type text, p_to_id uuid, p_notes text, p_items jsonb, p_rep_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_voucher public.stock_vouchers%ROWTYPE;
  v_vehicle public.vehicles%ROWTYPE;
  v_rep public.users%ROWTYPE;
  v_supplier public.suppliers%ROWTYPE;
  v_operation public.stock_voucher_operations%ROWTYPE;
  v_item jsonb;
  v_item_id uuid;
  v_fingerprint text;
  v_allowed boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'غير مصرح';
  END IF;

  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.auth_id=auth.uid()
    AND u.company_id=p_company_id
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المستخدم الحالي غير صالح ضمن الشركة';
  END IF;

  IF NOT (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR coalesce(v_actor.active_warehouse_role,'') IN ('أذونات','مخزن شامل')
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
  ) THEN
    RAISE EXCEPTION 'المستخدم غير مخول بتعديل الأذونات المخزنية';
  END IF;

  IF NULLIF(btrim(p_operation_id),'') IS NULL THEN
    RAISE EXCEPTION 'operation_id مطلوب';
  END IF;

  IF NULLIF(btrim(p_reference),'') IS NULL THEN
    RAISE EXCEPTION 'المرجع مطلوب';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN
    RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل';
  END IF;

  SELECT * INTO v_voucher
  FROM public.stock_vouchers
  WHERE company_id=p_company_id
    AND voucher_code=p_voucher_code
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الإذن غير موجود';
  END IF;

  IF v_voucher.status<>'Draft' THEN
    RAISE EXCEPTION 'لا يمكن تعديل إذن بعد إرساله';
  END IF;

  IF EXISTS(
    SELECT 1
    FROM jsonb_array_elements(p_items) AS z(value)
    GROUP BY btrim(z.value->>'itemCode')
    HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'لا يجوز تكرار الصنف داخل نفس الإذن';
  END IF;

  IF p_from_type='Branch' THEN
    IF p_from_id IS NULL OR NOT EXISTS(
      SELECT 1
      FROM public.branches b
      WHERE b.id=p_from_id
        AND b.company_id=p_company_id
        AND b.is_active=true
    ) THEN
      RAISE EXCEPTION 'فرع المصدر غير صالح';
    END IF;
  ELSIF p_from_type='Vehicle' THEN
    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_from_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'مركبة المصدر غير صالحة';
    END IF;
  ELSE
    RAISE EXCEPTION 'نوع المصدر غير مدعوم';
  END IF;

  IF p_to_type='Branch' THEN
    IF p_to_id IS NULL OR NOT EXISTS(
      SELECT 1
      FROM public.branches b
      WHERE b.id=p_to_id
        AND b.company_id=p_company_id
        AND b.is_active=true
    ) THEN
      RAISE EXCEPTION 'فرع الوجهة غير صالح';
    END IF;
  ELSIF p_to_type='Vehicle' THEN
    SELECT * INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id=p_to_id
      AND v.company_id=p_company_id
      AND coalesce(v.status,'Active')='Active'
      AND coalesce(v.mobile_stock_enabled,true)=true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'مركبة الوجهة غير صالحة';
    END IF;
  ELSIF p_to_type='Supplier' THEN
    SELECT * INTO v_supplier
    FROM public.suppliers s
    WHERE s.id=p_to_id
      AND s.company_id=p_company_id
      AND coalesce(s.is_active,true)=true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'المورد غير صالح';
    END IF;
  ELSE
    RAISE EXCEPTION 'نوع الوجهة غير مدعوم';
  END IF;

  IF v_voucher.type='Transfer' THEN
    IF p_from_type<>'Branch' OR p_to_type<>'Branch' THEN
      RAISE EXCEPTION 'تحويل داخلي يجب أن يكون فرعاً إلى فرع';
    END IF;

  ELSIF v_voucher.type='DirectSale' THEN
    IF p_from_type<>'Branch' OR p_to_type<>'Vehicle' THEN
      RAISE EXCEPTION 'الصرف المباشر يجب أن يكون فرعاً إلى مركبة';
    END IF;

    IF p_rep_id IS NULL THEN
      RAISE EXCEPTION 'مندوب البيع المباشر مطلوب';
    END IF;

    SELECT * INTO v_rep
    FROM public.users u
    WHERE u.id=p_rep_id
      AND u.company_id=p_company_id
      AND coalesce(u.status,'Active')='Active'
      AND u.role='مندوب بيع مباشر';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'مندوب البيع المباشر غير صالح';
    END IF;


    IF v_rep.default_branch_id IS NOT NULL THEN
      IF v_rep.default_branch_id<>p_from_id THEN
        RAISE EXCEPTION 'الفرع المصدر غير مسموح لمندوب البيع المباشر';
      END IF;
    ELSIF NOT (
      v_rep.allowed_branch_ids IS NULL
      OR v_rep.allowed_branch_ids='[]'::jsonb
      OR coalesce(trim(both '"' from v_rep.allowed_branch_ids::text),'')='*'
    ) THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.id=p_from_id
          AND b.company_id=p_company_id
          AND (
            (
              jsonb_typeof(v_rep.allowed_branch_ids)='array'
              AND (
                v_rep.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR v_rep.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR (
              jsonb_typeof(v_rep.allowed_branch_ids)='string'
              AND lower(trim(both '"' from v_rep.allowed_branch_ids::text))
                  = lower(b.branch_code)
            )
          )
      ) INTO v_allowed;

      IF NOT v_allowed THEN
        RAISE EXCEPTION 'الفرع المصدر غير مسموح لمندوب البيع المباشر';
      END IF;
    END IF;

  ELSIF v_voucher.type='DirectReturn' THEN
    IF p_from_type<>'Vehicle' OR p_to_type<>'Branch' THEN
      RAISE EXCEPTION 'المرتجع المباشر يجب أن يكون مركبة إلى فرع';
    END IF;

    IF p_rep_id IS NULL THEN
      RAISE EXCEPTION 'مندوب البيع المباشر مطلوب';
    END IF;

    SELECT * INTO v_rep
    FROM public.users u
    WHERE u.id=p_rep_id
      AND u.company_id=p_company_id
      AND coalesce(u.status,'Active')='Active'
      AND u.role='مندوب بيع مباشر';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'مندوب البيع المباشر غير صالح';
    END IF;

    IF NOT (
      EXISTS(
        SELECT 1
        FROM public.fleet_vehicle_sales_rep_assignments a
        WHERE a.company_id=p_company_id
          AND a.vehicle_id=v_vehicle.id
          AND a.sales_rep_user_id=p_rep_id
          AND a.end_at IS NULL
          AND a.is_primary=true
      )
      OR v_vehicle.driver_id=p_rep_id
    ) THEN
      RAISE EXCEPTION 'المركبة لا تتبع مندوب البيع المباشر المحدد';
    END IF;

  ELSIF v_voucher.type='SupplierReturn' THEN
    IF p_from_type<>'Branch' OR p_to_type<>'Supplier' THEN
      RAISE EXCEPTION 'مرتجع المورد يجب أن يكون فرعاً إلى مورد';
    END IF;

    -- SupplierReturn is a standalone warehouse operation.
    -- Supplier master is the authoritative destination; purchase-order history
    -- must not block a physical return that is intentionally independent of orders.
  END IF;

  IF NOT (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR v_actor.allowed_branch_ids IS NULL
    OR v_actor.allowed_branch_ids='[]'::jsonb
    OR coalesce(trim(both '"' from v_actor.allowed_branch_ids::text),'')='*'
    OR (
      v_voucher.type IN ('Transfer','DirectReturn')
      AND v_actor.role='مخزني'
      AND coalesce(v_actor.active_warehouse_role,'')='أذونات'
    )
  ) THEN

    IF p_from_type='Branch' THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.id=p_from_id
          AND b.company_id=p_company_id
          AND b.is_active=true
          AND (
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='array'
              AND (
                v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR (
              jsonb_typeof(v_actor.allowed_branch_ids)='string'
              AND trim(both '"' from v_actor.allowed_branch_ids::text)
                  IN (b.branch_code,b.id::text,'*')
            )
          )
      ) INTO v_allowed;

      IF NOT v_allowed THEN
        RAISE EXCEPTION 'فرع المصدر خارج نطاق المستخدم';
      END IF;
    END IF;

    IF p_to_type='Branch' THEN
      SELECT EXISTS(
        SELECT 1
        FROM public.branches b
        WHERE b.id=p_to_id
          AND b.company_id=p_company_id
          AND b.is_active=true
          AND (
            (
              jsonb_typeof(v_actor.allowed_branch_ids)='array'
              AND (
                v_actor.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR v_actor.allowed_branch_ids @> jsonb_build_array(b.id::text)
              )
            )
            OR (
              jsonb_typeof(v_actor.allowed_branch_ids)='string'
              AND trim(both '"' from v_actor.allowed_branch_ids::text)
                  IN (b.branch_code,b.id::text,'*')
            )
          )
      ) INTO v_allowed;

      IF NOT v_allowed THEN
        RAISE EXCEPTION 'فرع الوجهة خارج نطاق المستخدم';
      END IF;
    END IF;
  END IF;

  FOR v_item IN
    SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF nullif(btrim(v_item->>'itemCode'),'') IS NULL THEN
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
  END LOOP;

  v_fingerprint:=md5(
    jsonb_build_object(
      'voucher_id',v_voucher.id,
      'type',v_voucher.type,
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

  SELECT * INTO v_operation
  FROM public.stock_voucher_operations
  WHERE company_id=p_company_id
    AND operation_id=btrim(p_operation_id)
  FOR UPDATE;

  IF FOUND THEN
    IF v_operation.fingerprint<>v_fingerprint THEN
      RAISE EXCEPTION 'operation_id مستخدم مع بيانات مختلفة';
    END IF;

    IF v_operation.voucher_id IS NOT NULL
       AND v_operation.voucher_id<>v_voucher.id THEN
      RAISE EXCEPTION 'operation_id مرتبط بإذن آخر';
    END IF;

    RETURN jsonb_build_object(
      'success',true,
      'duplicate',true,
      'voucher_id',v_voucher.id,
      'voucher_code',p_voucher_code,
      'operation_id',btrim(p_operation_id)
    );
  END IF;

  INSERT INTO public.stock_voucher_operations(
    company_id,operation_id,fingerprint,voucher_id
  )
  VALUES(
    p_company_id,btrim(p_operation_id),v_fingerprint,v_voucher.id
  );

  UPDATE public.stock_vouchers
  SET reference=btrim(p_reference),
      from_type=p_from_type,
      from_id=p_from_id,
      to_type=p_to_type,
      to_id=p_to_id,
      notes=coalesce(p_notes,''),
      custodian_user_id=CASE
        WHEN v_voucher.type IN ('DirectSale','DirectReturn')
          THEN p_rep_id
        ELSE custodian_user_id
      END,
      updated_at=now()
  WHERE id=v_voucher.id
    AND company_id=p_company_id
    AND status='Draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'فشل تحديث رأس الإذن';
  END IF;

  DELETE FROM public.stock_voucher_details
  WHERE voucher_id=v_voucher.id;

  FOR v_item IN
    SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    SELECT i.id INTO v_item_id
    FROM public.items i
    WHERE i.item_code=v_item->>'itemCode';

    INSERT INTO public.stock_voucher_details(
      id,voucher_id,item_id,item_code,item_name,unit,qty,unit_price,notes,created_at
    )
    VALUES(
      gen_random_uuid(),
      v_voucher.id,
      v_item_id,
      v_item->>'itemCode',
      coalesce(nullif(v_item->>'itemName',''),v_item->>'itemCode'),
      coalesce(nullif(v_item->>'unit',''),'حبة'),
      (v_item->>'qty')::numeric,
      coalesce((v_item->>'unitPrice')::numeric,0),
      coalesce(v_item->>'notes',''),
      now()
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success',true,
    'duplicate',false,
    'voucher_id',v_voucher.id,
    'voucher_code',p_voucher_code,
    'operation_id',btrim(p_operation_id),
    'status','Draft'
  );
END;
$function$
;