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
('f3c6e6a1-8c22-4df0-9a01-666666666666','f3c6e6a1-8c22-4df0-9a01-333333333333','shelf','TEST-LOC-B','Test Shelf B',2),
('f3c6e6a1-8c22-4df0-9a01-555555555556','f3c6e6a1-8c22-4df0-9a01-333333333333','shelf','TEST-LOC-C','Test Shelf C',3);
INSERT INTO public.count_sessions(id,project_id,name,status,created_by)
VALUES('f3c6e6a1-8c22-4df0-9a01-777777777777','f3c6e6a1-8c22-4df0-9a01-333333333333','Rollback Integration Session','planned','f3c6e6a1-8c22-4df0-9a01-111111111111');
SELECT public.count_transition_session('f3c6e6a1-8c22-4df0-9a01-777777777777','active');
INSERT INTO public.count_assignments(session_id,member_id,location_id,status)
VALUES('f3c6e6a1-8c22-4df0-9a01-777777777777','f3c6e6a1-8c22-4df0-9a01-444444444444','f3c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO public.count_assignments(session_id,member_id,location_id,status)
VALUES('f3c6e6a1-8c22-4df0-9a01-777777777777','f3c6e6a1-8c22-4df0-9a01-444444444444','f3c6e6a1-8c22-4df0-9a01-666666666666','assigned');

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
DO $barcode_import$
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
    {"sku":"","barcode":"990000000009","name":"","base_unit":"قطعة","units":[],"expected_qty":"","location_code":"TEST-LOC-A","purchase_unit_cost":"120","currency_code":"EGP","purchase_unit":"كرتونة","unit_factor_to_base":"12","cost_source_type":"supplier_invoice","cost_source_reference":"SUP-INV-001","cost_source_date":"2026-11-20"},
    {"sku":"","barcode":"990000000009","name":"","base_unit":"قطعة","units":[],"expected_qty":"","location_code":"TEST-LOC-B","purchase_unit_cost":"120","currency_code":"EGP","purchase_unit":"كرتونة","unit_factor_to_base":"12","cost_source_type":"supplier_invoice","cost_source_reference":"SUP-INV-001","cost_source_date":"2026-11-20"},
    {"sku":"","barcode":"990000000011","name":"","base_unit":"قطعة","purchase_unit_cost":"15","purchase_unit":"كرتونة"},
    {"sku":"","barcode":"990000000012","name":"","base_unit":"قطعة","location_code":"TEST-LOC-A","purchase_unit_cost":"10","currency_code":"EGP","purchase_unit":"كرتونة","unit_factor_to_base":"12","cost_source_type":"supplier_invoice","cost_source_reference":"SUP-INV-A"},
    {"sku":"","barcode":"990000000012","name":"","base_unit":"قطعة","location_code":"TEST-LOC-B","purchase_unit_cost":"12","currency_code":"EGP","purchase_unit":"كرتونة","unit_factor_to_base":"12","cost_source_type":"supplier_invoice","cost_source_reference":"SUP-INV-B"},
    {"sku":"","barcode":"","name":"Missing Identity","base_unit":"قطعة"},
    {"sku":"","barcode":"990000000010","name":"","base_unit":""}
  ]'::jsonb,0);

  IF (v_stage->>'accepted_rows')::int<>5 OR (v_stage->>'rejected_rows')::int<>2
  THEN RAISE EXCEPTION 'ASSERT_MINIMUM_DATA_STAGE_FAILED: %',v_stage; END IF;

  v_commit := public.count_commit_import_batch(v_batch);
  IF (v_commit->>'accepted_rows')::int<>5 OR (v_commit->>'rejected_rows')::int<>2
  THEN RAISE EXCEPTION 'ASSERT_MINIMUM_DATA_COMMIT_FAILED: %',v_commit; END IF;

  SELECT * INTO v_product FROM public.count_products
  WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
    AND barcode='990000000009';
  IF NOT FOUND OR v_product.sku IS NOT NULL OR v_product.name IS NOT NULL
     OR v_product.base_unit<>'قطعة' OR v_product.image_url IS NOT NULL
  THEN RAISE EXCEPTION 'ASSERT_OPTIONAL_METADATA_NOT_PRESERVED_AS_NULL'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.count_session_product_costs c
    WHERE c.session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
      AND c.product_id=v_product.id
      AND c.purchase_unit_cost=120 AND c.currency_code='EGP'
      AND c.purchase_unit='كرتونة' AND c.unit_factor_to_base=12
      AND c.source_type='supplier_invoice' AND c.source_reference='SUP-INV-001'
      AND cardinality(c.warning_codes)=0
  ) THEN RAISE EXCEPTION 'ASSERT_COMPLETE_COST_SNAPSHOT_FAILED'; END IF;
  IF (SELECT count(*) FROM public.count_expected_balances
      WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' AND product_id=v_product.id)<>2
  THEN RAISE EXCEPTION 'ASSERT_MULTI_LOCATION_EXPECTED_BALANCE_FAILED'; END IF;
  IF (SELECT count(*) FROM public.count_session_product_costs
      WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' AND product_id=v_product.id)<>1
  THEN RAISE EXCEPTION 'ASSERT_COST_SNAPSHOT_DUPLICATED_BY_LOCATION'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.count_session_product_costs c
    JOIN public.count_products p ON p.id=c.product_id
    WHERE c.session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
      AND p.barcode='990000000012'
  ) THEN RAISE EXCEPTION 'ASSERT_CONFLICTING_COST_WAS_NOT_BLOCKED'; END IF;
  IF (SELECT count(*) FROM public.count_import_rows
      WHERE batch_id=v_batch AND row_status='committed'
        AND 'CONFLICTING_COST_SNAPSHOT_IN_BATCH'=ANY(warning_codes))<>2
  THEN RAISE EXCEPTION 'ASSERT_CONFLICTING_COST_WARNING_MISSING'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.count_session_product_costs c
    JOIN public.count_products p ON p.id=c.product_id
    WHERE c.session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
      AND p.barcode='990000000011'
      AND c.purchase_unit_cost=15 AND c.currency_code IS NULL
      AND c.unit_factor_to_base IS NULL
      AND 'COST_DATA_INCOMPLETE'=ANY(c.warning_codes)
  ) THEN RAISE EXCEPTION 'ASSERT_PARTIAL_COST_ACCEPTED_WITH_WARNING_FAILED'; END IF;
