-- Delivery Supervisor complaint read contract.
-- Reuses service_complaints and existing complaint relationships; no duplicate table.
-- Company scope and supervisor permission are enforced server-side.
BEGIN;

CREATE OR REPLACE FUNCTION public.delivery_supervisor_complaints_query(p_company_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_rows jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'جلسة مصادقة مطلوبة';
  END IF;
  IF p_company_id IS NULL THEN
    RAISE EXCEPTION 'سياق الشركة مطلوب';
  END IF;

  SELECT u.* INTO v_actor
  FROM public.users u
  WHERE u.auth_id = auth.uid()
    AND u.company_id = p_company_id
    AND coalesce(u.status, 'Active') = 'Active'
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المستخدم غير نشط أو لا ينتمي إلى الشركة';
  END IF;

  IF NOT (
    coalesce(v_actor.permissions, '[]'::jsonb) @> '["*"]'::jsonb
    OR coalesce(v_actor.permissions, '[]'::jsonb) @> '["delivery_supervisor"]'::jsonb
    OR coalesce(v_actor.permissions, '[]'::jsonb) @> '["fleet.read"]'::jsonb
    OR coalesce(v_actor.permissions, '[]'::jsonb) @> '["fleet.manage"]'::jsonb
  ) THEN
    RAISE EXCEPTION 'غير مصرح بقراءة شكاوى التوصيل';
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT c.id, c.complaint_code, c.company_id, c.source_type, c.status,
           c.description, c.created_at, c.updated_at, c.item_code, c.item_name,
           c.resolution, c.reviewed_at, ct.type_name AS complaint_type,
           u.id AS employee_id, u.name AS employee_name, u.email AS employee_email,
           r.runsheet_code, o.order_code
    FROM public.service_complaints c
    LEFT JOIN public.complaint_types ct ON ct.id = c.complaint_type_id
    LEFT JOIN public.users u ON u.id = c.employee_id AND u.company_id = p_company_id
    LEFT JOIN public.runsheets r ON r.id = c.runsheet_id AND r.company_id = p_company_id
    LEFT JOIN public.orders o ON o.id = c.order_id AND o.company_id = p_company_id
    WHERE c.company_id = p_company_id
    ORDER BY c.created_at DESC
    LIMIT 300
  ) x;

  RETURN jsonb_build_object('success', true, 'rows', v_rows);
END;
$function$;

REVOKE ALL ON FUNCTION public.delivery_supervisor_complaints_query(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delivery_supervisor_complaints_query(uuid) TO authenticated, service_role;

COMMIT;
