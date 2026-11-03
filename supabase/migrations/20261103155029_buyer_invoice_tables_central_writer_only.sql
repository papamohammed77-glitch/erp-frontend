-- Buyer invoice tables: authenticated users retain tenant-scoped reads only.
-- All writes remain in the authorized central purchase/finance RPC paths.
BEGIN;
REVOKE ALL PRIVILEGES ON TABLE public.purchase_invoices, public.purchase_invoice_details, public.purchase_attachments FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.purchase_invoices, public.purchase_invoice_details, public.purchase_attachments FROM authenticated;
GRANT SELECT ON TABLE public.purchase_invoices, public.purchase_invoice_details, public.purchase_attachments TO authenticated;
DROP POLICY IF EXISTS purchase_invoices_company ON public.purchase_invoices;
CREATE POLICY purchase_invoices_select_company ON public.purchase_invoices FOR SELECT TO authenticated
USING (company_id = app_private.current_user_company_id());
DROP POLICY IF EXISTS purchase_invoice_details_company ON public.purchase_invoice_details;
CREATE POLICY purchase_invoice_details_select_company ON public.purchase_invoice_details FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.purchase_invoices i WHERE i.id=purchase_invoice_details.invoice_id AND i.company_id=app_private.current_user_company_id()));
DROP POLICY IF EXISTS purchase_attachments_company ON public.purchase_attachments;
CREATE POLICY purchase_attachments_select_company ON public.purchase_attachments FOR SELECT TO authenticated
USING (company_id = app_private.current_user_company_id());
COMMIT;
