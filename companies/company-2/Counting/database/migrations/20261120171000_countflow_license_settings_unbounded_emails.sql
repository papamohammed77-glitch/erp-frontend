-- Owner-only CountFlow license contact settings. The email array has no application-level cap.
create table if not exists public.count_platform_settings (
  id smallint primary key default 1 check (id = 1),
  license_emails text[] not null default array['owner@rawaea.com']::text[],
  updated_by uuid null references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.count_platform_settings enable row level security;
revoke all on public.count_platform_settings from public, anon, authenticated;
grant select, insert, update on public.count_platform_settings to authenticated;

drop policy if exists count_platform_settings_owner_read on public.count_platform_settings;
create policy count_platform_settings_owner_read
on public.count_platform_settings for select to authenticated
using (counting_private.is_platform_owner());

drop policy if exists count_platform_settings_owner_insert on public.count_platform_settings;
create policy count_platform_settings_owner_insert
on public.count_platform_settings for insert to authenticated
with check (counting_private.is_platform_owner() and id = 1);

drop policy if exists count_platform_settings_owner_update on public.count_platform_settings;
create policy count_platform_settings_owner_update
on public.count_platform_settings for update to authenticated
using (counting_private.is_platform_owner())
with check (counting_private.is_platform_owner() and id = 1);

insert into public.count_platform_settings(id, license_emails)
values (1, array['owner@rawaea.com']::text[])
on conflict (id) do nothing;

comment on table public.count_platform_settings is
'CountFlow owner-only platform settings. license_emails is intentionally an unbounded text array (subject only to PostgreSQL row/storage limits), not a capped user list.';
