-- Complete missing FK indexes for the Buyer cash-custody and purchasing workflow.
CREATE INDEX IF NOT EXISTS buyer_custodies_branch_id_fk_idx ON public.buyer_custodies (branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custodies_employee_id_fk_idx ON public.buyer_custodies (employee_id);
CREATE INDEX IF NOT EXISTS buyer_custodies_issued_by_fk_idx ON public.buyer_custodies (issued_by);

CREATE INDEX IF NOT EXISTS buyer_custody_advances_acknowledged_by_fk_idx ON public.buyer_custody_advances (acknowledged_by) WHERE acknowledged_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_advances_cash_box_id_fk_idx ON public.buyer_custody_advances (cash_box_id) WHERE cash_box_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_advances_custody_id_fk_idx ON public.buyer_custody_advances (custody_id);
CREATE INDEX IF NOT EXISTS buyer_custody_advances_employee_id_fk_idx ON public.buyer_custody_advances (employee_id);
CREATE INDEX IF NOT EXISTS buyer_custody_advances_issued_by_fk_idx ON public.buyer_custody_advances (issued_by);
CREATE INDEX IF NOT EXISTS buyer_custody_advances_journal_entry_id_fk_idx ON public.buyer_custody_advances (journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_advances_treasury_id_fk_idx ON public.buyer_custody_advances (treasury_id) WHERE treasury_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS buyer_custody_expenses_custody_id_fk_idx ON public.buyer_custody_expenses (custody_id);
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_employee_id_fk_idx ON public.buyer_custody_expenses (employee_id);
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_journal_entry_id_fk_idx ON public.buyer_custody_expenses (journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_payment_id_fk_idx ON public.buyer_custody_expenses (payment_id) WHERE payment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_purchase_invoice_id_fk_idx ON public.buyer_custody_expenses (purchase_invoice_id) WHERE purchase_invoice_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_reviewed_by_fk_idx ON public.buyer_custody_expenses (reviewed_by) WHERE reviewed_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_expenses_supplier_id_fk_idx ON public.buyer_custody_expenses (supplier_id) WHERE supplier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS buyer_custody_payments_custody_id_fk_idx ON public.buyer_custody_payments (custody_id);
CREATE INDEX IF NOT EXISTS buyer_custody_payments_journal_entry_id_fk_idx ON public.buyer_custody_payments (journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_payments_purchase_invoice_id_fk_idx ON public.buyer_custody_payments (purchase_invoice_id);
CREATE INDEX IF NOT EXISTS buyer_custody_payments_recorded_by_fk_idx ON public.buyer_custody_payments (recorded_by);
CREATE INDEX IF NOT EXISTS buyer_custody_payments_supplier_id_fk_idx ON public.buyer_custody_payments (supplier_id);

CREATE INDEX IF NOT EXISTS buyer_custody_settlements_cash_box_id_fk_idx ON public.buyer_custody_settlements (cash_box_id) WHERE cash_box_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_settlements_journal_entry_id_fk_idx ON public.buyer_custody_settlements (journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS buyer_custody_settlements_recorded_by_fk_idx ON public.buyer_custody_settlements (recorded_by);
CREATE INDEX IF NOT EXISTS buyer_custody_settlements_treasury_id_fk_idx ON public.buyer_custody_settlements (treasury_id) WHERE treasury_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS purchase_invoice_details_item_id_fk_idx ON public.purchase_invoice_details (item_id);
CREATE INDEX IF NOT EXISTS purchase_invoices_branch_id_fk_idx ON public.purchase_invoices (branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_invoices_cash_custody_id_fk_idx ON public.purchase_invoices (cash_custody_id) WHERE cash_custody_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_invoices_purchase_order_id_fk_idx ON public.purchase_invoices (purchase_order_id) WHERE purchase_order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_invoices_purchaser_user_id_fk_idx ON public.purchase_invoices (purchaser_user_id) WHERE purchaser_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_invoices_quotation_id_fk_idx ON public.purchase_invoices (quotation_id) WHERE quotation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_invoices_supplier_id_fk_idx ON public.purchase_invoices (supplier_id);

CREATE INDEX IF NOT EXISTS purchase_order_details_item_id_fk_idx ON public.purchase_order_details (item_id);
CREATE INDEX IF NOT EXISTS purchase_orders_branch_id_fk_idx ON public.purchase_orders (branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_orders_supplier_id_fk_idx ON public.purchase_orders (supplier_id) WHERE supplier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS purchase_payment_allocations_company_id_fk_idx ON public.purchase_payment_allocations (company_id);
CREATE INDEX IF NOT EXISTS purchase_payments_cash_box_id_fk_idx ON public.purchase_payments (cash_box_id) WHERE cash_box_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_payments_supplier_id_fk_idx ON public.purchase_payments (supplier_id);
CREATE INDEX IF NOT EXISTS purchase_payments_treasury_id_fk_idx ON public.purchase_payments (treasury_id);

CREATE INDEX IF NOT EXISTS purchase_quotation_details_item_id_fk_idx ON public.purchase_quotation_details (item_id);
CREATE INDEX IF NOT EXISTS purchase_quotations_rfq_id_fk_idx ON public.purchase_quotations (rfq_id) WHERE rfq_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_quotations_supplier_id_fk_idx ON public.purchase_quotations (supplier_id);
CREATE INDEX IF NOT EXISTS purchase_request_details_item_id_fk_idx ON public.purchase_request_details (item_id);
CREATE INDEX IF NOT EXISTS purchase_rfq_details_item_id_fk_idx ON public.purchase_rfq_details (item_id);
CREATE INDEX IF NOT EXISTS purchase_rfq_suppliers_supplier_id_fk_idx ON public.purchase_rfq_suppliers (supplier_id);
CREATE INDEX IF NOT EXISTS purchase_rfqs_request_id_fk_idx ON public.purchase_rfqs (request_id) WHERE request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS purchase_settings_default_branch_id_fk_idx ON public.purchase_settings (default_branch_id) WHERE default_branch_id IS NOT NULL;