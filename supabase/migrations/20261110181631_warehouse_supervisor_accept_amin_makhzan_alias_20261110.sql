CREATE OR REPLACE FUNCTION public.set_active_warehouse_role(p_user_id uuid, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app_private'
AS $function$
declare
  actor_company uuid;
  actor_default_branch uuid;
  actor_allowed jsonb;
  target_company uuid;
  target_default_branch uuid;
  target_allowed jsonb;
  actor_scope text[] := ARRAY[]::text[];
  target_scope text[] := ARRAY[]::text[];
  allowed boolean := false;
  warehouse_roles constant text[] := ARRAY['مخزني','أمين مخزن','امين مخزن'];
  allowed_roles constant text[] := ARRAY['استلام','تحضير','تحميل','مرتجعات','تفريغ','أذونات','جرد','احتياطي','مخزن شامل'];
begin
  select u.company_id, u.default_branch_id, u.allowed_branch_ids
    into actor_company, actor_default_branch, actor_allowed
  from public.users u
  where u.auth_id = auth.uid()
    and coalesce(u.role,'') <> ''
  limit 1;

  if actor_company is null then
    raise exception 'سياق المشرف غير محدد';
  end if;

  if exists (
       select 1 from public.users u
       where u.auth_id=auth.uid()
         and u.company_id=actor_company
         and coalesce(u.role,'')='مدير النظام'
     )
     or app_private.current_user_has_permission('warehouse_supervisor')
  then
    allowed := true;
  end if;

  if not allowed then
    raise exception 'غير مصرح بتعيين أدوار عمال المخازن';
  end if;

  if p_role is null or btrim(p_role)='' then
    raise exception 'الدور مطلوب';
  end if;
  if not (p_role = any(allowed_roles)) then
    raise exception 'دور مخزني غير معتمد: %', p_role;
  end if;

  if actor_default_branch is not null then
    select array[b.branch_code]
      into actor_scope
    from public.branches b
    where b.id=actor_default_branch
      and b.company_id=actor_company;
  end if;

  if coalesce(array_length(actor_scope,1),0)=0 and actor_allowed is not null then
    if jsonb_typeof(actor_allowed)='array' then
      select coalesce(array_agg(x),ARRAY[]::text[])
        into actor_scope
      from jsonb_array_elements_text(actor_allowed) x;
    elsif jsonb_typeof(actor_allowed)='string' then
      actor_scope := ARRAY[actor_allowed #>> '{}'];
    end if;
  end if;

  if coalesce(array_length(actor_scope,1),0)=0 then
    raise exception 'نطاق فرع المشرف غير محدد';
  end if;

  select u.company_id, u.default_branch_id, u.allowed_branch_ids
    into target_company, target_default_branch, target_allowed
  from public.users u
  where u.id=p_user_id
    and coalesce(u.status,'Active')='Active';

  if target_company is null or target_company <> actor_company then
    raise exception 'العضو لا ينتمي إلى شركة المشرف';
  end if;

  if not exists (
    select 1 from public.users u
    where u.id=p_user_id
      and coalesce(u.role,'') = any(warehouse_roles)
  ) then
    raise exception 'يمكن تعيين الدور لعضو مخزني أو أمين مخزن فقط';
  end if;

  if target_default_branch is not null then
    select array[b.branch_code]
      into target_scope
    from public.branches b
    where b.id=target_default_branch
      and b.company_id=actor_company;
  end if;

  if coalesce(array_length(target_scope,1),0)=0 and target_allowed is not null then
    if jsonb_typeof(target_allowed)='array' then
      select coalesce(array_agg(x),ARRAY[]::text[])
        into target_scope
      from jsonb_array_elements_text(target_allowed) x;
    elsif jsonb_typeof(target_allowed)='string' then
      target_scope := ARRAY[target_allowed #>> '{}'];
    end if;
  end if;

  if coalesce(array_length(target_scope,1),0)=0 then
    raise exception 'نطاق فرع العضو غير محدد';
  end if;

  if not ('*'=any(actor_scope)) then
    if not exists (
      select 1
      from unnest(actor_scope) a
      join unnest(target_scope) t on t=a
      where a<>'*'
    ) then
      raise exception 'لا يمكن تعيين دور لعضو خارج فرع المشرف';
    end if;
  end if;

  update public.users
  set active_warehouse_role = p_role
  where id=p_user_id
    and company_id=actor_company;

  return jsonb_build_object(
    'success',true,
    'user_id',p_user_id,
    'active_warehouse_role',p_role,
    'company_id',actor_company,
    'branch_scope',actor_scope
  );
end;
$function$

