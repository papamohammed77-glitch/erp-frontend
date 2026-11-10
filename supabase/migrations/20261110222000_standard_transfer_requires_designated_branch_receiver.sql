-- Standard transfer receiver resolution for the unified warehouse role.

-- Prefer one eligible dedicated 'أذونات' user; use 'مخزن شامل' only when none exists.

-- Full-role fallback requires a unique home branch (default_branch_id or one allowed branch token).

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
  receiver_candidates uuid[] := '{}'::uuid[];
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

      WITH eligible_voucher_role_receivers AS (
        SELECT u.id
        FROM public.users u
        WHERE u.company_id=NEW.company_id
          AND COALESCE(u.status,'Active')='Active'
          AND u.role IN ('مخزني','أمين مخزن','امين مخزن')
          AND COALESCE(u.active_warehouse_role,'')='أذونات'
          AND u.default_branch_id=NEW.to_id
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
      ),
      eligible_full_role_receivers AS (
        SELECT u.id
        FROM public.users u
        WHERE u.company_id=NEW.company_id
          AND COALESCE(u.status,'Active')='Active'
          AND u.role IN ('مخزني','أمين مخزن','امين مخزن')
          AND COALESCE(u.active_warehouse_role,'')='مخزن شامل'
          AND (
            u.default_branch_id=NEW.to_id
            OR (
              u.default_branch_id IS NULL
              AND (
                (
                  jsonb_typeof(u.allowed_branch_ids)='array'
                  AND jsonb_array_length(u.allowed_branch_ids)=1
                  AND (
                    u.allowed_branch_ids @> jsonb_build_array(NEW.to_id::text)
                    OR u.allowed_branch_ids @> jsonb_build_array(branch_code)
                  )
                )
                OR (
                  jsonb_typeof(u.allowed_branch_ids)='string'
                  AND TRIM(BOTH '"' FROM u.allowed_branch_ids::text)
                      IN (branch_code, NEW.to_id::text)
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
      ),
      eligible_receivers AS (
        SELECT id FROM eligible_voucher_role_receivers
        UNION ALL
        SELECT id
        FROM eligible_full_role_receivers
        WHERE NOT EXISTS (SELECT 1 FROM eligible_voucher_role_receivers)
      )
      SELECT COALESCE(array_agg(id ORDER BY id),'{}'::uuid[])
      INTO receiver_candidates
      FROM eligible_receivers;

      receiver_count:=COALESCE(cardinality(receiver_candidates),0);

      IF receiver_count=0 THEN
        RAISE EXCEPTION 'لا يوجد مسؤول استلام مخزني مفعّل ومحدد للفرع الوجهة';
      END IF;

      IF receiver_count>1 THEN
        RAISE EXCEPTION 'يوجد أكثر من مسؤول استلام للفرع الوجهة؛ عيّن مسؤولًا واحدًا من النظام الأم';
      END IF;

      receiver_id:=receiver_candidates[1];

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
$function$;