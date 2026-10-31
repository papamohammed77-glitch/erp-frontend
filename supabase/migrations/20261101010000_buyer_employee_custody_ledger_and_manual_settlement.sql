-- Dedicated employee buyer-custody ledger. No treasury, cash_box, HR salary advance or GL posting.
create table public.buyer_custodies (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 custody_code text not null,
 employee_id uuid not null references public.users(id),
 branch_id uuid references public.branches(id),
 purpose text not null,
 currency text not null default 'SAR',
 issued_amount numeric(14,2) not null check (issued_amount>0),
 issued_date date not null default current_date,
 received_reference text,
 received_at timestamptz not null default now(),
 issued_by uuid not null references public.users(id),
 acknowledged_at timestamptz,
 status text not null default 'Issued' check(status in ('Issued','UnderReview','Settled','Closed')),
 notes text,
 operation_id text not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(company_id,custody_code),
 unique(company_id,operation_id)
);
create table public.buyer_custody_expenses (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 custody_id uuid not null references public.buyer_custodies(id) on delete cascade,
 employee_id uuid not null references public.users(id),
 expense_date date not null default current_date,
 supplier_name text,
 invoice_number text,
 description text not null,
 amount numeric(14,2) not null check(amount>0),
 currency text not null default 'SAR',
 document_name text not null,
 document_path text not null,
 mime_type text,
 status text not null default 'Submitted' check(status in ('Submitted','Approved','Rejected')),
 submitted_at timestamptz not null default now(),
 reviewed_by uuid references public.users(id),
 reviewed_at timestamptz,
 review_note text,
 operation_id text not null,
 created_at timestamptz not null default now(),
 unique(company_id,operation_id)
);
create table public.buyer_custody_settlements (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 custody_id uuid not null unique references public.buyer_custodies(id) on delete restrict,
 approved_expense_total numeric(14,2) not null check(approved_expense_total>=0),
 cash_returned numeric(14,2) not null check(cash_returned>=0),
 amount_due_employee numeric(14,2) not null check(amount_due_employee>=0),
 balance_due_company numeric(14,2) not null check(balance_due_company>=0),
 finance_reference text,
 notes text,
 recorded_by uuid not null references public.users(id),
 recorded_at timestamptz not null default now()
);
create index buyer_custodies_company_employee_date_idx on public.buyer_custodies(company_id,employee_id,issued_date desc);
create index buyer_custody_expenses_company_custody_date_idx on public.buyer_custody_expenses(company_id,custody_id,expense_date desc);
create index buyer_custody_settlements_company_idx on public.buyer_custody_settlements(company_id,recorded_at desc);

alter table public.buyer_custodies enable row level security;
alter table public.buyer_custody_expenses enable row level security;
alter table public.buyer_custody_settlements enable row level security;
create policy buyer_custodies_read_scope on public.buyer_custodies for select to authenticated using (
 company_id=app_private.current_user_company_id() and (
  employee_id=(select u.id from public.users u where u.auth_id=auth.uid() limit 1)
  or app_private.current_user_has_effective_permission('finance')
 )
);
create policy buyer_custody_expenses_read_scope on public.buyer_custody_expenses for select to authenticated using (
 company_id=app_private.current_user_company_id() and (
  employee_id=(select u.id from public.users u where u.auth_id=auth.uid() limit 1)
  or app_private.current_user_has_effective_permission('finance')
 )
);
create policy buyer_custody_settlements_read_scope on public.buyer_custody_settlements for select to authenticated using (
 company_id=app_private.current_user_company_id() and exists (
  select 1 from public.buyer_custodies c where c.id=buyer_custody_settlements.custody_id
   and c.company_id=buyer_custody_settlements.company_id and (
    c.employee_id=(select u.id from public.users u where u.auth_id=auth.uid() limit 1)
    or app_private.current_user_has_effective_permission('finance')
   )
 )
);
revoke all on public.buyer_custodies,public.buyer_custody_expenses,public.buyer_custody_settlements from anon,authenticated;
grant select on public.buyer_custodies,public.buyer_custody_expenses,public.buyer_custody_settlements to authenticated;

