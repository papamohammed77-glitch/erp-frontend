
alter table public.purchase_orders
  add column if not exists currency text not null default 'EGP',
  add column if not exists expected_delivery_date date,
  add column if not exists payment_terms text,
  add column if not exists operation_id text;
alter table public.purchase_invoices alter column currency set default 'EGP';
alter table public.buyer_custodies alter column currency set default 'EGP';
alter table public.buyer_custody_expenses alter column currency set default 'EGP';
alter table public.purchase_settings alter column default_currency set default 'EGP';
alter table public.app_settings alter column currency set default 'EGP';
update public.purchase_settings ps set default_currency=coalesce(nullif(upper(btrim(a.currency)),''),'EGP'),updated_at=now()
from public.app_settings a where a.company_id=ps.company_id
and ps.default_currency is distinct from coalesce(nullif(upper(btrim(a.currency)),''),'EGP');
create unique index if not exists purchase_orders_company_operation_uidx on public.purchase_orders(company_id,operation_id) where operation_id is not null;

create or replace function public.purchase_create_po_atomic(
 p_company_id uuid,p_supplier_id uuid,p_branch_id uuid,p_expected_delivery_date date,
 p_payment_terms text,p_notes text,p_items jsonb,p_operation_id text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 v_actor public.users%rowtype; v_supplier public.suppliers%rowtype; v_item public.items%rowtype;
 v_currency text; v_po_id uuid; v_code text; v_total numeric(14,2):=0; x jsonb; v_existing public.purchase_orders%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'PURCHASE_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('purchases') then raise exception 'PURCHASE_PERMISSION_REQUIRED'; end if;
 if nullif(btrim(p_operation_id),'') is null or p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'PURCHASE_PO_INVALID'; end if;
 select * into v_existing from public.purchase_orders where company_id=p_company_id and operation_id=p_operation_id for update;
 if found then return jsonb_build_object('success',true,'duplicate',true,'id',v_existing.id,'code',v_existing.po_code,'status',v_existing.status); end if;
 select * into v_supplier from public.suppliers where id=p_supplier_id and company_id=p_company_id and is_active=true;
 if not found then raise exception 'PURCHASE_SUPPLIER_INVALID'; end if;
 if p_branch_id is not null and not exists(select 1 from public.branches where id=p_branch_id and company_id=p_company_id and coalesce(is_active,true)) then raise exception 'PURCHASE_BRANCH_INVALID'; end if;
 select coalesce(nullif(upper(btrim(currency)),''),'EGP') into v_currency from public.app_settings where company_id=p_company_id order by created_at,id limit 1;
 if v_currency is null then raise exception 'SYSTEM_CURRENCY_NOT_CONFIGURED'; end if;
 perform pg_advisory_xact_lock(hashtext('rawaea:purchase-po-code:'||p_company_id::text));
 select 'PO-'||((coalesce(max(nullif(regexp_replace(po_code,'[^0-9]','','g'),'')::bigint,1000))+1)::text)
 into v_code from public.purchase_orders where company_id=p_company_id;
 insert into public.purchase_orders(company_id,po_code,po_date,supplier_id,supplier_name,total_amount,status,branch_id,created_by,notes,currency,expected_delivery_date,payment_terms,operation_id)
 values(p_company_id,v_code,current_date,p_supplier_id,v_supplier.name,0,'Draft',p_branch_id,v_actor.email,
 nullif(btrim(p_notes),''),v_currency,p_expected_delivery_date,nullif(btrim(p_payment_terms),''),p_operation_id)
 returning id into v_po_id;
 for x in select value from jsonb_array_elements(p_items) loop
  if nullif(btrim(x->>'item_code'),'') is null or coalesce((x->>'qty')::numeric,0)<=0 or coalesce((x->>'unit_price')::numeric,0)<0 then raise exception 'PURCHASE_PO_ITEM_INVALID'; end if;
  select * into v_item from public.items where company_id=p_company_id and item_code=btrim(x->>'item_code');
  if not found then raise exception 'PURCHASE_PO_ITEM_NOT_FOUND:%',x->>'item_code'; end if;
  if exists(select 1 from public.purchase_order_details d where d.po_id=v_po_id and d.item_code=v_item.item_code) then raise exception 'PURCHASE_PO_DUPLICATE_ITEM:%',v_item.item_code; end if;
  insert into public.purchase_order_details(po_id,item_id,item_code,item_name,unit,qty_ordered,unit_price,line_amount,notes)
  values(v_po_id,v_item.id,v_item.item_code,v_item.name,v_item.unit,(x->>'qty')::numeric,(x->>'unit_price')::numeric,
   (x->>'qty')::numeric*(x->>'unit_price')::numeric,nullif(btrim(x->>'notes'),''));
  v_total:=v_total+(x->>'qty')::numeric*(x->>'unit_price')::numeric;
 end loop;
 update public.purchase_orders set total_amount=v_total,updated_at=now() where id=v_po_id and company_id=p_company_id;
 insert into public.purchase_status_history(company_id,document_type,document_id,from_status,to_status,action,actor_email,note)
 values(p_company_id,'PurchaseOrder',v_po_id,null,'Draft','Created',v_actor.email,nullif(btrim(p_notes),''));
 return jsonb_build_object('success',true,'id',v_po_id,'code',v_code,'status','Draft','total_amount',v_total,'currency',v_currency);
end;
$function$;
revoke all on function public.purchase_create_po_atomic(uuid,uuid,uuid,date,text,text,jsonb,text) from public,anon;
grant execute on function public.purchase_create_po_atomic(uuid,uuid,uuid,date,text,text,jsonb,text) to authenticated;
