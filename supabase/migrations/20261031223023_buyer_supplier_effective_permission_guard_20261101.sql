DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.save_supplier_atomic(uuid,uuid,text,jsonb,boolean,text)'::regprocedure);
  v_old := '  if not v_is_owner
     and not (
       jsonb_typeof(coalesce(v_user.permissions,''[]''::jsonb)) = ''array''
       and (
         v_user.permissions ? ''*''
         or v_user.permissions ? ''suppliers''
       )
     ) then
    raise exception ''لا تملك صلاحية تنفيذ هذه العملية'';
  end if;';
  v_new := '  if not v_is_owner
     and not (
       (
         jsonb_typeof(coalesce(v_user.permissions,''[]''::jsonb)) = ''array''
         and (
           v_user.permissions ? ''*''
           or v_user.permissions ? ''suppliers''
           or v_user.permissions ? ''purchases''
         )
       )
       or exists (
         select 1
         from public.roles r
         where r.id = v_user.role_id
           and r.company_id = p_company_id
           and jsonb_typeof(coalesce(r.permissions,''[]''::jsonb)) = ''array''
           and (r.permissions ? ''suppliers'' or r.permissions ? ''purchases'')
       )
       or exists (
         select 1 from public.role_permissions rp
         where rp.role_id = v_user.role_id
           and rp.permission_key in (''suppliers'',''purchases'')
       )
     ) then
    raise exception ''لا تملك صلاحية تنفيذ هذه العملية'';
  end if;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'SUPPLIER_PERMISSION_GUARD_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
