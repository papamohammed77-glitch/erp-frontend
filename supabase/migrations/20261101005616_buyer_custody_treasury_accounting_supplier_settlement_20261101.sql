
insert into public.chart_of_accounts(company_id,account_code,account_name,account_type,parent_account_id,normal_balance,is_active,notes)
select c.id,'127','عهد الموظفين','asset',p.id,'debit',true,'حساب عهد الموظفين والمشتريات النقدية'
from public.companies c
join public.chart_of_accounts p on p.company_id=c.id and p.account_code='12'
where not exists(select 1 from public.chart_of_accounts x where x.company_id=c.id and x.account_code='127');

alter table public.buyer_custody_advances
 add column if not exists treasury_id uuid references public.treasury(id),
 add column if not exists cash_box_id uuid references public.cash_box(id),
 add column if not exists journal_entry_id uuid references public.journal_entries(id);
alter table public.buyer_custody_expenses
 add column if not exists payment_id uuid,
 add column if not exists journal_entry_id uuid references public.journal_entries(id);
alter table public.buyer_custody_settlements
 add column if not exists treasury_id uuid references public.treasury(id),
 add column if not exists cash_box_id uuid references public.cash_box(id),
 add column if not exists journal_entry_id uuid references public.journal_entries(id);

create table if not exists public.buyer_custody_payments(
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id),
 custody_id uuid not null references public.buyer_custodies(id),
 expense_id uuid not null unique references public.buyer_custody_expenses(id),
 purchase_invoice_id uuid not null references public.purchase_invoices(id),
 supplier_id uuid not null references public.suppliers(id),
 payment_code text not null,
 payment_date date not null default current_date,
 amount numeric(14,2) not null check(amount>0),
 currency text not null,
 reference text,
 recorded_by uuid not null references public.users(id),
 journal_entry_id uuid references public.journal_entries(id),
 status text not null default 'Posted' check(status in ('Posted','Reversed')),
 operation_id uuid not null unique,
 created_at timestamptz not null default now(),
 unique(company_id,payment_code)
);
create index if not exists buyer_custody_payments_supplier_date_idx on public.buyer_custody_payments(company_id,supplier_id,payment_date);
alter table public.buyer_custody_payments enable row level security;
drop policy if exists buyer_custody_payments_scoped_select on public.buyer_custody_payments;
create policy buyer_custody_payments_scoped_select on public.buyer_custody_payments for select to authenticated
using (
 company_id=app_private.current_user_company_id()
 and (
  exists(select 1 from public.buyer_custodies c where c.id=custody_id and c.company_id=company_id
    and c.employee_id=(select u.id from public.users u where u.auth_id=auth.uid() limit 1))
  or app_private.current_user_has_effective_permission('finance')
  or app_private.current_user_has_effective_permission('finance_manager')
 )
);
revoke all on public.buyer_custody_payments from anon,authenticated;
grant select on public.buyer_custody_payments to authenticated;
alter table public.buyer_custody_expenses
 add constraint buyer_custody_expenses_payment_fk foreign key(payment_id) references public.buyer_custody_payments(id);

drop function if exists public.buyer_custody_issue_atomic(uuid,uuid,uuid,text,text,numeric,date,text,text,text);
create or replace function public.buyer_custody_issue_atomic(
 p_company_id uuid,p_employee_id uuid,p_branch_id uuid,p_treasury_id uuid,p_purpose text,p_currency text,
 p_amount numeric,p_issued_date date,p_received_reference text,p_notes text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_employee public.users%rowtype; v_row public.buyer_custodies%rowtype;
 v_currency text; v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb; v_advance_id uuid;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_purpose),'') is null or nullif(btrim(p_operation_id),'') is null or p_treasury_id is null then raise exception 'CUSTODY_INVALID_ISSUE'; end if;
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
 v_cash_result:=public.post_cash_payment_atomic(p_company_id,gen_random_uuid(),p_treasury_id,v_cash_account,v_custody_account,p_amount,
  coalesce(p_issued_date,current_date),coalesce(nullif(btrim(p_received_reference),''),v_row.custody_code),'تسليم عهدة مشتريات',
  v_actor.email,v_employee.name,'BuyerCustodyAdvance',v_row.id,nullif(btrim(p_notes),''),null);
 update public.buyer_custody_advances set cash_box_id=nullif(v_cash_result->>'cash_box_id','')::uuid,
  journal_entry_id=nullif(v_cash_result->>'entry_id','')::uuid where id=v_advance_id;
 return to_jsonb(v_row)||jsonb_build_object('cash_box_id',v_cash_result->'cash_box_id','journal_entry_id',v_cash_result->'entry_id');
end;
$function$;
revoke all on function public.buyer_custody_issue_atomic(uuid,uuid,uuid,uuid,text,text,numeric,date,text,text,text) from public,anon;
grant execute on function public.buyer_custody_issue_atomic(uuid,uuid,uuid,uuid,text,text,numeric,date,text,text,text) to authenticated;

