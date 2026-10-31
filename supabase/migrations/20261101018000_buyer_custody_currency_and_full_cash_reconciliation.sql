create or replace function public.buyer_custody_submit_expense_atomic(
 p_company_id uuid,p_custody_id uuid,p_expense_date date,p_supplier_name text,p_invoice_number text,
 p_description text,p_amount numeric,p_currency text,p_document_name text,p_document_path text,
 p_mime_type text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_row public.buyer_custody_expenses%rowtype; v_currency text;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id and employee_id=v_actor.id;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_OPEN'; end if;
 v_currency:=coalesce(nullif(upper(btrim(p_currency)),''),upper(v_custody.currency));
 if v_currency<>upper(v_custody.currency) then raise exception 'CUSTODY_CURRENCY_MISMATCH'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_description),'') is null or nullif(btrim(p_document_name),'') is null or nullif(btrim(p_document_path),'') is null or nullif(btrim(p_operation_id),'') is null then raise exception 'CUSTODY_EXPENSE_INVALID'; end if;
 if p_document_path not like p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
  or not exists(select 1 from storage.objects o where o.bucket_id='employee-documents' and o.name=p_document_path) then raise exception 'CUSTODY_DOCUMENT_NOT_FOUND_OR_FORBIDDEN'; end if;
 select * into v_row from public.buyer_custody_expenses where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 insert into public.buyer_custody_expenses(company_id,custody_id,employee_id,expense_date,supplier_name,invoice_number,description,amount,currency,document_name,document_path,mime_type,operation_id)
 values(p_company_id,p_custody_id,v_actor.id,coalesce(p_expense_date,current_date),nullif(btrim(p_supplier_name),''),nullif(btrim(p_invoice_number),''),btrim(p_description),p_amount,
 v_currency,btrim(p_document_name),btrim(p_document_path),nullif(btrim(p_mime_type),''),p_operation_id)
 returning * into v_row;
 update public.buyer_custodies set status='UnderReview',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_settle_atomic(p_company_id uuid,p_custody_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_approved numeric(14,2); v_pending integer; v_expected_return numeric(14,2); v_settlement public.buyer_custody_settlements%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; end if;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 v_expected_return:=greatest(v_custody.issued_amount-v_approved,0);
 if coalesce(p_cash_returned,0)<>v_expected_return then raise exception 'CUSTODY_CASH_RETURN_MUST_RECONCILE'; end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by)
 values(p_company_id,p_custody_id,v_approved,v_expected_return,greatest(v_approved-v_custody.issued_amount,0),0,
 nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;$fn$;
