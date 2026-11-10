-- RAWAEA unified inventory control scope and costed inventory-count finalization
-- Code-only database change. It does not create or mutate operational business rows.
-- Existing signatures, SECURITY DEFINER, search_path and grants are retained.

CREATE OR REPLACE FUNCTION public.inventory_stock_snapshot(p_company_id uuid, p_user_email text DEFAULT NULL::text, p_branch_id uuid DEFAULT NULL::uuid, p_query text DEFAULT NULL::text, p_low_only boolean DEFAULT false, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_limit integer:=LEAST(GREATEST(COALESCE(p_limit,200),1),1000);
 v_offset integer:=GREATEST(COALESCE(p_offset,0),0);
 v_rows jsonb;
 v_count bigint;
 v_role text:=COALESCE(current_setting('request.jwt.claim.role',true),'');
 v_context_company uuid:=app_private.current_user_company_id();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND COALESCE(c.is_active,true)) THEN RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط'; END IF;
 IF v_role<>'service_role' THEN
   IF v_context_company IS NULL OR v_context_company<>p_company_id THEN
     RAISE EXCEPTION 'سياق الشركة غير صالح للجلسة الحالية';
   END IF;
   IF NOT (
     app_private.current_user_has_effective_permission('reports')
     OR app_private.current_user_has_effective_permission('warehouse')
     OR app_private.current_user_has_effective_permission('warehouse_manager')
     OR app_private.current_user_has_effective_permission('warehouse_supervisor')
   ) THEN RAISE EXCEPTION 'غير مصرح بقراءة أرصدة المخزون'; END IF;
   IF NOT EXISTS(
     SELECT 1 FROM public.users u
     WHERE u.auth_id=auth.uid() AND u.company_id=p_company_id
       AND COALESCE(u.status,'Active')='Active'
       AND (p_user_email IS NULL OR lower(u.email)=lower(p_user_email))
   ) THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو البريد لا يطابق الجلسة'; END IF;
 ELSIF p_user_email IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.users u WHERE u.company_id=p_company_id
     AND lower(u.email)=lower(p_user_email) AND COALESCE(u.status,'Active')='Active'
 ) THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة'; END IF;
 IF p_branch_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.branches b WHERE b.id=p_branch_id AND b.company_id=p_company_id) THEN RAISE EXCEPTION 'الفرع لا ينتمي إلى الشركة'; END IF;
 SELECT count(*) INTO v_count FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id AND b.company_id=p_company_id JOIN public.items i ON i.id=sb.item_id
 WHERE (p_branch_id IS NULL OR sb.branch_id=p_branch_id)
   AND (v_role='service_role' OR app_private.current_user_can_access_warehouse_branch(p_company_id,sb.branch_id))
   AND (NULLIF(btrim(p_query),'') IS NULL OR i.item_code ILIKE '%'||btrim(p_query)||'%' OR i.name ILIKE '%'||btrim(p_query)||'%' OR b.name ILIKE '%'||btrim(p_query)||'%')
   AND (NOT COALESCE(p_low_only,false) OR (COALESCE(i.reorder_point,0)>0 AND GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0)<=COALESCE(i.reorder_point,0)));
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.branch_name,x.item_code),'[]'::jsonb) INTO v_rows FROM (
  SELECT sb.branch_id,b.branch_code,b.name branch_name,sb.item_id,i.item_code,i.name item_name,i.unit,COALESCE(sb.qty,0) physical_qty,COALESCE(sb.allocated_qty,0) allocated_qty,GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0) available_qty,COALESCE(i.reorder_point,0) reorder_point,COALESCE(i.max_qty,0) max_qty,
   CASE WHEN COALESCE(i.max_qty,0)>COALESCE(i.reorder_point,0) THEN GREATEST(COALESCE(i.max_qty,0)-GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),0) ELSE GREATEST(COALESCE(i.reorder_point,0)-GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),0) END suggested_replenishment_qty,
   COALESCE(i.cost_price,0) cost_price,COALESCE(sb.qty,0)*COALESCE(i.cost_price,0) stock_value_at_cost,
   (COALESCE(i.reorder_point,0)>0 AND GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0)<=COALESCE(i.reorder_point,0)) low_stock,sb.updated_at
  FROM public.stock_branches sb JOIN public.branches b ON b.id=sb.branch_id AND b.company_id=p_company_id JOIN public.items i ON i.id=sb.item_id
  WHERE (p_branch_id IS NULL OR sb.branch_id=p_branch_id)
   AND (v_role='service_role' OR app_private.current_user_can_access_warehouse_branch(p_company_id,sb.branch_id))
    AND (NULLIF(btrim(p_query),'') IS NULL OR i.item_code ILIKE '%'||btrim(p_query)||'%' OR i.name ILIKE '%'||btrim(p_query)||'%' OR b.name ILIKE '%'||btrim(p_query)||'%')
    AND (NOT COALESCE(p_low_only,false) OR (COALESCE(i.reorder_point,0)>0 AND GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0)<=COALESCE(i.reorder_point,0)))
  LIMIT v_limit OFFSET v_offset) x;
 RETURN jsonb_build_object('success',true,'rows',v_rows,'count',v_count,'limit',v_limit,'offset',v_offset);
