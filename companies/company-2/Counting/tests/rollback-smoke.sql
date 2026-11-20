-- CountFlow rollback-only integration smoke test.
-- Run with a privileged SQL connection on rawaea-staging.
-- All fixtures (including synthetic auth.users) are rolled back. Never remove ROLLBACK.
BEGIN;

CREATE TEMP TABLE countflow_qa_result(result jsonb) ON COMMIT DROP;

DO $countflow_qa$
DECLARE
  v_supervisor uuid := gen_random_uuid();
  v_counter uuid := gen_random_uuid();
  v_project uuid;
  v_session uuid;
  v_product uuid;
  v_product_sku text;
  v_product_barcode text;
  v_batch uuid;
  v_stage jsonb;
  v_commit jsonb;
  v_loc1 uuid;
  v_loc2 uuid;
  v_member uuid;
  v_device text := 'qa-device-' || gen_random_uuid()::text;
  v_event uuid := gen_random_uuid();
  v_entry public.count_entries;
  v_retry public.count_entries;
  v_run uuid;
  v_task uuid;
  v_result jsonb;
BEGIN
  INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,is_sso_user,is_anonymous)
  VALUES
    (v_supervisor,'authenticated','authenticated','qa-supervisor-'||v_supervisor||'@countflow.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"QA Supervisor"}',now(),now(),false,false),
    (v_counter,'authenticated','authenticated','qa-counter-'||v_counter||'@countflow.invalid','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"QA Counter"}',now(),now(),false,false);

  PERFORM set_config('request.jwt.claim.sub',v_supervisor::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_supervisor,'role','authenticated','aud','authenticated')::text,true);

  INSERT INTO public.count_projects(name,code,created_by)
  VALUES('QA Rollback Project','QA-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),v_supervisor)
  RETURNING id INTO v_project;

  SELECT id INTO v_member FROM public.count_members WHERE project_id=v_project AND user_id=v_supervisor;
  IF v_member IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'QA_FAIL_OWNER_BOOTSTRAP';
  END IF;

  INSERT INTO public.count_members(project_id,user_id,display_name,username,role,status)
  VALUES(v_project,v_counter,'QA Counter','qa-counter-'||substr(v_counter::text,1,8),'counter','active')
  RETURNING id INTO v_member;

  INSERT INTO public.count_locations(project_id,location_type,code,name)
  VALUES(v_project,'shelf','QA-S1','QA Shelf 1') RETURNING id INTO v_loc1;
  INSERT INTO public.count_locations(project_id,location_type,code,name)
  VALUES(v_project,'shelf','QA-S2','QA Shelf 2') RETURNING id INTO v_loc2;

  INSERT INTO public.count_products(project_id,sku,barcode,name,base_unit,units,is_active)
  VALUES(v_project,'QA-SKU-'||substr(replace(gen_random_uuid()::text,'-',''),1,10),
    'QA'||substr(replace(gen_random_uuid()::text,'-',''),1,10),
    'QA Test Product','قطعة','[]'::jsonb,true)
  RETURNING id INTO v_product;

  INSERT INTO public.count_sessions(project_id,name,status,created_by)
  VALUES(v_project,'QA Rollback Session','planned',v_supervisor) RETURNING id INTO v_session;

  -- Direct DML may not jump from planned to completed.
  BEGIN
    UPDATE public.count_sessions SET status='completed' WHERE id=v_session;
    RAISE EXCEPTION 'QA_FAIL_DIRECT_SESSION_JUMP_ALLOWED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='QA_FAIL_DIRECT_SESSION_JUMP_ALLOWED' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE 'INVALID_SESSION_STATUS_TRANSITION:%' THEN RAISE; END IF;
  END;

  -- Only the authorized transition RPC starts, pauses, and resumes this session.
  PERFORM public.count_transition_session(v_session,'active');
  BEGIN
    UPDATE public.count_sessions SET status='completed' WHERE id=v_session;
    RAISE EXCEPTION 'QA_FAIL_DIRECT_SESSION_CLOSE_BEFORE_APPROVAL';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='QA_FAIL_DIRECT_SESSION_CLOSE_BEFORE_APPROVAL' THEN RAISE; END IF;
    IF SQLERRM<>'SESSION_CLOSE_REQUIRES_LATEST_APPROVED_RECONCILIATION' THEN RAISE; END IF;
  END;
  PERFORM public.count_transition_session(v_session,'paused');
  PERFORM public.count_transition_session(v_session,'active');

  SELECT sku,barcode INTO v_product_sku,v_product_barcode
  FROM public.count_products WHERE id=v_product;

  v_batch := public.count_create_import_batch(
    v_project,v_session,'qa-baseline.csv','csv','qa-baseline-checksum'
  );
  v_stage := public.count_stage_import_rows(v_batch,jsonb_build_array(jsonb_build_object(
    'sku',v_product_sku,'barcode',v_product_barcode,'name','QA Test Product',
    'base_unit','قطعة','expected_qty','10','location_code','QA-S1'
  )),0);
  IF (v_stage->>'accepted_rows')::int<>1 OR (v_stage->>'rejected_rows')::int<>0
  THEN RAISE EXCEPTION 'QA_FAIL_IMPORT_STAGE_BASELINE:%',v_stage; END IF;
  v_commit := public.count_commit_import_batch(v_batch);
  IF (v_commit->>'accepted_rows')::int<>1 OR (v_commit->>'expected_balance_rows')::int<>1
  THEN RAISE EXCEPTION 'QA_FAIL_IMPORT_COMMIT_BASELINE:%',v_commit; END IF;

  INSERT INTO public.count_devices(project_id,member_id,device_id,device_label,platform,app_version,status)
  VALUES(v_project,v_member,v_device,'QA Device','test','qa','active');

  INSERT INTO public.count_assignments(session_id,member_id,location_id,status)
  VALUES(v_session,v_member,v_loc1,'assigned');

  PERFORM set_config('request.jwt.claim.sub',v_counter::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_counter,'role','authenticated','aud','authenticated')::text,true);

  v_entry := public.count_record_entry(v_session,v_product,v_loc1,8,'قطعة',v_event,'QA-BARCODE',v_device,'first count');
  v_retry := public.count_record_entry(v_session,v_product,v_loc1,8,'قطعة',v_event,'QA-BARCODE',v_device,'retry');
  IF v_entry.id IS DISTINCT FROM v_retry.id THEN RAISE EXCEPTION 'QA_FAIL_IDEMPOTENT_RETRY'; END IF;

  BEGIN
    PERFORM public.count_record_entry(v_session,v_product,v_loc2,3,'قطعة',gen_random_uuid(),'QA-BARCODE',v_device,'wrong location');
    RAISE EXCEPTION 'QA_FAIL_ASSIGNMENT_NOT_ENFORCED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='QA_FAIL_ASSIGNMENT_NOT_ENFORCED' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%LOCATION_NOT_ASSIGNED%' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub',v_supervisor::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_supervisor,'role','authenticated','aud','authenticated')::text,true);

  v_run := public.count_reconcile_session(v_session);
  PERFORM public.count_generate_recount_tasks(v_run,v_member,0);
  SELECT id INTO v_task FROM public.count_recount_tasks WHERE session_id=v_session LIMIT 1;
  IF v_task IS NULL THEN RAISE EXCEPTION 'QA_FAIL_RECOUNT_TASK_NOT_CREATED'; END IF;

  PERFORM set_config('request.jwt.claim.sub',v_counter::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_counter,'role','authenticated','aud','authenticated')::text,true);
  PERFORM public.count_record_recount_entry(v_task,9,'قطعة',gen_random_uuid(),'QA-BARCODE',v_device,'second count');

  PERFORM set_config('request.jwt.claim.sub',v_supervisor::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_supervisor,'role','authenticated','aud','authenticated')::text,true);

  v_result := public.count_review_recount_task(v_task,'accept','QA accepted');
  IF v_result->>'status'<>'reviewed' THEN RAISE EXCEPTION 'QA_FAIL_RECOUNT_REVIEW'; END IF;

  v_run := public.count_reconcile_session(v_session);
  v_result := public.count_approve_reconciliation(v_run);
  IF v_result->>'status'<>'approved' THEN RAISE EXCEPTION 'QA_FAIL_RECONCILIATION_APPROVAL'; END IF;
  v_result := public.count_transition_session(v_session,'completed');
  IF v_result->>'status'<>'completed' THEN RAISE EXCEPTION 'QA_FAIL_SESSION_CLOSE_AFTER_APPROVAL'; END IF;

  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND (left(p.proname,6) = 'count_' OR p.proname='countflow_broadcast_changes')
      AND has_function_privilege('anon',p.oid,'EXECUTE')
  ) THEN RAISE EXCEPTION 'QA_FAIL_ANON_FUNCTION_EXECUTE'; END IF;

  IF has_table_privilege('authenticated','public.count_import_rows','INSERT')
     OR has_table_privilege('authenticated','public.count_import_rows','UPDATE')
     OR has_table_privilege('authenticated','public.count_import_rows','DELETE')
  THEN RAISE EXCEPTION 'QA_FAIL_IMPORT_ROW_DIRECT_DML_PRIVILEGE'; END IF;

  IF has_table_privilege('authenticated','public.count_audit_log','UPDATE')
     OR has_table_privilege('authenticated','public.count_audit_log','DELETE')
     OR has_table_privilege('authenticated','public.count_reconciliation_lines','UPDATE')
     OR has_table_privilege('authenticated','public.count_reconciliation_lines','DELETE')
     OR has_table_privilege('authenticated','public.count_entries','UPDATE')
     OR has_table_privilege('authenticated','public.count_entries','DELETE')
  THEN RAISE EXCEPTION 'QA_FAIL_IMMUTABLE_LEDGER_ACL'; END IF;

  INSERT INTO pg_temp.countflow_qa_result(result)
  VALUES(jsonb_build_object(
    'status','PASS',
    'owner_bootstrap',true,
    'entry_idempotency',true,
    'assignment_scope_rejection',true,
    'recount_creation_and_entry',true,
    'recount_review',true,
    'reconciliation_approval_and_freeze',true,
    'anon_rpc_denied',true,
    'append_only_ledgers',true,
    'project_id',v_project,
    'session_id',v_session,
    'entry_id',v_entry.id,
    'recount_task_id',v_task,
    'approved_run_id',v_run
  ));
END
$countflow_qa$;

SELECT result FROM pg_temp.countflow_qa_result;
ROLLBACK;
