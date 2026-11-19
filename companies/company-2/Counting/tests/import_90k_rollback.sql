-- 90,000-row CountFlow import pipeline regression.
-- The synthetic project, Auth user, import batch, staged rows and products are
-- created in one transaction and rolled back. Never remove the final ROLLBACK.
BEGIN;
SET LOCAL statement_timeout='180s';
CREATE TEMP TABLE countflow_90k_result(result jsonb) ON COMMIT DROP;
DO $countflow_90k$
DECLARE
  v_supervisor uuid := gen_random_uuid(); v_project uuid; v_batch uuid;
  v_rows jsonb; v_chunk_result jsonb; v_commit jsonb; v_offset integer;
  v_staged bigint; v_products bigint;
BEGIN
  INSERT INTO auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,is_sso_user,is_anonymous)
  VALUES(v_supervisor,'authenticated','authenticated','qa-90k-'||v_supervisor||'@countflow.invalid','',now(),
    '{"provider":"email","providers":["email"]}','{"display_name":"QA 90K"}',now(),now(),false,false);
  PERFORM set_config('request.jwt.claim.sub',v_supervisor::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_supervisor,'role','authenticated','aud','authenticated')::text,true);
  INSERT INTO public.count_projects(name,code,created_by)
  VALUES('QA 90K Rollback','QA90K-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),v_supervisor)
  RETURNING id INTO v_project;
  v_batch := public.count_create_import_batch(v_project,NULL,'qa-90000-products.csv','csv',encode(digest('countflow-90k-qa','sha256'),'hex'));
  FOR v_offset IN 0..89000 BY 1000 LOOP
    SELECT jsonb_agg(jsonb_build_object(
      '_row_number',v_offset+g+1,
      'sku','QA90K-'||lpad((v_offset+g+1)::text,6,'0'),
      'barcode','QA90KB-'||lpad((v_offset+g+1)::text,6,'0'),
      'name','QA 90K Product '||(v_offset+g+1),
      'base_unit','each','units','[]'::jsonb
    )) INTO v_rows FROM generate_series(0,999) g;
    v_chunk_result := public.count_stage_import_rows(v_batch,v_rows,v_offset);
  END LOOP;
  v_commit := public.count_commit_import_batch(v_batch);
  SELECT count(*) INTO v_staged FROM public.count_import_rows WHERE batch_id=v_batch;
  SELECT count(*) INTO v_products FROM public.count_products WHERE project_id=v_project;
  IF v_commit->>'status'<>'committed' OR (v_commit->>'accepted_rows')::bigint<>90000 OR v_staged<>90000 OR v_products<>90000
  THEN RAISE EXCEPTION 'QA_90K_IMPORT_ASSERTION_FAILED: %, staged %, products %',v_commit,v_staged,v_products; END IF;
  INSERT INTO pg_temp.countflow_90k_result(result)
  VALUES(jsonb_build_object('status','PASS','rows_submitted',90000,'rows_staged',v_staged,
    'rows_accepted',(v_commit->>'accepted_rows')::bigint,'products_committed',v_products,
    'batch_chunks',90,'rollback_only',true));
END
$countflow_90k$;
SELECT result FROM pg_temp.countflow_90k_result;
ROLLBACK;
