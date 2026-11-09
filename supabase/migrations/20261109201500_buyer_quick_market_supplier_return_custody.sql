-- Buyer Quick Market custody is invoice-backed by explicit owner clarification.
-- Each live Quick Market invoice line is buyer-held goods from the moment it is saved.
-- This is a custody projection only; it does not post inventory, AP, cash, treasury or GL.
BEGIN;
CREATE OR REPLACE FUNCTION public.buyer_goods_custody_get_balances_atomic(p_company_id uuid, p_custodian_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_target uuid;
  v_can_view_all boolean;
  v_balances jsonb;
  v_events jsonb;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth.uid()=users.auth_id AND company_id=p_company_id
    AND COALESCE(status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'BUYER_GOODS_AUTH_REQUIRED'; END IF;

  IF NOT (
    app_private.current_user_has_effective_permission('purchases')
    OR app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN RAISE EXCEPTION 'BUYER_GOODS_PERMISSION_REQUIRED'; END IF;

  v_can_view_all:=
    app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager');

  IF p_custodian_user_id IS NULL THEN
    v_target:=CASE WHEN v_can_view_all THEN NULL ELSE v_actor.id END;
  ELSE
    IF p_custodian_user_id<>v_actor.id AND NOT v_can_view_all THEN
      RAISE EXCEPTION 'BUYER_GOODS_SCOPE_FORBIDDEN';
    END IF;
    v_target:=p_custodian_user_id;
  END IF;

  WITH actual_events AS (
    SELECT
      e.id,e.company_id,e.branch_id,e.custodian_user_id,e.item_id,e.vehicle_id,
      e.event_type,e.qty_delta,e.source_document_type,e.source_document_id,e.source_line_id,
      e.related_document_type,e.related_document_id,e.operation_id,e.payload_fingerprint,
      e.evidence_path,e.actor_user_id,e.reverses_event_id,e.correction_reason,e.notes,e.created_at,
      COALESCE(parent.event_type,e.event_type) AS root_event_type,
      COALESCE(parent.source_document_type,e.source_document_type) AS root_source_document_type,
      COALESCE(parent.source_document_id,e.source_document_id) AS root_source_document_id,
      COALESCE(parent.source_line_id,e.source_line_id) AS root_source_line_id,
      COALESCE(e.evidence_path,parent.evidence_path) AS root_evidence_path
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND (v_target IS NULL OR e.custodian_user_id=v_target)
  ),
  invoice_custody_base AS (
    SELECT
      md5('RAWAEA:QMP-INVOICE-CUSTODY:'||pi.id::text||':'||d.id::text)::uuid AS id,
      pi.company_id,pi.branch_id,pi.purchaser_user_id AS custodian_user_id,
      d.item_id,NULL::uuid AS vehicle_id,
      'SUPPLIER_TO_BUYER_QUICK_MARKET'::text AS event_type,
      GREATEST(COALESCE(d.qty,0)-COALESCE(h.handed_over_qty,0),0)::numeric AS qty_delta,
      'PurchaseInvoice'::text AS source_document_type,
      pi.id AS source_document_id,d.id AS source_line_id,
      'Supplier'::text AS related_document_type,pi.supplier_id AS related_document_id,
      'QMP-INVOICE-CUSTODY:'||pi.id::text||':'||d.id::text AS operation_id,
      md5(pi.id::text||':'||d.id::text||':'||d.qty::text) AS payload_fingerprint,
      NULL::text AS evidence_path,pi.purchaser_user_id AS actor_user_id,
      NULL::uuid AS reverses_event_id,NULL::text AS correction_reason,
      'حيازة شراء مباشر سريع مستمدة من فاتورة الشراء؛ لا تنشئ حركة مخزون أو قيدًا ماليًا'::text AS notes,
      pi.created_at,
      'SUPPLIER_TO_BUYER_QUICK_MARKET'::text AS root_event_type,
      'PurchaseInvoice'::text AS root_source_document_type,
      pi.id AS root_source_document_id,d.id AS root_source_line_id,
      NULL::text AS root_evidence_path
    FROM public.purchase_invoices pi
    JOIN public.purchase_invoice_details d ON d.invoice_id=pi.id
    JOIN public.suppliers s ON s.id=pi.supplier_id AND s.company_id=p_company_id
    JOIN public.branches br ON br.id=pi.branch_id AND br.company_id=p_company_id
    JOIN public.items it ON it.id=d.item_id AND it.company_id=p_company_id
    LEFT JOIN LATERAL (
      SELECT COALESCE(SUM(e.qty_delta),0) AS handed_over_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=pi.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type)='SUPPLIER_TO_BUYER_QUICK_MARKET'
        AND e.custodian_user_id=pi.purchaser_user_id
        AND e.branch_id=pi.branch_id
    ) h ON true
    WHERE pi.company_id=p_company_id
      AND pi.purchase_source='QUICK_MARKET'
      AND pi.status IN ('Draft','Posted','PartiallyPaid','Paid')
      AND pi.purchaser_user_id IS NOT NULL
      AND pi.branch_id IS NOT NULL
      AND (v_target IS NULL OR pi.purchaser_user_id=v_target)
      AND GREATEST(COALESCE(d.qty,0)-COALESCE(h.handed_over_qty,0),0)>0
  ),
  invoice_receipt_projection AS (
    SELECT
      md5('RAWAEA:QMP-RECEIPT-PROJECTION:'||pi.id::text||':'||d.id::text)::uuid AS id,
      pi.company_id,pi.branch_id,pi.purchaser_user_id AS custodian_user_id,
      d.item_id,NULL::uuid AS vehicle_id,
      'BUYER_TO_WAREHOUSE_ACCEPTED'::text AS event_type,
      -GREATEST(
        GREATEST(COALESCE(d.received_qty,0),CASE WHEN COALESCE(pi.is_received,false) THEN d.qty ELSE 0 END)
        -COALESCE(w.warehouse_accepted_qty,0),0
      )::numeric AS qty_delta,
      'PurchaseInvoice'::text AS source_document_type,
      pi.id AS source_document_id,d.id AS source_line_id,
      'Receiving'::text AS related_document_type,NULL::uuid AS related_document_id,
      'QMP-RECEIPT-PROJECTION:'||pi.id::text||':'||d.id::text AS operation_id,
      md5(pi.id::text||':'||d.id::text||':'||COALESCE(d.received_qty,0)::text||':'||COALESCE(pi.is_received,false)::text) AS payload_fingerprint,
      NULL::text AS evidence_path,pi.purchaser_user_id AS actor_user_id,
      NULL::uuid AS reverses_event_id,NULL::text AS correction_reason,
      'استلام مخزني مستنتج من الكمية المقبولة المسجلة على سطر فاتورة السوق السريع'::text AS notes,
      COALESCE(pi.updated_at,pi.created_at) AS created_at,
      'BUYER_TO_WAREHOUSE_ACCEPTED'::text AS root_event_type,
      'PurchaseInvoice'::text AS root_source_document_type,
      pi.id AS root_source_document_id,d.id AS root_source_line_id,
      NULL::text AS root_evidence_path
    FROM public.purchase_invoices pi
    JOIN public.purchase_invoice_details d ON d.invoice_id=pi.id
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_accepted_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=pi.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
        AND e.custodian_user_id=pi.purchaser_user_id
        AND e.branch_id=pi.branch_id
    ) w ON true
    WHERE pi.company_id=p_company_id
      AND pi.purchase_source='QUICK_MARKET'
      AND pi.status IN ('Draft','Posted','PartiallyPaid','Paid')
      AND pi.purchaser_user_id IS NOT NULL
      AND pi.branch_id IS NOT NULL
      AND (v_target IS NULL OR pi.purchaser_user_id=v_target)
      AND GREATEST(
        GREATEST(COALESCE(d.received_qty,0),CASE WHEN COALESCE(pi.is_received,false) THEN d.qty ELSE 0 END)
        -COALESCE(w.warehouse_accepted_qty,0),0
      )>0
  ),
  base_events AS (
    SELECT * FROM actual_events
    UNION ALL
    SELECT * FROM invoice_custody_base
    UNION ALL
    SELECT * FROM invoice_receipt_projection
  ),
  enriched AS (
    SELECT b.*,
      CASE
        WHEN b.root_source_document_type='PurchaseInvoice'
          AND b.root_event_type IN ('SUPPLIER_TO_BUYER_QUICK_MARKET','BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN','BUYER_TO_SUPPLIER_ACCEPTED')
          THEN 'SUPPLIER_OWNED'
        WHEN b.root_source_document_type='StockVoucher'
          AND b.root_event_type IN ('WAREHOUSE_TO_BUYER_SUPPLIER_RETURN','BUYER_TO_SUPPLIER_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
          THEN 'COMPANY_OWNED_SUPPLIER_RETURN'
        ELSE 'UNCLASSIFIED'
      END AS ownership_class,
      COALESCE(pi.supplier_id,sv.to_id) AS supplier_id,
      s.name AS supplier_name,
      COALESCE(pi.invoice_code,sv.voucher_code) AS source_document_code,
      pi.supplier_invoice_no
    FROM base_events b
    LEFT JOIN public.purchase_invoices pi
      ON b.root_source_document_type='PurchaseInvoice'
     AND pi.id=b.root_source_document_id AND pi.company_id=p_company_id
    LEFT JOIN public.stock_vouchers sv
      ON b.root_source_document_type='StockVoucher'
     AND sv.id=b.root_source_document_id AND sv.company_id=p_company_id
     AND sv.type='SupplierReturn'
    LEFT JOIN public.suppliers s
      ON s.id=COALESCE(pi.supplier_id,sv.to_id) AND s.company_id=p_company_id
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'custodian_user_id',b.custodian_user_id,
    'branch_id',b.branch_id,'branch_name',br.name,
    'item_id',b.item_id,'item_code',it.item_code,'item_name',it.name,'unit',it.unit,
    'ownership_class',b.ownership_class,
    'supplier_id',b.supplier_id,'supplier_name',b.supplier_name,
    'source_document_type',b.root_source_document_type,
    'source_document_id',b.root_source_document_id,
    'source_document_code',b.source_document_code,
    'supplier_invoice_no',b.supplier_invoice_no,
    'balance_qty',b.balance_qty,'vehicle_ids',b.vehicle_ids,
    'last_movement_at',b.last_movement_at,'evidence_path',b.evidence_path
  ) ORDER BY br.name,it.name,b.ownership_class,b.source_document_code),'[]'::jsonb)
  INTO v_balances
  FROM (
    SELECT e.custodian_user_id,e.branch_id,e.item_id,e.ownership_class,
      e.supplier_id,e.supplier_name,e.root_source_document_type,e.root_source_document_id,
      e.source_document_code,e.supplier_invoice_no,
      SUM(e.qty_delta) AS balance_qty,
      ARRAY_REMOVE(ARRAY_AGG(DISTINCT e.vehicle_id),NULL) AS vehicle_ids,
      MAX(e.created_at) AS last_movement_at,
      (ARRAY_AGG(e.root_evidence_path ORDER BY e.created_at DESC)
        FILTER (WHERE e.root_evidence_path IS NOT NULL))[1] AS evidence_path
    FROM enriched e
    GROUP BY e.custodian_user_id,e.branch_id,e.item_id,e.ownership_class,
      e.supplier_id,e.supplier_name,e.root_source_document_type,e.root_source_document_id,
      e.source_document_code,e.supplier_invoice_no
    HAVING ABS(SUM(e.qty_delta))>0.0001
  ) b
  JOIN public.branches br ON br.id=b.branch_id AND br.company_id=p_company_id
  JOIN public.items it ON it.id=b.item_id AND it.company_id=p_company_id;

  WITH actual_events AS (
    SELECT
      e.*,
      COALESCE(parent.event_type,e.event_type) AS root_event_type,
      COALESCE(parent.source_document_type,e.source_document_type) AS root_source_document_type,
      COALESCE(parent.source_document_id,e.source_document_id) AS root_source_document_id,
      COALESCE(parent.source_line_id,e.source_line_id) AS root_source_line_id,
      COALESCE(e.evidence_path,parent.evidence_path) AS root_evidence_path
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND (v_target IS NULL OR e.custodian_user_id=v_target)
  ),
  invoice_custody_base AS (
    SELECT
      md5('RAWAEA:QMP-INVOICE-CUSTODY:'||pi.id::text||':'||d.id::text)::uuid AS id,
      pi.company_id,pi.branch_id,pi.purchaser_user_id AS custodian_user_id,
      d.item_id,NULL::uuid AS vehicle_id,'SUPPLIER_TO_BUYER_QUICK_MARKET'::text AS event_type,
      GREATEST(COALESCE(d.qty,0)-COALESCE(h.handed_over_qty,0),0)::numeric AS qty_delta,
      'PurchaseInvoice'::text AS source_document_type,pi.id AS source_document_id,d.id AS source_line_id,
      'Supplier'::text AS related_document_type,pi.supplier_id AS related_document_id,
      'QMP-INVOICE-CUSTODY:'||pi.id::text||':'||d.id::text AS operation_id,
      md5(pi.id::text||':'||d.id::text||':'||d.qty::text) AS payload_fingerprint,
      NULL::text AS evidence_path,pi.purchaser_user_id AS actor_user_id,
      NULL::uuid AS reverses_event_id,NULL::text AS correction_reason,
      'حيازة شراء مباشر سريع مستمدة من فاتورة الشراء'::text AS notes,pi.created_at,
      'SUPPLIER_TO_BUYER_QUICK_MARKET'::text AS root_event_type,
      'PurchaseInvoice'::text AS root_source_document_type,pi.id AS root_source_document_id,
      d.id AS root_source_line_id,NULL::text AS root_evidence_path
    FROM public.purchase_invoices pi
    JOIN public.purchase_invoice_details d ON d.invoice_id=pi.id
    LEFT JOIN LATERAL (
      SELECT COALESCE(SUM(e.qty_delta),0) AS handed_over_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=pi.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type)='SUPPLIER_TO_BUYER_QUICK_MARKET'
        AND e.custodian_user_id=pi.purchaser_user_id AND e.branch_id=pi.branch_id
    ) h ON true
    WHERE pi.company_id=p_company_id AND pi.purchase_source='QUICK_MARKET'
      AND pi.status IN ('Draft','Posted','PartiallyPaid','Paid')
      AND pi.purchaser_user_id IS NOT NULL
      AND (v_target IS NULL OR pi.purchaser_user_id=v_target)
      AND GREATEST(COALESCE(d.qty,0)-COALESCE(h.handed_over_qty,0),0)>0
  ),
  invoice_receipt_projection AS (
    SELECT
      md5('RAWAEA:QMP-RECEIPT-PROJECTION:'||pi.id::text||':'||d.id::text)::uuid AS id,
      pi.company_id,pi.branch_id,pi.purchaser_user_id AS custodian_user_id,
      d.item_id,NULL::uuid AS vehicle_id,'BUYER_TO_WAREHOUSE_ACCEPTED'::text AS event_type,
      -GREATEST(GREATEST(COALESCE(d.received_qty,0),CASE WHEN COALESCE(pi.is_received,false) THEN d.qty ELSE 0 END)
        -COALESCE(w.warehouse_accepted_qty,0),0)::numeric AS qty_delta,
      'PurchaseInvoice'::text AS source_document_type,pi.id AS source_document_id,d.id AS source_line_id,
      'Receiving'::text AS related_document_type,NULL::uuid AS related_document_id,
      'QMP-RECEIPT-PROJECTION:'||pi.id::text||':'||d.id::text AS operation_id,
      md5(pi.id::text||':'||d.id::text||':'||COALESCE(d.received_qty,0)::text) AS payload_fingerprint,
      NULL::text AS evidence_path,pi.purchaser_user_id AS actor_user_id,
      NULL::uuid AS reverses_event_id,NULL::text AS correction_reason,
      'استلام مخزني مستنتج من الكمية المقبولة المسجلة على سطر فاتورة السوق السريع'::text AS notes,
      COALESCE(pi.updated_at,pi.created_at) AS created_at,
      'BUYER_TO_WAREHOUSE_ACCEPTED'::text AS root_event_type,
      'PurchaseInvoice'::text AS root_source_document_type,pi.id AS root_source_document_id,
      d.id AS root_source_line_id,NULL::text AS root_evidence_path
    FROM public.purchase_invoices pi
    JOIN public.purchase_invoice_details d ON d.invoice_id=pi.id
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_accepted_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=pi.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
        AND e.custodian_user_id=pi.purchaser_user_id AND e.branch_id=pi.branch_id
    ) w ON true
    WHERE pi.company_id=p_company_id AND pi.purchase_source='QUICK_MARKET'
      AND pi.status IN ('Draft','Posted','PartiallyPaid','Paid')
      AND pi.purchaser_user_id IS NOT NULL
      AND (v_target IS NULL OR pi.purchaser_user_id=v_target)
      AND GREATEST(GREATEST(COALESCE(d.received_qty,0),CASE WHEN COALESCE(pi.is_received,false) THEN d.qty ELSE 0 END)
        -COALESCE(w.warehouse_accepted_qty,0),0)>0
  ),
  enriched AS (
    SELECT b.*,
      CASE
        WHEN b.root_source_document_type='PurchaseInvoice'
          AND b.root_event_type IN ('SUPPLIER_TO_BUYER_QUICK_MARKET','BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN','BUYER_TO_SUPPLIER_ACCEPTED')
          THEN 'SUPPLIER_OWNED'
        WHEN b.root_source_document_type='StockVoucher'
          AND b.root_event_type IN ('WAREHOUSE_TO_BUYER_SUPPLIER_RETURN','BUYER_TO_SUPPLIER_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
          THEN 'COMPANY_OWNED_SUPPLIER_RETURN'
        ELSE 'UNCLASSIFIED'
      END AS ownership_class,
      COALESCE(pi.supplier_id,sv.to_id) AS supplier_id,
      s.name AS supplier_name,
      COALESCE(pi.invoice_code,sv.voucher_code) AS source_document_code,
      pi.supplier_invoice_no
    FROM (
      SELECT * FROM actual_events
      UNION ALL SELECT * FROM invoice_custody_base
      UNION ALL SELECT * FROM invoice_receipt_projection
    ) b
    LEFT JOIN public.purchase_invoices pi
      ON b.root_source_document_type='PurchaseInvoice'
     AND pi.id=b.root_source_document_id AND pi.company_id=p_company_id
    LEFT JOIN public.stock_vouchers sv
      ON b.root_source_document_type='StockVoucher'
     AND sv.id=b.root_source_document_id AND sv.company_id=p_company_id
     AND sv.type='SupplierReturn'
    LEFT JOIN public.suppliers s
      ON s.id=COALESCE(pi.supplier_id,sv.to_id) AND s.company_id=p_company_id
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',e.id,'custodian_user_id',e.custodian_user_id,
    'item_id',e.item_id,'item_code',it.item_code,'item_name',it.name,'unit',it.unit,
    'branch_id',e.branch_id,'branch_name',br.name,'vehicle_id',e.vehicle_id,
    'event_type',e.event_type,'root_event_type',e.root_event_type,
    'ownership_class',e.ownership_class,'qty_delta',e.qty_delta,
    'source_document_type',e.root_source_document_type,
    'source_document_id',e.root_source_document_id,'source_line_id',e.root_source_line_id,
    'source_document_code',e.source_document_code,
    'invoice_code',CASE WHEN e.root_source_document_type='PurchaseInvoice' THEN e.source_document_code ELSE NULL END,
    'voucher_code',CASE WHEN e.root_source_document_type='StockVoucher' THEN e.source_document_code ELSE NULL END,
    'supplier_id',e.supplier_id,'supplier_name',e.supplier_name,'supplier_invoice_no',e.supplier_invoice_no,
    'operation_id',e.operation_id,'evidence_path',e.root_evidence_path,
    'notes',e.notes,'created_at',e.created_at
  ) ORDER BY e.created_at DESC),'[]'::jsonb)
  INTO v_events
  FROM (SELECT * FROM enriched ORDER BY created_at DESC LIMIT 200) e
  JOIN public.items it ON it.id=e.item_id AND it.company_id=p_company_id
  JOIN public.branches br ON br.id=e.branch_id AND br.company_id=p_company_id;

  RETURN jsonb_build_object(
    'success',true,'custodian_user_id',v_target,'can_view_all',v_can_view_all,
    'balances',v_balances,'events',v_events
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.buyer_goods_custody_get_invoice_handover_progress_atomic(p_company_id uuid,p_invoice_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_lines jsonb;
  v_events jsonb;
  v_return_events jsonb;
  v_warehouse_events jsonb;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth.uid()=users.auth_id AND company_id=p_company_id
    AND COALESCE(status,'Active')='Active';
  IF NOT FOUND OR NOT (
    app_private.current_user_has_effective_permission('purchases')
    OR app_private.current_user_has_effective_permission('finance')
    OR app_private.current_user_has_effective_permission('finance_manager')
  ) THEN RAISE EXCEPTION 'BUYER_PURCHASE_PERMISSION_REQUIRED'; END IF;

  SELECT * INTO v_invoice
  FROM public.purchase_invoices
  WHERE id=p_invoice_id AND company_id=p_company_id AND purchase_source='QUICK_MARKET'
  FOR SHARE;
  IF NOT FOUND OR (
    v_invoice.purchaser_user_id IS DISTINCT FROM v_actor.id AND NOT (
      app_private.current_user_has_effective_permission('finance')
      OR app_private.current_user_has_effective_permission('finance_manager')
    )
  ) THEN RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_FOUND_OR_FORBIDDEN'; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'invoice_detail_id',d.id,'item_id',d.item_id,'item_code',d.item_code,
    'item_name',d.item_name,'unit',d.unit,'invoice_qty',d.qty,
    'handed_over_qty',d.qty,
    'warehouse_accepted_qty',GREATEST(
      COALESCE(d.received_qty,0),CASE WHEN COALESCE(v_invoice.is_received,false) THEN d.qty ELSE 0 END,
      COALESCE(w.warehouse_event_qty,0)
    ),
    'supplier_returned_qty',COALESCE(r.supplier_returned_qty,0),
    'current_custody_qty',GREATEST(
      d.qty-GREATEST(
        COALESCE(d.received_qty,0),CASE WHEN COALESCE(v_invoice.is_received,false) THEN d.qty ELSE 0 END,
        COALESCE(w.warehouse_event_qty,0)
      )-COALESCE(r.supplier_returned_qty,0),0
    ),
    'remaining_qty',0,
    'unit_price',d.unit_price,'line_total',d.line_total
  ) ORDER BY d.item_code,d.id),'[]'::jsonb)
  INTO v_lines
  FROM public.purchase_invoice_details d
  LEFT JOIN LATERAL (
    SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_event_qty
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
      AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
      AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
      AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
      AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id
  ) w ON true
  LEFT JOIN LATERAL (
    SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS supplier_returned_qty
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
      AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
      AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
      AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
      AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id
  ) r ON true
  WHERE d.invoice_id=p_invoice_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',e.id,'item_id',e.item_id,'source_line_id',e.source_line_id,
    'qty_delta',e.qty_delta,'vehicle_id',e.vehicle_id,'operation_id',e.operation_id,
    'evidence_path',e.evidence_path,'notes',e.notes,'created_at',e.created_at
  ) ORDER BY e.created_at DESC),'[]'::jsonb)
  INTO v_events
  FROM public.buyer_goods_custody_events e
  WHERE e.company_id=p_company_id AND e.source_document_type='PurchaseInvoice'
    AND e.source_document_id=p_invoice_id
    AND e.event_type='SUPPLIER_TO_BUYER_QUICK_MARKET'
    AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',e.id,'event_type',e.event_type,'root_event_type',COALESCE(parent.event_type,e.event_type),
    'item_id',e.item_id,'source_line_id',COALESCE(parent.source_line_id,e.source_line_id),
    'qty_delta',e.qty_delta,'operation_id',e.operation_id,
    'evidence_path',COALESCE(e.evidence_path,parent.evidence_path),
    'notes',e.notes,'created_at',e.created_at
  ) ORDER BY e.created_at DESC),'[]'::jsonb)
  INTO v_return_events
  FROM public.buyer_goods_custody_events e
  LEFT JOIN public.buyer_goods_custody_events parent
    ON e.event_type='BUYER_CUSTODY_CORRECTION'
   AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
  WHERE e.company_id=p_company_id
    AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
    AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
    AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
    AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',e.id,'event_type',e.event_type,'root_event_type',COALESCE(parent.event_type,e.event_type),
    'item_id',e.item_id,'source_line_id',COALESCE(parent.source_line_id,e.source_line_id),
    'qty_delta',e.qty_delta,'operation_id',e.operation_id,
    'evidence_path',COALESCE(e.evidence_path,parent.evidence_path),
    'notes',e.notes,'created_at',e.created_at
  ) ORDER BY e.created_at DESC),'[]'::jsonb)
  INTO v_warehouse_events
  FROM public.buyer_goods_custody_events e
  LEFT JOIN public.buyer_goods_custody_events parent
    ON e.event_type='BUYER_CUSTODY_CORRECTION'
   AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
  WHERE e.company_id=p_company_id
    AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
    AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
    AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
    AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id;

  RETURN jsonb_build_object(
    'success',true,'invoice_id',v_invoice.id,'invoice_code',v_invoice.invoice_code,
    'supplier_invoice_no',v_invoice.supplier_invoice_no,'purchaser_user_id',v_invoice.purchaser_user_id,
    'branch_id',v_invoice.branch_id,'currency',v_invoice.currency,'status',v_invoice.status,
    'lines',v_lines,'events',v_events,'return_events',v_return_events,'warehouse_events',v_warehouse_events
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.get_quick_market_receiving_queue_atomic(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_owner boolean:=false;
  v_rows jsonb:='[]'::jsonb;
  v_invoice record;
  v_items jsonb;
  v_branch_code text;
  v_allowed boolean;
  v_allowed_value text;
BEGIN
  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.auth_id=auth.uid() AND u.company_id=p_company_id
    AND COALESCE(u.status,'Active')='Active';
  IF NOT FOUND THEN RAISE EXCEPTION 'QMP_RECEIVER_AUTH_REQUIRED'; END IF;

  v_owner:=COALESCE((public.get_my_effective_profile()->>'isOwner')::boolean,false);
  IF NOT v_owner AND NOT (
    v_actor.active_warehouse_role='استلام'
    AND (public.hr_user_has_permission(v_actor.id,'warehouse')
      OR public.hr_user_has_permission(v_actor.id,'receiving'))
  ) THEN
    RAISE EXCEPTION 'QMP_RECEIVER_PERMISSION_REQUIRED';
  END IF;

  FOR v_invoice IN
    SELECT i.id,i.invoice_code,i.supplier_invoice_no,i.invoice_date,i.currency,
           i.branch_id,i.supplier_id,i.purchaser_user_id,s.name supplier_name,i.status,i.receipt_status
    FROM public.purchase_invoices i
    JOIN public.suppliers s ON s.id=i.supplier_id AND s.company_id=i.company_id
    JOIN public.branches b ON b.id=i.branch_id AND b.company_id=i.company_id AND COALESCE(b.is_active,true)
    WHERE i.company_id=p_company_id
      AND i.purchase_source='QUICK_MARKET'
      AND i.settlement_source='EMPLOYEE_CUSTODY'
      AND i.status IN ('Draft','PartiallyPaid')
      AND i.receipt_status IN ('NOT_RECEIVED','PARTIALLY_RECEIVED')
      AND COALESCE(i.is_received,false)=false
    ORDER BY i.invoice_date,i.created_at,i.id
  LOOP
    SELECT b.branch_code INTO v_branch_code
    FROM public.branches b
    WHERE b.id=v_invoice.branch_id AND b.company_id=p_company_id;

    v_allowed:=v_owner OR v_actor.default_branch_id=v_invoice.branch_id;
    IF NOT v_owner THEN
      IF jsonb_typeof(v_actor.allowed_branch_ids)='array' THEN
        v_allowed:=v_allowed
          OR v_actor.allowed_branch_ids ? '*'
          OR v_actor.allowed_branch_ids ? v_invoice.branch_id::text
          OR v_actor.allowed_branch_ids ? COALESCE(v_branch_code,'');
      ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string' THEN
        v_allowed_value:=v_actor.allowed_branch_ids #>> '{}';
        v_allowed:=v_allowed OR v_allowed_value IN ('*',v_invoice.branch_id::text,v_branch_code);
      END IF;
    END IF;
    IF NOT v_allowed THEN CONTINUE; END IF;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'purchase_invoice_detail_id',d.id,
      'item_id',d.item_id,
      'item_code',d.item_code,
      'item_name',COALESCE(d.item_name,it.name,d.item_code),
      'unit',COALESCE(d.unit,it.unit,'حبة'),
      'qty_ordered',d.qty,
      'qty_received',COALESCE(d.received_qty,0),
      'handover_available',GREATEST(
        d.qty
        -GREATEST(COALESCE(d.received_qty,0),COALESCE(w.warehouse_event_qty,0))
        -COALESCE(r.supplier_returned_qty,0),0
      ),
      'remaining_to_receive',LEAST(
        GREATEST(0,d.qty-COALESCE(d.received_qty,0)),
        GREATEST(
          d.qty
          -GREATEST(COALESCE(d.received_qty,0),COALESCE(w.warehouse_event_qty,0))
          -COALESCE(r.supplier_returned_qty,0),0
        )
      )
    ) ORDER BY d.item_code),'[]'::jsonb)
    FROM public.purchase_invoice_details d
    JOIN public.items it ON it.id=d.item_id AND it.company_id=p_company_id
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_event_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=v_invoice.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) w ON true
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS supplier_returned_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=v_invoice.id
        AND COALESCE(parent.source_line_id,e.source_line_id)=d.id
        AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) r ON true
    WHERE d.invoice_id=v_invoice.id
      AND GREATEST(
        d.qty
        -GREATEST(COALESCE(d.received_qty,0),COALESCE(w.warehouse_event_qty,0))
        -COALESCE(r.supplier_returned_qty,0),0
      )>0
    INTO v_items
    FROM public.purchase_invoice_details d
    JOIN public.items it ON it.id=d.item_id AND it.company_id=p_company_id
    WHERE d.invoice_id=v_invoice.id
      AND LEAST(
        GREATEST(0,d.qty-COALESCE(d.received_qty,0)),
        GREATEST(0,COALESCE((
          SELECT SUM(e.qty_delta)
          FROM public.buyer_goods_custody_events e
          WHERE e.company_id=p_company_id
            AND e.source_document_type='PurchaseInvoice'
            AND e.source_document_id=v_invoice.id
            AND e.source_line_id=d.id
            AND e.event_type IN ('SUPPLIER_TO_BUYER_QUICK_MARKET','BUYER_TO_WAREHOUSE_ACCEPTED')
        ),0))
      )>0;

    IF jsonb_array_length(COALESCE(v_items,'[]'::jsonb))>0 THEN
      v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
        'id',v_invoice.id,
        'doc_type','QUICK_MARKET',
        'po_code',v_invoice.invoice_code,
        'invoice_code',v_invoice.invoice_code,
        'supplier_invoice_no',v_invoice.supplier_invoice_no,
        'po_date',v_invoice.invoice_date,
        'supplier_name',v_invoice.supplier_name,
        'status',v_invoice.status,
        'receipt_status',v_invoice.receipt_status,
        'branch_id',v_invoice.branch_id,
        'currency',v_invoice.currency,
        'items',v_items
      ));
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success',true,'invoices',v_rows,'count',jsonb_array_length(v_rows));
END;
$function$


