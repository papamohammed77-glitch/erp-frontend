# CountFlow / Counting — Applied Supabase Migration Ledger Archive

> **ARCHIVE ONLY — DO NOT APPLY OR REPLAY.** This file preserves historical SQL recorded by the live Supabase migration ledger. It is not a migration plan, not a replacement for the deployment history, and must never be submitted to the database as one script.

## Capture provenance

- Captured: `2026-11-19` from Supabase project `rawaea-staging` (`hfzznsiprnwkpayskzhu`).
- Read path: `supabase_migrations.schema_migrations` using SELECT only.
- Included migration rows: 60 (`counting_*` foundation and `countflow_*` migrations).
- Total stored SQL characters: 288700.
- The `rollback` field was NULL for 60 of 60 rows; rollback scripts must not be inferred from this archive.
- SQL is preserved from each ledger `statements` array in version order. This is the recorded applied SQL, not a reconstructed guess.

## Reconciliation with Git

- Current Git folder contains 14 standalone `.sql` files.
- The live ledger contains 60 system migrations: 7 `counting_*` foundation rows and 53 `countflow_*` rows.
- Therefore 46 applied ledger rows have no one-to-one standalone file in the current migration folder.
- Only 4 of the 14 tracked files were token-equivalent to their matching ledger statement in a whitespace/comment-insensitive comparison. The other 10 require semantic reconciliation; do not reapply them based on filename alone.
- `20261119195630_countflow_import_batch_sku_lookup_index_v1.sql` maps to live ledger version `20261119195750` and its SQL matches exactly; this is timestamp drift, not a missing operation.
- `20261119192509_countflow_approval_requires_all_positions_counted.sql` is a consolidated source for the incremental `20261119192305..20261119192509` finality changes, not a one-to-one copy of the final ledger row.
- The two missing location/heatmap rows `20261119195107` and `20261119195202` are preserved below from the ledger.

## Integrity and handling

- This archive is a historical evidence artifact only.
- Before any future deployment, compare the proposed migration against the live schema and function definitions; never replay this archive.
- Do not modify legacy ERP objects in this project while reconciling CountFlow.

---

## 20261119174358 — counting_independent_foundation_v1

- Statements: 1
- SQL characters: 16270
- Rollback recorded: NO

### Statement 1

```sql

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.count_projects (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 code text not null unique,
 status text not null default 'draft' check (status in ('draft','ready','active','paused','closed','archived')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.count_members (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.count_projects(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null,
 username text not null,
 role text not null check (role in ('supervisor','counter','auditor')),
 status text not null default 'active' check (status in ('active','paused','removed')),
 last_seen_at timestamptz,
 created_at timestamptz not null default now(),
 unique(project_id,user_id),
 unique(project_id,username)
);

create table if not exists public.count_locations (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.count_projects(id) on delete cascade,
 parent_id uuid references public.count_locations(id) on delete restrict,
 location_type text not null check (location_type in ('store','warehouse','department','aisle','shelf','bin','zone','role')),
 code text not null,
 name text not null,
 sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 unique(project_id,location_type,code),
 unique(id,project_id)
);
create index if not exists count_locations_parent_idx on public.count_locations(project_id,parent_id,sort_order);

create table if not exists public.count_products (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.count_projects(id) on delete cascade,
 sku text not null,
 barcode text,
 name text not null,
 category text,
 base_unit text not null default 'وحدة',
 units jsonb not null default '[]'::jsonb,
 expected_qty numeric(18,4),
 image_url text,
 is_active boolean not null default true,
 search_text text generated always as (lower(coalesce(sku,'') || ' ' || coalesce(barcode,'') || ' ' || coalesce(name,''))) stored,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(project_id,sku)
);
create index if not exists count_products_barcode_idx on public.count_products(project_id,barcode) where barcode is not null;
create index if not exists count_products_search_idx on public.count_products using gin (to_tsvector('simple',search_text));
create index if not exists count_products_project_idx on public.count_products(project_id,is_active);

create table if not exists public.count_sessions (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.count_projects(id) on delete cascade,
 name text not null,
 status text not null default 'planned' check (status in ('planned','active','paused','review','completed','cancelled')),
 started_at timestamptz,
 closed_at timestamptz,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists count_sessions_project_idx on public.count_sessions(project_id,status,created_at desc);

create table if not exists public.count_assignments (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.count_sessions(id) on delete cascade,
 member_id uuid not null references public.count_members(id) on delete cascade,
 location_id uuid references public.count_locations(id) on delete set null,
 status text not null default 'assigned' check (status in ('assigned','active','paused','done')),
 assigned_at timestamptz not null default now(),
 unique(session_id,member_id,location_id)
);

create table if not exists public.count_entries (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.count_sessions(id) on delete cascade,
 project_id uuid not null references public.count_projects(id) on delete cascade,
 product_id uuid not null references public.count_products(id),
 location_id uuid references public.count_locations(id),
 member_id uuid not null references public.count_members(id),
 client_event_id uuid not null,
 quantity numeric(18,4) not null check (quantity >= 0),
 unit text not null,
 scan_code text,
 device_id text,
 counted_at timestamptz not null default now(),
 revision integer not null default 1,
 supersedes_id uuid references public.count_entries(id),
 note text,
 unique(session_id,client_event_id)
);
create index if not exists count_entries_session_idx on public.count_entries(session_id,counted_at desc);
create index if not exists count_entries_product_location_idx on public.count_entries(session_id,product_id,location_id,counted_at desc);
create index if not exists count_entries_member_idx on public.count_entries(session_id,member_id,counted_at desc);

create table if not exists public.count_import_batches (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.count_projects(id) on delete cascade,
 imported_by uuid not null references auth.users(id),
 source_name text not null,
 row_count integer not null default 0,
 accepted_count integer not null default 0,
 rejected_count integer not null default 0,
 status text not null default 'preview' check (status in ('preview','committed','failed')),
 error_report jsonb not null default '[]'::jsonb,
 created_at timestamptz not null default now()
);

create table if not exists public.count_audit_log (
 id bigint generated always as identity primary key,
 project_id uuid not null references public.count_projects(id) on delete cascade,
 actor_id uuid references auth.users(id),
 action text not null,
 entity_type text not null,
 entity_id uuid,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists count_audit_project_idx on public.count_audit_log(project_id,created_at desc);

create or replace function public.count_is_member(p_project uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists(select 1 from public.count_members m where m.project_id=p_project and m.user_id=(select auth.uid()) and m.status in ('active','paused'))
$$;
create or replace function public.count_is_supervisor(p_project uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists(select 1 from public.count_members m where m.project_id=p_project and m.user_id=(select auth.uid()) and m.role='supervisor' and m.status='active')
$$;
revoke all on function public.count_is_member(uuid) from public, anon;
revoke all on function public.count_is_supervisor(uuid) from public, anon;
grant execute on function public.count_is_member(uuid),public.count_is_supervisor(uuid) to authenticated;

alter table public.count_projects enable row level security;
alter table public.count_members enable row level security;
alter table public.count_locations enable row level security;
alter table public.count_products enable row level security;
alter table public.count_sessions enable row level security;
alter table public.count_assignments enable row level security;
alter table public.count_entries enable row level security;
alter table public.count_import_batches enable row level security;
alter table public.count_audit_log enable row level security;

drop policy if exists count_projects_read on public.count_projects;
create policy count_projects_read on public.count_projects for select to authenticated using (public.count_is_member(id));
drop policy if exists count_projects_create on public.count_projects;
create policy count_projects_create on public.count_projects for insert to authenticated with check (created_by=(select auth.uid()));
drop policy if exists count_projects_update on public.count_projects;
create policy count_projects_update on public.count_projects for update to authenticated using (public.count_is_supervisor(id)) with check (public.count_is_supervisor(id));

drop policy if exists count_members_read on public.count_members;
create policy count_members_read on public.count_members for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_members_manage on public.count_members;
create policy count_members_manage on public.count_members for all to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_locations_read on public.count_locations;
create policy count_locations_read on public.count_locations for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_locations_manage on public.count_locations;
create policy count_locations_manage on public.count_locations for all to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_products_read on public.count_products;
create policy count_products_read on public.count_products for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_products_manage on public.count_products;
create policy count_products_manage on public.count_products for all to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_sessions_read on public.count_sessions;
create policy count_sessions_read on public.count_sessions for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_sessions_manage on public.count_sessions;
create policy count_sessions_manage on public.count_sessions for all to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_assignments_read on public.count_assignments;
create policy count_assignments_read on public.count_assignments for select to authenticated using (exists(select 1 from public.count_sessions s where s.id=session_id and public.count_is_member(s.project_id)));
drop policy if exists count_assignments_manage on public.count_assignments;
create policy count_assignments_manage on public.count_assignments for all to authenticated using (exists(select 1 from public.count_sessions s where s.id=session_id and public.count_is_supervisor(s.project_id))) with check (exists(select 1 from public.count_sessions s where s.id=session_id and public.count_is_supervisor(s.project_id)));

drop policy if exists count_entries_read on public.count_entries;
create policy count_entries_read on public.count_entries for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_entries_insert on public.count_entries;
create policy count_entries_insert on public.count_entries for insert to authenticated with check (
 member_id in (select id from public.count_members where project_id=count_entries.project_id and user_id=(select auth.uid()) and role in ('counter','auditor') and status='active')
 and exists(select 1 from public.count_sessions s where s.id=session_id and s.project_id=project_id and s.status='active')
);
drop policy if exists count_entries_supervisor_update on public.count_entries;
create policy count_entries_supervisor_update on public.count_entries for update to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_import_read on public.count_import_batches;
create policy count_import_read on public.count_import_batches for select to authenticated using (public.count_is_member(project_id));
drop policy if exists count_import_manage on public.count_import_batches;
create policy count_import_manage on public.count_import_batches for all to authenticated using (public.count_is_supervisor(project_id)) with check (public.count_is_supervisor(project_id));

drop policy if exists count_audit_read on public.count_audit_log;
create policy count_audit_read on public.count_audit_log for select to authenticated using (public.count_is_supervisor(project_id));
drop policy if exists count_audit_insert on public.count_audit_log;
create policy count_audit_insert on public.count_audit_log for insert to authenticated with check (public.count_is_member(project_id) and actor_id=(select auth.uid()));

grant select,insert,update on public.count_projects to authenticated;
grant select,insert,update,delete on public.count_members,public.count_locations,public.count_products,public.count_sessions,public.count_assignments,public.count_import_batches to authenticated;
grant select,insert,update on public.count_entries to authenticated;
grant select,insert on public.count_audit_log to authenticated;

create or replace function public.count_record_entry(
 p_session_id uuid,p_product_id uuid,p_location_id uuid,p_quantity numeric,p_unit text,
 p_client_event_id uuid,p_scan_code text default null,p_device_id text default null,p_note text default null
) returns public.count_entries
language plpgsql security invoker set search_path=''
as $$
declare v_session public.count_sessions; v_member public.count_members; v_entry public.count_entries;
begin
 select * into v_session from public.count_sessions where id=p_session_id;
 if not found or v_session.status <> 'active' then raise exception 'SESSION_NOT_ACTIVE'; end if;
 select * into v_member from public.count_members where project_id=v_session.project_id and user_id=(select auth.uid()) and role in ('counter','auditor') and status='active';
 if not found then raise exception 'COUNTER_NOT_ACTIVE'; end if;
 if p_quantity is null or p_quantity < 0 or p_quantity > 999999999 then raise exception 'INVALID_QUANTITY'; end if;
 insert into public.count_entries(session_id,project_id,product_id,location_id,member_id,client_event_id,quantity,unit,scan_code,device_id,note)
 values(p_session_id,v_session.project_id,p_product_id,p_location_id,v_member.id,p_client_event_id,p_quantity,coalesce(nullif(trim(p_unit),''),'وحدة'),p_scan_code,p_device_id,p_note)
 on conflict(session_id,client_event_id) do nothing
 returning * into v_entry;
 if v_entry.id is null then
  select * into v_entry from public.count_entries where session_id=p_session_id and client_event_id=p_client_event_id;
 end if;
 return v_entry;
end $$;
revoke all on function public.count_record_entry(uuid,uuid,uuid,numeric,text,uuid,text,text,text) from public,anon;
grant execute on function public.count_record_entry(uuid,uuid,uuid,numeric,text,uuid,text,text,text) to authenticated;

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='count_entries') then
  alter publication supabase_realtime add table public.count_entries;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='count_members') then
  alter publication supabase_realtime add table public.count_members;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='count_sessions') then
  alter publication supabase_realtime add table public.count_sessions;
 end if;
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('counting-product-images','counting-product-images',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
drop policy if exists count_image_read on storage.objects;
create policy count_image_read on storage.objects for select to authenticated using (bucket_id='counting-product-images');
drop policy if exists count_image_upload on storage.objects;
create policy count_image_upload on storage.objects for insert to authenticated with check (bucket_id='counting-product-images' and (storage.foldername(name))[1] in (select project_id::text from public.count_members where user_id=(select auth.uid()) and role='supervisor' and status='active'));

```

---

## 20261119174405 — counting_project_owner_bootstrap

- Statements: 1
- SQL characters: 855
- Rollback recorded: NO

### Statement 1

```sql

create or replace function public.count_bootstrap_project_owner()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_email text;
begin
 select email into v_email from auth.users where id=new.created_by;
 insert into public.count_members(project_id,user_id,display_name,username,role,status)
 values(new.id,new.created_by,coalesce(nullif(v_email,''),'مشرف الجرد'),coalesce(nullif(v_email,''),new.id::text),'supervisor','active')
 on conflict(project_id,user_id) do nothing;
 return new;
end $$;
revoke all on function public.count_bootstrap_project_owner() from public,anon,authenticated;
drop trigger if exists count_project_owner_bootstrap on public.count_projects;
create trigger count_project_owner_bootstrap after insert on public.count_projects
for each row execute function public.count_bootstrap_project_owner();

```

---

## 20261119174613 — counting_storage_isolation_fix

- Statements: 1
- SQL characters: 772
- Rollback recorded: NO

### Statement 1

```sql

drop policy if exists count_image_read on storage.objects;
create policy count_image_read on storage.objects for select to authenticated
using (
 bucket_id='counting-product-images'
 and exists (
  select 1 from public.count_members m
  where m.user_id=(select auth.uid())
    and m.project_id::text=(storage.foldername(name))[1]
    and m.status in ('active','paused')
 )
);
drop policy if exists count_image_upload on storage.objects;
create policy count_image_upload on storage.objects for insert to authenticated
with check (
 bucket_id='counting-product-images'
 and exists (
  select 1 from public.count_members m
  where m.user_id=(select auth.uid())
    and m.project_id::text=(storage.foldername(name))[1]
    and m.role='supervisor' and m.status='active'
 )
);

```

---

## 20261119174716 — counting_rls_hardening_and_indexes_v2

- Statements: 1
- SQL characters: 9285
- Rollback recorded: NO

### Statement 1

```sql

create schema if not exists counting_private;
revoke all on schema counting_private from public,anon;
grant usage on schema counting_private to authenticated;
create or replace function counting_private.is_member(p_project uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.count_members m where m.project_id=p_project and m.user_id=(select auth.uid()) and m.status in ('active','paused')) $$;
create or replace function counting_private.is_supervisor(p_project uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.count_members m where m.project_id=p_project and m.user_id=(select auth.uid()) and m.role='supervisor' and m.status='active') $$;
revoke all on function counting_private.is_member(uuid),counting_private.is_supervisor(uuid) from public,anon;
grant execute on function counting_private.is_member(uuid),counting_private.is_supervisor(uuid) to authenticated;
revoke all on function public.count_is_member(uuid),public.count_is_supervisor(uuid) from public,anon,authenticated;

drop policy if exists count_projects_read on public.count_projects;
create policy count_projects_read on public.count_projects for select to authenticated using (counting_private.is_member(id));
drop policy if exists count_projects_update on public.count_projects;
create policy count_projects_update on public.count_projects for update to authenticated using (counting_private.is_supervisor(id)) with check (counting_private.is_supervisor(id));

drop policy if exists count_members_read on public.count_members;
drop policy if exists count_members_manage on public.count_members;
create policy count_members_read on public.count_members for select to authenticated using (counting_private.is_member(project_id));
create policy count_members_insert on public.count_members for insert to authenticated with check (counting_private.is_supervisor(project_id));
create policy count_members_update on public.count_members for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));
create policy count_members_delete on public.count_members for delete to authenticated using (counting_private.is_supervisor(project_id));

drop policy if exists count_locations_read on public.count_locations;
drop policy if exists count_locations_manage on public.count_locations;
create policy count_locations_read on public.count_locations for select to authenticated using (counting_private.is_member(project_id));
create policy count_locations_insert on public.count_locations for insert to authenticated with check (counting_private.is_supervisor(project_id));
create policy count_locations_update on public.count_locations for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));
create policy count_locations_delete on public.count_locations for delete to authenticated using (counting_private.is_supervisor(project_id));

drop policy if exists count_products_read on public.count_products;
drop policy if exists count_products_manage on public.count_products;
create policy count_products_read on public.count_products for select to authenticated using (counting_private.is_member(project_id));
create policy count_products_insert on public.count_products for insert to authenticated with check (counting_private.is_supervisor(project_id));
create policy count_products_update on public.count_products for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));
create policy count_products_delete on public.count_products for delete to authenticated using (counting_private.is_supervisor(project_id));

drop policy if exists count_sessions_read on public.count_sessions;
drop policy if exists count_sessions_manage on public.count_sessions;
create policy count_sessions_read on public.count_sessions for select to authenticated using (counting_private.is_member(project_id));
create policy count_sessions_insert on public.count_sessions for insert to authenticated with check (counting_private.is_supervisor(project_id));
create policy count_sessions_update on public.count_sessions for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));
create policy count_sessions_delete on public.count_sessions for delete to authenticated using (counting_private.is_supervisor(project_id));

drop policy if exists count_assignments_read on public.count_assignments;
drop policy if exists count_assignments_manage on public.count_assignments;
create policy count_assignments_read on public.count_assignments for select to authenticated using (exists(select 1 from public.count_sessions s where s.id=session_id and counting_private.is_member(s.project_id)));
create policy count_assignments_insert on public.count_assignments for insert to authenticated with check (exists(select 1 from public.count_sessions s where s.id=session_id and counting_private.is_supervisor(s.project_id)));
create policy count_assignments_update on public.count_assignments for update to authenticated using (exists(select 1 from public.count_sessions s where s.id=session_id and counting_private.is_supervisor(s.project_id))) with check (exists(select 1 from public.count_sessions s where s.id=session_id and counting_private.is_supervisor(s.project_id)));
create policy count_assignments_delete on public.count_assignments for delete to authenticated using (exists(select 1 from public.count_sessions s where s.id=session_id and counting_private.is_supervisor(s.project_id)));

drop policy if exists count_entries_read on public.count_entries;
create policy count_entries_read on public.count_entries for select to authenticated using (counting_private.is_member(project_id));
drop policy if exists count_entries_insert on public.count_entries;
create policy count_entries_insert on public.count_entries for insert to authenticated with check (
 member_id in (select id from public.count_members where project_id=count_entries.project_id and user_id=(select auth.uid()) and role in ('counter','auditor') and status='active')
 and exists(select 1 from public.count_sessions s where s.id=session_id and s.project_id=count_entries.project_id and s.status='active')
);
drop policy if exists count_entries_supervisor_update on public.count_entries;
create policy count_entries_supervisor_update on public.count_entries for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));

drop policy if exists count_import_read on public.count_import_batches;
drop policy if exists count_import_manage on public.count_import_batches;
create policy count_import_read on public.count_import_batches for select to authenticated using (counting_private.is_member(project_id));
create policy count_import_insert on public.count_import_batches for insert to authenticated with check (counting_private.is_supervisor(project_id));
create policy count_import_update on public.count_import_batches for update to authenticated using (counting_private.is_supervisor(project_id)) with check (counting_private.is_supervisor(project_id));
create policy count_import_delete on public.count_import_batches for delete to authenticated using (counting_private.is_supervisor(project_id));

drop policy if exists count_audit_read on public.count_audit_log;
drop policy if exists count_audit_insert on public.count_audit_log;
create policy count_audit_read on public.count_audit_log for select to authenticated using (counting_private.is_supervisor(project_id));
create policy count_audit_insert on public.count_audit_log for insert to authenticated with check (counting_private.is_member(project_id) and actor_id=(select auth.uid()));

create index if not exists count_assignments_location_idx on public.count_assignments(location_id);
create index if not exists count_assignments_member_idx on public.count_assignments(member_id);
create index if not exists count_audit_actor_idx on public.count_audit_log(actor_id);
create index if not exists count_entries_location_idx on public.count_entries(location_id);
create index if not exists count_entries_member_fk_idx on public.count_entries(member_id);
create index if not exists count_entries_product_fk_idx on public.count_entries(product_id);
create index if not exists count_entries_project_fk_idx on public.count_entries(project_id);
create index if not exists count_entries_supersedes_idx on public.count_entries(supersedes_id);
create index if not exists count_import_imported_by_idx on public.count_import_batches(imported_by);
create index if not exists count_import_project_fk_idx on public.count_import_batches(project_id);
create index if not exists count_locations_parent_fk_idx on public.count_locations(parent_id);
create index if not exists count_members_user_fk_idx on public.count_members(user_id);
create index if not exists count_projects_created_by_idx on public.count_projects(created_by);
create index if not exists count_sessions_created_by_idx on public.count_sessions(created_by);

```

---

## 20261119174731 — counting_assignment_enforcement_append_only

- Statements: 1
- SQL characters: 2497
- Rollback recorded: NO

### Statement 1

```sql

create or replace function public.count_record_entry(
 p_session_id uuid,p_product_id uuid,p_location_id uuid,p_quantity numeric,p_unit text,
 p_client_event_id uuid,p_scan_code text default null,p_device_id text default null,p_note text default null
) returns public.count_entries
language plpgsql security invoker set search_path=''
as $$
declare v_session public.count_sessions; v_member public.count_members; v_entry public.count_entries; v_has_assignments boolean;
begin
 select * into v_session from public.count_sessions where id=p_session_id;
 if not found or v_session.status <> 'active' then raise exception 'SESSION_NOT_ACTIVE'; end if;
 select * into v_member from public.count_members where project_id=v_session.project_id and user_id=(select auth.uid()) and role in ('counter','auditor') and status='active';
 if not found then raise exception 'COUNTER_NOT_ACTIVE'; end if;
 select exists(select 1 from public.count_assignments a where a.session_id=p_session_id) into v_has_assignments;
 if v_has_assignments and not exists(
   select 1 from public.count_assignments a where a.session_id=p_session_id and a.member_id=v_member.id
    and a.status in ('assigned','active') and (a.location_id is null or a.location_id=p_location_id)
 ) then raise exception 'LOCATION_NOT_ASSIGNED'; end if;
 if p_quantity is null or p_quantity < 0 or p_quantity > 999999999 then raise exception 'INVALID_QUANTITY'; end if;
 insert into public.count_entries(session_id,project_id,product_id,location_id,member_id,client_event_id,quantity,unit,scan_code,device_id,note)
 values(p_session_id,v_session.project_id,p_product_id,p_location_id,v_member.id,p_client_event_id,p_quantity,coalesce(nullif(trim(p_unit),''),'وحدة'),p_scan_code,p_device_id,p_note)
 on conflict(session_id,client_event_id) do nothing
 returning * into v_entry;
 if v_entry.id is null then select * into v_entry from public.count_entries where session_id=p_session_id and client_event_id=p_client_event_id; end if;
 return v_entry;
end $$;
revoke all on function public.count_record_entry(uuid,uuid,uuid,numeric,text,uuid,text,text,text) from public,anon;
grant execute on function public.count_record_entry(uuid,uuid,uuid,numeric,text,uuid,text,text,text) to authenticated;
drop policy if exists count_entries_supervisor_update on public.count_entries;
revoke update on public.count_entries from authenticated;
create index if not exists count_assignments_session_member_idx on public.count_assignments(session_id,member_id,status);

```

---

## 20261119175111 — counting_entries_immutable_permissions

- Statements: 1
- SQL characters: 142
- Rollback recorded: NO

### Statement 1

```sql

revoke all on table public.count_entries from public,anon,authenticated;
grant select,insert on table public.count_entries to authenticated;

```

---

## 20261119175119 — counting_storage_image_upsert_policy

- Statements: 1
- SQL characters: 612
- Rollback recorded: NO

### Statement 1

```sql

drop policy if exists count_image_update on storage.objects;
create policy count_image_update on storage.objects for update to authenticated
using (
 bucket_id='counting-product-images'
 and exists(select 1 from public.count_members m where m.user_id=(select auth.uid()) and m.project_id::text=(storage.foldername(name))[1] and m.role='supervisor' and m.status='active')
)
with check (
 bucket_id='counting-product-images'
 and exists(select 1 from public.count_members m where m.user_id=(select auth.uid()) and m.project_id::text=(storage.foldername(name))[1] and m.role='supervisor' and m.status='active')
);

```

---

## 20261119182050 — countflow_enterprise_data_model_v1

- Statements: 1
- SQL characters: 17847
- Rollback recorded: NO

### Statement 1

