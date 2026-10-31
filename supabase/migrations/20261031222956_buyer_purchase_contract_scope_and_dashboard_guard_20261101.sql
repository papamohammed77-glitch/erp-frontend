DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  -- PR item lookup: enforce same-company item ownership.
  v_def := pg_get_functiondef('public.purchase_create_request_atomic(uuid,text,date,text,text,jsonb,text)'::regprocedure);
  v_old := 'SELECT * INTO im FROM items WHERE item_code=btrim(x->>''item_code'');';
  v_new := 'SELECT * INTO im FROM items WHERE item_code=btrim(x->>''item_code'') AND company_id=p_company_id;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_ITEM_LOOKUP_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  -- Invoice item lookup: enforce same-company item ownership.
  v_def := pg_get_functiondef('public.purchase_create_invoice_atomic(uuid,uuid,uuid,uuid,date,text,text,jsonb,text)'::regprocedure);
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'INVOICE_ITEM_LOOKUP_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  -- The existing AFTER INSERT/UPDATE status trigger is the single history writer.
  v_def := pg_get_functiondef('public.purchase_submit_request_atomic(uuid,uuid,text)'::regprocedure);
  v_old := ' insert into purchase_status_history(id,company_id,document_type,document_id,from_status,to_status,changed_by,changed_at)
 values(gen_random_uuid(),p_company_id,''PurchaseRequest'',r.id,r.status,''Submitted'',p_actor,now());';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PR_HISTORY_INSERT_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,' -- trg_purchase_requests_status_history records this status transition exactly once.');
  EXECUTE v_def;

  -- Dashboard may be called by the trusted Edge service role, or by a same-company
  -- authenticated user with purchases/finance permission. Anonymous/public access is denied.
  v_def := pg_get_functiondef('public.purchase_get_dashboard(uuid)'::regprocedure);
  v_old := 'AS $function$
begin
  if not exists(select 1 from companies where id=p_company_id) then raise exception ''COMPANY_INVALID''; end if;';
  v_new := 'AS $function$
declare v_profile jsonb;
begin
  if p_company_id is null or not exists(select 1 from companies where id=p_company_id) then raise exception ''COMPANY_INVALID''; end if;
  if current_setting(''request.jwt.claim.role'',true) is distinct from ''service_role'' then
    if auth.uid() is null then raise exception ''PURCHASE_AUTH_REQUIRED''; end if;
    v_profile := public.get_my_effective_profile();
    if v_profile is null or (v_profile->>''company_id'')::uuid is distinct from p_company_id then
      raise exception ''PURCHASE_COMPANY_SCOPE_DENIED'';
    end if;
    if coalesce((v_profile->>''isOwner'')::boolean,false) is not true
       and not (coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''purchases''
                or coalesce(v_profile->''permissions'',''[]''::jsonb) ? ''finance'') then
      raise exception ''PURCHASE_PERMISSION_DENIED'';
    end if;
  end if;';
  IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'DASHBOARD_GUARD_PATTERN_NOT_FOUND'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;

REVOKE ALL ON FUNCTION public.purchase_get_dashboard(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purchase_get_dashboard(uuid) TO authenticated, service_role;