drop function if exists public.buyer_custody_add_advance_atomic(uuid,uuid,numeric,date,text,text,text);
create or replace function public.buyer_custody_add_advance_atomic(
 p_company_id uuid,p_custody_id uuid,p_treasury_id uuid,p_amount numeric,p_advance_date date,p_reference text,p_notes text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_advance public.buyer_custody_advances%rowtype;
 v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_operation_id),'') is null or p_treasury_id is null then raise exception 'CUSTODY_ADVANCE_INVALID'; end if;
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
 v_cash_result:=public.post_cash_payment_atomic(p_company_id,gen_random_uuid(),p_treasury_id,v_cash_account,v_custody_account,p_amount,
  coalesce(p_advance_date,current_date),coalesce(nullif(btrim(p_reference),''),v_custody.custody_code),'زيادة عهدة مشتريات',
  v_actor.email,(select name from public.users where id=v_custody.employee_id),'BuyerCustodyAdvance',v_custody.id,nullif(btrim(p_notes),''),null);
 update public.buyer_custody_advances set cash_box_id=nullif(v_cash_result->>'cash_box_id','')::uuid,
  journal_entry_id=nullif(v_cash_result->>'entry_id','')::uuid where id=v_advance.id returning * into v_advance;
 return to_jsonb(v_advance);
end;
$function$;
revoke all on function public.buyer_custody_add_advance_atomic(uuid,uuid,uuid,numeric,date,text,text,text) from public,anon;
grant execute on function public.buyer_custody_add_advance_atomic(uuid,uuid,uuid,numeric,date,text,text,text) to authenticated;

create or replace function public.buyer_custody_review_expense_atomic(p_company_id uuid,p_expense_id uuid,p_decision text,p_review_note text)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_expense public.buyer_custody_expenses%rowtype; v_row public.buyer_custody_expenses%rowtype;
 v_custody public.buyer_custodies%rowtype; v_invoice public.purchase_invoices%rowtype; v_po public.purchase_orders%rowtype;
 v_supplier_account uuid; v_custody_account uuid; v_balance numeric(14,2); v_po_credit numeric(14,2);
 v_journal jsonb; v_payment_id uuid; v_payment_code text;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_decision not in ('Approved','Rejected') then raise exception 'CUSTODY_REVIEW_DECISION_INVALID'; end if;
 select * into v_expense from public.buyer_custody_expenses where id=p_expense_id and company_id=p_company_id for update;
 if not found or v_expense.status<>'Submitted' then raise exception 'CUSTODY_EXPENSE_NOT_PENDING'; end if;
 if v_expense.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_REVIEW_FORBIDDEN'; end if;
 if p_decision='Rejected' then
  update public.buyer_custody_expenses set status='Rejected',reviewed_by=v_actor.id,reviewed_at=now(),review_note=nullif(btrim(p_review_note),'')
   where id=p_expense_id and company_id=p_company_id returning * into v_row;
  return to_jsonb(v_row);
 end if;
 select * into v_custody from public.buyer_custodies where id=v_expense.custody_id and company_id=p_company_id for update;
 select * into v_invoice from public.purchase_invoices where id=v_expense.purchase_invoice_id and company_id=p_company_id and supplier_id=v_expense.supplier_id for update;
 if not found or v_invoice.status<>'Draft' or abs(v_invoice.total_amount-v_expense.amount)>0.01 then raise exception 'CUSTODY_INVOICE_NOT_READY_FOR_PAYMENT'; end if;
 select * into v_po from public.purchase_orders where id=v_invoice.purchase_order_id and company_id=p_company_id and supplier_id=v_expense.supplier_id;
 if not found or not exists(select 1 from public.receiving r where r.company_id=p_company_id and r.operation_id=v_expense.receiving_operation_id and r.po_number=v_po.po_code and r.status in ('مكتمل','Completed')) then
  raise exception 'CUSTODY_WAREHOUSE_RECEIPT_INVALID';
 end if;
 select coalesce(sum(credit-debit),0) into v_po_credit from public.supplier_ledger where supplier_id=v_expense.supplier_id and reference=v_po.po_code;
 if v_po_credit+0.005<v_expense.amount then raise exception 'CUSTODY_PO_SUPPLIER_LIABILITY_NOT_POSTED'; end if;
 select coalesce((select balance from public.supplier_ledger where supplier_id=v_expense.supplier_id order by created_at desc,id desc limit 1),0) into v_balance;
 if v_balance+0.005<v_expense.amount then raise exception 'CUSTODY_SUPPLIER_BALANCE_INSUFFICIENT'; end if;
 select id into v_supplier_account from public.chart_of_accounts where company_id=p_company_id and account_code='211' and is_active;
 select id into v_custody_account from public.chart_of_accounts where company_id=p_company_id and account_code='127' and is_active;
 if v_supplier_account is null or v_custody_account is null then raise exception 'CUSTODY_ACCOUNT_MAPPING_MISSING'; end if;
 v_payment_code:='BCP-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 v_journal:=public.post_journal_entry(p_company_id,gen_random_uuid(),current_date,'PurchasePayment',v_invoice.invoice_code,
  'سداد فاتورة المورد من عهدة الموظف',v_actor.email,
  jsonb_build_array(
   jsonb_build_object('account_id',v_supplier_account,'debit',v_expense.amount,'credit',0,'notes','سداد مورد من عهدة الموظف'),
   jsonb_build_object('account_id',v_custody_account,'debit',0,'credit',v_expense.amount,'notes','تسوية مصروف عهدة معتمد')
  ),null,now(),null);
 insert into public.buyer_custody_payments(company_id,custody_id,expense_id,purchase_invoice_id,supplier_id,payment_code,payment_date,amount,currency,reference,recorded_by,journal_entry_id,operation_id)
 values(p_company_id,v_expense.custody_id,v_expense.id,v_invoice.id,v_expense.supplier_id,v_payment_code,current_date,v_expense.amount,
 v_expense.currency,v_invoice.invoice_code,v_actor.id,(v_journal->>'entry_id')::uuid,gen_random_uuid())
 returning id into v_payment_id;
 update public.purchase_invoices set paid_amount=total_amount,status='Paid',is_received=true,received_date=coalesce(received_date,current_date),
  posted_by=v_actor.email,posted_at=now(),updated_at=now()
 where id=v_invoice.id and company_id=p_company_id;
 insert into public.supplier_ledger(supplier_id,entry_date,reference,description,debit,credit,balance,user_email)
 values(v_expense.supplier_id,current_date,v_invoice.invoice_code,'سداد فاتورة من عهدة الموظف - '||v_payment_code,
 v_expense.amount,0,v_balance-v_expense.amount,v_actor.email);
 update public.buyer_custody_expenses set status='Approved',reviewed_by=v_actor.id,reviewed_at=now(),
  review_note=nullif(btrim(p_review_note),''),payment_id=v_payment_id,journal_entry_id=(v_journal->>'entry_id')::uuid
 where id=p_expense_id and company_id=p_company_id returning * into v_row;
 return to_jsonb(v_row)||jsonb_build_object('payment_code',v_payment_code,'journal_entry_id',v_journal->'entry_id');
