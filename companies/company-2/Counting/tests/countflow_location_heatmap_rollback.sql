-- Authoritative location heatmap, hierarchy integrity, and repeat refresh stability.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('b6c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-heat-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('b6c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-heat-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','b6c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"b6c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('b6c6e6a1-8c22-4df0-9a01-333333333333','HEAT TEST','CF-HEAT-TEST','b6c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('b6c6e6a1-8c22-4df0-9a01-444444444444','b6c6e6a1-8c22-4df0-9a01-333333333333','b6c6e6a1-8c22-4df0-9a01-222222222222','Heat Counter','heat-counter','counter','active');
INSERT INTO count_locations(id,project_id,location_type,code,name,parent_id,sort_order)
VALUES
('b6c6e6a1-8c22-4df0-9a01-555555555555','b6c6e6a1-8c22-4df0-9a01-333333333333','warehouse','WH','المخزن',NULL,1),
('b6c6e6a1-8c22-4df0-9a01-666666666666','b6c6e6a1-8c22-4df0-9a01-333333333333','shelf','A-01','رف A-01','b6c6e6a1-8c22-4df0-9a01-555555555555',1);
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('b6c6e6a1-8c22-4df0-9a01-777777777777','b6c6e6a1-8c22-4df0-9a01-333333333333','Heat Session','active','b6c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO count_assignments(session_id,member_id,location_id,status) VALUES('b6c6e6a1-8c22-4df0-9a01-777777777777','b6c6e6a1-8c22-4df0-9a01-444444444444','b6c6e6a1-8c22-4df0-9a01-666666666666','assigned');
INSERT INTO count_products(id,project_id,sku,name,base_unit,units) VALUES('b6c6e6a1-8c22-4df0-9a01-888888888888','b6c6e6a1-8c22-4df0-9a01-333333333333','CF-HEAT-001','Heat Product','each','[{"name":"each","factor_to_base":1}]'::jsonb);
INSERT INTO count_expected_balances(project_id,session_id,product_id,location_id,expected_quantity,unit)
VALUES('b6c6e6a1-8c22-4df0-9a01-333333333333','b6c6e6a1-8c22-4df0-9a01-777777777777','b6c6e6a1-8c22-4df0-9a01-888888888888','b6c6e6a1-8c22-4df0-9a01-666666666666',10,'each');
SELECT set_config('request.jwt.claim.sub','b6c6e6a1-8c22-4df0-9a01-222222222222',true);
SELECT set_config('request.jwt.claims','{"sub":"b6c6e6a1-8c22-4df0-9a01-222222222222","role":"authenticated"}',true);
SELECT count_touch_presence('b6c6e6a1-8c22-4df0-9a01-777777777777','heat-device','Heat Device','desktop','test','online','b6c6e6a1-8c22-4df0-9a01-666666666666');
SELECT count_record_entry('b6c6e6a1-8c22-4df0-9a01-777777777777','b6c6e6a1-8c22-4df0-9a01-888888888888','b6c6e6a1-8c22-4df0-9a01-666666666666',4,'each','b6c6e6a1-8c22-4df0-9a01-999999999991','barcode','heat-device','first');
SELECT count_record_entry('b6c6e6a1-8c22-4df0-9a01-777777777777','b6c6e6a1-8c22-4df0-9a01-888888888888','b6c6e6a1-8c22-4df0-9a01-666666666666',6,'each','b6c6e6a1-8c22-4df0-9a01-999999999992','barcode','heat-device','second');
SELECT set_config('request.jwt.claim.sub','b6c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"b6c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
DO $$ DECLARE a jsonb; b jsonb; row jsonb;
BEGIN
 a:=public.count_session_heatmap('b6c6e6a1-8c22-4df0-9a01-777777777777');
 b:=public.count_session_heatmap('b6c6e6a1-8c22-4df0-9a01-777777777777');
 IF a->>'counted_positions_total'<>'1' OR a->>'expected_positions_total'<>'1' OR a->>'coverage_percent_total'<>'100.0' THEN
   RAISE EXCEPTION 'HEATMAP_TOTALS_INVALID:%',a;
 END IF;
 SELECT value INTO row FROM jsonb_array_elements(a->'locations') WHERE value->>'code'='A-01';
 IF row IS NULL OR row->>'path'<>'WH / A-01' OR (row->>'counted_quantity')::numeric<>10 OR (row->>'variance_quantity')::numeric<>0 OR row->>'count_events'<>'2' THEN
   RAISE EXCEPTION 'HEATMAP_LOCATION_INVALID:%',row;
 END IF;
 IF (a-'generated_at') IS DISTINCT FROM (b-'generated_at') THEN
   RAISE EXCEPTION 'HEATMAP_REFRESH_NOT_IDEMPOTENT:%:%',a,b;
 END IF;
 BEGIN
   UPDATE count_locations SET parent_id='b6c6e6a1-8c22-4df0-9a01-666666666666'
   WHERE id='b6c6e6a1-8c22-4df0-9a01-555555555555';
   RAISE EXCEPTION 'LOCATION_CYCLE_NOT_BLOCKED';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'LOCATION_PARENT_CYCLE_NOT_ALLOWED' THEN RAISE; END IF; END;
END $$;
SELECT jsonb_build_object('hierarchy_path','WH / A-01','counted_positions',1,'count_events',2,'coverage_percent',100,'refresh_stable',true,'cycle_guard','passed') AS verified;
ROLLBACK;
