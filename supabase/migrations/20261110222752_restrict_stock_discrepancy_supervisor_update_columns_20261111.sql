-- Applied to SMART ERP Production as 20261110222752.
-- Supervisor approval may change only the review status and reviewer notes.

REVOKE UPDATE ON TABLE public.stock_discrepancies FROM authenticated;
GRANT UPDATE (status, notes) ON TABLE public.stock_discrepancies TO authenticated;
