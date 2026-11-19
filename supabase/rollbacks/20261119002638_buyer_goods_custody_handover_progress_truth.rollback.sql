-- Rollback to the immediately previous progress read model.
CREATE OR REPLACE FUNCTION public.buyer_goods_custody_get_invoice_handover_progress_atomic(p_company_id uuid, p_invoice_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
;