END $barcode_import$;

DO $cost_enrichment$
DECLARE v_batch uuid; v_stage jsonb; v_commit jsonb;
BEGIN
  v_batch := public.count_create_import_batch(
    'f3c6e6a1-8c22-4df0-9a01-333333333333',
    'f3c6e6a1-8c22-4df0-9a01-777777777777',
    'cost-enrichment-fixture.csv','csv','cost-enrichment-fixture-checksum'
  );
  v_stage := public.count_stage_import_rows(v_batch,'[
    {"sku":"","barcode":"990000000009","name":"","base_unit":"","purchase_unit_cost":"36","currency_code":"EGP","purchase_unit":"كرتونة","unit_factor_to_base":"12","cost_source_type":"supplier_invoice","cost_source_reference":"SUP-INV-002","cost_source_date":"2026-11-20"}
  ]'::jsonb,0);
  IF (v_stage->>'accepted_rows')::int<>1 OR (v_stage->>'rejected_rows')::int<>0
  THEN RAISE EXCEPTION 'ASSERT_COST_ENRICHMENT_STAGE_FAILED: %',v_stage; END IF;
  v_commit := public.count_commit_import_batch(v_batch);
  IF (v_commit->>'accepted_rows')::int<>1 OR (v_commit->>'rejected_rows')::int<>0
  THEN RAISE EXCEPTION 'ASSERT_COST_ENRICHMENT_COMMIT_FAILED: %',v_commit; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.count_session_product_costs c
    JOIN public.count_products p ON p.id=c.product_id
    WHERE c.session_id='f3c6e6a1-8c22-4df0-9a01-777777777777'
      AND p.barcode='990000000009'
      AND c.purchase_unit_cost=36 AND c.currency_code='EGP'
      AND c.unit_factor_to_base=12 AND c.source_reference='SUP-INV-002'
  ) THEN RAISE EXCEPTION 'ASSERT_COST_ENRICHMENT_UPDATE_FAILED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.count_products
    WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
      AND barcode='990000000009' AND base_unit='قطعة'
  ) THEN RAISE EXCEPTION 'ASSERT_EXISTING_UNIT_REUSE_FAILED'; END IF;
