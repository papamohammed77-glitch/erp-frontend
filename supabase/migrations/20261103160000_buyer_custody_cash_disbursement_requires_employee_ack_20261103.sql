-- Buyer custody: create advance records without cash/GL posting.
-- The employee acknowledgement is the only point that posts the cash disbursement.
CREATE OR REPLACE FUNCTION public.buyer_custody_acknowledge_advance_atomic(p_company_id uuid, p_advance_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%rowtype; v_employee public.users%rowtype; v_custody public.buyer_custodies%rowtype;
  v_advance public.buyer_custody_advances%rowtype; v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb;
BEGIN
  SELECT * INTO v_actor FROM public.users WHERE auth_id=auth.uid() AND company_id=p_company_id AND coalesce(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;
  SELECT a.* INTO v_advance FROM public.buyer_custody_advances a
   JOIN public.buyer_custodies c ON c.id=a.custody_id AND c.company_id=a.company_id
   WHERE a.id=p_advance_id AND a.company_id=p_company_id AND a.employee_id=v_actor.id AND a.advance_type='Additional'
   FOR UPDATE OF a;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_ADVANCE_ACKNOWLEDGE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_custody FROM public.buyer_custodies
   WHERE id=v_advance.custody_id AND company_id=p_company_id FOR UPDATE;
  IF NOT FOUND OR v_custody.status NOT IN ('Issued','UnderReview') THEN RAISE EXCEPTION 'CUSTODY_NOT_OPEN'; END IF;
  SELECT * INTO v_employee FROM public.users WHERE id=v_advance.employee_id AND company_id=p_company_id;
  SELECT id INTO v_cash_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='121' AND is_active;
  SELECT id INTO v_custody_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='127' AND is_active;
  IF v_cash_account IS NULL OR v_custody_account IS NULL THEN RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING'; END IF;
  IF (v_advance.cash_box_id IS NULL) <> (v_advance.journal_entry_id IS NULL) THEN RAISE EXCEPTION 'CUSTODY_ADVANCE_CASH_POSTING_INCONSISTENT'; END IF;
  IF v_advance.acknowledged_at IS NULL THEN
    UPDATE public.buyer_custody_advances SET acknowledged_at=now(),acknowledged_by=v_actor.id
     WHERE id=v_advance.id AND company_id=p_company_id RETURNING * INTO v_advance;
  ELSIF v_advance.cash_box_id IS NULL THEN
    RAISE EXCEPTION 'CUSTODY_ACKNOWLEDGED_WITHOUT_CASH_POSTING_REQUIRES_RECONCILIATION';
  END IF;
  IF v_advance.cash_box_id IS NULL AND v_advance.journal_entry_id IS NULL THEN
    IF v_advance.treasury_id IS NULL THEN RAISE EXCEPTION 'CUSTODY_TREASURY_REQUIRED_BEFORE_ACKNOWLEDGEMENT'; END IF;
    v_cash_result:=public.post_cash_payment_atomic(
      p_company_id,v_advance.id,v_advance.treasury_id,v_cash_account,v_custody_account,v_advance.amount,
      v_advance.advance_date,coalesce(nullif(btrim(v_advance.reference),''),v_custody.custody_code),
      'زيادة عهدة مشتريات بعد إقرار الموظف بالاستلام',v_actor.email,v_employee.name,
      'BuyerCustodyAdvance',v_custody.id,nullif(btrim(v_advance.notes),''),null
    );
    UPDATE public.buyer_custody_advances SET cash_box_id=nullif(v_cash_result->>'cash_box_id','')::uuid,
      journal_entry_id=nullif(v_cash_result->>'entry_id','')::uuid
     WHERE id=v_advance.id AND company_id=p_company_id RETURNING * INTO v_advance;
  END IF;
  RETURN to_jsonb(v_advance)||jsonb_build_object('cash_disbursement_status','PostedAfterAcknowledgement');
END;
$function$


CREATE OR REPLACE FUNCTION public.buyer_custody_acknowledge_atomic(p_company_id uuid, p_custody_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%rowtype; v_employee public.users%rowtype; v_custody public.buyer_custodies%rowtype;
  v_advance public.buyer_custody_advances%rowtype; v_cash_account uuid; v_custody_account uuid;
  v_cash_result jsonb; v_seen_initial boolean:=false;
BEGIN
  SELECT * INTO v_actor FROM public.users WHERE auth_id=auth.uid() AND company_id=p_company_id AND coalesce(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_AUTH_REQUIRED'; END IF;
  SELECT * INTO v_custody FROM public.buyer_custodies
   WHERE id=p_custody_id AND company_id=p_company_id AND employee_id=v_actor.id AND status='Issued' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CUSTODY_ACKNOWLEDGE_NOT_ALLOWED'; END IF;
  SELECT * INTO v_employee FROM public.users WHERE id=v_custody.employee_id AND company_id=p_company_id;
  SELECT id INTO v_cash_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='121' AND is_active;
  SELECT id INTO v_custody_account FROM public.chart_of_accounts WHERE company_id=p_company_id AND account_code='127' AND is_active;
  IF v_cash_account IS NULL OR v_custody_account IS NULL THEN RAISE EXCEPTION 'CUSTODY_ACCOUNT_MAPPING_MISSING'; END IF;

  FOR v_advance IN SELECT * FROM public.buyer_custody_advances
    WHERE custody_id=p_custody_id AND company_id=p_company_id AND advance_type='Initial' FOR UPDATE
  LOOP
    v_seen_initial:=true;
    IF (v_advance.cash_box_id IS NULL) <> (v_advance.journal_entry_id IS NULL) THEN RAISE EXCEPTION 'CUSTODY_ADVANCE_CASH_POSTING_INCONSISTENT'; END IF;
    IF v_advance.acknowledged_at IS NULL THEN
      UPDATE public.buyer_custody_advances SET acknowledged_at=now(),acknowledged_by=v_actor.id
      WHERE id=v_advance.id AND company_id=p_company_id RETURNING * INTO v_advance;
    ELSIF v_advance.cash_box_id IS NULL THEN
      RAISE EXCEPTION 'CUSTODY_ACKNOWLEDGED_WITHOUT_CASH_POSTING_REQUIRES_RECONCILIATION';
    END IF;
    IF v_advance.cash_box_id IS NULL AND v_advance.journal_entry_id IS NULL THEN
      IF v_advance.treasury_id IS NULL THEN RAISE EXCEPTION 'CUSTODY_TREASURY_REQUIRED_BEFORE_ACKNOWLEDGEMENT'; END IF;
      v_cash_result:=public.post_cash_payment_atomic(
        p_company_id,v_advance.id,v_advance.treasury_id,v_cash_account,v_custody_account,v_advance.amount,
        v_advance.advance_date,coalesce(nullif(btrim(v_advance.reference),''),v_custody.custody_code),
        'تسليم عهدة مشتريات بعد إقرار الموظف بالاستلام',v_actor.email,v_employee.name,
        'BuyerCustodyAdvance',v_custody.id,nullif(btrim(v_advance.notes),''),null
      );
      UPDATE public.buyer_custody_advances SET cash_box_id=nullif(v_cash_result->>'cash_box_id','')::uuid,
        journal_entry_id=nullif(v_cash_result->>'entry_id','')::uuid
      WHERE id=v_advance.id AND company_id=p_company_id;
    END IF;
  END LOOP;
  IF NOT v_seen_initial THEN RAISE EXCEPTION 'CUSTODY_INITIAL_ADVANCE_NOT_FOUND'; END IF;
  UPDATE public.buyer_custodies SET acknowledged_at=coalesce(acknowledged_at,now()),updated_at=now()
   WHERE id=p_custody_id AND company_id=p_company_id RETURNING * INTO v_custody;
  RETURN to_jsonb(v_custody)||jsonb_build_object('cash_disbursement_status','PostedAfterAcknowledgement');
END;
$function$


CREATE OR REPLACE FUNCTION public.buyer_custody_add_advance_atomic(p_company_id uuid, p_custody_id uuid, p_treasury_id uuid, p_amount numeric, p_advance_date date, p_reference text, p_notes text, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_advance public.buyer_custody_advances%rowtype;
 v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_operation_id),'') is null or p_treasury_id is null then raise exception 'CUSTODY_ADVANCE_INVALID'; end if;
  IF NOT EXISTS (SELECT 1 FROM public.treasury t WHERE t.id=p_treasury_id AND t.company_id=p_company_id AND coalesce(t.is_active,true)) THEN RAISE EXCEPTION 'CUSTODY_TREASURY_INVALID'; END IF;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_OPEN'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_ISSUE_FORBIDDEN'; end if;
 select * into v_advance from public.buyer_custody_advances where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_advance); end if;
 select id into v_cash_account from public.chart_of_accounts where company_id=p_company_id and account_code='121' and is_active;
 select id into v_custody_account from public.chart_of_accounts where company_id=p_company_id and account_code='127' and is_active;
 if v_cash_account is null or v_custody_account is null then raise exception 'CUSTODY_ACCOUNT_MAPPING_MISSING'; end if;
 insert into public.buyer_custody_advances(company_id,custody_id,employee_id,advance_type,amount,currency,advance_date,reference,notes,issued_by,operation_id,treasury_id)
 values(p_company_id,p_custody_id,v_custody.employee_id,'Additional',p_amount,v_custody.currency,coalesce(p_advance_date,current_date),
 nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_operation_id,p_treasury_id) returning * into v_advance;
 update public.buyer_custodies set issued_amount=issued_amount+p_amount,updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_advance)||jsonb_build_object('cash_disbursement_status','PendingEmployeeAcknowledgement');
end;
$function$


CREATE OR REPLACE FUNCTION public.buyer_custody_issue_atomic(p_company_id uuid, p_employee_id uuid, p_branch_id uuid, p_treasury_id uuid, p_purpose text, p_currency text, p_amount numeric, p_issued_date date, p_received_reference text, p_notes text, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_actor public.users%rowtype; v_employee public.users%rowtype; v_row public.buyer_custodies%rowtype;
 v_currency text; v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb; v_advance_id uuid;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_purpose),'') is null or nullif(btrim(p_operation_id),'') is null or p_treasury_id is null then raise exception 'CUSTODY_INVALID_ISSUE'; end if;
  IF NOT EXISTS (SELECT 1 FROM public.treasury t WHERE t.id=p_treasury_id AND t.company_id=p_company_id AND coalesce(t.is_active,true)) THEN RAISE EXCEPTION 'CUSTODY_TREASURY_INVALID'; END IF;
 select * into v_employee from public.users where id=p_employee_id and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_EMPLOYEE_INVALID'; end if;
 if v_employee.id=v_actor.id then raise exception 'CUSTODY_SELF_ISSUE_FORBIDDEN'; end if;
 if p_branch_id is not null and not exists(select 1 from public.branches b where b.id=p_branch_id and b.company_id=p_company_id) then raise exception 'CUSTODY_BRANCH_INVALID'; end if;
 select coalesce(nullif(upper(btrim(a.currency)),''),'EGP') into v_currency from public.app_settings a where a.company_id=p_company_id order by a.created_at,a.id limit 1;
 if v_currency is null then raise exception 'SYSTEM_CURRENCY_NOT_CONFIGURED'; end if;
 select * into v_row from public.buyer_custodies where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 select id into v_cash_account from public.chart_of_accounts where company_id=p_company_id and account_code='121' and is_active;
 select id into v_custody_account from public.chart_of_accounts where company_id=p_company_id and account_code='127' and is_active;
 if v_cash_account is null or v_custody_account is null then raise exception 'CUSTODY_ACCOUNT_MAPPING_MISSING'; end if;
 insert into public.buyer_custodies(company_id,custody_code,employee_id,branch_id,purpose,currency,issued_amount,issued_date,received_reference,received_at,issued_by,notes,operation_id)
 values(p_company_id,'BC-'||to_char(coalesce(p_issued_date,current_date),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
 p_employee_id,p_branch_id,btrim(p_purpose),v_currency,p_amount,coalesce(p_issued_date,current_date),nullif(btrim(p_received_reference),''),now(),v_actor.id,nullif(btrim(p_notes),''),p_operation_id)
 returning * into v_row;
 insert into public.buyer_custody_advances(company_id,custody_id,employee_id,advance_type,amount,currency,advance_date,reference,notes,issued_by,operation_id,treasury_id)
 values(p_company_id,v_row.id,p_employee_id,'Initial',p_amount,v_currency,coalesce(p_issued_date,current_date),nullif(btrim(p_received_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_operation_id||':INITIAL',p_treasury_id)
 returning id into v_advance_id;
 return to_jsonb(v_row)||jsonb_build_object('cash_disbursement_status','PendingEmployeeAcknowledgement','advance_id',v_advance_id);
end;
$function$

