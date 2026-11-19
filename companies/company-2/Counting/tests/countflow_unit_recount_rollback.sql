-- Unit conversion + approved recount regression test. Run as postgres in SQL Editor.
-- All Auth/CountFlow fixtures are rolled back.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('b4c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-unit-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('b4c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-unit-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','b4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"b4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO public.count_projects(id,name,code,created_by,status)
VALUES('b4c6e6a1-8c22-4df0-9a01-333333333333','UNIT TEST','CF-UNIT-TEST','b4c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO public.count_members(id,project_id,user_id,display_name,username,role,status)
VALUES('b4c6e6a1-8c22-4df0-9a01-444444444444','b4c6e6a1-8c22-4df0-9a01-333333333333',
'b4c6e6a1-8c22-4df0-9a01-222222222222','Counter','counter','counter','active');
INSERT INTO public.count_locations(id,project_id,location_type,code,name)
VALUES('b4c6e6a1-8c22-4df0-9a01-555555555555','b4c6e6a1-8c22-4df0-9a01-333333333333','shelf','U-A','Unit Shelf');
INSERT INTO public.count_sessions(id,project_id,name,status,created_by)
VALUES('b4c6e6a1-8c22-4df0-9a01-777777777777','b4c6e6a1-8c22-4df0-9a01-333333333333','Unit Session','active','b4c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO public.count_assignments(session_id,member_id,location_id,status)
VALUES('b4c6e6a1-8c22-4df0-9a01-777777777777','b4c6e6a1-8c22-4df0-9a01-444444444444','b4c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO public.count_products(id,project_id,sku,name,base_unit,units)
VALUES('b4c6e6a1-8c22-4df0-9a01-888888888888','b4c6e6a1-8c22-4df0-9a01-333333333333',
'CF-UNIT-001','Unit Test Product','each','[{"name":"case","factor_to_base":12},{"name":"pack"}]');
INSERT INTO public.count_expected_balances(project_id,session_id,product_id,location_id,expected_quantity,unit)
VALUES('b4c6e6a1-8c22-4df0-9a01-333333333333','b4c6e6a1-8c22-4df0-9a01-777777777777',
'b4c6e6a1-8c22-4df0-9a01-888888888888','b4c6e6a1-8c22-4df0-9a01-555555555555',30,'each');

SELECT set_config('request.jwt.claim.sub','b4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"b4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT public.count_touch_presence('b4c6e6a1-8c22-4df0-9a01-777777777777','unit-device','test','desktop','test','online','b4c6e6a1-8c22-4df0-9a01-555555555555');
SELECT public.count_record_entry('b4c6e6a1-8c22-4df0-9a01-777777777777','b4c6e6a1-8c22-4df0-9a01-888888888888',
'b4c6e6a1-8c22-4df0-9a01-555555555555',2,'case','b4c6e6a1-8c22-4df0-9a01-999999999991','barcode','unit-device','two cases');
SELECT public.count_record_entry('b4c6e6a1-8c22-4df0-9a01-777777777777','b4c6e6a1-8c22-4df0-9a01-888888888888',
'b4c6e6a1-8c22-4df0-9a01-555555555555',3,'each','b4c6e6a1-8c22-4df0-9a01-999999999992','barcode','unit-device','three each');
DO $$ BEGIN
  BEGIN
    PERFORM public.count_record_entry('b4c6e6a1-8c22-4df0-9a01-777777777777','b4c6e6a1-8c22-4df0-9a01-888888888888',
      'b4c6e6a1-8c22-4df0-9a01-555555555555',1,'pack','b4c6e6a1-8c22-4df0-9a01-999999999993','barcode','unit-device','missing factor');
    RAISE EXCEPTION 'ASSERT_MISSING_UNIT_FACTOR_NOT_REJECTED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'UNIT_CONVERSION_REQUIRED:%' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','b4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"b4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
DO $$ BEGIN
  BEGIN
    UPDATE public.count_products SET units='[{"name":"case","factor_to_base":10}]'
    WHERE id='b4c6e6a1-8c22-4df0-9a01-888888888888';
    RAISE EXCEPTION 'ASSERT_ACTIVE_SESSION_UNIT_CHANGE_NOT_BLOCKED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'PRODUCT_UNITS_LOCKED_DURING_ACTIVE_COUNT' THEN RAISE; END IF;
  END;
END $$;

SELECT public.count_reconcile_session('b4c6e6a1-8c22-4df0-9a01-777777777777');
DO $$ DECLARE v_qty numeric;
BEGIN
  SELECT counted_qty INTO v_qty FROM counting_private.session_effective_counts('b4c6e6a1-8c22-4df0-9a01-777777777777');
  IF v_qty<>27 THEN RAISE EXCEPTION 'ASSERT_UNIT_NORMALIZATION_FAILED: %',v_qty; END IF;
END $$;
SELECT public.count_generate_recount_tasks(
 (SELECT id FROM public.count_reconciliation_runs WHERE session_id='b4c6e6a1-8c22-4df0-9a01-777777777777' ORDER BY run_number DESC LIMIT 1),
 'b4c6e6a1-8c22-4df0-9a01-444444444444',0);

SELECT set_config('request.jwt.claim.sub','b4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"b4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT public.count_record_recount_entry(
 (SELECT id FROM public.count_recount_tasks WHERE session_id='b4c6e6a1-8c22-4df0-9a01-777777777777' LIMIT 1),
 2,'case','b4c6e6a1-8c22-4df0-9a01-aaaaaaaaaaaa','barcode','unit-device','recount two cases');
SELECT set_config('request.jwt.claim.sub','b4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"b4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT public.count_review_recount_task(
 (SELECT id FROM public.count_recount_tasks WHERE session_id='b4c6e6a1-8c22-4df0-9a01-777777777777' LIMIT 1),'accept','approved');
SELECT public.count_reconcile_session('b4c6e6a1-8c22-4df0-9a01-777777777777');

DO $$
DECLARE v_first numeric; v_second numeric; v_kpis jsonb;
BEGIN
  SELECT counted_quantity INTO v_first FROM public.count_reconciliation_lines
  WHERE run_id=(SELECT id FROM public.count_reconciliation_runs WHERE session_id='b4c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=1);
  SELECT counted_quantity INTO v_second FROM public.count_reconciliation_lines
  WHERE run_id=(SELECT id FROM public.count_reconciliation_runs WHERE session_id='b4c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=2);
  v_kpis:=public.count_session_kpis('b4c6e6a1-8c22-4df0-9a01-777777777777');
  IF v_first<>27 OR v_second<>24 OR (v_kpis->>'quantity_total')::numeric<>24
    OR (v_kpis->'quantity_by_unit'->>'each')::numeric<>24
  THEN RAISE EXCEPTION 'ASSERT_EFFECTIVE_UNIT_RECOUNT_FAILED: first %, second %, KPIs %',v_first,v_second,v_kpis; END IF;
END $$;
SELECT jsonb_build_object('first_round_base_quantity',27,'approved_recount_base_quantity',24,
 'reconciled_quantity_after_recount',24,'kpi_quantity_by_unit',public.count_session_kpis('b4c6e6a1-8c22-4df0-9a01-777777777777')->'quantity_by_unit') AS verified_result;
ROLLBACK;
