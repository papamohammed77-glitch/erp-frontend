
create table if not exists public.buyer_custody_advances (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id),
 custody_id uuid not null references public.buyer_custodies(id) on delete restrict,
 employee_id uuid not null references public.users(id),
 advance_type text not null check (advance_type in ('Initial','Additional')),
 amount numeric(14,2) not null check (amount>0),
 currency text not null,
 advance_date date not null default current_date,
 reference text,
 notes text,
 issued_by uuid not null references public.users(id),
 acknowledged_by uuid references public.users(id),
 acknowledged_at timestamptz,
 operation_id text not null,
 created_at timestamptz not null default now(),
 unique(company_id,operation_id)
);
create index if not exists buyer_custody_advances_custody_date_idx on public.buyer_custody_advances(company_id,custody_id,advance_date,created_at);
alter table public.buyer_custody_advances enable row level security;
drop policy if exists buyer_custody_advances_scoped_select on public.buyer_custody_advances;
create policy buyer_custody_advances_scoped_select on public.buyer_custody_advances for select to authenticated
using (
 company_id=app_private.current_user_company_id()
 and (
  employee_id=(select u.id from public.users u where u.auth_id=auth.uid() limit 1)
  or app_private.current_user_has_effective_permission('finance')
  or app_private.current_user_has_effective_permission('finance_manager')
 )
);
revoke all on public.buyer_custody_advances from anon,authenticated;
grant select on public.buyer_custody_advances to authenticated;

alter table public.buyer_custody_expenses
 add column if not exists supplier_id uuid references public.suppliers(id),
 add column if not exists purchase_invoice_id uuid references public.purchase_invoices(id),
 add column if not exists receiving_operation_id text,
 add column if not exists receipt_document_name text,
 add column if not exists receipt_document_path text,
 add column if not exists receipt_mime_type text;
create unique index if not exists buyer_custody_expenses_invoice_uidx
 on public.buyer_custody_expenses(company_id,purchase_invoice_id) where purchase_invoice_id is not null;

create or replace function public.buyer_custody_issue_atomic(
 p_company_id uuid,p_employee_id uuid,p_branch_id uuid,p_purpose text,p_currency text,
 p_amount numeric,p_issued_date date,p_received_reference text,p_notes text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor public.users%rowtype; v_employee public.users%rowtype; v_row public.buyer_custodies%rowtype; v_currency text;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_purpose),'') is null or nullif(btrim(p_operation_id),'') is null then raise exception 'CUSTODY_INVALID_ISSUE'; end if;
 select * into v_employee from public.users where id=p_employee_id and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_EMPLOYEE_INVALID'; end if;
 if p_branch_id is not null and not exists(select 1 from public.branches b where b.id=p_branch_id and b.company_id=p_company_id) then raise exception 'CUSTODY_BRANCH_INVALID'; end if;
 select coalesce(nullif(upper(btrim(a.currency)),''),'EGP') into v_currency from public.app_settings a where a.company_id=p_company_id order by a.created_at,a.id limit 1;
 if v_currency is null then raise exception 'SYSTEM_CURRENCY_NOT_CONFIGURED'; end if;
 select * into v_row from public.buyer_custodies where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 insert into public.buyer_custodies(company_id,custody_code,employee_id,branch_id,purpose,currency,issued_amount,issued_date,received_reference,received_at,issued_by,notes,operation_id)
 values(p_company_id,'BC-'||to_char(coalesce(p_issued_date,current_date),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
 p_employee_id,p_branch_id,btrim(p_purpose),v_currency,p_amount,coalesce(p_issued_date,current_date),nullif(btrim(p_received_reference),''),now(),v_actor.id,nullif(btrim(p_notes),''),p_operation_id)
 returning * into v_row;
 insert into public.buyer_custody_advances(company_id,custody_id,employee_id,advance_type,amount,currency,advance_date,reference,notes,issued_by,operation_id)
 values(p_company_id,v_row.id,p_employee_id,'Initial',p_amount,v_currency,coalesce(p_issued_date,current_date),nullif(btrim(p_received_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_operation_id||':INITIAL');
 return to_jsonb(v_row);
end;
$function$;

create or replace function public.buyer_custody_acknowledge_atomic(p_company_id uuid,p_custody_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor public.users%rowtype; v_row public.buyer_custodies%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 update public.buyer_custodies set acknowledged_at=coalesce(acknowledged_at,now()),updated_at=now()
 where id=p_custody_id and company_id=p_company_id and employee_id=v_actor.id and status='Issued' returning * into v_row;
 if not found then raise exception 'CUSTODY_ACKNOWLEDGE_NOT_ALLOWED'; end if;
 update public.buyer_custody_advances set acknowledged_at=coalesce(acknowledged_at,now()),acknowledged_by=v_actor.id
 where custody_id=p_custody_id and company_id=p_company_id and advance_type='Initial';
 return to_jsonb(v_row);
end;
$function$;

create or replace function public.buyer_custody_add_advance_atomic(
 p_company_id uuid,p_custody_id uuid,p_amount numeric,p_advance_date date,p_reference text,p_notes text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_advance public.buyer_custody_advances%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_operation_id),'') is null then raise exception 'CUSTODY_ADVANCE_INVALID'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_OPEN'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_ISSUE_FORBIDDEN'; end if;
 select * into v_advance from public.buyer_custody_advances where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_advance); end if;
 insert into public.buyer_custody_advances(company_id,custody_id,employee_id,advance_type,amount,currency,advance_date,reference,notes,issued_by,operation_id)
 values(p_company_id,p_custody_id,v_custody.employee_id,'Additional',p_amount,v_custody.currency,coalesce(p_advance_date,current_date),
 nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),v_actor.id,p_operation_id) returning * into v_advance;
 update public.buyer_custodies set issued_amount=issued_amount+p_amount,updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_advance);
