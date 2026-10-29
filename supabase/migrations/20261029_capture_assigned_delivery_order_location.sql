-- Capture GPS for the specific delivery order only when the authenticated assigned driver is actively delivering it.
-- No direct UPDATE grant is made to delivery users; all guards live in this SECURITY DEFINER RPC.
CREATE OR REPLACE FUNCTION public.capture_assigned_delivery_order_location(
  p_runsheet_id uuid,
  p_order_id uuid,
  p_latitude numeric,
  p_longitude numeric,
  p_accuracy_m numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_company_id uuid;
  v_actor public.users%ROWTYPE;
  v_runsheet public.runsheets%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_rows integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'جلسة المصادقة مطلوبة';
  END IF;

  IF p_runsheet_id IS NULL OR p_order_id IS NULL THEN
    RAISE EXCEPTION 'الرانشيت والأوردر مطلوبان';
  END IF;

  IF p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude < -90 OR p_latitude > 90
     OR p_longitude < -180 OR p_longitude > 180
     OR (p_latitude = 0 AND p_longitude = 0) THEN
    RAISE EXCEPTION 'إحداثيات GPS غير صالحة';
  END IF;

  -- Persist only a reasonably accurate GPS fix from the driver's device.
  IF p_accuracy_m IS NULL OR p_accuracy_m < 0 OR p_accuracy_m > 50 THEN
    RAISE EXCEPTION 'دقة GPS غير كافية؛ أعد المحاولة عند توفر دقة 50 مترًا أو أفضل';
  END IF;

  v_company_id := app_private.current_user_company_id();
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'تعذر تحديد شركة المستخدم';
  END IF;

  SELECT u.* INTO v_actor
  FROM public.users u
  WHERE u.auth_id = auth.uid()
    AND u.company_id = v_company_id
    AND coalesce(u.status, 'Active') = 'Active'
  LIMIT 1;

  IF NOT FOUND
     OR v_actor.role IS DISTINCT FROM 'مندوب توصيل'
     OR NOT app_private.current_user_has_permission('delivery'::text) THEN
    RAISE EXCEPTION 'غير مصرح بتسجيل موقع تسليم بهذا الحساب';
  END IF;

  SELECT r.* INTO v_runsheet
  FROM public.runsheets r
  WHERE r.id = p_runsheet_id
    AND r.company_id = v_company_id
    AND r.deliverer_id = v_actor.id
    AND r.status = 'Delivering'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الرانشيت غير نشط أو غير مسند إلى هذا المندوب';
  END IF;

  SELECT o.* INTO v_order
  FROM public.orders o
  WHERE o.id = p_order_id
    AND o.company_id = v_company_id
    AND o.runsheet_id = v_runsheet.id
    AND o.order_status IN ('Loaded', 'Delivering', 'Partially Delivered')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الأوردر غير تابع للرانشيت النشط أو لم يعد قابلًا لتحديد الموقع';
  END IF;

  -- Preserve an already-valid order-level location; never silently overwrite it.
  IF v_order.latitude IS NOT NULL
     AND v_order.longitude IS NOT NULL
     AND v_order.latitude BETWEEN -90 AND 90
     AND v_order.longitude BETWEEN -180 AND 180
     AND NOT (v_order.latitude = 0 AND v_order.longitude = 0) THEN
    RETURN jsonb_build_object(
      'success', true,
      'updated', false,
      'code', 'LOCATION_ALREADY_SET',
      'order_id', v_order.id,
      'latitude', v_order.latitude,
      'longitude', v_order.longitude
    );
  END IF;

  UPDATE public.orders
  SET latitude = p_latitude,
      longitude = p_longitude,
      updated_at = now()
  WHERE id = v_order.id
    AND company_id = v_company_id
    AND runsheet_id = v_runsheet.id;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'تعذر حفظ موقع الأوردر';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'updated', true,
    'order_id', v_order.id,
    'runsheet_id', v_runsheet.id,
    'latitude', p_latitude,
    'longitude', p_longitude,
    'accuracy_m', p_accuracy_m
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.capture_assigned_delivery_order_location(uuid, uuid, numeric, numeric, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capture_assigned_delivery_order_location(uuid, uuid, numeric, numeric, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.capture_assigned_delivery_order_location(uuid, uuid, numeric, numeric, numeric) TO authenticated;

COMMENT ON FUNCTION public.capture_assigned_delivery_order_location(uuid, uuid, numeric, numeric, numeric)
IS 'Save a verified GPS point for an order on the authenticated driver''s own Delivering runsheet. Enforces company, user, runsheet, status, and GPS accuracy; does not permit overwriting an existing valid point.';