end;
$function$;

drop function if exists public.buyer_custody_settle_atomic(uuid,uuid,numeric,text,text);
create or replace function public.buyer_custody_settle_atomic(
 p_company_id uuid,p_custody_id uuid,p_treasury_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_employee public.users%rowtype;
 v_approved numeric(14,2); v_pending integer; v_expected_return numeric(14,2); v_unacknowledged integer;
 v_settlement public.buyer_custody_settlements%rowtype; v_cash_account uuid; v_custody_account uuid; v_cash_result jsonb;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; end if;
 select * into v_employee from public.users where id=v_custody.employee_id and company_id=p_company_id;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select count(*) into v_unacknowledged from public.buyer_custody_advances where custody_id=p_custody_id and company_id=p_company_id and acknowledged_at is null;
 if v_unacknowledged>0 then raise exception 'CUSTODY_ADVANCES_NOT_ACKNOWLEDGED'; end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 v_expected_return:=greatest(v_custody.issued_amount-v_approved,0);
 if coalesce(p_cash_returned,0)<>v_expected_return then raise exception 'CUSTODY_CASH_RETURN_MUST_RECONCILE'; end if;
 if v_expected_return>0 then
  if p_treasury_id is null then raise exception 'CUSTODY_RETURN_TREASURY_REQUIRED'; end if;
  select id into v_cash_account from public.chart_of_accounts where company_id=p_company_id and account_code='121' and is_active;
  select id into v_custody_account from public.chart_of_accounts where company_id=p_company_id and account_code='127' and is_active;
  if v_cash_account is null or v_custody_account is null then raise exception 'CUSTODY_ACCOUNT_MAPPING_MISSING'; end if;
  v_cash_result:=public.post_cash_receipt_atomic(p_company_id,gen_random_uuid(),p_treasury_id,v_cash_account,v_custody_account,v_expected_return,
   current_date,coalesce(nullif(btrim(p_finance_reference),''),v_custody.custody_code),'رد نقدية متبقية من عهدة مشتريات',
   v_actor.email,v_employee.name,'BuyerCustodySettlement',v_custody.id,nullif(btrim(p_notes),''),null);
 end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by,treasury_id,cash_box_id,journal_entry_id)
 values(p_company_id,p_custody_id,v_approved,v_expected_return,greatest(v_approved-v_custody.issued_amount,0),0,
 nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_treasury_id,
 nullif(v_cash_result->>'cash_box_id','')::uuid,nullif(v_cash_result->>'entry_id','')::uuid)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;
$function$;

revoke all on function public.buyer_custody_settle_atomic(uuid,uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.buyer_custody_settle_atomic(uuid,uuid,uuid,numeric,text,text) to authenticated;

do $publication$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='buyer_custody_payments') then
  alter publication supabase_realtime add table public.buyer_custody_payments;
 end if;
end;
$publication$;
