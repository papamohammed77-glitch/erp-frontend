BEGIN;

CREATE OR REPLACE FUNCTION public.owner_login_alias_sync_atomic(
  p_actor_user_id uuid,
  p_auth_user_id uuid,
  p_actor_email text,
  p_expected_old_email text,
  p_new_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_user public.users%ROWTYPE;
  v_owner public.owner_profile%ROWTYPE;
  v_new_email text;
  v_old_email text;
  v_user_rows integer := 0;
  v_owner_rows integer := 0;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_actor_user_id IS NULL
     OR p_auth_user_id IS NULL
     OR NULLIF(BTRIM(p_actor_email), '') IS NULL
     OR NULLIF(BTRIM(p_expected_old_email), '') IS NULL
     OR NULLIF(BTRIM(p_new_email), '') IS NULL THEN
    RAISE EXCEPTION 'OWNER_ALIAS_ARGUMENTS_INVALID';
  END IF;

  v_old_email := LOWER(BTRIM(p_expected_old_email));
  v_new_email := LOWER(BTRIM(p_new_email));

  IF LENGTH(v_new_email) > 254
     OR v_new_email !~ '^[a-z0-9][a-z0-9._+-]{0,63}@(rawaea|alrawae)\.com$' THEN
    RAISE EXCEPTION 'OWNER_ALIAS_DOMAIN_OR_FORMAT_INVALID';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_new_email, 771042));

  SELECT *
    INTO v_user
    FROM public.users u
   WHERE u.id = p_actor_user_id
     AND u.auth_id = p_auth_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OWNER_USER_LINK_NOT_FOUND';
  END IF;

  SELECT *
    INTO v_owner
    FROM public.owner_profile op
   WHERE op.auth_user_id = p_auth_user_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OWNER_PROFILE_LINK_NOT_FOUND';
  END IF;

  IF COALESCE(v_user.status, 'Active') <> 'Active'
     OR jsonb_typeof(v_user.permissions) <> 'array'
     OR NOT (v_user.permissions ? '*') THEN
    RAISE EXCEPTION 'ACTIVE_OWNER_WILDCARD_REQUIRED';
  END IF;

  IF LOWER(v_user.email) <> v_old_email
     OR LOWER(v_owner.owner_email) <> v_old_email
     OR LOWER(p_actor_email) <> v_old_email THEN
    RAISE EXCEPTION 'OWNER_ALIAS_STALE_OR_MISMATCHED';
  END IF;

  IF v_new_email = v_old_email THEN
    RETURN jsonb_build_object(
      'success', true,
      'changed', false,
      'auth_user_id', p_auth_user_id,
      'user_id', v_user.id,
      'email', v_old_email
    );
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.users u
     WHERE LOWER(u.email) = v_new_email
       AND u.auth_id IS DISTINCT FROM p_auth_user_id
  ) THEN
    RAISE EXCEPTION 'OWNER_ALIAS_ALREADY_USED_BY_USER';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.owner_profile op
     WHERE LOWER(op.owner_email) = v_new_email
       AND op.auth_user_id IS DISTINCT FROM p_auth_user_id
  ) THEN
    RAISE EXCEPTION 'OWNER_ALIAS_ALREADY_USED_BY_OWNER_PROFILE';
  END IF;

  UPDATE public.users
     SET email = v_new_email,
         updated_at = now()
   WHERE id = v_user.id
     AND auth_id = p_auth_user_id;
  GET DIAGNOSTICS v_user_rows = ROW_COUNT;

  UPDATE public.owner_profile
     SET owner_email = v_new_email,
         updated_at = now()
   WHERE id = v_owner.id
     AND auth_user_id = p_auth_user_id;
  GET DIAGNOSTICS v_owner_rows = ROW_COUNT;

  IF v_user_rows <> 1 OR v_owner_rows <> 1 THEN
    RAISE EXCEPTION 'OWNER_ALIAS_SYNC_ROWCOUNT_MISMATCH';
  END IF;

  INSERT INTO public.audit_log (
    user_email, action, table_name, record_id, old_data, new_data,
    company_id, actor_user_id, source_type, operation_id
  )
  VALUES (
    p_actor_email,
    'update',
    'owner_profile',
    v_owner.id::text,
    jsonb_build_object('auth_user_id', p_auth_user_id, 'owner_email', v_old_email),
    jsonb_build_object('auth_user_id', p_auth_user_id, 'owner_email', v_new_email),
    v_user.company_id,
    p_actor_user_id,
    'authentication',
    'OWNER_LOGIN_ALIAS_CHANGE:' || p_auth_user_id::text
  );

  RETURN jsonb_build_object(
    'success', true,
    'changed', true,
    'auth_user_id', p_auth_user_id,
    'user_id', v_user.id,
    'email', v_new_email
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.owner_login_alias_sync_atomic(uuid, uuid, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_login_alias_sync_atomic(uuid, uuid, text, text, text) FROM anon;
REVOKE ALL ON FUNCTION public.owner_login_alias_sync_atomic(uuid, uuid, text, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.owner_login_alias_sync_atomic(uuid, uuid, text, text, text) TO service_role;

COMMENT ON FUNCTION public.owner_login_alias_sync_atomic(uuid, uuid, text, text, text)
IS 'Owner-only synchronization of a synthetic Auth login alias into public.users and public.owner_profile with row locks, stale-value checks, duplicate guards, and audit logging. Service-role only.';

COMMIT;
