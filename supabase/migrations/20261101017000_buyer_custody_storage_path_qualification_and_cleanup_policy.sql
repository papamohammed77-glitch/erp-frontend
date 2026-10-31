drop policy if exists buyer_custody_docs_insert on storage.objects;
create policy buyer_custody_docs_insert on storage.objects for insert to authenticated
with check (
 bucket_id='employee-documents'
 and (storage.foldername(storage.objects.name))[3]='buyer-custody'
 and exists (
  select 1 from public.users u
  join public.buyer_custodies c
    on c.id = case
      when (storage.foldername(storage.objects.name))[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[4])::uuid else null end
   and c.company_id=u.company_id and c.employee_id=u.id
  where u.auth_id=auth.uid()
    and u.company_id = case
      when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[1])::uuid else null end
    and u.id::text=(storage.foldername(storage.objects.name))[2]
    and coalesce(u.status,'Active')='Active'
 )
);

drop policy if exists buyer_custody_docs_select on storage.objects;
create policy buyer_custody_docs_select on storage.objects for select to authenticated
using (
 bucket_id='employee-documents'
 and (storage.foldername(storage.objects.name))[3]='buyer-custody'
 and exists (
  select 1 from public.users u
  join public.buyer_custodies c
    on c.id = case
      when (storage.foldername(storage.objects.name))[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[4])::uuid else null end
   and c.company_id=u.company_id and c.employee_id::text=(storage.foldername(storage.objects.name))[2]
  where u.auth_id=auth.uid()
    and u.company_id = case
      when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[1])::uuid else null end
    and coalesce(u.status,'Active')='Active'
    and (u.id::text=(storage.foldername(storage.objects.name))[2]
      or app_private.current_user_has_effective_permission('finance')
      or app_private.current_user_has_effective_permission('finance_manager'))
 )
);

drop policy if exists buyer_custody_docs_delete on storage.objects;
create policy buyer_custody_docs_delete on storage.objects for delete to authenticated
using (
 bucket_id='employee-documents'
 and (storage.foldername(storage.objects.name))[3]='buyer-custody'
 and exists (
  select 1 from public.users u
  join public.buyer_custodies c
    on c.id = case
      when (storage.foldername(storage.objects.name))[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[4])::uuid else null end
   and c.company_id=u.company_id and c.employee_id=u.id
  where u.auth_id=auth.uid()
    and u.company_id = case
      when (storage.foldername(storage.objects.name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(storage.objects.name))[1])::uuid else null end
    and u.id::text=(storage.foldername(storage.objects.name))[2]
    and coalesce(u.status,'Active')='Active'
 )
);