CREATE OR REPLACE FUNCTION public.receive_quick_market_purchase_atomic(p_company_id uuid, p_invoice_id uuid, p_user_email text, p_items jsonb, p_operation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_detail public.purchase_invoice_details%ROWTYPE;
  v_item public.items%ROWTYPE;
  v_input record;
  v_branch_code text;
  v_branch_allowed boolean:=false;
  v_owner boolean:=false;
  v_allowed_value text;
  v_operation text;
  v_fingerprint text;
  v_existing public.receiving%ROWTYPE;
  v_existing_fp text;
  v_balance numeric(14,4);
  v_total_value numeric(14,2):=0;
  v_total_qty numeric(14,4):=0;
  v_all_received boolean:=true;
  v_stock_result jsonb;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.companies c WHERE c.id=p_company_id AND COALESCE(c.is_active,true)) THEN
    RAISE EXCEPTION 'سياق الشركة غير موجود أو غير نشط';
  END IF;
  SELECT * INTO v_actor
  FROM public.users u
  WHERE u.company_id=p_company_id AND lower(u.email)=lower(COALESCE(p_user_email,''))
    AND COALESCE(u.status,'Active')='Active'
  FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'المستخدم لا ينتمي إلى الشركة أو غير نشط'; END IF;

  v_owner:=EXISTS(SELECT 1 FROM auth.users au
      JOIN public.owner_profile op ON op.auth_user_id=au.id
      WHERE au.id=v_actor.auth_id
        AND COALESCE(au.raw_user_meta_data->>'isOwner','false')='true'
        AND jsonb_typeof(v_actor.permissions)='array'
        AND v_actor.permissions ? '*');
  IF NOT v_owner AND NOT (
    v_actor.active_warehouse_role='استلام'
    AND (public.hr_user_has_permission(v_actor.id,'warehouse')
      OR public.hr_user_has_permission(v_actor.id,'receiving'))
  ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية استلام فواتير السوق السريع';
  END IF;
  IF p_operation_id IS NULL THEN RAISE EXCEPTION 'operation_id مطلوب لاستلام فاتورة السوق'; END IF;
  IF p_invoice_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items)<>'array'
     OR jsonb_array_length(p_items)=0 THEN
    RAISE EXCEPTION 'بيانات استلام فاتورة السوق غير مكتملة';
  END IF;

  SELECT * INTO v_invoice
  FROM public.purchase_invoices i
  WHERE i.id=p_invoice_id AND i.company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_invoice.purchase_source<>'QUICK_MARKET'
     OR v_invoice.settlement_source<>'EMPLOYEE_CUSTODY'
     OR v_invoice.cash_custody_id IS NULL
     OR v_invoice.status NOT IN ('Draft','PartiallyPaid')
     OR COALESCE(v_invoice.is_received,false)
     OR v_invoice.received_date IS NOT NULL
     OR v_invoice.branch_id IS NULL THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_RECEIVABLE';
  END IF;

  SELECT b.branch_code INTO v_branch_code
  FROM public.branches b
  WHERE b.id=v_invoice.branch_id AND b.company_id=p_company_id AND COALESCE(b.is_active,true);
  IF NOT FOUND THEN RAISE EXCEPTION 'فرع استلام فاتورة السوق غير صالح'; END IF;

  v_branch_allowed:=v_owner OR v_actor.default_branch_id=v_invoice.branch_id;
  IF NOT v_owner THEN
    IF jsonb_typeof(v_actor.allowed_branch_ids)='array' THEN
      v_branch_allowed:=v_branch_allowed
        OR v_actor.allowed_branch_ids ? '*'
        OR v_actor.allowed_branch_ids ? v_invoice.branch_id::text
        OR v_actor.allowed_branch_ids ? COALESCE(v_branch_code,'');
    ELSIF jsonb_typeof(v_actor.allowed_branch_ids)='string' THEN
      v_allowed_value:=v_actor.allowed_branch_ids #>> '{}';
      v_branch_allowed:=v_branch_allowed OR v_allowed_value IN ('*',v_invoice.branch_id::text,v_branch_code);
    END IF;
  END IF;
  IF NOT v_branch_allowed THEN RAISE EXCEPTION 'لا تملك صلاحية الاستلام في فرع فاتورة السوق'; END IF;

  IF EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric)
    GROUP BY btrim(item_code) HAVING count(*)>1
  ) THEN RAISE EXCEPTION 'لا يجوز تكرار الصنف داخل استلام الفاتورة'; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric)
    WHERE COALESCE(x.received_qty,0)>0
  ) THEN RAISE EXCEPTION 'أدخل كمية موجبة لصنف واحد على الأقل'; END IF;

  v_operation:='QMP-RECEIVE:'||p_company_id::text||':'||p_invoice_id::text||':'||p_operation_id::text;
  SELECT md5(COALESCE(string_agg(btrim(x.item_code)||':'||COALESCE(x.received_qty,0)::text,'|' ORDER BY btrim(x.item_code)),''))
  INTO v_fingerprint
  FROM jsonb_to_recordset(p_items) x(item_code text,received_qty numeric,item_name text,unit text,reason text)
  WHERE COALESCE(x.received_qty,0)>0;

  SELECT * INTO v_existing
  FROM public.receiving r
  WHERE r.company_id=p_company_id AND r.operation_id=v_operation
  FOR UPDATE;
  IF FOUND THEN
    IF v_existing.purchase_invoice_id IS DISTINCT FROM p_invoice_id
       OR v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'QMP_RECEIVE_OPERATION_ID_CONFLICT';
    END IF;
    RETURN jsonb_build_object('success',true,'duplicate',true,'invoice_id',p_invoice_id,
      'invoice_code',v_invoice.invoice_code,'operation_id',v_operation,'status',v_invoice.receipt_status);
  END IF;

  FOR v_input IN
    SELECT * FROM jsonb_to_recordset(p_items)
      x(item_code text,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    IF COALESCE(v_input.received_qty,0)<=0 THEN CONTINUE; END IF;
    IF NULLIF(btrim(v_input.item_code),'') IS NULL OR v_input.received_qty IS NULL
       OR v_input.received_qty::text IN ('NaN','Infinity','-Infinity') OR v_input.received_qty<0 THEN
      RAISE EXCEPTION 'بيانات الصنف أو الكمية غير صالحة';
    END IF;
    SELECT * INTO v_detail
    FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND d.item_code=btrim(v_input.item_code)
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود في فاتورة السوق: %',v_input.item_code; END IF;
    SELECT * INTO v_item FROM public.items i
    WHERE i.id=v_detail.item_id AND i.company_id=p_company_id AND i.item_code=v_detail.item_code;
    IF NOT FOUND THEN RAISE EXCEPTION 'هوية الصنف غير متسقة مع دليل الأصناف: %',v_input.item_code; END IF;
    IF v_input.received_qty<=0 OR v_input.received_qty>GREATEST(0,v_detail.qty-COALESCE(v_detail.received_qty,0))+0.0001 THEN
      RAISE EXCEPTION 'الكمية المستلمة تتجاوز المتبقي في الفاتورة: %',v_input.item_code;
    END IF;
    SELECT GREATEST(
      v_detail.qty
      -GREATEST(COALESCE(v_detail.received_qty,0),CASE WHEN COALESCE(v_invoice.is_received,false) THEN v_detail.qty ELSE 0 END,COALESCE(w.warehouse_event_qty,0))
      -COALESCE(r.supplier_returned_qty,0),0
    ) INTO v_balance
    FROM (SELECT 1) seed
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS warehouse_event_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
        AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
        AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) w ON true
    LEFT JOIN LATERAL (
      SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0)) AS supplier_returned_qty
      FROM public.buyer_goods_custody_events e
      LEFT JOIN public.buyer_goods_custody_events parent
        ON e.event_type='BUYER_CUSTODY_CORRECTION'
       AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
      WHERE e.company_id=p_company_id
        AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
        AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
        AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
        AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
        AND e.custodian_user_id=v_invoice.purchaser_user_id
        AND e.branch_id=v_invoice.branch_id
    ) r ON true;
    IF v_balance+0.0001<v_input.received_qty THEN
      RAISE EXCEPTION 'الكمية المستلمة أكبر من الكمية المسجلة في حيازة المشتري: %',v_input.item_code;
    END IF;
  END LOOP;

  INSERT INTO public.receiving(
    id,operation_id,date,po_number,responsible,start_time,end_time,status,company_id,
    purchase_invoice_id,request_fingerprint
  )
  VALUES(gen_random_uuid(),v_operation,current_date,v_invoice.invoice_code,p_user_email,now(),now(),
    'مكتمل',p_company_id,p_invoice_id,v_fingerprint);

  FOR v_input IN
    SELECT * FROM jsonb_to_recordset(p_items)
      x(item_code text,received_qty numeric,item_name text,unit text,reason text)
  LOOP
    IF COALESCE(v_input.received_qty,0)<=0 THEN CONTINUE; END IF;
    SELECT * INTO v_detail
    FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND d.item_code=btrim(v_input.item_code)
    FOR UPDATE;
    SELECT * INTO v_item FROM public.items i WHERE i.id=v_detail.item_id AND i.company_id=p_company_id;
    SELECT public.post_stock_movement(
      p_company_id,'PurchaseIn',NULL,v_invoice.branch_id,v_item.id,v_input.received_qty,
      v_invoice.invoice_code,v_invoice.invoice_code,p_user_email,
      'QMP-RECEIPT:'||p_company_id::text||':'||p_invoice_id::text||':'||p_operation_id::text||':'||v_item.id::text
    ) INTO v_stock_result;

    UPDATE public.purchase_invoice_details
    SET received_qty=COALESCE(received_qty,0)+v_input.received_qty
    WHERE id=v_detail.id AND invoice_id=p_invoice_id;

    INSERT INTO public.receiving_details(
      id,operation_id,item_code,item_name,unit,qty_expected,qty_received,difference,reason,purchase_invoice_detail_id
    )
    VALUES(
      gen_random_uuid(),v_operation,v_detail.item_code,
      COALESCE(NULLIF(v_input.item_name,''),v_detail.item_name,v_detail.item_code),
      COALESCE(NULLIF(v_input.unit,''),v_detail.unit,'حبة'),
      v_detail.qty,v_input.received_qty,v_input.received_qty-v_detail.qty,
      NULLIF(COALESCE(v_input.reason,CASE WHEN v_input.received_qty<v_detail.qty THEN 'استلام جزئي' ELSE '' END),''),
      v_detail.id
    );

    INSERT INTO public.buyer_goods_custody_events(
      company_id,branch_id,custodian_user_id,item_id,vehicle_id,event_type,qty_delta,
      source_document_type,source_document_id,source_line_id,operation_id,payload_fingerprint,
      actor_user_id,notes
    )
    VALUES(
      p_company_id,v_invoice.branch_id,v_invoice.purchaser_user_id,v_detail.item_id,NULL,
      'BUYER_TO_WAREHOUSE_ACCEPTED',-v_input.received_qty,
      'PurchaseInvoice',p_invoice_id,v_detail.id,v_operation,v_fingerprint,
      v_actor.id,'استلام المخزن من فاتورة السوق السريع '||v_invoice.invoice_code
    );
    v_total_qty:=v_total_qty+v_input.received_qty;
    v_total_value:=v_total_value+ROUND(
      v_input.received_qty*COALESCE(v_detail.unit_price,0)
      *(1-COALESCE(v_detail.discount_percent,0)/100)
      *(1+COALESCE(v_detail.tax_rate,0)/100),2
    );
  END LOOP;

  IF EXISTS(
    SELECT 1 FROM public.purchase_invoice_details d
    WHERE d.invoice_id=p_invoice_id AND COALESCE(d.received_qty,0)+0.0001<d.qty
  ) THEN
    v_all_received:=false;
  END IF;

  UPDATE public.purchase_invoices
  SET receipt_status=CASE WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
      is_received=v_all_received,
      received_date=CASE WHEN v_all_received THEN COALESCE(received_date,current_date) ELSE NULL END,
      updated_at=now()
  WHERE id=p_invoice_id AND company_id=p_company_id;

  INSERT INTO public.audit_log(user_email,action,table_name,record_id,new_data)
  VALUES(p_user_email,'receive','purchase_invoices',p_invoice_id::text,
    jsonb_build_object('invoice_code',v_invoice.invoice_code,'operation_id',v_operation,
      'receipt_status',CASE WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
      'received_qty',v_total_qty,'received_value',v_total_value));

  RETURN jsonb_build_object('success',true,'duplicate',false,'invoice_id',p_invoice_id,
    'invoice_code',v_invoice.invoice_code,'operation_id',v_operation,
    'receipt_status',CASE WHEN v_all_received THEN 'RECEIVED' ELSE 'PARTIALLY_RECEIVED' END,
    'total_received_qty',v_total_qty,'total_received_value',v_total_value,
    'journal_posted',false,'supplier_balance_changed',false);
