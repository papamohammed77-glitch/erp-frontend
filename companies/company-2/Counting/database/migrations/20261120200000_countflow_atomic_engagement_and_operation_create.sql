-- Atomic creation of a CountFlow engagement workspace and its first operation.
-- The contracting party and each operation name are intentionally separate values.
create or replace function public.count_create_engagement(
  p_client_name text,
  p_engagement_code text,
  p_operation_name text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_project_id uuid;
  v_session_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  if nullif(btrim(p_client_name), '') is null
     or length(btrim(p_client_name)) > 120
     or nullif(btrim(p_engagement_code), '') is null
     or length(btrim(p_engagement_code)) > 40
     or btrim(p_engagement_code) !~ '^[A-Za-z0-9_-]+$'
     or nullif(btrim(p_operation_name), '') is null
     or length(btrim(p_operation_name)) > 150 then
    raise exception 'INVALID_ENGAGEMENT_INPUT';
  end if;

  insert into public.count_projects(name, code, status, created_by)
  values (btrim(p_client_name), upper(btrim(p_engagement_code)), 'draft', (select auth.uid()))
  returning id into v_project_id;

  insert into public.count_sessions(project_id, name, status, created_by)
  values (v_project_id, btrim(p_operation_name), 'planned', (select auth.uid()))
  returning id into v_session_id;

  return jsonb_build_object(
    'project_id', v_project_id,
    'session_id', v_session_id,
    'client_name', btrim(p_client_name),
    'engagement_code', upper(btrim(p_engagement_code)),
    'operation_name', btrim(p_operation_name),
    'session_status', 'planned'
  );
end;
$function$;

revoke all on function public.count_create_engagement(text,text,text) from public, anon;
grant execute on function public.count_create_engagement(text,text,text) to authenticated;