create or replace function public.buyer_custody_issue_atomic(
 p_company_id uuid,p_employee_id uuid,p_branch_id uuid,p_purpose text,p_currency text,
 p_amount numeric,p_issued_date date,p_received_reference text,p_notes text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_employee public.users%rowtype; v_row public.buyer_custodies%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('finance') then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_purpose),'') is null or nullif(btrim(p_operation_id),'') is null then raise exception 'CUSTODY_INVALID_ISSUE'; end if;
 select * into v_employee from public.users where id=p_employee_id and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_EMPLOYEE_INVALID'; end if;
 if p_branch_id is not null and not exists(select 1 from public.branches b where b.id=p_branch_id and b.company_id=p_company_id) then raise exception 'CUSTODY_BRANCH_INVALID'; end if;
 select * into v_row from public.buyer_custodies where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 insert into public.buyer_custodies(company_id,custody_code,employee_id,branch_id,purpose,currency,issued_amount,issued_date,received_reference,received_at,issued_by,notes,operation_id)
 values(p_company_id,'BC-'||to_char(coalesce(p_issued_date,current_date),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
 p_employee_id,p_branch_id,btrim(p_purpose),coalesce(nullif(upper(btrim(p_currency)),''),'SAR'),p_amount,
 coalesce(p_issued_date,current_date),nullif(btrim(p_received_reference),''),now(),v_actor.id,nullif(btrim(p_notes),''),p_operation_id)
 returning * into v_row;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_acknowledge_atomic(p_company_id uuid,p_custody_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_row public.buyer_custodies%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 update public.buyer_custodies set acknowledged_at=coalesce(acknowledged_at,now()),updated_at=now()
 where id=p_custody_id and company_id=p_company_id and employee_id=v_actor.id and status='Issued' returning * into v_row;
 if not found then raise exception 'CUSTODY_ACKNOWLEDGE_NOT_ALLOWED'; end if;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_submit_expense_atomic(
 p_company_id uuid,p_custody_id uuid,p_expense_date date,p_supplier_name text,p_invoice_number text,
 p_description text,p_amount numeric,p_currency text,p_document_name text,p_document_path text,
 p_mime_type text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_row public.buyer_custody_expenses%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id and employee_id=v_actor.id;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_OPEN'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_description),'') is null or nullif(btrim(p_document_name),'') is null or nullif(btrim(p_document_path),'') is null or nullif(btrim(p_operation_id),'') is null then raise exception 'CUSTODY_EXPENSE_INVALID'; end if;
 if p_document_path not like p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
  or not exists(select 1 from storage.objects o where o.bucket_id='employee-documents' and o.name=p_document_path) then raise exception 'CUSTODY_DOCUMENT_NOT_FOUND_OR_FORBIDDEN'; end if;
 select * into v_row from public.buyer_custody_expenses where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 insert into public.buyer_custody_expenses(company_id,custody_id,employee_id,expense_date,supplier_name,invoice_number,description,amount,currency,document_name,document_path,mime_type,operation_id)
 values(p_company_id,p_custody_id,v_actor.id,coalesce(p_expense_date,current_date),nullif(btrim(p_supplier_name),''),nullif(btrim(p_invoice_number),''),btrim(p_description),p_amount,
 coalesce(nullif(upper(btrim(p_currency)),''),v_custody.currency),btrim(p_document_name),btrim(p_document_path),nullif(btrim(p_mime_type),''),p_operation_id)
 returning * into v_row;
 update public.buyer_custodies set status='UnderReview',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_review_expense_atomic(p_company_id uuid,p_expense_id uuid,p_decision text,p_review_note text)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_row public.buyer_custody_expenses%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('finance') then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_decision not in ('Approved','Rejected') then raise exception 'CUSTODY_REVIEW_DECISION_INVALID'; end if;
 update public.buyer_custody_expenses set status=p_decision,reviewed_by=v_actor.id,reviewed_at=now(),review_note=nullif(btrim(p_review_note),'')
 where id=p_expense_id and company_id=p_company_id and status='Submitted' returning * into v_row;
 if not found then raise exception 'CUSTODY_EXPENSE_NOT_PENDING'; end if;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_settle_atomic(p_company_id uuid,p_custody_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_approved numeric(14,2); v_pending integer; v_settlement public.buyer_custody_settlements%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('finance') then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 if coalesce(p_cash_returned,0)<0 or coalesce(p_cash_returned,0)>greatest(v_custody.issued_amount-v_approved,0) then raise exception 'CUSTODY_CASH_RETURN_INVALID'; end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by)
 values(p_company_id,p_custody_id,v_approved,coalesce(p_cash_returned,0),greatest(v_approved-v_custody.issued_amount,0),
 greatest(v_custody.issued_amount-v_approved-coalesce(p_cash_returned,0),0),nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;$fn$;

revoke all on function public.buyer_custody_issue_atomic(uuid,uuid,uuid,text,text,numeric,date,text,text,text) from public,anon;
revoke all on function public.buyer_custody_acknowledge_atomic(uuid,uuid) from public,anon;
revoke all on function public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,text) from public,anon;
revoke all on function public.buyer_custody_review_expense_atomic(uuid,uuid,text,text) from public,anon;
revoke all on function public.buyer_custody_settle_atomic(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.buyer_custody_issue_atomic(uuid,uuid,uuid,text,text,numeric,date,text,text,text) to authenticated;
grant execute on function public.buyer_custody_acknowledge_atomic(uuid,uuid) to authenticated;
grant execute on function public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,text) to authenticated;
grant execute on function public.buyer_custody_review_expense_atomic(uuid,uuid,text,text) to authenticated;
grant execute on function public.buyer_custody_settle_atomic(uuid,uuid,numeric,text,text) to authenticated;

drop policy if exists buyer_custody_docs_insert on storage.objects;
create policy buyer_custody_docs_insert on storage.objects for insert to authenticated with check (
 bucket_id='employee-documents' and (storage.foldername(name))[3]='buyer-custody'
 and exists(select 1 from public.users u join public.buyer_custodies c on c.id=nullif((storage.foldername(name))[4],'')::uuid and c.company_id=u.company_id and c.employee_id=u.id
  where u.auth_id=auth.uid() and u.company_id=nullif((storage.foldername(name))[1],'')::uuid and u.id::text=(storage.foldername(name))[2] and coalesce(u.status,'Active')='Active')
);
drop policy if exists buyer_custody_docs_select on storage.objects;
create policy buyer_custody_docs_select on storage.objects for select to authenticated using (
 bucket_id='employee-documents' and (storage.foldername(name))[3]='buyer-custody'
 and exists(select 1 from public.users u join public.buyer_custodies c on c.id=nullif((storage.foldername(name))[4],'')::uuid and c.company_id=u.company_id and c.employee_id::text=(storage.foldername(name))[2]
  where u.auth_id=auth.uid() and u.company_id=nullif((storage.foldername(name))[1],'')::uuid and coalesce(u.status,'Active')='Active'
   and (u.id::text=(storage.foldername(name))[2] or app_private.current_user_has_effective_permission('finance')))
);
