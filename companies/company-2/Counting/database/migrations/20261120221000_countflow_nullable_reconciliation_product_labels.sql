-- CountFlow: reconciliation is operationally valid when optional SKU/name are unknown.
-- Identity remains enforced on count_products by SKU-or-barcode; this relaxes labels only.
ALTER TABLE public.count_reconciliation_lines
  ALTER COLUMN product_sku DROP NOT NULL,
  ALTER COLUMN product_name DROP NOT NULL;