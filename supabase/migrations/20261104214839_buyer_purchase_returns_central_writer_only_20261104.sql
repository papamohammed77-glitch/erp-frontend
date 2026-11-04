-- Buyer / Parent returns: read through RLS, write only through central atomic RPCs.
REVOKE ALL PRIVILEGES ON TABLE public.purchase_returns, public.purchase_return_details FROM anon, authenticated;
GRANT SELECT ON TABLE public.purchase_returns, public.purchase_return_details TO authenticated;

DROP POLICY IF EXISTS purchase_returns_company ON public.purchase_returns;
CREATE POLICY purchase_returns_select_company
ON public.purchase_returns
FOR SELECT
TO authenticated
USING (company_id = app_private.current_user_company_id());

DROP POLICY IF EXISTS purchase_return_details_company ON public.purchase_return_details;
CREATE POLICY purchase_return_details_select_company
ON public.purchase_return_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.purchase_returns r
    WHERE r.id = purchase_return_details.return_id
      AND r.company_id = app_private.current_user_company_id()
  )
);