-- CountFlow only: remove inherited table-level destructive grants from cost snapshots.
REVOKE ALL ON TABLE public.count_session_product_costs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.count_session_product_costs TO authenticated;