END $cost_enrichment$;

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT public.count_touch_presence('f3c6e6a1-8c22-4df0-9a01-777777777777',
'rollback-device-001','Rollback Test Device','desktop','test','online','f3c6e6a1-8c22-4df0-9a01-555555555555');
SELECT public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
(SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND sku='CF-TEST-001'),
'f3c6e6a1-8c22-4df0-9a01-555555555555',7,'each','f3c6e6a1-8c22-4df0-9a01-888888888888',
'990000000001','rollback-device-001','rollback integration count');
SELECT public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
 (SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND barcode='990000000009'),
 'f3c6e6a1-8c22-4df0-9a01-555555555555',3,'قطعة','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '990000000009','rollback-device-001','barcode-only location A');
SELECT public.count_record_entry('f3c6e6a1-8c22-4df0-9a01-777777777777',
 (SELECT id FROM public.count_products WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333' AND barcode='990000000009'),
 'f3c6e6a1-8c22-4df0-9a01-666666666666',4,'قطعة','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
 '990000000009','rollback-device-001','barcode-only location B');

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
      'f3c6e6a1-8c22-4df0-9a01-555555555556',1,'each','f3c6e6a1-8c22-4df0-9a01-999999999999',
      '990000000001','rollback-device-001','must be denied');
    RAISE EXCEPTION 'ASSERT_ASSIGNMENT_ENFORCEMENT_FAILED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'LOCATION_NOT_ASSIGNED' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','f3c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f3c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT public.count_reconcile_session('f3c6e6a1-8c22-4df0-9a01-777777777777');
DO $scope_reconciliation$
DECLARE v_product uuid; v_count integer;
BEGIN
  SELECT id INTO v_product FROM public.count_products
  WHERE project_id='f3c6e6a1-8c22-4df0-9a01-333333333333'
    AND barcode='990000000009';
  SELECT count(*) INTO v_count FROM public.count_reconciliation_lines
  WHERE run_id=(SELECT id FROM public.count_reconciliation_runs
    WHERE session_id='f3c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=1)
    AND product_id=v_product AND expected_scope
    AND expected_quantity IS NULL AND counted_quantity IS NOT NULL
    AND result_status='not_expected';
  IF v_count<>2 THEN RAISE EXCEPTION 'ASSERT_NULL_BASELINE_SCOPE_RECONCILIATION_FAILED:%',v_count; END IF;
END $scope_reconciliation$;
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
  IF v_first<>7 OR v_second<>8 OR (v_kpis->>'quantity_total')::numeric<>15
  THEN RAISE EXCEPTION 'ASSERT_RECOUNT_OVERRIDE_FAILED: first %, second %, kpis %',v_first,v_second,v_kpis; END IF;
END $$;

SELECT jsonb_build_object(
 'accepted_import_rows',2,'rejected_import_rows',1,'idempotency','passed',
 'assignment_boundary','passed','first_count',7,'approved_recount',8,
 'reconciliation_after_recount',8,'kpis',public.count_session_kpis('f3c6e6a1-8c22-4df0-9a01-777777777777')
) AS verified_result;

-- Barcode-only counting at both locations is asserted in the first reconciliation.
SELECT 'PASS: barcode-only counting, optional fields, complete/partial cost capture and unit reuse' AS regression_result;
ROLLBACK;