END;
$function$


;

CREATE OR REPLACE FUNCTION public.inventory_movement_report(p_company_id uuid, p_user_email text DEFAULT NULL::text, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_branch_id uuid DEFAULT NULL::uuid, p_item_id uuid DEFAULT NULL::uuid, p_movement_type text DEFAULT NULL::text, p_query text DEFAULT NULL::text, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit,200),1),1000);
  v_offset integer := GREATEST(COALESCE(p_offset,0),0);
  v_rows jsonb;
  v_count bigint;
  v_role text := COALESCE(current_setting('request.jwt.claim.role', true),'');
  v_context_company uuid := app_private.current_user_company_id();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id=p_company_id AND COALESCE(c.is_active,true)
  ) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط';
  END IF;

  IF v_role <> 'service_role' THEN
    IF v_context_company IS NULL OR v_context_company <> p_company_id THEN
      RAISE EXCEPTION 'سياق الشركة غير صالح للجلسة الحالية';
    END IF;

    IF NOT (
      app_private.current_user_has_effective_permission('reports')
      OR app_private.current_user_has_effective_permission('warehouse')
      OR app_private.current_user_has_effective_permission('warehouse_manager')
      OR app_private.current_user_has_effective_permission('warehouse_supervisor')
    ) THEN RAISE EXCEPTION 'REPORTS_OR_WAREHOUSE_PERMISSION_REQUIRED'; END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id=auth.uid()
        AND u.company_id=p_company_id
        AND COALESCE(u.status,'Active')='Active'
        AND (
          p_user_email IS NULL
          OR lower(u.email)=lower(p_user_email)
        )
    ) THEN
      RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو البريد لا يطابق الجلسة';
    END IF;
  ELSIF p_user_email IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.company_id=p_company_id
      AND lower(u.email)=lower(p_user_email)
      AND COALESCE(u.status,'Active')='Active'
  ) THEN
    RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة';
  END IF;

  IF p_branch_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.branches b
       WHERE b.id=p_branch_id AND b.company_id=p_company_id
     )
  THEN
    RAISE EXCEPTION 'الفرع لا ينتمي إلى الشركة';
  END IF;

  IF p_item_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.items i
       WHERE i.id=p_item_id
     )
  THEN
    RAISE EXCEPTION 'الصنف غير موجود';
  END IF;

  WITH base AS (
    SELECT
      il.id AS event_id,
      il.created_at,
      il.movement_date,
      il.company_id,
      il.voucher_id,
      il.reference,
      il.item_id,
      il.item_code,
      il.item_name,
      il.movement_type,
      il.qty,
      il.user_email,
      il.source_branch_id,
      il.target_branch_id
    FROM public.inventory_log il
    WHERE il.company_id=p_company_id
      AND (p_item_id IS NULL OR il.item_id=p_item_id)
      AND (p_movement_type IS NULL OR il.movement_type=p_movement_type)
  ),
  effects AS (
    SELECT
      event_id,created_at,movement_date,company_id,voucher_id,reference,
      item_id,item_code,item_name,movement_type,qty,user_email,
      source_branch_id AS branch_id,
      -qty AS effect_qty
    FROM base
    WHERE source_branch_id IS NOT NULL

    UNION ALL

    SELECT
      event_id,created_at,movement_date,company_id,voucher_id,reference,
      item_id,item_code,item_name,movement_type,qty,user_email,
      target_branch_id AS branch_id,
      qty AS effect_qty
    FROM base
    WHERE target_branch_id IS NOT NULL
      AND target_branch_id IS DISTINCT FROM source_branch_id
  ),
  states AS (
    SELECT
      e.*,
      COALESCE(sb.qty,0) AS current_qty,
      COALESCE(sb.qty,0)-COALESCE(
        SUM(e.effect_qty) OVER (
          PARTITION BY e.branch_id,e.item_id
          ORDER BY e.created_at DESC,e.event_id DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ),0
      ) AS after_qty
    FROM effects e
    JOIN public.branches b
      ON b.id=e.branch_id
     AND b.company_id=p_company_id
    LEFT JOIN public.stock_branches sb
      ON sb.branch_id=e.branch_id
     AND sb.item_id=e.item_id
  ),
  filtered AS (
    SELECT * FROM states
    WHERE (p_from_date IS NULL OR movement_date>=p_from_date)
      AND (p_to_date IS NULL OR movement_date<=p_to_date)
      AND (v_role='service_role' OR app_private.current_user_can_access_warehouse_branch(p_company_id,branch_id))
      AND (p_branch_id IS NULL OR branch_id=p_branch_id)
      AND (
        NULLIF(btrim(p_query),'') IS NULL
        OR item_code ILIKE '%'||btrim(p_query)||'%'
        OR item_name ILIKE '%'||btrim(p_query)||'%'
        OR COALESCE(reference,'') ILIKE '%'||btrim(p_query)||'%'
        OR COALESCE(voucher_id,'') ILIKE '%'||btrim(p_query)||'%'
      )
  )
  SELECT count(*) INTO v_count
  FROM filtered;

  WITH base AS (
    SELECT
      il.id AS event_id,
      il.created_at,
      il.movement_date,
      il.company_id,
      il.voucher_id,
      il.reference,
      il.item_id,
      il.item_code,
      il.item_name,
      il.movement_type,
      il.qty,
      il.user_email,
      il.source_branch_id,
      il.target_branch_id
    FROM public.inventory_log il
    WHERE il.company_id=p_company_id
      AND (p_item_id IS NULL OR il.item_id=p_item_id)
      AND (p_movement_type IS NULL OR il.movement_type=p_movement_type)
  ),
  effects AS (
    SELECT
      event_id,created_at,movement_date,voucher_id,reference,
      item_id,item_code,item_name,movement_type,qty,user_email,
      source_branch_id AS branch_id,-qty AS effect_qty
    FROM base
    WHERE source_branch_id IS NOT NULL

    UNION ALL

    SELECT
      event_id,created_at,movement_date,voucher_id,reference,
      item_id,item_code,item_name,movement_type,qty,user_email,
      target_branch_id AS branch_id,qty AS effect_qty
    FROM base
    WHERE target_branch_id IS NOT NULL
      AND target_branch_id IS DISTINCT FROM source_branch_id
  ),
  states AS (
    SELECT
      e.*,
      b.branch_code,
      b.name AS branch_name,
      COALESCE(i.unit,'') AS unit,
      COALESCE(sb.qty,0) AS current_qty,
      COALESCE(sb.qty,0)-COALESCE(
        SUM(e.effect_qty) OVER (
          PARTITION BY e.branch_id,e.item_id
          ORDER BY e.created_at DESC,e.event_id DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ),0
      ) AS after_qty
    FROM effects e
    JOIN public.branches b
      ON b.id=e.branch_id
     AND b.company_id=p_company_id
    JOIN public.items i
      ON i.id=e.item_id
    LEFT JOIN public.stock_branches sb
      ON sb.branch_id=e.branch_id
     AND sb.item_id=e.item_id
  ),
  filtered AS (
    SELECT * FROM states
    WHERE (p_from_date IS NULL OR movement_date>=p_from_date)
      AND (p_to_date IS NULL OR movement_date<=p_to_date)
      AND (v_role='service_role' OR app_private.current_user_can_access_warehouse_branch(p_company_id,branch_id))
      AND (p_branch_id IS NULL OR branch_id=p_branch_id)
      AND (
        NULLIF(btrim(p_query),'') IS NULL
        OR item_code ILIKE '%'||btrim(p_query)||'%'
        OR item_name ILIKE '%'||btrim(p_query)||'%'
        OR COALESCE(reference,'') ILIKE '%'||btrim(p_query)||'%'
        OR COALESCE(voucher_id,'') ILIKE '%'||btrim(p_query)||'%'
      )
  )
  SELECT COALESCE(
    jsonb_agg(
      to_jsonb(x)
      ORDER BY x.created_at DESC,x.event_id DESC
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM (
    SELECT
      event_id,
      created_at,
      movement_date,
      voucher_id,
      reference,
      item_id,
      item_code,
      item_name,
      unit,
      movement_type,
      qty,
      effect_qty,
      branch_id,
      branch_code,
      branch_name,
      after_qty-effect_qty AS before_qty,
      after_qty AS after_qty,
      user_email
    FROM filtered
    LIMIT v_limit OFFSET v_offset
  ) x;

  RETURN jsonb_build_object(
    'success',true,
    'rows',v_rows,
    'count',v_count,
    'limit',v_limit,
    'offset',v_offset
  );
END;
$function$


;

CREATE OR REPLACE FUNCTION public.inventory_replenishment_report(p_company_id uuid, p_user_email text DEFAULT NULL::text, p_branch_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit,200),1),1000);
  v_offset integer := GREATEST(COALESCE(p_offset,0),0);
  v_rows jsonb;
  v_role text := COALESCE(current_setting('request.jwt.claim.role', true),'');
  v_context_company uuid := app_private.current_user_company_id();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id=p_company_id AND COALESCE(c.is_active,true)
  ) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط';
  END IF;

  IF v_role <> 'service_role' THEN
    IF v_context_company IS NULL OR v_context_company <> p_company_id THEN
      RAISE EXCEPTION 'سياق الشركة غير صالح للجلسة الحالية';
    END IF;

    IF NOT (
      app_private.current_user_has_effective_permission('reports')
      OR app_private.current_user_has_effective_permission('warehouse')
      OR app_private.current_user_has_effective_permission('warehouse_manager')
      OR app_private.current_user_has_effective_permission('warehouse_supervisor')
    ) THEN RAISE EXCEPTION 'REPORTS_OR_WAREHOUSE_PERMISSION_REQUIRED'; END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id=auth.uid()
        AND u.company_id=p_company_id
        AND COALESCE(u.status,'Active')='Active'
        AND (
          p_user_email IS NULL
          OR lower(u.email)=lower(p_user_email)
        )
    ) THEN
      RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو البريد لا يطابق الجلسة';
    END IF;
  ELSIF p_user_email IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.company_id=p_company_id
      AND lower(u.email)=lower(p_user_email)
      AND COALESCE(u.status,'Active')='Active'
  ) THEN
    RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة';
  END IF;

  IF p_branch_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.branches b
       WHERE b.id=p_branch_id AND b.company_id=p_company_id
     )
  THEN
    RAISE EXCEPTION 'الفرع لا ينتمي إلى الشركة';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      to_jsonb(x)
      ORDER BY x.deficit_qty DESC,x.branch_name,x.item_code
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM (
    SELECT
      sb.branch_id,
      b.branch_code,
      b.name AS branch_name,
      i.id AS item_id,
      i.item_code,
      i.name AS item_name,
      i.unit,
      GREATEST(
        COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),
        0
      ) AS available_qty,
      COALESCE(sb.allocated_qty,0) AS allocated_qty,
      COALESCE(i.reorder_point,0) AS reorder_point,
      COALESCE(i.max_qty,0) AS max_qty,
      GREATEST(
        COALESCE(i.reorder_point,0)-
        GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),
        0
      ) AS deficit_qty,
      CASE
        WHEN COALESCE(i.max_qty,0)>COALESCE(i.reorder_point,0)
        THEN GREATEST(
          COALESCE(i.max_qty,0)-
          GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),
          0
        )
        ELSE GREATEST(
          COALESCE(i.reorder_point,0)-
          GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),
          0
        )
      END AS recommended_order_qty,
      COALESCE(i.cost_price,0) AS cost_price,
      CASE
        WHEN COALESCE(i.max_qty,0)>COALESCE(i.reorder_point,0)
        THEN GREATEST(
          COALESCE(i.max_qty,0)-
          GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),
          0
        )
        ELSE GREATEST(
          COALESCE(i.reorder_point,0)-
          GREATEST(COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),0),
          0
        )
      END * COALESCE(i.cost_price,0) AS recommended_order_value
    FROM public.stock_branches sb
    JOIN public.branches b
      ON b.id=sb.branch_id
     AND b.company_id=p_company_id
    JOIN public.items i
      ON i.id=sb.item_id
    WHERE (p_branch_id IS NULL OR sb.branch_id=p_branch_id)
      AND (v_role='service_role' OR app_private.current_user_can_access_warehouse_branch(p_company_id,sb.branch_id))
      AND COALESCE(i.reorder_point,0)>0
      AND GREATEST(
        COALESCE(sb.qty,0)-COALESCE(sb.allocated_qty,0),
        0
      )<=COALESCE(i.reorder_point,0)
    LIMIT v_limit OFFSET v_offset
  ) x;

  RETURN jsonb_build_object(
    'success',true,
    'rows',v_rows,
    'limit',v_limit,
    'offset',v_offset
  );
