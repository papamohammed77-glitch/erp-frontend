CREATE POLICY buyer_goods_docs_select_finance
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'employee-documents'
  AND (storage.foldername(name))[3] = 'buyer-goods'
  AND public.employee_document_storage_company_id(name) = app_private.current_user_company_id()
  AND public.employee_document_storage_employee_id(name) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_id = auth.uid()
      AND u.company_id = app_private.current_user_company_id()
      AND COALESCE(u.status, 'Active') = 'Active'
  )
  AND (
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
    OR COALESCE((public.get_my_effective_profile() ->> 'isOwner')::boolean, false)
  )
  AND EXISTS (
    SELECT 1
    FROM public.purchase_invoices pi
    WHERE pi.id = CASE
      WHEN (storage.foldername(name))[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN ((storage.foldername(name))[4])::uuid
      ELSE NULL::uuid
    END
      AND pi.company_id = app_private.current_user_company_id()
      AND pi.purchase_source = 'QUICK_MARKET'
  )
);