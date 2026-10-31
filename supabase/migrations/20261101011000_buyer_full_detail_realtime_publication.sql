do $$
declare t text;
begin
 foreach t in array array[
 'purchase_request_details','purchase_rfq_details','purchase_rfq_suppliers',
 'purchase_quotation_details','purchase_invoice_details','purchase_payment_allocations',
 'purchase_return_details','purchase_status_history','purchase_attachments',
 'purchase_document_links','purchase_settings','buyer_custodies',
 'buyer_custody_expenses','buyer_custody_settlements'
 ] loop
  if to_regclass('public.'||t) is not null and not exists(
   select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t
  ) then execute format('alter publication supabase_realtime add table public.%I',t); end if;
 end loop;
end $$;