```sql

-- CountFlow-only data model. Transactional DDL; no legacy ERP table is altered.
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_sessions_id_project_uq') THEN
  ALTER TABLE public.count_sessions ADD CONSTRAINT count_sessions_id_project_uq UNIQUE(id,project_id);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_products_id_project_uq') THEN
  ALTER TABLE public.count_products ADD CONSTRAINT count_products_id_project_uq UNIQUE(id,project_id);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_members_id_project_uq') THEN
  ALTER TABLE public.count_members ADD CONSTRAINT count_members_id_project_uq UNIQUE(id,project_id);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_import_batches_id_project_uq') THEN
  ALTER TABLE public.count_import_batches ADD CONSTRAINT count_import_batches_id_project_uq UNIQUE(id,project_id);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_entries_id_project_uq') THEN
  ALTER TABLE public.count_entries ADD CONSTRAINT count_entries_id_project_uq UNIQUE(id,project_id);
 END IF;
END $$;

ALTER TABLE public.count_import_batches
 ADD COLUMN IF NOT EXISTS session_id uuid,
 ADD COLUMN IF NOT EXISTS source_format text NOT NULL DEFAULT 'csv',
 ADD COLUMN IF NOT EXISTS source_checksum text,
 ADD COLUMN IF NOT EXISTS started_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN IF NOT EXISTS completed_at timestamptz,
 ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_import_batches_session_project_fkey') THEN
  ALTER TABLE public.count_import_batches ADD CONSTRAINT count_import_batches_session_project_fkey
   FOREIGN KEY(session_id,project_id) REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT;
 END IF;
 IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_import_batches_status_check') THEN
  ALTER TABLE public.count_import_batches DROP CONSTRAINT count_import_batches_status_check;
 END IF;
 ALTER TABLE public.count_import_batches ADD CONSTRAINT count_import_batches_status_check
  CHECK(status IN ('uploading','validating','preview','committing','committed','failed','cancelled'));
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='count_import_batches_format_check') THEN
  ALTER TABLE public.count_import_batches ADD CONSTRAINT count_import_batches_format_check
   CHECK(source_format IN ('csv','xlsx','json'));
 END IF;
END $$;

CREATE TABLE public.count_import_rows (
 id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 batch_id uuid NOT NULL,
 project_id uuid NOT NULL,
 row_number integer NOT NULL CHECK(row_number>0),
 raw_row jsonb NOT NULL,
 sku text,
 barcode text,
 product_name text,
 category text,
 base_unit text,
 units jsonb NOT NULL DEFAULT '[]'::jsonb,
 expected_quantity numeric(18,4),
 location_code text,
 location_id uuid,
 product_id uuid,
 row_status text NOT NULL DEFAULT 'staged' CHECK(row_status IN ('staged','accepted','rejected','committed')),
 error_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
 error_detail jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 processed_at timestamptz,
 CONSTRAINT count_import_rows_batch_project_fkey FOREIGN KEY(batch_id,project_id)
  REFERENCES public.count_import_batches(id,project_id) ON DELETE CASCADE,
 CONSTRAINT count_import_rows_product_project_fkey FOREIGN KEY(product_id,project_id)
  REFERENCES public.count_products(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_import_rows_location_project_fkey FOREIGN KEY(location_id,project_id)
  REFERENCES public.count_locations(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_import_rows_batch_row_uq UNIQUE(batch_id,row_number)
);
CREATE INDEX count_import_rows_batch_status_idx ON public.count_import_rows(batch_id,row_status,row_number);
CREATE INDEX count_import_rows_project_sku_idx ON public.count_import_rows(project_id,sku) WHERE sku IS NOT NULL;

CREATE TABLE public.count_expected_balances (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 product_id uuid NOT NULL,
 location_id uuid,
 expected_quantity numeric(18,4) NOT NULL CHECK(expected_quantity>=0),
 unit text NOT NULL,
 source_batch_id uuid,
 snapshot_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT count_expected_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_expected_product_project_fkey FOREIGN KEY(product_id,project_id)
  REFERENCES public.count_products(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_expected_location_project_fkey FOREIGN KEY(location_id,project_id)
  REFERENCES public.count_locations(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_expected_batch_project_fkey FOREIGN KEY(source_batch_id,project_id)
  REFERENCES public.count_import_batches(id,project_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX count_expected_scope_uq ON public.count_expected_balances(session_id,product_id,location_id) NULLS NOT DISTINCT;
CREATE INDEX count_expected_session_product_idx ON public.count_expected_balances(session_id,product_id,location_id);

CREATE TABLE public.count_reconciliation_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 run_number integer NOT NULL DEFAULT 1 CHECK(run_number>0),
 status text NOT NULL DEFAULT 'building' CHECK(status IN ('building','computed','approved','superseded','failed')),
 expected_rows bigint NOT NULL DEFAULT 0,
 counted_rows bigint NOT NULL DEFAULT 0,
 matched_rows bigint NOT NULL DEFAULT 0,
 variance_rows bigint NOT NULL DEFAULT 0,
 uncounted_rows bigint NOT NULL DEFAULT 0,
 total_expected numeric(20,4) NOT NULL DEFAULT 0,
 total_counted numeric(20,4) NOT NULL DEFAULT 0,
 created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 approved_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 computed_at timestamptz,
 approved_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 CONSTRAINT count_recon_run_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recon_run_number_uq UNIQUE(session_id,run_number),
 CONSTRAINT count_recon_run_id_project_uq UNIQUE(id,project_id)
);
CREATE INDEX count_recon_runs_project_session_idx ON public.count_reconciliation_runs(project_id,session_id,created_at DESC);

CREATE TABLE public.count_reconciliation_lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 run_id uuid NOT NULL,
 session_id uuid NOT NULL,
 product_id uuid NOT NULL,
 location_id uuid,
 product_sku text NOT NULL,
 product_name text NOT NULL,
 location_path text,
 unit text NOT NULL,
 expected_quantity numeric(18,4),
 counted_quantity numeric(18,4),
 variance_quantity numeric(18,4),
 variance_percent numeric(18,4),
 counted_events bigint NOT NULL DEFAULT 0,
 counter_count integer NOT NULL DEFAULT 0,
 result_status text NOT NULL CHECK(result_status IN ('not_counted','not_expected','matched','under','over')),
 computed_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT count_recon_line_run_project_fkey FOREIGN KEY(run_id,project_id)
  REFERENCES public.count_reconciliation_runs(id,project_id) ON DELETE CASCADE,
 CONSTRAINT count_recon_line_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recon_line_product_project_fkey FOREIGN KEY(product_id,project_id)
  REFERENCES public.count_products(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recon_line_location_project_fkey FOREIGN KEY(location_id,project_id)
  REFERENCES public.count_locations(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recon_line_scope_uq UNIQUE(run_id,product_id,location_id),
 CONSTRAINT count_recon_line_id_project_uq UNIQUE(id,project_id)
);
CREATE INDEX count_recon_lines_variance_idx ON public.count_reconciliation_lines(run_id,result_status,variance_quantity);
CREATE INDEX count_recon_lines_product_idx ON public.count_reconciliation_lines(project_id,session_id,product_id);

CREATE TABLE public.count_recount_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 reconciliation_line_id uuid,
 product_id uuid NOT NULL,
 location_id uuid,
 assigned_member_id uuid,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','assigned','in_progress','completed','reviewed','escalated','cancelled')),
 reason text NOT NULL,
 first_count_quantity numeric(18,4),
 second_count_quantity numeric(18,4),
 variance_percent numeric(18,4),
 created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 assigned_at timestamptz,
 started_at timestamptz,
 completed_at timestamptz,
 reviewed_at timestamptz,
 notes text,
 CONSTRAINT count_recount_task_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recount_task_line_project_fkey FOREIGN KEY(reconciliation_line_id,project_id)
  REFERENCES public.count_reconciliation_lines(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recount_task_product_project_fkey FOREIGN KEY(product_id,project_id)
  REFERENCES public.count_products(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recount_task_location_project_fkey FOREIGN KEY(location_id,project_id)
  REFERENCES public.count_locations(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recount_task_member_project_fkey FOREIGN KEY(assigned_member_id,project_id)
  REFERENCES public.count_members(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_recount_task_line_uq UNIQUE(session_id,reconciliation_line_id)
);
CREATE INDEX count_recount_tasks_queue_idx ON public.count_recount_tasks(project_id,session_id,status,created_at DESC);
CREATE INDEX count_recount_tasks_member_idx ON public.count_recount_tasks(assigned_member_id,status,created_at DESC);

ALTER TABLE public.count_entries ADD COLUMN count_round smallint NOT NULL DEFAULT 1;
ALTER TABLE public.count_entries ADD COLUMN recount_task_id uuid;
ALTER TABLE public.count_entries ADD CONSTRAINT count_entries_round_check CHECK(count_round BETWEEN 1 AND 5);
ALTER TABLE public.count_entries ADD CONSTRAINT count_entries_recount_task_fkey
 FOREIGN KEY(recount_task_id) REFERENCES public.count_recount_tasks(id) ON DELETE RESTRICT;
CREATE INDEX count_entries_recount_task_idx ON public.count_entries(recount_task_id) WHERE recount_task_id IS NOT NULL;

CREATE TABLE public.count_entry_images (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 entry_id uuid NOT NULL,
 storage_path text NOT NULL,
 mime_type text NOT NULL CHECK(mime_type IN ('image/jpeg','image/png','image/webp')),
 size_bytes bigint NOT NULL CHECK(size_bytes>0 AND size_bytes<=5242880),
 caption text,
 uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT count_entry_images_entry_project_fkey FOREIGN KEY(entry_id,project_id)
  REFERENCES public.count_entries(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_entry_images_storage_path_uq UNIQUE(storage_path)
);
CREATE INDEX count_entry_images_entry_idx ON public.count_entry_images(entry_id,created_at DESC);

CREATE TABLE public.count_anomaly_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 name text NOT NULL,
 rule_type text NOT NULL CHECK(rule_type IN ('quantity_above','variance_percent_above','repeat_scan_window')),
 threshold numeric(18,4) NOT NULL CHECK(threshold>0),
 severity text NOT NULL DEFAULT 'warning' CHECK(severity IN ('info','warning','critical')),
 is_active boolean NOT NULL DEFAULT true,
 config jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT count_anomaly_rule_project_name_uq UNIQUE(project_id,name),
 CONSTRAINT count_anomaly_rule_id_project_uq UNIQUE(id,project_id)
);

CREATE TABLE public.count_alerts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 entry_id uuid,
 rule_id uuid,
 alert_type text NOT NULL,
 severity text NOT NULL CHECK(severity IN ('info','warning','critical')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','acknowledged','resolved','false_positive')),
 title text NOT NULL,
 details jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 acknowledged_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 acknowledged_at timestamptz,
 resolved_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 resolved_at timestamptz,
 CONSTRAINT count_alert_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_alert_entry_project_fkey FOREIGN KEY(entry_id,project_id)
  REFERENCES public.count_entries(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_alert_rule_project_fkey FOREIGN KEY(rule_id,project_id)
  REFERENCES public.count_anomaly_rules(id,project_id) ON DELETE RESTRICT
);
CREATE INDEX count_alerts_open_idx ON public.count_alerts(project_id,session_id,severity,created_at DESC)
 WHERE status IN ('open','acknowledged');

CREATE TABLE public.count_devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 member_id uuid NOT NULL,
 device_id text NOT NULL,
 device_label text,
 platform text,
 app_version text,
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','revoked')),
 first_seen_at timestamptz NOT NULL DEFAULT now(),
 last_seen_at timestamptz NOT NULL DEFAULT now(),
 revoked_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 revoked_at timestamptz,
 CONSTRAINT count_devices_member_project_fkey FOREIGN KEY(member_id,project_id)
  REFERENCES public.count_members(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_devices_project_device_uq UNIQUE(project_id,device_id),
 CONSTRAINT count_devices_id_project_uq UNIQUE(id,project_id)
);
CREATE INDEX count_devices_member_idx ON public.count_devices(member_id,status,last_seen_at DESC);

CREATE TABLE public.count_presence (
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 member_id uuid NOT NULL,
 device_id text NOT NULL,
 presence_state text NOT NULL DEFAULT 'online' CHECK(presence_state IN ('online','idle','offline')),
 current_location_id uuid,
 started_at timestamptz NOT NULL DEFAULT now(),
 last_seen_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(session_id,member_id,device_id),
 CONSTRAINT count_presence_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE CASCADE,
 CONSTRAINT count_presence_member_project_fkey FOREIGN KEY(member_id,project_id)
  REFERENCES public.count_members(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_presence_location_project_fkey FOREIGN KEY(current_location_id,project_id)
  REFERENCES public.count_locations(id,project_id) ON DELETE RESTRICT
);
CREATE INDEX count_presence_live_idx ON public.count_presence(project_id,session_id,presence_state,last_seen_at DESC);

CREATE TABLE public.count_exports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 session_id uuid NOT NULL,
 requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 export_format text NOT NULL CHECK(export_format IN ('xlsx','csv','pdf')),
 export_scope text NOT NULL DEFAULT 'full' CHECK(export_scope IN ('full','summary','variance')),
 status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','ready','failed','expired')),
 storage_path text,
 row_count bigint NOT NULL DEFAULT 0,
 file_size_bytes bigint,
 sha256 text,
 error_message text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 expires_at timestamptz,
 CONSTRAINT count_exports_session_project_fkey FOREIGN KEY(session_id,project_id)
  REFERENCES public.count_sessions(id,project_id) ON DELETE RESTRICT,
 CONSTRAINT count_exports_path_uq UNIQUE(storage_path)
);
CREATE INDEX count_exports_session_idx ON public.count_exports(project_id,session_id,created_at DESC);

CREATE TABLE public.count_import_mappings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid NOT NULL REFERENCES public.count_projects(id) ON DELETE RESTRICT,
 name text NOT NULL,
 source_format text NOT NULL CHECK(source_format IN ('csv','xlsx')),
 column_mapping jsonb NOT NULL,
 is_default boolean NOT NULL DEFAULT false,
 created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT count_import_mapping_name_uq UNIQUE(project_id,name)
);

```

---

## 20261119182153 — countflow_enterprise_security_storage_v1

- Statements: 1
- SQL characters: 10544
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.can_access_recount_task(p_project uuid, p_member uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.count_members m
  WHERE m.project_id=p_project AND m.user_id=(SELECT auth.uid()) AND m.status='active'
   AND (m.role='supervisor' OR m.id=p_member)
 );
$$;
GRANT EXECUTE ON FUNCTION counting_private.can_access_recount_task(uuid,uuid) TO authenticated;
REVOKE ALL ON FUNCTION counting_private.can_access_recount_task(uuid,uuid) FROM anon, public;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'count_import_rows','count_expected_balances','count_reconciliation_runs',
  'count_reconciliation_lines','count_recount_tasks','count_entry_images',
  'count_anomaly_rules','count_alerts','count_devices','count_presence',
  'count_exports','count_import_mappings'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;

CREATE POLICY count_import_rows_read ON public.count_import_rows FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_import_rows_insert ON public.count_import_rows FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_import_rows_update ON public.count_import_rows FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_import_rows_delete ON public.count_import_rows FOR DELETE TO authenticated
 USING(counting_private.is_supervisor(project_id));

CREATE POLICY count_expected_read ON public.count_expected_balances FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_expected_insert ON public.count_expected_balances FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_expected_update ON public.count_expected_balances FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_expected_delete ON public.count_expected_balances FOR DELETE TO authenticated
 USING(counting_private.is_supervisor(project_id));

CREATE POLICY count_recon_runs_read ON public.count_reconciliation_runs FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_recon_runs_insert ON public.count_reconciliation_runs FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id) AND created_by=(SELECT auth.uid()));
CREATE POLICY count_recon_runs_update ON public.count_reconciliation_runs FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));

CREATE POLICY count_recon_lines_read ON public.count_reconciliation_lines FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_recon_lines_insert ON public.count_reconciliation_lines FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id));

CREATE POLICY count_recount_tasks_read ON public.count_recount_tasks FOR SELECT TO authenticated
 USING(counting_private.can_access_recount_task(project_id,assigned_member_id));
CREATE POLICY count_recount_tasks_insert ON public.count_recount_tasks FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id) AND created_by=(SELECT auth.uid()));
CREATE POLICY count_recount_tasks_update ON public.count_recount_tasks FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_recount_tasks_delete ON public.count_recount_tasks FOR DELETE TO authenticated
 USING(counting_private.is_supervisor(project_id));

CREATE POLICY count_entry_images_read ON public.count_entry_images FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id) OR uploaded_by=(SELECT auth.uid()));
CREATE POLICY count_entry_images_insert ON public.count_entry_images FOR INSERT TO authenticated
 WITH CHECK(
  uploaded_by=(SELECT auth.uid())
  AND EXISTS(
   SELECT 1 FROM public.count_entries e
   JOIN public.count_members m ON m.id=e.member_id
   WHERE e.id=entry_id AND e.project_id=count_entry_images.project_id
    AND m.user_id=(SELECT auth.uid()) AND m.status='active'
  )
 );

CREATE POLICY count_anomaly_rules_read ON public.count_anomaly_rules FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_anomaly_rules_insert ON public.count_anomaly_rules FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id) AND created_by=(SELECT auth.uid()));
CREATE POLICY count_anomaly_rules_update ON public.count_anomaly_rules FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_anomaly_rules_delete ON public.count_anomaly_rules FOR DELETE TO authenticated
 USING(counting_private.is_supervisor(project_id));

CREATE POLICY count_alerts_read ON public.count_alerts FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_alerts_update ON public.count_alerts FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));

CREATE POLICY count_devices_read ON public.count_devices FOR SELECT TO authenticated
 USING(
  counting_private.is_supervisor(project_id)
  OR EXISTS(SELECT 1 FROM public.count_members m WHERE m.id=member_id
    AND m.project_id=count_devices.project_id AND m.user_id=(SELECT auth.uid()))
 );
CREATE POLICY count_devices_update ON public.count_devices FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));

CREATE POLICY count_presence_read ON public.count_presence FOR SELECT TO authenticated
 USING(
  counting_private.is_supervisor(project_id)
  OR EXISTS(SELECT 1 FROM public.count_members m WHERE m.id=member_id
    AND m.project_id=count_presence.project_id AND m.user_id=(SELECT auth.uid()))
 );

CREATE POLICY count_exports_read ON public.count_exports FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_exports_insert ON public.count_exports FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id) AND requested_by=(SELECT auth.uid()));
CREATE POLICY count_exports_update ON public.count_exports FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));

CREATE POLICY count_import_mappings_read ON public.count_import_mappings FOR SELECT TO authenticated
 USING(counting_private.is_supervisor(project_id));
CREATE POLICY count_import_mappings_insert ON public.count_import_mappings FOR INSERT TO authenticated
 WITH CHECK(counting_private.is_supervisor(project_id) AND created_by=(SELECT auth.uid()));
CREATE POLICY count_import_mappings_update ON public.count_import_mappings FOR UPDATE TO authenticated
 USING(counting_private.is_supervisor(project_id)) WITH CHECK(counting_private.is_supervisor(project_id));
CREATE POLICY count_import_mappings_delete ON public.count_import_mappings FOR DELETE TO authenticated
 USING(counting_private.is_supervisor(project_id));

GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE
 public.count_import_rows,public.count_expected_balances,
 public.count_reconciliation_runs,public.count_reconciliation_lines,
 public.count_recount_tasks,public.count_entry_images,
 public.count_anomaly_rules,public.count_alerts,public.count_devices,
 public.count_presence,public.count_exports,public.count_import_mappings
TO authenticated;

REVOKE ALL ON TABLE
 public.count_import_rows,public.count_expected_balances,
 public.count_reconciliation_runs,public.count_reconciliation_lines,
 public.count_recount_tasks,public.count_entry_images,
 public.count_anomaly_rules,public.count_alerts,public.count_devices,
 public.count_presence,public.count_exports,public.count_import_mappings
FROM anon,PUBLIC;

CREATE UNIQUE INDEX count_assignments_global_scope_uq
 ON public.count_assignments(session_id,member_id) WHERE location_id IS NULL;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES
 ('counting-evidence','counting-evidence',false,5242880,ARRAY['image/jpeg','image/png','image/webp']),
 ('counting-exports','counting-exports',false,52428800,ARRAY['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv','application/pdf'])
ON CONFLICT(id) DO NOTHING;

CREATE POLICY count_evidence_read ON storage.objects FOR SELECT TO authenticated
 USING(
  bucket_id='counting-evidence'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_member(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );
CREATE POLICY count_evidence_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(
  bucket_id='counting-evidence'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_member(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );
CREATE POLICY count_evidence_delete_supervisor ON storage.objects FOR DELETE TO authenticated
 USING(
  bucket_id='counting-evidence'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );

CREATE POLICY count_exports_storage_read ON storage.objects FOR SELECT TO authenticated
 USING(
  bucket_id='counting-exports'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );
CREATE POLICY count_exports_storage_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(
  bucket_id='counting-exports'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );
CREATE POLICY count_exports_storage_delete ON storage.objects FOR DELETE TO authenticated
 USING(
  bucket_id='counting-exports'
  AND CASE WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
    ELSE false END
 );

```

---

## 20261119182705 — countflow_import_pipeline_v1

- Statements: 1
- SQL characters: 13702
- Rollback recorded: NO

### Statement 1

```sql

ALTER TABLE public.count_import_batches
 ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.count_sessions
 ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION counting_private.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
 NEW.updated_at = now();
 RETURN NEW;
END;
$$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'count_products','count_projects','count_import_batches','count_sessions',
  'count_expected_balances','count_anomaly_rules','count_import_mappings'
 ] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',t||'_touch_updated_at',t);
  EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION counting_private.touch_updated_at()',t||'_touch_updated_at',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.count_create_import_batch(
 p_project_id uuid,
 p_session_id uuid,
 p_source_name text,
 p_source_format text DEFAULT 'csv',
 p_source_checksum text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE v_id uuid;
BEGIN
 IF NOT counting_private.is_supervisor(p_project_id) THEN
  RAISE EXCEPTION 'SUPERVISOR_REQUIRED';
 END IF;
 IF nullif(btrim(p_source_name),'') IS NULL OR p_source_format NOT IN ('csv','xlsx','json') THEN
  RAISE EXCEPTION 'INVALID_IMPORT_METADATA';
 END IF;
 IF p_session_id IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.count_sessions s
  WHERE s.id=p_session_id AND s.project_id=p_project_id
    AND s.status IN ('planned','active','paused','review')
 ) THEN
  RAISE EXCEPTION 'INVALID_IMPORT_SESSION';
 END IF;
 INSERT INTO public.count_import_batches(
  project_id,imported_by,source_name,row_count,accepted_count,rejected_count,
  status,error_report,session_id,source_format,source_checksum
 ) VALUES(
  p_project_id,(SELECT auth.uid()),btrim(p_source_name),0,0,0,
  'uploading','{}'::jsonb,p_session_id,p_source_format,p_source_checksum
 ) RETURNING id INTO v_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(p_project_id,(SELECT auth.uid()),'import.created','import_batch',v_id,
  jsonb_build_object('source_name',p_source_name,'source_format',p_source_format,'session_id',p_session_id));
 RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.count_stage_import_rows(
 p_batch_id uuid,
 p_rows jsonb,
 p_row_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE v_batch public.count_import_batches; v_inserted integer; v_rejected integer; v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 WITH src AS (
  SELECT value AS r, ordinality::integer AS ord
  FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 ),
 norm AS (
  SELECT r,ord,
   coalesce(nullif(btrim(r->>'sku'),''),nullif(btrim(r->>'item_code'),''),nullif(btrim(r->>'كود الصنف'),'')) AS sku,
   coalesce(nullif(btrim(r->>'barcode'),''),nullif(btrim(r->>'باركود'),'')) AS barcode,
   coalesce(nullif(btrim(r->>'name'),''),nullif(btrim(r->>'product_name'),''),nullif(btrim(r->>'اسم الصنف'),'')) AS product_name,
   coalesce(nullif(btrim(r->>'category'),''),nullif(btrim(r->>'الفئة'),'')) AS category,
   coalesce(nullif(btrim(r->>'base_unit'),''),nullif(btrim(r->>'unit'),''),nullif(btrim(r->>'الوحدة'),'')) AS base_unit,
   CASE WHEN jsonb_typeof(r->'units')='array' THEN r->'units' ELSE '[]'::jsonb END AS units,
   coalesce(nullif(btrim(r->>'expected_qty'),''),nullif(btrim(r->>'expected_quantity'),''),nullif(btrim(r->>'الكمية الدفترية'),'')) AS expected_text,
   coalesce(nullif(btrim(r->>'location_code'),''),nullif(btrim(r->>'الموقع'),'')) AS location_code,
   CASE WHEN coalesce(r->>'_row_number','') ~ '^[0-9]+$' THEN (r->>'_row_number')::integer ELSE p_row_offset+ord::integer END AS row_number
  FROM src
 ),
 prepared AS (
  SELECT n.*,
   CASE WHEN expected_text IS NULL THEN NULL
    WHEN expected_text ~ '^[0-9]+([.][0-9]{1,4})?$' THEN expected_text::numeric
    ELSE NULL END AS expected_quantity,
   CASE WHEN jsonb_typeof(r)='object' THEN ARRAY[]::text[] ELSE ARRAY['INVALID_ROW_SHAPE']::text[] END
   || CASE WHEN sku IS NULL THEN ARRAY['MISSING_SKU']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN product_name IS NULL THEN ARRAY['MISSING_PRODUCT_NAME']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN base_unit IS NULL THEN ARRAY['MISSING_BASE_UNIT']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN expected_text IS NOT NULL AND expected_text !~ '^[0-9]+([.][0-9]{1,4})?$' THEN ARRAY['INVALID_EXPECTED_QUANTITY']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN expected_text IS NOT NULL AND expected_text ~ '^[0-9]+([.][0-9]{1,4})?$' AND expected_text::numeric<0 THEN ARRAY['NEGATIVE_EXPECTED_QUANTITY']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN expected_text IS NOT NULL AND v_batch.session_id IS NULL THEN ARRAY['SESSION_REQUIRED_FOR_EXPECTED_QTY']::text[] ELSE ARRAY[]::text[] END
   || CASE WHEN location_code IS NOT NULL AND NOT EXISTS(
       SELECT 1 FROM public.count_locations l WHERE l.project_id=v_batch.project_id AND l.code=prepared_location_code(location_code)
      ) THEN ARRAY['UNKNOWN_LOCATION_CODE']::text[] ELSE ARRAY[]::text[] END
   AS errors
  FROM norm n
 ),
 dedup AS (
  SELECT p.*,
   row_number() OVER(PARTITION BY lower(coalesce(sku,'')) ORDER BY row_number) AS duplicate_rank,
   EXISTS(SELECT 1 FROM public.count_import_rows old
     WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(p.sku)
       AND old.row_number < p.row_number) AS already_staged
  FROM prepared p
 )
 INSERT INTO public.count_import_rows(
  batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
  units,expected_quantity,location_code,row_status,error_codes
 )
 SELECT p_batch_id,v_batch.project_id,row_number,r,sku,barcode,product_name,category,base_unit,
  units,expected_quantity,location_code,
  CASE WHEN cardinality(errors)>0 OR duplicate_rank>1 OR already_staged THEN 'rejected' ELSE 'staged' END,
  CASE WHEN duplicate_rank>1 OR already_staged THEN array_append(errors,'DUPLICATE_SKU_IN_BATCH') ELSE errors END
 FROM dedup
 ON CONFLICT(batch_id,row_number) DO NOTHING;

 GET DIAGNOSTICS v_inserted = ROW_COUNT;
 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0), rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$$;

