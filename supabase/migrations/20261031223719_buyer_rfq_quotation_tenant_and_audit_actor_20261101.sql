DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_create_quotation_atomic(uuid,uuid,uuid,date,text,text,jsonb,text)'::regprocedure);
  v_old := 'SELECT * INTO im FROM items WHERE item_code=btrim(x->>''item_code'');';
  v_new := 'SELECT * INTO im FROM items WHERE item_code=btrim(x->>''item_code'') AND company_id=p_company_id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'QUOTATION_ITEM_LOOKUP_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_company_status_history()'::regprocedure);
  v_old := 'ELSIF TG_TABLE_NAME=''purchase_rfqs'' THEN actor:=NEW.created_by;';
  v_new := 'ELSIF TG_TABLE_NAME=''purchase_rfqs'' THEN actor:=COALESCE(NULLIF(current_setting(''rawaea.purchase_actor'',true),''''),NEW.created_by);';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'RFQ_HISTORY_ACTOR_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := 'ELSIF TG_TABLE_NAME=''purchase_quotations'' THEN actor:=NEW.created_by;';
  v_new := 'ELSIF TG_TABLE_NAME=''purchase_quotations'' THEN actor:=COALESCE(NULLIF(current_setting(''rawaea.purchase_actor'',true),''''),NEW.created_by);';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'QUOTATION_HISTORY_ACTOR_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_send_rfq_atomic(uuid,uuid,text)'::regprocedure);
  v_old := 'UPDATE purchase_rfqs SET status=''Sent'' WHERE id=p_rfq_id;';
  v_new := 'PERFORM set_config(''rawaea.purchase_actor'',p_actor,true); UPDATE purchase_rfqs SET status=''Sent'' WHERE id=p_rfq_id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'RFQ_SEND_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_accept_quotation_atomic(uuid,uuid,text)'::regprocedure);
  v_old := 'BEGIN UPDATE purchase_quotations SET status=''Accepted'',accepted_by=p_actor,accepted_at=now() WHERE id=p_quotation_id AND company_id=p_company_id AND status=''Submitted'';';
  v_new := 'BEGIN PERFORM set_config(''rawaea.purchase_actor'',p_actor,true); UPDATE purchase_quotations SET status=''Accepted'',accepted_by=p_actor,accepted_at=now() WHERE id=p_quotation_id AND company_id=p_company_id AND status=''Submitted'';';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'QUOTATION_ACCEPT_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_convert_quotation_to_po_atomic(uuid,uuid,text)'::regprocedure);
  v_old := 'UPDATE purchase_quotations SET status=''Converted'',accepted_by=COALESCE(accepted_by,p_actor),accepted_at=COALESCE(accepted_at,now()) WHERE id=q.id;';
  v_new := 'PERFORM set_config(''rawaea.purchase_actor'',p_actor,true); UPDATE purchase_quotations SET status=''Converted'',accepted_by=COALESCE(accepted_by,p_actor),accepted_at=COALESCE(accepted_at,now()) WHERE id=q.id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'QUOTATION_CONVERT_UPDATE_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
