-- RAWAEA ERP — Buyer Quick Market evidence Storage access
-- Date: 2026-11-09
-- Production project: fiilmooggumokxanwiyx
-- Source record for policies applied directly to SMART ERP Production.
-- Repository policy: migrations in this folder are source records; this SQL was
-- executed through the authorized direct SQL path, not through apply_migration.
--
-- Security boundary:
-- - authenticated, active Buyer with effective purchases permission
-- - exact company / users.id / buyer-goods / Quick Market invoice path
-- - invoice must belong to that purchaser and have purchase_source QUICK_MARKET
-- - uploads/replacements only while invoice is Draft and not received
-- - SELECT grants the owner read access to their own invoice and handover evidence
-- - no DELETE policy is added; finance SELECT policy remains unchanged
--
-- The two accepted filename families map to existing Buyer flows:
-- supplier-invoice-*  -> quickPurchase() supplier invoice attachment (upsert)
-- handover-*           -> recordQuickMarketHandover() physical handover evidence (insert only)

DROP POLICY IF EXISTS buyer_goods_docs_insert_owner ON storage.objects;
CREATE POLICY buyer_goods_docs_insert_owner
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'employee-documents'
  AND cardinality(storage.foldername(storage.objects.name)) = 4
  AND (storage.foldername(storage.objects.name))[3] = 'buyer-goods'
  AND (
    storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
  )
  AND EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.purchase_invoices pi
      ON pi.id::text = (storage.foldername(storage.objects.name))[4]
     AND pi.company_id = u.company_id
     AND pi.purchaser_user_id = u.id
     AND pi.purchase_source = 'QUICK_MARKET'
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id::text = (storage.foldername(storage.objects.name))[1]
      AND u.id::text = (storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status, 'Active') = 'Active'
      AND app_private.current_user_has_effective_permission('purchases')
      AND pi.status = 'Draft'
      AND pi.is_received = false
      AND pi.received_date IS NULL
  )
);

DROP POLICY IF EXISTS buyer_goods_docs_select_owner ON storage.objects;
CREATE POLICY buyer_goods_docs_select_owner
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'employee-documents'
  AND cardinality(storage.foldername(storage.objects.name)) = 4
  AND (storage.foldername(storage.objects.name))[3] = 'buyer-goods'
  AND (
    storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
  )
  AND EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.purchase_invoices pi
      ON pi.id::text = (storage.foldername(storage.objects.name))[4]
     AND pi.company_id = u.company_id
     AND pi.purchaser_user_id = u.id
     AND pi.purchase_source = 'QUICK_MARKET'
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id::text = (storage.foldername(storage.objects.name))[1]
      AND u.id::text = (storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status, 'Active') = 'Active'
      AND app_private.current_user_has_effective_permission('purchases')
  )
);

DROP POLICY IF EXISTS buyer_goods_docs_update_owner ON storage.objects;
CREATE POLICY buyer_goods_docs_update_owner
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'employee-documents'
  AND cardinality(storage.foldername(storage.objects.name)) = 4
  AND (storage.foldername(storage.objects.name))[3] = 'buyer-goods'
  AND storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
  AND EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.purchase_invoices pi
      ON pi.id::text = (storage.foldername(storage.objects.name))[4]
     AND pi.company_id = u.company_id
     AND pi.purchaser_user_id = u.id
     AND pi.purchase_source = 'QUICK_MARKET'
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id::text = (storage.foldername(storage.objects.name))[1]
      AND u.id::text = (storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status, 'Active') = 'Active'
      AND app_private.current_user_has_effective_permission('purchases')
      AND pi.status = 'Draft'
      AND pi.is_received = false
      AND pi.received_date IS NULL
  )
)
WITH CHECK (
  bucket_id = 'employee-documents'
  AND cardinality(storage.foldername(storage.objects.name)) = 4
  AND (storage.foldername(storage.objects.name))[3] = 'buyer-goods'
  AND storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
  AND EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.purchase_invoices pi
      ON pi.id::text = (storage.foldername(storage.objects.name))[4]
     AND pi.company_id = u.company_id
     AND pi.purchaser_user_id = u.id
     AND pi.purchase_source = 'QUICK_MARKET'
    WHERE u.auth_id = (SELECT auth.uid())
      AND u.company_id::text = (storage.foldername(storage.objects.name))[1]
      AND u.id::text = (storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status, 'Active') = 'Active'
      AND app_private.current_user_has_effective_permission('purchases')
      AND pi.status = 'Draft'
      AND pi.is_received = false
      AND pi.received_date IS NULL
  )
);