END;
$function$


;

CREATE OR REPLACE FUNCTION public.inventory_stock_request_engine(p_company_id uuid, p_user_email text, p_operation text, p_payload jsonb DEFAULT '{}'::jsonb, p_operation_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_op text:=upper(btrim(coalesce(p_operation,'')));
  v_request public.inventory_stock_requests%ROWTYPE;
  v_detail jsonb;
  v_item public.items%ROWTYPE;
  v_source uuid;
  v_target uuid;
  v_request_id uuid;
  v_voucher jsonb;
  v_request_code text;
  v_num bigint:=0;
  v_items jsonb;
  v_rows jsonb;
  v_count bigint;
  v_limit integer:=LEAST(GREATEST(COALESCE((p_payload->>'limit')::integer,200),1),1000);
  v_offset integer:=GREATEST(COALESCE((p_payload->>'offset')::integer,0),0);
  v_privileged boolean:=false;
BEGIN
  SELECT * INTO v_actor FROM public.users u
  WHERE u.company_id=p_company_id
    AND lower(u.email)=lower(coalesce(p_user_email,''))
    AND COALESCE(u.status,'Active')='Active'
  LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو غير نشط'; END IF;

  v_privileged:=
    COALESCE(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR v_actor.role IN ('مدير مخازن','مشرف مخازن','مدير عام');

  IF NOT (
    v_privileged
    OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["transfer"]'::jsonb
    OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["warehouse_manager"]'::jsonb
    OR COALESCE(v_actor.permissions,'[]'::jsonb) @> '["warehouse_supervisor"]'::jsonb
    OR (
      COALESCE(v_actor.active_warehouse_role,'')='مخزن شامل'
      AND COALESCE(v_actor.permissions,'[]'::jsonb) @> '["warehouse"]'::jsonb
    )
  ) THEN
    RAISE EXCEPTION 'غير مصرح بإدارة طلبات المخزون';
  END IF;

  IF v_op='LIST' THEN
    SELECT count(*) INTO v_count
    FROM public.inventory_stock_requests r
    WHERE r.company_id=p_company_id
      AND (
        v_privileged
        OR (
          app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,r.source_branch_id)
          AND app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,r.target_branch_id)
        )
      );

    SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC,x.request_code),'[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT r.*
      FROM public.inventory_stock_requests r
      WHERE r.company_id=p_company_id
        AND (
          v_privileged
          OR (
            app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,r.source_branch_id)
            AND app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,r.target_branch_id)
          )
        )
      ORDER BY r.created_at DESC,r.request_code
      LIMIT v_limit OFFSET v_offset
    ) x;

    RETURN jsonb_build_object('success',true,'rows',v_rows,'count',v_count,'limit',v_limit,'offset',v_offset);
  END IF;

  IF v_op='CREATE' THEN
    IF NULLIF(btrim(p_operation_id),'') IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب'; END IF;
    IF EXISTS (SELECT 1 FROM public.inventory_stock_requests r WHERE r.company_id=p_company_id AND r.operation_id=p_operation_id) THEN
      SELECT * INTO v_request FROM public.inventory_stock_requests r WHERE r.company_id=p_company_id AND r.operation_id=p_operation_id FOR UPDATE;
      RETURN jsonb_build_object('success',true,'duplicate',true,'request_id',v_request.id,'request_code',v_request.request_code,'status',v_request.status,'operation_id',p_operation_id);
    END IF;
    v_source:=(p_payload->>'source_branch_id')::uuid;
    v_target:=(p_payload->>'target_branch_id')::uuid;
    IF v_source IS NULL OR v_target IS NULL OR v_source=v_target THEN RAISE EXCEPTION 'يجب تحديد فرعي مصدر ووجهة مختلفين'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_source AND b.company_id=p_company_id AND COALESCE(b.is_active,true)) THEN RAISE EXCEPTION 'فرع المصدر غير صالح'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_target AND b.company_id=p_company_id AND COALESCE(b.is_active,true)) THEN RAISE EXCEPTION 'فرع الوجهة غير صالح'; END IF;
    IF NOT v_privileged AND (
      NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_source)
      OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_target)
    ) THEN RAISE EXCEPTION 'المصدر أو الوجهة خارج نطاق فروع المستخدم'; END IF;
    IF jsonb_typeof(p_payload->'items')<>'array' OR jsonb_array_length(p_payload->'items')=0 THEN RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل'; END IF;
    IF EXISTS (SELECT 1 FROM jsonb_to_recordset(p_payload->'items') AS x(item_code text,qty numeric) GROUP BY x.item_code HAVING count(*)>1) THEN RAISE EXCEPTION 'لا يجوز تكرار الصنف في نفس الطلب'; END IF;
    PERFORM pg_advisory_xact_lock(hashtext('rawaea:inventory-stock-request:'||p_company_id::text));
    SELECT COALESCE(max(substring(request_code from '[0-9]+$')::bigint),0) INTO v_num FROM public.inventory_stock_requests WHERE company_id=p_company_id;
    v_request_code:='SR-'||(v_num+1)::text;
    INSERT INTO public.inventory_stock_requests(company_id,request_code,request_date,request_type,source_branch_id,target_branch_id,status,requested_by,notes,operation_id,created_at,updated_at)
    VALUES(p_company_id,v_request_code,COALESCE((p_payload->>'request_date')::date,current_date),'TRANSFER',v_source,v_target,'Pending',p_user_email,p_payload->>'notes',p_operation_id,now(),now())
    RETURNING * INTO v_request;
    FOR v_detail IN SELECT value FROM jsonb_array_elements(p_payload->'items') LOOP
      IF COALESCE((v_detail->>'qty')::numeric,0)<=0 OR NULLIF(btrim(v_detail->>'item_code'),'') IS NULL THEN RAISE EXCEPTION 'بيانات بند طلب المخزون غير صالحة'; END IF;
      SELECT * INTO v_item FROM public.items i WHERE i.company_id=p_company_id AND i.item_code=btrim(v_detail->>'item_code');
      IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود: %',v_detail->>'item_code'; END IF;
      INSERT INTO public.inventory_stock_request_details(request_id,item_id,item_code,item_name,unit,requested_qty,notes,created_at,updated_at)
      VALUES(v_request.id,v_item.id,v_item.item_code,v_item.name,v_item.unit,(v_detail->>'qty')::numeric,v_detail->>'notes',now(),now());
    END LOOP;
    RETURN jsonb_build_object('success',true,'duplicate',false,'request_id',v_request.id,'request_code',v_request_code,'status','Pending','operation_id',p_operation_id);
  END IF;

  IF p_payload->>'request_id' IS NULL THEN RAISE EXCEPTION 'request_id مطلوب'; END IF;
  SELECT * INTO v_request FROM public.inventory_stock_requests r WHERE r.id=(p_payload->>'request_id')::uuid AND r.company_id=p_company_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'طلب المخزون غير موجود'; END IF;

  IF NOT v_privileged AND (
    NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_request.source_branch_id)
    OR NOT app_private.user_can_access_warehouse_branch(v_actor.id,p_company_id,v_request.target_branch_id)
  ) THEN RAISE EXCEPTION 'طلب المخزون خارج نطاق الفروع المسموح بها'; END IF;

  IF v_op='GET' THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.item_code),'[]'::jsonb) INTO v_items
    FROM (SELECT d.item_id,d.item_code,d.item_name,d.unit,d.requested_qty,d.notes FROM public.inventory_stock_request_details d WHERE d.request_id=v_request.id) x;
    RETURN jsonb_build_object('success',true,'request',to_jsonb(v_request),'items',v_items);
  END IF;

  IF v_op='APPROVE' THEN
    IF v_request.status<>'Pending' THEN RAISE EXCEPTION 'لا يمكن اعتماد طلب في حالته الحالية: %',v_request.status; END IF;
    UPDATE public.inventory_stock_requests SET status='Approved',approved_by=p_user_email,approved_at=now(),updated_at=now() WHERE id=v_request.id;
    RETURN jsonb_build_object('success',true,'request_id',v_request.id,'request_code',v_request.request_code,'status','Approved');
  END IF;

  IF v_op='REJECT' THEN
    IF v_request.status<>'Pending' THEN RAISE EXCEPTION 'لا يمكن رفض طلب في حالته الحالية: %',v_request.status; END IF;
    UPDATE public.inventory_stock_requests SET status='Rejected',rejected_by=p_user_email,rejected_at=now(),rejection_reason=NULLIF(btrim(p_payload->>'reason'),''),updated_at=now() WHERE id=v_request.id;
    RETURN jsonb_build_object('success',true,'request_id',v_request.id,'request_code',v_request.request_code,'status','Rejected');
  END IF;

  IF v_op='CONVERT' THEN
    IF v_request.status='Converted' AND v_request.converted_voucher_id IS NOT NULL THEN
      RETURN jsonb_build_object('success',true,'duplicate',true,'request_id',v_request.id,'request_code',v_request.request_code,'status','Converted','voucher_id',v_request.converted_voucher_id);
    END IF;
    IF v_request.status<>'Approved' THEN RAISE EXCEPTION 'لا يمكن تحويل طلب إلا بعد اعتماده'; END IF;
    SELECT COALESCE(jsonb_agg(jsonb_build_object('itemCode',d.item_code,'itemName',d.item_name,'unit',d.unit,'qty',d.requested_qty,'unitPrice',0,'notes',d.notes) ORDER BY d.item_code),'[]'::jsonb)
    INTO v_items
    FROM public.inventory_stock_request_details d WHERE d.request_id=v_request.id;
    v_voucher:=public.create_manual_stock_voucher_atomic(
      p_company_id,
      'Transfer',
      v_request.request_code,
      'Branch',v_request.source_branch_id,
      'Branch',v_request.target_branch_id,
      COALESCE(v_request.notes,''),p_user_email,v_items
    );
    v_request_id:=(v_voucher->>'voucher_id')::uuid;
    UPDATE public.inventory_stock_requests SET status='Converted',converted_voucher_id=v_request_id,updated_at=now() WHERE id=v_request.id AND status='Approved';
    RETURN v_voucher || jsonb_build_object('success',true,'request_id',v_request.id,'request_code',v_request.request_code,'status','Converted');
  END IF;

  IF v_op='CANCEL' THEN
    IF v_request.status IN ('Converted','Cancelled') THEN RAISE EXCEPTION 'لا يمكن إلغاء الطلب بعد التحويل أو الإلغاء'; END IF;
    UPDATE public.inventory_stock_requests SET status='Cancelled',updated_at=now() WHERE id=v_request.id;
    RETURN jsonb_build_object('success',true,'request_id',v_request.id,'request_code',v_request.request_code,'status','Cancelled');
  END IF;

  RAISE EXCEPTION 'عملية طلب مخزون غير مدعومة: %',v_op;
