-- Idempotent assignment upsert, including the NULL all-locations scope.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES
('e4c6e6a1-8c22-4df0-9a01-111111111111','authenticated','authenticated','cf-assign-sup@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()),
('e4c6e6a1-8c22-4df0-9a01-222222222222','authenticated','authenticated','cf-assign-counter@example.invalid','',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now());
SELECT set_config('request.jwt.claim.sub','e4c6e6a1-8c22-4df0-9a01-111111111111',true);
SELECT set_config('request.jwt.claims','{"sub":"e4c6e6a1-8c22-4df0-9a01-111111111111","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
INSERT INTO count_projects(id,name,code,created_by,status) VALUES('e4c6e6a1-8c22-4df0-9a01-333333333333','ASSIGN TEST','CF-ASSIGN-TEST','e4c6e6a1-8c22-4df0-9a01-111111111111','active');
INSERT INTO count_members(id,project_id,user_id,display_name,username,role,status) VALUES('e4c6e6a1-8c22-4df0-9a01-444444444444','e4c6e6a1-8c22-4df0-9a01-333333333333','e4c6e6a1-8c22-4df0-9a01-222222222222','Counter','counter','counter','active');
INSERT INTO count_sessions(id,project_id,name,status,created_by) VALUES('e4c6e6a1-8c22-4df0-9a01-777777777777','e4c6e6a1-8c22-4df0-9a01-333333333333','Assign Session','active','e4c6e6a1-8c22-4df0-9a01-111111111111');
INSERT INTO count_locations(id,project_id,location_type,code,name) VALUES('e4c6e6a1-8c22-4df0-9a01-555555555555','e4c6e6a1-8c22-4df0-9a01-333333333333','shelf','AS-1','Assign Shelf');
INSERT INTO count_assignments(session_id,member_id,location_id,status)
VALUES('e4c6e6a1-8c22-4df0-9a01-777777777777','e4c6e6a1-8c22-4df0-9a01-444444444444',NULL,'assigned')
ON CONFLICT(session_id,member_id,location_id) DO UPDATE SET status=excluded.status;
INSERT INTO count_assignments(session_id,member_id,location_id,status)
VALUES('e4c6e6a1-8c22-4df0-9a01-777777777777','e4c6e6a1-8c22-4df0-9a01-444444444444',NULL,'assigned')
ON CONFLICT(session_id,member_id,location_id) DO UPDATE SET status=excluded.status;
INSERT INTO count_assignments(session_id,member_id,location_id,status)
VALUES('e4c6e6a1-8c22-4df0-9a01-777777777777','e4c6e6a1-8c22-4df0-9a01-444444444444','e4c6e6a1-8c22-4df0-9a01-555555555555','assigned')
ON CONFLICT(session_id,member_id,location_id) DO UPDATE SET status=excluded.status;
INSERT INTO count_assignments(session_id,member_id,location_id,status)
VALUES('e4c6e6a1-8c22-4df0-9a01-777777777777','e4c6e6a1-8c22-4df0-9a01-444444444444','e4c6e6a1-8c22-4df0-9a01-555555555555','assigned')
ON CONFLICT(session_id,member_id,location_id) DO UPDATE SET status=excluded.status;
DO $$ DECLARE v_global integer; v_specific integer;
BEGIN
 SELECT count(*) INTO v_global FROM count_assignments WHERE session_id='e4c6e6a1-8c22-4df0-9a01-777777777777' AND member_id='e4c6e6a1-8c22-4df0-9a01-444444444444' AND location_id IS NULL;
 SELECT count(*) INTO v_specific FROM count_assignments WHERE session_id='e4c6e6a1-8c22-4df0-9a01-777777777777' AND member_id='e4c6e6a1-8c22-4df0-9a01-444444444444' AND location_id='e4c6e6a1-8c22-4df0-9a01-555555555555';
 IF v_global<>1 OR v_specific<>1 THEN RAISE EXCEPTION 'ASSIGNMENT_UPSERT_NOT_IDEMPOTENT: %, %',v_global,v_specific; END IF;
END $$;
SELECT jsonb_build_object('global_scope_assignment_count',1,'specific_location_assignment_count',1,'idempotent_upsert','passed') AS verified;
ROLLBACK;
