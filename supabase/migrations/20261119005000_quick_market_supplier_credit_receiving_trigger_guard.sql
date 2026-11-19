-- Extend the receiving-invoice trigger guard to admit Supplier Credit QMP,
-- retaining invoice ownership, source, status, branch and invoice-code validation.
CREATE OR REPLACE FUNCTION app_private.guard_po_receiving_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_po_status text;
  v_invoice public.purchase_invoices%ROWTYPE;
BEGIN
  IF NEW.company_id IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_RECEIVING_COMPANY_REQUIRED';
  END IF;

  IF NEW.purchase_invoice_id IS NOT NULL THEN
    SELECT * INTO v_invoice
    FROM public.purchase_invoices i
    WHERE i.id=NEW.purchase_invoice_id AND i.company_id=NEW.company_id
    FOR UPDATE;
    IF NOT FOUND
       OR v_invoice.purchase_source<>'QUICK_MARKET'
       OR v_invoice.settlement_source NOT IN ('EMPLOYEE_CUSTODY','SUPPLIER_CREDIT')
       OR v_invoice.status NOT IN ('Draft','PartiallyPaid')
       OR COALESCE(v_invoice.is_received,false)
       OR v_invoice.received_date IS NOT NULL
       OR v_invoice.branch_id IS NULL
       OR BTRIM(COALESCE(NEW.po_number,''))<>BTRIM(COALESCE(v_invoice.invoice_code,'')) THEN
      RAISE EXCEPTION 'QUICK_MARKET_RECEIVING_INVOICE_NOT_ELIGIBLE';
    END IF;
    RETURN NEW;
  END IF;

  IF NULLIF(BTRIM(NEW.po_number),'') IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT po.status INTO v_po_status
  FROM public.purchase_orders po
  WHERE po.company_id=NEW.company_id
    AND po.po_code=BTRIM(NEW.po_number)
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_PO_NOT_FOUND_FOR_RECEIVING'; END IF;
  IF COALESCE(v_po_status,'') NOT IN ('Approved','Sent','Partially Received') THEN
    RAISE EXCEPTION 'PURCHASE_PO_NOT_APPROVED_FOR_RECEIVING';
  END IF;
  RETURN NEW;
END;
$function$
;
