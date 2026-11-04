DROP POLICY IF EXISTS purchase_attachments_select_company ON public.purchase_attachments;
CREATE POLICY purchase_attachments_select_scoped
ON public.purchase_attachments
FOR SELECT
TO authenticated
USING (
  company_id = app_private.current_user_company_id()
  AND (
    document_type <> 'PurchaseInvoice'
    OR app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
    OR COALESCE((public.get_my_effective_profile() ->> 'isOwner')::boolean, false)
    OR EXISTS (
      SELECT 1
      FROM public.purchase_invoices pi
      JOIN public.users u ON u.auth_id = auth.uid()
      WHERE pi.id = purchase_attachments.document_id
        AND pi.company_id = purchase_attachments.company_id
        AND u.company_id = purchase_attachments.company_id
        AND COALESCE(u.status, 'Active') = 'Active'
        AND (
          pi.purchaser_user_id = u.id
          OR lower(COALESCE(pi.created_by, '')) = lower(COALESCE(u.email, ''))
        )
    )
  )
);