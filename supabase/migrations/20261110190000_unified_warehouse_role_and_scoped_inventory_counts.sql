-- RAWAEA ERP — Unified Warehouse role and branch-scoped inventory counts.
-- No business rows or balances are changed by this migration.

CREATE OR REPLACE FUNCTION app_private.user_can_access_warehouse_branch(
  p_user_id uuid,
  p_company_id uuid,
  p_branch_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'app_private'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.branches b
      ON b.company_id = u.company_id
     AND b.id = p_branch_id
     AND COALESCE(b.is_active, true) = true
    WHERE u.id = p_user_id
      AND u.company_id = p_company_id
      AND COALESCE(u.status, 'Active') = 'Active'
      AND (
        u.default_branch_id = b.id
        OR (
          jsonb_typeof(u.allowed_branch_ids) = 'array'
          AND (
            u.allowed_branch_ids @> jsonb_build_array(b.id::text)
            OR u.allowed_branch_ids @> jsonb_build_array(b.branch_code)
            OR u.allowed_branch_ids @> '["*"]'::jsonb
          )
        )
        OR (
          jsonb_typeof(u.allowed_branch_ids) = 'string'
          AND trim(both '"' from u.allowed_branch_ids::text)
              IN (b.id::text, b.branch_code, '*')
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION app_private.current_user_can_access_warehouse_branch(
  p_company_id uuid,
  p_branch_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'app_private'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_id = auth.uid()
      AND u.company_id = p_company_id
      AND COALESCE(u.status, 'Active') = 'Active'
      AND (
        (
          u.permissions @> '["*"]'::jsonb
          AND EXISTS (
            SELECT 1 FROM public.owner_profile op
            JOIN auth.users au ON au.id = op.auth_user_id
            WHERE op.auth_user_id = auth.uid()
              AND COALESCE(au.raw_user_meta_data->>'isOwner', 'false') = 'true'
          )
        )
        OR app_private.user_can_access_warehouse_branch(u.id, p_company_id, p_branch_id)
      )
  );
$function$;

REVOKE ALL ON FUNCTION app_private.user_can_access_warehouse_branch(uuid,uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.user_can_access_warehouse_branch(uuid,uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION app_private.current_user_can_access_warehouse_branch(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION app_private.current_user_can_access_warehouse_branch(uuid,uuid) TO authenticated, service_role;

-- The supervisor roster and role assignment functions already enforce auth.uid(),
-- company membership, supervisor permission, and branch overlap in their bodies.
-- Permit the authenticated supervisor session to invoke those existing guards.
REVOKE ALL ON FUNCTION public.get_warehouse_team() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_warehouse_team() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_active_warehouse_role(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_active_warehouse_role(uuid,text) TO authenticated, service_role;

-- Add one authorized operational assignment; never alter the employee's job role.
DO $migration$
DECLARE
  v_definition text;
  v_old text := 'allowed_roles constant text[] := ARRAY[''استلام'',''تحضير'',''تحميل'',''مرتجعات'',''تفريغ'',''أذونات'',''جرد'',''احتياطي''];';
  v_new text := 'allowed_roles constant text[] := ARRAY[''استلام'',''تحضير'',''تحميل'',''مرتجعات'',''تفريغ'',''أذونات'',''جرد'',''احتياطي'',''مخزن شامل''];';
BEGIN
  SELECT pg_get_functiondef('public.set_active_warehouse_role(uuid,text)'::regprocedure)
    INTO v_definition;
  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'set_active_warehouse_role allowlist does not match the reviewed production definition';
  END IF;
  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;
END
$migration$;

-- The old details policy granted every authenticated user ALL access because this
-- table has no company_id. Replace it with a read-only, tenant/branch-scoped policy.
DROP POLICY IF EXISTS allow_all_inventory_count_details ON public.inventory_count_details;

CREATE POLICY inventory_count_details_select_scoped
ON public.inventory_count_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.inventory_counts c
    JOIN public.users u
      ON u.auth_id = auth.uid()
     AND u.company_id = c.company_id
     AND COALESCE(u.status, 'Active') = 'Active'
    WHERE c.id = inventory_count_details.count_id
      AND (
        u.permissions @> '["*"]'::jsonb
        OR u.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
        OR COALESCE(u.active_warehouse_role,'') IN ('جرد','مخزن شامل')
        OR app_private.current_user_has_permission('reports')
        OR app_private.current_user_has_permission('warehouse')
        OR app_private.current_user_has_permission('warehouse_manager')
        OR app_private.current_user_has_permission('warehouse_supervisor')
        OR app_private.current_user_has_permission('general-count')
        OR app_private.current_user_has_permission('branch-count')
        OR app_private.current_user_has_permission('vehicle-count')
      )
      AND app_private.current_user_can_access_warehouse_branch(
        c.company_id,
        inventory_count_details.branch_id
      )
    )
);

-- Restrict count headers to the same branch scope. General counts are visible
-- only when every active company branch is within the user's assigned scope.
DROP POLICY IF EXISTS inventory_counts_select_company_authorized ON public.inventory_counts;

CREATE POLICY inventory_counts_select_company_authorized
ON public.inventory_counts
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_id = auth.uid()
      AND u.company_id = inventory_counts.company_id
      AND COALESCE(u.status, 'Active') = 'Active'
      AND (
        u.permissions @> '["*"]'::jsonb
        OR u.role IN ('مدير مخازن','مشرف مخازن','مدير عام')
        OR COALESCE(u.active_warehouse_role,'') IN ('جرد','مخزن شامل')
        OR app_private.current_user_has_permission('reports')
        OR app_private.current_user_has_permission('warehouse')
        OR app_private.current_user_has_permission('warehouse_manager')
        OR app_private.current_user_has_permission('warehouse_supervisor')
        OR app_private.current_user_has_permission('general-count')
        OR app_private.current_user_has_permission('branch-count')
        OR app_private.current_user_has_permission('vehicle-count')
      )
  )
  AND (
    (
      type = 'general'
      AND NOT EXISTS (
        SELECT 1
        FROM public.branches b
        WHERE b.company_id = inventory_counts.company_id
          AND COALESCE(b.is_active, true) = true
          AND NOT app_private.current_user_can_access_warehouse_branch(
            inventory_counts.company_id, b.id
          )
      )
    )
    OR (
      type IN ('branch','vehicle')
      AND branch_id IS NOT NULL
      AND app_private.current_user_can_access_warehouse_branch(company_id, branch_id)
    )
  )
);

-- Expand the existing atomic count engine only for the new assigned warehouse role,
-- and enforce branch scope at the server-side writer before any count mutation.
DO $migration$
DECLARE
  v_definition text;
  v_old_role text := 'OR v_actor.role IN (''مدير مخازن'',''مشرف مخازن'',''مدير عام'')';
  v_new_role text := 'OR v_actor.role IN (''مدير مخازن'',''مشرف مخازن'',''مدير عام'')' || E'\n    OR COALESCE(v_actor.active_warehouse_role,'''') = ''مخزن شامل''';
  v_old_count text := '  IF NOT FOUND THEN RAISE EXCEPTION ''جلسة الجرد غير موجودة''; END IF;' || E'\n  IF v_count.status IN';
  v_new_count text := '  IF NOT FOUND THEN RAISE EXCEPTION ''جلسة الجرد غير موجودة''; END IF;' || E'\n  IF COALESCE(v_actor.active_warehouse_role,'''') = ''مخزن شامل'' THEN' || E'\n    IF v_count.type = ''general'' THEN' || E'\n      IF EXISTS (SELECT 1 FROM public.branches b WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true) AND NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,b.id)) THEN RAISE EXCEPTION ''الجرد العام يتضمن فروعًا خارج نطاق المستخدم''; END IF;' || E'\n    ELSIF v_count.branch_id IS NULL OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_count.branch_id) THEN' || E'\n      RAISE EXCEPTION ''جلسة الجرد خارج نطاق الفروع المسموح بها للمستخدم'';' || E'\n    END IF;' || E'\n  END IF;' || E'\n  IF v_count.status IN';
  v_old_create text := '    IF p_payload->>''type''=''vehicle'' THEN';
  v_old_create_end text := '    INSERT INTO public.inventory_counts(type,entity_id,reference,created_by,company_id,status,count_date,branch_id,notes,operation_id,started_at,updated_at)';
  v_old_upsert_branch text := '    IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_branch_id AND b.company_id=p_company_id) THEN RAISE EXCEPTION ''الفرع غير صالح''; END IF;';
  v_new_upsert_branch text := v_old_upsert_branch || E'\n    IF COALESCE(v_actor.active_warehouse_role,'''') = ''مخزن شامل'' THEN' || E'\n      IF NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_branch_id) THEN RAISE EXCEPTION ''فرع بند الجرد خارج نطاق المستخدم''; END IF;' || E'\n      IF v_count.type<>''general'' AND v_branch_id IS DISTINCT FROM v_count.branch_id THEN RAISE EXCEPTION ''فرع بند الجرد لا يطابق فرع جلسة الجرد''; END IF;' || E'\n    END IF;';
  v_new_create_end text := '    IF COALESCE(v_actor.active_warehouse_role,'''') = ''مخزن شامل'' THEN' || E'\n      IF p_payload->>''type''=''general'' THEN' || E'\n        IF EXISTS (SELECT 1 FROM public.branches b WHERE b.company_id=p_company_id AND COALESCE(b.is_active,true) AND NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,b.id)) THEN RAISE EXCEPTION ''الجرد العام يتضمن فروعًا خارج نطاق المستخدم''; END IF;' || E'\n      ELSIF v_branch_id IS NULL OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_branch_id) THEN' || E'\n        RAISE EXCEPTION ''فرع الجرد خارج نطاق المستخدم'';' || E'\n      END IF;' || E'\n    END IF;' || E'\n' || v_old_create_end;
BEGIN
  SELECT pg_get_functiondef('public.inventory_count_engine(uuid,text,text,jsonb,text)'::regprocedure)
    INTO v_definition;
  IF position(v_old_role IN v_definition) = 0 THEN
    RAISE EXCEPTION 'inventory_count_engine role predicate does not match reviewed production definition';
  END IF;
  IF position(v_old_count IN v_definition) = 0 THEN
    RAISE EXCEPTION 'inventory_count_engine count-session guard does not match reviewed production definition';
  END IF;
  IF position(v_old_create_end IN v_definition) = 0 THEN
    RAISE EXCEPTION 'inventory_count_engine CREATE branch insertion point does not match reviewed production definition';
  END IF;
  IF position(v_old_upsert_branch IN v_definition) = 0 THEN
    RAISE EXCEPTION 'inventory_count_engine UPSERT_LINE branch guard does not match reviewed production definition';
  END IF;
  v_definition := replace(v_definition, v_old_role, v_new_role);
  v_definition := replace(v_definition, v_old_count, v_new_count);
  v_definition := replace(v_definition, v_old_create_end, v_new_create_end);
  v_definition := replace(v_definition, v_old_upsert_branch, v_new_upsert_branch);
  EXECUTE v_definition;
END
$migration$;

-- No direct writes are granted to the count detail table; the existing service-role
-- SECURITY DEFINER engine remains the only approved writer.
REVOKE INSERT, UPDATE, DELETE ON public.inventory_count_details FROM anon, authenticated;