CREATE OR REPLACE FUNCTION public.count_commit_import_batch(p_batch_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE v_batch public.count_import_batches; v_accepted integer; v_rejected integer; v_expected integer;
BEGIN
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status='committed' THEN
  RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed','accepted_rows',v_batch.accepted_count,'rejected_rows',v_batch.rejected_count,'idempotent',true);
 END IF;
 IF v_batch.status NOT IN ('preview','uploading') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_READY';
 END IF;
 UPDATE public.count_import_batches SET status='committing' WHERE id=p_batch_id;

 UPDATE public.count_import_rows r
 SET row_status='rejected',
     error_codes=array_append(r.error_codes,'AMBIGUOUS_LOCATION_CODE'),
     error_detail=r.error_detail||jsonb_build_object('location_code',r.location_code)
 WHERE r.batch_id=p_batch_id AND r.row_status<>'rejected' AND r.location_code IS NOT NULL
  AND (SELECT count(*) FROM public.count_locations l
       WHERE l.project_id=r.project_id AND l.code=r.location_code)>1;

 UPDATE public.count_import_rows r
 SET row_status='rejected',error_codes=array_append(r.error_codes,'UNKNOWN_LOCATION_CODE')
 WHERE r.batch_id=p_batch_id AND r.row_status<>'rejected' AND r.location_code IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM public.count_locations l
                 WHERE l.project_id=r.project_id AND l.code=r.location_code);

 UPDATE public.count_import_rows r
 SET row_status='rejected',error_codes=array_append(r.error_codes,'SESSION_REQUIRED_FOR_EXPECTED_QTY')
 WHERE r.batch_id=p_batch_id AND r.row_status<>'rejected'
  AND r.expected_quantity IS NOT NULL AND v_batch.session_id IS NULL;

 WITH valid AS (
  SELECT r.*,
   row_number() OVER(PARTITION BY lower(r.sku) ORDER BY r.row_number) AS sku_rank
  FROM public.count_import_rows r
  WHERE r.batch_id=p_batch_id AND r.row_status IN ('staged','accepted')
 )
 UPDATE public.count_import_rows target
 SET row_status='rejected',error_codes=array_append(target.error_codes,'DUPLICATE_SKU_IN_BATCH')
 FROM valid v
 WHERE target.id=v.id AND v.sku_rank>1;

 INSERT INTO public.count_products(project_id,sku,barcode,name,category,base_unit,units,is_active,updated_at)
 SELECT v_batch.project_id,r.sku,r.barcode,r.product_name,r.category,r.base_unit,r.units,true,now()
 FROM public.count_import_rows r
 WHERE r.batch_id=p_batch_id AND r.row_status IN ('staged','accepted')
 ON CONFLICT(project_id,sku) DO UPDATE SET
  barcode=coalesce(EXCLUDED.barcode,public.count_products.barcode),
  name=EXCLUDED.name,
  category=coalesce(EXCLUDED.category,public.count_products.category),
  base_unit=EXCLUDED.base_unit,
  units=EXCLUDED.units,
  is_active=true,
  updated_at=now();

 UPDATE public.count_import_rows r
 SET product_id=p.id,
     location_id=l.id,
     row_status='accepted',
     processed_at=now()
 FROM public.count_products p
 LEFT JOIN public.count_locations l
  ON l.project_id=v_batch.project_id AND l.code=r.location_code
 WHERE r.batch_id=p_batch_id AND r.row_status IN ('staged','accepted')
  AND p.project_id=r.project_id AND p.sku=r.sku;

 IF v_batch.session_id IS NOT NULL THEN
  INSERT INTO public.count_expected_balances(
   project_id,session_id,product_id,location_id,expected_quantity,unit,source_batch_id,snapshot_at,updated_at
  )
  SELECT v_batch.project_id,v_batch.session_id,r.product_id,r.location_id,r.expected_quantity,
   coalesce(nullif(r.base_unit,''),'وحدة'),p_batch_id,now(),now()
  FROM public.count_import_rows r
  WHERE r.batch_id=p_batch_id AND r.row_status='accepted' AND r.expected_quantity IS NOT NULL
  ON CONFLICT(session_id,product_id,location_id) DO UPDATE SET
   expected_quantity=EXCLUDED.expected_quantity,unit=EXCLUDED.unit,
   source_batch_id=EXCLUDED.source_batch_id,snapshot_at=EXCLUDED.snapshot_at,updated_at=now();
 END IF;

 UPDATE public.count_import_rows
 SET row_status='committed',processed_at=coalesce(processed_at,now())
 WHERE batch_id=p_batch_id AND row_status='accepted';

 SELECT count(*) FILTER(WHERE row_status='committed'),
        count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status='committed' AND expected_quantity IS NOT NULL)
 INTO v_accepted,v_rejected,v_expected
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET status='committed',accepted_count=coalesce(v_accepted,0),
     rejected_count=coalesce(v_rejected,0),completed_at=now(),
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'expected_balance_rows',coalesce(v_expected,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_batch.project_id,(SELECT auth.uid()),'import.committed','import_batch',p_batch_id,
  jsonb_build_object('accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),'expected_balance_rows',coalesce(v_expected,0)));

 RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed',
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0));
EXCEPTION WHEN OTHERS THEN
 UPDATE public.count_import_batches SET status='failed',completed_at=now(),
  error_report=jsonb_build_object('message',SQLERRM),updated_at=now()
 WHERE id=p_batch_id;
 RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.count_create_import_batch(uuid,uuid,text,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.count_commit_import_batch(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.count_create_import_batch(uuid,uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_commit_import_batch(uuid) TO authenticated;

```

---

## 20261119182926 — countflow_import_pipeline_hardening_v1

- Statements: 1
- SQL characters: 9560
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_stage_import_rows(
 p_batch_id uuid,
 p_rows jsonb,
 p_row_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
 v_batch public.count_import_batches;
 v_row jsonb;
 v_ord bigint;
 v_row_number integer;
 v_sku text;
 v_barcode text;
 v_name text;
 v_category text;
 v_unit text;
 v_units jsonb;
 v_expected_text text;
 v_expected numeric(18,4);
 v_location_code text;
 v_location_id uuid;
 v_location_count integer;
 v_errors text[];
 v_inserted integer:=0;
 v_rejected integer;
 v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 IF p_row_offset<0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 FOR v_row,v_ord IN
  SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 LOOP
  v_errors:=ARRAY[]::text[];
  v_expected:=NULL;
  v_location_id:=NULL;
  v_sku:=NULL;v_barcode:=NULL;v_name:=NULL;v_category:=NULL;v_unit:=NULL;
  v_expected_text:=NULL;v_location_code:=NULL;v_units:='[]'::jsonb;

  IF jsonb_typeof(v_row)<>'object' THEN
   v_errors:=array_append(v_errors,'INVALID_ROW_SHAPE');
  ELSE
   v_sku:=coalesce(nullif(btrim(v_row->>'sku'),''),nullif(btrim(v_row->>'item_code'),''),nullif(btrim(v_row->>'كود الصنف'),''));
   v_barcode:=coalesce(nullif(btrim(v_row->>'barcode'),''),nullif(btrim(v_row->>'باركود'),''));
   v_name:=coalesce(nullif(btrim(v_row->>'name'),''),nullif(btrim(v_row->>'product_name'),''),nullif(btrim(v_row->>'اسم الصنف'),''));
   v_category:=coalesce(nullif(btrim(v_row->>'category'),''),nullif(btrim(v_row->>'الفئة'),''));
   v_unit:=coalesce(nullif(btrim(v_row->>'base_unit'),''),nullif(btrim(v_row->>'unit'),''),nullif(btrim(v_row->>'الوحدة'),''));
   v_units:=CASE WHEN jsonb_typeof(v_row->'units')='array' THEN v_row->'units' ELSE '[]'::jsonb END;
   v_expected_text:=coalesce(nullif(btrim(v_row->>'expected_qty'),''),nullif(btrim(v_row->>'expected_quantity'),''),nullif(btrim(v_row->>'الكمية الدفترية'),''));
   v_location_code:=coalesce(nullif(btrim(v_row->>'location_code'),''),nullif(btrim(v_row->>'الموقع'),''));

   IF v_sku IS NULL THEN v_errors:=array_append(v_errors,'MISSING_SKU'); END IF;
   IF v_name IS NULL THEN v_errors:=array_append(v_errors,'MISSING_PRODUCT_NAME'); END IF;
   IF v_unit IS NULL THEN v_errors:=array_append(v_errors,'MISSING_BASE_UNIT'); END IF;

   IF v_expected_text IS NOT NULL THEN
    IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
     v_errors:=array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
    ELSE
     v_expected:=v_expected_text::numeric;
     IF v_expected<0 THEN v_errors:=array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY'); END IF;
     IF v_batch.session_id IS NULL THEN v_errors:=array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY'); END IF;
    END IF;
   END IF;

   IF v_location_code IS NOT NULL THEN
    SELECT count(*),min(id) INTO v_location_count,v_location_id
    FROM public.count_locations
    WHERE project_id=v_batch.project_id AND code=v_location_code;
    IF v_location_count=0 THEN
     v_errors:=array_append(v_errors,'UNKNOWN_LOCATION_CODE');
    ELSIF v_location_count>1 THEN
     v_location_id:=NULL;
     v_errors:=array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
    END IF;
   END IF;

   IF v_sku IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.count_import_rows old
    WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(v_sku)
   ) THEN
    v_errors:=array_append(v_errors,'DUPLICATE_SKU_IN_BATCH');
   END IF;
  END IF;

  IF jsonb_typeof(v_row)='object' AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
   v_row_number:=(v_row->>'_row_number')::integer;
  ELSE
   v_row_number:=p_row_offset+v_ord::integer;
  END IF;
  IF v_row_number<1 THEN RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER'; END IF;

  INSERT INTO public.count_import_rows(
   batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
   units,expected_quantity,location_code,location_id,row_status,error_codes
  ) VALUES(
   p_batch_id,v_batch.project_id,v_row_number,v_row,v_sku,v_barcode,v_name,v_category,v_unit,
   v_units,v_expected,v_location_code,v_location_id,
   CASE WHEN cardinality(v_errors)>0 THEN 'rejected' ELSE 'staged' END,v_errors
  )
  ON CONFLICT(batch_id,row_number) DO NOTHING;
  IF FOUND THEN v_inserted:=v_inserted+1; END IF;
 END LOOP;

 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$$;

CREATE OR REPLACE FUNCTION public.count_commit_import_batch(p_batch_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
 v_batch public.count_import_batches;
 v_accepted integer;
 v_rejected integer;
 v_expected integer;
BEGIN
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status='committed' THEN
  RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed',
   'accepted_rows',v_batch.accepted_count,'rejected_rows',v_batch.rejected_count,'idempotent',true);
 END IF;
 IF v_batch.status<>'preview' THEN RAISE EXCEPTION 'IMPORT_BATCH_NOT_READY'; END IF;
 UPDATE public.count_import_batches SET status='committing' WHERE id=p_batch_id;

 INSERT INTO public.count_products(project_id,sku,barcode,name,category,base_unit,units,is_active,updated_at)
 SELECT v_batch.project_id,r.sku,r.barcode,r.product_name,r.category,r.base_unit,r.units,true,now()
 FROM public.count_import_rows r
 WHERE r.batch_id=p_batch_id AND r.row_status='staged'
 ON CONFLICT(project_id,sku) DO UPDATE SET
  barcode=coalesce(EXCLUDED.barcode,public.count_products.barcode),
  name=EXCLUDED.name,
  category=coalesce(EXCLUDED.category,public.count_products.category),
  base_unit=EXCLUDED.base_unit,
  units=EXCLUDED.units,
  is_active=true,
  updated_at=now();

 UPDATE public.count_import_rows r
 SET product_id=p.id,row_status='accepted',processed_at=now()
 FROM public.count_products p
 WHERE r.batch_id=p_batch_id AND r.row_status='staged'
  AND p.project_id=r.project_id AND p.sku=r.sku;

 IF v_batch.session_id IS NOT NULL THEN
  INSERT INTO public.count_expected_balances(
   project_id,session_id,product_id,location_id,expected_quantity,unit,source_batch_id,snapshot_at,updated_at
  )
  SELECT v_batch.project_id,v_batch.session_id,r.product_id,r.location_id,r.expected_quantity,
   coalesce(nullif(r.base_unit,''),'وحدة'),p_batch_id,now(),now()
  FROM public.count_import_rows r
  WHERE r.batch_id=p_batch_id AND r.row_status='accepted' AND r.expected_quantity IS NOT NULL
  ON CONFLICT(session_id,product_id,location_id) DO UPDATE SET
   expected_quantity=EXCLUDED.expected_quantity,unit=EXCLUDED.unit,
   source_batch_id=EXCLUDED.source_batch_id,snapshot_at=EXCLUDED.snapshot_at,updated_at=now();
 END IF;

 UPDATE public.count_import_rows
 SET row_status='committed',processed_at=coalesce(processed_at,now())
 WHERE batch_id=p_batch_id AND row_status='accepted';

 SELECT count(*) FILTER(WHERE row_status='committed'),
        count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status='committed' AND expected_quantity IS NOT NULL)
 INTO v_accepted,v_rejected,v_expected
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET status='committed',accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
  completed_at=now(),error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0)),updated_at=now()
 WHERE id=p_batch_id;

 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_batch.project_id,(SELECT auth.uid()),'import.committed','import_batch',p_batch_id,
  jsonb_build_object('accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0)));

 RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed',
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0));
EXCEPTION WHEN OTHERS THEN
 UPDATE public.count_import_batches SET status='failed',completed_at=now(),
  error_report=jsonb_build_object('message',SQLERRM),updated_at=now()
 WHERE id=p_batch_id;
 RAISE;
END;
$$;

```

---

## 20261119183711 — countflow_reconciliation_recount_presence_v1

- Statements: 1
- SQL characters: 11261
- Rollback recorded: NO

### Statement 1

```sql

-- CountFlow operational RPC layer: reconciliation, recount work queue, and presence heartbeat.
-- This migration is isolated to count_* objects and never writes to ERP inventory/accounting.

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_run_id uuid;
  v_run_number integer;
BEGIN
  SELECT * INTO v_session
  FROM public.count_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN
    RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION';
  END IF;

  SELECT coalesce(max(run_number),0)+1 INTO v_run_number
  FROM public.count_reconciliation_runs
  WHERE session_id = p_session_id;

  INSERT INTO public.count_reconciliation_runs(
    project_id, session_id, run_number, status, created_by, created_at
  ) VALUES (
    v_session.project_id, p_session_id, v_run_number, 'building', (SELECT auth.uid()), now()
  ) RETURNING id INTO v_run_id;

  WITH expected AS (
    SELECT product_id, location_id, sum(expected_quantity)::numeric AS expected_qty,
           max(unit) AS unit
    FROM public.count_expected_balances
    WHERE session_id = p_session_id
    GROUP BY product_id, location_id
  ),
  counted AS (
    SELECT product_id, location_id, sum(quantity)::numeric AS counted_qty,
           max(unit) AS unit, count(*)::bigint AS events,
           count(DISTINCT member_id)::integer AS counters
    FROM public.count_entries
    WHERE session_id = p_session_id
    GROUP BY product_id, location_id
  ),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,
           coalesce(e.location_id,c.location_id) location_id,
           e.expected_qty, c.counted_qty, coalesce(c.unit,e.unit,'وحدة') unit,
           coalesce(c.events,0) events, coalesce(c.counters,0) counters
    FROM expected e
    FULL OUTER JOIN counted c
      ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*, p.sku, p.name product_name,
           coalesce(l.name,'غير محدد') location_name
    FROM merged m
    JOIN public.count_products p ON p.id=m.product_id
    LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(
    project_id,run_id,session_id,product_id,location_id,product_sku,product_name,
    location_path,unit,expected_quantity,counted_quantity,variance_quantity,
    variance_percent,counted_events,counter_count,result_status,computed_at
  )
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,
         e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
         CASE WHEN e.expected_qty IS NULL THEN NULL
              ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
         CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL
              ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
         e.events,e.counters,
         CASE WHEN e.expected_qty IS NULL THEN 'not_expected'
              WHEN e.counted_qty IS NULL THEN 'not_counted'
              WHEN e.counted_qty=e.expected_qty THEN 'matched'
              WHEN e.counted_qty<e.expected_qty THEN 'under'
              ELSE 'over' END,
         now()
  FROM enriched e;

  UPDATE public.count_reconciliation_runs r
  SET status='computed',
      expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
      counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
      matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
      variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
      uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
      total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      computed_at=now()
  WHERE r.id=v_run_id;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number));

  RETURN v_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_generate_recount_tasks(
  p_run_id uuid,
  p_assigned_member_id uuid DEFAULT NULL,
  p_min_variance_percent numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_created integer := 0;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN
    RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_run.status NOT IN ('computed','approved') THEN
    RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED';
  END IF;
  IF p_min_variance_percent < 0 THEN RAISE EXCEPTION 'INVALID_VARIANCE_THRESHOLD'; END IF;
  IF p_assigned_member_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_members
    WHERE id=p_assigned_member_id AND project_id=v_run.project_id
      AND role IN ('counter','auditor') AND status='active'
  ) THEN RAISE EXCEPTION 'INVALID_RECOUNT_ASSIGNEE'; END IF;

  INSERT INTO public.count_recount_tasks(
    project_id,session_id,reconciliation_line_id,product_id,location_id,
    assigned_member_id,status,reason,first_count_quantity,variance_percent,created_by,assigned_at
  )
  SELECT v_run.project_id,v_run.session_id,l.id,l.product_id,l.location_id,
    p_assigned_member_id,
    CASE WHEN p_assigned_member_id IS NULL THEN 'pending' ELSE 'assigned' END,
    CASE l.result_status WHEN 'not_counted' THEN 'Expected item not counted'
      WHEN 'under' THEN 'Count below expected balance'
      WHEN 'over' THEN 'Count above expected balance' END,
    l.counted_quantity,l.variance_percent,(SELECT auth.uid()),
    CASE WHEN p_assigned_member_id IS NULL THEN NULL ELSE now() END
  FROM public.count_reconciliation_lines l
  WHERE l.run_id=p_run_id
    AND l.result_status IN ('not_counted','under','over')
    AND (l.variance_percent IS NULL OR abs(l.variance_percent)>=p_min_variance_percent)
  ON CONFLICT(session_id,reconciliation_line_id) DO NOTHING;

  GET DIAGNOSTICS v_created = ROW_COUNT;
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'recount.tasks_created','reconciliation_run',p_run_id,
    jsonb_build_object('created',v_created,'assigned_member_id',p_assigned_member_id,
      'minimum_variance_percent',p_min_variance_percent));

  RETURN jsonb_build_object('run_id',p_run_id,'created_tasks',v_created);
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_touch_presence(
  p_session_id uuid,
  p_device_id text,
  p_device_label text DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL,
  p_state text DEFAULT 'online',
  p_location_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_member public.count_members;
BEGIN
  IF nullif(btrim(p_device_id),'') IS NULL OR p_state NOT IN ('online','idle','offline') THEN
    RAISE EXCEPTION 'INVALID_PRESENCE_PAYLOAD';
  END IF;
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
  IF NOT FOUND OR v_session.status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE';
  END IF;
  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND THEN RAISE EXCEPTION 'MEMBER_NOT_ACTIVE'; END IF;
  IF p_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
  ) THEN RAISE EXCEPTION 'INVALID_PRESENCE_LOCATION'; END IF;

  INSERT INTO public.count_devices(project_id,member_id,device_id,device_label,platform,app_version,status,last_seen_at)
  VALUES(v_session.project_id,v_member.id,p_device_id,p_device_label,p_platform,p_app_version,'active',now())
  ON CONFLICT(project_id,device_id) DO UPDATE SET
    member_id=EXCLUDED.member_id,device_label=coalesce(EXCLUDED.device_label,public.count_devices.device_label),
    platform=coalesce(EXCLUDED.platform,public.count_devices.platform),
    app_version=coalesce(EXCLUDED.app_version,public.count_devices.app_version),
    status='active',last_seen_at=now()
  WHERE public.count_devices.status='active';

  INSERT INTO public.count_presence(project_id,session_id,member_id,device_id,presence_state,current_location_id,started_at,last_seen_at)
  VALUES(v_session.project_id,p_session_id,v_member.id,p_device_id,p_state,p_location_id,now(),now())
  ON CONFLICT(session_id,member_id,device_id) DO UPDATE SET
    presence_state=EXCLUDED.presence_state,current_location_id=EXCLUDED.current_location_id,last_seen_at=now();

  UPDATE public.count_members SET last_seen_at=now() WHERE id=v_member.id;

  RETURN jsonb_build_object('ok',true,'member_id',v_member.id,'session_id',p_session_id,'last_seen_at',now());
END;
$function$;

GRANT EXECUTE ON FUNCTION public.count_reconcile_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_generate_recount_tasks(uuid,uuid,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_touch_presence(uuid,text,text,text,text,text,uuid) TO authenticated;

GRANT INSERT, UPDATE ON public.count_presence TO authenticated;
DROP POLICY IF EXISTS count_presence_write_self_insert ON public.count_presence;
CREATE POLICY count_presence_write_self_insert ON public.count_presence
FOR INSERT TO authenticated
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=project_id AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);
DROP POLICY IF EXISTS count_presence_write_self_update ON public.count_presence;
CREATE POLICY count_presence_write_self_update ON public.count_presence
FOR UPDATE TO authenticated
USING (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=project_id AND m.user_id=(SELECT auth.uid()) AND m.status='active')
)
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=project_id AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);

```

---

## 20261119183721 — countflow_presence_rls_self_scope_fix

- Statements: 1
- SQL characters: 4881
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_touch_presence(
  p_session_id uuid,
  p_device_id text,
  p_device_label text DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL,
  p_state text DEFAULT 'online',
  p_location_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_member public.count_members;
BEGIN
  IF nullif(btrim(p_device_id),'') IS NULL OR p_state NOT IN ('online','idle','offline') THEN
    RAISE EXCEPTION 'INVALID_PRESENCE_PAYLOAD';
  END IF;
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
  IF NOT FOUND OR v_session.status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE';
  END IF;
  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND THEN RAISE EXCEPTION 'MEMBER_NOT_ACTIVE'; END IF;
  IF p_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
  ) THEN RAISE EXCEPTION 'INVALID_PRESENCE_LOCATION'; END IF;

  INSERT INTO public.count_devices(project_id,member_id,device_id,device_label,platform,app_version,status,last_seen_at)
  VALUES(v_session.project_id,v_member.id,p_device_id,p_device_label,p_platform,p_app_version,'active',now())
  ON CONFLICT(project_id,device_id) DO UPDATE SET
    device_label=coalesce(EXCLUDED.device_label,public.count_devices.device_label),
    platform=coalesce(EXCLUDED.platform,public.count_devices.platform),
    app_version=coalesce(EXCLUDED.app_version,public.count_devices.app_version),
    last_seen_at=now()
  WHERE public.count_devices.member_id=v_member.id AND public.count_devices.status='active';

  IF NOT EXISTS (SELECT 1 FROM public.count_devices d
    WHERE d.project_id=v_session.project_id AND d.device_id=p_device_id
      AND d.member_id=v_member.id AND d.status='active') THEN
    RAISE EXCEPTION 'DEVICE_REVOKED_OR_OWNED_BY_ANOTHER_MEMBER';
  END IF;

  INSERT INTO public.count_presence(project_id,session_id,member_id,device_id,presence_state,current_location_id,started_at,last_seen_at)
  VALUES(v_session.project_id,p_session_id,v_member.id,p_device_id,p_state,p_location_id,now(),now())
  ON CONFLICT(session_id,member_id,device_id) DO UPDATE SET
    presence_state=EXCLUDED.presence_state,current_location_id=EXCLUDED.current_location_id,last_seen_at=now();

  RETURN jsonb_build_object('ok',true,'member_id',v_member.id,'session_id',p_session_id,'last_seen_at',now());
END;
$function$;

GRANT INSERT, UPDATE ON public.count_devices TO authenticated;
DROP POLICY IF EXISTS count_devices_write_self_insert ON public.count_devices;
CREATE POLICY count_devices_write_self_insert ON public.count_devices
FOR INSERT TO authenticated
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_devices.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);
DROP POLICY IF EXISTS count_devices_write_self_update ON public.count_devices;
CREATE POLICY count_devices_write_self_update ON public.count_devices
FOR UPDATE TO authenticated
USING (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_devices.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
)
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_devices.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);

DROP POLICY IF EXISTS count_presence_write_self_insert ON public.count_presence;
CREATE POLICY count_presence_write_self_insert ON public.count_presence
FOR INSERT TO authenticated
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_presence.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);
DROP POLICY IF EXISTS count_presence_write_self_update ON public.count_presence;
CREATE POLICY count_presence_write_self_update ON public.count_presence
FOR UPDATE TO authenticated
USING (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_presence.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
)
WITH CHECK (
  counting_private.is_member(project_id)
  AND EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=member_id AND m.project_id=count_presence.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
);

```

---

## 20261119183927 — countflow_import_image_and_presence_stream_v1

- Statements: 1
- SQL characters: 10273
- Rollback recorded: NO

### Statement 1

```sql
ALTER TABLE public.count_import_rows ADD COLUMN IF NOT EXISTS image_url text;
CREATE OR REPLACE FUNCTION public.count_stage_import_rows(p_batch_id uuid, p_rows jsonb, p_row_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.count_import_batches;
 v_row jsonb;
 v_ord bigint;
 v_row_number integer;
 v_sku text;
 v_barcode text;
 v_name text;
 v_category text;
 v_unit text;
 v_units jsonb;
 v_image_url text;
 v_expected_text text;
 v_expected numeric(18,4);
 v_location_code text;
 v_location_id uuid;
 v_location_count integer;
 v_errors text[];
 v_inserted integer:=0;
 v_rejected integer;
 v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 IF p_row_offset<0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 FOR v_row,v_ord IN
  SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 LOOP
  v_errors:=ARRAY[]::text[];
  v_expected:=NULL;
  v_location_id:=NULL;
  v_sku:=NULL;v_barcode:=NULL;v_name:=NULL;v_category:=NULL;v_unit:=NULL;
  v_expected_text:=NULL;v_location_code:=NULL;v_units:='[]'::jsonb;v_image_url:=NULL;

  IF jsonb_typeof(v_row)<>'object' THEN
   v_errors:=array_append(v_errors,'INVALID_ROW_SHAPE');
  ELSE
   v_sku:=coalesce(nullif(btrim(v_row->>'sku'),''),nullif(btrim(v_row->>'item_code'),''),nullif(btrim(v_row->>'كود الصنف'),''));
   v_barcode:=coalesce(nullif(btrim(v_row->>'barcode'),''),nullif(btrim(v_row->>'باركود'),''));
   v_name:=coalesce(nullif(btrim(v_row->>'name'),''),nullif(btrim(v_row->>'product_name'),''),nullif(btrim(v_row->>'اسم الصنف'),''));
   v_category:=coalesce(nullif(btrim(v_row->>'category'),''),nullif(btrim(v_row->>'الفئة'),''));
   v_unit:=coalesce(nullif(btrim(v_row->>'base_unit'),''),nullif(btrim(v_row->>'unit'),''),nullif(btrim(v_row->>'الوحدة'),''));
   v_units:=CASE WHEN jsonb_typeof(v_row->'units')='array' THEN v_row->'units' ELSE '[]'::jsonb END;
   v_expected_text:=coalesce(nullif(btrim(v_row->>'expected_qty'),''),nullif(btrim(v_row->>'expected_quantity'),''),nullif(btrim(v_row->>'الكمية الدفترية'),''));
   v_location_code:=coalesce(nullif(btrim(v_row->>'location_code'),''),nullif(btrim(v_row->>'الموقع'),''));
   v_image_url:=coalesce(nullif(btrim(v_row->>'image_url'),''),nullif(btrim(v_row->>'رابط الصورة'),''));
   IF length(v_image_url)>2048 OR v_image_url ~ '^http://' THEN v_errors:=array_append(v_errors,'INVALID_IMAGE_REFERENCE'); END IF;

   IF v_sku IS NULL THEN v_errors:=array_append(v_errors,'MISSING_SKU'); END IF;
   IF v_name IS NULL THEN v_errors:=array_append(v_errors,'MISSING_PRODUCT_NAME'); END IF;
   IF v_unit IS NULL THEN v_errors:=array_append(v_errors,'MISSING_BASE_UNIT'); END IF;

   IF v_expected_text IS NOT NULL THEN
    IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
     v_errors:=array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
    ELSE
     v_expected:=v_expected_text::numeric;
     IF v_expected<0 THEN v_errors:=array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY'); END IF;
     IF v_batch.session_id IS NULL THEN v_errors:=array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY'); END IF;
    END IF;
   END IF;

   IF v_location_code IS NOT NULL THEN
    SELECT count(*),min(id) INTO v_location_count,v_location_id
    FROM public.count_locations
    WHERE project_id=v_batch.project_id AND code=v_location_code;
    IF v_location_count=0 THEN
     v_errors:=array_append(v_errors,'UNKNOWN_LOCATION_CODE');
    ELSIF v_location_count>1 THEN
     v_location_id:=NULL;
     v_errors:=array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
    END IF;
   END IF;

   IF v_sku IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.count_import_rows old
    WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(v_sku)
   ) THEN
    v_errors:=array_append(v_errors,'DUPLICATE_SKU_IN_BATCH');
   END IF;
  END IF;

  IF jsonb_typeof(v_row)='object' AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
   v_row_number:=(v_row->>'_row_number')::integer;
  ELSE
   v_row_number:=p_row_offset+v_ord::integer;
  END IF;
  IF v_row_number<1 THEN RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER'; END IF;

  INSERT INTO public.count_import_rows(
   batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
   units,image_url,expected_quantity,location_code,location_id,row_status,error_codes
  ) VALUES(
   p_batch_id,v_batch.project_id,v_row_number,v_row,v_sku,v_barcode,v_name,v_category,v_unit,
   v_units,v_image_url,v_expected,v_location_code,v_location_id,
   CASE WHEN cardinality(v_errors)>0 THEN 'rejected' ELSE 'staged' END,v_errors
  )
  ON CONFLICT(batch_id,row_number) DO NOTHING;
  IF FOUND THEN v_inserted:=v_inserted+1; END IF;
 END LOOP;

 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$function$
;
CREATE OR REPLACE FUNCTION public.count_commit_import_batch(p_batch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.count_import_batches;
 v_accepted integer;
 v_rejected integer;
 v_expected integer;
BEGIN
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status='committed' THEN
  RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed',
   'accepted_rows',v_batch.accepted_count,'rejected_rows',v_batch.rejected_count,'idempotent',true);
 END IF;
 IF v_batch.status<>'preview' THEN RAISE EXCEPTION 'IMPORT_BATCH_NOT_READY'; END IF;
 UPDATE public.count_import_batches SET status='committing' WHERE id=p_batch_id;

 INSERT INTO public.count_products(project_id,sku,barcode,name,category,base_unit,units,image_url,is_active,updated_at)
 SELECT v_batch.project_id,r.sku,r.barcode,r.product_name,r.category,r.base_unit,r.units,r.image_url,true,now()
 FROM public.count_import_rows r
 WHERE r.batch_id=p_batch_id AND r.row_status='staged'
 ON CONFLICT(project_id,sku) DO UPDATE SET
  barcode=coalesce(EXCLUDED.barcode,public.count_products.barcode),
  name=EXCLUDED.name,
  category=coalesce(EXCLUDED.category,public.count_products.category),
  base_unit=EXCLUDED.base_unit,
  units=EXCLUDED.units,
  image_url=coalesce(EXCLUDED.image_url,public.count_products.image_url),
  is_active=true,
  updated_at=now();

 UPDATE public.count_import_rows r
 SET product_id=p.id,row_status='accepted',processed_at=now()
 FROM public.count_products p
 WHERE r.batch_id=p_batch_id AND r.row_status='staged'
  AND p.project_id=r.project_id AND p.sku=r.sku;

 IF v_batch.session_id IS NOT NULL THEN
  INSERT INTO public.count_expected_balances(
   project_id,session_id,product_id,location_id,expected_quantity,unit,source_batch_id,snapshot_at,updated_at
  )
  SELECT v_batch.project_id,v_batch.session_id,r.product_id,r.location_id,r.expected_quantity,
   coalesce(nullif(r.base_unit,''),'وحدة'),p_batch_id,now(),now()
  FROM public.count_import_rows r
  WHERE r.batch_id=p_batch_id AND r.row_status='accepted' AND r.expected_quantity IS NOT NULL
  ON CONFLICT(session_id,product_id,location_id) DO UPDATE SET
   expected_quantity=EXCLUDED.expected_quantity,unit=EXCLUDED.unit,
   source_batch_id=EXCLUDED.source_batch_id,snapshot_at=EXCLUDED.snapshot_at,updated_at=now();
 END IF;

 UPDATE public.count_import_rows
 SET row_status='committed',processed_at=coalesce(processed_at,now())
 WHERE batch_id=p_batch_id AND row_status='accepted';

 SELECT count(*) FILTER(WHERE row_status='committed'),
        count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status='committed' AND expected_quantity IS NOT NULL)
 INTO v_accepted,v_rejected,v_expected
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET status='committed',accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
  completed_at=now(),error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0)),updated_at=now()
 WHERE id=p_batch_id;

 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_batch.project_id,(SELECT auth.uid()),'import.committed','import_batch',p_batch_id,
  jsonb_build_object('accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0)));

 RETURN jsonb_build_object('batch_id',p_batch_id,'status','committed',
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0),
  'expected_balance_rows',coalesce(v_expected,0));
