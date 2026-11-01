DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_create_rfq_atomic(uuid,uuid,date,text,jsonb)'::regprocedure);
  v_old := 'code:=purchase_next_code(p_company_id,''rfq''); INSERT INTO purchase_rfqs';
  v_new := 'code:=purchase_next_code(p_company_id,''rfq''); PERFORM set_config(''rawaea.purchase_actor'',p_created_by,true); INSERT INTO purchase_rfqs';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'RFQ_CREATE_ACTOR_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_create_quotation_atomic(uuid,uuid,uuid,date,text,text,jsonb,text)'::regprocedure);
  v_old := '  code:=purchase_next_code(p_company_id,''quotation'');';
  v_new := '  code:=purchase_next_code(p_company_id,''quotation'');
  PERFORM set_config(''rawaea.purchase_actor'',p_created_by,true);';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'QUOTATION_CREATE_ACTOR_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.purchase_convert_quotation_to_po_atomic(uuid,uuid,text)'::regprocedure);
  v_old := 'INSERT INTO purchase_orders(company_id,po_code,po_date,supplier_id,supplier_name,total_amount,status,created_by) VALUES';
  v_new := 'PERFORM set_config(''rawaea.purchase_actor'',p_actor,true); INSERT INTO purchase_orders(company_id,po_code,po_date,supplier_id,supplier_name,total_amount,status,created_by) VALUES';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PO_CREATE_ACTOR_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;