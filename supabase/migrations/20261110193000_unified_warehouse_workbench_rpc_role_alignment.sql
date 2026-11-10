-- RAWAEA ERP — Unified Warehouse Workbench RPC role alignment
-- Scope: preserve the canonical inventory engines while allowing the assigned
-- "مخزن شامل" role to use the same existing, tenant- and branch-scoped services.
-- No tables, stock movements, accounting entries, or new write endpoints are created.

DO $migration$
DECLARE
  v_definition text;

  v_old_reporting text := $old$
  v_reporting :=
      v_privileged
      OR coalesce(v_actor.permissions,'[]'::jsonb) @> jsonb_build_array('reports');
$old$;
  v_new_reporting text := $new$
  v_reporting :=
      v_privileged
      OR app_private.current_user_has_effective_permission('reports');
$new$;

  v_old_warehouse text := $old$
  v_warehouse :=
      v_privileged
      OR coalesce(v_actor.permissions,'[]'::jsonb) @> jsonb_build_array('warehouse')
      OR coalesce(v_actor.permissions,'[]'::jsonb) @> jsonb_build_array('warehouse_manager')
      OR coalesce(v_actor.permissions,'[]'::jsonb) @> jsonb_build_array('warehouse_supervisor');
$old$;
  v_new_warehouse text := $new$
  v_warehouse :=
      v_privileged
      OR app_private.current_user_has_effective_permission('warehouse')
      OR app_private.current_user_has_effective_permission('warehouse_manager')
      OR app_private.current_user_has_effective_permission('warehouse_supervisor');
$new$;

  v_old_qmp text := $old$
  IF NOT v_owner AND NOT (
    v_actor.active_warehouse_role='استلام'
    AND (public.hr_user_has_permission(v_actor.id,'warehouse')
      OR public.hr_user_has_permission(v_actor.id,'receiving'))
  ) THEN
    RAISE EXCEPTION 'QMP_RECEIVER_PERMISSION_REQUIRED';
  END IF;
$old$;
  v_new_qmp text := $new$
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
    RAISE EXCEPTION 'QMP_RECEIVER_PERMISSION_REQUIRED';
  END IF;
$new$;
BEGIN
  -- Inventory Control: recognize permissions inherited from the user's assigned
  -- role, using the canonical effective-permission resolver rather than only
  -- the legacy direct permissions JSON on public.users.
  SELECT pg_get_functiondef('public.inventory_control(text,jsonb)'::regprocedure)
    INTO v_definition;

  IF v_definition IS NULL
     OR position(v_old_reporting IN v_definition)=0
     OR position(v_old_warehouse IN v_definition)=0 THEN
    RAISE EXCEPTION
      'inventory_control role guards differ from the reviewed production contract; migration stopped without modification';
  END IF;

  v_definition := replace(v_definition,v_old_reporting,v_new_reporting);
  v_definition := replace(v_definition,v_old_warehouse,v_new_warehouse);
  EXECUTE v_definition;

  -- Quick-market receiving queue: align the read-side role gate with the
  -- existing receive-purchase Edge Function and atomic receipt RPC. The
  -- receiving function already enforces company, invoice, actor and branch
  -- scope, and the accepted quantity remains the only quantity posted.
  SELECT pg_get_functiondef('public.get_quick_market_receiving_queue_atomic(uuid)'::regprocedure)
    INTO v_definition;

  IF v_definition IS NULL OR position(v_old_qmp IN v_definition)=0 THEN
    RAISE EXCEPTION
      'get_quick_market_receiving_queue_atomic role guard differs from the reviewed production contract; migration stopped without modification';
  END IF;

  v_definition := replace(v_definition,v_old_qmp,v_new_qmp);
  EXECUTE v_definition;

  -- Fail closed if either role predicate did not persist exactly as intended.
  SELECT pg_get_functiondef('public.inventory_control(text,jsonb)'::regprocedure)
    INTO v_definition;
  IF position(v_new_reporting IN v_definition)=0
     OR position(v_new_warehouse IN v_definition)=0 THEN
    RAISE EXCEPTION 'inventory_control effective-role verification failed';
  END IF;

  SELECT pg_get_functiondef('public.get_quick_market_receiving_queue_atomic(uuid)'::regprocedure)
    INTO v_definition;
  IF position(v_new_qmp IN v_definition)=0 THEN
    RAISE EXCEPTION 'quick-market receiving role verification failed';
  END IF;
END
$migration$;
