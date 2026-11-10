-- Read-only, branch-scoped operational summary for the unified warehouse hub.
-- No stock, accounting, supplier, treasury, voucher, or inventory rows are written.
CREATE OR REPLACE FUNCTION public.get_warehouse_hub_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_auth_id uuid := auth.uid();
  v_user_id uuid;
  v_company_id uuid;
  v_user_role text;
  v_active_role text;
  v_is_owner boolean := false;
  v_has_warehouse boolean := false;
  v_allowed_branch_ids uuid[] := ARRAY[]::uuid[];
  v_branch_scope jsonb := '[]'::jsonb;
  v_main_branch_id uuid;
  v_main_branch_access boolean := false;
  v_pending_purchase_orders integer := 0;
  v_active_runsheets integer := 0;
  v_loading_runsheets integer := 0;
  v_loaded_runsheets integer := 0;
  v_returning_runsheets integer := 0;
  v_pending_vouchers integer := 0;
  v_open_counts integer := 0;
BEGIN
  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'warehouse hub requires an authenticated session';
  END IF;

  SELECT u.id, u.company_id, COALESCE(u.role,''), COALESCE(u.active_warehouse_role,''),
         (COALESCE(u.permissions,'[]'::jsonb) ? '*')
    INTO v_user_id, v_company_id, v_user_role, v_active_role, v_is_owner
  FROM public.users u
  WHERE u.auth_id = v_auth_id
    AND COALESCE(u.status,'Active') = 'Active'
  LIMIT 1;

  IF v_user_id IS NULL OR v_company_id IS NULL THEN
    RAISE EXCEPTION 'active warehouse user profile not found';
  END IF;

  -- Owner bypass is based on the server-side owner profile and wildcard permission.
  -- Do not use user-editable user_metadata as an authorization source.
  v_is_owner := v_is_owner AND EXISTS (
    SELECT 1 FROM public.owner_profile op WHERE op.auth_user_id = v_auth_id
  );

  SELECT (
    COALESCE(u.permissions,'[]'::jsonb) ? 'warehouse'
    OR COALESCE(u.permissions,'[]'::jsonb) ? '*'
    OR COALESCE(r.permissions,'[]'::jsonb) ? 'warehouse'
    OR EXISTS (
      SELECT 1 FROM public.role_permissions rp
      WHERE rp.role_id = u.role_id AND rp.permission_key = 'warehouse'
    )
  )
  INTO v_has_warehouse
  FROM public.users u
  LEFT JOIN public.roles r ON r.id = u.role_id AND r.company_id = u.company_id
  WHERE u.id = v_user_id
  LIMIT 1;

  IF NOT COALESCE(v_has_warehouse,false) AND NOT v_is_owner THEN
    RAISE EXCEPTION 'warehouse permission required';
  END IF;

  IF v_active_role <> ALL(ARRAY['استلام','تحضير','تحميل','مرتجعات','تفريغ','أذونات','جرد','احتياطي','مخزن شامل']::text[])
     AND NOT v_is_owner THEN
    RAISE EXCEPTION 'active warehouse role required';
  END IF;

  SELECT
    COALESCE(array_agg(b.id ORDER BY b.branch_code), ARRAY[]::uuid[]),
    COALESCE(jsonb_agg(jsonb_build_object('id',b.id,'code',b.branch_code,'name',b.name) ORDER BY b.branch_code),'[]'::jsonb)
  INTO v_allowed_branch_ids, v_branch_scope
  FROM public.branches b
  WHERE b.company_id = v_company_id
    AND app_private.user_can_access_warehouse_branch(v_user_id,v_company_id,b.id);

  IF COALESCE(array_length(v_allowed_branch_ids,1),0)=0 THEN
    RAISE EXCEPTION 'warehouse branch scope is empty';
  END IF;

  -- All current runsheet stock writers use the configured main warehouse branch.
  -- The hub only exposes runsheet totals when that branch is in the user's authorized scope.
  SELECT s.main_branch_id
    INTO v_main_branch_id
  FROM public.app_settings s
  WHERE s.company_id = v_company_id
  ORDER BY s.created_at ASC, s.id
  LIMIT 1;

  v_main_branch_access := v_main_branch_id IS NOT NULL
    AND app_private.user_can_access_warehouse_branch(v_user_id,v_company_id,v_main_branch_id);

  SELECT count(*)::integer
    INTO v_pending_purchase_orders
  FROM public.purchase_orders po
  WHERE po.company_id = v_company_id
    AND po.branch_id = ANY(v_allowed_branch_ids)
    AND po.status IN ('Approved','Sent','Partially Received');

  IF v_main_branch_access THEN
    SELECT
      count(*) FILTER (WHERE rs.status NOT IN ('Delivered','Returned','Cancelled'))::integer,
      count(*) FILTER (WHERE rs.status='Loading')::integer,
      count(*) FILTER (WHERE rs.status='Loaded')::integer,
      count(*) FILTER (WHERE rs.status='Returning')::integer
    INTO v_active_runsheets,v_loading_runsheets,v_loaded_runsheets,v_returning_runsheets
    FROM public.runsheets rs
    WHERE rs.company_id = v_company_id;
  END IF;

  SELECT count(*)::integer
    INTO v_pending_vouchers
  FROM public.stock_vouchers sv
  WHERE sv.company_id = v_company_id
    AND COALESCE(sv.status,'') NOT IN ('Completed','Cancelled','Rejected','Voided')
    AND (
      sv.from_branch_id = ANY(v_allowed_branch_ids)
      OR sv.to_branch_id = ANY(v_allowed_branch_ids)
    );

  SELECT count(*)::integer
    INTO v_open_counts
  FROM public.inventory_counts ic
  WHERE ic.company_id = v_company_id
    AND ic.branch_id = ANY(v_allowed_branch_ids)
    AND COALESCE(ic.status,'') NOT IN ('Completed','Cancelled','Closed','Posted');

  RETURN jsonb_build_object(
    'success',true,
    'generated_at',now(),
    'user',jsonb_build_object(
      'id',v_user_id,
      'company_id',v_company_id,
      'role',v_user_role,
      'active_warehouse_role',v_active_role,
      'is_owner',v_is_owner
    ),
    'branch_scope',v_branch_scope,
    'main_branch_access',v_main_branch_access,
    'metrics',jsonb_build_object(
      'pending_purchase_orders',v_pending_purchase_orders,
      'active_runsheets',v_active_runsheets,
      'loading_runsheets',v_loading_runsheets,
      'loaded_runsheets',v_loaded_runsheets,
      'returning_runsheets',v_returning_runsheets,
      'pending_vouchers',v_pending_vouchers,
      'open_counts',v_open_counts
    )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_warehouse_hub_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_warehouse_hub_snapshot() TO authenticated;

COMMENT ON FUNCTION public.get_warehouse_hub_snapshot() IS
'Read-only, authenticated, company- and branch-scoped summary for RAWAEA unified warehouse hub. No business writes.';
