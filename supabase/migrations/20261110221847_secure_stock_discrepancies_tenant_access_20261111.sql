-- Applied to SMART ERP Production as 20261110221847.
-- Scope stock discrepancy reads to the authenticated company, reporter,
-- assigned Returns handler, and company supervisors. Inserts are reserved
-- for the authenticated report-discrepancy Edge Function using service_role.

ALTER TABLE public.stock_discrepancies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to insert discrepancies" ON public.stock_discrepancies;
DROP POLICY IF EXISTS "Allow authenticated users to read discrepancies" ON public.stock_discrepancies;
DROP POLICY IF EXISTS "Allow supervisors to update discrepancies" ON public.stock_discrepancies;
DROP POLICY IF EXISTS "Warehouse users read scoped return discrepancies" ON public.stock_discrepancies;
DROP POLICY IF EXISTS "Company supervisors update scoped return discrepancies" ON public.stock_discrepancies;

REVOKE ALL ON TABLE public.stock_discrepancies FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON TABLE public.stock_discrepancies TO authenticated;

CREATE POLICY "Warehouse users read scoped return discrepancies"
ON public.stock_discrepancies
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id = stock_discrepancies.company_id
      AND lower(coalesce(u.status, 'active')) = 'active'
      AND (
        u.id = stock_discrepancies.reported_by
        OR u.role IN ('supervisor', 'owner')
        OR EXISTS (
          SELECT 1
          FROM public.runsheets AS rs
          WHERE rs.id = stock_discrepancies.runsheet_id
            AND rs.company_id = u.company_id
            AND rs.return_handler_id = u.id
        )
      )
  )
);

CREATE POLICY "Company supervisors update scoped return discrepancies"
ON public.stock_discrepancies
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id = stock_discrepancies.company_id
      AND lower(coalesce(u.status, 'active')) = 'active'
      AND u.role IN ('supervisor', 'owner')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id = stock_discrepancies.company_id
      AND lower(coalesce(u.status, 'active')) = 'active'
      AND u.role IN ('supervisor', 'owner')
  )
);
