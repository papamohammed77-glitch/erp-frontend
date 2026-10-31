DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.purchase_get_dashboard(uuid)'::regprocedure);
  v_old := 'not (coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''purchases''
                or coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''finance'')';
  v_new := 'not (coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''*''
                or coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''purchases''
                or coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''finance'')';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'DASHBOARD_WILDCARD_PERMISSION_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.save_supplier_atomic(uuid,uuid,text,jsonb,boolean,text)'::regprocedure);
  v_old := '(r.permissions ? ''suppliers'' or r.permissions ? ''purchases'')';
  v_new := '(r.permissions ? ''*'' or r.permissions ? ''suppliers'' or r.permissions ? ''purchases'')';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'SUPPLIER_ROLE_WILDCARD_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  v_old := 'rp.permission_key in (''suppliers'',''purchases'')';
  v_new := 'rp.permission_key in (''*'',''suppliers'',''purchases'')';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'SUPPLIER_ROLE_PERMISSION_WILDCARD_ANCHOR_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
