-- Canonical source for applied Supabase migration:
-- delivery_agent_user_link_company_guard_20261029
-- Adds company/active-user validation to existing AGENT_CREATE and AGENT_UPDATE commands.
-- Preserves the existing command RPC, authorization, operation registry, and all other commands.

CREATE OR REPLACE FUNCTION public.delivery_logistics_command_atomic(p_company_id uuid, p_command text, p_payload jsonb DEFAULT '{}'::jsonb, p_operation_id text DEFAULT NULL::text, p_actor_user_id uuid DEFAULT NULL::uuid, p_actor_email text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_command text := upper(btrim(coalesce(p_command,'')));
  v_registry public.erp_operation_registry%ROWTYPE;
  v_response jsonb;
  v_rows integer;
  v_operation_key text;
  v_plan public.delivery_route_plans%ROWTYPE;
  v_stop public.delivery_route_stops%ROWTYPE;
  v_agent public.delivery_agents%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_receipt public.delivery_collection_receipts%ROWTYPE;
  v_existing numeric;
  v_allowed numeric;
  v_receipt_code text;
  v_status text;
  v_actual_at timestamptz;

  v_runsheet public.runsheets%ROWTYPE;

  v_missing integer;
  v_total_stops integer;
  v_seq integer;
  v_prev_lat numeric;
  v_prev_lon numeric;
  v_next_id uuid;
  v_next_lat numeric;
  v_next_lon numeric;
  v_dist numeric;
  v_total_km numeric := 0;
  v_elapsed timestamptz;
  v_service_minutes integer;
  v_speed numeric;
BEGIN
  IF p_company_id IS NULL THEN RAISE EXCEPTION 'سياق الشركة مطلوب'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND c.is_active=true) THEN
    RAISE EXCEPTION 'الشركة غير موجودة أو غير نشطة';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT * INTO v_actor
    FROM public.users u
    WHERE u.auth_id=auth.uid()
      AND u.company_id=p_company_id
      AND coalesce(u.status,'Active')='Active'
    LIMIT 1;
  ELSE
    SELECT * INTO v_actor
    FROM public.users u
    WHERE u.id=p_actor_user_id
      AND u.company_id=p_company_id
      AND coalesce(u.status,'Active')='Active'
    LIMIT 1;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'هوية المستخدم أو سياق الشركة غير صالح'; END IF;

  IF p_actor_email IS NOT NULL AND lower(p_actor_email)<>lower(v_actor.email) THEN
    RAISE EXCEPTION 'بريد المنفذ لا يطابق هوية المستخدم';
  END IF;

  IF NULLIF(btrim(v_command),'') IS NULL THEN RAISE EXCEPTION 'الأمر مطلوب'; END IF;
  IF NULLIF(btrim(p_operation_id),'') IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لإعادة المحاولة الآمنة'; END IF;

  IF NOT (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["delivery_supervisor"]'::jsonb
    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["fleet.manage"]'::jsonb
    OR v_actor.role IN ('مدير عام','مدير مخازن','مدير مالي')
  ) THEN
    RAISE EXCEPTION 'غير مصرح بإدارة التوصيل واللوجستيات';
  END IF;

  v_operation_key := 'DELIVERY:'||p_operation_id;

  INSERT INTO public.erp_operation_registry(company_id,operation_type,operation_key,request_payload,status)
  VALUES(p_company_id,'DELIVERY',v_operation_key,coalesce(p_payload,'{}'::jsonb),'processing')
  ON CONFLICT (company_id,operation_type,operation_key) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  SELECT * INTO v_registry
  FROM public.erp_operation_registry
  WHERE company_id=p_company_id
    AND operation_type='DELIVERY'
    AND operation_key=v_operation_key
  FOR UPDATE;

  IF v_registry.request_payload <> coalesce(p_payload,'{}'::jsonb) THEN
    RAISE EXCEPTION 'operation_id conflict: نفس الهوية استُخدمت بطلب مختلف';
  END IF;
  IF v_registry.status='completed' THEN
    RETURN coalesce(v_registry.response_payload,'{}'::jsonb) || jsonb_build_object('duplicate',true);
  END IF;
  IF v_rows=0 AND v_registry.status='processing' AND v_registry.created_at > now()-interval '15 minutes' THEN
    RAISE EXCEPTION 'delivery operation is already processing';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('email',v_actor.email)::text, true);

  IF v_command='AGENT_CREATE' THEN
    IF nullif(btrim(p_payload->>'agent_code'),'') IS NULL OR nullif(btrim(p_payload->>'full_name'),'') IS NULL THEN
      RAISE EXCEPTION 'كود واسم مندوب التوصيل مطلوبان';
    END IF;
    IF nullif(p_payload->>'user_id','') IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id=nullif(p_payload->>'user_id','')::uuid
        AND u.company_id=p_company_id
        AND coalesce(u.status,'Active')='Active'
    ) THEN
      RAISE EXCEPTION 'حساب المستخدم غير نشط أو لا ينتمي إلى الشركة';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.delivery_agents
      WHERE company_id=p_company_id AND lower(agent_code)=lower(btrim(p_payload->>'agent_code'))
    ) THEN
      RAISE EXCEPTION 'كود مندوب التوصيل مستخدم بالفعل';
    END IF;
    INSERT INTO public.delivery_agents(
      company_id,agent_code,full_name,phone,email,user_id,employment_type,status,default_branch_id,notes,created_by,updated_by
    )
    VALUES(
      p_company_id,btrim(p_payload->>'agent_code'),btrim(p_payload->>'full_name'),
      nullif(btrim(p_payload->>'phone'),''),
      nullif(btrim(p_payload->>'email'),''),
      nullif(p_payload->>'user_id','')::uuid,
      coalesce(nullif(p_payload->>'employment_type',''),'Employee'),
      coalesce(nullif(p_payload->>'status',''),'Active'),
      nullif(p_payload->>'default_branch_id','')::uuid,
      nullif(p_payload->>'notes',''),
      v_actor.email,v_actor.email
    )
    RETURNING * INTO v_agent;
    v_response:=jsonb_build_object('success',true,'command',v_command,'agent',to_jsonb(v_agent));

  ELSIF v_command='AGENT_UPDATE' THEN
    SELECT * INTO v_agent
    FROM public.delivery_agents
    WHERE id=nullif(p_payload->>'agent_id','')::uuid AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'مندوب التوصيل غير موجود'; END IF;
    IF p_payload ? 'user_id'
       AND nullif(p_payload->>'user_id','') IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.users u
         WHERE u.id=nullif(p_payload->>'user_id','')::uuid
           AND u.company_id=p_company_id
           AND coalesce(u.status,'Active')='Active'
       ) THEN
      RAISE EXCEPTION 'حساب المستخدم غير نشط أو لا ينتمي إلى الشركة';
    END IF;
    UPDATE public.delivery_agents
    SET agent_code=coalesce(nullif(btrim(p_payload->>'agent_code'),''),agent_code),
        full_name=coalesce(nullif(btrim(p_payload->>'full_name'),''),full_name),
        phone=case when p_payload ? 'phone' then nullif(btrim(p_payload->>'phone'),'') else phone end,
        email=case when p_payload ? 'email' then nullif(btrim(p_payload->>'email'),'') else email end,
        user_id=case when p_payload ? 'user_id' then nullif(p_payload->>'user_id','')::uuid else user_id end,
        employment_type=coalesce(nullif(p_payload->>'employment_type',''),employment_type),
        status=coalesce(nullif(p_payload->>'status',''),status),
        default_branch_id=case when p_payload ? 'default_branch_id' then nullif(p_payload->>'default_branch_id','')::uuid else default_branch_id end,
        notes=case when p_payload ? 'notes' then p_payload->>'notes' else notes end,
        updated_by=v_actor.email,updated_at=now()
    WHERE id=v_agent.id AND company_id=p_company_id
    RETURNING * INTO v_agent;
    v_response:=jsonb_build_object('success',true,'command',v_command,'agent',to_jsonb(v_agent));

  ELSIF v_command='ROUTE_PLAN_CREATE' THEN
    SELECT * INTO v_runsheet
    FROM public.runsheets
    WHERE company_id=p_company_id
      AND (
        id=nullif(p_payload->>'runsheet_id','')::uuid
        OR runsheet_code=nullif(btrim(p_payload->>'runsheet_code'),'')
      )
    LIMIT 1
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الرانشيت غير موجود'; END IF;
    IF v_runsheet.status IN ('Cancelled','Completed','Deleted') THEN
      RAISE EXCEPTION 'لا يمكن تخطيط رانشيت في حالته الحالية: %',v_runsheet.status;
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.delivery_route_plans
      WHERE company_id=p_company_id AND runsheet_id=v_runsheet.id AND status<>'Cancelled'
    ) THEN
      SELECT * INTO v_plan FROM public.delivery_route_plans
      WHERE company_id=p_company_id AND runsheet_id=v_runsheet.id AND status<>'Cancelled'
      ORDER BY created_at DESC LIMIT 1;
      RETURN jsonb_build_object('success',true,'duplicate',true,'plan_id',v_plan.id,'plan_code',v_plan.plan_code,'status',v_plan.status);
    END IF;

    INSERT INTO public.delivery_route_plans(
      company_id,plan_code,runsheet_id,status,optimization_strategy,planned_start_at,
      start_latitude,start_longitude,end_latitude,end_longitude,planned_speed_kmh,
      default_service_minutes,notes,created_by,updated_by
    )
    VALUES(
      p_company_id,
      'DLP-'||v_runsheet.runsheet_code||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6),
      v_runsheet.id,'Draft',
      coalesce(nullif(p_payload->>'optimization_strategy',''),'Manual'),
      nullif(p_payload->>'planned_start_at','')::timestamptz,
      nullif(p_payload->>'start_latitude','')::numeric,
      nullif(p_payload->>'start_longitude','')::numeric,
      nullif(p_payload->>'end_latitude','')::numeric,
      nullif(p_payload->>'end_longitude','')::numeric,
      nullif(p_payload->>'planned_speed_kmh','')::numeric,
      coalesce(nullif(p_payload->>'default_service_minutes','')::integer,0),
      nullif(p_payload->>'notes',''),
      v_actor.email,v_actor.email
    )
    RETURNING * INTO v_plan;

    INSERT INTO public.delivery_route_stops(company_id,route_plan_id,order_id,stop_sequence,planned_service_minutes)
    SELECT p_company_id,v_plan.id,o.id,
           row_number() over(order by o.order_date,o.created_at,o.order_code),
           coalesce(v_plan.default_service_minutes,0)
    FROM public.orders o
    WHERE o.company_id=p_company_id AND o.runsheet_id=v_runsheet.id;

    SELECT count(*) INTO v_total_stops FROM public.delivery_route_stops WHERE route_plan_id=v_plan.id;
    IF v_total_stops=0 THEN
      RAISE EXCEPTION 'الرانشيت لا يحتوي أوردرات قابلة للتوصيل';
    END IF;

    v_response:=jsonb_build_object(
      'success',true,'duplicate',false,'command',v_command,
      'plan_id',v_plan.id,'plan_code',v_plan.plan_code,'runsheet_code',v_runsheet.runsheet_code,
      'stop_count',v_total_stops
    );

  ELSIF v_command='ROUTE_OPTIMIZE' THEN
    SELECT * INTO v_plan
    FROM public.delivery_route_plans
    WHERE id=nullif(p_payload->>'plan_id','')::uuid
      AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'خطة الرحلة غير موجودة'; END IF;
    IF v_plan.status='Cancelled' THEN RAISE EXCEPTION 'خطة الرحلة ملغاة'; END IF;

    IF v_plan.start_latitude IS NULL OR v_plan.start_longitude IS NULL
       OR v_plan.planned_start_at IS NULL OR v_plan.planned_speed_kmh IS NULL OR v_plan.planned_speed_kmh<=0 THEN
      v_response:=jsonb_build_object(
        'success',true,'status','INCOMPLETE_DATA','code','ROUTE_PLAN_INPUT_INCOMPLETE',
        'msg','نقطة البداية ووقت البداية والسرعة المخططة مطلوبة قبل تحسين المسار'
      );
    ELSE
      SELECT count(*) INTO v_missing
      FROM public.delivery_route_stops s
      JOIN public.orders o ON o.id=s.order_id AND o.company_id=p_company_id
      WHERE s.route_plan_id=v_plan.id
        AND (o.latitude IS NULL OR o.longitude IS NULL);
      IF v_missing>0 THEN
        v_response:=jsonb_build_object(
          'success',true,'status','INCOMPLETE_DATA','code','ORDER_GEO_INCOMPLETE',
          'missing_geo_orders',v_missing,
          'msg','بعض أوردرات الرحلة لا تحتوي إحداثيات توصيل مثبتة'
        );
      ELSE
        CREATE TEMP TABLE IF NOT EXISTS _delivery_opt_stops(
          id uuid PRIMARY KEY, lat numeric, lon numeric, used boolean NOT NULL DEFAULT false
        ) ON COMMIT DROP;
        DELETE FROM _delivery_opt_stops;
        INSERT INTO _delivery_opt_stops(id,lat,lon)
        SELECT s.id,o.latitude,o.longitude
        FROM public.delivery_route_stops s
        JOIN public.orders o ON o.id=s.order_id AND o.company_id=p_company_id
        WHERE s.route_plan_id=v_plan.id;

        SELECT count(*) INTO v_total_stops FROM _delivery_opt_stops;
        IF v_total_stops=0 THEN
          v_response:=jsonb_build_object('success',true,'status','BLOCKED','code','NO_STOPS','msg','لا توجد نقاط توصيل');
        ELSE
          v_seq:=0;
          v_prev_lat:=v_plan.start_latitude;
          v_prev_lon:=v_plan.start_longitude;
          v_elapsed:=v_plan.planned_start_at;
          v_speed:=v_plan.planned_speed_kmh;
          v_service_minutes:=v_plan.default_service_minutes;
          v_total_km:=0;

          WHILE EXISTS(SELECT 1 FROM _delivery_opt_stops WHERE used=false) LOOP
            SELECT x.id,x.lat,x.lon,x.dist_km
            INTO v_next_id,v_next_lat,v_next_lon,v_dist
            FROM (
              SELECT t.id,t.lat,t.lon,
                6371.0088*2*asin(
                  sqrt(
                    power(sin(radians(t.lat-v_prev_lat)/2),2)
                    + cos(radians(v_prev_lat))*cos(radians(t.lat))*power(sin(radians(t.lon-v_prev_lon)/2),2)
                  )
                ) AS dist_km
              FROM _delivery_opt_stops t
              WHERE t.used=false
            ) x
            ORDER BY x.dist_km,x.id
            LIMIT 1;

            v_seq:=v_seq+1;
            v_total_km:=v_total_km+coalesce(v_dist,0);
            v_elapsed:=v_elapsed + (coalesce(v_dist,0)/v_speed*interval '1 hour');
            UPDATE public.delivery_route_stops
            SET stop_sequence=v_seq,
                planned_distance_km=round(coalesce(v_dist,0),3),
                planned_arrival_at=v_elapsed,
                planned_service_minutes=v_service_minutes,
                updated_at=now()
            WHERE id=v_next_id AND company_id=p_company_id AND route_plan_id=v_plan.id;

            UPDATE _delivery_opt_stops SET used=true WHERE id=v_next_id;
            v_elapsed:=v_elapsed + make_interval(mins=>v_service_minutes);
            v_prev_lat:=v_next_lat;
            v_prev_lon:=v_next_lon;
          END LOOP;

          IF v_plan.end_latitude IS NOT NULL AND v_plan.end_longitude IS NOT NULL THEN
            v_dist := 6371.0088*2*asin(
              sqrt(
                power(sin(radians(v_plan.end_latitude-v_prev_lat)/2),2)
                + cos(radians(v_prev_lat))*cos(radians(v_plan.end_latitude))*power(sin(radians(v_plan.end_longitude-v_prev_lon)/2),2)
              )
            );
            v_total_km:=v_total_km+coalesce(v_dist,0);
          END IF;

          UPDATE public.delivery_route_plans
          SET optimization_strategy='GeographicNearest',
              optimization_status='OPTIMIZED',
              status=case when status='Draft' then 'Planned' else status end,
              planned_total_km=round(v_total_km,3),
              planned_duration_minutes=round(extract(epoch from (v_elapsed-v_plan.planned_start_at))/60.0,2),
              updated_by=v_actor.email,updated_at=now()
          WHERE id=v_plan.id AND company_id=p_company_id;

          v_response:=jsonb_build_object(
            'success',true,'status','OPTIMIZED','plan_id',v_plan.id,'plan_code',v_plan.plan_code,
            'stop_count',v_total_stops,'planned_total_km',round(v_total_km,3),
            'planned_duration_minutes',round(extract(epoch from (v_elapsed-v_plan.planned_start_at))/60.0,2)
          );
        END IF;
      END IF;
    END IF;

  ELSIF v_command='ROUTE_AGENT_ASSIGN' THEN
    SELECT * INTO v_plan FROM public.delivery_route_plans
    WHERE id=nullif(p_payload->>'plan_id','')::uuid AND company_id=p_company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'خطة الرحلة غير موجودة'; END IF;
    SELECT * INTO v_agent FROM public.delivery_agents
    WHERE id=nullif(p_payload->>'delivery_agent_id','')::uuid AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'مندوب التوصيل غير موجود'; END IF;
    IF v_agent.status<>'Active' THEN RAISE EXCEPTION 'مندوب التوصيل غير نشط'; END IF;
    UPDATE public.delivery_route_plans
    SET delivery_agent_id=v_agent.id,
        updated_by=v_actor.email,updated_at=now(),
        status=case when status='Draft' then 'Planned' else status end
    WHERE id=v_plan.id AND company_id=p_company_id;
    v_response:=jsonb_build_object('success',true,'plan_id',v_plan.id,'plan_code',v_plan.plan_code,'delivery_agent_id',v_agent.id);

  ELSIF v_command='STOP_ARRIVE' THEN
    SELECT * INTO v_stop FROM public.delivery_route_stops
    WHERE id=nullif(p_payload->>'stop_id','')::uuid AND company_id=p_company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'نقطة التوصيل غير موجودة'; END IF;
    v_actual_at:=coalesce(nullif(p_payload->>'actual_at','')::timestamptz,now());
    UPDATE public.delivery_route_stops
    SET actual_arrival_at=v_actual_at,
        status=case when status in ('Delivered','Partial','Refused','Returned') then status else 'Arrived' end,
        updated_at=now()
    WHERE id=v_stop.id AND company_id=p_company_id;
    UPDATE public.delivery_route_plans
    SET status=case when status='Planned' then 'InProgress' else status end,
        actual_start_at=coalesce(actual_start_at,v_actual_at),
        updated_by=v_actor.email,updated_at=now()
    WHERE id=v_stop.route_plan_id AND company_id=p_company_id;
    v_response:=jsonb_build_object('success',true,'stop_id',v_stop.id,'actual_arrival_at',v_actual_at);

  ELSIF v_command='STOP_POD' THEN
    SELECT * INTO v_stop FROM public.delivery_route_stops
    WHERE id=nullif(p_payload->>'stop_id','')::uuid AND company_id=p_company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'نقطة التوصيل غير موجودة'; END IF;
    IF nullif(btrim(p_payload->>'pod_method'),'') IS NULL THEN RAISE EXCEPTION 'طريقة إثبات التسليم مطلوبة'; END IF;
    IF p_payload->>'pod_method' NOT IN ('OTP','Signature','Photo','Reference','None') THEN RAISE EXCEPTION 'طريقة إثبات التسليم غير مدعومة'; END IF;
    v_status:=coalesce(nullif(p_payload->>'delivery_result',''),'Delivered');
    IF v_status NOT IN ('Delivered','Partial','Refused','Returned') THEN RAISE EXCEPTION 'نتيجة التسليم غير مدعومة'; END IF;
    v_actual_at:=coalesce(nullif(p_payload->>'captured_at','')::timestamptz,now());
    UPDATE public.delivery_route_stops
    SET recipient_name=case when p_payload ? 'recipient_name' then nullif(btrim(p_payload->>'recipient_name'),'') else recipient_name end,
        pod_method=p_payload->>'pod_method',
        pod_reference=case when p_payload ? 'pod_reference' then nullif(btrim(p_payload->>'pod_reference'),'') else pod_reference end,
        pod_note=case when p_payload ? 'pod_note' then p_payload->>'pod_note' else pod_note end,
        actual_latitude=case when p_payload ? 'latitude' then nullif(p_payload->>'latitude','')::numeric else actual_latitude end,
        actual_longitude=case when p_payload ? 'longitude' then nullif(p_payload->>'longitude','')::numeric else actual_longitude end,
        actual_arrival_at=coalesce(actual_arrival_at,v_actual_at),
        delivery_completed_at=v_actual_at,
        status=v_status,
        updated_at=now()
    WHERE id=v_stop.id AND company_id=p_company_id;
    UPDATE public.delivery_route_plans
    SET status='InProgress',
        actual_start_at=coalesce(actual_start_at,v_actual_at),
        updated_by=v_actor.email,updated_at=now()
    WHERE id=v_stop.route_plan_id AND company_id=p_company_id AND status<>'Completed';
    v_response:=jsonb_build_object('success',true,'stop_id',v_stop.id,'status',v_status,'captured_at',v_actual_at);

  ELSIF v_command='ROUTE_STATUS' THEN
    SELECT * INTO v_plan FROM public.delivery_route_plans
    WHERE id=nullif(p_payload->>'plan_id','')::uuid AND company_id=p_company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'خطة الرحلة غير موجودة'; END IF;
    v_status:=coalesce(nullif(p_payload->>'status',''),v_plan.status);
    IF v_status NOT IN ('Draft','Planned','InProgress','Completed','Cancelled') THEN RAISE EXCEPTION 'حالة الخطة غير مدعومة'; END IF;
    UPDATE public.delivery_route_plans
    SET status=v_status,
        actual_end_at=case when v_status='Completed' then coalesce(actual_end_at,now()) else actual_end_at end,
        updated_by=v_actor.email,updated_at=now()
    WHERE id=v_plan.id AND company_id=p_company_id;
    v_response:=jsonb_build_object('success',true,'plan_id',v_plan.id,'status',v_status);

  ELSIF v_command='COLLECTION_RECORD' THEN
    SELECT * INTO v_stop FROM public.delivery_route_stops
    WHERE id=nullif(p_payload->>'stop_id','')::uuid AND company_id=p_company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'نقطة التوصيل غير موجودة'; END IF;
    SELECT * INTO v_plan FROM public.delivery_route_plans
    WHERE id=v_stop.route_plan_id AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND OR v_plan.delivery_agent_id IS NULL THEN RAISE EXCEPTION 'لا يوجد مندوب توصيل مرتبط بالرحلة'; END IF;
    SELECT * INTO v_order FROM public.orders
    WHERE id=v_stop.order_id AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الأوردر غير موجود'; END IF;

    SELECT coalesce(sum(r.amount),0) INTO v_existing
    FROM public.delivery_collection_receipts r
    WHERE r.company_id=p_company_id AND r.order_id=v_order.id AND r.status<>'Voided';

    v_allowed:=greatest(0,coalesce(v_order.total_amount,0)-coalesce(v_order.amount_paid,0)-v_existing);
    IF coalesce((p_payload->>'amount')::numeric,0)<=0 THEN RAISE EXCEPTION 'قيمة التحصيل يجب أن تكون أكبر من صفر'; END IF;
    IF (p_payload->>'amount')::numeric > v_allowed THEN
      RAISE EXCEPTION 'قيمة التحصيل تتجاوز المتبقي على الأوردر: %',round(v_allowed,2);
    END IF;

    v_receipt_code:='COL-'||substr(replace(gen_random_uuid()::text,'-',''),1,12);
    INSERT INTO public.delivery_collection_receipts(
      company_id,receipt_code,route_plan_id,route_stop_id,order_id,delivery_agent_id,
      collected_at,amount,payment_method,reference,status,notes,created_by,updated_at,operation_id
    )
    VALUES(
      p_company_id,v_receipt_code,v_plan.id,v_stop.id,v_order.id,v_plan.delivery_agent_id,
      coalesce(nullif(p_payload->>'collected_at','')::timestamptz,now()),
      (p_payload->>'amount')::numeric,
      coalesce(nullif(btrim(p_payload->>'payment_method'),''),'Cash'),
      nullif(btrim(p_payload->>'reference'),''),
      'Collected',
      nullif(p_payload->>'notes',''),
      v_actor.email,now(),p_operation_id
    )
    RETURNING * INTO v_receipt;
    v_response:=jsonb_build_object('success',true,'receipt',to_jsonb(v_receipt),'remaining_after',round(v_allowed-v_receipt.amount,2));

  ELSIF v_command='COLLECTION_VOID' THEN
    SELECT * INTO v_receipt
    FROM public.delivery_collection_receipts
    WHERE id=nullif(p_payload->>'receipt_id','')::uuid AND company_id=p_company_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'سند التحصيل غير موجود'; END IF;
    IF v_receipt.status='Voided' THEN
      v_response:=jsonb_build_object('success',true,'duplicate',true,'receipt_id',v_receipt.id,'status','Voided');
    ELSE
      UPDATE public.delivery_collection_receipts
      SET status='Voided',updated_at=now()
      WHERE id=v_receipt.id AND company_id=p_company_id;
      v_response:=jsonb_build_object('success',true,'receipt_id',v_receipt.id,'status','Voided');
    END IF;

  ELSE
    RAISE EXCEPTION 'أمر Delivery غير مدعوم: %',v_command;
  END IF;

  UPDATE public.erp_operation_registry
  SET status='completed',response_payload=v_response,completed_at=now()
  WHERE company_id=p_company_id AND operation_type='DELIVERY' AND operation_key=v_operation_key;

  RETURN v_response;
EXCEPTION WHEN OTHERS THEN
  UPDATE public.erp_operation_registry
  SET status='failed',response_payload=jsonb_build_object('success',false,'error',SQLERRM),completed_at=now()
  WHERE company_id=p_company_id AND operation_type='DELIVERY' AND operation_key=v_operation_key;
  RAISE;
END;
$function$

