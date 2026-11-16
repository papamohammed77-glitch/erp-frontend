-- Restrict receipt-history realtime access to existing purchasing scope or the
-- authenticated actor who created the receipt. No business rows or balances change.

CREATE POLICY receiving_select_purchases_permission
ON public.receiving
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND app_private.current_user_has_effective_permission('purchases')
);

CREATE POLICY receiving_select_actor_email
ON public.receiving
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND lower(btrim(coalesce(responsible,''))) =
      lower(btrim(coalesce((select auth.jwt()->>'email'),'')))
);

CREATE POLICY receiving_details_select_purchases_permission
ON public.receiving_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.receiving r
    WHERE r.operation_id = receiving_details.operation_id
      AND r.company_id = app_private.current_user_company_id()
      AND app_private.current_user_has_effective_permission('purchases')
  )
);

CREATE POLICY receiving_details_select_actor_email
ON public.receiving_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.receiving r
    WHERE r.operation_id = receiving_details.operation_id
      AND r.company_id = app_private.current_user_company_id()
      AND lower(btrim(coalesce(r.responsible,''))) =
          lower(btrim(coalesce((select auth.jwt()->>'email'),'')))
  )
);

ALTER PUBLICATION supabase_realtime
  ADD TABLE public.receiving, public.receiving_details;
