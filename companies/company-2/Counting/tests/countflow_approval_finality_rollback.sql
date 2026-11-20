-- Reconciliation approval watermark, latest-run, session-freeze and append-only gate.
-- Run as postgres in SQL Editor; all temporary identities and rows roll back.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('d4c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-final-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('d4c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-final-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','d4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"d4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('d4c6e6a1-8c22-4df0-9a01-333333333333','FINALITY TEST','CF-FINAL-TEST','d4c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('d4c6e6a1-8c22-4df0-9a01-444444444444','d4c6e6a1-8c22-4df0-9a01-333333333333','d4c6e6a1-8c22-4df0-9a01-222222222222','Counter','counter','counter','active');
INSERT INTO count_locations(id,project_id,location_type,code,name) VALUES('d4c6e6a1-8c22-4df0-9a01-555555555555','d4c6e6a1-8c22-4df0-9a01-333333333333','shelf','F-A','Final Shelf');
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('d4c6e6a1-8c22-4df0-9a01-777777777777','d4c6e6a1-8c22-4df0-9a01-333333333333','Final Session','planned','d4c6e6a1-8c22-4df0-9a01-111111111111');
SELECT count_transition_session('d4c6e6a1-8c22-4df0-9a01-777777777777','active');
INSERT INTO count_assignments(session_id,member_id,location_id,status) VALUES('d4c6e6a1-8c22-4df0-9a01-777777777777','d4c6e6a1-8c22-4df0-9a01-444444444444','d4c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO count_products(id,project_id,sku,name,base_unit,units) VALUES('d4c6e6a1-8c22-4df0-9a01-888888888888','d4c6e6a1-8c22-4df0-9a01-333333333333','CF-FINAL-001','Final Product','each','["each"]');
DO $baseline_import$
DECLARE v_batch uuid; v_stage jsonb; v_commit jsonb;
BEGIN
 v_batch:=public.count_create_import_batch(
  'd4c6e6a1-8c22-4df0-9a01-333333333333',
  'd4c6e6a1-8c22-4df0-9a01-777777777777',
  'finality-baseline.csv','csv','finality-baseline-checksum'
 );
 v_stage:=public.count_stage_import_rows(v_batch,'[
  {"sku":"CF-FINAL-001","name":"Final Product","base_unit":"each","expected_qty":"10","location_code":"F-A"}
 ]'::jsonb,0);
 IF (v_stage->>'accepted_rows')::int<>1 THEN RAISE EXCEPTION 'ASSERT_FINALITY_BASELINE_STAGE_FAILED:%',v_stage; END IF;
 v_commit:=public.count_commit_import_batch(v_batch);
 IF (v_commit->>'accepted_rows')::int<>1 OR (v_commit->>'expected_balance_rows')::int<>1
 THEN RAISE EXCEPTION 'ASSERT_FINALITY_BASELINE_COMMIT_FAILED:%',v_commit; END IF;
END $baseline_import$;
SELECT set_config('request.jwt.claim.sub','d4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"d4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_touch_presence('d4c6e6a1-8c22-4df0-9a01-777777777777','final-device','test','desktop','test','online','d4c6e6a1-8c22-4df0-9a01-555555555555');
SELECT count_record_entry('d4c6e6a1-8c22-4df0-9a01-777777777777','d4c6e6a1-8c22-4df0-9a01-888888888888','d4c6e6a1-8c22-4df0-9a01-555555555555',8,'each','d4c6e6a1-8c22-4df0-9a01-999999999991','barcode','final-device','first');
SELECT set_config('request.jwt.claim.sub','d4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"d4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT count_reconcile_session('d4c6e6a1-8c22-4df0-9a01-777777777777');
SELECT set_config('request.jwt.claim.sub','d4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"d4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_record_entry('d4c6e6a1-8c22-4df0-9a01-777777777777','d4c6e6a1-8c22-4df0-9a01-888888888888','d4c6e6a1-8c22-4df0-9a01-555555555555',2,'each','d4c6e6a1-8c22-4df0-9a01-999999999992','barcode','final-device','post-reconcile count');
SELECT set_config('request.jwt.claim.sub','d4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"d4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
DO $$ DECLARE v_run1 uuid;
BEGIN
 SELECT id INTO v_run1 FROM count_reconciliation_runs WHERE session_id='d4c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=1;
 BEGIN PERFORM count_approve_reconciliation(v_run1); RAISE EXCEPTION 'ASSERT_STALE_RUN_DATA_GUARD_FAILED';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%' THEN RAISE; END IF; END;
END $$;
SELECT count_reconcile_session('d4c6e6a1-8c22-4df0-9a01-777777777777');
DO $$ DECLARE v_run1 uuid;
BEGIN
 SELECT id INTO v_run1 FROM count_reconciliation_runs WHERE session_id='d4c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=1;
 BEGIN PERFORM count_approve_reconciliation(v_run1); RAISE EXCEPTION 'ASSERT_LATEST_RUN_GUARD_FAILED';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'RECONCILIATION_NOT_LATEST' THEN RAISE; END IF; END;
END $$;
SELECT count_approve_reconciliation((SELECT id FROM count_reconciliation_runs WHERE session_id='d4c6e6a1-8c22-4df0-9a01-777777777777' AND run_number=2));
DO $$ DECLARE v_status text;
BEGIN
 SELECT status INTO v_status FROM count_sessions WHERE id='d4c6e6a1-8c22-4df0-9a01-777777777777';
 IF v_status<>'review' THEN RAISE EXCEPTION 'ASSERT_SESSION_FREEZE_STATUS_FAILED: %',v_status; END IF;
 BEGIN
  INSERT INTO count_entries(project_id,session_id,member_id,product_id,location_id,quantity,unit,client_event_id,scan_code,device_id)
  VALUES('d4c6e6a1-8c22-4df0-9a01-333333333333','d4c6e6a1-8c22-4df0-9a01-777777777777','d4c6e6a1-8c22-4df0-9a01-222222222222','d4c6e6a1-8c22-4df0-9a01-888888888888','d4c6e6a1-8c22-4df0-9a01-555555555555',1,'each','d4c6e6a1-8c22-4df0-9a01-999999999993','barcode','final-device');
  RAISE EXCEPTION 'ASSERT_POST_APPROVAL_COUNT_NOT_BLOCKED';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'SESSION_RECONCILIATION_ALREADY_APPROVED' THEN RAISE; END IF; END;
END $$;
SELECT jsonb_build_object('stale_data_guard','passed','latest_run_guard','passed','approval_freezes_session','passed','post_approval_insert_blocked','passed') AS verified_result;
ROLLBACK;
