CREATE INDEX IF NOT EXISTS count_import_rows_batch_sku_lower_idx
ON public.count_import_rows (batch_id, lower(sku))
WHERE sku IS NOT NULL;