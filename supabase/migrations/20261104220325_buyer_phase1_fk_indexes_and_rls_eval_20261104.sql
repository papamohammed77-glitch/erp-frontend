-- Foreign-key and operational lookup indexes for Buyer custody and purchasing returns.
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_actor_user_id_company_idx
  ON public.buyer_goods_custody_events (actor_user_id, company_id);
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_branch_id_company_idx
  ON public.buyer_goods_custody_events (branch_id, company_id);
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_custodian_user_id_company_idx
  ON public.buyer_goods_custody_events (custodian_user_id, company_id);
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_item_id_company_idx
  ON public.buyer_goods_custody_events (item_id, company_id);
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_vehicle_id_company_idx
  ON public.buyer_goods_custody_events (vehicle_id, company_id)
  WHERE vehicle_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_goods_custody_events_reverses_event_id_company_idx
  ON public.buyer_goods_custody_events (reverses_event_id, company_id)
  WHERE reverses_event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS purchase_returns_branch_id_company_created_idx
  ON public.purchase_returns (branch_id, company_id, created_at DESC)
  WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_returns_purchase_invoice_id_company_idx
  ON public.purchase_returns (purchase_invoice_id, company_id);
CREATE INDEX IF NOT EXISTS purchase_returns_supplier_id_company_created_idx
  ON public.purchase_returns (supplier_id, company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS purchase_return_details_item_id_return_idx
  ON public.purchase_return_details (item_id, return_id);

-- Evaluate stable auth/permission helpers once per statement rather than once per row.
DROP POLICY IF EXISTS buyer_goods_custody_events_select_authorized ON public.buyer_goods_custody_events;
CREATE POLICY buyer_goods_custody_events_select_authorized
ON public.buyer_goods_custody_events
FOR SELECT
TO authenticated
USING (
  company_id = (SELECT app_private.current_user_company_id())
  AND (
    custodian_user_id = (
      SELECT u.id
      FROM public.users u
      WHERE u.auth_id = (SELECT auth.uid())
        AND u.company_id = buyer_goods_custody_events.company_id
        AND COALESCE(u.status, 'Active') = 'Active'
      LIMIT 1
    )
    OR (SELECT app_private.current_user_has_effective_permission('finance'))
    OR (SELECT app_private.current_user_has_effective_permission('finance_manager'))
    OR COALESCE(((SELECT public.get_my_effective_profile()) ->> 'isOwner')::boolean, false)
  )
);

DROP POLICY IF EXISTS purchase_attachments_select_scoped ON public.purchase_attachments;
CREATE POLICY purchase_attachments_select_scoped
ON public.purchase_attachments
FOR SELECT
TO authenticated
USING (
  company_id = (SELECT app_private.current_user_company_id())
  AND (
    document_type <> 'PurchaseInvoice'
    OR (SELECT app_private.current_user_has_effective_permission('finance'))
    OR (SELECT app_private.current_user_has_effective_permission('finance_manager'))
    OR COALESCE(((SELECT public.get_my_effective_profile()) ->> 'isOwner')::boolean, false)
    OR EXISTS (
      SELECT 1
      FROM public.purchase_invoices pi
      JOIN public.users u ON u.auth_id = (SELECT auth.uid())
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

DROP POLICY IF EXISTS purchase_returns_select_company ON public.purchase_returns;
CREATE POLICY purchase_returns_select_company
ON public.purchase_returns
FOR SELECT
TO authenticated
USING (company_id = (SELECT app_private.current_user_company_id()));

DROP POLICY IF EXISTS purchase_return_details_select_company ON public.purchase_return_details;
CREATE POLICY purchase_return_details_select_company
ON public.purchase_return_details
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.purchase_returns r
    WHERE r.id = purchase_return_details.return_id
      AND r.company_id = (SELECT app_private.current_user_company_id())
  )
);

DROP POLICY IF EXISTS buyer_goods_docs_select_finance ON storage.objects;
CREATE POLICY buyer_goods_docs_select_finance
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'employee-documents'
  AND (storage.foldername(name))[3] = 'buyer-goods'
  AND public.employee_document_storage_company_id(name) = (SELECT app_private.current_user_company_id())
  AND public.employee_document_storage_employee_id(name) IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id = (SELECT app_private.current_user_company_id())
      AND COALESCE(u.status, 'Active') = 'Active'
  )
  AND (
    (SELECT app_private.current_user_has_effective_permission('finance'))
    OR (SELECT app_private.current_user_has_effective_permission('finance_manager'))
    OR COALESCE(((SELECT public.get_my_effective_profile()) ->> 'isOwner')::boolean, false)
  )
  AND EXISTS (
    SELECT 1
    FROM public.purchase_invoices pi
    WHERE pi.id = CASE
      WHEN (storage.foldername(name))[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN ((storage.foldername(name))[4])::uuid
      ELSE NULL::uuid
    END
      AND pi.company_id = (SELECT app_private.current_user_company_id())
      AND pi.purchase_source = 'QUICK_MARKET'
  )
);