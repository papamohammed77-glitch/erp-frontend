-- LVE-2026-11-20-742
-- Bind CountFlow platform-wide owner access to a verified Auth email.
-- No user_metadata/JWT custom metadata is trusted for authorization.
create or replace function counting_private.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from auth.users u
    where u.id = (select auth.uid())
      and lower(coalesce(u.email, '')) = 'owner@rawaea.com'
      and u.email_confirmed_at is not null
  );
$function$;

create or replace function counting_private.is_member(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select counting_private.is_platform_owner()
    or exists (
      select 1 from public.count_members m
      where m.project_id = p_project
        and m.user_id = (select auth.uid())
        and m.status in ('active','paused')
    );
$function$;

create or replace function counting_private.is_supervisor(p_project uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select counting_private.is_platform_owner()
    or exists (
      select 1 from public.count_members m
      where m.project_id = p_project
        and m.user_id = (select auth.uid())
        and m.role = 'supervisor'
        and m.status = 'active'
    );
$function$;

revoke all on function counting_private.is_platform_owner() from public, anon;
grant execute on function counting_private.is_platform_owner() to authenticated;
