-- CountFlow core integration test. Run as postgres in SQL Editor.
-- Every fixture, including Auth users, is inside one transaction and is rolled back.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('f3c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','countflow-rollback-supervisor@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('f3c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','countflow-rollback-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;

INSERT INTO public.count_projects(id,name,code,created_by,status)
VALUES('f3c6e6a1-8c22-4df0-9a01-333333333333','ROLLBACK TEST ONLY','CF-ROLLBACK-TEST','f3c6e6a1-8c22-4df0-9a01-111111111111','active');
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.count_members WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
    AND user_id='f3c6e6a1-8c22-4df0-9a01-111111111111' AND role='supervisor' AND status='active')
  THEN RAISE EXCEPTION 'ASSERT_OWNER_BOOTSTRAP_FAILED'; END IF;
END $$;

INSERT INTO public.count_members(id,project_id,user_id,display_name,username,role,status)
VALUES('f3c6e6a1-8c22-4df0-9a01-444444444444','f3c6e6a1-8c22-4df0-9a01-333333333333',
'f3c6e6a1-8c22-4df0-9a01-222222222222','Counter Test','counter-test','counter','active');
INSERT INTO public.count_locations(id,project_id,location_type,code,name,sort_order)
VALUES
('f3c6e6a1-8c22-4df0-9a01-555555555555','f3c6e6a1-8c22-4df0-9a01-333333333333','shelf','TEST-LOC-A','Test Shelf A',1),
('f3c6e6a1-8c22-4df0-9a01-666666666666','f3c6e6a1-8c22-4df0-9a01-333333333333','shelf','TEST-LOC-B','Test Shelf B',2);
INSERT INTO public.count_sessions(id,project_id,name,status,created_by)
VALUES('f3c6e6a1-8c22-4df0-9a01-777777777777','f3c6e6a1-8c22-4df0-9a01-333333333333','Rollback Integration Session','active','f3c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO public.count_assignments(session_id,member_id,location_id,status)
VALUES('f3c6e6a1-8c22-4df0-9a01-777777777777','f3c6e6a1-8c22-4df0-9a01-444444444444','f3c6e6a1-8c22-4df0-9a01-555555555555','assigned');

SELECT public.count_create_import_batch('f3c6e6a1-8c22-4df0-9a01-333333333333',
'f3c6e6a1-8c22-4df0-9a01-777777777777','rollback-fixture.csv','csv','rollback-fixture-checksum');
DO $$
DECLARE v_batch uuid; v_stage jsonb; v_commit jsonb;
BEGIN
  SELECT id INTO v_batch FROM public.count_import_batches
  WHERE source_name='rollback-fixture.csv' AND project_id='f3c6e6a1-8c22-4df0-9a01-333333333333';
  v_stage:=public.count_stage_import_rows(v_batch,'[
    {"sku":"CF-TEST-001","barcode":"990000000001","name":"Test Product One","base_unit":"each","units":["each"],"expected_qty":"10","location_code":"TEST-LOC-A"},
    {"sku":"CF-TEST-002","barcode":"990000000002","name":"Test Product Two","base_unit":"each","units":["each"],"expected_qty":"5","location_code":"TEST-LOC-A"},
    {"sku":"","name":"Rejected Product","base_unit":"each","expected_qty":"2","location_code":"TEST-LOC-A"}
  ]'::jsonb,0);
  IF (v_stage->>'accepted_rows')::int<>2 OR (v_stage->>'rejected_rows')::int<>1
  THEN RAISE EXCEPTION 'ASSERT_IMPORT_PREVIEW_FAILED: %',v_stage; END IF;
  v_commit:=public.count_commit_import_batch(v_batch);
  IF (v_commit->>'accepted_rows')::int<>2 OR (v_commit->>'rejected_rows')::int<>1
     OR (v_commit->>'expected_balance_rows')::int<>2
  THEN RAISE EXCEPTION 'ASSERT_IMPORT_COMMIT_FAILED: %',v_commit; END IF;
END $$;

-- New minimum-data regression: barcode + base unit is enough to create and count an item.
DO $$
DECLARE
  v_batch uuid;
  v_stage jsonb;
  v_commit jsonb;
  v_product public.count_products;
BEGIN
  v_batch := public.count_create_import_batch(
    'f3c6e6a1-8c22-4df0-9a01-333333333333',
    'f3c6e6a1-8c22-4df0-9a01-777777777777',
    'barcode-only-fixture.csv','csv','barcode-only-fixture-checksum'
  );
  v_stage := public.count_stage_import_rows(v_batch,'[
    {"sku":"","barcode":"990000000009","name":"","base_unit":"قطعة","units":[],"expected_qty":"","location_code":"TEST-LOC-A"},
    {"sku":"","barcode":"","name":"Missing Identity","base_unit":"قطعة"},
    {"sku":"","barcode":"990000000010","name":"","base_unit":""}
  ]'::jsonb,0);

  IF (v_stage->>'accepted_rows')::int<>1 OR (v_stage->>'rejected_rows')::int<>2
  THEN RAISE EXCEPTION 'ASSERT_MINIMUM_DATA_STAGE_FAILED: %',v_stage; END IF;

  v_commit := public.count_commit_import_batch(v_batch);
  IF (v_commit->>'accepted_rows')::int<>1 OR (v_commit->>'rejected_rows')::int<>2
  THEN RAISE EXCEPTION 'ASSERT_MINIMUM_DATA_COMMIT_FAILED: %',v_commit; END IF;

  SELECT * INTO v_product FROM public.count_products
  WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
    AND barcode='990000000009';
  IF NOT FOUND OR v_product.sku IS NOT NULL OR v_product.name IS NOT NULL
     OR v_product.base_unit<>'قطعة' OR v_product.image_url IS NOT NULL
  THEN RAISE EXCEPTION 'ASSERT_OPTIONAL_METADATA_NOT_PRESERVED_AS_NULL'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT public.count_touch_presence('f3c6e6a1-8c22-4df0-9a01-777777777777',
'rollback-device-001','Rollback Test Device','desktop','test','online','f3c6e6a1-8c22-4df0-9a01-555555555555');
SELECT public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001'),
'f3c6e6a1-8c22-4df0-9a01-555555555555',7,'each','f3c6e6a1-8c22-4df0-9a01-888888888888',
'990000000001','rollback-device-001','rollback integration count');