end;
$function$;

create or replace function public.buyer_custody_acknowledge_advance_atomic(p_company_id uuid,p_advance_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor public.users%rowtype; v_advance public.buyer_custody_advances%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 update public.buyer_custody_advances a set acknowledged_at=coalesce(a.acknowledged_at,now()),acknowledged_by=v_actor.id
 where a.id=p_advance_id and a.company_id=p_company_id and a.employee_id=v_actor.id and a.advance_type='Additional' and a.acknowledged_at is null
 returning * into v_advance;
 if not found then raise exception 'CUSTODY_ADVANCE_ACKNOWLEDGE_NOT_ALLOWED'; end if;
 return to_jsonb(v_advance);
end;
$function$;

create or replace function public.buyer_custody_submit_expense_atomic(
 p_company_id uuid,p_custody_id uuid,p_expense_date date,p_supplier_name text,p_invoice_number text,
 p_description text,p_amount numeric,p_currency text,p_document_name text,p_document_path text,p_mime_type text,
 p_supplier_id uuid,p_purchase_invoice_id uuid,p_receiving_operation_id text,
 p_receipt_document_name text,p_receipt_document_path text,p_receipt_mime_type text,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_row public.buyer_custody_expenses%rowtype;
 v_invoice public.purchase_invoices%rowtype; v_po public.purchase_orders%rowtype;
 v_currency text; v_acknowledged numeric(14,2); v_committed numeric(14,2);
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id and employee_id=v_actor.id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_OPEN'; end if;
 if v_custody.acknowledged_at is null then raise exception 'CUSTODY_NOT_ACKNOWLEDGED'; end if;
 v_currency:=upper(v_custody.currency);
 if coalesce(nullif(upper(btrim(p_currency)),''),v_currency)<>v_currency then raise exception 'CUSTODY_CURRENCY_MISMATCH'; end if;
 if p_amount is null or p_amount<=0 or nullif(btrim(p_description),'') is null or nullif(btrim(p_document_name),'') is null
  or nullif(btrim(p_document_path),'') is null or nullif(btrim(p_receipt_document_name),'') is null
  or nullif(btrim(p_receipt_document_path),'') is null or nullif(btrim(p_operation_id),'') is null
  or p_supplier_id is null or p_purchase_invoice_id is null or nullif(btrim(p_receiving_operation_id),'') is null then raise exception 'CUSTODY_EXPENSE_INVALID'; end if;
 if p_document_path not like p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
  or p_receipt_document_path not like p_company_id::text||'/'||v_actor.id::text||'/buyer-custody/'||p_custody_id::text||'/%'
  or not exists(select 1 from storage.objects o where o.bucket_id='employee-documents' and o.name=p_document_path)
  or not exists(select 1 from storage.objects o where o.bucket_id='employee-documents' and o.name=p_receipt_document_path) then raise exception 'CUSTODY_DOCUMENT_NOT_FOUND_OR_FORBIDDEN'; end if;
 select * into v_invoice from public.purchase_invoices i
 where i.id=p_purchase_invoice_id and i.company_id=p_company_id and i.supplier_id=p_supplier_id and i.status in ('Draft','Posted') for share;
 if not found or v_invoice.purchase_order_id is null then raise exception 'CUSTODY_PURCHASE_INVOICE_NOT_LINKED_TO_PO'; end if;
 if upper(v_invoice.currency)<>v_currency then raise exception 'CUSTODY_INVOICE_CURRENCY_MISMATCH'; end if;
 if abs(coalesce(v_invoice.total_amount,0)-p_amount)>0.01 then raise exception 'CUSTODY_INVOICE_AMOUNT_MISMATCH'; end if;
 select * into v_po from public.purchase_orders po where po.id=v_invoice.purchase_order_id and po.company_id=p_company_id and po.supplier_id=p_supplier_id;
 if not found then raise exception 'CUSTODY_PURCHASE_ORDER_INVALID'; end if;
 if not exists(select 1 from public.receiving r where r.company_id=p_company_id and r.operation_id=p_receiving_operation_id and r.po_number=v_po.po_code and r.status in ('مكتمل','Completed'))
  or not exists(select 1 from public.receiving_details rd where rd.operation_id=p_receiving_operation_id) then raise exception 'CUSTODY_WAREHOUSE_RECEIPT_INVALID'; end if;
 if exists(select 1 from public.purchase_invoice_details d where d.invoice_id=v_invoice.id and not exists(
  select 1 from public.receiving_details rd where rd.operation_id=p_receiving_operation_id and rd.item_code=d.item_code and rd.qty_received>=d.qty
 )) then raise exception 'CUSTODY_WAREHOUSE_RECEIPT_ITEMS_MISMATCH'; end if;
 if nullif(btrim(p_invoice_number),'') is not null and v_invoice.supplier_invoice_no is not null and btrim(p_invoice_number)<>btrim(v_invoice.supplier_invoice_no) then
  raise exception 'CUSTODY_SUPPLIER_INVOICE_NUMBER_MISMATCH';
 end if;
 select coalesce(sum(amount),0) into v_acknowledged from public.buyer_custody_advances where company_id=p_company_id and custody_id=p_custody_id and acknowledged_at is not null;
 select coalesce(sum(amount),0) into v_committed from public.buyer_custody_expenses where company_id=p_company_id and custody_id=p_custody_id and status in ('Submitted','Approved');
 if v_committed+p_amount>v_acknowledged then raise exception 'CUSTODY_AVAILABLE_FUNDS_EXCEEDED'; end if;
 select * into v_row from public.buyer_custody_expenses where company_id=p_company_id and operation_id=p_operation_id;
 if found then return to_jsonb(v_row); end if;
 insert into public.buyer_custody_expenses(company_id,custody_id,employee_id,expense_date,supplier_name,invoice_number,description,amount,currency,document_name,document_path,mime_type,supplier_id,purchase_invoice_id,receiving_operation_id,receipt_document_name,receipt_document_path,receipt_mime_type,operation_id)
 values(p_company_id,p_custody_id,v_actor.id,coalesce(p_expense_date,current_date),nullif(btrim(p_supplier_name),''),nullif(btrim(p_invoice_number),''),btrim(p_description),p_amount,v_currency,btrim(p_document_name),btrim(p_document_path),nullif(btrim(p_mime_type),''),p_supplier_id,p_purchase_invoice_id,p_receiving_operation_id,btrim(p_receipt_document_name),btrim(p_receipt_document_path),nullif(btrim(p_receipt_mime_type),''),p_operation_id)
 returning * into v_row;
 update public.buyer_custodies set status='UnderReview',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_row);
end;
$function$;

create or replace function public.buyer_custody_settle_atomic(
 p_company_id uuid,p_custody_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_approved numeric(14,2);
 v_pending integer; v_expected_return numeric(14,2); v_unacknowledged integer; v_settlement public.buyer_custody_settlements%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not (app_private.current_user_has_effective_permission('finance') or app_private.current_user_has_effective_permission('finance_manager')) then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; end if;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select count(*) into v_unacknowledged from public.buyer_custody_advances where custody_id=p_custody_id and company_id=p_company_id and acknowledged_at is null;
 if v_unacknowledged>0 then raise exception 'CUSTODY_ADVANCES_NOT_ACKNOWLEDGED'; end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 v_expected_return:=greatest(v_custody.issued_amount-v_approved,0);
 if coalesce(p_cash_returned,0)<>v_expected_return then raise exception 'CUSTODY_CASH_RETURN_MUST_RECONCILE'; end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by)
 values(p_company_id,p_custody_id,v_approved,v_expected_return,greatest(v_approved-v_custody.issued_amount,0),0,nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;
$function$;

drop function if exists public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,text);
revoke all on function public.buyer_custody_add_advance_atomic(uuid,uuid,numeric,date,text,text,text) from public,anon;
grant execute on function public.buyer_custody_add_advance_atomic(uuid,uuid,numeric,date,text,text,text) to authenticated;
revoke all on function public.buyer_custody_acknowledge_advance_atomic(uuid,uuid) from public,anon;
grant execute on function public.buyer_custody_acknowledge_advance_atomic(uuid,uuid) to authenticated;
revoke all on function public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,uuid,uuid,text,text,text,text,text) to authenticated;

do $publication$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='buyer_custody_advances') then
  alter publication supabase_realtime add table public.buyer_custody_advances;
 end if;
end;
$publication$;
