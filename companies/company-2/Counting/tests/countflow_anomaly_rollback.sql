-- Automatic anomaly alerts and approval gate; rollback-only.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('c4c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-alert-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('c4c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-alert-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','c4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"c4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('c4c6e6a1-8c22-4df0-9a01-333333333333','ALERT TEST','CF-ALERT-TEST','c4c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('c4c6e6a1-8c22-4df0-9a01-444444444444','c4c6e6a1-8c22-4df0-9a01-333333333333','c4c6e6a1-8c22-4df0-9a01-222222222222','Counter','counter','counter','active');
INSERT INTO count_locations(id,project_id,location_type,code,name) VALUES('c4c6e6a1-8c22-4df0-9a01-555555555555','c4c6e6a1-8c22-4df0-9a01-333333333333','shelf','A-1','Alert Shelf');
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('c4c6e6a1-8c22-4df0-9a01-777777777777','c4c6e6a1-8c22-4df0-9a01-333333333333','Alert Session','active','c4c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO count_assignments(session_id,member_id,location_id,status) VALUES('c4c6e6a1-8c22-4df0-9a01-777777777777','c4c6e6a1-8c22-4df0-9a01-444444444444','c4c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO count_products(id,project_id,sku,name,base_unit,units) VALUES('c4c6e6a1-8c22-4df0-9a01-888888888888','c4c6e6a1-8c22-4df0-9a01-333333333333','CF-ALERT-001','Alert Product','each','["each"]');
INSERT INTO count_expected_balances(project_id,session_id,product_id,location_id,expected_quantity,unit)
VALUES('c4c6e6a1-8c22-4df0-9a01-333333333333','c4c6e6a1-8c22-4df0-9a01-777777777777','c4c6e6a1-8c22-4df0-9a01-888888888888','c4c6e6a1-8c22-4df0-9a01-555555555555',10,'each');
INSERT INTO count_anomaly_rules(project_id,name,rule_type,threshold,severity,config,is_active,created_by)
VALUES
('c4c6e6a1-8c22-4df0-9a01-333333333333','quantity','quantity_above',5,'warning','{}',true,'c4c6e6a1-8c22-4df0-9a01-111111111111'),
('c4c6e6a1-8c22-4df0-9a01-333333333333','repeat','repeat_scan_window',1,'warning','{"window_minutes":5}',true,'c4c6e6a1-8c22-4df0-9a01-111111111111'),
('c4c6e6a1-8c22-4df0-9a01-333333333333','variance','variance_percent_above',10,'critical','{}',true,'c4c6e6a1-8c22-4df0-9a01-111111111111');
SELECT set_config('request.jwt.claim.sub','c4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"c4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_touch_presence('c4c6e6a1-8c22-4df0-9a01-777777777777','alert-device','test','desktop','test','online','c4c6e6a1-8c22-4df0-9a01-555555555555');
SELECT count_record_entry('c4c6e6a1-8c22-4df0-9a01-777777777777','c4c6e6a1-8c22-4df0-9a01-888888888888','c4c6e6a1-8c22-4df0-9a01-555555555555',7,'each','c4c6e6a1-8c22-4df0-9a01-999999999991','barcode','alert-device','large count');
SELECT count_record_entry('c4c6e6a1-8c22-4df0-9a01-777777777777','c4c6e6a1-8c22-4df0-9a01-888888888888','c4c6e6a1-8c22-4df0-9a01-555555555555',1,'each','c4c6e6a1-8c22-4df0-9a01-999999999992','barcode','alert-device','repeat count');
SELECT set_config('request.jwt.claim.sub','c4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"c4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SELECT count_reconcile_session('c4c6e6a1-8c22-4df0-9a01-777777777777');
DO $$
DECLARE v_qty int; v_repeat int; v_variance int; v_run uuid;
BEGIN
 SELECT count(*) FILTER(WHERE alert_type='quantity_above'),count(*) FILTER(WHERE alert_type='repeat_scan_window'),
        count(*) FILTER(WHERE alert_type='variance_percent_above')
 INTO v_qty,v_repeat,v_variance FROM count_alerts WHERE session_id='c4c6e6a1-8c22-4df0-9a01-777777777777';
 IF v_qty<>1 OR v_repeat<>1 OR v_variance<>1 THEN RAISE EXCEPTION 'ASSERT_AUTOMATIC_ALERTS_FAILED: %, %, %',v_qty,v_repeat,v_variance; END IF;
 SELECT id INTO v_run FROM count_reconciliation_runs WHERE session_id='c4c6e6a1-8c22-4df0-9a01-777777777777';
 BEGIN
  PERFORM count_approve_reconciliation(v_run);
  RAISE EXCEPTION 'ASSERT_CRITICAL_ALERT_GUARD_FAILED';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE 'CRITICAL_ALERTS_UNRESOLVED:%' THEN RAISE; END IF;
 END;
END $$;
UPDATE count_alerts SET status='resolved',resolved_by='c4c6e6a1-8c22-4df0-9a01-111111111111',resolved_at=now()
WHERE session_id='c4c6e6a1-8c22-4df0-9a01-777777777777' AND severity='critical' AND status='open';
SELECT count_approve_reconciliation((SELECT id FROM count_reconciliation_runs WHERE session_id='c4c6e6a1-8c22-4df0-9a01-777777777777'));
SELECT jsonb_build_object('quantity_alerts',1,'repeat_scan_alerts',1,'variance_alerts',1,'critical_guard','passed','approval_after_resolution','passed') AS verified;
ROLLBACK;
