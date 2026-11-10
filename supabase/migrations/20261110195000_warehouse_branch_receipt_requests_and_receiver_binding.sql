ALTER TABLE public.stock_vouchers ADD COLUMN IF NOT EXISTS request_origin text;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.stock_vouchers'::regclass AND conname='stock_vouchers_request_origin_ck') THEN
    ALTER TABLE public.stock_vouchers ADD CONSTRAINT stock_vouchers_request_origin_ck
      CHECK (request_origin IS NULL OR request_origin='WarehouseBranchReceipt') NOT VALID;
  END IF;
END $$;
ALTER TABLE public.stock_vouchers VALIDATE CONSTRAINT stock_vouchers_request_origin_ck;
CREATE INDEX IF NOT EXISTS idx_stock_vouchers_branch_receipt_request
  ON public.stock_vouchers(company_id,from_id,status,created_at DESC)
  WHERE request_origin='WarehouseBranchReceipt';
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
              AND jsonb_typeof(ru.allowed_branch_ids)='array'
              AND jsonb_array_length(ru.allowed_branch_ids)=1
              AND (
                ru.allowed_branch_ids @> jsonb_build_array(b.branch_code)
                OR ru.allowed_branch_ids @> jsonb_build_array(b.id::text)
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
            AND jsonb_typeof(u.allowed_branch_ids)='array'
            AND jsonb_array_length(u.allowed_branch_ids)=1
            AND EXISTS (
              SELECT 1 FROM public.branches hb
              WHERE hb.id=NEW.to_id
                AND hb.company_id=NEW.company_id
                AND (
                  u.allowed_branch_ids @> jsonb_build_array(hb.branch_code)
                  OR u.allowed_branch_ids @> jsonb_build_array(hb.id::text)
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
            AND jsonb_typeof(u.allowed_branch_ids)='array'
            AND jsonb_array_length(u.allowed_branch_ids)=1
            AND EXISTS (
              SELECT 1 FROM public.branches hb
              WHERE hb.id=NEW.to_id
                AND hb.company_id=NEW.company_id
                AND (
                  u.allowed_branch_ids @> jsonb_build_array(hb.branch_code)
                  OR u.allowed_branch_ids @> jsonb_build_array(hb.id::text)
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

CREATE OR REPLACE FUNCTION public.inventory_voucher_report(p_operation text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_op text := upper(btrim(coalesce(p_operation,'')));
  v_company_id uuid;
  v_email text;
  v_privileged boolean := false;
  v_reporting boolean := false;
  v_warehouse boolean := false;
  v_voucher_access boolean := false;
  v_type text;
  v_status text;
  v_query text;
  v_from_date date;
  v_to_date date;
  v_source text;
  v_voucher_code text;
  v_workflow_scope text := '';
  v_allowed_tokens text[] := '{}'::text[];
  v_scope_branch_ids uuid[] := '{}'::uuid[];
  v_all_scope boolean := false;
  v_limit integer := 50;
  v_offset integer := 0;
  v_total bigint := 0;
  v_rows jsonb := '[]'::jsonb;
  v_statuses jsonb := '[]'::jsonb;
  v_types jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'غير مصرح';
  END IF;

  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.auth_id=auth.uid()
    AND coalesce(u.status,'Active')='Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المستخدم الحالي غير مسجل أو غير نشط';
  END IF;

  v_company_id:=v_actor.company_id;
  v_email:=v_actor.email;

  v_privileged:=coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
                 OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام');
  v_reporting:=v_privileged
                OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["reports"]'::jsonb;
  v_warehouse:=v_privileged
                OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
                OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse_manager"]'::jsonb
                OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["warehouse_supervisor"]'::jsonb;
  v_voucher_access:=v_warehouse
                    OR v_reporting
                    OR coalesce(v_actor.active_warehouse_role,'')='أذونات'
                    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["vouchers"]'::jsonb;

  IF v_op NOT IN ('LIST','SUMMARY') THEN
    RAISE EXCEPTION 'عملية تقرير الأذونات غير مدعومة';
  END IF;

  IF NOT v_voucher_access THEN
    RAISE EXCEPTION 'غير مصرح بقراءة تقارير الأذونات المخزنية';
  END IF;

  v_type:=nullif(btrim(coalesce(p_payload->>'type','')),'');
  v_status:=nullif(btrim(coalesce(p_payload->>'status','')),'');
  v_query:=lower(nullif(btrim(coalesce(p_payload->>'search','')),''));
  v_source:=coalesce(nullif(btrim(coalesce(p_payload->>'source','')),''),'Manual');
  v_voucher_code:=nullif(btrim(coalesce(p_payload->>'voucher_code','')),'');
  v_from_date:=nullif(btrim(coalesce(p_payload->>'from_date','')),'')::date;
  v_to_date:=nullif(btrim(coalesce(p_payload->>'to_date','')),'')::date;
  v_workflow_scope:=lower(btrim(coalesce(p_payload->>'workflow_scope','')));

  v_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,50),1),1000);
  v_offset:=greatest(coalesce((p_payload->>'offset')::integer,0),0);

  IF v_workflow_scope NOT IN ('','pending','completed') THEN
    RAISE EXCEPTION 'نطاق قائمة الأذونات غير مدعوم';
  END IF;

  v_all_scope:=v_privileged;

  IF jsonb_typeof(v_actor.allowed_branch_ids)='array' THEN
    SELECT coalesce(array_agg(trim(x.value)),'{}'::text[])
    INTO v_allowed_tokens
    FROM jsonb_array_elements_text(v_actor.allowed_branch_ids) x;
  ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string' THEN
    v_allowed_tokens:=regexp_split_to_array(
      trim(both '"' from v_actor.allowed_branch_ids::text),
      '[,|]'
    );
  END IF;

  SELECT coalesce(array_agg(b.id),'{}'::uuid[])
  INTO v_scope_branch_ids
  FROM public.branches b
  WHERE b.company_id=v_company_id
    AND coalesce(b.is_active,true)=true
    AND (
      '*'=any(v_allowed_tokens)
      OR b.id=v_actor.default_branch_id
      OR b.id::text=any(v_allowed_tokens)
      OR b.branch_code=any(v_allowed_tokens)
    );

  IF v_type IS NOT NULL AND v_type NOT IN ('Transfer','DirectSale','DirectReturn','SupplierReturn') THEN
    RAISE EXCEPTION 'نوع الإذن غير مدعوم';
  END IF;

  IF v_status IS NOT NULL AND v_status NOT IN ('Draft','Sent','Received','Completed','Cancelled') THEN
    RAISE EXCEPTION 'حالة الإذن غير مدعومة';
  END IF;

  IF v_from_date IS NOT NULL AND v_to_date IS NOT NULL AND v_from_date>v_to_date THEN
    RAISE EXCEPTION 'نطاق التاريخ غير صالح';
  END IF;

  IF v_op='SUMMARY' THEN
    SELECT count(*) INTO v_total
    FROM public.stock_vouchers v
    WHERE v.company_id=v_company_id
      AND v.source=v_source
      AND (v_type IS NULL OR v.type=v_type)
      AND (v_status IS NULL OR v.status=v_status)
      AND (v_voucher_code IS NULL OR v.voucher_code=v_voucher_code)
      AND (v_from_date IS NULL OR v.voucher_date>=v_from_date)
      AND (v_to_date IS NULL OR v.voucher_date<=v_to_date)
      AND (
        v_workflow_scope=''
        OR (
          v_workflow_scope='pending'
          AND (
            v_all_scope
            OR (v.status='Draft' AND lower(coalesce(v.created_by,''))=lower(v_email))
            OR (v.type='Transfer' AND v.status='Draft' AND v.request_origin='WarehouseBranchReceipt' AND v.from_id=any(v_scope_branch_ids))
            OR (v.type='Transfer' AND v.status='Sent' AND v.receiver_user_id=v_actor.id)
            OR (v.type='DirectReturn' AND v.status='Sent' AND v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
            OR (v.type IN ('DirectSale','SupplierReturn') AND v.status='Sent' AND lower(coalesce(v.created_by,''))=lower(v_email))
            OR (v.status='Received' AND (lower(coalesce(v.created_by,''))=lower(v_email) OR v.receiver_user_id=v_actor.id))
          )
        )
        OR (
          v_workflow_scope='completed'
          AND (
            (v_all_scope AND v.status IN ('Completed','Cancelled'))
            OR (
              NOT v_all_scope
              AND v.status IN ('Completed','Cancelled')
              AND (
                (v.from_type='Branch' AND v.from_id=any(v_scope_branch_ids))
                OR (v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
              )
            )
          )
        )
      )
      AND (
        v_query IS NULL
        OR lower(concat_ws(' ',v.voucher_code,v.reference,v.type,v.status,v.source,v.created_by,v.completed_by,v.notes,v.from_type,v.to_type)) LIKE '%'||v_query||'%'
        OR EXISTS (
          SELECT 1 FROM public.stock_voucher_details d
          WHERE d.voucher_id=v.id
            AND lower(concat_ws(' ',d.item_code,d.item_name,d.unit,d.notes)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.branches b
          WHERE b.company_id=v_company_id AND b.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',b.branch_code,b.name,b.location)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.vehicles vh
          WHERE vh.company_id=v_company_id AND vh.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',vh.vehicle_code,vh.license_plate,vh.model)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.suppliers sp
          WHERE sp.company_id=v_company_id AND sp.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',sp.supplier_code,sp.name,sp.search_label)) LIKE '%'||v_query||'%'
        )
      );

    SELECT coalesce(jsonb_agg(jsonb_build_object('type',x.type,'count',x.cnt) ORDER BY x.type),'[]'::jsonb)
    INTO v_types
    FROM (
      SELECT v.type,count(*) cnt
      FROM public.stock_vouchers v
      WHERE v.company_id=v_company_id
        AND v.source=v_source
        AND (v_type IS NULL OR v.type=v_type)
        AND (v_status IS NULL OR v.status=v_status)
        AND (v_voucher_code IS NULL OR v.voucher_code=v_voucher_code)
        AND (v_from_date IS NULL OR v.voucher_date>=v_from_date)
        AND (v_to_date IS NULL OR v.voucher_date<=v_to_date)
        AND (
          v_workflow_scope=''
          OR (
            v_workflow_scope='pending'
            AND (
              v_all_scope
              OR (v.status='Draft' AND lower(coalesce(v.created_by,''))=lower(v_email))
              OR (v.type='Transfer' AND v.status='Draft' AND v.request_origin='WarehouseBranchReceipt' AND v.from_id=any(v_scope_branch_ids))
            OR (v.type='Transfer' AND v.status='Sent' AND v.receiver_user_id=v_actor.id)
              OR (v.type='DirectReturn' AND v.status='Sent' AND v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
              OR (v.type IN ('DirectSale','SupplierReturn') AND v.status='Sent' AND lower(coalesce(v.created_by,''))=lower(v_email))
              OR (v.status='Received' AND (lower(coalesce(v.created_by,''))=lower(v_email) OR v.receiver_user_id=v_actor.id))
            )
          )
          OR (
            v_workflow_scope='completed'
            AND (
              (v_all_scope AND v.status IN ('Completed','Cancelled'))
              OR (
                NOT v_all_scope
                AND v.status IN ('Completed','Cancelled')
                AND (
                  (v.from_type='Branch' AND v.from_id=any(v_scope_branch_ids))
                  OR (v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
                )
              )
            )
          )
        )
      GROUP BY v.type
    ) x;

    SELECT coalesce(jsonb_agg(jsonb_build_object('status',x.status,'count',x.cnt) ORDER BY x.status),'[]'::jsonb)
    INTO v_statuses
    FROM (
      SELECT v.status,count(*) cnt
      FROM public.stock_vouchers v
      WHERE v.company_id=v_company_id
        AND v.source=v_source
        AND (v_type IS NULL OR v.type=v_type)
        AND (v_status IS NULL OR v.status=v_status)
        AND (v_voucher_code IS NULL OR v.voucher_code=v_voucher_code)
        AND (v_from_date IS NULL OR v.voucher_date>=v_from_date)
        AND (v_to_date IS NULL OR v.voucher_date<=v_to_date)
        AND (
          v_workflow_scope=''
          OR (
            v_workflow_scope='pending'
            AND (
              v_all_scope
              OR (v.status='Draft' AND lower(coalesce(v.created_by,''))=lower(v_email))
              OR (v.type='Transfer' AND v.status='Draft' AND v.request_origin='WarehouseBranchReceipt' AND v.from_id=any(v_scope_branch_ids))
            OR (v.type='Transfer' AND v.status='Sent' AND v.receiver_user_id=v_actor.id)
              OR (v.type='DirectReturn' AND v.status='Sent' AND v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
              OR (v.type IN ('DirectSale','SupplierReturn') AND v.status='Sent' AND lower(coalesce(v.created_by,''))=lower(v_email))
              OR (v.status='Received' AND (lower(coalesce(v.created_by,''))=lower(v_email) OR v.receiver_user_id=v_actor.id))
            )
          )
          OR (
            v_workflow_scope='completed'
            AND (
              (v_all_scope AND v.status IN ('Completed','Cancelled'))
              OR (
                NOT v_all_scope
                AND v.status IN ('Completed','Cancelled')
                AND (
                  (v.from_type='Branch' AND v.from_id=any(v_scope_branch_ids))
                  OR (v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
                )
              )
            )
          )
        )
      GROUP BY v.status
    ) x;

    RETURN jsonb_build_object(
      'success',true,'operation','SUMMARY','type',v_type,'source',v_source,
      'status',v_status,'search',v_query,'total',v_total,
      'summary',jsonb_build_object('types',v_types,'statuses',v_statuses)
    );
  END IF;

  SELECT count(*) INTO v_total
  FROM public.stock_vouchers v
  WHERE v.company_id=v_company_id
    AND v.source=v_source
    AND (v_type IS NULL OR v.type=v_type)
    AND (v_status IS NULL OR v.status=v_status)
    AND (v_voucher_code IS NULL OR v.voucher_code=v_voucher_code)
    AND (v_from_date IS NULL OR v.voucher_date>=v_from_date)
    AND (v_to_date IS NULL OR v.voucher_date<=v_to_date)
    AND (
      v_workflow_scope=''
      OR (
        v_workflow_scope='pending'
        AND (
          v_all_scope
          OR (v.status='Draft' AND lower(coalesce(v.created_by,''))=lower(v_email))
          OR (v.type='Transfer' AND v.status='Draft' AND v.request_origin='WarehouseBranchReceipt' AND v.from_id=any(v_scope_branch_ids))
            OR (v.type='Transfer' AND v.status='Sent' AND v.receiver_user_id=v_actor.id)
          OR (v.type='DirectReturn' AND v.status='Sent' AND v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
          OR (v.type IN ('DirectSale','SupplierReturn') AND v.status='Sent' AND lower(coalesce(v.created_by,''))=lower(v_email))
          OR (v.status='Received' AND (lower(coalesce(v.created_by,''))=lower(v_email) OR v.receiver_user_id=v_actor.id))
        )
      )
      OR (
        v_workflow_scope='completed'
        AND (
          (v_all_scope AND v.status IN ('Completed','Cancelled'))
          OR (
            NOT v_all_scope
            AND v.status IN ('Completed','Cancelled')
            AND (
              (v.from_type='Branch' AND v.from_id=any(v_scope_branch_ids))
              OR (v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
            )
          )
        )
      )
    )
    AND (
      v_query IS NULL
      OR lower(concat_ws(' ',v.voucher_code,v.reference,v.type,v.status,v.source,v.created_by,v.completed_by,v.notes,v.from_type,v.to_type)) LIKE '%'||v_query||'%'
      OR EXISTS (
        SELECT 1 FROM public.stock_voucher_details d
        WHERE d.voucher_id=v.id
          AND lower(concat_ws(' ',d.item_code,d.item_name,d.unit,d.notes)) LIKE '%'||v_query||'%'
      )
      OR EXISTS (
        SELECT 1 FROM public.branches b
        WHERE b.company_id=v_company_id AND b.id IN (v.from_id,v.to_id)
          AND lower(concat_ws(' ',b.branch_code,b.name,b.location)) LIKE '%'||v_query||'%'
      )
      OR EXISTS (
        SELECT 1 FROM public.vehicles vh
        WHERE vh.company_id=v_company_id AND vh.id IN (v.from_id,v.to_id)
          AND lower(concat_ws(' ',vh.vehicle_code,vh.license_plate,vh.model)) LIKE '%'||v_query||'%'
      )
      OR EXISTS (
        SELECT 1 FROM public.suppliers sp
        WHERE sp.company_id=v_company_id AND sp.id IN (v.from_id,v.to_id)
          AND lower(concat_ws(' ',sp.supplier_code,sp.name,sp.search_label)) LIKE '%'||v_query||'%'
      )
    );

  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.voucher_date DESC,r.created_at DESC,r.voucher_code DESC),'[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      v.id,v.voucher_code,v.voucher_date,v.type,v.status,v.reference,v.notes,v.source,
      CASE WHEN v_all_scope THEN v.created_by ELSE NULL END AS created_by,
      CASE WHEN v_all_scope THEN v.completed_by ELSE NULL END AS completed_by,
      v.created_at,v.updated_at,v.sent_date,v.received_date,v.completed_at,
      v.from_type,v.from_id,v.to_type,v.to_id,
      v.custodian_user_id,
      v.receiver_user_id,
      v.request_origin,
      CASE v.from_type
        WHEN 'Branch' THEN coalesce((SELECT b.name||' ['||b.branch_code||']' FROM public.branches b WHERE b.id=v.from_id AND b.company_id=v_company_id),'')
        WHEN 'Vehicle' THEN coalesce((SELECT vh.vehicle_code||' ['||vh.license_plate||']' FROM public.vehicles vh WHERE vh.id=v.from_id AND vh.company_id=v_company_id),'')
        WHEN 'Supplier' THEN coalesce((SELECT sp.name||' ['||sp.supplier_code||']' FROM public.suppliers sp WHERE sp.id=v.from_id AND sp.company_id=v_company_id),'')
        ELSE coalesce(v.from_id::text,'')
      END AS from_label,
      CASE v.to_type
        WHEN 'Branch' THEN coalesce((SELECT b.name||' ['||b.branch_code||']' FROM public.branches b WHERE b.id=v.to_id AND b.company_id=v_company_id),'')
        WHEN 'Vehicle' THEN coalesce((SELECT vh.vehicle_code||' ['||vh.license_plate||']' FROM public.vehicles vh WHERE vh.id=v.to_id AND vh.company_id=v_company_id),'')
        WHEN 'Supplier' THEN coalesce((SELECT sp.name||' ['||sp.supplier_code||']' FROM public.suppliers sp WHERE sp.id=v.to_id AND sp.company_id=v_company_id),'')
        ELSE coalesce(v.to_id::text,'')
      END AS to_label,
      CASE
        WHEN v.type IN ('DirectSale','DirectReturn') AND v.custodian_user_id IS NOT NULL THEN
          COALESCE(
            (
              SELECT COALESCE(NULLIF(btrim(u.name),''),NULLIF(btrim(u.email),''))
              FROM public.users u
              WHERE u.id=v.custodian_user_id
                AND u.company_id=v_company_id
              LIMIT 1
            ),
            ''
          )
        ELSE NULL
      END AS custodian_name,
      (SELECT count(*) FROM public.stock_voucher_details d WHERE d.voucher_id=v.id) AS item_lines,
      (SELECT coalesce(sum(d.qty),0) FROM public.stock_voucher_details d WHERE d.voucher_id=v.id) AS total_qty,
      (SELECT count(*) FROM public.inventory_log il WHERE il.company_id=v_company_id AND il.voucher_id=v.voucher_code) AS movement_count,
      (SELECT count(*) FROM public.audit_log a WHERE a.table_name='stock_vouchers' AND a.record_id=v.id::text AND (a.company_id IS NULL OR a.company_id=v_company_id)) AS audit_count
    FROM public.stock_vouchers v
    WHERE v.company_id=v_company_id
      AND v.source=v_source
      AND (v_type IS NULL OR v.type=v_type)
      AND (v_status IS NULL OR v.status=v_status)
      AND (v_voucher_code IS NULL OR v.voucher_code=v_voucher_code)
      AND (v_from_date IS NULL OR v.voucher_date>=v_from_date)
      AND (v_to_date IS NULL OR v.voucher_date<=v_to_date)
      AND (
        v_workflow_scope=''
        OR (
          v_workflow_scope='pending'
          AND (
            v_all_scope
            OR (v.status='Draft' AND lower(coalesce(v.created_by,''))=lower(v_email))
            OR (v.type='Transfer' AND v.status='Draft' AND v.request_origin='WarehouseBranchReceipt' AND v.from_id=any(v_scope_branch_ids))
            OR (v.type='Transfer' AND v.status='Sent' AND v.receiver_user_id=v_actor.id)
            OR (v.type='DirectReturn' AND v.status='Sent' AND v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
            OR (v.type IN ('DirectSale','SupplierReturn') AND v.status='Sent' AND lower(coalesce(v.created_by,''))=lower(v_email))
            OR (v.status='Received' AND (lower(coalesce(v.created_by,''))=lower(v_email) OR v.receiver_user_id=v_actor.id))
          )
        )
        OR (
          v_workflow_scope='completed'
          AND (
            (v_all_scope AND v.status IN ('Completed','Cancelled'))
            OR (
              NOT v_all_scope
              AND v.status IN ('Completed','Cancelled')
              AND (
                (v.from_type='Branch' AND v.from_id=any(v_scope_branch_ids))
                OR (v.to_type='Branch' AND v.to_id=any(v_scope_branch_ids))
              )
            )
          )
        )
      )
      AND (
        v_query IS NULL
        OR lower(concat_ws(' ',v.voucher_code,v.reference,v.type,v.status,v.source,v.created_by,v.completed_by,v.notes,v.from_type,v.to_type)) LIKE '%'||v_query||'%'
        OR EXISTS (
          SELECT 1 FROM public.stock_voucher_details d
          WHERE d.voucher_id=v.id
            AND lower(concat_ws(' ',d.item_code,d.item_name,d.unit,d.notes)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.branches b
          WHERE b.company_id=v_company_id AND b.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',b.branch_code,b.name,b.location)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.vehicles vh
          WHERE vh.company_id=v_company_id AND vh.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',vh.vehicle_code,vh.license_plate,vh.model)) LIKE '%'||v_query||'%'
        )
        OR EXISTS (
          SELECT 1 FROM public.suppliers sp
          WHERE sp.company_id=v_company_id AND sp.id IN (v.from_id,v.to_id)
            AND lower(concat_ws(' ',sp.supplier_code,sp.name,sp.search_label)) LIKE '%'||v_query||'%'
        )
      )
    ORDER BY v.voucher_date DESC,v.created_at DESC,v.voucher_code DESC
    LIMIT v_limit OFFSET v_offset
  ) r;

  RETURN jsonb_build_object(
    'success',true,'operation','LIST','type',v_type,'source',v_source,'status',v_status,
    'search',v_query,'from_date',v_from_date,'to_date',v_to_date,
    'workflow_scope',v_workflow_scope,'total',v_total,'offset',v_offset,'limit',v_limit,
    'has_more',(v_offset+v_limit)<v_total,'rows',v_rows
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.create_branch_receipt_request_atomic(
  p_company_id uuid,p_source_branch_id uuid,p_reference text,p_notes text,
  p_created_by text,p_items jsonb,p_operation_id text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
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
  WHERE b.id=p_source_branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true)=true;
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
$function$;

REVOKE ALL ON FUNCTION public.create_branch_receipt_request_atomic(uuid,uuid,text,text,text,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_branch_receipt_request_atomic(uuid,uuid,text,text,text,jsonb,text) TO service_role;
