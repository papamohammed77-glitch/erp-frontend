DROP INDEX IF EXISTS public.count_assignments_global_scope_uq;
ALTER TABLE public.count_assignments
  DROP CONSTRAINT IF EXISTS count_assignments_session_id_member_id_location_id_key;
CREATE UNIQUE INDEX count_assignments_session_member_location_uq
  ON public.count_assignments(session_id,member_id,location_id) NULLS NOT DISTINCT;
