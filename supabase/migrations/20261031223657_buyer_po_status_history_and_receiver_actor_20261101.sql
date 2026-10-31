DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_company_status_history()'::regprocedure);
  v_old := 'ELSIF TG_TABLE_NAME=''purchase_rfqs'' THEN actor:=NEW.created_by;';
  v_new := 'ELSIF TG_TABLE_NAME=''purchase_rfqs'' THEN actor:=NEW.created_by; ELSIF TG_TABLE_NAME=''purchase_orders'' THEN actor:=COALESCE(NULLIF(current_setting(''rawaea.purchase_actor'',true),''''),NEW.created_by);';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PO_HISTORY_ACTOR_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.receive_purchase_atomic(uuid,text,text,jsonb,uuid)'::regprocedure);
  v_old := '  UPDATE public.purchase_orders SET status=CASE WHEN all_received THEN ''Received'' ELSE ''Partially Received'' END,updated_at=now() WHERE id=po.id AND company_id=p_company_id;';
  v_new := '  PERFORM set_config(''rawaea.purchase_actor'',p_user_email,true);
  UPDATE public.purchase_orders SET status=CASE WHEN all_received THEN ''Received'' ELSE ''Partially Received'' END,updated_at=now() WHERE id=po.id AND company_id=p_company_id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PO_RECEIVE_STATUS_UPDATE_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;

DROP TRIGGER IF EXISTS trg_purchase_orders_status_history ON public.purchase_orders;
CREATE TRIGGER trg_purchase_orders_status_history
AFTER INSERT OR UPDATE ON public.purchase_orders
FOR EACH ROW EXECUTE FUNCTION public.purchase_company_status_history();
