create or replace function public.purchase_get_dashboard(p_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_profile jsonb;
begin
  if p_company_id is null or not exists(select 1 from companies where id=p_company_id) then
    raise exception 'COMPANY_INVALID';
  end if;
  if current_setting('request.jwt.claim.role',true) is distinct from 'service_role' then
    if auth.uid() is null then raise exception 'PURCHASE_AUTH_REQUIRED'; end if;
    v_profile := public.get_my_effective_profile();
    if v_profile is null or (v_profile->>'company_id')::uuid is distinct from p_company_id then
      raise exception 'PURCHASE_COMPANY_SCOPE_DENIED';
    end if;
    if coalesce((v_profile->>'isOwner')::boolean,false) is not true
       and not (
         coalesce(v_profile->'permissions','[]'::jsonb) ? '*'
         or coalesce(v_profile->'permissions','[]'::jsonb) ? 'purchases'
         or coalesce(v_profile->'permissions','[]'::jsonb) ? 'finance'
         or coalesce(v_profile->'permissions','[]'::jsonb) ? 'finance_manager'
       ) then
      raise exception 'PURCHASE_PERMISSION_DENIED';
    end if;
  end if;
  return jsonb_build_object(
    'requests',jsonb_build_object('draft',coalesce((select count(*) from purchase_requests where company_id=p_company_id and status in ('Draft','مسودة')),0),'pending',coalesce((select count(*) from purchase_requests where company_id=p_company_id and status='PendingApproval'),0),'approved',coalesce((select count(*) from purchase_requests where company_id=p_company_id and status='Approved'),0)),
    'rfqs',jsonb_build_object('draft',coalesce((select count(*) from purchase_rfqs where company_id=p_company_id and status='Draft'),0),'sent',coalesce((select count(*) from purchase_rfqs where company_id=p_company_id and status='Sent'),0),'closed',coalesce((select count(*) from purchase_rfqs where company_id=p_company_id and status in ('Closed','Converted')),0)),
    'quotations',jsonb_build_object('submitted',coalesce((select count(*) from purchase_quotations where company_id=p_company_id and status='Submitted'),0),'accepted',coalesce((select count(*) from purchase_quotations where company_id=p_company_id and status='Accepted'),0)),
    'orders',jsonb_build_object('draft',coalesce((select count(*) from purchase_orders where company_id=p_company_id and status='Draft'),0),'open',coalesce((select count(*) from purchase_orders where company_id=p_company_id and status not in ('Draft','Received','Cancelled')),0)),
    'invoices',jsonb_build_object('draft',coalesce((select count(*) from purchase_invoices where company_id=p_company_id and status='Draft'),0),'open',coalesce((select count(*) from purchase_invoices where company_id=p_company_id and status in ('Posted','Partially Paid','Approved')),0),'outstanding',coalesce((select sum(greatest(0,total_amount-paid_amount)) from purchase_invoices where company_id=p_company_id and status in ('Posted','Partially Paid','Approved')),0)),
    'payments',jsonb_build_object('posted',coalesce((select count(*) from purchase_payments where company_id=p_company_id and status='Posted'),0),'amount',coalesce((select sum(amount) from purchase_payments where company_id=p_company_id and status='Posted'),0)),
    'returns',jsonb_build_object('draft',coalesce((select count(*) from purchase_returns where company_id=p_company_id and status='Draft'),0),'posted',coalesce((select count(*) from purchase_returns where company_id=p_company_id and status='Posted'),0))
  );
end;
$function$;