EXCEPTION WHEN OTHERS THEN
 UPDATE public.count_import_batches SET status='failed',completed_at=now(),
  error_report=jsonb_build_object('message',SQLERRM),updated_at=now()
 WHERE id=p_batch_id;
 RAISE;
END;
$function$
;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='count_presence') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.count_presence; END IF; END $$;
```

---

## 20261119184026 — countflow_fk_indexes_and_device_policy_consolidation

- Statements: 1
- SQL characters: 1983
- Rollback recorded: NO

### Statement 1

```sql

-- Remove overlapping UPDATE policies while preserving supervisor administration and member-owned device heartbeat.
DROP POLICY IF EXISTS count_devices_write_self_update ON public.count_devices;
DROP POLICY IF EXISTS count_devices_update ON public.count_devices;
CREATE POLICY count_devices_update ON public.count_devices
FOR UPDATE TO authenticated
USING (
  counting_private.is_supervisor(project_id)
  OR (
    counting_private.is_member(project_id)
    AND EXISTS (SELECT 1 FROM public.count_members m
      WHERE m.id=count_devices.member_id
        AND m.project_id=count_devices.project_id
        AND m.user_id=(SELECT auth.uid()) AND m.status='active')
  )
)
WITH CHECK (
  counting_private.is_supervisor(project_id)
  OR (
    counting_private.is_member(project_id)
    AND EXISTS (SELECT 1 FROM public.count_members m
      WHERE m.id=count_devices.member_id
        AND m.project_id=count_devices.project_id
        AND m.user_id=(SELECT auth.uid()) AND m.status='active')
  )
);

-- Cover every remaining count_* foreign key with a leading-column index.
DO $$
DECLARE
  fk record;
  idx_name text;
  cols text;
BEGIN
  FOR fk IN
    SELECT c.oid,c.conrelid,c.conname,c.conkey
    FROM pg_constraint c
    JOIN pg_class t ON t.oid=c.conrelid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE c.contype='f' AND n.nspname='public' AND t.relname LIKE 'count_%'
      AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid=c.conrelid
          AND (i.indkey::smallint[])[0:array_length(c.conkey,1)-1] = c.conkey
      )
  LOOP
    SELECT string_agg(format('%I',a.attname),', ' ORDER BY u.ord)
    INTO cols
    FROM unnest(fk.conkey) WITH ORDINALITY u(attnum,ord)
    JOIN pg_attribute a ON a.attrelid=fk.conrelid AND a.attnum=u.attnum;
    idx_name := 'count_fk_' || substr(md5(fk.conrelid::text || ':' || fk.conname),1,16);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %s (%s)',idx_name,fk.conrelid::regclass,cols);
  END LOOP;
END $$;

```

---

## 20261119184103 — countflow_import_uuid_location_lookup_fix

- Statements: 1
- SQL characters: 5897
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION public.count_stage_import_rows(p_batch_id uuid, p_rows jsonb, p_row_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.count_import_batches;
 v_row jsonb;
 v_ord bigint;
 v_row_number integer;
 v_sku text;
 v_barcode text;
 v_name text;
 v_category text;
 v_unit text;
 v_units jsonb;
 v_image_url text;
 v_expected_text text;
 v_expected numeric(18,4);
 v_location_code text;
 v_location_id uuid;
 v_location_count integer;
 v_errors text[];
 v_inserted integer:=0;
 v_rejected integer;
 v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 IF p_row_offset<0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 FOR v_row,v_ord IN
  SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 LOOP
  v_errors:=ARRAY[]::text[];
  v_expected:=NULL;
  v_location_id:=NULL;
  v_sku:=NULL;v_barcode:=NULL;v_name:=NULL;v_category:=NULL;v_unit:=NULL;
  v_expected_text:=NULL;v_location_code:=NULL;v_units:='[]'::jsonb;v_image_url:=NULL;

  IF jsonb_typeof(v_row)<>'object' THEN
   v_errors:=array_append(v_errors,'INVALID_ROW_SHAPE');
  ELSE
   v_sku:=coalesce(nullif(btrim(v_row->>'sku'),''),nullif(btrim(v_row->>'item_code'),''),nullif(btrim(v_row->>'كود الصنف'),''));
   v_barcode:=coalesce(nullif(btrim(v_row->>'barcode'),''),nullif(btrim(v_row->>'باركود'),''));
   v_name:=coalesce(nullif(btrim(v_row->>'name'),''),nullif(btrim(v_row->>'product_name'),''),nullif(btrim(v_row->>'اسم الصنف'),''));
   v_category:=coalesce(nullif(btrim(v_row->>'category'),''),nullif(btrim(v_row->>'الفئة'),''));
   v_unit:=coalesce(nullif(btrim(v_row->>'base_unit'),''),nullif(btrim(v_row->>'unit'),''),nullif(btrim(v_row->>'الوحدة'),''));
   v_units:=CASE WHEN jsonb_typeof(v_row->'units')='array' THEN v_row->'units' ELSE '[]'::jsonb END;
   v_expected_text:=coalesce(nullif(btrim(v_row->>'expected_qty'),''),nullif(btrim(v_row->>'expected_quantity'),''),nullif(btrim(v_row->>'الكمية الدفترية'),''));
   v_location_code:=coalesce(nullif(btrim(v_row->>'location_code'),''),nullif(btrim(v_row->>'الموقع'),''));
   v_image_url:=coalesce(nullif(btrim(v_row->>'image_url'),''),nullif(btrim(v_row->>'رابط الصورة'),''));
   IF length(v_image_url)>2048 OR v_image_url ~ '^http://' THEN v_errors:=array_append(v_errors,'INVALID_IMAGE_REFERENCE'); END IF;

   IF v_sku IS NULL THEN v_errors:=array_append(v_errors,'MISSING_SKU'); END IF;
   IF v_name IS NULL THEN v_errors:=array_append(v_errors,'MISSING_PRODUCT_NAME'); END IF;
   IF v_unit IS NULL THEN v_errors:=array_append(v_errors,'MISSING_BASE_UNIT'); END IF;

   IF v_expected_text IS NOT NULL THEN
    IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
     v_errors:=array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
    ELSE
     v_expected:=v_expected_text::numeric;
     IF v_expected<0 THEN v_errors:=array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY'); END IF;
     IF v_batch.session_id IS NULL THEN v_errors:=array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY'); END IF;
    END IF;
   END IF;

   IF v_location_code IS NOT NULL THEN
    SELECT count(*),(array_agg(id))[1] INTO v_location_count,v_location_id
    FROM public.count_locations
    WHERE project_id=v_batch.project_id AND code=v_location_code;
    IF v_location_count=0 THEN
     v_errors:=array_append(v_errors,'UNKNOWN_LOCATION_CODE');
    ELSIF v_location_count>1 THEN
     v_location_id:=NULL;
     v_errors:=array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
    END IF;
   END IF;

   IF v_sku IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.count_import_rows old
    WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(v_sku)
   ) THEN
    v_errors:=array_append(v_errors,'DUPLICATE_SKU_IN_BATCH');
   END IF;
  END IF;

  IF jsonb_typeof(v_row)='object' AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
   v_row_number:=(v_row->>'_row_number')::integer;
  ELSE
   v_row_number:=p_row_offset+v_ord::integer;
  END IF;
  IF v_row_number<1 THEN RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER'; END IF;

  INSERT INTO public.count_import_rows(
   batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
   units,image_url,expected_quantity,location_code,location_id,row_status,error_codes
  ) VALUES(
   p_batch_id,v_batch.project_id,v_row_number,v_row,v_sku,v_barcode,v_name,v_category,v_unit,
   v_units,v_image_url,v_expected,v_location_code,v_location_id,
   CASE WHEN cardinality(v_errors)>0 THEN 'rejected' ELSE 'staged' END,v_errors
  )
  ON CONFLICT(batch_id,row_number) DO NOTHING;
  IF FOUND THEN v_inserted:=v_inserted+1; END IF;
 END LOOP;

 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$function$
;
```

---

## 20261119184201 — countflow_kpis_and_anomaly_alert_engine_v1

