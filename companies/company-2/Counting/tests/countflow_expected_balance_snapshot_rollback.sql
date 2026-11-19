-- Expected balance uses the product base unit and becomes immutable after first count.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('f4c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-expected-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('f4c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-expected-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','f4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('f4c6e6a1-8c22-4df0-9a01-333333333333','EXPECTED TEST','CF-EXPECTED-TEST','f4c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('f4c6e6a1-8c22-4df0-9a01-444444444444','f4c6e6a1-8c22-4df0-9a01-333333333333','f4c6e6a1-8c22-4df0-9a01-222222222222','Counter','counter','counter','active');
INSERT INTO count_locations(id,project_id,location_type,code,name) VALUES('f4c6e6a1-8c22-4df0-9a01-555555555555','f4c6e6a1-8c22-4df0-9a01-333333333333','shelf','EX-A','Expected Shelf');
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('f4c6e6a1-8c22-4df0-9a01-777777777777','f4c6e6a1-8c22-4df0-9a01-333333333333','Expected Session','active','f4c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO count_assignments(session_id,member_id,location_id,status) VALUES('f4c6e6a1-8c22-4df0-9a01-777777777777','f4c6e6a1-8c22-4df0-9a01-444444444444','f4c6e6a1-8c22-4df0-9a01-555555555555','assigned');
INSERT INTO count_products(id,project_id,sku,name,base_unit,units) VALUES('f4c6e6a1-8c22-4df0-9a01-888888888888','f4c6e6a1-8c22-4df0-9a01-333333333333','CF-EXPECTED-001','Expected Product','each','["each"]');
INSERT INTO count_expected_balances(project_id,session_id,product_id,location_id,expected_quantity,unit)
VALUES('f4c6e6a1-8c22-4df0-9a01-333333333333','f4c6e6a1-8c22-4df0-9a01-777777777777','f4c6e6a1-8c22-4df0-9a01-888888888888','f4c6e6a1-8c22-4df0-9a01-555555555555',10,'each');
UPDATE count_expected_balances SET expected_quantity=11
WHERE session_id='f4c6e6a1-8c22-4df0-9a01-777777777777';
DO $$ BEGIN
  BEGIN
    INSERT INTO count_expected_balances(project_id,session_id,product_id,location_id,expected_quantity,unit)
    VALUES('f4c6e6a1-8c22-4df0-9a01-333333333333','f4c6e6a1-8c22-4df0-9a01-777777777777','f4c6e6a1-8c22-4df0-9a01-888888888888',NULL,1,'case');
    RAISE EXCEPTION 'ASSERT_NON_BASE_EXPECTED_UNIT_NOT_BLOCKED';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'EXPECTED_BALANCE_MUST_USE_BASE_UNIT:%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','f4c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"f4c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_touch_presence('f4c6e6a1-8c22-4df0-9a01-777777777777','expected-device','test','desktop','test','online','f4c6e6a1-8c22-4df0-9a01-555555555555');
SELECT count_record_entry('f4c6e6a1-8c22-4df0-9a01-777777777777','f4c6e6a1-8c22-4df0-9a01-888888888888','f4c6e6a1-8c22-4df0-9a01-555555555555',11,'each','f4c6e6a1-8c22-4df0-9a01-999999999991','barcode','expected-device','first count');
SELECT set_config('request.jwt.claim.sub','f4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"f4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
DO $$ BEGIN
  BEGIN
    UPDATE count_expected_balances SET expected_quantity=12
    WHERE session_id='f4c6e6a1-8c22-4df0-9a01-777777777777';
    RAISE EXCEPTION 'ASSERT_EXPECTED_BALANCE_MUTATION_AFTER_COUNT_NOT_BLOCKED';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'EXPECTED_BALANCES_LOCKED_AFTER_FIRST_COUNT' THEN RAISE; END IF; END;
END $$;
SELECT jsonb_build_object('base_unit_only','passed','pre_count_update','passed','post_count_snapshot_lock','passed') AS verified;
ROLLBACK;
