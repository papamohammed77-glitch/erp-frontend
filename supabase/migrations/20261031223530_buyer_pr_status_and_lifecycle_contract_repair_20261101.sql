ALTER TABLE public.purchase_requests
  DROP CONSTRAINT purchase_requests_status_check;
ALTER TABLE public.purchase_requests
  ADD CONSTRAINT purchase_requests_status_check
  CHECK (status = ANY (ARRAY['Draft'::text,'Submitted'::text,'PendingApproval'::text,'Approved'::text,'Rejected'::text,'Converted'::text,'Cancelled'::text]));

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_approve_request_atomic(uuid,uuid,text)'::regprocedure);
  v_old := 'IF NOT FOUND OR r.status NOT IN(''Draft'',''PendingApproval'') THEN';
  v_new := 'IF NOT FOUND OR r.status NOT IN(''Draft'',''PendingApproval'',''Submitted'') THEN';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_APPROVE_STATUS_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := 'UPDATE purchase_requests SET status=''Approved'',approved_by=p_actor,approved_at=now() WHERE id=r.id;';
  v_new := 'PERFORM set_config(''rawaea.purchase_actor'',p_actor,true); UPDATE purchase_requests SET status=''Approved'',approved_by=p_actor,approved_at=now() WHERE id=r.id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_APPROVE_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_reject_request_atomic(uuid,uuid,text,text)'::regprocedure);
  v_old := ' update purchase_requests set status=''Rejected''';
  v_new := ' perform set_config(''rawaea.purchase_actor'',p_actor,true);
 update purchase_requests set status=''Rejected''';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_REJECT_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := ' insert into purchase_status_history(id,company_id,document_type,document_id,from_status,to_status,changed_by,changed_at)
 values(gen_random_uuid(),p_company_id,''PurchaseRequest'',r.id,r.status,''Rejected'',p_actor,now());';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_REJECT_HISTORY_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,' -- trg_purchase_requests_status_history records this status transition exactly once.');
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_create_rfq_atomic(uuid,uuid,date,text,jsonb)'::regprocedure);
  v_old := 'UPDATE purchase_requests SET status=''Converted'' WHERE id=r.id;';
  v_new := 'PERFORM set_config(''rawaea.purchase_actor'',p_created_by,true); UPDATE purchase_requests SET status=''Converted'' WHERE id=r.id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_CONVERT_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
