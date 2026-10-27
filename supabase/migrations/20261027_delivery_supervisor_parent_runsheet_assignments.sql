-- 2026-10-27: expose runsheet.deliverer_id assignments in the existing parent ERP delivery representatives view.
-- Root cause: the parent agents view previously returned delivery_agents rows and route-plan counts only;
-- supervisor assignments are persisted independently on runsheets.deliverer_id -> users.id.
-- This is an additive JSON response field; existing 'rows' shape and schema objects remain unchanged.

CREATE OR REPLACE FUNCTION public.delivery_logistics_query(p_company_id uuid, p_view text, p_payload jsonb DEFAULT '{}'::jsonb, p_actor_user_id uuid DEFAULT NULL::uuid, p_actor_email text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_view text := lower(btrim(coalesce(p_view,'')));
  v_from date := coalesce(nullif(p_payload->>'from_date','')::date,current_date-30);
  v_to date := coalesce(nullif(p_payload->>'to_date','')::date,current_date);
  v_response jsonb;
  v_limit integer := greatest(1,least(coalesce((p_payload->>'limit')::integer,100),500));
  v_offset integer := greatest(0,coalesce((p_payload->>'offset')::integer,0));
BEGIN
  IF p_company_id IS NULL THEN RAISE EXCEPTION 'سياق الشركة مطلوب'; END IF;
  IF auth.uid() IS NOT NULL THEN
    SELECT * INTO v_actor
    FROM public.users u
    WHERE u.auth_id=auth.uid() AND u.company_id=p_company_id AND coalesce(u.status,'Active')='Active'
    LIMIT 1;
  ELSE
    SELECT * INTO v_actor
    FROM public.users u
    WHERE u.id=p_actor_user_id AND u.company_id=p_company_id AND coalesce(u.status,'Active')='Active'
    LIMIT 1;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'هوية المستخدم أو سياق الشركة غير صالح'; END IF;
  IF p_actor_email IS NOT NULL AND lower(p_actor_email)<>lower(v_actor.email) THEN RAISE EXCEPTION 'بريد المنفذ لا يطابق هوية المستخدم'; END IF;
  IF NOT (
    coalesce(v_actor.permissions,'[]'::jsonb) @> '["*"]'::jsonb
    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["delivery_supervisor"]'::jsonb
    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["fleet.read"]'::jsonb
    OR coalesce(v_actor.permissions,'[]'::jsonb) @> '["fleet.manage"]'::jsonb
    OR v_actor.role IN ('مدير عام','مدير مخازن','مدير مالي')
  ) THEN
    RAISE EXCEPTION 'غير مصرح بقراءة مركز التوصيل واللوجستيات';
  END IF;

  IF v_view='dashboard' THEN
    SELECT jsonb_build_object(
      'success',true,
      'plans_today',(SELECT count(*) FROM public.delivery_route_plans p WHERE p.company_id=p_company_id AND p.created_at::date=current_date AND p.status<>'Cancelled'),
      'active_plans',(SELECT count(*) FROM public.delivery_route_plans p WHERE p.company_id=p_company_id AND p.status IN ('Planned','InProgress')),
      'unassigned_plans',(SELECT count(*) FROM public.delivery_route_plans p WHERE p.company_id=p_company_id AND p.status IN ('Draft','Planned') AND p.delivery_agent_id IS NULL),
      'pending_stops',(SELECT count(*) FROM public.delivery_route_stops s WHERE s.company_id=p_company_id AND s.status IN ('Planned','EnRoute','Arrived')),
      'on_time_pct',(
        SELECT case when count(*)=0 then null
          else round(100.0*count(*) FILTER (WHERE s.actual_arrival_at<=s.planned_arrival_at)/count(*),2) end
        FROM public.delivery_route_stops s
        JOIN public.delivery_route_plans p ON p.id=s.route_plan_id AND p.company_id=p_company_id
        WHERE s.company_id=p_company_id AND s.planned_arrival_at IS NOT NULL AND s.actual_arrival_at IS NOT NULL
      ),
      'recorded_collections',(SELECT coalesce(sum(r.amount),0) FROM public.delivery_collection_receipts r WHERE r.company_id=p_company_id AND r.status<>'Voided'),
      'outstanding_order_value',(
        SELECT coalesce(sum(greatest(0,coalesce(o.total_amount,0)-coalesce(o.amount_paid,0))),0)
        FROM public.orders o
        WHERE o.company_id=p_company_id AND o.runsheet_id IS NOT NULL
          AND o.order_status NOT IN ('Cancelled')
      )
    ) INTO v_response;

  ELSIF v_view='routes' THEN
    SELECT jsonb_build_object(
      'success',true,
      'rows',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]'::jsonb)
        FROM (
          SELECT p.id,p.plan_code,p.status,p.optimization_strategy,p.optimization_status,
                 p.planned_start_at,p.planned_end_at,p.actual_start_at,p.actual_end_at,
                 p.planned_total_km,p.actual_total_km,p.planned_duration_minutes,p.actual_duration_minutes,
                 r.runsheet_code,r.run_date,r.status AS runsheet_status,
                 r.vehicle_id,r.driver_id,v.vehicle_code,v.license_plate,
                 a.id AS delivery_agent_id,a.agent_code,a.full_name AS delivery_agent_name,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.route_plan_id=p.id) AS stop_count,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.route_plan_id=p.id AND s.status='Delivered') AS delivered_stops,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.route_plan_id=p.id AND s.status='Partial') AS partial_stops,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.route_plan_id=p.id AND s.status='Refused') AS refused_stops,
                 (SELECT coalesce(sum(cr.amount),0) FROM public.delivery_collection_receipts cr WHERE cr.route_plan_id=p.id AND cr.status<>'Voided') AS collected_amount,
                 (SELECT coalesce(sum(greatest(0,coalesce(o.total_amount,0)-coalesce(o.amount_paid,0))),0)
                    FROM public.delivery_route_stops s
                    JOIN public.orders o ON o.id=s.order_id AND o.company_id=p_company_id
                    WHERE s.route_plan_id=p.id) AS outstanding_amount,
                 p.created_at
          FROM public.delivery_route_plans p
          JOIN public.runsheets r ON r.id=p.runsheet_id AND r.company_id=p_company_id
          LEFT JOIN public.vehicles v ON v.id=r.vehicle_id AND v.company_id=p_company_id
          LEFT JOIN public.delivery_agents a ON a.id=p.delivery_agent_id AND a.company_id=p_company_id
          WHERE p.company_id=p_company_id
            AND p.created_at::date BETWEEN v_from AND v_to
            AND (nullif(btrim(p_payload->>'status'),'') IS NULL OR p.status=p_payload->>'status')
          LIMIT v_limit OFFSET v_offset
        ) x
      )
    ) INTO v_response;

  ELSIF v_view='route_detail' THEN
    SELECT jsonb_build_object(
      'success',true,
      'plan',(
        SELECT to_jsonb(p) || jsonb_build_object(
          'runsheet_code',r.runsheet_code,
          'runsheet_status',r.status,
          'vehicle_code',v.vehicle_code,
          'license_plate',v.license_plate,
          'driver_user_id',r.driver_id,
          'delivery_agent_name',a.full_name,
          'delivery_agent_code',a.agent_code
        )
        FROM public.delivery_route_plans p
        JOIN public.runsheets r ON r.id=p.runsheet_id AND r.company_id=p_company_id
        LEFT JOIN public.vehicles v ON v.id=r.vehicle_id AND v.company_id=p_company_id
        LEFT JOIN public.delivery_agents a ON a.id=p.delivery_agent_id AND a.company_id=p_company_id
        WHERE p.id=nullif(p_payload->>'plan_id','')::uuid AND p.company_id=p_company_id
      ),
      'stops',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.stop_sequence),'[]'::jsonb)
        FROM (
          SELECT s.id,s.stop_sequence,s.status,s.planned_distance_km,s.planned_arrival_at,s.actual_arrival_at,
                 s.delivery_completed_at,s.recipient_name,s.pod_method,s.pod_reference,s.pod_note,
                 s.actual_latitude,s.actual_longitude,
                 o.order_code,o.customer_name,o.customer_phone,o.shipping_address,o.latitude,o.longitude,
                 o.total_amount,o.amount_paid,o.payment_type,o.order_status,
                 coalesce(sum(od.qty),0) AS ordered_qty,
                 coalesce(sum(od.qty_loaded),0) AS loaded_qty,
                 coalesce(sum(od.qty_delivered),0) AS delivered_qty,
                 coalesce(sum(od.qty_refused),0) AS refused_qty,
                 coalesce(sum(od.qty_returned),0) AS returned_qty,
                 coalesce((SELECT sum(cr.amount) FROM public.delivery_collection_receipts cr WHERE cr.route_stop_id=s.id AND cr.status<>'Voided'),0) AS collected_amount,
                 case when s.planned_arrival_at is not null and s.actual_arrival_at is not null
                      then (s.actual_arrival_at<=s.planned_arrival_at) end AS on_time
          FROM public.delivery_route_stops s
          JOIN public.orders o ON o.id=s.order_id AND o.company_id=p_company_id
          LEFT JOIN public.order_details od ON od.order_id=o.id
          WHERE s.company_id=p_company_id
            AND s.route_plan_id=nullif(p_payload->>'plan_id','')::uuid
          GROUP BY s.id,o.id
        ) x
      )
    ) INTO v_response;

  ELSIF v_view='planning' THEN
    SELECT jsonb_build_object(
      'success',true,
      'rows',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.run_date DESC,x.runsheet_code DESC),'[]'::jsonb)
        FROM (
          SELECT r.id,r.runsheet_code,r.run_date,r.status,r.vehicle_id,r.driver_id,
                 v.vehicle_code,v.license_plate,v.max_weight_kg,v.max_volume_m3,
                 count(distinct o.id) AS order_count,
                 coalesce(sum(rsd.qty_ordered),0) AS ordered_qty,
                 coalesce(sum(rsd.qty_loaded),0) AS loaded_qty,
                 coalesce(sum(rsd.qty_delivered),0) AS delivered_qty,
                 exists(SELECT 1 FROM public.delivery_route_plans p WHERE p.company_id=p_company_id AND p.runsheet_id=r.id AND p.status<>'Cancelled') AS has_route_plan
          FROM public.runsheets r
          LEFT JOIN public.vehicles v ON v.id=r.vehicle_id AND v.company_id=p_company_id
          LEFT JOIN public.orders o ON o.company_id=p_company_id AND o.runsheet_id=r.id
          LEFT JOIN public.run_sheet_details rsd ON rsd.runsheet_id=r.id
          WHERE r.company_id=p_company_id
            AND r.run_date BETWEEN v_from AND v_to
            AND r.status NOT IN ('Cancelled','Completed')
          GROUP BY r.id,v.id
          LIMIT v_limit OFFSET v_offset
        ) x
      )
    ) INTO v_response;

  ELSIF v_view='agents' THEN
    SELECT jsonb_build_object(
      'success',true,
      'rows',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.full_name),'[]'::jsonb)
        FROM (
          SELECT a.id,a.agent_code,a.full_name,a.phone,a.email,a.employment_type,a.status,a.user_id,
                 (SELECT count(*) FROM public.delivery_route_plans p WHERE p.delivery_agent_id=a.id AND p.company_id=p_company_id AND p.status IN ('Planned','InProgress')) AS active_routes,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.company_id=p_company_id AND s.route_plan_id IN (SELECT p.id FROM public.delivery_route_plans p WHERE p.delivery_agent_id=a.id AND p.company_id=p_company_id)) AS stops_total,
                 (SELECT count(*) FROM public.delivery_route_stops s WHERE s.company_id=p_company_id AND s.status='Delivered' AND s.route_plan_id IN (SELECT p.id FROM public.delivery_route_plans p WHERE p.delivery_agent_id=a.id AND p.company_id=p_company_id)) AS stops_delivered,
                 (SELECT coalesce(sum(r.amount),0) FROM public.delivery_collection_receipts r WHERE r.company_id=p_company_id AND r.delivery_agent_id=a.id AND r.status<>'Voided') AS collected_amount
          FROM public.delivery_agents a
          WHERE a.company_id=p_company_id
            AND (nullif(btrim(p_payload->>'status'),'') IS NULL OR a.status=p_payload->>'status')
            AND (nullif(btrim(p_payload->>'search'),'') IS NULL OR a.full_name ILIKE '%'||btrim(p_payload->>'search')||'%' OR a.agent_code ILIKE '%'||btrim(p_payload->>'search')||'%')
          LIMIT v_limit OFFSET v_offset
        ) x
      ),
      'runsheet_assignments',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.run_date DESC,x.runsheet_code DESC),'[]'::jsonb)
        FROM (
          SELECT r.id AS runsheet_id,
                 r.runsheet_code,
                 r.run_date,
                 r.status,
                 r.deliverer_id AS deliverer_user_id,
                 u.name AS deliverer_name,
                 r.driver_id,
                 r.vehicle_id,
                 (
                   SELECT a.agent_code
                   FROM public.delivery_agents a
                   WHERE a.company_id=p_company_id
                     AND a.user_id=r.deliverer_id
                   ORDER BY a.created_at DESC,a.id
                   LIMIT 1
                 ) AS delivery_agent_code
          FROM public.runsheets r
          JOIN public.users u
            ON u.id=r.deliverer_id
           AND u.company_id=r.company_id
          WHERE r.company_id=p_company_id
            AND r.deliverer_id IS NOT NULL
            AND r.status IN ('Loaded','Delivering','Delivered','Returning')
          ORDER BY r.run_date DESC,r.runsheet_code DESC
          LIMIT 200
        ) x
      )
    ) INTO v_response;

  ELSIF v_view='collections' THEN
    SELECT jsonb_build_object(
      'success',true,
      'rows',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.collected_at DESC),'[]'::jsonb)
        FROM (
          SELECT c.id,c.receipt_code,c.collected_at,c.amount,c.payment_method,c.reference,c.status,c.notes,
                 p.plan_code,s.stop_sequence,o.order_code,o.customer_name,
                 a.agent_code,a.full_name AS delivery_agent_name
          FROM public.delivery_collection_receipts c
          JOIN public.delivery_route_plans p ON p.id=c.route_plan_id AND p.company_id=p_company_id
          JOIN public.delivery_route_stops s ON s.id=c.route_stop_id AND s.company_id=p_company_id
          JOIN public.orders o ON o.id=c.order_id AND o.company_id=p_company_id
          JOIN public.delivery_agents a ON a.id=c.delivery_agent_id AND a.company_id=p_company_id
          WHERE c.company_id=p_company_id
            AND c.collected_at::date BETWEEN v_from AND v_to
          LIMIT v_limit OFFSET v_offset
        ) x
      )
    ) INTO v_response;

  ELSIF v_view='performance' THEN
    SELECT jsonb_build_object(
      'success',true,
      'rows',(
        SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.delivered_stops DESC,x.agent_code),'[]'::jsonb)
        FROM (
          SELECT a.id AS delivery_agent_id,a.agent_code,a.full_name,
                 count(distinct s.id) AS assigned_stops,
                 count(distinct s.id) FILTER (WHERE s.status='Delivered') AS delivered_stops,
                 count(distinct s.id) FILTER (WHERE s.status='Partial') AS partial_stops,
                 count(distinct s.id) FILTER (WHERE s.status='Refused') AS refused_stops,
                 count(distinct s.id) FILTER (WHERE s.status='Returned') AS returned_stops,
                 case when count(*) FILTER (WHERE s.planned_arrival_at IS NOT NULL AND s.actual_arrival_at IS NOT NULL)=0 then null
                      else round(100.0*count(*) FILTER (WHERE s.planned_arrival_at IS NOT NULL AND s.actual_arrival_at IS NOT NULL AND s.actual_arrival_at<=s.planned_arrival_at)
                           /count(*) FILTER (WHERE s.planned_arrival_at IS NOT NULL AND s.actual_arrival_at IS NOT NULL),2) end AS on_time_pct,
                 coalesce(sum(o.total_amount),0) AS order_value,
                 coalesce(sum(cr.collected),0) AS collected_amount,
                 perf.total_distance_km,
                 perf.total_delivery_minutes,
                 case when perf.total_delivery_minutes>0 then round(perf.total_distance_km/(perf.total_delivery_minutes/60.0),2) end AS delivery_speed_kmh,
                 case when count(distinct s.id)>0 and perf.total_delivery_minutes>0
                      then round(perf.total_delivery_minutes/count(distinct s.id),2) end AS avg_minutes_per_stop
          FROM public.delivery_agents a
          LEFT JOIN public.delivery_route_plans p ON p.delivery_agent_id=a.id AND p.company_id=p_company_id
          LEFT JOIN public.delivery_route_stops s ON s.route_plan_id=p.id AND s.company_id=p_company_id
          LEFT JOIN public.orders o ON o.id=s.order_id AND o.company_id=p_company_id
          LEFT JOIN LATERAL (
            SELECT coalesce(sum(c.amount),0) AS collected
            FROM public.delivery_collection_receipts c
            WHERE c.company_id=p_company_id AND c.route_stop_id=s.id AND c.status<>'Voided'
          ) cr ON true
          LEFT JOIN LATERAL (
            SELECT
              coalesce(sum(case
                when r2.meter_start is not null and r2.meter_end is not null and r2.meter_end>=r2.meter_start
                  then r2.meter_end-r2.meter_start
                else coalesce(p2.actual_total_km,0)
              end),0) AS total_distance_km,
              coalesce(sum(case
                when r2.delivery_start is not null and r2.delivery_end is not null and r2.delivery_end>=r2.delivery_start
                  then extract(epoch from (r2.delivery_end-r2.delivery_start))/60.0
                else coalesce(p2.actual_duration_minutes,0)
              end),0) AS total_delivery_minutes
            FROM public.delivery_route_plans p2
            JOIN public.runsheets r2 ON r2.id=p2.runsheet_id AND r2.company_id=p_company_id
            WHERE p2.company_id=p_company_id
              AND p2.delivery_agent_id=a.id
              AND p2.status<>'Cancelled'
              AND p2.created_at::date BETWEEN v_from AND v_to
          ) perf ON true
          WHERE a.company_id=p_company_id
            AND (s.id IS NULL OR s.created_at::date BETWEEN v_from AND v_to)
          GROUP BY a.id,perf.total_distance_km,perf.total_delivery_minutes
        ) x
      )
    ) INTO v_response;

  ELSE
    RAISE EXCEPTION 'Delivery Logistics view غير مدعومة: %',v_view;
  END IF;

  RETURN coalesce(v_response,jsonb_build_object('success',true));
END;
$function$;
