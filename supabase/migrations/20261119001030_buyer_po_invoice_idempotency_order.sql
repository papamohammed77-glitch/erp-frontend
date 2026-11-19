-- Fix Buyer PO invoice idempotent retries: duplicate operation replay precedes supplier invoice uniqueness.
CREATE OR REPLACE FUNCTION public.purchase_create_po_invoice_atomic(p_company_id uuid, p_supplier_id uuid, p_purchase_order_id uuid, p_branch_id uuid, p_due_date date, p_supplier_invoice_no text, p_notes text, p_items jsonb, p_operation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_detail public.purchase_order_details%ROWTYPE;
  v_item public.items%ROWTYPE;
  v_line jsonb;
  v_qty numeric;
  v_unit_price numeric;
  v_discount numeric;
  v_tax numeric;
  v_unit text;
  v_unit_factor numeric;
  v_po_unit_factor numeric;
  v_ordered_base numeric;
  v_previously_invoiced numeric;

  v_po public.purchase_orders%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_currency text;
  v_fingerprint text;
  v_result jsonb;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth.uid()=users.auth_id
    AND company_id=p_company_id
    AND COALESCE(status,'Active')='Active';

  IF NOT FOUND OR NOT (
    app_private.current_user_has_effective_permission('purchases')
  ) THEN
    RAISE EXCEPTION 'BUYER_PURCHASE_PERMISSION_REQUIRED';
  END IF;

  IF p_purchase_order_id IS NULL OR NULLIF(btrim(p_operation_id),'') IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_ORDER_AND_OPERATION_REQUIRED';
  END IF;

  IF COALESCE(jsonb_typeof(p_items),'')<>'array' THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_ITEMS_MUST_BE_ARRAY';
  END IF;
  IF jsonb_array_length(p_items)<1 OR jsonb_array_length(p_items)>500 THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_COUNT_INVALID';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.items i
      WHERE i.company_id=p_company_id
        AND i.item_code=btrim(x.item_code)
        AND COALESCE(i.is_active,true)=true
    )
  ) THEN
    RAISE EXCEPTION 'PURCHASE_INVOICE_ITEM_INVALID_OR_INACTIVE';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('RAWAEA:PO-INVOICE:'||p_company_id::text||':'||btrim(p_operation_id),0)
  );

  SELECT upper(nullif(btrim(currency),'')) INTO v_currency
  FROM public.app_settings
  WHERE company_id=p_company_id
  ORDER BY created_at,id
  LIMIT 1;

  IF v_currency IS NULL OR v_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'SYSTEM_CURRENCY_NOT_CONFIGURED';
  END IF;

  SELECT * INTO v_po
  FROM public.purchase_orders
  WHERE id=p_purchase_order_id
    AND company_id=p_company_id
    AND supplier_id=p_supplier_id
    AND status<>'Cancelled'
  FOR UPDATE;

  IF NOT FOUND OR upper(COALESCE(v_po.currency,''))<>v_currency THEN
    RAISE EXCEPTION 'PURCHASE_PO_SUPPLIER_OR_CURRENCY_INVALID';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.suppliers
    WHERE id=p_supplier_id AND company_id=p_company_id AND COALESCE(is_active,false)=true
  ) THEN
    RAISE EXCEPTION 'PURCHASE_SUPPLIER_INVALID';
  END IF;


  IF p_branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches
    WHERE id=p_branch_id AND company_id=p_company_id AND COALESCE(is_active,true)=true
  ) THEN
    RAISE EXCEPTION 'PURCHASE_BRANCH_INVALID';
  END IF;

  v_fingerprint:=md5(jsonb_build_object(
    'supplier_id',p_supplier_id,'purchase_order_id',p_purchase_order_id,
    'branch_id',p_branch_id,'due_date',p_due_date,
    'supplier_invoice_no',NULLIF(btrim(p_supplier_invoice_no),''),
    'notes',NULLIF(btrim(p_notes),''),'currency',v_currency,'items',p_items
  )::text);

  SELECT * INTO v_invoice
  FROM public.purchase_invoices
  WHERE company_id=p_company_id AND operation_id=p_operation_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_invoice.purchase_source<>'PURCHASE_ORDER'
       OR v_invoice.source_payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'PURCHASE_OPERATION_ID_PAYLOAD_CONFLICT';
    END IF;

    RETURN jsonb_build_object(
      'success',true,'duplicate',true,'id',v_invoice.id,'code',v_invoice.invoice_code,
      'status',v_invoice.status,'currency',v_invoice.currency,'purchase_source','PURCHASE_ORDER'
    );
  END IF;


  -- A retry of the same operation must return its original result before
  -- testing supplier-invoice uniqueness against its own existing invoice.
  PERFORM app_private.assert_unique_purchase_supplier_invoice(
    p_company_id,p_supplier_id,p_supplier_invoice_no,NULL
  );

  -- New Buyer drafts require an approved PO with no warehouse receipt.
  -- The operation-id duplicate replay above intentionally precedes this guard.
  IF v_po.status <> 'Approved' THEN
    RAISE EXCEPTION 'BUYER_PO_INVOICE_REQUIRES_APPROVED_PO';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.purchase_order_details d WHERE d.po_id=v_po.id
  ) OR EXISTS (
    SELECT 1 FROM public.purchase_order_details d
    WHERE d.po_id=v_po.id AND COALESCE(d.qty_received,0)>0.00005
  ) THEN
    RAISE EXCEPTION 'BUYER_PO_INVOICE_REQUIRES_PO_WITHOUT_RECEIPT';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text)
    GROUP BY btrim(item_code) HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'BUYER_PO_INVOICE_DUPLICATE_ITEM';
  END IF;

  FOR v_line IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_item
    FROM public.items i
    WHERE i.company_id=p_company_id AND i.item_code=btrim(v_line->>'item_code')
      AND COALESCE(i.is_active,true)=true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'BUYER_PO_INVOICE_ITEM_INVALID:%',v_line->>'item_code';
    END IF;

    SELECT * INTO v_detail
    FROM public.purchase_order_details d
    WHERE d.po_id=v_po.id AND d.item_id=v_item.id
      AND d.item_code=v_item.item_code
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'BUYER_PO_INVOICE_ITEM_NOT_IN_PO:%',v_line->>'item_code';
    END IF;

    v_unit:=COALESCE(NULLIF(btrim(v_line->>'unit'),''),v_item.unit);
    v_unit_factor:=CASE
      WHEN v_unit=NULLIF(btrim(v_item.alt_unit),'') THEN COALESCE(v_item.alt_unit_qty,0)
      WHEN v_unit=v_item.unit THEN 1
      ELSE 0
    END;
    v_po_unit_factor:=CASE
      WHEN btrim(v_detail.unit)=NULLIF(btrim(v_item.alt_unit),'') THEN COALESCE(v_item.alt_unit_qty,0)
      WHEN btrim(v_detail.unit)=v_item.unit THEN 1
      ELSE 0
    END;

    v_qty:=NULLIF(btrim(v_line->>'qty'),'')::numeric;
    v_unit_price:=NULLIF(btrim(v_line->>'unit_price'),'')::numeric;
    v_discount:=COALESCE(NULLIF(btrim(v_line->>'discount_percent'),'')::numeric,0);
    v_tax:=COALESCE(NULLIF(btrim(v_line->>'tax_rate'),'')::numeric,0);

    IF v_unit_factor<=0 OR v_po_unit_factor<=0
       OR v_qty IS NULL OR v_qty<=0 OR v_qty::text IN ('NaN','Infinity','-Infinity')
       OR v_unit_price IS NULL OR v_unit_price<0 OR v_unit_price::text IN ('NaN','Infinity','-Infinity')
       OR v_discount<>0 OR v_tax<>0 THEN
      RAISE EXCEPTION 'BUYER_PO_INVOICE_LINE_VALUES_INVALID:%',v_line->>'item_code';
    END IF;

    v_ordered_base:=COALESCE(v_detail.qty_ordered,0)*v_po_unit_factor;
    SELECT COALESCE(SUM(od.qty*COALESCE(od.unit_conversion_factor,1)),0)
      INTO v_previously_invoiced
    FROM public.purchase_invoice_details od
    JOIN public.purchase_invoices oi ON oi.id=od.invoice_id
    WHERE oi.company_id=p_company_id
      AND oi.purchase_order_id=v_po.id
      AND oi.status<>'Cancelled'
      AND od.item_code=v_detail.item_code;

    IF v_qty*v_unit_factor+v_previously_invoiced>v_ordered_base+0.00005 THEN
      RAISE EXCEPTION 'BUYER_PO_INVOICE_QTY_EXCEEDS_UNINVOICED_ORDERED:%',v_line->>'item_code';
    END IF;

    IF abs(
      v_unit_price/v_unit_factor
      -COALESCE(v_detail.unit_price,0)/v_po_unit_factor
    )>0.01 THEN
      RAISE EXCEPTION 'BUYER_PO_INVOICE_PRICE_MISMATCH:%',v_line->>'item_code';
    END IF;
  END LOOP;

  v_result:=public.purchase_create_invoice_atomic_v2(
    p_company_id,p_supplier_id,p_purchase_order_id,p_branch_id,p_due_date,v_currency,
    v_actor.email,p_supplier_invoice_no,p_notes,p_items,p_operation_id
  );

  IF COALESCE((v_result->>'success')::boolean,false)=false
     OR NULLIF(v_result->>'id','') IS NULL THEN
    RAISE EXCEPTION 'PURCHASE_ORDER_INVOICE_CREATE_FAILED';
  END IF;

  UPDATE public.purchase_invoices
  SET purchase_source='PURCHASE_ORDER',
      settlement_source='SUPPLIER_CREDIT',
      purchaser_user_id=v_actor.id,
      cash_custody_id=NULL,
      receipt_status='NOT_RECEIVED',
      settlement_status='UNSETTLED',
      source_payload_fingerprint=v_fingerprint,
      updated_at=now()
  WHERE id=(v_result->>'id')::uuid
    AND company_id=p_company_id
    AND status='Draft';

  IF NOT FOUND THEN RAISE EXCEPTION 'PURCHASE_ORDER_INVOICE_CLASSIFICATION_FAILED'; END IF;

  RETURN v_result||jsonb_build_object(
    'purchase_source','PURCHASE_ORDER',
    'settlement_source','SUPPLIER_CREDIT',
    'purchaser_user_id',v_actor.id
  );
END;
$function$
;