- Statements: 1
- SQL characters: 6653
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_project uuid;
  v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_member(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
    'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
    'counted_positions',(SELECT count(*) FROM (
      SELECT product_id,location_id FROM public.count_entries WHERE session_id=p_session_id GROUP BY product_id,location_id
    ) x),
    'counted_products',(SELECT count(DISTINCT product_id) FROM public.count_entries WHERE session_id=p_session_id),
    'counted_locations',(SELECT count(DISTINCT location_id) FROM public.count_entries WHERE session_id=p_session_id AND location_id IS NOT NULL),
    'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    'quantity_total',(SELECT coalesce(sum(quantity),0) FROM public.count_entries WHERE session_id=p_session_id),
    'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
    'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
    'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
    'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
    'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
    'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_evaluate_session_alerts(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_project uuid;
  r public.count_anomaly_rules;
  v_inserted integer := 0;
  v_n integer := 0;
  v_run uuid;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  FOR r IN SELECT * FROM public.count_anomaly_rules
    WHERE project_id=v_project AND is_active ORDER BY created_at
  LOOP
    IF r.rule_type='quantity_above' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,e.id,r.id,r.rule_type,r.severity,
        'كمية عد غير معتادة',
        jsonb_build_object('quantity',e.quantity,'threshold',r.threshold,'product_id',e.product_id,'member_id',e.member_id)
      FROM public.count_entries e
      WHERE e.session_id=p_session_id AND e.quantity>r.threshold
        AND NOT EXISTS (SELECT 1 FROM public.count_alerts a
          WHERE a.session_id=p_session_id AND a.rule_id=r.id AND a.entry_id=e.id AND a.status IN ('open','acknowledged'));
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_inserted := v_inserted + v_n;

    ELSIF r.rule_type='repeat_scan_window' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,max(e.id),r.id,r.rule_type,r.severity,
        'تكرار مسح الصنف في فترة قصيرة',
        jsonb_build_object('member_id',e.member_id,'product_id',e.product_id,'location_id',e.location_id,
          'event_count',count(*),'threshold',r.threshold,'window_minutes',coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      FROM public.count_entries e
      WHERE e.session_id=p_session_id
        AND e.counted_at>=now()-make_interval(mins=>coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      GROUP BY e.member_id,e.product_id,e.location_id
      HAVING count(*)>r.threshold
        AND NOT EXISTS (SELECT 1 FROM public.count_alerts a
          WHERE a.session_id=p_session_id AND a.rule_id=r.id
            AND a.details->>'member_id'=e.member_id::text
            AND a.details->>'product_id'=e.product_id::text
            AND a.status IN ('open','acknowledged'));
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_inserted := v_inserted + v_n;

    ELSIF r.rule_type='variance_percent_above' THEN
      SELECT id INTO v_run FROM public.count_reconciliation_runs
      WHERE session_id=p_session_id AND status IN ('computed','approved')
      ORDER BY run_number DESC LIMIT 1;
      IF v_run IS NOT NULL THEN
        INSERT INTO public.count_alerts(project_id,session_id,rule_id,alert_type,severity,title,details)
        SELECT v_project,p_session_id,r.id,r.rule_type,r.severity,
          'فرق جرد يتجاوز حد التنبيه',
          jsonb_build_object('line_id',l.id,'product_id',l.product_id,'location_id',l.location_id,
            'variance_percent',l.variance_percent,'threshold',r.threshold,'run_id',v_run)
        FROM public.count_reconciliation_lines l
        WHERE l.run_id=v_run AND l.variance_percent IS NOT NULL AND abs(l.variance_percent)>r.threshold
          AND NOT EXISTS (SELECT 1 FROM public.count_alerts a
            WHERE a.session_id=p_session_id AND a.rule_id=r.id
              AND a.details->>'line_id'=l.id::text AND a.status IN ('open','acknowledged'));
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_inserted := v_inserted + v_n;
      END IF;
    END IF;
  END LOOP;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project,(SELECT auth.uid()),'alerts.evaluated','session',p_session_id,jsonb_build_object('created',v_inserted));
  RETURN jsonb_build_object('session_id',p_session_id,'created_alerts',v_inserted);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.count_session_kpis(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_evaluate_session_alerts(uuid) TO authenticated;
GRANT INSERT ON public.count_alerts TO authenticated;
DROP POLICY IF EXISTS count_alerts_insert ON public.count_alerts;
CREATE POLICY count_alerts_insert ON public.count_alerts
FOR INSERT TO authenticated
WITH CHECK (counting_private.is_supervisor(project_id));

```

---

## 20261119184224 — countflow_alerts_and_recount_realtime_publication

- Statements: 1
- SQL characters: 2526
- Rollback recorded: NO

### Statement 1

```sql

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['count_alerts','count_recount_tasks','count_import_batches'] LOOP
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
   EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
  END IF;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
 SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
 IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
  RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 SELECT jsonb_build_object(
  'session_id',p_session_id,
  'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
  'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
  'counted_positions',(SELECT count(*) FROM (SELECT product_id,location_id FROM public.count_entries WHERE session_id=p_session_id GROUP BY product_id,location_id) x),
  'counted_products',(SELECT count(DISTINCT product_id) FROM public.count_entries WHERE session_id=p_session_id),
  'counted_locations',(SELECT count(DISTINCT location_id) FROM public.count_entries WHERE session_id=p_session_id AND location_id IS NOT NULL),
  'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
  'quantity_total',(SELECT coalesce(sum(quantity),0) FROM public.count_entries WHERE session_id=p_session_id),
  'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
  'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
  'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
  'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
  'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
  'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
 ) INTO v_result;
 RETURN v_result;
END;
$function$;

```

---

## 20261119184230 — countflow_import_image_reference_validation

- Statements: 1
- SQL characters: 5997
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION public.count_stage_import_rows(p_batch_id uuid, p_rows jsonb, p_row_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.count_import_batches;
 v_row jsonb;
 v_ord bigint;
 v_row_number integer;
 v_sku text;
 v_barcode text;
 v_name text;
 v_category text;
 v_unit text;
 v_units jsonb;
 v_image_url text;
 v_expected_text text;
 v_expected numeric(18,4);
 v_location_code text;
 v_location_id uuid;
 v_location_count integer;
 v_errors text[];
 v_inserted integer:=0;
 v_rejected integer;
 v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 IF p_row_offset<0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 FOR v_row,v_ord IN
  SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 LOOP
  v_errors:=ARRAY[]::text[];
  v_expected:=NULL;
  v_location_id:=NULL;
  v_sku:=NULL;v_barcode:=NULL;v_name:=NULL;v_category:=NULL;v_unit:=NULL;
  v_expected_text:=NULL;v_location_code:=NULL;v_units:='[]'::jsonb;v_image_url:=NULL;

  IF jsonb_typeof(v_row)<>'object' THEN
   v_errors:=array_append(v_errors,'INVALID_ROW_SHAPE');
  ELSE
   v_sku:=coalesce(nullif(btrim(v_row->>'sku'),''),nullif(btrim(v_row->>'item_code'),''),nullif(btrim(v_row->>'كود الصنف'),''));
   v_barcode:=coalesce(nullif(btrim(v_row->>'barcode'),''),nullif(btrim(v_row->>'باركود'),''));
   v_name:=coalesce(nullif(btrim(v_row->>'name'),''),nullif(btrim(v_row->>'product_name'),''),nullif(btrim(v_row->>'اسم الصنف'),''));
   v_category:=coalesce(nullif(btrim(v_row->>'category'),''),nullif(btrim(v_row->>'الفئة'),''));
   v_unit:=coalesce(nullif(btrim(v_row->>'base_unit'),''),nullif(btrim(v_row->>'unit'),''),nullif(btrim(v_row->>'الوحدة'),''));
   v_units:=CASE WHEN jsonb_typeof(v_row->'units')='array' THEN v_row->'units' ELSE '[]'::jsonb END;
   v_expected_text:=coalesce(nullif(btrim(v_row->>'expected_qty'),''),nullif(btrim(v_row->>'expected_quantity'),''),nullif(btrim(v_row->>'الكمية الدفترية'),''));
   v_location_code:=coalesce(nullif(btrim(v_row->>'location_code'),''),nullif(btrim(v_row->>'الموقع'),''));
   v_image_url:=coalesce(nullif(btrim(v_row->>'image_url'),''),nullif(btrim(v_row->>'رابط الصورة'),''));
   IF length(v_image_url)>2048 OR (v_image_url ~* '^[a-z][a-z0-9+.-]*://' AND v_image_url !~* '^https://') OR v_image_url LIKE '/%' OR v_image_url LIKE '%..%' THEN v_errors:=array_append(v_errors,'INVALID_IMAGE_REFERENCE'); END IF;

   IF v_sku IS NULL THEN v_errors:=array_append(v_errors,'MISSING_SKU'); END IF;
   IF v_name IS NULL THEN v_errors:=array_append(v_errors,'MISSING_PRODUCT_NAME'); END IF;
   IF v_unit IS NULL THEN v_errors:=array_append(v_errors,'MISSING_BASE_UNIT'); END IF;

   IF v_expected_text IS NOT NULL THEN
    IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
     v_errors:=array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
    ELSE
     v_expected:=v_expected_text::numeric;
     IF v_expected<0 THEN v_errors:=array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY'); END IF;
     IF v_batch.session_id IS NULL THEN v_errors:=array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY'); END IF;
    END IF;
   END IF;

   IF v_location_code IS NOT NULL THEN
    SELECT count(*),(array_agg(id))[1] INTO v_location_count,v_location_id
    FROM public.count_locations
    WHERE project_id=v_batch.project_id AND code=v_location_code;
    IF v_location_count=0 THEN
     v_errors:=array_append(v_errors,'UNKNOWN_LOCATION_CODE');
    ELSIF v_location_count>1 THEN
     v_location_id:=NULL;
     v_errors:=array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
    END IF;
   END IF;

   IF v_sku IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.count_import_rows old
    WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(v_sku)
   ) THEN
    v_errors:=array_append(v_errors,'DUPLICATE_SKU_IN_BATCH');
   END IF;
  END IF;

  IF jsonb_typeof(v_row)='object' AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
   v_row_number:=(v_row->>'_row_number')::integer;
  ELSE
   v_row_number:=p_row_offset+v_ord::integer;
  END IF;
  IF v_row_number<1 THEN RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER'; END IF;

  INSERT INTO public.count_import_rows(
   batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
   units,image_url,expected_quantity,location_code,location_id,row_status,error_codes
  ) VALUES(
   p_batch_id,v_batch.project_id,v_row_number,v_row,v_sku,v_barcode,v_name,v_category,v_unit,
   v_units,v_image_url,v_expected,v_location_code,v_location_id,
   CASE WHEN cardinality(v_errors)>0 THEN 'rejected' ELSE 'staged' END,v_errors
  )
  ON CONFLICT(batch_id,row_number) DO NOTHING;
  IF FOUND THEN v_inserted:=v_inserted+1; END IF;
 END LOOP;

 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$function$
;
```

---

## 20261119184250 — countflow_recount_entry_secure_rpc_v1

- Statements: 1
- SQL characters: 4171
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.record_recount_entry(
  p_task_id uuid,
  p_quantity numeric,
  p_unit text,
  p_client_event_id uuid,
  p_scan_code text DEFAULT NULL,
  p_device_id text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS public.count_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_task public.count_recount_tasks;
  v_session public.count_sessions;
  v_member public.count_members;
  v_entry public.count_entries;
  v_previous public.count_entries;
  v_next_round smallint;
BEGIN
  IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 OR p_client_event_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_RECOUNT_PAYLOAD';
  END IF;

  SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND'; END IF;

  SELECT * INTO v_session FROM public.count_sessions
  WHERE id=v_task.session_id AND project_id=v_task.project_id;
  IF NOT FOUND OR v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;

  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_task.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND OR v_task.assigned_member_id IS DISTINCT FROM v_member.id THEN
    RAISE EXCEPTION 'RECOUNT_TASK_NOT_ASSIGNED_TO_CALLER';
  END IF;
  IF v_task.status NOT IN ('assigned','in_progress') THEN
    RAISE EXCEPTION 'RECOUNT_TASK_NOT_OPEN';
  END IF;

  SELECT * INTO v_entry FROM public.count_entries
  WHERE session_id=v_task.session_id AND client_event_id=p_client_event_id;
  IF FOUND THEN RETURN v_entry; END IF;

  SELECT * INTO v_previous FROM public.count_entries
  WHERE session_id=v_task.session_id AND product_id=v_task.product_id
    AND location_id IS NOT DISTINCT FROM v_task.location_id
  ORDER BY counted_at DESC,id DESC LIMIT 1;

  SELECT coalesce(max(count_round),1)+1 INTO v_next_round
  FROM public.count_entries
  WHERE session_id=v_task.session_id AND product_id=v_task.product_id
    AND location_id IS NOT DISTINCT FROM v_task.location_id;
  IF v_next_round>5 THEN RAISE EXCEPTION 'MAX_COUNT_ROUNDS_REACHED'; END IF;

  INSERT INTO public.count_entries(
    session_id,project_id,product_id,location_id,member_id,client_event_id,
    quantity,unit,scan_code,device_id,note,revision,supersedes_id,count_round,recount_task_id
  ) VALUES (
    v_task.session_id,v_task.project_id,v_task.product_id,v_task.location_id,v_member.id,p_client_event_id,
    p_quantity,coalesce(nullif(trim(p_unit),''),'وحدة'),p_scan_code,p_device_id,p_note,
    v_next_round, v_previous.id, v_next_round, p_task_id
  ) RETURNING * INTO v_entry;

  UPDATE public.count_recount_tasks
  SET status='completed',second_count_quantity=p_quantity,
      started_at=coalesce(started_at,now()),completed_at=now(),
      notes=coalesce(nullif(p_note,''),notes)
  WHERE id=p_task_id;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_task.project_id,(SELECT auth.uid()),'recount.completed','recount_task',p_task_id,
    jsonb_build_object('entry_id',v_entry.id,'quantity',p_quantity,'count_round',v_next_round));

  RETURN v_entry;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_record_recount_entry(
  p_task_id uuid,
  p_quantity numeric,
  p_unit text,
  p_client_event_id uuid,
  p_scan_code text DEFAULT NULL,
  p_device_id text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS public.count_entries
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
BEGIN
  RETURN counting_private.record_recount_entry(
    p_task_id,p_quantity,p_unit,p_client_event_id,p_scan_code,p_device_id,p_note
  );
END;
$function$;

GRANT USAGE ON SCHEMA counting_private TO authenticated;
REVOKE ALL ON FUNCTION counting_private.record_recount_entry(uuid,numeric,text,uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION counting_private.record_recount_entry(uuid,numeric,text,uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_record_recount_entry(uuid,numeric,text,uuid,text,text,text) TO authenticated;

```

---

## 20261119184532 — countflow_recount_idempotency_retry_fix

- Statements: 1
- SQL characters: 3260
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION counting_private.record_recount_entry(p_task_id uuid, p_quantity numeric, p_unit text, p_client_event_id uuid, p_scan_code text DEFAULT NULL::text, p_device_id text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS count_entries
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_task public.count_recount_tasks;
  v_session public.count_sessions;
  v_member public.count_members;
  v_entry public.count_entries;
  v_previous public.count_entries;
  v_next_round smallint;
BEGIN
  IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 OR p_client_event_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_RECOUNT_PAYLOAD';
  END IF;

  SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND'; END IF;

  SELECT * INTO v_session FROM public.count_sessions
  WHERE id=v_task.session_id AND project_id=v_task.project_id;
  IF NOT FOUND OR v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;

  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_task.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND OR v_task.assigned_member_id IS DISTINCT FROM v_member.id THEN
    RAISE EXCEPTION 'RECOUNT_TASK_NOT_ASSIGNED_TO_CALLER';
  END IF;

  SELECT * INTO v_entry FROM public.count_entries
  WHERE session_id=v_task.session_id AND client_event_id=p_client_event_id;
  IF FOUND THEN RETURN v_entry; END IF;

  IF v_task.status NOT IN ('assigned','in_progress') THEN
    RAISE EXCEPTION 'RECOUNT_TASK_NOT_OPEN';
  END IF;

  SELECT * INTO v_previous FROM public.count_entries
  WHERE session_id=v_task.session_id AND product_id=v_task.product_id
    AND location_id IS NOT DISTINCT FROM v_task.location_id
  ORDER BY counted_at DESC,id DESC LIMIT 1;

  SELECT coalesce(max(count_round),1)+1 INTO v_next_round
  FROM public.count_entries
  WHERE session_id=v_task.session_id AND product_id=v_task.product_id
    AND location_id IS NOT DISTINCT FROM v_task.location_id;
  IF v_next_round>5 THEN RAISE EXCEPTION 'MAX_COUNT_ROUNDS_REACHED'; END IF;

  INSERT INTO public.count_entries(
    session_id,project_id,product_id,location_id,member_id,client_event_id,
    quantity,unit,scan_code,device_id,note,revision,supersedes_id,count_round,recount_task_id
  ) VALUES (
    v_task.session_id,v_task.project_id,v_task.product_id,v_task.location_id,v_member.id,p_client_event_id,
    p_quantity,coalesce(nullif(trim(p_unit),''),'وحدة'),p_scan_code,p_device_id,p_note,
    v_next_round, v_previous.id, v_next_round, p_task_id
  ) RETURNING * INTO v_entry;

  UPDATE public.count_recount_tasks
  SET status='completed',second_count_quantity=p_quantity,
      started_at=coalesce(started_at,now()),completed_at=now(),
      notes=coalesce(nullif(p_note,''),notes)
  WHERE id=p_task_id;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_task.project_id,(SELECT auth.uid()),'recount.completed','recount_task',p_task_id,
    jsonb_build_object('entry_id',v_entry.id,'quantity',p_quantity,'count_round',v_next_round));

  RETURN v_entry;
END;
$function$
;
```

---

## 20261119184632 — countflow_private_realtime_broadcast_architecture_v1

- Statements: 1
- SQL characters: 5119
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.can_access_countflow_topic(p_topic text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE v_id uuid;
BEGIN
 IF p_topic ~ '^countflow:project:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
  v_id := split_part(p_topic,':',3)::uuid;
  RETURN counting_private.is_supervisor(v_id);
 ELSIF p_topic ~ '^countflow:session:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
  v_id := split_part(p_topic,':',3)::uuid;
  RETURN EXISTS(
   SELECT 1 FROM public.count_sessions s
   WHERE s.id=v_id AND counting_private.is_supervisor(s.project_id)
  );
 ELSIF p_topic ~ '^countflow:member:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
  v_id := split_part(p_topic,':',3)::uuid;
  RETURN EXISTS(
   SELECT 1 FROM public.count_members m
   WHERE m.id=v_id AND m.user_id=(SELECT auth.uid()) AND m.status IN ('active','paused')
  ) OR EXISTS(
   SELECT 1 FROM public.count_members m
   WHERE m.id=v_id AND counting_private.is_supervisor(m.project_id)
  );
 END IF;
 RETURN false;
END;
$function$;

REVOKE ALL ON FUNCTION counting_private.can_access_countflow_topic(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION counting_private.can_access_countflow_topic(text) TO authenticated;

DROP POLICY IF EXISTS countflow_private_topic_read ON realtime.messages;
CREATE POLICY countflow_private_topic_read ON realtime.messages
FOR SELECT TO authenticated
USING (counting_private.can_access_countflow_topic(realtime.topic()));

CREATE OR REPLACE FUNCTION public.countflow_broadcast_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_project_id uuid;
 v_session_id uuid;
 v_member_id uuid;
 v_topic text;
 m record;
BEGIN
 IF TG_TABLE_NAME='count_sessions' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_session_id := coalesce(NEW.id,OLD.id);
  v_topic := 'countflow:session:'||v_session_id::text;
  PERFORM realtime.broadcast_changes(v_topic,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  FOR m IN SELECT id FROM public.count_members WHERE project_id=v_project_id AND status IN ('active','paused') LOOP
   PERFORM realtime.broadcast_changes('countflow:member:'||m.id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END LOOP;
 ELSIF TG_TABLE_NAME='count_members' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.id,OLD.id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_assignments' THEN
  SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=coalesce(NEW.session_id,OLD.session_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_import_batches' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSE
  v_session_id := coalesce(NEW.session_id,OLD.session_id);
  IF v_session_id IS NOT NULL THEN
   PERFORM realtime.broadcast_changes('countflow:session:'||v_session_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END IF;
  IF TG_TABLE_NAME='count_recount_tasks' THEN
   v_member_id := coalesce(NEW.assigned_member_id,OLD.assigned_member_id);
   IF v_member_id IS NOT NULL THEN
    PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
   END IF;
  END IF;
 END IF;
 RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.countflow_broadcast_changes() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['count_entries','count_sessions','count_members','count_assignments','count_import_batches','count_presence','count_alerts','count_recount_tasks','count_reconciliation_runs'] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS countflow_broadcast_changes_trigger ON public.%I',t);
  IF t='count_entries' THEN
   EXECUTE 'CREATE TRIGGER countflow_broadcast_changes_trigger AFTER INSERT ON public.count_entries FOR EACH ROW EXECUTE FUNCTION public.countflow_broadcast_changes()';
  ELSIF t IN ('count_sessions','count_members','count_assignments','count_import_batches','count_presence','count_alerts','count_recount_tasks','count_reconciliation_runs') THEN
   EXECUTE format('CREATE TRIGGER countflow_broadcast_changes_trigger AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.countflow_broadcast_changes()',t);
  END IF;
 END LOOP;
END $$;

```

---

## 20261119184706 — countflow_recount_review_and_reconciliation_approval_v1

- Statements: 1
- SQL characters: 4913
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_assign_recount_task(p_task_id uuid,p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_task public.count_recount_tasks;
BEGIN
 SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_task.project_id) THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND_OR_FORBIDDEN'; END IF;
 IF v_task.status NOT IN ('pending','assigned','escalated') THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_ASSIGNABLE'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.count_members WHERE id=p_member_id AND project_id=v_task.project_id AND role IN ('counter','auditor') AND status='active') THEN
  RAISE EXCEPTION 'INVALID_RECOUNT_ASSIGNEE';
 END IF;
 UPDATE public.count_recount_tasks SET assigned_member_id=p_member_id,status='assigned',assigned_at=now(),
  started_at=NULL,completed_at=NULL,reviewed_by=NULL,reviewed_at=NULL,second_count_quantity=NULL
 WHERE id=p_task_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_task.project_id,(SELECT auth.uid()),'recount.assigned','recount_task',p_task_id,jsonb_build_object('member_id',p_member_id));
 RETURN jsonb_build_object('task_id',p_task_id,'assigned_member_id',p_member_id,'status','assigned');
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_review_recount_task(p_task_id uuid,p_decision text,p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_task public.count_recount_tasks; v_status text;
BEGIN
 SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_task.project_id) THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND_OR_FORBIDDEN'; END IF;
 IF v_task.status<>'completed' THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_COMPLETED'; END IF;
 IF p_decision NOT IN ('accept','repeat','cancel') THEN RAISE EXCEPTION 'INVALID_RECOUNT_REVIEW_DECISION'; END IF;
 v_status:=CASE p_decision WHEN 'accept' THEN 'reviewed' WHEN 'repeat' THEN 'pending' ELSE 'cancelled' END;
 UPDATE public.count_recount_tasks SET status=v_status,
  assigned_member_id=CASE WHEN p_decision='repeat' THEN NULL ELSE assigned_member_id END,
  second_count_quantity=CASE WHEN p_decision='repeat' THEN NULL ELSE second_count_quantity END,
  started_at=CASE WHEN p_decision='repeat' THEN NULL ELSE started_at END,
  completed_at=CASE WHEN p_decision='repeat' THEN NULL ELSE completed_at END,
  reviewed_by=(SELECT auth.uid()),reviewed_at=now(),
  notes=concat_ws(E'\n',nullif(notes,''),nullif(p_note,''))
 WHERE id=p_task_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_task.project_id,(SELECT auth.uid()),'recount.reviewed','recount_task',p_task_id,
  jsonb_build_object('decision',p_decision,'status',v_status,'note',p_note));
 RETURN jsonb_build_object('task_id',p_task_id,'status',v_status);
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_run public.count_reconciliation_runs; v_open_tasks integer; v_critical_alerts integer;
BEGIN
 SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN'; END IF;
 IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;
 SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks
 WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
 SELECT count(*) INTO v_critical_alerts FROM public.count_alerts
 WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
 IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
 IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;
 UPDATE public.count_reconciliation_runs SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now()
 WHERE id=p_run_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
  jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number));
 RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now());
END;
$function$;

GRANT EXECUTE ON FUNCTION public.count_assign_recount_task(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_review_recount_task(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_approve_reconciliation(uuid) TO authenticated;

```

---

## 20261119185002 — countflow_evidence_owner_cleanup_policy

- Statements: 1
- SQL characters: 787
- Rollback recorded: NO

### Statement 1

```sql

DROP POLICY IF EXISTS count_evidence_delete_supervisor ON storage.objects;
DROP POLICY IF EXISTS count_evidence_delete_owner ON storage.objects;
CREATE POLICY count_evidence_delete_owner ON storage.objects
FOR DELETE TO authenticated
USING (
 bucket_id='counting-evidence'
 AND CASE
  WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
   AND (storage.foldername(name))[3] ~* '^[0-9a-f-]{36}$'
  THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
   OR EXISTS (
    SELECT 1 FROM public.count_entries e
    JOIN public.count_members m ON m.id=e.member_id
    WHERE e.id=((storage.foldername(name))[3])::uuid
      AND e.project_id=((storage.foldername(name))[1])::uuid
      AND m.user_id=(SELECT auth.uid()) AND m.status='active'
   )
  ELSE false
 END
);

```

---

## 20261119185027 — countflow_session_project_broadcast_event

- Statements: 1
- SQL characters: 2629
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION public.countflow_broadcast_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_project_id uuid;
 v_session_id uuid;
 v_member_id uuid;
 v_topic text;
 m record;
BEGIN
 IF TG_TABLE_NAME='count_sessions' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_session_id := coalesce(NEW.id,OLD.id);
  v_topic := 'countflow:session:'||v_session_id::text;
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes(v_topic,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  FOR m IN SELECT id FROM public.count_members WHERE project_id=v_project_id AND status IN ('active','paused') LOOP
   PERFORM realtime.broadcast_changes('countflow:member:'||m.id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END LOOP;
 ELSIF TG_TABLE_NAME='count_members' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.id,OLD.id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_assignments' THEN
  SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=coalesce(NEW.session_id,OLD.session_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_import_batches' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSE
  v_session_id := coalesce(NEW.session_id,OLD.session_id);
  IF v_session_id IS NOT NULL THEN
   PERFORM realtime.broadcast_changes('countflow:session:'||v_session_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END IF;
  IF TG_TABLE_NAME='count_recount_tasks' THEN
   v_member_id := coalesce(NEW.assigned_member_id,OLD.assigned_member_id);
   IF v_member_id IS NOT NULL THEN
    PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
   END IF;
  END IF;
 END IF;
 RETURN NULL;
END;
$function$
;
```

---

## 20261119185123 — countflow_import_mapping_relation_and_raw_source_preservation

- Statements: 1
- SQL characters: 6525
- Rollback recorded: NO

### Statement 1

```sql

ALTER TABLE public.count_import_mappings ADD CONSTRAINT count_import_mappings_id_project_uq UNIQUE(id,project_id);
ALTER TABLE public.count_import_batches ADD COLUMN mapping_id uuid;
ALTER TABLE public.count_import_batches ADD CONSTRAINT count_import_batches_mapping_project_fkey
 FOREIGN KEY(mapping_id,project_id) REFERENCES public.count_import_mappings(id,project_id)
 ON DELETE SET NULL (mapping_id);
CREATE INDEX count_import_batches_mapping_idx ON public.count_import_batches(mapping_id);
CREATE OR REPLACE FUNCTION public.count_stage_import_rows(p_batch_id uuid, p_rows jsonb, p_row_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_batch public.count_import_batches;
 v_row jsonb;
 v_ord bigint;
 v_row_number integer;
 v_sku text;
 v_barcode text;
 v_name text;
 v_category text;
 v_unit text;
 v_units jsonb;
 v_image_url text;
 v_expected_text text;
 v_expected numeric(18,4);
 v_location_code text;
 v_location_id uuid;
 v_location_count integer;
 v_errors text[];
 v_inserted integer:=0;
 v_rejected integer;
 v_accepted integer;
BEGIN
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows)<1 OR jsonb_array_length(p_rows)>1000 THEN
  RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
 END IF;
 IF p_row_offset<0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;
 SELECT * INTO v_batch FROM public.count_import_batches WHERE id=p_batch_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 IF v_batch.status NOT IN ('uploading','preview') THEN
  RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
 END IF;

 FOR v_row,v_ord IN
  SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY
 LOOP
  v_errors:=ARRAY[]::text[];
  v_expected:=NULL;
  v_location_id:=NULL;
  v_sku:=NULL;v_barcode:=NULL;v_name:=NULL;v_category:=NULL;v_unit:=NULL;
  v_expected_text:=NULL;v_location_code:=NULL;v_units:='[]'::jsonb;v_image_url:=NULL;

  IF jsonb_typeof(v_row)<>'object' THEN
   v_errors:=array_append(v_errors,'INVALID_ROW_SHAPE');
  ELSE
   v_sku:=coalesce(nullif(btrim(v_row->>'sku'),''),nullif(btrim(v_row->>'item_code'),''),nullif(btrim(v_row->>'كود الصنف'),''));
   v_barcode:=coalesce(nullif(btrim(v_row->>'barcode'),''),nullif(btrim(v_row->>'باركود'),''));
   v_name:=coalesce(nullif(btrim(v_row->>'name'),''),nullif(btrim(v_row->>'product_name'),''),nullif(btrim(v_row->>'اسم الصنف'),''));
   v_category:=coalesce(nullif(btrim(v_row->>'category'),''),nullif(btrim(v_row->>'الفئة'),''));
   v_unit:=coalesce(nullif(btrim(v_row->>'base_unit'),''),nullif(btrim(v_row->>'unit'),''),nullif(btrim(v_row->>'الوحدة'),''));
   v_units:=CASE WHEN jsonb_typeof(v_row->'units')='array' THEN v_row->'units' ELSE '[]'::jsonb END;
   v_expected_text:=coalesce(nullif(btrim(v_row->>'expected_qty'),''),nullif(btrim(v_row->>'expected_quantity'),''),nullif(btrim(v_row->>'الكمية الدفترية'),''));
   v_location_code:=coalesce(nullif(btrim(v_row->>'location_code'),''),nullif(btrim(v_row->>'الموقع'),''));
   v_image_url:=coalesce(nullif(btrim(v_row->>'image_url'),''),nullif(btrim(v_row->>'رابط الصورة'),''));
   IF length(v_image_url)>2048 OR (v_image_url ~* '^[a-z][a-z0-9+.-]*://' AND v_image_url !~* '^https://') OR v_image_url LIKE '/%' OR v_image_url LIKE '%..%' THEN v_errors:=array_append(v_errors,'INVALID_IMAGE_REFERENCE'); END IF;

   IF v_sku IS NULL THEN v_errors:=array_append(v_errors,'MISSING_SKU'); END IF;
   IF v_name IS NULL THEN v_errors:=array_append(v_errors,'MISSING_PRODUCT_NAME'); END IF;
   IF v_unit IS NULL THEN v_errors:=array_append(v_errors,'MISSING_BASE_UNIT'); END IF;

   IF v_expected_text IS NOT NULL THEN
    IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
     v_errors:=array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
    ELSE
     v_expected:=v_expected_text::numeric;
     IF v_expected<0 THEN v_errors:=array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY'); END IF;
     IF v_batch.session_id IS NULL THEN v_errors:=array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY'); END IF;
    END IF;
   END IF;

   IF v_location_code IS NOT NULL THEN
    SELECT count(*),(array_agg(id))[1] INTO v_location_count,v_location_id
    FROM public.count_locations
    WHERE project_id=v_batch.project_id AND code=v_location_code;
    IF v_location_count=0 THEN
     v_errors:=array_append(v_errors,'UNKNOWN_LOCATION_CODE');
    ELSIF v_location_count>1 THEN
     v_location_id:=NULL;
     v_errors:=array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
    END IF;
   END IF;

   IF v_sku IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.count_import_rows old
    WHERE old.batch_id=p_batch_id AND lower(old.sku)=lower(v_sku)
   ) THEN
    v_errors:=array_append(v_errors,'DUPLICATE_SKU_IN_BATCH');
   END IF;
  END IF;

  IF jsonb_typeof(v_row)='object' AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
   v_row_number:=(v_row->>'_row_number')::integer;
  ELSE
   v_row_number:=p_row_offset+v_ord::integer;
  END IF;
  IF v_row_number<1 THEN RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER'; END IF;

  INSERT INTO public.count_import_rows(
   batch_id,project_id,row_number,raw_row,sku,barcode,product_name,category,base_unit,
   units,image_url,expected_quantity,location_code,location_id,row_status,error_codes
  ) VALUES(
   p_batch_id,v_batch.project_id,v_row_number,coalesce(v_row->'_source_row',v_row),v_sku,v_barcode,v_name,v_category,v_unit,
   v_units,v_image_url,v_expected,v_location_code,v_location_id,
   CASE WHEN cardinality(v_errors)>0 THEN 'rejected' ELSE 'staged' END,v_errors
  )
  ON CONFLICT(batch_id,row_number) DO NOTHING;
  IF FOUND THEN v_inserted:=v_inserted+1; END IF;
 END LOOP;

 SELECT count(*) FILTER(WHERE row_status='rejected'),
        count(*) FILTER(WHERE row_status IN ('staged','accepted'))
 INTO v_rejected,v_accepted
 FROM public.count_import_rows WHERE batch_id=p_batch_id;

 UPDATE public.count_import_batches
 SET row_count=(SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
     accepted_count=coalesce(v_accepted,0),rejected_count=coalesce(v_rejected,0),
     status='preview',
     error_report=jsonb_build_object('rejected_count',coalesce(v_rejected,0),'staged_count',coalesce(v_accepted,0)),
     updated_at=now()
 WHERE id=p_batch_id;

 RETURN jsonb_build_object('batch_id',p_batch_id,'inserted_rows',v_inserted,
  'accepted_rows',coalesce(v_accepted,0),'rejected_rows',coalesce(v_rejected,0));
END;
$function$
;

```

---

## 20261119185154 — countflow_single_default_import_mapping_per_format

- Statements: 1
- SQL characters: 145
- Rollback recorded: NO

### Statement 1

```sql
CREATE UNIQUE INDEX count_import_mappings_one_default_per_format ON public.count_import_mappings(project_id,source_format) WHERE is_default=true;
```

---

## 20261119185210 — countflow_all_location_assignment_uniqueness

- Statements: 1
- SQL characters: 130
- Rollback recorded: NO

### Statement 1

```sql
CREATE UNIQUE INDEX count_assignments_all_location_uq ON public.count_assignments(session_id,member_id) WHERE location_id IS NULL;
```

---

## 20261119185240 — countflow_server_side_device_and_product_scope_enforcement

- Statements: 1
- SQL characters: 8205
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_record_entry(
 p_session_id uuid,p_product_id uuid,p_location_id uuid,p_quantity numeric,p_unit text,
 p_client_event_id uuid,p_scan_code text DEFAULT NULL,p_device_id text DEFAULT NULL,p_note text DEFAULT NULL
)
RETURNS public.count_entries
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
 v_session public.count_sessions;
 v_member public.count_members;
 v_product public.count_products;
 v_entry public.count_entries;
 v_unit text := coalesce(nullif(trim(p_unit),''),'وحدة');
 v_has_assignments boolean;
BEGIN
 SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;

 SELECT * INTO v_member FROM public.count_members
 WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
   AND role IN ('counter','auditor') AND status='active';
 IF NOT FOUND THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;

 IF p_client_event_id IS NULL THEN RAISE EXCEPTION 'CLIENT_EVENT_ID_REQUIRED'; END IF;
 SELECT * INTO v_entry FROM public.count_entries
 WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
  RETURN v_entry;
 END IF;

 IF v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
 IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
 IF nullif(btrim(p_device_id),'') IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.count_devices d
   WHERE d.project_id=v_session.project_id AND d.member_id=v_member.id
     AND d.device_id=p_device_id AND d.status='active'
 ) THEN RAISE EXCEPTION 'DEVICE_NOT_REGISTERED_OR_REVOKED'; END IF;

 SELECT * INTO v_product FROM public.count_products
 WHERE id=p_product_id AND project_id=v_session.project_id AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE_IN_PROJECT'; END IF;
 IF NOT (
   v_product.base_unit=v_unit
   OR EXISTS (
     SELECT 1 FROM jsonb_array_elements(
       CASE WHEN jsonb_typeof(v_product.units)='array' THEN v_product.units ELSE '[]'::jsonb END
     ) u WHERE coalesce(u->>'name',u#>>'{}')=v_unit
   )
 ) THEN RAISE EXCEPTION 'UNIT_NOT_ALLOWED_FOR_PRODUCT'; END IF;

 IF p_location_id IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
 ) THEN RAISE EXCEPTION 'LOCATION_NOT_IN_PROJECT'; END IF;

 SELECT EXISTS(SELECT 1 FROM public.count_assignments a WHERE a.session_id=p_session_id) INTO v_has_assignments;
 IF v_has_assignments AND NOT EXISTS(
   SELECT 1 FROM public.count_assignments a
   WHERE a.session_id=p_session_id AND a.member_id=v_member.id
     AND a.status IN ('assigned','active')
     AND (a.location_id IS NULL OR a.location_id=p_location_id)
 ) THEN RAISE EXCEPTION 'LOCATION_NOT_ASSIGNED'; END IF;

 INSERT INTO public.count_entries(
   session_id,project_id,product_id,location_id,member_id,client_event_id,
   quantity,unit,scan_code,device_id,note
 ) VALUES (
   p_session_id,v_session.project_id,p_product_id,p_location_id,v_member.id,p_client_event_id,
   p_quantity,v_unit,p_scan_code,p_device_id,p_note
 )
 ON CONFLICT(session_id,client_event_id) DO NOTHING
 RETURNING * INTO v_entry;

 IF v_entry.id IS NULL THEN
  SELECT * INTO v_entry FROM public.count_entries
  WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
 END IF;
 RETURN v_entry;
END;
$function$;

CREATE OR REPLACE FUNCTION counting_private.record_recount_entry(
  p_task_id uuid,p_quantity numeric,p_unit text,p_client_event_id uuid,
  p_scan_code text DEFAULT NULL,p_device_id text DEFAULT NULL,p_note text DEFAULT NULL
)
RETURNS public.count_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_task public.count_recount_tasks;
 v_session public.count_sessions;
 v_member public.count_members;
 v_entry public.count_entries;
 v_previous public.count_entries;
 v_product public.count_products;
 v_next_round smallint;
 v_unit text := coalesce(nullif(trim(p_unit),''),'وحدة');
BEGIN
 IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 OR p_client_event_id IS NULL THEN
  RAISE EXCEPTION 'INVALID_RECOUNT_PAYLOAD';
 END IF;
 SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND'; END IF;
 SELECT * INTO v_member FROM public.count_members
 WHERE project_id=v_task.project_id AND user_id=(SELECT auth.uid())
   AND role IN ('counter','auditor') AND status='active';
 IF NOT FOUND OR v_task.assigned_member_id IS DISTINCT FROM v_member.id THEN
  RAISE EXCEPTION 'RECOUNT_TASK_NOT_ASSIGNED_TO_CALLER';
 END IF;
 SELECT * INTO v_entry FROM public.count_entries
 WHERE session_id=v_task.session_id AND client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_entry.member_id<>v_member.id OR v_entry.recount_task_id<>p_task_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
  RETURN v_entry;
 END IF;
 IF v_task.status NOT IN ('assigned','in_progress') THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_OPEN'; END IF;
 SELECT * INTO v_session FROM public.count_sessions
 WHERE id=v_task.session_id AND project_id=v_task.project_id;
 IF NOT FOUND OR v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
 IF nullif(btrim(p_device_id),'') IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.count_devices d WHERE d.project_id=v_task.project_id
   AND d.member_id=v_member.id AND d.device_id=p_device_id AND d.status='active'
 ) THEN RAISE EXCEPTION 'DEVICE_NOT_REGISTERED_OR_REVOKED'; END IF;
 SELECT * INTO v_product FROM public.count_products
 WHERE id=v_task.product_id AND project_id=v_task.project_id AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE_IN_PROJECT'; END IF;
 IF NOT (
  v_product.base_unit=v_unit OR EXISTS(
   SELECT 1 FROM jsonb_array_elements(
    CASE WHEN jsonb_typeof(v_product.units)='array' THEN v_product.units ELSE '[]'::jsonb END
   ) u WHERE coalesce(u->>'name',u#>>'{}')=v_unit
  )
 ) THEN RAISE EXCEPTION 'UNIT_NOT_ALLOWED_FOR_PRODUCT'; END IF;
 SELECT * INTO v_previous FROM public.count_entries
 WHERE session_id=v_task.session_id AND product_id=v_task.product_id
   AND location_id IS NOT DISTINCT FROM v_task.location_id
 ORDER BY counted_at DESC,id DESC LIMIT 1;
 SELECT coalesce(max(count_round),1)+1 INTO v_next_round
 FROM public.count_entries
 WHERE session_id=v_task.session_id AND product_id=v_task.product_id
   AND location_id IS NOT DISTINCT FROM v_task.location_id;
 IF v_next_round>5 THEN RAISE EXCEPTION 'MAX_COUNT_ROUNDS_REACHED'; END IF;
 INSERT INTO public.count_entries(
  session_id,project_id,product_id,location_id,member_id,client_event_id,
  quantity,unit,scan_code,device_id,note,revision,supersedes_id,count_round,recount_task_id
 ) VALUES (
  v_task.session_id,v_task.project_id,v_task.product_id,v_task.location_id,v_member.id,p_client_event_id,
  p_quantity,v_unit,p_scan_code,p_device_id,p_note,v_next_round,v_previous.id,v_next_round,p_task_id
 ) RETURNING * INTO v_entry;
 UPDATE public.count_recount_tasks SET status='completed',second_count_quantity=p_quantity,
  started_at=coalesce(started_at,now()),completed_at=now(),notes=coalesce(nullif(p_note,''),notes)
 WHERE id=p_task_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_task.project_id,(SELECT auth.uid()),'recount.completed','recount_task',p_task_id,
  jsonb_build_object('entry_id',v_entry.id,'quantity',p_quantity,'count_round',v_next_round));
 RETURN v_entry;
END;
$function$;

```

---

## 20261119185300 — countflow_assignment_scope_rls_and_enforcement

- Statements: 1
- SQL characters: 6756
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.session_has_assignments(p_session_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.count_assignments WHERE session_id=p_session_id);
$function$;
CREATE OR REPLACE FUNCTION counting_private.member_has_location_assignment(p_session_id uuid,p_member_id uuid,p_location_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.count_assignments a
  WHERE a.session_id=p_session_id AND a.member_id=p_member_id
   AND a.status IN ('assigned','active')
   AND (a.location_id IS NULL OR a.location_id IS NOT DISTINCT FROM p_location_id));
$function$;
REVOKE ALL ON FUNCTION counting_private.session_has_assignments(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION counting_private.member_has_location_assignment(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION counting_private.session_has_assignments(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION counting_private.member_has_location_assignment(uuid,uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_record_entry(p_session_id uuid, p_product_id uuid, p_location_id uuid, p_quantity numeric, p_unit text, p_client_event_id uuid, p_scan_code text DEFAULT NULL::text, p_device_id text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS count_entries
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_session public.count_sessions;
 v_member public.count_members;
 v_product public.count_products;
 v_entry public.count_entries;
 v_unit text := coalesce(nullif(trim(p_unit),''),'وحدة');
 v_has_assignments boolean;
BEGIN
 SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;

 SELECT * INTO v_member FROM public.count_members
 WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
   AND role IN ('counter','auditor') AND status='active';
 IF NOT FOUND THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;

 IF p_client_event_id IS NULL THEN RAISE EXCEPTION 'CLIENT_EVENT_ID_REQUIRED'; END IF;
 SELECT * INTO v_entry FROM public.count_entries
 WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
  RETURN v_entry;
 END IF;

 IF v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
 IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
 IF nullif(btrim(p_device_id),'') IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.count_devices d
   WHERE d.project_id=v_session.project_id AND d.member_id=v_member.id
     AND d.device_id=p_device_id AND d.status='active'
 ) THEN RAISE EXCEPTION 'DEVICE_NOT_REGISTERED_OR_REVOKED'; END IF;

 SELECT * INTO v_product FROM public.count_products
 WHERE id=p_product_id AND project_id=v_session.project_id AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE_IN_PROJECT'; END IF;
 IF NOT (
   v_product.base_unit=v_unit
   OR EXISTS (
     SELECT 1 FROM jsonb_array_elements(
       CASE WHEN jsonb_typeof(v_product.units)='array' THEN v_product.units ELSE '[]'::jsonb END
     ) u WHERE coalesce(u->>'name',u#>>'{}')=v_unit
   )
 ) THEN RAISE EXCEPTION 'UNIT_NOT_ALLOWED_FOR_PRODUCT'; END IF;

 IF p_location_id IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
 ) THEN RAISE EXCEPTION 'LOCATION_NOT_IN_PROJECT'; END IF;

 v_has_assignments := counting_private.session_has_assignments(p_session_id);
 IF v_has_assignments AND NOT counting_private.member_has_location_assignment(p_session_id,v_member.id,p_location_id) THEN
  RAISE EXCEPTION 'LOCATION_NOT_ASSIGNED';
 END IF;

 INSERT INTO public.count_entries(
   session_id,project_id,product_id,location_id,member_id,client_event_id,
   quantity,unit,scan_code,device_id,note
 ) VALUES (
   p_session_id,v_session.project_id,p_product_id,p_location_id,v_member.id,p_client_event_id,
   p_quantity,v_unit,p_scan_code,p_device_id,p_note
 )
 ON CONFLICT(session_id,client_event_id) DO NOTHING
 RETURNING * INTO v_entry;

 IF v_entry.id IS NULL THEN
  SELECT * INTO v_entry FROM public.count_entries
  WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
 END IF;
 RETURN v_entry;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.count_get_assignment_scope(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_member uuid; v_all boolean; v_ids jsonb;
BEGIN
 SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
 IF v_project IS NULL THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;
 SELECT id INTO v_member FROM public.count_members
 WHERE project_id=v_project AND user_id=(SELECT auth.uid()) AND role IN ('counter','auditor') AND status='active';
 IF v_member IS NULL THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.count_assignments WHERE session_id=p_session_id AND member_id=v_member AND location_id IS NULL AND status IN ('assigned','active')) INTO v_all;
 SELECT coalesce(jsonb_agg(location_id) FILTER(WHERE location_id IS NOT NULL),'[]'::jsonb)
 INTO v_ids FROM public.count_assignments
 WHERE session_id=p_session_id AND member_id=v_member AND status IN ('assigned','active');
 RETURN jsonb_build_object('has_assignments',counting_private.session_has_assignments(p_session_id),
  'all_locations',v_all,'location_ids',v_ids);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.count_get_assignment_scope(uuid) TO authenticated;

DROP POLICY IF EXISTS count_assignments_read ON public.count_assignments;
CREATE POLICY count_assignments_read ON public.count_assignments
FOR SELECT TO authenticated
USING (
 EXISTS (SELECT 1 FROM public.count_sessions s
  WHERE s.id=count_assignments.session_id AND (
   counting_private.is_supervisor(s.project_id)
   OR EXISTS (SELECT 1 FROM public.count_members m
    WHERE m.id=count_assignments.member_id AND m.project_id=s.project_id
      AND m.user_id=(SELECT auth.uid()) AND m.status='active')
  ))
);

```

---

## 20261119185320 — countflow_device_realtime_broadcast

- Statements: 1
- SQL characters: 3306
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.countflow_broadcast_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_project_id uuid;
 v_session_id uuid;
 v_member_id uuid;
 v_topic text;
 m record;
BEGIN
 IF TG_TABLE_NAME='count_sessions' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_session_id := coalesce(NEW.id,OLD.id);
  v_topic := 'countflow:session:'||v_session_id::text;
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes(v_topic,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  FOR m IN SELECT id FROM public.count_members WHERE project_id=v_project_id AND status IN ('active','paused') LOOP
   PERFORM realtime.broadcast_changes('countflow:member:'||m.id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END LOOP;
 ELSIF TG_TABLE_NAME='count_members' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.id,OLD.id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_assignments' THEN
  SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=coalesce(NEW.session_id,OLD.session_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_devices' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_import_batches' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSE
  v_session_id := coalesce(NEW.session_id,OLD.session_id);
  IF v_session_id IS NOT NULL THEN
   PERFORM realtime.broadcast_changes('countflow:session:'||v_session_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END IF;
  IF TG_TABLE_NAME='count_recount_tasks' THEN
   v_member_id := coalesce(NEW.assigned_member_id,OLD.assigned_member_id);
   IF v_member_id IS NOT NULL THEN
    PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
   END IF;
  END IF;
 END IF;
 RETURN NULL;
END;
$function$
;
DROP TRIGGER IF EXISTS countflow_broadcast_changes_trigger ON public.count_devices;
CREATE TRIGGER countflow_broadcast_changes_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.count_devices
FOR EACH ROW EXECUTE FUNCTION public.countflow_broadcast_changes();

```

---

## 20261119185755 — countflow_member_data_isolation_and_audit_write_restriction

- Statements: 1
- SQL characters: 1080
- Rollback recorded: NO

### Statement 1

```sql

DROP POLICY IF EXISTS count_entries_read ON public.count_entries;
CREATE POLICY count_entries_read ON public.count_entries
FOR SELECT TO authenticated
USING (
 counting_private.is_supervisor(project_id)
 OR EXISTS (
  SELECT 1 FROM public.count_members m
  WHERE m.id=count_entries.member_id
    AND m.project_id=count_entries.project_id
    AND m.user_id=(SELECT auth.uid())
 )
);

DROP POLICY IF EXISTS count_members_read ON public.count_members;
CREATE POLICY count_members_read ON public.count_members
FOR SELECT TO authenticated
USING (counting_private.is_supervisor(project_id) OR user_id=(SELECT auth.uid()));

DROP POLICY IF EXISTS count_import_read ON public.count_import_batches;
CREATE POLICY count_import_read ON public.count_import_batches
FOR SELECT TO authenticated
USING (counting_private.is_supervisor(project_id));

DROP POLICY IF EXISTS count_audit_insert ON public.count_audit_log;
CREATE POLICY count_audit_insert ON public.count_audit_log
FOR INSERT TO authenticated
WITH CHECK (counting_private.is_supervisor(project_id) AND actor_id=(SELECT auth.uid()));

```

---

## 20261119185811 — countflow_evidence_storage_member_scope

- Statements: 1
- SQL characters: 1617
- Rollback recorded: NO

### Statement 1

```sql

DROP POLICY IF EXISTS count_evidence_insert ON storage.objects;
CREATE POLICY count_evidence_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
 bucket_id='counting-evidence'
 AND CASE
  WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
   AND (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$'
   AND (storage.foldername(name))[3] ~* '^[0-9a-f-]{36}$'
  THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
   OR EXISTS (
    SELECT 1 FROM public.count_entries e
    JOIN public.count_members m ON m.id=e.member_id
    WHERE e.id=((storage.foldername(name))[3])::uuid
      AND e.session_id=((storage.foldername(name))[2])::uuid
      AND e.project_id=((storage.foldername(name))[1])::uuid
      AND m.user_id=(SELECT auth.uid()) AND m.status='active'
   )
  ELSE false
 END
);

DROP POLICY IF EXISTS count_evidence_read ON storage.objects;
CREATE POLICY count_evidence_read ON storage.objects
FOR SELECT TO authenticated
USING (
 bucket_id='counting-evidence'
 AND CASE
  WHEN (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
   AND (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$'
   AND (storage.foldername(name))[3] ~* '^[0-9a-f-]{36}$'
  THEN counting_private.is_supervisor(((storage.foldername(name))[1])::uuid)
   OR EXISTS (
    SELECT 1 FROM public.count_entries e
    JOIN public.count_members m ON m.id=e.member_id
    WHERE e.id=((storage.foldername(name))[3])::uuid
      AND e.session_id=((storage.foldername(name))[2])::uuid
      AND e.project_id=((storage.foldername(name))[1])::uuid
      AND m.user_id=(SELECT auth.uid())
   )
  ELSE false
 END
);

```

---

## 20261119185920 — countflow_append_only_insert_policy_full_validation

- Statements: 1
- SQL characters: 1915
- Rollback recorded: NO

### Statement 1

```sql

DROP POLICY IF EXISTS count_entries_insert ON public.count_entries;
CREATE POLICY count_entries_insert ON public.count_entries
FOR INSERT TO authenticated
WITH CHECK (
 quantity>=0 AND quantity<=999999999
 AND client_event_id IS NOT NULL
 AND nullif(btrim(device_id),'') IS NOT NULL
 AND counted_at BETWEEN now()-interval '5 minutes' AND now()+interval '1 minute'
 AND revision=1 AND count_round=1
 AND supersedes_id IS NULL AND recount_task_id IS NULL
 AND EXISTS (
  SELECT 1 FROM public.count_sessions s
  WHERE s.id=count_entries.session_id
    AND s.project_id=count_entries.project_id
    AND s.status='active'
 )
 AND EXISTS (
  SELECT 1 FROM public.count_members m
  WHERE m.id=count_entries.member_id
    AND m.project_id=count_entries.project_id
    AND m.user_id=(SELECT auth.uid())
    AND m.role IN ('counter','auditor')
    AND m.status='active'
 )
 AND EXISTS (
  SELECT 1 FROM public.count_products p
  WHERE p.id=count_entries.product_id
    AND p.project_id=count_entries.project_id
    AND p.is_active
    AND (
     p.base_unit=count_entries.unit
     OR EXISTS (
      SELECT 1 FROM jsonb_array_elements(
       CASE WHEN jsonb_typeof(p.units)='array' THEN p.units ELSE '[]'::jsonb END
      ) u WHERE coalesce(u->>'name',u#>>'{}')=count_entries.unit
     )
    )
 )
 AND (
  count_entries.location_id IS NULL
  OR EXISTS (
   SELECT 1 FROM public.count_locations l
   WHERE l.id=count_entries.location_id AND l.project_id=count_entries.project_id
  )
 )
 AND EXISTS (
  SELECT 1 FROM public.count_devices d
  WHERE d.project_id=count_entries.project_id
    AND d.member_id=count_entries.member_id
    AND d.device_id=count_entries.device_id
    AND d.status='active'
 )
 AND (
  NOT counting_private.session_has_assignments(count_entries.session_id)
  OR counting_private.member_has_location_assignment(
   count_entries.session_id,count_entries.member_id,count_entries.location_id
  )
 )
);

```

---

## 20261119185943 — countflow_device_status_supervisor_only

- Statements: 1
- SQL characters: 2588
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.set_device_status(p_device_id uuid,p_status text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE v_device public.count_devices;
BEGIN
 IF p_status NOT IN ('active','revoked') THEN RAISE EXCEPTION 'INVALID_DEVICE_STATUS'; END IF;
 SELECT * INTO v_device FROM public.count_devices WHERE id=p_device_id FOR UPDATE;
 IF NOT FOUND OR NOT counting_private.is_supervisor(v_device.project_id) THEN
  RAISE EXCEPTION 'DEVICE_NOT_FOUND_OR_FORBIDDEN';
 END IF;
 UPDATE public.count_devices SET status=p_status,
  revoked_by=CASE WHEN p_status='revoked' THEN (SELECT auth.uid()) ELSE NULL END,
  revoked_at=CASE WHEN p_status='revoked' THEN now() ELSE NULL END
 WHERE id=p_device_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_device.project_id,(SELECT auth.uid()),
  CASE WHEN p_status='revoked' THEN 'device.revoked' ELSE 'device.reactivated' END,
  'device',p_device_id,jsonb_build_object('member_id',v_device.member_id,'device_id',v_device.device_id));
 RETURN jsonb_build_object('device_id',p_device_id,'status',p_status);
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.set_device_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION counting_private.set_device_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_set_device_status(p_device_id uuid,p_status text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $function$
 SELECT counting_private.set_device_status(p_device_id,p_status);
$function$;
GRANT EXECUTE ON FUNCTION public.count_set_device_status(uuid,text) TO authenticated;

DROP POLICY IF EXISTS count_devices_update ON public.count_devices;
CREATE POLICY count_devices_update ON public.count_devices
FOR UPDATE TO authenticated
USING (
 counting_private.is_supervisor(project_id)
 OR EXISTS (
  SELECT 1 FROM public.count_members m
  WHERE m.id=count_devices.member_id AND m.project_id=count_devices.project_id
   AND m.user_id=(SELECT auth.uid()) AND m.status='active'
   AND count_devices.status='active'
 )
)
WITH CHECK (
 counting_private.is_supervisor(project_id)
 OR EXISTS (
  SELECT 1 FROM public.count_members m
  WHERE m.id=count_devices.member_id AND m.project_id=count_devices.project_id
   AND m.user_id=(SELECT auth.uid()) AND m.status='active'
   AND count_devices.status='active'
 )
);

REVOKE UPDATE ON public.count_devices FROM authenticated;
GRANT UPDATE(device_label,platform,app_version,last_seen_at) ON public.count_devices TO authenticated;

```

---

## 20261119190029 — countflow_first_device_autoapproval_and_new_device_supervisor_gate

- Statements: 1
- SQL characters: 4909
- Rollback recorded: NO

### Statement 1

```sql

ALTER TABLE public.count_devices DROP CONSTRAINT count_devices_status_check;
ALTER TABLE public.count_devices ADD CONSTRAINT count_devices_status_check CHECK(status IN ('active','pending','revoked'));

CREATE OR REPLACE FUNCTION counting_private.register_count_device(
 p_project_id uuid,p_member_id uuid,p_device_id text,p_device_label text,p_platform text,p_app_version text
)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_device public.count_devices;v_has_history boolean;
BEGIN
 PERFORM 1 FROM public.count_members WHERE id=p_member_id AND project_id=p_project_id
  AND user_id=(SELECT auth.uid()) AND status='active' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'MEMBER_NOT_ACTIVE'; END IF;
 SELECT * INTO v_device FROM public.count_devices
 WHERE project_id=p_project_id AND device_id=p_device_id FOR UPDATE;
 IF FOUND THEN
  IF v_device.member_id<>p_member_id THEN RAISE EXCEPTION 'DEVICE_OWNED_BY_ANOTHER_MEMBER'; END IF;
  IF v_device.status<>'active' THEN RETURN v_device.status; END IF;
  UPDATE public.count_devices SET device_label=coalesce(p_device_label,device_label),
   platform=coalesce(p_platform,platform),app_version=coalesce(p_app_version,app_version),last_seen_at=now()
  WHERE id=v_device.id;
  RETURN 'active';
 END IF;
 SELECT EXISTS(SELECT 1 FROM public.count_devices WHERE project_id=p_project_id AND member_id=p_member_id)
 INTO v_has_history;
 INSERT INTO public.count_devices(project_id,member_id,device_id,device_label,platform,app_version,status,last_seen_at)
 VALUES(p_project_id,p_member_id,p_device_id,p_device_label,p_platform,p_app_version,
  CASE WHEN v_has_history THEN 'pending' ELSE 'active' END,now());
 RETURN CASE WHEN v_has_history THEN 'pending' ELSE 'active' END;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.register_count_device(uuid,uuid,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION counting_private.register_count_device(uuid,uuid,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_touch_presence(p_session_id uuid, p_device_id text, p_device_label text DEFAULT NULL::text, p_platform text DEFAULT NULL::text, p_app_version text DEFAULT NULL::text, p_state text DEFAULT 'online'::text, p_location_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_member public.count_members;
  v_device_status text;
BEGIN
  IF nullif(btrim(p_device_id),'') IS NULL OR p_state NOT IN ('online','idle','offline') THEN
    RAISE EXCEPTION 'INVALID_PRESENCE_PAYLOAD';
  END IF;
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
  IF NOT FOUND OR v_session.status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE';
  END IF;
  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND THEN RAISE EXCEPTION 'MEMBER_NOT_ACTIVE'; END IF;
  IF p_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
  ) THEN RAISE EXCEPTION 'INVALID_PRESENCE_LOCATION'; END IF;

  v_device_status := counting_private.register_count_device(
    v_session.project_id,v_member.id,p_device_id,p_device_label,p_platform,p_app_version
  );
  IF v_device_status='pending' THEN RAISE EXCEPTION 'DEVICE_PENDING_APPROVAL'; END IF;
  IF v_device_status='revoked' THEN RAISE EXCEPTION 'DEVICE_REVOKED_OR_OWNED_BY_ANOTHER_MEMBER'; END IF;

  INSERT INTO public.count_presence(project_id,session_id,member_id,device_id,presence_state,current_location_id,started_at,last_seen_at)
  VALUES(v_session.project_id,p_session_id,v_member.id,p_device_id,p_state,p_location_id,now(),now())
  ON CONFLICT(session_id,member_id,device_id) DO UPDATE SET
    presence_state=EXCLUDED.presence_state,current_location_id=EXCLUDED.current_location_id,last_seen_at=now();

  RETURN jsonb_build_object('ok',true,'member_id',v_member.id,'session_id',p_session_id,'last_seen_at',now());
END;
$function$
;

DROP POLICY IF EXISTS count_devices_insert ON public.count_devices;
DROP POLICY IF EXISTS count_devices_insert_self ON public.count_devices;
DROP POLICY IF EXISTS count_devices_write_self_insert ON public.count_devices;
CREATE POLICY count_devices_insert ON public.count_devices
FOR INSERT TO authenticated
WITH CHECK (counting_private.is_supervisor(project_id));

DROP POLICY IF EXISTS count_devices_update ON public.count_devices;
CREATE POLICY count_devices_update ON public.count_devices
FOR UPDATE TO authenticated
USING (counting_private.is_supervisor(project_id))
WITH CHECK (counting_private.is_supervisor(project_id));

REVOKE INSERT,UPDATE ON public.count_devices FROM authenticated;
GRANT SELECT ON public.count_devices TO authenticated;

```

---

## 20261119190037 — countflow_persist_pending_device_registration

- Statements: 1
- SQL characters: 2281
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION public.count_touch_presence(p_session_id uuid, p_device_id text, p_device_label text DEFAULT NULL::text, p_platform text DEFAULT NULL::text, p_app_version text DEFAULT NULL::text, p_state text DEFAULT 'online'::text, p_location_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_member public.count_members;
  v_device_status text;
BEGIN
  IF nullif(btrim(p_device_id),'') IS NULL OR p_state NOT IN ('online','idle','offline') THEN
    RAISE EXCEPTION 'INVALID_PRESENCE_PAYLOAD';
  END IF;
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
  IF NOT FOUND OR v_session.status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE';
  END IF;
  SELECT * INTO v_member FROM public.count_members
  WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
    AND role IN ('counter','auditor') AND status='active';
  IF NOT FOUND THEN RAISE EXCEPTION 'MEMBER_NOT_ACTIVE'; END IF;
  IF p_location_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
  ) THEN RAISE EXCEPTION 'INVALID_PRESENCE_LOCATION'; END IF;

  v_device_status := counting_private.register_count_device(
    v_session.project_id,v_member.id,p_device_id,p_device_label,p_platform,p_app_version
  );
  IF v_device_status='pending' THEN
    RETURN jsonb_build_object('ok',false,'device_status','pending','message','DEVICE_PENDING_APPROVAL');
  END IF;
  IF v_device_status='revoked' THEN
    RETURN jsonb_build_object('ok',false,'device_status','revoked','message','DEVICE_REVOKED_OR_OWNED_BY_ANOTHER_MEMBER');
  END IF;

  INSERT INTO public.count_presence(project_id,session_id,member_id,device_id,presence_state,current_location_id,started_at,last_seen_at)
  VALUES(v_session.project_id,p_session_id,v_member.id,p_device_id,p_state,p_location_id,now(),now())
  ON CONFLICT(session_id,member_id,device_id) DO UPDATE SET
    presence_state=EXCLUDED.presence_state,current_location_id=EXCLUDED.current_location_id,last_seen_at=now();

  RETURN jsonb_build_object('ok',true,'member_id',v_member.id,'session_id',p_session_id,'last_seen_at',now());
END;
$function$
;
```

---

## 20261119190249 — countflow_fk_and_duplicate_index_advisor_fixes

- Statements: 1
- SQL characters: 236
- Rollback recorded: NO

### Statement 1

```sql

DROP INDEX IF EXISTS public.count_assignments_all_location_uq;
DROP INDEX IF EXISTS public.count_import_batches_mapping_idx;
CREATE INDEX count_import_batches_mapping_project_idx
 ON public.count_import_batches(mapping_id,project_id);

```

---

## 20261119190309 — countflow_realtime_evidence_and_location_updates

- Statements: 1
- SQL characters: 4445
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.countflow_broadcast_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_project_id uuid;
 v_session_id uuid;
 v_member_id uuid;
 v_topic text;
 m record;
BEGIN
 IF TG_TABLE_NAME='count_sessions' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_session_id := coalesce(NEW.id,OLD.id);
  v_topic := 'countflow:session:'||v_session_id::text;
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes(v_topic,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  FOR m IN SELECT id FROM public.count_members WHERE project_id=v_project_id AND status IN ('active','paused') LOOP
   PERFORM realtime.broadcast_changes('countflow:member:'||m.id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END LOOP;
 ELSIF TG_TABLE_NAME='count_members' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.id,OLD.id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_assignments' THEN
  SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=coalesce(NEW.session_id,OLD.session_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_entry_images' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  SELECT session_id INTO v_session_id FROM public.count_entries WHERE id=coalesce(NEW.entry_id,OLD.entry_id);
  IF v_session_id IS NOT NULL THEN
   PERFORM realtime.broadcast_changes('countflow:session:'||v_session_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END IF;
 ELSIF TG_TABLE_NAME='count_locations' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  FOR m IN SELECT id FROM public.count_members WHERE project_id=v_project_id AND status IN ('active','paused') LOOP
   PERFORM realtime.broadcast_changes('countflow:member:'||m.id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END LOOP;
 ELSIF TG_TABLE_NAME='count_devices' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  v_member_id := coalesce(NEW.member_id,OLD.member_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSIF TG_TABLE_NAME='count_import_batches' THEN
  v_project_id := coalesce(NEW.project_id,OLD.project_id);
  PERFORM realtime.broadcast_changes('countflow:project:'||v_project_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
 ELSE
  v_session_id := coalesce(NEW.session_id,OLD.session_id);
  IF v_session_id IS NOT NULL THEN
   PERFORM realtime.broadcast_changes('countflow:session:'||v_session_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
  END IF;
  IF TG_TABLE_NAME='count_recount_tasks' THEN
   v_member_id := coalesce(NEW.assigned_member_id,OLD.assigned_member_id);
   IF v_member_id IS NOT NULL THEN
    PERFORM realtime.broadcast_changes('countflow:member:'||v_member_id::text,TG_OP,TG_OP,TG_TABLE_NAME,TG_TABLE_SCHEMA,NEW,OLD);
   END IF;
  END IF;
 END IF;
 RETURN NULL;
END;
$function$
;
DROP TRIGGER IF EXISTS countflow_broadcast_changes_trigger ON public.count_entry_images;
CREATE TRIGGER countflow_broadcast_changes_trigger AFTER INSERT OR DELETE ON public.count_entry_images
FOR EACH ROW EXECUTE FUNCTION public.countflow_broadcast_changes();
DROP TRIGGER IF EXISTS countflow_broadcast_changes_trigger ON public.count_locations;
CREATE TRIGGER countflow_broadcast_changes_trigger AFTER INSERT OR UPDATE OR DELETE ON public.count_locations
FOR EACH ROW EXECUTE FUNCTION public.countflow_broadcast_changes();

```

---

## 20261119190448 — countflow_idempotent_retries_after_member_pause

- Statements: 1
- SQL characters: 8171
- Rollback recorded: NO

### Statement 1

```sql
CREATE OR REPLACE FUNCTION public.count_record_entry(p_session_id uuid, p_product_id uuid, p_location_id uuid, p_quantity numeric, p_unit text, p_client_event_id uuid, p_scan_code text DEFAULT NULL::text, p_device_id text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS count_entries
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 v_session public.count_sessions;
 v_member public.count_members;
 v_product public.count_products;
 v_entry public.count_entries;
 v_unit text := coalesce(nullif(trim(p_unit),''),'وحدة');
 v_has_assignments boolean;
BEGIN
 SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;

 SELECT * INTO v_member FROM public.count_members
 WHERE project_id=v_session.project_id AND user_id=(SELECT auth.uid())
   AND role IN ('counter','auditor');
 IF NOT FOUND THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;

 IF p_client_event_id IS NULL THEN RAISE EXCEPTION 'CLIENT_EVENT_ID_REQUIRED'; END IF;
 SELECT * INTO v_entry FROM public.count_entries
 WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
  RETURN v_entry;
 END IF;

 IF v_member.status<>'active' THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;
 IF v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
 IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 THEN RAISE EXCEPTION 'INVALID_QUANTITY'; END IF;
 IF nullif(btrim(p_device_id),'') IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.count_devices d
   WHERE d.project_id=v_session.project_id AND d.member_id=v_member.id
     AND d.device_id=p_device_id AND d.status='active'
 ) THEN RAISE EXCEPTION 'DEVICE_NOT_REGISTERED_OR_REVOKED'; END IF;

 SELECT * INTO v_product FROM public.count_products
 WHERE id=p_product_id AND project_id=v_session.project_id AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE_IN_PROJECT'; END IF;
 IF NOT (
   v_product.base_unit=v_unit
   OR EXISTS (
     SELECT 1 FROM jsonb_array_elements(
       CASE WHEN jsonb_typeof(v_product.units)='array' THEN v_product.units ELSE '[]'::jsonb END
     ) u WHERE coalesce(u->>'name',u#>>'{}')=v_unit
   )
 ) THEN RAISE EXCEPTION 'UNIT_NOT_ALLOWED_FOR_PRODUCT'; END IF;

 IF p_location_id IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.count_locations WHERE id=p_location_id AND project_id=v_session.project_id
 ) THEN RAISE EXCEPTION 'LOCATION_NOT_IN_PROJECT'; END IF;

 v_has_assignments := counting_private.session_has_assignments(p_session_id);
 IF v_has_assignments AND NOT counting_private.member_has_location_assignment(p_session_id,v_member.id,p_location_id) THEN
  RAISE EXCEPTION 'LOCATION_NOT_ASSIGNED';
 END IF;

 INSERT INTO public.count_entries(
   session_id,project_id,product_id,location_id,member_id,client_event_id,
   quantity,unit,scan_code,device_id,note
 ) VALUES (
   p_session_id,v_session.project_id,p_product_id,p_location_id,v_member.id,p_client_event_id,
   p_quantity,v_unit,p_scan_code,p_device_id,p_note
 )
 ON CONFLICT(session_id,client_event_id) DO NOTHING
 RETURNING * INTO v_entry;

 IF v_entry.id IS NULL THEN
  SELECT * INTO v_entry FROM public.count_entries
  WHERE session_id=p_session_id AND client_event_id=p_client_event_id;
  IF v_entry.member_id<>v_member.id OR v_entry.product_id<>p_product_id
    OR v_entry.location_id IS DISTINCT FROM p_location_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
 END IF;
 RETURN v_entry;
END;
$function$
;
CREATE OR REPLACE FUNCTION counting_private.record_recount_entry(p_task_id uuid, p_quantity numeric, p_unit text, p_client_event_id uuid, p_scan_code text DEFAULT NULL::text, p_device_id text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS count_entries
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_task public.count_recount_tasks;
 v_session public.count_sessions;
 v_member public.count_members;
 v_entry public.count_entries;
 v_previous public.count_entries;
 v_product public.count_products;
 v_next_round smallint;
 v_unit text := coalesce(nullif(trim(p_unit),''),'وحدة');
BEGIN
 IF p_quantity IS NULL OR p_quantity<0 OR p_quantity>999999999 OR p_client_event_id IS NULL THEN
  RAISE EXCEPTION 'INVALID_RECOUNT_PAYLOAD';
 END IF;
 SELECT * INTO v_task FROM public.count_recount_tasks WHERE id=p_task_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_FOUND'; END IF;
 SELECT * INTO v_member FROM public.count_members
 WHERE project_id=v_task.project_id AND user_id=(SELECT auth.uid())
   AND role IN ('counter','auditor');
 IF NOT FOUND OR v_task.assigned_member_id IS DISTINCT FROM v_member.id THEN
  RAISE EXCEPTION 'RECOUNT_TASK_NOT_ASSIGNED_TO_CALLER';
 END IF;
 SELECT * INTO v_entry FROM public.count_entries
 WHERE session_id=v_task.session_id AND client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_entry.member_id<>v_member.id OR v_entry.recount_task_id<>p_task_id
    OR v_entry.quantity<>p_quantity OR v_entry.unit<>v_unit THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  END IF;
  RETURN v_entry;
 END IF;
 IF v_member.status<>'active' THEN RAISE EXCEPTION 'COUNTER_NOT_ACTIVE'; END IF;
 IF v_task.status NOT IN ('assigned','in_progress') THEN RAISE EXCEPTION 'RECOUNT_TASK_NOT_OPEN'; END IF;
 SELECT * INTO v_session FROM public.count_sessions
 WHERE id=v_task.session_id AND project_id=v_task.project_id;
 IF NOT FOUND OR v_session.status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
 IF nullif(btrim(p_device_id),'') IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.count_devices d WHERE d.project_id=v_task.project_id
   AND d.member_id=v_member.id AND d.device_id=p_device_id AND d.status='active'
 ) THEN RAISE EXCEPTION 'DEVICE_NOT_REGISTERED_OR_REVOKED'; END IF;
 SELECT * INTO v_product FROM public.count_products
 WHERE id=v_task.product_id AND project_id=v_task.project_id AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE_IN_PROJECT'; END IF;
 IF NOT (
  v_product.base_unit=v_unit OR EXISTS(
   SELECT 1 FROM jsonb_array_elements(
    CASE WHEN jsonb_typeof(v_product.units)='array' THEN v_product.units ELSE '[]'::jsonb END
   ) u WHERE coalesce(u->>'name',u#>>'{}')=v_unit
  )
 ) THEN RAISE EXCEPTION 'UNIT_NOT_ALLOWED_FOR_PRODUCT'; END IF;
 SELECT * INTO v_previous FROM public.count_entries
 WHERE session_id=v_task.session_id AND product_id=v_task.product_id
   AND location_id IS NOT DISTINCT FROM v_task.location_id
 ORDER BY counted_at DESC,id DESC LIMIT 1;
 SELECT coalesce(max(count_round),1)+1 INTO v_next_round
 FROM public.count_entries
 WHERE session_id=v_task.session_id AND product_id=v_task.product_id
   AND location_id IS NOT DISTINCT FROM v_task.location_id;
 IF v_next_round>5 THEN RAISE EXCEPTION 'MAX_COUNT_ROUNDS_REACHED'; END IF;
 INSERT INTO public.count_entries(
  session_id,project_id,product_id,location_id,member_id,client_event_id,
  quantity,unit,scan_code,device_id,note,revision,supersedes_id,count_round,recount_task_id
 ) VALUES (
  v_task.session_id,v_task.project_id,v_task.product_id,v_task.location_id,v_member.id,p_client_event_id,
  p_quantity,v_unit,p_scan_code,p_device_id,p_note,v_next_round,v_previous.id,v_next_round,p_task_id
 ) RETURNING * INTO v_entry;
 UPDATE public.count_recount_tasks SET status='completed',second_count_quantity=p_quantity,
  started_at=coalesce(started_at,now()),completed_at=now(),notes=coalesce(nullif(p_note,''),notes)
 WHERE id=p_task_id;
 INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
 VALUES(v_task.project_id,(SELECT auth.uid()),'recount.completed','recount_task',p_task_id,
  jsonb_build_object('entry_id',v_entry.id,'quantity',p_quantity,'count_round',v_next_round));
 RETURN v_entry;
END;
$function$
;
```

---

## 20261119190750 — countflow_revoke_unsafe_anon_and_ddl_privileges

- Statements: 1
- SQL characters: 1962
- Rollback recorded: NO

### Statement 1

```sql

-- CountFlow is an isolated application surface. RLS is not a substitute
-- for revoking TRUNCATE / REFERENCES / TRIGGER, which are not row-filtered.
REVOKE ALL PRIVILEGES ON TABLE
  public.count_alerts,
  public.count_anomaly_rules,
  public.count_assignments,
  public.count_audit_log,
  public.count_devices,
  public.count_entries,
  public.count_entry_images,
  public.count_expected_balances,
  public.count_exports,
  public.count_import_batches,
  public.count_import_mappings,
  public.count_import_rows,
  public.count_locations,
  public.count_members,
  public.count_presence,
  public.count_products,
  public.count_projects,
  public.count_reconciliation_lines,
  public.count_reconciliation_runs,
  public.count_recount_tasks,
  public.count_sessions
FROM anon;

REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.count_alerts,
  public.count_anomaly_rules,
  public.count_assignments,
  public.count_audit_log,
  public.count_devices,
  public.count_entries,
  public.count_entry_images,
  public.count_expected_balances,
  public.count_exports,
  public.count_import_batches,
  public.count_import_mappings,
  public.count_import_rows,
  public.count_locations,
  public.count_members,
  public.count_presence,
  public.count_products,
  public.count_projects,
  public.count_reconciliation_lines,
  public.count_reconciliation_runs,
  public.count_recount_tasks,
  public.count_sessions
FROM authenticated;

-- Public SECURITY DEFINER helpers / trigger entrypoint must not be callable
-- through the Data API by anon or ordinary authenticated clients.
REVOKE EXECUTE ON FUNCTION public.count_is_member(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.count_is_supervisor(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.countflow_broadcast_changes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_is_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_is_supervisor(uuid) TO authenticated;

```

---

## 20261119191119 — countflow_reconciliation_approved_recount_override_v1

- Statements: 1
- SQL characters: 6726
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_run_id uuid;
  v_run_number integer;
BEGIN
  SELECT * INTO v_session
  FROM public.count_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN
    RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION';
  END IF;

  SELECT coalesce(max(run_number),0)+1 INTO v_run_number
  FROM public.count_reconciliation_runs
  WHERE session_id = p_session_id;

  INSERT INTO public.count_reconciliation_runs(
    project_id, session_id, run_number, status, created_by, created_at
  ) VALUES (
    v_session.project_id, p_session_id, v_run_number, 'building', (SELECT auth.uid()), now()
  ) RETURNING id INTO v_run_id;

  WITH expected AS (
    SELECT product_id, location_id, sum(expected_quantity)::numeric AS expected_qty,
           max(unit) AS unit
    FROM public.count_expected_balances
    WHERE session_id = p_session_id
    GROUP BY product_id, location_id
  ),
  counted_base AS (
    -- First-round entries are the base result. Recount entries are immutable
    -- evidence and must never be added to the first-round quantity.
    SELECT product_id, location_id, sum(quantity)::numeric AS counted_qty,
           max(unit) AS unit
    FROM public.count_entries
    WHERE session_id = p_session_id AND recount_task_id IS NULL
    GROUP BY product_id, location_id
  ),
  latest_reviewed_recount AS (
    -- Only a supervisor-reviewed recount supersedes the base count.
    -- A pending, completed-but-unreviewed, repeated, or cancelled recount
    -- remains visible in the audit trail but does not change the official total.
    SELECT DISTINCT ON (t.product_id,t.location_id)
      t.product_id,t.location_id,t.second_count_quantity,
      (
        SELECT e.unit
        FROM public.count_entries e
        WHERE e.recount_task_id=t.id
        ORDER BY e.counted_at DESC,e.id DESC
        LIMIT 1
      ) AS unit
    FROM public.count_recount_tasks t
    WHERE t.session_id=p_session_id
      AND t.status='reviewed'
      AND t.second_count_quantity IS NOT NULL
    ORDER BY t.product_id,t.location_id,t.reviewed_at DESC NULLS LAST,t.created_at DESC,t.id DESC
  ),
  counted_metrics AS (
    -- Preserve the true audit event/counter metrics across all rounds,
    -- while quantity comes from the first round or latest approved recount.
    SELECT product_id,location_id,count(*)::bigint AS events,
           count(DISTINCT member_id)::integer AS counters
    FROM public.count_entries
    WHERE session_id=p_session_id
    GROUP BY product_id,location_id
  ),
  counted AS (
    SELECT coalesce(b.product_id,r.product_id) AS product_id,
           coalesce(b.location_id,r.location_id) AS location_id,
           coalesce(r.second_count_quantity,b.counted_qty) AS counted_qty,
           coalesce(r.unit,b.unit,'وحدة') AS unit,
           coalesce(m.events,0) AS events,
           coalesce(m.counters,0) AS counters
    FROM counted_base b
    FULL OUTER JOIN latest_reviewed_recount r
      ON r.product_id=b.product_id
     AND r.location_id IS NOT DISTINCT FROM b.location_id
    LEFT JOIN counted_metrics m
      ON m.product_id=coalesce(b.product_id,r.product_id)
     AND m.location_id IS NOT DISTINCT FROM coalesce(b.location_id,r.location_id)
  ),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,
           coalesce(e.location_id,c.location_id) location_id,
           e.expected_qty, c.counted_qty, coalesce(c.unit,e.unit,'وحدة') unit,
           coalesce(c.events,0) events, coalesce(c.counters,0) counters
    FROM expected e
    FULL OUTER JOIN counted c
      ON c.product_id=e.product_id
     AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*, p.sku, p.name product_name,
           coalesce(l.name,'غير محدد') location_name
    FROM merged m
    JOIN public.count_products p ON p.id=m.product_id
    LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(
    project_id,run_id,session_id,product_id,location_id,product_sku,product_name,
    location_path,unit,expected_quantity,counted_quantity,variance_quantity,
    variance_percent,counted_events,counter_count,result_status,computed_at
  )
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,
         e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
         CASE WHEN e.expected_qty IS NULL THEN NULL
              ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
         CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL
              ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
         e.events,e.counters,
         CASE WHEN e.expected_qty IS NULL THEN 'not_expected'
              WHEN e.counted_qty IS NULL THEN 'not_counted'
              WHEN e.counted_qty=e.expected_qty THEN 'matched'
              WHEN e.counted_qty<e.expected_qty THEN 'under'
              ELSE 'over' END,
         now()
  FROM enriched e;

  UPDATE public.count_reconciliation_runs r
  SET status='computed',
      expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
      counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
      matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
      variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
      uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
      total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      computed_at=now()
  WHERE r.id=v_run_id;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,
      'approved_recount_override',true));

  RETURN v_run_id;
END;
$function$;

```

---

## 20261119191232 — countflow_unit_conversion_snapshots_and_effective_totals_v1

- Statements: 1
- SQL characters: 12490
- Rollback recorded: NO

### Statement 1

```sql

-- Snapshot the conversion factor at the moment each immutable count is recorded.
ALTER TABLE public.count_entries
  ADD COLUMN unit_factor_to_base numeric(18,8) NOT NULL DEFAULT 1
    CHECK (unit_factor_to_base > 0 AND unit_factor_to_base <= 1000000000),
  ADD COLUMN base_quantity numeric(24,8)
    GENERATED ALWAYS AS (quantity * unit_factor_to_base) STORED;

CREATE OR REPLACE FUNCTION counting_private.unit_factor_to_base(p_product_id uuid,p_unit text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_base_unit text;
  v_units jsonb;
  v_factor_text text;
  v_factor numeric;
BEGIN
  SELECT base_unit,units INTO v_base_unit,v_units
  FROM public.count_products
  WHERE id=p_product_id;
  IF NOT FOUND OR nullif(btrim(p_unit),'') IS NULL THEN RETURN NULL; END IF;
  IF p_unit=v_base_unit THEN RETURN 1; END IF;

  SELECT coalesce(u.value->>'factor_to_base',u.value->>'conversion_factor',u.value->>'factor')
  INTO v_factor_text
  FROM jsonb_array_elements(
    CASE WHEN jsonb_typeof(v_units)='array' THEN v_units ELSE '[]'::jsonb END
  ) AS u(value)
  WHERE coalesce(u.value->>'name',u.value#>>'{}')=p_unit
  LIMIT 1;

  IF v_factor_text IS NULL OR v_factor_text !~ '^[0-9]+([.][0-9]{1,8})?$' THEN
    RETURN NULL;
  END IF;
  v_factor:=v_factor_text::numeric;
  IF v_factor<=0 OR v_factor>1000000000 THEN RETURN NULL; END IF;
  RETURN v_factor;
END;
$function$;

REVOKE ALL ON FUNCTION counting_private.unit_factor_to_base(uuid,text) FROM PUBLIC,anon;
GRANT USAGE ON SCHEMA counting_private TO authenticated;
GRANT EXECUTE ON FUNCTION counting_private.unit_factor_to_base(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE v_factor numeric;
BEGIN
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS count_entries_unit_conversion_guard ON public.count_entries;
CREATE TRIGGER count_entries_unit_conversion_guard
BEFORE INSERT ON public.count_entries
FOR EACH ROW EXECUTE FUNCTION counting_private.set_count_entry_unit_factor();

CREATE OR REPLACE FUNCTION counting_private.guard_product_unit_change_during_count()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF (OLD.base_unit IS DISTINCT FROM NEW.base_unit OR OLD.units IS DISTINCT FROM NEW.units)
     AND EXISTS (
       SELECT 1
       FROM public.count_entries e
       JOIN public.count_sessions s ON s.id=e.session_id
       WHERE e.product_id=OLD.id
         AND s.status IN ('active','paused','review')
     ) THEN
    RAISE EXCEPTION 'PRODUCT_UNITS_LOCKED_DURING_ACTIVE_COUNT';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS count_products_unit_change_guard ON public.count_products;
CREATE TRIGGER count_products_unit_change_guard
BEFORE UPDATE OF base_unit,units ON public.count_products
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_product_unit_change_during_count();

CREATE OR REPLACE FUNCTION counting_private.session_effective_counts(p_session_id uuid)
RETURNS TABLE(
  product_id uuid,
  location_id uuid,
  counted_qty numeric,
  unit text,
  events bigint,
  counters integer
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  WITH base AS (
    SELECT e.product_id,e.location_id,
           sum(e.base_quantity)::numeric AS counted_qty,
           max(p.base_unit) AS unit
    FROM public.count_entries e
    JOIN public.count_products p ON p.id=e.product_id
    WHERE e.session_id=p_session_id AND e.recount_task_id IS NULL
    GROUP BY e.product_id,e.location_id
  ),
  latest_reviewed_recount AS (
    SELECT DISTINCT ON (t.product_id,t.location_id)
      t.product_id,t.location_id,re.base_quantity AS counted_qty,p.base_unit AS unit
    FROM public.count_recount_tasks t
    JOIN public.count_products p ON p.id=t.product_id
    JOIN LATERAL (
      SELECT e.base_quantity
      FROM public.count_entries e
      WHERE e.recount_task_id=t.id
      ORDER BY e.counted_at DESC,e.id DESC
      LIMIT 1
    ) re ON true
    WHERE t.session_id=p_session_id
      AND t.status='reviewed'
      AND t.second_count_quantity IS NOT NULL
    ORDER BY t.product_id,t.location_id,t.reviewed_at DESC NULLS LAST,t.created_at DESC,t.id DESC
  ),
  metrics AS (
    SELECT e.product_id,e.location_id,count(*)::bigint AS events,
           count(DISTINCT e.member_id)::integer AS counters
    FROM public.count_entries e
    WHERE e.session_id=p_session_id
    GROUP BY e.product_id,e.location_id
  )
  SELECT coalesce(b.product_id,r.product_id),
         coalesce(b.location_id,r.location_id),
         coalesce(r.counted_qty,b.counted_qty),
         coalesce(r.unit,b.unit,'وحدة'),
         coalesce(m.events,0),
         coalesce(m.counters,0)
  FROM base b
  FULL OUTER JOIN latest_reviewed_recount r
    ON r.product_id=b.product_id
   AND r.location_id IS NOT DISTINCT FROM b.location_id
  LEFT JOIN metrics m
    ON m.product_id=coalesce(b.product_id,r.product_id)
   AND m.location_id IS NOT DISTINCT FROM coalesce(b.location_id,r.location_id);
$function$;

REVOKE ALL ON FUNCTION counting_private.session_effective_counts(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION counting_private.session_effective_counts(uuid) TO authenticated;

-- Replace the reconciliation's duplicated aggregation with the canonical effective-count helper.
CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_session public.count_sessions;
  v_run_id uuid;
  v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN
    RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION';
  END IF;

  SELECT coalesce(max(run_number),0)+1 INTO v_run_number
  FROM public.count_reconciliation_runs WHERE session_id=p_session_id;

  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now())
  RETURNING id INTO v_run_id;

  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
    FROM public.count_expected_balances
    WHERE session_id=p_session_id
    GROUP BY product_id,location_id
  ),
  counted AS (
    SELECT * FROM counting_private.session_effective_counts(p_session_id)
  ),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,
           coalesce(e.location_id,c.location_id) location_id,
           e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,
           coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e
    FULL OUTER JOIN counted c
      ON c.product_id=e.product_id
     AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m
    JOIN public.count_products p ON p.id=m.product_id
    LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(
    project_id,run_id,session_id,product_id,location_id,product_sku,product_name,
    location_path,unit,expected_quantity,counted_quantity,variance_quantity,
    variance_percent,counted_events,counter_count,result_status,computed_at
  )
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,
         e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
         CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
         CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL
              ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
         e.events,e.counters,
         CASE WHEN e.expected_qty IS NULL THEN 'not_expected'
              WHEN e.counted_qty IS NULL THEN 'not_counted'
              WHEN e.counted_qty=e.expected_qty THEN 'matched'
              WHEN e.counted_qty<e.expected_qty THEN 'under'
              ELSE 'over' END,
         now()
  FROM enriched e;

  UPDATE public.count_reconciliation_runs r
  SET status='computed',
      expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
      counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
      matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
      variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
      uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
      total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
      computed_at=now()
  WHERE r.id=v_run_id;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,
      'approved_recount_override',true,'unit_normalization','base_quantity_snapshot'));
  RETURN v_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
    'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
    'counted_positions',(SELECT count(*) FROM counting_private.session_effective_counts(p_session_id)),
    'counted_products',(SELECT count(DISTINCT product_id) FROM counting_private.session_effective_counts(p_session_id)),
    'counted_locations',(SELECT count(DISTINCT location_id) FROM counting_private.session_effective_counts(p_session_id) WHERE location_id IS NOT NULL),
    'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    'quantity_total',(SELECT coalesce(sum(counted_qty),0) FROM counting_private.session_effective_counts(p_session_id)),
    'quantity_by_unit',(SELECT coalesce(jsonb_object_agg(unit,total_qty),'{}'::jsonb)
      FROM (SELECT unit,sum(counted_qty) total_qty FROM counting_private.session_effective_counts(p_session_id) GROUP BY unit) q),
    'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
    'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
    'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
    'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
    'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
    'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;

```

---

## 20261119191603 — countflow_remove_exposed_security_definer_helpers

- Statements: 1
- SQL characters: 320
- Rollback recorded: NO

### Statement 1

```sql

-- The UI and RLS policies use counting_private helpers directly.
-- These legacy public wrappers are not part of the client contract.
REVOKE EXECUTE ON FUNCTION public.count_is_member(uuid) FROM authenticated, PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.count_is_supervisor(uuid) FROM authenticated, PUBLIC, anon;

```

---

## 20261119191833 — countflow_automatic_anomaly_alerts_v1

- Statements: 1
- SQL characters: 11414
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_evaluate_session_alerts(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_project uuid;
  r public.count_anomaly_rules;
  v_inserted integer := 0;
  v_n integer := 0;
  v_run uuid;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  FOR r IN SELECT * FROM public.count_anomaly_rules
    WHERE project_id=v_project AND is_active ORDER BY created_at
  LOOP
    IF r.rule_type='quantity_above' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,e.id,r.id,r.rule_type,r.severity,
        'كمية عد غير معتادة',
        jsonb_build_object('quantity',e.quantity,'quantity_base',e.base_quantity,
          'unit',e.unit,'threshold_base',r.threshold,'product_id',e.product_id,'member_id',e.member_id)
      FROM public.count_entries e
      WHERE e.session_id=p_session_id AND e.base_quantity>r.threshold
        AND NOT EXISTS (
          SELECT 1 FROM public.count_alerts a
          WHERE a.session_id=p_session_id AND a.rule_id=r.id AND a.entry_id=e.id
            AND a.status IN ('open','acknowledged')
        );
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_inserted := v_inserted + v_n;

    ELSIF r.rule_type='repeat_scan_window' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,max(e.id),r.id,r.rule_type,r.severity,
        'تكرار مسح الصنف في فترة قصيرة',
        jsonb_build_object('member_id',e.member_id,'product_id',e.product_id,'location_id',e.location_id,
          'event_count',count(*),'threshold',r.threshold,
          'window_minutes',coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      FROM public.count_entries e
      WHERE e.session_id=p_session_id
        AND e.counted_at>=now()-make_interval(mins=>coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      GROUP BY e.member_id,e.product_id,e.location_id
      HAVING count(*)>r.threshold
        AND NOT EXISTS (
          SELECT 1 FROM public.count_alerts a
          WHERE a.session_id=p_session_id AND a.rule_id=r.id
            AND a.details->>'member_id'=e.member_id::text
            AND a.details->>'product_id'=e.product_id::text
            AND a.status IN ('open','acknowledged')
        );
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_inserted := v_inserted + v_n;

    ELSIF r.rule_type='variance_percent_above' THEN
      SELECT id INTO v_run FROM public.count_reconciliation_runs
      WHERE session_id=p_session_id AND status IN ('computed','approved')
      ORDER BY run_number DESC LIMIT 1;
      IF v_run IS NOT NULL THEN
        INSERT INTO public.count_alerts(project_id,session_id,rule_id,alert_type,severity,title,details)
        SELECT v_project,p_session_id,r.id,r.rule_type,r.severity,
          'فرق جرد يتجاوز حد التنبيه',
          jsonb_build_object('line_id',l.id,'product_id',l.product_id,'location_id',l.location_id,
            'variance_percent',l.variance_percent,'threshold',r.threshold,'run_id',v_run)
        FROM public.count_reconciliation_lines l
        WHERE l.run_id=v_run AND l.variance_percent IS NOT NULL AND abs(l.variance_percent)>r.threshold
          AND NOT EXISTS (
            SELECT 1 FROM public.count_alerts a
            WHERE a.session_id=p_session_id AND a.rule_id=r.id
              AND a.details->>'line_id'=l.id::text AND a.status IN ('open','acknowledged')
          );
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_inserted := v_inserted + v_n;
      END IF;
    END IF;
  END LOOP;

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project,(SELECT auth.uid()),'alerts.evaluated','session',p_session_id,
    jsonb_build_object('created',v_inserted));
  RETURN jsonb_build_object('session_id',p_session_id,'created_alerts',v_inserted);
END;
$function$;

CREATE OR REPLACE FUNCTION counting_private.emit_count_entry_alerts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  r public.count_anomaly_rules;
  v_count integer;
  v_window integer;
BEGIN
  FOR r IN
    SELECT * FROM public.count_anomaly_rules
    WHERE project_id=NEW.project_id AND is_active
      AND rule_type IN ('quantity_above','repeat_scan_window')
    ORDER BY created_at
  LOOP
    IF r.rule_type='quantity_above' AND NEW.base_quantity>r.threshold THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT NEW.project_id,NEW.session_id,NEW.id,r.id,r.rule_type,r.severity,
        'كمية عد غير معتادة',
        jsonb_build_object('quantity',NEW.quantity,'quantity_base',NEW.base_quantity,
          'unit',NEW.unit,'threshold_base',r.threshold,'product_id',NEW.product_id,'member_id',NEW.member_id)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.count_alerts a
        WHERE a.session_id=NEW.session_id AND a.rule_id=r.id AND a.entry_id=NEW.id
          AND a.status IN ('open','acknowledged')
      );

    ELSIF r.rule_type='repeat_scan_window' THEN
      v_window:=greatest(1,least(120,coalesce(nullif(r.config->>'window_minutes','')::integer,5)));
      SELECT count(*) INTO v_count
      FROM public.count_entries e
      WHERE e.session_id=NEW.session_id AND e.member_id=NEW.member_id
        AND e.product_id=NEW.product_id AND e.location_id IS NOT DISTINCT FROM NEW.location_id
        AND e.counted_at>=now()-make_interval(mins=>v_window);

      IF v_count>r.threshold AND NOT EXISTS (
        SELECT 1 FROM public.count_alerts a
        WHERE a.session_id=NEW.session_id AND a.rule_id=r.id
          AND a.details->>'member_id'=NEW.member_id::text
          AND a.details->>'product_id'=NEW.product_id::text
          AND a.status IN ('open','acknowledged')
      ) THEN
        INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
        VALUES(NEW.project_id,NEW.session_id,NEW.id,r.id,r.rule_type,r.severity,
          'تكرار مسح الصنف في فترة قصيرة',
          jsonb_build_object('member_id',NEW.member_id,'product_id',NEW.product_id,
            'location_id',NEW.location_id,'event_count',v_count,'threshold',r.threshold,
            'window_minutes',v_window));
      END IF;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION counting_private.emit_count_entry_alerts() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS count_entries_auto_anomaly_alerts ON public.count_entries;
CREATE TRIGGER count_entries_auto_anomaly_alerts
AFTER INSERT ON public.count_entries
FOR EACH ROW EXECUTE FUNCTION counting_private.emit_count_entry_alerts();

-- Every reconciliation automatically evaluates variance rules after its run is marked computed.
CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
  SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;

  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
    FROM public.count_expected_balances WHERE session_id=p_session_id GROUP BY product_id,location_id
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,
      coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c
      ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id
    LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(
    project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at
  )
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,
    e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_qty IS NULL THEN 'not_expected' WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched' WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,
    now()
  FROM enriched e;

  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    computed_at=now() WHERE r.id=v_run_id;

  PERFORM public.count_evaluate_session_alerts(p_session_id);

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,
      'approved_recount_override',true,'unit_normalization','base_quantity_snapshot','alerts_evaluated',true));
  RETURN v_run_id;
END;
$function$;

```

---

## 20261119191854 — countflow_fix_repeat_alert_uuid_aggregate

- Statements: 1
- SQL characters: 3990
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_evaluate_session_alerts(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE v_project uuid; r public.count_anomaly_rules; v_inserted integer:=0; v_n integer:=0; v_run uuid;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  FOR r IN SELECT * FROM public.count_anomaly_rules WHERE project_id=v_project AND is_active ORDER BY created_at LOOP
    IF r.rule_type='quantity_above' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,e.id,r.id,r.rule_type,r.severity,'كمية عد غير معتادة',
        jsonb_build_object('quantity',e.quantity,'quantity_base',e.base_quantity,'unit',e.unit,
          'threshold_base',r.threshold,'product_id',e.product_id,'member_id',e.member_id)
      FROM public.count_entries e
      WHERE e.session_id=p_session_id AND e.base_quantity>r.threshold
        AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id
          AND a.rule_id=r.id AND a.entry_id=e.id AND a.status IN ('open','acknowledged'));
      GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;

    ELSIF r.rule_type='repeat_scan_window' THEN
      INSERT INTO public.count_alerts(project_id,session_id,entry_id,rule_id,alert_type,severity,title,details)
      SELECT v_project,p_session_id,(array_agg(e.id ORDER BY e.counted_at DESC,e.id DESC))[1],
        r.id,r.rule_type,r.severity,'تكرار مسح الصنف في فترة قصيرة',
        jsonb_build_object('member_id',e.member_id,'product_id',e.product_id,'location_id',e.location_id,
          'event_count',count(*),'threshold',r.threshold,
          'window_minutes',coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      FROM public.count_entries e
      WHERE e.session_id=p_session_id
        AND e.counted_at>=now()-make_interval(mins=>coalesce(nullif(r.config->>'window_minutes','')::integer,5))
      GROUP BY e.member_id,e.product_id,e.location_id
      HAVING count(*)>r.threshold
        AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id
          AND a.rule_id=r.id AND a.details->>'member_id'=e.member_id::text
          AND a.details->>'product_id'=e.product_id::text AND a.status IN ('open','acknowledged'));
      GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;

    ELSIF r.rule_type='variance_percent_above' THEN
      SELECT id INTO v_run FROM public.count_reconciliation_runs
      WHERE session_id=p_session_id AND status IN ('computed','approved') ORDER BY run_number DESC LIMIT 1;
      IF v_run IS NOT NULL THEN
        INSERT INTO public.count_alerts(project_id,session_id,rule_id,alert_type,severity,title,details)
        SELECT v_project,p_session_id,r.id,r.rule_type,r.severity,'فرق جرد يتجاوز حد التنبيه',
          jsonb_build_object('line_id',l.id,'product_id',l.product_id,'location_id',l.location_id,
            'variance_percent',l.variance_percent,'threshold',r.threshold,'run_id',v_run)
        FROM public.count_reconciliation_lines l
        WHERE l.run_id=v_run AND l.variance_percent IS NOT NULL AND abs(l.variance_percent)>r.threshold
          AND NOT EXISTS(SELECT 1 FROM public.count_alerts a WHERE a.session_id=p_session_id
            AND a.rule_id=r.id AND a.details->>'line_id'=l.id::text AND a.status IN ('open','acknowledged'));
        GET DIAGNOSTICS v_n=ROW_COUNT; v_inserted:=v_inserted+v_n;
      END IF;
    END IF;
  END LOOP;
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project,(SELECT auth.uid()),'alerts.evaluated','session',p_session_id,jsonb_build_object('created',v_inserted));
  RETURN jsonb_build_object('session_id',p_session_id,'created_alerts',v_inserted);
END;
$function$;

```

---

## 20261119192305 — countflow_reconciliation_approval_freeze_v1

- Statements: 1
- SQL characters: 7493
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE v_factor numeric;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.count_reconciliation_runs r
    WHERE r.session_id=NEW.session_id AND r.status='approved'
  ) THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_open_tasks integer;
  v_critical_alerts integer;
  v_later_runs integer;
  v_new_entries integer;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN
    RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;

  SELECT count(*) INTO v_later_runs FROM public.count_reconciliation_runs
  WHERE session_id=v_run.session_id AND run_number>v_run.run_number;
  IF v_later_runs>0 THEN RAISE EXCEPTION 'RECONCILIATION_NOT_LATEST'; END IF;

  SELECT count(*) INTO v_new_entries FROM public.count_entries
  WHERE session_id=v_run.session_id AND counted_at>v_run.computed_at;
  IF v_new_entries>0 THEN RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%',v_new_entries; END IF;

  SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks
  WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
  SELECT count(*) INTO v_critical_alerts FROM public.count_alerts
  WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
  IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
  IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;

  UPDATE public.count_reconciliation_runs
  SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now()
  WHERE id=p_run_id;

  UPDATE public.count_sessions SET status='review'
  WHERE id=v_run.session_id AND status IN ('active','paused');

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
    jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number,'session_frozen',true));
  RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now(),'session_status','review');
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=p_session_id AND status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;
  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
    FROM public.count_expected_balances WHERE session_id=p_session_id GROUP BY product_id,location_id
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at)
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_qty IS NULL THEN 'not_expected' WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched' WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,now()
  FROM enriched e;
  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    computed_at=now() WHERE r.id=v_run_id;
  PERFORM public.count_evaluate_session_alerts(p_session_id);
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,
      'unit_normalization','base_quantity_snapshot','alerts_evaluated',true));
  RETURN v_run_id;
END;
$function$;

```

---

## 20261119192405 — countflow_atomic_reconciliation_freeze_watermark_v1

- Statements: 1
- SQL characters: 8488
- Rollback recorded: NO

### Statement 1

```sql

ALTER TABLE public.count_reconciliation_runs
  ADD COLUMN IF NOT EXISTS entry_count_snapshot bigint NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE v_factor numeric; v_session_status text;
BEGIN
  -- Serialize entry creation against reconciliation approval/session closure.
  SELECT status INTO v_session_status
  FROM public.count_sessions WHERE id=NEW.session_id FOR UPDATE;
  IF NOT FOUND OR v_session_status<>'active' THEN
    RAISE EXCEPTION 'SESSION_NOT_ACTIVE';
  END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs r WHERE r.session_id=NEW.session_id AND r.status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=p_session_id AND status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;
  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,max(unit) AS unit
    FROM public.count_expected_balances WHERE session_id=p_session_id GROUP BY product_id,location_id
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(c.unit,e.unit,'وحدة') unit,coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.*,p.sku,p.name product_name,coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at)
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_qty IS NULL THEN 'not_expected' WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched' WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,now()
  FROM enriched e;
  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_quantity IS NOT NULL),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    entry_count_snapshot=(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    computed_at=now() WHERE r.id=v_run_id;
  PERFORM public.count_evaluate_session_alerts(p_session_id);
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,
      'unit_normalization','base_quantity_snapshot','alerts_evaluated',true,'entry_count_snapshot',
      (SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id)));
  RETURN v_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_session_status text;
  v_open_tasks integer;
  v_critical_alerts integer;
  v_later_runs integer;
  v_current_entry_count bigint;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN
    RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;

  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=v_run.session_id FOR UPDATE;
  IF NOT FOUND OR v_session_status NOT IN ('active','paused','review') THEN
    RAISE EXCEPTION 'SESSION_NOT_READY_FOR_APPROVAL';
  END IF;

  SELECT count(*) INTO v_later_runs FROM public.count_reconciliation_runs
  WHERE session_id=v_run.session_id AND run_number>v_run.run_number;
  IF v_later_runs>0 THEN RAISE EXCEPTION 'RECONCILIATION_NOT_LATEST'; END IF;

  SELECT count(*) INTO v_current_entry_count FROM public.count_entries WHERE session_id=v_run.session_id;
  IF v_current_entry_count<>v_run.entry_count_snapshot THEN
    RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%',v_current_entry_count-v_run.entry_count_snapshot;
  END IF;

  SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks
  WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
  SELECT count(*) INTO v_critical_alerts FROM public.count_alerts
  WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
  IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
  IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;

  UPDATE public.count_reconciliation_runs SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now()
  WHERE id=p_run_id;
  UPDATE public.count_sessions SET status='review' WHERE id=v_run.session_id AND status IN ('active','paused');

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
    jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number,
      'session_frozen',true,'entry_count_snapshot',v_run.entry_count_snapshot));
  RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now(),'session_status','review');
END;
$function$;

```

---

## 20261119192409 — countflow_approved_session_insert_error_order_fix

- Statements: 1
- SQL characters: 932
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE v_factor numeric; v_session_status text;
BEGIN
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=NEW.session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs r WHERE r.session_id=NEW.session_id AND r.status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  IF v_session_status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;

```

---

## 20261119192427 — countflow_count_entry_guard_definer_lock_fix

- Statements: 1
- SQL characters: 1051
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.set_count_entry_unit_factor()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE v_factor numeric; v_session_status text;
BEGIN
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=NEW.session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SESSION_NOT_FOUND'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs r WHERE r.session_id=NEW.session_id AND r.status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  IF v_session_status<>'active' THEN RAISE EXCEPTION 'SESSION_NOT_ACTIVE'; END IF;
  v_factor:=counting_private.unit_factor_to_base(NEW.product_id,NEW.unit);
  IF v_factor IS NULL THEN
    RAISE EXCEPTION 'UNIT_CONVERSION_REQUIRED: define a positive factor_to_base for every non-base unit';
  END IF;
  NEW.unit_factor_to_base:=v_factor;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.set_count_entry_unit_factor() FROM PUBLIC,anon,authenticated;

```

---

## 20261119192509 — countflow_approval_requires_all_positions_counted

- Statements: 1
- SQL characters: 2752
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_session_status text;
  v_open_tasks integer;
  v_critical_alerts integer;
  v_later_runs integer;
  v_current_entry_count bigint;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=v_run.session_id FOR UPDATE;
  IF NOT FOUND OR v_session_status NOT IN ('active','paused','review') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_APPROVAL'; END IF;
  SELECT count(*) INTO v_later_runs FROM public.count_reconciliation_runs WHERE session_id=v_run.session_id AND run_number>v_run.run_number;
  IF v_later_runs>0 THEN RAISE EXCEPTION 'RECONCILIATION_NOT_LATEST'; END IF;
  SELECT count(*) INTO v_current_entry_count FROM public.count_entries WHERE session_id=v_run.session_id;
  IF v_current_entry_count<>v_run.entry_count_snapshot THEN
    RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%',v_current_entry_count-v_run.entry_count_snapshot;
  END IF;
  IF v_run.uncounted_rows>0 THEN RAISE EXCEPTION 'UNCOUNTED_POSITIONS_REMAINING:%',v_run.uncounted_rows; END IF;
  SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
  SELECT count(*) INTO v_critical_alerts FROM public.count_alerts WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
  IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
  IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;
  UPDATE public.count_reconciliation_runs SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now() WHERE id=p_run_id;
  UPDATE public.count_sessions SET status='review' WHERE id=v_run.session_id AND status IN ('active','paused');
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
    jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number,'session_frozen',true,'entry_count_snapshot',v_run.entry_count_snapshot));
  RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now(),'session_status','review');
END;
$function$;

```

---

## 20261119192958 — countflow_live_kpi_and_alert_index_tuning_v1

- Statements: 1
- SQL characters: 3124
- Rollback recorded: NO

### Statement 1

```sql

CREATE INDEX IF NOT EXISTS count_entries_repeat_scan_idx
  ON public.count_entries(session_id,member_id,product_id,location_id,counted_at DESC);

CREATE INDEX IF NOT EXISTS count_alerts_open_entry_rule_idx
  ON public.count_alerts(session_id,rule_id,entry_id)
  WHERE status IN ('open','acknowledged');

CREATE INDEX IF NOT EXISTS count_alerts_open_rule_member_product_idx
  ON public.count_alerts(session_id,rule_id,(details->>'member_id'),(details->>'product_id'))
  WHERE status IN ('open','acknowledged');

CREATE OR REPLACE FUNCTION public.count_session_kpis(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  WITH effective AS MATERIALIZED (
    SELECT * FROM counting_private.session_effective_counts(p_session_id)
  ),
  effective_metrics AS (
    SELECT count(*)::bigint AS counted_positions,
      count(DISTINCT product_id)::bigint AS counted_products,
      count(DISTINCT location_id) FILTER (WHERE location_id IS NOT NULL)::bigint AS counted_locations,
      coalesce(sum(counted_qty),0)::numeric AS quantity_total
    FROM effective
  ),
  unit_totals AS (
    SELECT unit,sum(counted_qty)::numeric AS total_qty
    FROM effective GROUP BY unit
  ),
  unit_metrics AS (
    SELECT coalesce(jsonb_object_agg(unit,total_qty),'{}'::jsonb) AS quantity_by_unit
    FROM unit_totals
  )
  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'total_products',(SELECT count(*) FROM public.count_products WHERE project_id=v_project AND is_active),
    'expected_positions',(SELECT count(*) FROM public.count_expected_balances WHERE session_id=p_session_id),
    'counted_positions',em.counted_positions,
    'counted_products',em.counted_products,
    'counted_locations',em.counted_locations,
    'count_events',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    'quantity_total',em.quantity_total,
    'quantity_by_unit',um.quantity_by_unit,
    'events_last_minute',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=now()-interval '1 minute'),
    'events_today',(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id AND counted_at>=date_trunc('day',now())),
    'active_members',(SELECT count(*) FROM public.count_members WHERE project_id=v_project AND status='active'),
    'members_with_activity',(SELECT count(DISTINCT member_id) FROM public.count_entries WHERE session_id=p_session_id),
    'online_members',(SELECT count(DISTINCT member_id) FROM public.count_presence WHERE session_id=p_session_id AND presence_state='online' AND last_seen_at>=now()-interval '90 seconds'),
    'last_entry_at',(SELECT max(counted_at) FROM public.count_entries WHERE session_id=p_session_id)
  ) INTO v_result
  FROM effective_metrics em CROSS JOIN unit_metrics um;
  RETURN v_result;
END;
$function$;

```

---

## 20261119193513 — countflow_assignments_nulls_not_distinct_unique_scope_v1

- Statements: 1
- SQL characters: 334
- Rollback recorded: NO

### Statement 1

```sql

DROP INDEX IF EXISTS public.count_assignments_global_scope_uq;
ALTER TABLE public.count_assignments
  DROP CONSTRAINT IF EXISTS count_assignments_session_id_member_id_location_id_key;
CREATE UNIQUE INDEX count_assignments_session_member_location_uq
  ON public.count_assignments(session_id,member_id,location_id) NULLS NOT DISTINCT;

```

---

## 20261119193620 — countflow_expected_balance_snapshot_guard_v1

- Statements: 1
- SQL characters: 2370
- Rollback recorded: NO

### Statement 1

```sql

ALTER TABLE public.count_expected_balances
  ADD CONSTRAINT count_expected_balances_nonnegative_qty_ck CHECK (expected_quantity>=0);

CREATE OR REPLACE FUNCTION counting_private.guard_expected_balance_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_session_id uuid;
  v_product_id uuid;
  v_project_id uuid;
  v_session_project uuid;
  v_session_status text;
  v_base_unit text;
BEGIN
  IF TG_OP='DELETE' THEN
    v_session_id:=OLD.session_id;
    v_product_id:=OLD.product_id;
    v_project_id:=OLD.project_id;
  ELSE
    v_session_id:=NEW.session_id;
    v_product_id:=NEW.product_id;
    v_project_id:=NEW.project_id;
  END IF;

  SELECT project_id,status INTO v_session_project,v_session_status
  FROM public.count_sessions WHERE id=v_session_id FOR UPDATE;
  IF NOT FOUND OR v_session_project<>v_project_id THEN
    RAISE EXCEPTION 'EXPECTED_BALANCE_SESSION_SCOPE_INVALID';
  END IF;

  SELECT base_unit INTO v_base_unit
  FROM public.count_products WHERE id=v_product_id AND project_id=v_project_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'EXPECTED_BALANCE_PRODUCT_SCOPE_INVALID'; END IF;

  IF TG_OP<>'DELETE' THEN
    IF NEW.unit IS DISTINCT FROM v_base_unit THEN
      RAISE EXCEPTION 'EXPECTED_BALANCE_MUST_USE_BASE_UNIT:%',v_base_unit;
    END IF;
    IF NEW.expected_quantity<0 THEN RAISE EXCEPTION 'EXPECTED_BALANCE_NEGATIVE_NOT_ALLOWED'; END IF;
  END IF;

  IF EXISTS(SELECT 1 FROM public.count_entries WHERE session_id=v_session_id) THEN
    RAISE EXCEPTION 'EXPECTED_BALANCES_LOCKED_AFTER_FIRST_COUNT';
  END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=v_session_id) THEN
    RAISE EXCEPTION 'EXPECTED_BALANCES_LOCKED_AFTER_RECONCILIATION';
  END IF;
  IF v_session_status IN ('review','completed') THEN
    RAISE EXCEPTION 'EXPECTED_BALANCES_SESSION_FINALIZED';
  END IF;

  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.guard_expected_balance_mutation() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS count_expected_balances_snapshot_guard ON public.count_expected_balances;
CREATE TRIGGER count_expected_balances_snapshot_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.count_expected_balances
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_expected_balance_mutation();

```

---

## 20261119194632 — countflow_admin_audit_triggers_v1

- Statements: 1
- SQL characters: 4190
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.audit_countflow_row_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_new jsonb;
  v_old jsonb;
  v_project_id uuid;
  v_session_id uuid;
  v_entity_id uuid;
  v_actor_id uuid;
  v_action text;
BEGIN
  v_new:=CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
  v_old:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;

  IF TG_OP='UPDATE' AND v_new=v_old THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('count_devices','count_members')
     AND (v_new-'last_seen_at')=(v_old-'last_seen_at') THEN RETURN NEW; END IF;

  v_entity_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_session_id:=coalesce(nullif(v_new->>'session_id','')::uuid,nullif(v_old->>'session_id','')::uuid);
  v_project_id:=coalesce(nullif(v_new->>'project_id','')::uuid,nullif(v_old->>'project_id','')::uuid);

  IF TG_TABLE_NAME='count_projects' THEN
    v_project_id:=v_entity_id;
  ELSIF TG_TABLE_NAME='count_assignments' THEN
    SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=v_session_id;
  END IF;

  IF v_project_id IS NULL THEN RAISE EXCEPTION 'COUNT_AUDIT_PROJECT_SCOPE_MISSING:%',TG_TABLE_NAME; END IF;

  v_actor_id:=auth.uid();
  v_action:='countflow.'||TG_TABLE_NAME||'.'||lower(TG_OP);

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project_id,v_actor_id,v_action,TG_TABLE_NAME,v_entity_id,
    jsonb_build_object('operation',TG_OP,'session_id',v_session_id,'before',v_old,'after',v_new));

  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.audit_countflow_row_change() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_projects;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_projects
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_members;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_members
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_sessions;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_sessions
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_assignments;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_assignments
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_recount_tasks;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_recount_tasks
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_anomaly_rules;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_anomaly_rules
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_devices;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_devices
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_entry_images;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_entry_images
FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();

DROP TRIGGER IF EXISTS countflow_audit_status_change ON public.count_import_batches;
CREATE TRIGGER countflow_audit_status_change AFTER UPDATE OF status ON public.count_import_batches
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION counting_private.audit_countflow_row_change();

```

---

## 20261119194738 — countflow_audit_skip_service_member_provision_v1

- Statements: 1
- SQL characters: 1996
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.audit_countflow_row_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_new jsonb;
  v_old jsonb;
  v_project_id uuid;
  v_session_id uuid;
  v_entity_id uuid;
  v_actor_id uuid;
  v_action text;
BEGIN
  v_new:=CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
  v_old:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  v_actor_id:=auth.uid();

  -- Provisioning Edge Function writes membership through service_role and records
  -- its own explicit actor-aware audit event; suppress the duplicate null-actor row.
  IF TG_TABLE_NAME='count_members' AND TG_OP='INSERT' AND v_actor_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP='UPDATE' AND v_new=v_old THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('count_devices','count_members')
     AND (v_new-'last_seen_at')=(v_old-'last_seen_at') THEN RETURN NEW; END IF;

  v_entity_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_session_id:=coalesce(nullif(v_new->>'session_id','')::uuid,nullif(v_old->>'session_id','')::uuid);
  v_project_id:=coalesce(nullif(v_new->>'project_id','')::uuid,nullif(v_old->>'project_id','')::uuid);

  IF TG_TABLE_NAME='count_projects' THEN
    v_project_id:=v_entity_id;
  ELSIF TG_TABLE_NAME='count_assignments' THEN
    SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=v_session_id;
  END IF;

  IF v_project_id IS NULL THEN RAISE EXCEPTION 'COUNT_AUDIT_PROJECT_SCOPE_MISSING:%',TG_TABLE_NAME; END IF;
  v_action:='countflow.'||TG_TABLE_NAME||'.'||lower(TG_OP);

  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project_id,v_actor_id,v_action,TG_TABLE_NAME,v_entity_id,
    jsonb_build_object('operation',TG_OP,'session_id',v_session_id,'before',v_old,'after',v_new));

  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

```

---

## 20261119195107 — countflow_location_hierarchy_guard_and_session_heatmap_v1

- Statements: 1
- SQL characters: 7215
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION counting_private.guard_location_parent_scope()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE v_parent_project uuid; v_cycle boolean;
BEGIN
  IF NEW.parent_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.parent_id=NEW.id THEN RAISE EXCEPTION 'LOCATION_PARENT_CYCLE_SELF'; END IF;
  SELECT project_id INTO v_parent_project FROM public.count_locations WHERE id=NEW.parent_id;
  IF v_parent_project IS NULL OR v_parent_project<>NEW.project_id THEN
    RAISE EXCEPTION 'LOCATION_PARENT_MUST_BELONG_TO_SAME_PROJECT';
  END IF;
  WITH RECURSIVE parent_chain AS (
    SELECT id,parent_id,ARRAY[id]::uuid[] AS seen
    FROM public.count_locations WHERE id=NEW.parent_id AND project_id=NEW.project_id
    UNION ALL
    SELECT p.id,p.parent_id,c.seen||p.id
    FROM public.count_locations p
    JOIN parent_chain c ON p.id=c.parent_id
    WHERE p.project_id=NEW.project_id AND NOT p.id=ANY(c.seen)
  )
  SELECT EXISTS(SELECT 1 FROM parent_chain WHERE id=NEW.id) INTO v_cycle;
  IF v_cycle THEN RAISE EXCEPTION 'LOCATION_PARENT_CYCLE_NOT_ALLOWED'; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.guard_location_parent_scope() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS count_locations_parent_scope_guard ON public.count_locations;
CREATE TRIGGER count_locations_parent_scope_guard
BEFORE INSERT OR UPDATE OF parent_id,project_id ON public.count_locations
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_location_parent_scope();

CREATE OR REPLACE FUNCTION public.count_session_heatmap(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  WITH RECURSIVE location_tree AS (
    SELECT l.id,l.parent_id,l.code,l.name,l.location_type,l.sort_order,
      coalesce(nullif(l.code,''),l.name)::text AS location_path,
      ARRAY[l.id]::uuid[] AS seen
    FROM public.count_locations l
    WHERE l.project_id=v_project AND l.parent_id IS NULL
    UNION ALL
    SELECT c.id,c.parent_id,c.code,c.name,c.location_type,c.sort_order,
      p.location_path||' / '||coalesce(nullif(c.code,''),c.name),
      p.seen||c.id
    FROM public.count_locations c
    JOIN location_tree p ON c.parent_id=p.id
    WHERE c.project_id=v_project AND NOT c.id=ANY(p.seen)
  ),
  effective AS MATERIALIZED (
    SELECT location_id,product_id,counted_qty,count_events,last_count_at
    FROM counting_private.session_effective_counts(p_session_id)
  ),
  expected AS (
    SELECT location_id,count(*)::bigint AS expected_positions,
      coalesce(sum(expected_quantity),0)::numeric AS expected_quantity
    FROM public.count_expected_balances
    WHERE session_id=p_session_id
    GROUP BY location_id
  ),
  counted AS (
    SELECT location_id,count(*)::bigint AS counted_positions,
      coalesce(sum(counted_qty),0)::numeric AS counted_quantity,
      coalesce(sum(count_events),0)::bigint AS count_events,
      max(last_count_at) AS last_count_at
    FROM effective
    GROUP BY location_id
  ),
  assigned AS (
    SELECT DISTINCT location_id FROM public.count_assignments
    WHERE session_id=p_session_id AND location_id IS NOT NULL AND status='assigned'
  ),
  location_metrics AS (
    SELECT t.id AS location_id,t.code,t.name,t.parent_id,t.location_type,t.sort_order,t.location_path,
      coalesce(e.expected_positions,0)::bigint AS expected_positions,
      coalesce(c.counted_positions,0)::bigint AS counted_positions,
      coalesce(e.expected_quantity,0)::numeric AS expected_quantity,
      coalesce(c.counted_quantity,0)::numeric AS counted_quantity,
      coalesce(c.count_events,0)::bigint AS count_events,
      c.last_count_at
    FROM location_tree t
    LEFT JOIN expected e ON e.location_id=t.id
    LEFT JOIN counted c ON c.location_id=t.id
    WHERE e.location_id IS NOT NULL OR c.location_id IS NOT NULL
      OR EXISTS(SELECT 1 FROM assigned a WHERE a.location_id=t.id)
  ),
  unassigned_expected AS (
    SELECT count(*)::bigint AS expected_positions,coalesce(sum(expected_quantity),0)::numeric AS expected_quantity
    FROM public.count_expected_balances WHERE session_id=p_session_id AND location_id IS NULL
  ),
  unassigned_counted AS (
    SELECT count(*)::bigint AS counted_positions,coalesce(sum(counted_qty),0)::numeric AS counted_quantity,
      coalesce(sum(count_events),0)::bigint AS count_events,max(last_count_at) AS last_count_at
    FROM effective WHERE location_id IS NULL
  ),
  all_metrics AS (
    SELECT * FROM location_metrics
    UNION ALL
    SELECT NULL::uuid,'—'::text,'غير محدد'::text,NULL::uuid,'unassigned'::text,2147483647,
      'غير محدد'::text,ue.expected_positions,uc.counted_positions,ue.expected_quantity,uc.counted_quantity,
      uc.count_events,uc.last_count_at
    FROM unassigned_expected ue CROSS JOIN unassigned_counted uc
    WHERE ue.expected_positions>0 OR uc.counted_positions>0
  ),
  totals AS (
    SELECT coalesce(sum(expected_positions),0)::bigint AS expected_positions,
      coalesce(sum(counted_positions),0)::bigint AS counted_positions,
      coalesce(sum(expected_quantity),0)::numeric AS expected_quantity,
      coalesce(sum(counted_quantity),0)::numeric AS counted_quantity
    FROM all_metrics
  )
  SELECT jsonb_build_object(
    'session_id',p_session_id,
    'generated_at',now(),
    'expected_positions_total',t.expected_positions,
    'counted_positions_total',t.counted_positions,
    'coverage_percent_total',CASE WHEN t.expected_positions>0 THEN round(t.counted_positions*100.0/t.expected_positions,1) ELSE 0 END,
    'expected_quantity_total',t.expected_quantity,
    'counted_quantity_total',t.counted_quantity,
    'locations',coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'location_id',m.location_id,'code',m.code,'name',m.name,'parent_id',m.parent_id,
        'location_type',m.location_type,'path',m.location_path,
        'expected_positions',m.expected_positions,'counted_positions',m.counted_positions,
        'coverage_percent',CASE WHEN m.expected_positions>0 THEN round(m.counted_positions*100.0/m.expected_positions,1) ELSE 0 END,
        'expected_quantity',m.expected_quantity,'counted_quantity',m.counted_quantity,
        'variance_quantity',m.counted_quantity-m.expected_quantity,'count_events',m.count_events,
        'last_count_at',m.last_count_at,
        'status',CASE
          WHEN m.expected_positions=0 AND m.counted_positions>0 THEN 'unexpected'
          WHEN m.expected_positions=0 THEN 'no_baseline'
          WHEN m.counted_positions=0 THEN 'not_started'
          WHEN m.counted_positions<m.expected_positions THEN 'in_progress'
          ELSE 'complete' END
      ) ORDER BY m.location_path)
      FROM all_metrics m
    ),'[]'::jsonb)
  ) INTO v_result
  FROM totals t;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.count_session_heatmap(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.count_session_heatmap(uuid) TO authenticated;

```

---

## 20261119195202 — countflow_session_heatmap_helper_contract_fix_v1

- Statements: 1
- SQL characters: 5886
- Rollback recorded: NO

### Statement 1

```sql

CREATE OR REPLACE FUNCTION public.count_session_heatmap(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE v_project uuid; v_result jsonb;
BEGIN
  SELECT project_id INTO v_project FROM public.count_sessions WHERE id=p_session_id;
  IF v_project IS NULL OR NOT counting_private.is_supervisor(v_project) THEN
    RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  WITH RECURSIVE location_tree AS (
    SELECT l.id,l.parent_id,l.code,l.name,l.location_type,l.sort_order,
      coalesce(nullif(l.code,''),l.name)::text AS location_path,
      ARRAY[l.id]::uuid[] AS seen
    FROM public.count_locations l
    WHERE l.project_id=v_project AND l.parent_id IS NULL
    UNION ALL
    SELECT c.id,c.parent_id,c.code,c.name,c.location_type,c.sort_order,
      p.location_path||' / '||coalesce(nullif(c.code,''),c.name),
      p.seen||c.id
    FROM public.count_locations c
    JOIN location_tree p ON c.parent_id=p.id
    WHERE c.project_id=v_project AND NOT c.id=ANY(p.seen)
  ),
  effective AS MATERIALIZED (
    SELECT location_id,product_id,counted_qty,events,counters
    FROM counting_private.session_effective_counts(p_session_id)
  ),
  last_by_position AS (
    SELECT product_id,location_id,max(counted_at) AS last_count_at
    FROM public.count_entries WHERE session_id=p_session_id
    GROUP BY product_id,location_id
  ),
  expected AS (
    SELECT location_id,count(*)::bigint AS expected_positions,
      coalesce(sum(expected_quantity),0)::numeric AS expected_quantity
    FROM public.count_expected_balances
    WHERE session_id=p_session_id
    GROUP BY location_id
  ),
  counted AS (
    SELECT e.location_id,count(*)::bigint AS counted_positions,
      coalesce(sum(e.counted_qty),0)::numeric AS counted_quantity,
      coalesce(sum(e.events),0)::bigint AS count_events,
      max(l.last_count_at) AS last_count_at
    FROM effective e
    LEFT JOIN last_by_position l ON l.product_id=e.product_id AND l.location_id IS NOT DISTINCT FROM e.location_id
    GROUP BY e.location_id
  ),
  assigned AS (
    SELECT DISTINCT location_id FROM public.count_assignments
    WHERE session_id=p_session_id AND location_id IS NOT NULL AND status<>'cancelled'
  ),
  location_metrics AS (
    SELECT t.id AS location_id,t.code,t.name,t.parent_id,t.location_type,t.sort_order,t.location_path,
      coalesce(e.expected_positions,0)::bigint AS expected_positions,
      coalesce(c.counted_positions,0)::bigint AS counted_positions,
      coalesce(e.expected_quantity,0)::numeric AS expected_quantity,
      coalesce(c.counted_quantity,0)::numeric AS counted_quantity,
      coalesce(c.count_events,0)::bigint AS count_events,
      c.last_count_at
    FROM location_tree t
    LEFT JOIN expected e ON e.location_id=t.id
    LEFT JOIN counted c ON c.location_id=t.id
    WHERE e.location_id IS NOT NULL OR c.location_id IS NOT NULL
      OR EXISTS(SELECT 1 FROM assigned a WHERE a.location_id=t.id)
  ),
  unassigned_expected AS (
    SELECT count(*)::bigint AS expected_positions,coalesce(sum(expected_quantity),0)::numeric AS expected_quantity
    FROM public.count_expected_balances WHERE session_id=p_session_id AND location_id IS NULL
  ),
  unassigned_counted AS (
    SELECT count(*)::bigint AS counted_positions,coalesce(sum(counted_qty),0)::numeric AS counted_quantity,
      coalesce(sum(events),0)::bigint AS count_events,max(l.last_count_at) AS last_count_at
    FROM effective e
    LEFT JOIN last_by_position l ON l.product_id=e.product_id AND l.location_id IS NULL
    WHERE e.location_id IS NULL
  ),
  all_metrics AS (
    SELECT * FROM location_metrics
    UNION ALL
    SELECT NULL::uuid,'—'::text,'غير محدد'::text,NULL::uuid,'unassigned'::text,2147483647,
      'غير محدد'::text,ue.expected_positions,uc.counted_positions,ue.expected_quantity,uc.counted_quantity,
      uc.count_events,uc.last_count_at
    FROM unassigned_expected ue CROSS JOIN unassigned_counted uc
    WHERE ue.expected_positions>0 OR uc.counted_positions>0
  ),
  totals AS (
    SELECT coalesce(sum(expected_positions),0)::bigint AS expected_positions,
      coalesce(sum(counted_positions),0)::bigint AS counted_positions,
      coalesce(sum(expected_quantity),0)::numeric AS expected_quantity,
      coalesce(sum(counted_quantity),0)::numeric AS counted_quantity
    FROM all_metrics
  )
  SELECT jsonb_build_object(
    'session_id',p_session_id,'generated_at',now(),
    'expected_positions_total',t.expected_positions,'counted_positions_total',t.counted_positions,
    'coverage_percent_total',CASE WHEN t.expected_positions>0 THEN round(t.counted_positions*100.0/t.expected_positions,1) ELSE 0 END,
    'expected_quantity_total',t.expected_quantity,'counted_quantity_total',t.counted_quantity,
    'locations',coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'location_id',m.location_id,'code',m.code,'name',m.name,'parent_id',m.parent_id,
        'location_type',m.location_type,'path',m.location_path,
        'expected_positions',m.expected_positions,'counted_positions',m.counted_positions,
        'coverage_percent',CASE WHEN m.expected_positions>0 THEN round(m.counted_positions*100.0/m.expected_positions,1) ELSE 0 END,
        'expected_quantity',m.expected_quantity,'counted_quantity',m.counted_quantity,
        'variance_quantity',m.counted_quantity-m.expected_quantity,'count_events',m.count_events,
        'last_count_at',m.last_count_at,
        'status',CASE WHEN m.expected_positions=0 AND m.counted_positions>0 THEN 'unexpected'
          WHEN m.expected_positions=0 THEN 'no_baseline'
          WHEN m.counted_positions=0 THEN 'not_started'
          WHEN m.counted_positions<m.expected_positions THEN 'in_progress'
          ELSE 'complete' END
      ) ORDER BY m.location_path) FROM all_metrics m
    ),'[]'::jsonb)
  ) INTO v_result FROM totals t;
  RETURN v_result;
END;
$function$;

```

---

## 20261119195303 — countflow_rpc_and_immutable_ledger_acl_hardening_v1

- Statements: 1
- SQL characters: 1084
- Rollback recorded: NO

### Statement 1

```sql

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
           p.prorettype = 'trigger'::regtype AS is_trigger,
           p.prosecdef
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname LIKE 'count\_%' ESCAPE '\' OR p.proname = 'countflow_broadcast_changes')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.oid::regprocedure);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', r.oid::regprocedure);
    IF NOT r.is_trigger AND NOT r.prosecdef THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.oid::regprocedure);
    END IF;
  END LOOP;
END $$;

REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_audit_log FROM authenticated, anon;
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_reconciliation_lines FROM authenticated, anon;
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.count_entries FROM authenticated, anon;

```

---

## 20261119195750 — countflow_import_batch_sku_lookup_index_v1

- Statements: 1
- SQL characters: 138
- Rollback recorded: NO

### Statement 1

```sql
CREATE INDEX IF NOT EXISTS count_import_rows_batch_sku_lower_idx
ON public.count_import_rows (batch_id, lower(sku))
WHERE sku IS NOT NULL;
```

---
