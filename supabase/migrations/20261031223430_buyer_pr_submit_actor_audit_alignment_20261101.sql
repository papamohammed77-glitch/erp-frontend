DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_submit_request_atomic(uuid,uuid,text)'::regprocedure);
  v_old := ' update purchase_requests set status=''Submitted'',updated_at=now() where id=r.id;';
  v_new := ' perform set_config(''rawaea.purchase_actor'',p_actor,true);
 update purchase_requests set status=''Submitted'',updated_at=now() where id=r.id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_SUBMIT_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_company_status_history()'::regprocedure);
  v_old := 'IF TG_TABLE_NAME=''purchase_requests'' THEN actor:=NEW.requested_by;';
  v_new := 'IF TG_TABLE_NAME=''purchase_requests'' THEN actor:=COALESCE(NULLIF(current_setting(''rawaea.purchase_actor'',true),''''),NEW.requested_by);';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_HISTORY_ACTOR_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;