END;
$function$


CREATE OR REPLACE FUNCTION public.buyer_goods_custody_register_quick_market_supplier_return_atomic(
  p_company_id uuid,p_invoice_id uuid,p_items jsonb,p_evidence_path text,p_reason text,p_operation_id text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_actor public.users%ROWTYPE;
  v_invoice public.purchase_invoices%ROWTYPE;
  v_detail public.purchase_invoice_details%ROWTYPE;
  v_item jsonb;
  v_line_id uuid;
  v_qty numeric(14,4);
  v_available numeric(14,4);
  v_warehouse_qty numeric(14,4);
  v_returned_qty numeric(14,4);
  v_file_size bigint;
  v_file_mime text;
  v_fingerprint text;
  v_existing_count integer;
  v_inserted integer:=0;
  v_events jsonb:='[]'::jsonb;
BEGIN
  SELECT * INTO v_actor
  FROM public.users
  WHERE auth.uid()=users.auth_id AND company_id=p_company_id
    AND COALESCE(status,'Active')='Active';
  IF NOT FOUND OR NOT app_private.current_user_has_effective_permission('purchases') THEN
    RAISE EXCEPTION 'BUYER_PURCHASE_PERMISSION_REQUIRED';
  END IF;

  IF NULLIF(btrim(p_operation_id),'') IS NULL OR length(btrim(p_operation_id))>180 THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_OPERATION_ID_INVALID';
  END IF;
  IF NULLIF(btrim(p_reason),'') IS NULL OR length(btrim(p_reason))<5 OR length(btrim(p_reason))>1000 THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_REASON_REQUIRED';
  END IF;
  IF COALESCE(jsonb_typeof(p_items),'')<>'array' THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_ITEMS_INVALID';
  END IF;
  IF jsonb_array_length(p_items)<1 OR jsonb_array_length(p_items)>200 THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_ITEMS_INVALID';
  END IF;

  IF NULLIF(btrim(p_evidence_path),'') IS NULL
     OR cardinality(string_to_array(p_evidence_path,'/'))<>5
     OR split_part(p_evidence_path,'/',1)<>p_company_id::text
     OR split_part(p_evidence_path,'/',2)<>v_actor.id::text
     OR split_part(p_evidence_path,'/',3)<>'buyer-goods'
     OR split_part(p_evidence_path,'/',4)<>p_invoice_id::text
     OR split_part(p_evidence_path,'/',5)!~'^supplier-return-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$' THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_EVIDENCE_PATH_INVALID';
  END IF;

  SELECT
    CASE WHEN COALESCE(o.metadata->>'size','') ~ '^[0-9]{1,8}$' THEN (o.metadata->>'size')::bigint ELSE 0 END,
    lower(COALESCE(o.metadata->>'mimetype',''))
  INTO v_file_size,v_file_mime
  FROM storage.objects o
  WHERE o.bucket_id='employee-documents' AND o.name=p_evidence_path;
  IF NOT FOUND OR v_file_size<1 OR v_file_size>10485760
     OR v_file_mime NOT IN ('image/jpeg','image/png','image/webp','application/pdf') THEN
    RAISE EXCEPTION 'BUYER_GOODS_RETURN_EVIDENCE_INVALID';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    'RAWAEA:BUYER-GOODS-RETURN:'||p_company_id::text||':'||btrim(p_operation_id),0
  ));

  SELECT * INTO v_invoice
  FROM public.purchase_invoices
  WHERE id=p_invoice_id AND company_id=p_company_id
  FOR UPDATE;
  IF NOT FOUND OR v_invoice.purchase_source<>'QUICK_MARKET'
     OR v_invoice.purchaser_user_id IS DISTINCT FROM v_actor.id
     OR v_invoice.branch_id IS NULL OR v_invoice.supplier_id IS NULL
     OR NULLIF(btrim(v_invoice.supplier_invoice_no),'') IS NULL THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_ELIGIBLE_FOR_SUPPLIER_RETURN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.suppliers s WHERE s.id=v_invoice.supplier_id AND s.company_id=p_company_id)
     OR NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id=v_invoice.branch_id AND b.company_id=p_company_id) THEN
    RAISE EXCEPTION 'QUICK_MARKET_RETURN_PARTY_OR_BRANCH_INVALID';
  END IF;

  v_fingerprint:=md5(jsonb_build_object(
    'invoice_id',p_invoice_id,'supplier_id',v_invoice.supplier_id,
    'branch_id',v_invoice.branch_id,'items',p_items,
    'evidence_path',p_evidence_path,'reason',btrim(p_reason)
  )::text);

  SELECT count(*) INTO v_existing_count
  FROM public.buyer_goods_custody_events
  WHERE company_id=p_company_id AND operation_id=btrim(p_operation_id);
  IF v_existing_count>0 THEN
    IF EXISTS (
      SELECT 1 FROM public.buyer_goods_custody_events
      WHERE company_id=p_company_id AND operation_id=btrim(p_operation_id)
        AND (payload_fingerprint IS DISTINCT FROM v_fingerprint
          OR event_type IS DISTINCT FROM 'BUYER_TO_SUPPLIER_ACCEPTED'
          OR source_document_type IS DISTINCT FROM 'PurchaseInvoice'
          OR source_document_id IS DISTINCT FROM p_invoice_id)
    ) THEN RAISE EXCEPTION 'BUYER_GOODS_RETURN_OPERATION_ID_PAYLOAD_CONFLICT'; END IF;
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',id,'item_id',item_id,'source_line_id',source_line_id,
      'qty_delta',qty_delta,'event_type',event_type
    ) ORDER BY created_at),'[]'::jsonb)
    INTO v_events
    FROM public.buyer_goods_custody_events
    WHERE company_id=p_company_id AND operation_id=btrim(p_operation_id);
    RETURN jsonb_build_object(
      'success',true,'duplicate',true,'invoice_id',p_invoice_id,'events',v_events,
      'warehouse_stock_changed',false,'supplier_balance_changed',false,
      'treasury_changed',false,'journal_posted',false
    );
  END IF;

  IF v_invoice.status NOT IN ('Draft','PartiallyPaid')
     OR COALESCE(v_invoice.is_received,false)
     OR v_invoice.received_date IS NOT NULL
     OR v_invoice.receipt_status NOT IN ('NOT_RECEIVED','PARTIALLY_RECEIVED') THEN
    RAISE EXCEPTION 'QUICK_MARKET_INVOICE_NOT_ELIGIBLE_FOR_SUPPLIER_RETURN';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_to_recordset(p_items) x(invoice_detail_id uuid,qty numeric)
    GROUP BY invoice_detail_id HAVING count(*)>1
  ) THEN RAISE EXCEPTION 'BUYER_GOODS_RETURN_DUPLICATE_INVOICE_LINE'; END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_line_id:=NULLIF(btrim(v_item->>'invoice_detail_id'),'')::uuid;
    v_qty:=NULLIF(btrim(v_item->>'qty'),'')::numeric;
    IF v_line_id IS NULL OR v_qty IS NULL
       OR v_qty::text IN ('NaN','Infinity','-Infinity') OR v_qty<=0 THEN
      RAISE EXCEPTION 'BUYER_GOODS_RETURN_LINE_INPUT_INVALID';
    END IF;

    SELECT * INTO v_detail
    FROM public.purchase_invoice_details d
    WHERE d.id=v_line_id AND d.invoice_id=p_invoice_id
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'BUYER_GOODS_RETURN_LINE_NOT_IN_INVOICE'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id=v_detail.item_id AND i.company_id=p_company_id) THEN
      RAISE EXCEPTION 'BUYER_GOODS_RETURN_ITEM_COMPANY_MISMATCH';
    END IF;

    SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0))
    INTO v_warehouse_qty
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
      AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
      AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
      AND COALESCE(parent.event_type,e.event_type) IN ('BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_WAREHOUSE_RETURN')
      AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id;

    SELECT GREATEST(0,0-COALESCE(SUM(e.qty_delta),0))
    INTO v_returned_qty
    FROM public.buyer_goods_custody_events e
    LEFT JOIN public.buyer_goods_custody_events parent
      ON e.event_type='BUYER_CUSTODY_CORRECTION'
     AND parent.id=e.reverses_event_id AND parent.company_id=e.company_id
    WHERE e.company_id=p_company_id
      AND COALESCE(parent.source_document_type,e.source_document_type)='PurchaseInvoice'
      AND COALESCE(parent.source_document_id,e.source_document_id)=p_invoice_id
      AND COALESCE(parent.source_line_id,e.source_line_id)=v_detail.id
      AND COALESCE(parent.event_type,e.event_type)='BUYER_TO_SUPPLIER_ACCEPTED'
      AND e.custodian_user_id=v_invoice.purchaser_user_id AND e.branch_id=v_invoice.branch_id;

    v_available:=GREATEST(
      v_detail.qty
      -GREATEST(COALESCE(v_detail.received_qty,0),CASE WHEN COALESCE(v_invoice.is_received,false) THEN v_detail.qty ELSE 0 END,COALESCE(v_warehouse_qty,0))
      -COALESCE(v_returned_qty,0),0
    );
    IF v_available+0.0001<v_qty THEN
      RAISE EXCEPTION 'BUYER_GOODS_RETURN_EXCEEDS_CURRENT_CUSTODY:%',v_detail.item_code;
    END IF;

    INSERT INTO public.buyer_goods_custody_events(
      company_id,branch_id,custodian_user_id,item_id,vehicle_id,event_type,qty_delta,
      source_document_type,source_document_id,source_line_id,related_document_type,
      related_document_id,operation_id,payload_fingerprint,evidence_path,actor_user_id,notes
    ) VALUES (
      p_company_id,v_invoice.branch_id,v_invoice.purchaser_user_id,v_detail.item_id,NULL,
      'BUYER_TO_SUPPLIER_ACCEPTED',-v_qty,'PurchaseInvoice',p_invoice_id,v_detail.id,
      'Supplier',v_invoice.supplier_id,btrim(p_operation_id),v_fingerprint,p_evidence_path,
      v_actor.id,'قبول المورد لمرتجع شراء سوق سريع: '||btrim(p_reason)
    );
    v_inserted:=v_inserted+1;
  END LOOP;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',id,'item_id',item_id,'source_line_id',source_line_id,
    'qty_delta',qty_delta,'event_type',event_type
  ) ORDER BY created_at),'[]'::jsonb)
  INTO v_events
  FROM public.buyer_goods_custody_events
  WHERE company_id=p_company_id AND operation_id=btrim(p_operation_id);

  RETURN jsonb_build_object(
    'success',true,'duplicate',false,'invoice_id',p_invoice_id,'operation_id',btrim(p_operation_id),
    'event_count',v_inserted,'events',v_events,'warehouse_stock_changed',false,
    'supplier_balance_changed',false,'treasury_changed',false,'journal_posted',false
  );
