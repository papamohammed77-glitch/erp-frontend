-- Administrative audit coverage; test is fully rolled back.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('a5c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-audit-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('a5c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-audit-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','a5c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"a5c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('a5c6e6a1-8c22-4df0-9a01-333333333333','AUDIT TEST','CF-AUDIT-TEST','a5c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('a5c6e6a1-8c22-4df0-9a01-444444444444','a5c6e6a1-8c22-4df0-9a01-333333333333','a5c6e6a1-8c22-4df0-9a01-222222222222','Audit Counter','audit-counter','counter','active');
INSERT INTO count_locations(id,project_id,location_type,code,name) VALUES('a5c6e6a1-8c22-4df0-9a01-555555555555','a5c6e6a1-8c22-4df0-9a01-333333333333','shelf','AU-1','Audit Shelf');
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('a5c6e6a1-8c22-4df0-9a01-777777777777','a5c6e6a1-8c22-4df0-9a01-333333333333','Audit Session','active','a5c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO count_assignments(session_id,member_id,location_id,status) VALUES('a5c6e6a1-8c22-4df0-9a01-777777777777','a5c6e6a1-8c22-4df0-9a01-444444444444','a5c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO count_anomaly_rules(project_id,name,rule_type,threshold,severity,is_active,config,created_by)
VALUES('a5c6e6a1-8c22-4df0-9a01-333333333333','Audit Qty Rule','quantity_above',100,'warning',false,'{}','a5c6e6a1-8c22-4df0-9a01-111111111111');
SELECT set_config('request.jwt.claim.sub','a5c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"a5c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_touch_presence('a5c6e6a1-8c22-4df0-9a01-777777777777','audit-device','Audit Device','desktop','test','online','a5c6e6a1-8c22-4df0-9a01-555555555555');
SELECT count_touch_presence('a5c6e6a1-8c22-4df0-9a01-777777777777','audit-device','Audit Device','desktop','test','online','a5c6e6a1-8c22-4df0-9a01-555555555555');
SELECT set_config('request.jwt.claim.sub','a5c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"a5c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
UPDATE count_sessions SET status='paused' WHERE id='a5c6e6a1-8c22-4df0-9a01-777777777777';
UPDATE count_members SET status='paused' WHERE id='a5c6e6a1-8c22-4df0-9a01-444444444444';
DO $$ DECLARE
 v_projects integer; v_members integer; v_sessions integer; v_assignments integer; v_rules integer; v_devices integer;
BEGIN
 SELECT count(*) INTO v_projects FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_projects.insert';
 SELECT count(*) INTO v_members FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_members.insert';
 SELECT count(*) INTO v_sessions FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_sessions.insert';
 SELECT count(*) INTO v_assignments FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_assignments.insert';
 SELECT count(*) INTO v_rules FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_anomaly_rules.insert';
 SELECT count(*) INTO v_devices FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_devices.insert';
 IF v_projects<>1 OR v_members<2 OR v_sessions<>1 OR v_assignments<>1 OR v_rules<>1 OR v_devices<>1 THEN
   RAISE EXCEPTION 'AUDIT_COVERAGE_FAILED: %, %, %, %, %, %',v_projects,v_members,v_sessions,v_assignments,v_rules,v_devices;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_sessions.update') THEN
   RAISE EXCEPTION 'SESSION_UPDATE_AUDIT_MISSING';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM count_audit_log WHERE project_id='a5c6e6a1-8c22-4df0-9a01-333333333333' AND action='countflow.count_members.update') THEN
   RAISE EXCEPTION 'MEMBER_UPDATE_AUDIT_MISSING';
 END IF;
END $$;
SELECT jsonb_build_object('project','logged','members','logged','session','logged','assignment','logged','anomaly_rule','logged','device_registration','logged','heartbeat_noise','suppressed') AS verified;
ROLLBACK;
