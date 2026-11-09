-- RAWAEA ERP — Buyer Quick Market supplier invoice evidence access
-- Date: 2026-11-09
-- Production project: fiilmooggumokxanwiyx
-- This is the source record for the direct Production policy change.
-- The policies were applied through the authorized Supabase SQL execution path;
-- do not use apply_migration for this repository's source-only migration records.
--
-- Security boundary:
-- - authenticated Buyer with effective purchases permission only
-- - the exact company / internal user id / buyer-goods / invoice id path
-- - invoice must belong to that purchaser and be QUICK_MARKET
-- - upload/replace only while invoice remains Draft and not received
-- - SELECT permits that owner to read their own evidence after posting
-- - no DELETE or access to another buyer's invoice evidence is granted

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
    storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}
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
    storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}
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


    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}
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


    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}
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


    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}
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


    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}
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

