-- Client applications use the hardened counting_private helpers.
-- Keep public SECURITY DEFINER wrappers out of the exposed RPC surface.
REVOKE EXECUTE ON FUNCTION public.count_is_member(uuid) FROM authenticated, PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.count_is_supervisor(uuid) FROM authenticated, PUBLIC, anon;