END;
$function$

DROP POLICY IF EXISTS buyer_goods_docs_insert_owner ON storage.objects;
CREATE POLICY buyer_goods_docs_insert_owner ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='employee-documents'
  AND cardinality(storage.foldername(storage.objects.name))=4
  AND (storage.foldername(storage.objects.name))[3]='buyer-goods'
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.purchase_invoices pi ON pi.id::text=(storage.foldername(storage.objects.name))[4]
      AND pi.company_id=u.company_id AND pi.purchaser_user_id=u.id AND pi.purchase_source='QUICK_MARKET'
    WHERE u.auth_id=(SELECT auth.uid())
      AND u.company_id::text=(storage.foldername(storage.objects.name))[1]
      AND u.id::text=(storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status,'Active')='Active'
      AND app_private.current_user_has_effective_permission('purchases')
      AND pi.status IN ('Draft','PartiallyPaid')
      AND pi.is_received=false AND pi.received_date IS NULL
      AND (
        storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
        OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
        OR (
          storage.filename(storage.objects.name) ~ '^supplier-return-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
          AND CASE WHEN COALESCE(storage.objects.metadata->>'size','') ~ '^[0-9]{1,8}$'
              THEN (storage.objects.metadata->>'size')::bigint ELSE 0 END BETWEEN 1 AND 10485760
          AND lower(COALESCE(storage.objects.metadata->>'mimetype','')) IN ('image/jpeg','image/png','image/webp','application/pdf')
        )
      )
  )
);