DO $$
DECLARE v_first uuid; v_second uuid;
BEGIN
  SELECT id INTO v_first FROM public.count_entries WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
    AND client_event_id='f3c6e6a1-8c22-4df0-9a01-888888888888';
  SELECT (public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
    (SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001'),
    'f3c6e6a1-8c22-4df0-9a01-555555555555',7,'each','f3c6e6a1-8c22-4df0-9a01-888888888888',
    '990000000001','rollback-device-001','rollback integration count')).id INTO v_second;
  IF v_first IS DISTINCT FROM v_second THEN RAISE EXCEPTION 'ASSERT_IDEMPOTENCY_FAILED'; END IF;
END $$;

DO $$ BEGIN
  BEGIN
    PERFORM public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
      (SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001'),
      'f3c6e6a1-8c22-4df0-9a01-666666666666',1,'each','f3c6e6a1-8c22-4df0-9a01-999999999999',
      '990000000001','rollback-device-001','must be denied');
    RAISE EXCEPTION 'ASSERT_ASSIGNMENT_ENFORCEMENT_FAILED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'LOCATION_NOT_ASSIGNED' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT public.count_reconcile_session('f3c6e6a1-8c22-4df0-9a01-777777777777');
SELECT public.count_generate_recount_tasks(
 (SELECT id FROM public.count_reconciliation_runs WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' ORDER BY run_number DESC LIMIT 1),
 'f3c6e6a1-8c22-4df0-9a01-444444444444',0);

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT public.count_record_recount_entry(
 (SELECT id FROM public.count_recount_tasks WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
  AND product_id=(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001') LIMIT 1),
 8,'each','f3c6e6a1-8c22-4df0-9a01-aaaaaaaaaaaa','990000000001','rollback-device-001','recount test');

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT public.count_review_recount_task(
 (SELECT id FROM public.count_recount_tasks WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
  AND product_id=(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001') LIMIT 1),
 'accept','rollback integration review');
SELECT public.count_reconcile_session('f3c6e6a1-8c22-4df0-9a01-777777777777');

DO $$
DECLARE v_first numeric; v_second numeric; v_kpis jsonb;
BEGIN
  SELECT counted_quantity INTO v_first FROM public.count_reconciliation_lines
   WHERE run_id=(SELECT id FROM public.count_reconciliation_runs WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=1)
     AND product_id=(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001');
  SELECT counted_quantity INTO v_second FROM public.count_reconciliation_lines
   WHERE run_id=(SELECT id FROM public.count_reconciliation_runs WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=2)
     AND product_id=(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001');
  v_kpis:=public.count_session_kpis('f3c6e6a1-8c22-4df0-9a01-777777777777');
  IF v_first<>7 OR v_second<>8 OR (v_kpis->>'quantity_total')::numeric<>8
  THEN RAISE EXCEPTION 'ASSERT_RECOUNT_OVERRIDE_FAILED: first %, second %, kpis %',v_first,v_second,v_kpis; END IF;
END $$;

SELECT jsonb_build_object(
 'accepted_import_rows',2,'rejected_import_rows',1,'idempotency','passed',
 'assignment_boundary','passed','first_count',7,'approved_recount',8,
 'reconciliation_after_recount',8,'kpis',public.count_session_kpis('f3c6e6a1-8c22-4df0-9a01-777777777777')
) AS verified_result;

-- Prove the barcode-only product can pass the same server-authoritative count RPC.
SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
DO $
DECLARE v_product uuid; v_entry public.count_entries;
BEGIN
  SELECT id INTO v_product FROM public.count_products
  WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
    AND barcode='990000000009';
  v_entry := public.count_record_entry(
    'f3c6e6a1-8c22-4df0-9a01-777777777777',v_product,
    'f3c6e6a1-8c22-4df0-9a01-555555555555',3,'قطعة',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '990000000009','rollback-device-001','barcode-only count'
  );
  IF v_entry.product_id IS DISTINCT FROM v_product
     OR v_entry.quantity<>3 OR v_entry.unit<>'قطعة'
     OR v_entry.base_quantity<>3
  THEN RAISE EXCEPTION 'ASSERT_BARCODE_ONLY_COUNT_FAILED'; END IF;
END $$;
ROLLBACK;
