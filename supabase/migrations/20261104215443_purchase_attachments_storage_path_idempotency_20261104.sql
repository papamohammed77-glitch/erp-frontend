CREATE UNIQUE INDEX IF NOT EXISTS purchase_attachments_document_storage_path_uq
ON public.purchase_attachments (company_id, document_type, document_id, storage_path)
WHERE storage_path IS NOT NULL;