DROP POLICY IF EXISTS buyer_goods_docs_select_owner ON storage.objects;
CREATE POLICY buyer_goods_docs_select_owner ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id='employee-documents'
  AND cardinality(storage.foldername(storage.objects.name))=4
  AND (storage.foldername(storage.objects.name))[3]='buyer-goods'
  AND (
    storage.filename(storage.objects.name) ~ '^supplier-invoice-[A-Za-z0-9._-]{1,160}$'
    OR storage.filename(storage.objects.name) ~ '^handover-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
    OR storage.filename(storage.objects.name) ~ '^supplier-return-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$'
  )
  AND EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.purchase_invoices pi ON pi.id::text=(storage.foldername(storage.objects.name))[4]
      AND pi.company_id=u.company_id AND pi.purchaser_user_id=u.id AND pi.purchase_source='QUICK_MARKET'
    WHERE u.auth_id=(SELECT auth.uid())
      AND u.company_id::text=(storage.foldername(storage.objects.name))[1]
      AND u.id::text=(storage.foldername(storage.objects.name))[2]
      AND COALESCE(u.status,'Active')='Active'
      AND app_private.current_user_has_effective_permission('purchases')
  )
);

REVOKE ALL ON FUNCTION public.buyer_goods_custody_register_quick_market_supplier_return_atomic(uuid,uuid,jsonb,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.buyer_goods_custody_register_quick_market_supplier_return_atomic(uuid,uuid,jsonb,text,text,text) TO authenticated, service_role;

COMMIT;