END;
$function$


;

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
  v_items jsonb;
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

    -- Lock existing stock rows and refresh the book balance within this transaction.
    PERFORM 1
    FROM public.stock_branches sb
    JOIN public.inventory_count_details d
      ON d.branch_id=sb.branch_id AND d.item_id=sb.item_id
    WHERE d.count_id=v_count.id
    FOR UPDATE OF sb;

    UPDATE public.inventory_count_details d
    SET system_qty=COALESCE((
          SELECT sb.qty FROM public.stock_branches sb
          WHERE sb.branch_id=d.branch_id AND sb.item_id=d.item_id
        ),0),
        variance_qty=COALESCE(d.counted_qty,0)-COALESCE((
          SELECT sb.qty FROM public.stock_branches sb
          WHERE sb.branch_id=d.branch_id AND sb.item_id=d.item_id
        ),0),
        updated_at=now()
    WHERE d.count_id=v_count.id;

    -- Every branch goes through the established costed stock + balanced GL posting core.
    FOR v_branch_id IN
      SELECT DISTINCT d.branch_id
      FROM public.inventory_count_details d
      WHERE d.count_id=v_count.id
      ORDER BY d.branch_id
    LOOP
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'item_id',d.item_id,
            'item_code',d.item_code,
            'qty',d.counted_qty,
            'operation_kind','ADJUSTMENT'
          ) ORDER BY d.item_code
        ),
        '[]'::jsonb
      )
      INTO v_items
      FROM public.inventory_count_details d
      WHERE d.count_id=v_count.id
        AND d.branch_id=v_branch_id
        AND d.counted_qty IS NOT NULL;

      PERFORM public.post_inventory_adjustment_atomic(
        p_company_id,
        v_branch_id,
        'replace',
        'COUNT-'||v_count.id::text||'-'||v_branch_id::text,
        COALESCE(
          NULLIF(btrim(v_count.notes),''),
          NULLIF(btrim(v_count.reference),''),
          'تسوية جرد'
        ),
        p_user_email,
        v_items
      );
    END LOOP;

    UPDATE public.inventory_count_details
    SET variance_qty=COALESCE(counted_qty,0)-COALESCE(system_qty,0),
        adjusted=true,
        updated_at=now()
    WHERE count_id=v_count.id;

    UPDATE public.inventory_counts
    SET status='Adjusted',completed_at=now(),updated_at=now()
    WHERE id=v_count.id AND status<>'Adjusted';

    RETURN jsonb_build_object(
      'success',true,
      'count_id',v_count.id,
      'status','Adjusted',
      'accounting_engine','post_inventory_adjustment_atomic'
    );
  END IF;

  IF v_op='CANCEL' THEN
    UPDATE public.inventory_counts SET status='Cancelled',completed_at=COALESCE(completed_at,now()),updated_at=now() WHERE id=v_count.id AND status NOT IN ('Adjusted','Cancelled');
    RETURN jsonb_build_object('success',true,'count_id',v_count.id,'status','Cancelled');
  END IF;

  RAISE EXCEPTION 'عملية جرد غير مدعومة: %',v_op;
END;
$function$


;