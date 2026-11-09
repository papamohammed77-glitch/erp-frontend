import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json"
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = await req.json().catch(() => ({}));
    const op = String(body?.operation || "").trim();
    if (!op) throw new Error("عملية المشتريات مطلوبة");

    const auth = req.headers.get("Authorization");
    if (!auth) throw new Error("غير مصرح");

    const { data: { user }, error: ae } = await sb.auth.getUser(auth.replace("Bearer ", ""));
    if (ae || !user?.id || !user?.email) throw new Error("جلسة غير صالحة");

    const { data: u, error: ue } = await sb
      .from("users")
      .select("company_id,status")
      .eq("auth_id", user.id)
      .maybeSingle();

    if (ue || !u?.company_id || (u.status && u.status !== "Active")) {
      throw new Error("سياق الشركة غير متاح");
    }

    const companyId = u.company_id;
    const p = body?.payload || {};

    // Resolve the caller's authoritative effective permissions using the caller JWT,
    // not the service-role client used for atomic business operations.
    const profileClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } }, auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }
    );
    const { data: profile, error: profileError } = await profileClient.rpc("get_my_effective_profile");
    if (profileError || !profile?.auth_id || profile.auth_id !== user.id || profile.company_id !== companyId) {
      throw new Error("تعذر التحقق من صلاحيات المستخدم ونطاق الشركة");
    }
    const effectivePermissions = Array.isArray(profile.permissions) ? profile.permissions.map((x: any) => String(x)) : [];
    const isOwner = profile.isOwner === true;
    const hasPermission = (key: string) => isOwner || effectivePermissions.includes("*") || effectivePermissions.includes(key);
    const requireAny = (keys: string[]) => {
      if (!keys.some(hasPermission)) {
        throw new Error("لا تملك صلاحية تنفيذ عملية المشتريات المطلوبة");
      }
    };
    const requireAll = (keys: string[]) => {
      if (!keys.every(hasPermission)) {
        throw new Error("تتطلب هذه العملية صلاحيات المشتريات والمالية");
      }
    };

    if (op === "APPROVE_PO") {
      requireAny(["purchases", "purchases_supervisor"]);
    } else if (op === "REGISTER_QUICK_MARKET_SUPPLIER_RETURN") {
      requireAny(["purchases"]);
    } else if (op === "SAVE_SETTINGS") {
      requireAny(["purchases", "settings"]);
    } else if (["POST_INVOICE", "POST_PAYMENT", "POST_RETURN"].includes(op)) {
      requireAll(["purchases", "finance"]);
    } else if (op === "CANCEL_DOCUMENT" && ["PurchaseInvoice", "PurchasePayment", "PurchaseReturn"].includes(String(p.document_type || ""))) {
      requireAll(["purchases", "finance"]);
    } else if (op === "GET_SUMMARY" || op === "GET_REPORTS") {
      requireAny(["purchases", "finance", "finance_manager", "reports"]);
    } else if (op === "SAVE_SUPPLIER") {
      requireAny(["purchases", "suppliers"]);
    } else if (["ISSUE_CUSTODY", "ADD_CUSTODY_ADVANCE", "REVIEW_CUSTODY_EXPENSE", "REVIEW_QUICK_MARKET_CUSTODY_EXPENSE", "REVIEW_OTHER_CUSTODY_EXPENSE", "GET_OTHER_CUSTODY_EXPENSE_ACCOUNTS", "SETTLE_CUSTODY", "RETURN_CUSTODY_CASH", "UPDATE_CUSTODY", "CANCEL_CUSTODY"].includes(op)) {
      requireAny(["finance", "finance_manager"]);
    } else if (["SUBMIT_CUSTODY_EXPENSE", "SUBMIT_QUICK_MARKET_CUSTODY_EXPENSE", "SUBMIT_OTHER_CUSTODY_EXPENSE", "VERIFY_CUSTODY_EXPENSE_OPERATION", "ACKNOWLEDGE_CUSTODY", "ACKNOWLEDGE_CUSTODY_ADVANCE"].includes(op)) {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_CUSTODY") {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_SETTINGS") {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_DATA") {
      const table = String(p.table || "");
      if (table === "treasury") requireAny(["finance", "finance_manager"]);
      else if (table === "suppliers") requireAny(["purchases", "suppliers", "finance", "finance_manager"]);
      else if (table === "stock_branches") requireAny(["purchases", "warehouse", "finance", "finance_manager"]);
      else requireAny(["purchases", "finance", "finance_manager"]);
    } else {
      requireAny(["purchases"]);
    }

    const operationId = String(
      body?.operation_id ||
      req.headers.get("Idempotency-Key") ||
      crypto.randomUUID()
    ).trim();

    let data: any, error: any;
    const call = (name: string, args: any) => sb.rpc(name, args);
    const getSystemCurrency = async () => {
      const { data: settings, error: settingsError } = await sb.from("app_settings")
        .select("currency").eq("company_id", companyId).order("created_at", { ascending: true }).order("id", { ascending: true }).limit(1).maybeSingle();
      if (settingsError) throw settingsError;
      const currency = String(settings?.currency || "").trim().toUpperCase();
      if (!/^[A-Z]{3}$/.test(currency)) throw new Error("SYSTEM_CURRENCY_INVALID");
      return currency;
    };

    if (op === "SAVE_SUPPLIER") {
      ({ data, error } = await call("save_supplier_atomic", {
        p_auth_user_id: user.id,
        p_company_id: companyId,
        p_user_email: user.email,
        p_supplier: p.supplier || {},
        p_is_edit: p.is_edit === true,
        p_supplier_code: p.supplier_code || null
      }));
    } else if (op === "CREATE_REQUEST") {
      ({ data, error } = await call("purchase_create_request_atomic", {
        p_company_id: companyId,
        p_title: p.title,
        p_required_by: p.required_by || null,
        p_requested_by: user.email,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "CREATE_PO") {
      ({ data, error } = await profileClient.rpc("purchase_create_po_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id, p_branch_id: p.branch_id || null,
        p_expected_delivery_date: p.expected_delivery_date || null, p_payment_terms: p.payment_terms || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "APPROVE_PO") {
      ({ data, error } = await profileClient.rpc("purchase_approve_po_atomic", {
        p_po_id: p.id
      }));
    } else if (op === "SUBMIT_REQUEST") {
      ({ data, error } = await call("purchase_submit_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "APPROVE_REQUEST") {
      ({ data, error } = await call("purchase_approve_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "REJECT_REQUEST") {
      ({ data, error } = await call("purchase_reject_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email,
        p_reason: p.reason || null
      }));
    } else if (op === "CREATE_RFQ") {
      ({ data, error } = await call("purchase_create_rfq_atomic", {
        p_company_id: companyId,
        p_request_id: p.request_id,
        p_due_date: p.due_date || null,
        p_created_by: user.email,
        p_supplier_ids: p.supplier_ids || []
      }));
    } else if (op === "SEND_RFQ") {
      ({ data, error } = await call("purchase_send_rfq_atomic", {
        p_company_id: companyId,
        p_rfq_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CREATE_QUOTATION") {
      ({ data, error } = await call("purchase_create_quotation_atomic", {
        p_company_id: companyId,
        p_supplier_id: p.supplier_id,
        p_rfq_id: p.rfq_id || null,
        p_valid_until: p.valid_until || null,
        p_currency: await getSystemCurrency(),
        p_created_by: user.email,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "ACCEPT_QUOTATION") {
      ({ data, error } = await call("purchase_accept_quotation_atomic", {
        p_company_id: companyId,
        p_quotation_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CONVERT_QUOTATION_TO_PO") {
      ({ data, error } = await call("purchase_convert_quotation_to_po_atomic", {
        p_company_id: companyId,
        p_quotation_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CREATE_PO_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_create_po_invoice_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id, p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "UPDATE_PO_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_update_po_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id, p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "CREATE_QUICK_MARKET_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_create_quick_market_invoice_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id, p_branch_id: p.branch_id,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no,
        p_notes: p.notes || null, p_items: p.items || [],
        p_settlement_source: p.settlement_source, p_cash_custody_id: p.cash_custody_id || null,
        p_operation_id: operationId
      }));
    } else if (op === "UPDATE_QUICK_MARKET_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_update_quick_market_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_supplier_id: p.supplier_id,
        p_branch_id: p.branch_id, p_due_date: p.due_date || null,
        p_supplier_invoice_no: p.supplier_invoice_no, p_notes: p.notes || null,
        p_items: p.items || [], p_settlement_source: p.settlement_source,
        p_cash_custody_id: p.cash_custody_id || null, p_operation_id: operationId
      }));
    } else if (op === "REGISTER_QUICK_MARKET_HANDOVER") {
      ({ data, error } = await profileClient.rpc("buyer_goods_custody_register_handover_atomic", {
        p_company_id: companyId, p_invoice_id: p.invoice_id, p_vehicle_id: p.vehicle_id || null,
        p_items: p.items || [], p_evidence_path: p.evidence_path || null,
        p_notes: p.notes || null, p_operation_id: operationId
      }));
    } else if (op === "REGISTER_QUICK_MARKET_SUPPLIER_RETURN") {
      requireAny(["purchases"]);
    } else if (op === "SAVE_SETTINGS") {
      requireAny(["purchases", "settings"]);
    } else if (["POST_INVOICE", "POST_PAYMENT", "POST_RETURN"].includes(op)) {
      requireAll(["purchases", "finance"]);
    } else if (op === "CANCEL_DOCUMENT" && ["PurchaseInvoice", "PurchasePayment", "PurchaseReturn"].includes(String(p.document_type || ""))) {
      requireAll(["purchases", "finance"]);
    } else if (op === "GET_SUMMARY" || op === "GET_REPORTS") {
      requireAny(["purchases", "finance", "finance_manager", "reports"]);
    } else if (op === "SAVE_SUPPLIER") {
      requireAny(["purchases", "suppliers"]);
    } else if (["ISSUE_CUSTODY", "ADD_CUSTODY_ADVANCE", "REVIEW_CUSTODY_EXPENSE", "REVIEW_QUICK_MARKET_CUSTODY_EXPENSE", "REVIEW_OTHER_CUSTODY_EXPENSE", "GET_OTHER_CUSTODY_EXPENSE_ACCOUNTS", "SETTLE_CUSTODY", "RETURN_CUSTODY_CASH", "UPDATE_CUSTODY", "CANCEL_CUSTODY"].includes(op)) {
      requireAny(["finance", "finance_manager"]);
    } else if (["SUBMIT_CUSTODY_EXPENSE", "SUBMIT_QUICK_MARKET_CUSTODY_EXPENSE", "SUBMIT_OTHER_CUSTODY_EXPENSE", "VERIFY_CUSTODY_EXPENSE_OPERATION", "ACKNOWLEDGE_CUSTODY", "ACKNOWLEDGE_CUSTODY_ADVANCE"].includes(op)) {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_CUSTODY") {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_SETTINGS") {
      requireAny(["purchases", "finance", "finance_manager"]);
    } else if (op === "GET_DATA") {
      const table = String(p.table || "");
      if (table === "treasury") requireAny(["finance", "finance_manager"]);
      else if (table === "suppliers") requireAny(["purchases", "suppliers", "finance", "finance_manager"]);
      else if (table === "stock_branches") requireAny(["purchases", "warehouse", "finance", "finance_manager"]);
      else requireAny(["purchases", "finance", "finance_manager"]);
    } else {
      requireAny(["purchases"]);
    }

    const operationId = String(
      body?.operation_id ||
      req.headers.get("Idempotency-Key") ||
      crypto.randomUUID()
    ).trim();

    let data: any, error: any;
    const call = (name: string, args: any) => sb.rpc(name, args);
    const getSystemCurrency = async () => {
      const { data: settings, error: settingsError } = await sb.from("app_settings")
        .select("currency").eq("company_id", companyId).order("created_at", { ascending: true }).order("id", { ascending: true }).limit(1).maybeSingle();
      if (settingsError) throw settingsError;
      const currency = String(settings?.currency || "").trim().toUpperCase();
      if (!/^[A-Z]{3}$/.test(currency)) throw new Error("SYSTEM_CURRENCY_INVALID");
      return currency;
    };

    if (op === "SAVE_SUPPLIER") {
      ({ data, error } = await call("save_supplier_atomic", {
        p_auth_user_id: user.id,
        p_company_id: companyId,
        p_user_email: user.email,
        p_supplier: p.supplier || {},
        p_is_edit: p.is_edit === true,
        p_supplier_code: p.supplier_code || null
      }));
    } else if (op === "CREATE_REQUEST") {
      ({ data, error } = await call("purchase_create_request_atomic", {
        p_company_id: companyId,
        p_title: p.title,
        p_required_by: p.required_by || null,
        p_requested_by: user.email,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "CREATE_PO") {
      ({ data, error } = await profileClient.rpc("purchase_create_po_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id, p_branch_id: p.branch_id || null,
        p_expected_delivery_date: p.expected_delivery_date || null, p_payment_terms: p.payment_terms || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "APPROVE_PO") {
      ({ data, error } = await profileClient.rpc("purchase_approve_po_atomic", {
        p_po_id: p.id
      }));
    } else if (op === "SUBMIT_REQUEST") {
      ({ data, error } = await call("purchase_submit_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "APPROVE_REQUEST") {
      ({ data, error } = await call("purchase_approve_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "REJECT_REQUEST") {
      ({ data, error } = await call("purchase_reject_request_atomic", {
        p_company_id: companyId,
        p_request_id: p.id,
        p_actor: user.email,
        p_reason: p.reason || null
      }));
    } else if (op === "CREATE_RFQ") {
      ({ data, error } = await call("purchase_create_rfq_atomic", {
        p_company_id: companyId,
        p_request_id: p.request_id,
        p_due_date: p.due_date || null,
        p_created_by: user.email,
        p_supplier_ids: p.supplier_ids || []
      }));
    } else if (op === "SEND_RFQ") {
      ({ data, error } = await call("purchase_send_rfq_atomic", {
        p_company_id: companyId,
        p_rfq_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CREATE_QUOTATION") {
      ({ data, error } = await call("purchase_create_quotation_atomic", {
        p_company_id: companyId,
        p_supplier_id: p.supplier_id,
        p_rfq_id: p.rfq_id || null,
        p_valid_until: p.valid_until || null,
        p_currency: await getSystemCurrency(),
        p_created_by: user.email,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "ACCEPT_QUOTATION") {
      ({ data, error } = await call("purchase_accept_quotation_atomic", {
        p_company_id: companyId,
        p_quotation_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CONVERT_QUOTATION_TO_PO") {
      ({ data, error } = await call("purchase_convert_quotation_to_po_atomic", {
        p_company_id: companyId,
        p_quotation_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "CREATE_PO_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_create_po_invoice_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id, p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "UPDATE_PO_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_update_po_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id, p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "CREATE_QUICK_MARKET_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_create_quick_market_invoice_atomic", {
        p_company_id: companyId, p_supplier_id: p.supplier_id, p_branch_id: p.branch_id,
        p_due_date: p.due_date || null, p_supplier_invoice_no: p.supplier_invoice_no,
        p_notes: p.notes || null, p_items: p.items || [],
        p_settlement_source: p.settlement_source, p_cash_custody_id: p.cash_custody_id || null,
        p_operation_id: operationId
      }));
    } else if (op === "UPDATE_QUICK_MARKET_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_update_quick_market_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_supplier_id: p.supplier_id,
        p_branch_id: p.branch_id, p_due_date: p.due_date || null,
        p_supplier_invoice_no: p.supplier_invoice_no, p_notes: p.notes || null,
        p_items: p.items || [], p_settlement_source: p.settlement_source,
        p_cash_custody_id: p.cash_custody_id || null, p_operation_id: operationId
      }));
    } else if (op === "REGISTER_QUICK_MARKET_HANDOVER") {
      ({ data, error } = await profileClient.rpc("buyer_goods_custody_register_handover_atomic", {
        p_company_id: companyId, p_invoice_id: p.invoice_id, p_vehicle_id: p.vehicle_id || null,
        p_items: p.items || [], p_evidence_path: p.evidence_path || null,
        p_notes: p.notes || null, p_operation_id: operationId
      }));
    } else if (op === "REGISTER_QUICK_MARKET_SUPPLIER_RETURN") {
      const invoiceId = String(p.invoice_id || "").trim();
      const evidencePath = String(p.evidence_path || "").trim();
      const pathParts = evidencePath.split("/");
      if (!invoiceId || pathParts.length !== 5 || pathParts[0] !== companyId ||
          pathParts[1] !== profile.id || pathParts[2] !== "buyer-goods" ||
          pathParts[3] !== invoiceId ||
          !/^supplier-return-[0-9]{10,16}_[A-Za-z0-9._-]{1,80}$/.test(pathParts[4])) {
        throw new Error("BUYER_GOODS_RETURN_EVIDENCE_PATH_INVALID");
      }
      if (!operationId || operationId.length > 180) throw new Error("BUYER_GOODS_RETURN_OPERATION_ID_INVALID");

      const { data: invoice, error: invoiceError } = await sb.from("purchase_invoices")
        .select("id,purchase_source,purchaser_user_id")
        .eq("id", invoiceId).eq("company_id", companyId).maybeSingle();
      if (invoiceError) throw invoiceError;
      if (!invoice || invoice.purchase_source !== "QUICK_MARKET" || invoice.purchaser_user_id !== profile.id) {
        throw new Error("QUICK_MARKET_INVOICE_OWNER_REQUIRED");
      }

      const { data: storedObject, error: storedObjectError } = await sb.storage
        .from("employee-documents").info(evidencePath);
      if (storedObjectError) throw storedObjectError;
      if (!storedObject) throw new Error("BUYER_GOODS_RETURN_EVIDENCE_NOT_FOUND");
      const metadata = storedObject.metadata || {};
      const mimeType = String(storedObject.mimetype || storedObject.contentType || metadata.mimetype || "").trim().toLowerCase();
      const fileSize = Number(storedObject.size || metadata.size || 0);
      if (!["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(mimeType) ||
          !Number.isFinite(fileSize) || fileSize <= 0 || fileSize > 10 * 1024 * 1024) {
        const cleanup = await sb.storage.from("employee-documents").remove([evidencePath]);
        if (cleanup.error) console.warn("[Buyer] Invalid supplier-return evidence cleanup failed", cleanup.error);
        throw new Error("BUYER_GOODS_RETURN_EVIDENCE_INVALID");
      }

      ({ data, error } = await profileClient.rpc("buyer_goods_custody_register_quick_market_supplier_return_atomi", {
        p_company_id: companyId, p_invoice_id: invoiceId, p_items: p.items || [],
        p_evidence_path: evidencePath, p_reason: p.reason || null, p_operation_id: operationId
      }));

      if (error) {
        const { data: verify, error: verifyError } = await profileClient.rpc("buyer_goods_custody_get_invoice_handover_progress_atomic", {
          p_company_id: companyId, p_invoice_id: invoiceId
        });
        if (!verifyError) {
          const exactCommit = (verify?.return_events || []).some((event: any) =>
            event.operation_id === operationId && event.evidence_path === evidencePath
          );
          if (exactCommit) {
            data = { success: true, duplicate: true, operation_id: operationId };
            error = null;
          } else {
            const cleanup = await sb.storage.from("employee-documents").remove([evidencePath]);
            if (cleanup.error) console.warn("[Buyer] Uncommitted supplier-return evidence cleanup failed", cleanup.error);
          }
        }
      }
    } else if (op === "GET_QUICK_MARKET_HANDOVER_PROGRESS") {
      ({ data, error } = await profileClient.rpc("buyer_goods_custody_get_invoice_handover_progress_atomic", {
        p_company_id: companyId, p_invoice_id: p.invoice_id
      }));
    } else if (op === "GET_BUYER_GOODS_CUSTODY_BALANCES") {
      ({ data, error } = await profileClient.rpc("buyer_goods_custody_get_balances_atomic", {
        p_company_id: companyId, p_custodian_user_id: p.custodian_user_id || profile.id
      }));
    } else if (op === "DELETE_QUICK_MARKET_DRAFT") {
      ({ data, error } = await profileClient.rpc("purchase_delete_quick_market_draft_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_actor: user.email,
        p_reason: p.reason || null, p_operation_id: operationId
      }));
    } else if (op === "REGISTER_QUICK_MARKET_ATTACHMENT") {
      const invoiceId = String(p.invoice_id || "").trim();
      const storagePath = String(p.storage_path || "").trim();
      const fileName = String(p.file_name || "").trim().slice(0, 255);
      const uploadedBy = String(user.email || "").trim();
      if (!invoiceId || !storagePath || !fileName || !uploadedBy) throw new Error("QUICK_MARKET_ATTACHMENT_INPUT_REQUIRED");
      const { data: invoice, error: invoiceError } = await sb.from("purchase_invoices")
        .select("id,purchase_source,purchaser_user_id,status,is_received,received_date")
        .eq("id", invoiceId).eq("company_id", companyId).maybeSingle();
      if (invoiceError) throw invoiceError;
      if (!invoice || invoice.purchase_source !== "QUICK_MARKET" || invoice.status !== "Draft" ||
          invoice.is_received === true || invoice.received_date) {
        throw new Error("QUICK_MARKET_ATTACHMENT_INVOICE_NOT_EDITABLE");
      }
      if (!isOwner && invoice.purchaser_user_id !== profile.id) {
        throw new Error("QUICK_MARKET_ATTACHMENT_OWNER_REQUIRED");
      }
      const pathParts = storagePath.split("/");
      if (pathParts.length !== 5 || pathParts[0] !== companyId || pathParts[1] !== profile.id ||
          pathParts[2] !== "buyer-goods" || pathParts[3] !== invoiceId ||
          !/^[A-Za-z0-9._-]{1,180}$/.test(pathParts[4])) {
        throw new Error("QUICK_MARKET_ATTACHMENT_PATH_INVALID");
      }
      const { data: storedObject, error: storedObjectError } = await sb.storage
        .from("employee-documents").info(storagePath);
      if (storedObjectError) throw storedObjectError;
      if (!storedObject) throw new Error("QUICK_MARKET_ATTACHMENT_OBJECT_NOT_FOUND");
      const objectMetadata = storedObject.metadata || {};
      const mimeType = String(storedObject.mimetype || storedObject.contentType || objectMetadata.mimetype || "").trim().toLowerCase();
      const fileSize = Number(storedObject.size || objectMetadata.size || 0);
      if (!["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(mimeType)) {
        throw new Error("QUICK_MARKET_ATTACHMENT_MIME_INVALID");
      }
      if (!Number.isFinite(fileSize) || fileSize <= 0 || fileSize > 10 * 1024 * 1024) {
        throw new Error("QUICK_MARKET_ATTACHMENT_SIZE_INVALID");
      }
      const attachmentFilter = sb.from("purchase_attachments").select("id")
        .eq("company_id", companyId).eq("document_type", "PurchaseInvoice")
        .eq("document_id", invoiceId).eq("storage_path", storagePath);
      const { data: existingAttachment, error: existingAttachmentError } = await attachmentFilter.maybeSingle();
      if (existingAttachmentError) throw existingAttachmentError;
      const attachmentValues = {
        file_name: fileName,
        file_url: null,
        mime_type: mimeType,
        uploaded_by: uploadedBy
      };
      if (existingAttachment) {
        const { data: updatedAttachment, error: updateAttachmentError } = await sb.from("purchase_attachments")
          .update(attachmentValues).eq("id", existingAttachment.id)
          .select("id,document_type,document_id,file_name,storage_path,mime_type,uploaded_by,created_at").single();
        if (updateAttachmentError) throw updateAttachmentError;
        data = { success: true, attachment: updatedAttachment, duplicate: true };
      } else {
        const { data: createdAttachment, error: createAttachmentError } = await sb.from("purchase_attachments")
          .insert({
            company_id: companyId,
            document_type: "PurchaseInvoice",
            document_id: invoiceId,
            file_name: fileName,
            storage_path: storagePath,
            file_url: null,
            mime_type: mimeType,
            uploaded_by: uploadedBy
          })
          .select("id,document_type,document_id,file_name,storage_path,mime_type,uploaded_by,created_at").single();
        if (createAttachmentError) {
          if (createAttachmentError.code !== "23505") throw createAttachmentError;
          const { data: racedAttachment, error: raceReadError } = await sb.from("purchase_attachments")
            .select("id").eq("company_id", companyId).eq("document_type", "PurchaseInvoice")
            .eq("document_id", invoiceId).eq("storage_path", storagePath).maybeSingle();
          if (raceReadError || !racedAttachment) throw createAttachmentError;
          const { data: updatedAttachment, error: updateAttachmentError } = await sb.from("purchase_attachments")
            .update(attachmentValues).eq("id", racedAttachment.id)
            .select("id,document_type,document_id,file_name,storage_path,mime_type,uploaded_by,created_at").single();
          if (updateAttachmentError) throw updateAttachmentError;
          data = { success: true, attachment: updatedAttachment, duplicate: true };
        } else {
          data = { success: true, attachment: createdAttachment, duplicate: false };
        }
      }
    } else if (op === "UPDATE_BUYER_LEGACY_DRAFT") {
      ({ data, error } = await profileClient.rpc("purchase_update_buyer_legacy_draft_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id || null, p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null, p_currency: await getSystemCurrency(),
        p_actor: user.email, p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null, p_items: p.items || [], p_operation_id: operationId
      }));
    } else if (op === "DELETE_BUYER_DRAFT_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_delete_buyer_draft_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_actor: user.email,
        p_reason: p.reason || null, p_operation_id: operationId
      }));
    } else if (op === "CREATE_INVOICE") {
      ({ data, error } = await call("purchase_create_invoice_atomic_v2", {
        p_company_id: companyId,
        p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id || null,
        p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null,
        p_currency: await getSystemCurrency(),
        p_created_by: user.email,
        p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "UPDATE_DRAFT_INVOICE") {
      ({ data, error } = await call("purchase_update_draft_invoice_atomic", {
        p_company_id: companyId,
        p_invoice_id: p.id,
        p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id || null,
        p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null,
        p_currency: await getSystemCurrency(),
        p_actor: user.email,
        p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "DELETE_DRAFT_INVOICE") {
      const { data: invoice, error: invoiceError } = await sb.from("purchase_invoices")
        .select("id,purchase_source,purchaser_user_id,created_by,status,is_received,received_date")
        .eq("id", p.id).eq("company_id", companyId).maybeSingle();
      if (invoiceError) throw invoiceError;
      if (!invoice || !["PURCHASE_ORDER", "LEGACY_UNCLASSIFIED"].includes(String(invoice.purchase_source || ""))) {
        throw new Error("PURCHASE_DRAFT_DELETE_SOURCE_NOT_SUPPORTED");
      }
      if (!isOwner) {
        const ownsInvoice = invoice.purchase_source === "PURCHASE_ORDER"
          ? invoice.purchaser_user_id === profile.id
          : String(invoice.created_by || "").toLowerCase() === String(user.email).toLowerCase();
        if (!ownsInvoice) throw new Error("BUYER_INVOICE_NOT_OWNED_BY_CURRENT_USER");
      }
      const { count: goodsEvents, error: goodsError } = await sb.from("buyer_goods_custody_events")
        .select("id", { count: "exact", head: true })
        .eq("company_id", companyId)
        .eq("source_document_type", "PurchaseInvoice")
        .eq("source_document_id", p.id);
      if (goodsError) throw goodsError;
      if ((goodsEvents || 0) > 0) throw new Error("INVOICE_HAS_GOODS_CUSTODY_EVENTS");
      ({ data, error } = await call("purchase_delete_draft_invoice_atomic", {
        p_company_id: companyId,
        p_invoice_id: p.id,
        p_actor: user.email,
        p_reason: p.reason || null,
        p_operation_id: operationId
      }));
    } else if (op === "POST_INVOICE") {
      ({ data, error } = await profileClient.rpc("purchase_post_buyer_invoice_atomic", {
        p_company_id: companyId, p_invoice_id: p.id, p_actor: user.email
      }));
    } else if (op === "RECEIVE_PO") {
      ({ data, error } = await call("receive_purchase_atomic", {
        p_company_id: companyId,
        p_po_code: p.po_code,
        p_user_email: user.email,
        p_items: p.items || [],
        p_operation_id: p.operation_id || operationId
      }));
    } else if (op === "CREATE_RETURN") {
      ({ data, error } = await call("purchase_create_return_atomic", {
        p_company_id: companyId,
        p_invoice_id: p.invoice_id,
        p_created_by: user.email,
        p_reason: p.reason || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "POST_RETURN") {
      ({ data, error } = await call("purchase_post_return_atomic", {
        p_company_id: companyId,
        p_return_id: p.id,
        p_actor: user.email
      }));
    } else if (op === "POST_PAYMENT") {
      ({ data, error } = await call("purchase_post_payment_atomic", {
        p_company_id: companyId,
        p_supplier_id: p.supplier_id,
        p_treasury_id: p.treasury_id,
        p_amount: Number(p.amount || 0),
        p_entry_date: p.entry_date || new Date().toISOString().slice(0, 10),
        p_reference: p.reference || null,
        p_actor: user.email,
        p_invoice_ids: p.invoice_ids || [],
        p_operation_id: p.operation_id ? String(p.operation_id) : crypto.randomUUID()
      }));
    } else if (op === "CANCEL_DOCUMENT") {
      ({ data, error } = await call("purchase_cancel_document_atomic", {
        p_company_id: companyId,
        p_document_type: p.document_type,
        p_document_id: p.document_id,
        p_actor: user.email,
        p_reason: p.reason || null
      }));
    } else if (op === "GET_SUMMARY") {
      // Preserve the authenticated caller JWT: purchase_get_dashboard validates auth.uid(),
      // company scope and effective permissions. Do not invoke it through service_role.
      ({ data, error } = await profileClient.rpc("purchase_get_dashboard", {
        p_company_id: companyId
      }));
    } else if (op === "GET_REPORTS") {
      ({ data, error } = await call("purchase_get_reports", {
        p_company_id: companyId,
        p_as_of_date: p.as_of_date || new Date().toISOString().slice(0, 10)
      }));
    } else if (op === "SAVE_SETTINGS") {
      ({ data, error } = await call("purchase_set_settings_atomic", {
        p_company_id: companyId,
        p_actor: user.email,
        p_settings: p || {}
      }));
    } else if (op === "ISSUE_CUSTODY") {
      ({ data, error } = await profileClient.rpc("buyer_custody_issue_atomic", {
        p_company_id: companyId, p_employee_id: p.employee_id, p_branch_id: p.branch_id || null,
        p_treasury_id: p.treasury_id, p_purpose: p.purpose, p_currency: await getSystemCurrency(), p_amount: Number(p.amount || 0),
        p_issued_date: p.issued_date || new Date().toISOString().slice(0, 10),
        p_received_reference: p.received_reference || null, p_notes: p.notes || null,
        p_operation_id: operationId
      }));
    } else if (op === "ACKNOWLEDGE_CUSTODY") {
      ({ data, error } = await profileClient.rpc("buyer_custody_acknowledge_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id
      }));
    } else if (op === "ADD_CUSTODY_ADVANCE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_add_advance_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id, p_treasury_id: p.treasury_id, p_amount: Number(p.amount || 0),
        p_advance_date: p.advance_date || new Date().toISOString().slice(0, 10),
        p_reference: p.reference || null, p_notes: p.notes || null, p_operation_id: operationId
      }));
    } else if (op === "ACKNOWLEDGE_CUSTODY_ADVANCE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_acknowledge_advance_atomic", {
        p_company_id: companyId, p_advance_id: p.advance_id
      }));
    } else if (op === "SUBMIT_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_submit_expense_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id,
        p_expense_date: p.expense_date || new Date().toISOString().slice(0, 10),
        p_supplier_name: p.supplier_name || null, p_invoice_number: p.invoice_number || null,
        p_description: p.description, p_amount: Number(p.amount || 0), p_currency: await getSystemCurrency(),
        p_document_name: p.document_name, p_document_path: p.document_path,
        p_mime_type: p.mime_type || null, p_supplier_id: p.supplier_id,
        p_purchase_invoice_id: p.purchase_invoice_id, p_receiving_operation_id: p.receiving_operation_id,
        p_receipt_document_name: p.receipt_document_name, p_receipt_document_path: p.receipt_document_path,
        p_receipt_mime_type: p.receipt_mime_type || null, p_operation_id: operationId
      }));
    } else if (op === "SUBMIT_QUICK_MARKET_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_submit_quick_market_expense_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id,
        p_expense_date: p.expense_date || new Date().toISOString().slice(0, 10),
        p_supplier_name: p.supplier_name || null, p_invoice_number: p.invoice_number || null,
        p_description: p.description, p_amount: Number(p.amount || 0), p_currency: await getSystemCurrency(),
        p_document_name: p.document_name, p_document_path: p.document_path,
        p_mime_type: p.mime_type || null, p_supplier_id: p.supplier_id,
        p_purchase_invoice_id: p.purchase_invoice_id, p_receiving_operation_id: p.receiving_operation_id,
        p_receipt_document_name: p.receipt_document_name, p_receipt_document_path: p.receipt_document_path,
        p_receipt_mime_type: p.receipt_mime_type || null, p_operation_id: operationId
      }));
    } else if (op === "SUBMIT_OTHER_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_submit_other_expense_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id,
        p_expense_date: p.expense_date || new Date().toISOString().slice(0, 10),
        p_expense_category: p.expense_category,
        p_expense_reference: p.expense_reference || null,
        p_description: p.description, p_amount: Number(p.amount || 0),
        p_currency: await getSystemCurrency(),
        p_document_name: p.document_name, p_document_path: p.document_path,
        p_mime_type: p.mime_type || null, p_operation_id: operationId
      }));
    } else if (op === "VERIFY_CUSTODY_EXPENSE_OPERATION") {
      const check = await sb.from("buyer_custody_expenses")
        .select("id,custody_id,employee_id,status,expense_type")
        .eq("company_id", companyId).eq("custody_id", p.custody_id)
        .eq("operation_id", String(p.operation_id || operationId)).maybeSingle();
      if (check.error) throw check.error;
      if (check.data && !isOwner && !hasPermission("finance") && !hasPermission("finance_manager")
          && check.data.employee_id !== profile.id) {
        throw new Error("CUSTODY_EXPENSE_NOT_FOUND_OR_FORBIDDEN");
      }
      data = { success: true, committed: !!check.data, status: check.data?.status || null,
        expense_type: check.data?.expense_type || null };
    } else if (op === "REVIEW_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_review_expense_atomic", {
        p_company_id: companyId, p_expense_id: p.expense_id,
        p_decision: p.decision, p_review_note: p.review_note || null
      }));
    } else if (op === "REVIEW_QUICK_MARKET_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_review_quick_market_expense_atomic", {
        p_company_id: companyId, p_expense_id: p.expense_id,
        p_decision: p.decision, p_review_note: p.review_note || null
      }));
    } else if (op === "REVIEW_OTHER_CUSTODY_EXPENSE") {
      ({ data, error } = await profileClient.rpc("buyer_custody_review_other_expense_atomic", {
        p_company_id: companyId, p_expense_id: p.expense_id,
        p_decision: p.decision, p_expense_account_id: p.expense_account_id || null,
        p_review_note: p.review_note || null
      }));
    } else if (op === "GET_OTHER_CUSTODY_EXPENSE_ACCOUNTS") {
      const accounts = await sb.from("chart_of_accounts")
        .select("id,account_code,account_name,parent_account_id,account_type,is_active")
        .eq("company_id", companyId).eq("account_type", "expense").eq("is_active", true)
        .order("account_code").limit(500);
      if (accounts.error) throw accounts.error;
      const all = accounts.data || [];
      const parentIds = new Set(all.map((x: any) => x.parent_account_id).filter(Boolean));
      data = { success: true, accounts: all.filter((x: any) =>
        !parentIds.has(x.id) && !["5","51","52"].includes(String(x.account_code))
      ).map((x: any) => ({id:x.id,account_code:x.account_code,account_name:x.account_name})) };
    } else if (op === "SETTLE_CUSTODY") {
      ({ data, error } = await profileClient.rpc("buyer_custody_settle_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id, p_treasury_id: p.treasury_id || null,
        p_cash_returned: Number(p.cash_returned || 0),
        p_finance_reference: p.finance_reference || null, p_notes: p.notes || null
      }));
    } else if (op === "RETURN_CUSTODY_CASH") {
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(operationId)) {
        throw new Error("CUSTODY_RETURN_OPERATION_ID_INVALID");
      }
      ({ data, error } = await profileClient.rpc("buyer_custody_return_cash_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id, p_treasury_id: p.treasury_id,
        p_amount: Number(p.amount || 0), p_return_date: p.return_date || new Date().toISOString().slice(0, 10),
        p_reference: p.reference || null, p_notes: p.notes || null, p_operation_id: operationId
      }));
    } else if (op === "UPDATE_CUSTODY") {
      ({ data, error } = await profileClient.rpc("buyer_custody_update_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id,
        p_employee_id: p.employee_id, p_branch_id: p.branch_id, p_treasury_id: p.treasury_id,
        p_purpose: p.purpose, p_amount: Number(p.amount || 0), p_issued_date: p.issued_date,
        p_received_reference: p.received_reference || null, p_notes: p.notes || null,
        p_reason: p.reason, p_operation_id: operationId
      }));
    } else if (op === "CANCEL_CUSTODY") {
      ({ data, error } = await profileClient.rpc("buyer_custody_cancel_atomic", {
        p_company_id: companyId, p_custody_id: p.custody_id,
        p_reason: p.reason, p_operation_id: operationId
      }));
    } else if (op === "GET_CUSTODY") {
      const financeView = hasPermission("finance") || hasPermission("finance_manager");
      const registerMode = p.register === true;
      if (registerMode && !financeView) throw new Error("صلاحية متابعة العهد المالية مطلوبة");

      const requestedOffset = p.offset == null ? 0 : Number(p.offset);
      if (!Number.isSafeInteger(requestedOffset) || requestedOffset < 0) {
        throw new Error("رقم صفحة العهد غير صالح");
      }
      const requestedPageSize = Number(p.page_size || 50);
      const pageSize = [25, 50, 100, 200].includes(requestedPageSize) ? requestedPageSize : 50;
      const dateFrom = String(p.date_from || "").trim();
      const dateTo = String(p.date_to || "").trim();
      if ((dateFrom && !/^\d{4}-\d{2}-\d{2}$/.test(dateFrom)) ||
          (dateTo && !/^\d{4}-\d{2}-\d{2}$/.test(dateTo))) {
        throw new Error("صيغة تاريخ البحث غير صحيحة");
      }
      if (dateFrom && dateTo && dateFrom > dateTo) {
        throw new Error("تاريخ البداية يجب ألا يتجاوز تاريخ النهاية");
      }
      const employeeFilter = String(p.employee_id || "").trim();
      if (employeeFilter && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(employeeFilter)) {
        throw new Error("اختيار الموظف غير صالح");
      }
      const searchText = String(p.search || "").trim().slice(0, 120)
        .replace(/[^\p{L}\p{N}\s@._-]/gu, " ").replace(/\s+/g, " ").trim();

      // Range pagination is used only to transfer bounded pages. It never caps
      // the number of custody or child records available in the archive.
      const fetchAllRows = async (queryFactory: () => any) => {
        const rows: any[] = [];
        let offset = 0;
        let exactCount: number | null = null;
        while (true) {
          const result = await queryFactory().range(offset, offset + 499);
          if (result.error) throw result.error;
          if (exactCount === null && typeof result.count === "number") exactCount = result.count;
          const pageRows = result.data || [];
          if (!pageRows.length) {
            if (exactCount !== null && offset < exactCount) {
              throw new Error("تعذر استكمال قراءة سجل العهد؛ أعد المحاولة");
            }
            break;
          }
          rows.push(...pageRows);
          offset += pageRows.length;
          if (exactCount !== null && offset >= exactCount) break;
        }
        return rows;
      };

      let employeeRows: any[] = [];
      if (financeView) {
        employeeRows = await fetchAllRows(() => sb.from("users")
          .select("id,name,email,employee_id,default_branch_id,allowed_branch_ids,status", { count: "exact" })
          .eq("company_id", companyId).order("name", { ascending: true }).order("id", { ascending: true }));
      }

      let matchingEmployeeIds: string[] = [];
      if (registerMode && searchText) {
        const employeeMatches = await fetchAllRows(() => sb.from("users")
          .select("id", { count: "exact" }).eq("company_id", companyId)
          .or('name.ilike."%' + searchText + '%",email.ilike."%' + searchText + '%",employee_id.ilike."%' + searchText + '%"')
          .order("id", { ascending: true }));
        matchingEmployeeIds = Array.from(new Set(employeeMatches.map((row: any) => String(row.id)).filter(Boolean)));
      }

      const buildCustodyQuery = () => {
        let query = sb.from("buyer_custodies").select("*", { count: "exact" }).eq("company_id", companyId);
        if (!financeView) query = query.eq("employee_id", profile.id);
        if (employeeFilter) query = query.eq("employee_id", employeeFilter);
        if (dateFrom) query = query.gte("issued_date", dateFrom);
        if (dateTo) query = query.lte("issued_date", dateTo);
        if (registerMode && searchText) {
          const terms = [
            'custody_code.ilike."%' + searchText + '%"',
            'purpose.ilike."%' + searchText + '%"',
            'notes.ilike."%' + searchText + '%"',
            'received_reference.ilike."%' + searchText + '%"'
          ];
          if (matchingEmployeeIds.length) terms.push("employee_id.in.(" + matchingEmployeeIds.join(",") + ")");
          query = query.or(terms.join(","));
        }
        return query.order("issued_date", { ascending: false })
          .order("created_at", { ascending: false }).order("id", { ascending: false });
      };

      let custodyRows: any[] = [];
      let totalCount = 0;
      let offset = 0;
      let returnedPageSize = 0;
      let page = 0;
      if (registerMode) {
        offset = requestedOffset;
        returnedPageSize = pageSize;
        page = Math.floor(offset / pageSize);
        const custodyResult = await buildCustodyQuery().range(offset, offset + pageSize - 1);
        if (custodyResult.error) throw custodyResult.error;
        custodyRows = custodyResult.data || [];
        totalCount = Number(custodyResult.count || 0);
      } else {
        // Backward-compatible Buyer/employee payload: fetch every authorized
        // custody row, not an arbitrary first-200 slice.
        custodyRows = await fetchAllRows(buildCustodyQuery);
        totalCount = custodyRows.length;
        returnedPageSize = totalCount;
      }

      const custodyIds = custodyRows.map((row: any) => row.id).filter(Boolean);
      const loadChildRows = async (table: string, orderColumn: string) => {
        const rows: any[] = [];
        // Chunk the parent IDs to avoid oversized IN expressions, then page
        // every chunk until its exact count is exhausted.
        for (let i = 0; i < custodyIds.length; i += 75) {
          const ids = custodyIds.slice(i, i + 75);
          const chunkRows = await fetchAllRows(() => sb.from(table).select("*", { count: "exact" })
            .eq("company_id", companyId).in("custody_id", ids)
            .order(orderColumn, { ascending: false }).order("id", { ascending: false }));
          rows.push(...chunkRows);
        }
        return rows;
      };

      let expenseRows: any[] = [];
      let settlementRows: any[] = [];
      let advanceRows: any[] = [];
      let paymentRows: any[] = [];
      let returnRows: any[] = [];
      if (custodyIds.length) {
        [expenseRows, settlementRows, advanceRows, paymentRows, returnRows] = await Promise.all([
          loadChildRows("buyer_custody_expenses", "expense_date"),
          loadChildRows("buyer_custody_settlements", "recorded_at"),
          loadChildRows("buyer_custody_advances", "advance_date"),
          loadChildRows("buyer_custody_payments", "payment_date"),
          loadChildRows("buyer_custody_returns", "return_date")
        ]);
      }

      const linkedInvoiceRows: any[] = [];
      for (let i = 0; i < custodyIds.length; i += 75) {
        const ids = custodyIds.slice(i, i + 75);
        const invoices = await fetchAllRows(() => sb.from("purchase_invoices")
          .select("id,cash_custody_id", { count: "exact" })
          .eq("company_id", companyId).in("cash_custody_id", ids)
          .order("id", { ascending: true }));
        linkedInvoiceRows.push(...invoices);
      }

      // Audit data is returned only through a permission-checked, caller-JWT RPC.
      // Never use the service-role client to read the protected audit_log table.
      const cancelAuditRows: any[] = [];
      if (custodyIds.length) {
        const cancellationResult = await profileClient.rpc("buyer_custody_cancellation_audit_read", {
          p_company_id: companyId,
          p_custody_ids: custodyIds
        });
        if (cancellationResult.error) throw cancellationResult.error;
        cancelAuditRows.push(...(cancellationResult.data || []));
      }

      const employeeNames = new Map(employeeRows.map((row: any) => [row.id, row.name]));
      const advancesByCustody = new Map<string, any[]>();
      const expensesByCustody = new Set(expenseRows.map((row: any) => String(row.custody_id)));
      const paymentsByCustody = new Set(paymentRows.map((row: any) => String(row.custody_id)));
      const settlementsByCustody = new Set(settlementRows.map((row: any) => String(row.custody_id)));
      const invoicesByCustody = new Set(linkedInvoiceRows.map((row: any) => String(row.cash_custody_id)));
      const cancellationByCustody = new Map<string, any>();
      for (const row of advanceRows) {
        const key = String(row.custody_id);
        if (!advancesByCustody.has(key)) advancesByCustody.set(key, []);
        advancesByCustody.get(key)!.push(row);
      }
      for (const row of cancelAuditRows) {
        const key = String(row.custody_id);
        if (!cancellationByCustody.has(key)) cancellationByCustody.set(key, row);
      }
      for (const custody of custodyRows) {
        const key = String(custody.id);
        const custodyAdvances = advancesByCustody.get(key) || [];
        const initialOnly = custodyAdvances.length === 1
          && custodyAdvances[0].advance_type === "Initial"
          && !custodyAdvances[0].acknowledged_at
          && !custodyAdvances[0].cash_box_id
          && !custodyAdvances[0].journal_entry_id;
        const actionSafe = financeView
          && custody.status === "Issued"
          && !custody.acknowledged_at
          && !custody.received_at
          && initialOnly
          && !expensesByCustody.has(key)
          && !paymentsByCustody.has(key)
          && !settlementsByCustody.has(key)
          && !invoicesByCustody.has(key);
        custody.can_edit = actionSafe;
        custody.can_cancel = actionSafe;
        const cancellation = cancellationByCustody.get(key);
        if (cancellation) {
          custody.cancellation_reason = cancellation.cancellation_reason || null;
          custody.cancelled_by = cancellation.cancelled_by || null;
          custody.cancelled_at = cancellation.cancelled_at || null;
        }
        custody.employee_name = employeeNames.get(custody.employee_id) ||
          (custody.employee_id === profile.id ? profile.name : "موظف");
      }
      data = {
        success: true,
        custodies: custodyRows,
        expenses: expenseRows,
        advances: advanceRows,
        payments: paymentRows,
        settlements: settlementRows,
        returns: returnRows,
        employees: employeeRows,
        is_finance: financeView,
        total_count: totalCount,
        offset,
        page_size: returnedPageSize,
        page,
        register_mode: registerMode,
        filters: { date_from: dateFrom || null, date_to: dateTo || null, employee_id: employeeFilter || null, search: searchText || null }
      };
    } else if (op === "GET_SETTINGS") {
      data = { success: true, currency: await getSystemCurrency() };
    } else if (op === "GET_DATA") {
      const table = String(p.table || "");
      if (table === "treasury") requireAny(["finance", "finance_manager"]);
      const allowed = [
        "purchase_requests",
        "purchase_request_details",
        "purchase_rfqs",
        "purchase_rfq_details",
        "purchase_rfq_suppliers",
        "purchase_quotations",
        "purchase_quotation_details",
        "purchase_orders",
        "purchase_order_details",
        "purchase_invoices",
        "purchase_invoice_details",
        "purchase_returns",
        "purchase_return_details",
        "purchase_payments",
        "purchase_payment_allocations",
        "purchase_supplier_balance",
        "purchase_invoice_aging",
        "purchase_quotation_comparison",
        "purchase_status_history",
        "purchase_attachments",
        "purchase_document_links",
        "purchase_settings",
        "fleet_vehicle_assignments",
        "vehicles",
        "receiving",
        "receiving_details",
        "treasury",
        "stock_branches",
        "suppliers",
        "items",
        "branches"
      ];
      if (!allowed.includes(table)) throw new Error("جدول غير مدعوم");
      const detailScope: Record<string, { parent: string; foreignKey: string }> = {
        purchase_request_details: { parent: "purchase_requests", foreignKey: "request_id" },
        purchase_rfq_details: { parent: "purchase_rfqs", foreignKey: "rfq_id" },
        purchase_rfq_suppliers: { parent: "purchase_rfqs", foreignKey: "rfq_id" },
        purchase_quotation_details: { parent: "purchase_quotations", foreignKey: "quotation_id" },
        purchase_order_details: { parent: "purchase_orders", foreignKey: "po_id" },
        purchase_invoice_details: { parent: "purchase_invoices", foreignKey: "invoice_id" },
        purchase_return_details: { parent: "purchase_returns", foreignKey: "return_id" },
        stock_branches: { parent: "branches", foreignKey: "branch_id" }
      };
      const rowLimit = Math.min(Number(p.limit || 300), 500);
      const canViewAllInvoices = isOwner || hasPermission("finance") || hasPermission("finance_manager");
      const getVisibleInvoiceIds = async () => {
        if (canViewAllInvoices) {
          const all = await sb.from("purchase_invoices").select("id")
            .eq("company_id", companyId).limit(500);
          if (all.error) throw all.error;
          return (all.data || []).map((x: any) => x.id).filter(Boolean);
        }
        const [byPurchaser, byCreator] = await Promise.all([
          sb.from("purchase_invoices").select("id").eq("company_id", companyId)
            .eq("purchaser_user_id", profile.id).limit(500),
          sb.from("purchase_invoices").select("id").eq("company_id", companyId)
            .eq("created_by", user.email).limit(500)
        ]);
        if (byPurchaser.error) throw byPurchaser.error;
        if (byCreator.error) throw byCreator.error;
        return Array.from(new Set([...(byPurchaser.data || []), ...(byCreator.data || [])]
          .map((x: any) => x.id).filter(Boolean)));
      };
      const getVisibleReceivingRows = async () => {
        const invoiceIds = await getVisibleInvoiceIds();
        if (!invoiceIds.length) return [];
        const invoiceRows = await sb.from("purchase_invoices").select("purchase_order_id")
          .eq("company_id", companyId).in("id", invoiceIds).limit(500);
        if (invoiceRows.error) throw invoiceRows.error;
        const poIds = Array.from(new Set((invoiceRows.data || []).map((x: any) => x.purchase_order_id).filter(Boolean)));
        let poCodes: string[] = [];
        if (poIds.length) {
          const poRows = await sb.from("purchase_orders").select("po_code")
            .eq("company_id", companyId).in("id", poIds).limit(500);
          if (poRows.error) throw poRows.error;
          poCodes = Array.from(new Set((poRows.data || []).map((x: any) => x.po_code).filter(Boolean)));
        }
        const byInvoice = await sb.from("receiving").select("*")
          .eq("company_id", companyId).in("purchase_invoice_id", invoiceIds).limit(500);
        if (byInvoice.error) throw byInvoice.error;
        let byPo: any = { data: [], error: null };
        if (poCodes.length) {
          byPo = await sb.from("receiving").select("*")
            .eq("company_id", companyId).in("po_number", poCodes).limit(500);
          if (byPo.error) throw byPo.error;
        }
        const merged = new Map<string, any>();
        for (const row of [...(byInvoice.data || []), ...(byPo.data || [])]) {
          merged.set(String(row.operation_id || row.id), row);
        }
        return Array.from(merged.values())
          .sort((a: any, b: any) => String(b.date || "").localeCompare(String(a.date || "")))
          .slice(0, rowLimit);
      };
      let r: any;
      if (table === "fleet_vehicle_assignments") {
        r = await sb.from(table).select("*").eq("company_id", companyId)
          .eq("driver_user_id", profile.id).order("start_at", { ascending: false }).limit(rowLimit);
        if (r.error) throw r.error;
        data = { success: true, items: r.data || [], table };
      } else if (table === "vehicles" && hasPermission("purchases")) {
        r = await sb.from("vehicles").select("*").eq("company_id", companyId)
          .order("plate_number", { ascending: true }).limit(rowLimit);
        if (r.error) throw r.error;
        data = { success: true, items: r.data || [], table };
      } else if (table === "vehicles") {
        const assignmentResult = await sb.from("fleet_vehicle_assignments").select("vehicle_id")
          .eq("company_id", companyId).eq("driver_user_id", profile.id).limit(100);
        if (assignmentResult.error) throw assignmentResult.error;
        const assignedVehicleIds = (assignmentResult.data || []).map((row: any) => row.vehicle_id).filter(Boolean);
        if (!assignedVehicleIds.length) {
          data = { success: true, items: [], table };
        } else {
          r = await sb.from("vehicles").select("*").eq("company_id", companyId)
            .in("id", assignedVehicleIds).limit(rowLimit);
          if (r.error) throw r.error;
          data = { success: true, items: r.data || [], table };
        }
      } else if (table === "purchase_invoices" && !canViewAllInvoices) {
        const [byPurchaser, byCreator] = await Promise.all([
          sb.from("purchase_invoices").select("*").eq("company_id", companyId)
            .eq("purchaser_user_id", profile.id).order("created_at", { ascending: false }).limit(rowLimit),
          sb.from("purchase_invoices").select("*").eq("company_id", companyId)
            .eq("created_by", user.email).order("created_at", { ascending: false }).limit(rowLimit)
        ]);
        if (byPurchaser.error) throw byPurchaser.error;
        if (byCreator.error) throw byCreator.error;
        const merged = new Map<string, any>();
        for (const row of [...(byPurchaser.data || []), ...(byCreator.data || [])]) merged.set(row.id, row);
        data = { success: true, items: Array.from(merged.values())
          .sort((a: any, b: any) => String(b.created_at || "").localeCompare(String(a.created_at || "")))
          .slice(0, rowLimit), table };
      } else if (table === "purchase_attachments" && !canViewAllInvoices) {
        const invoiceIds = await getVisibleInvoiceIds();
        if (!invoiceIds.length) data = { success: true, items: [], table };
        else {
          r = await sb.from("purchase_attachments").select("*").eq("company_id", companyId)
            .eq("document_type", "PurchaseInvoice").in("document_id", invoiceIds)
            .order("created_at", { ascending: false }).limit(rowLimit);
          if (r.error) throw r.error;
          data = { success: true, items: r.data || [], table };
        }
      } else if (table === "purchase_invoice_details" && !canViewAllInvoices) {
        const invoiceIds = await getVisibleInvoiceIds();
        if (!invoiceIds.length) data = { success: true, items: [], table };
        else {
          r = await sb.from("purchase_invoice_details").select("*")
            .in("invoice_id", invoiceIds).limit(rowLimit);
          if (r.error) throw r.error;
          data = { success: true, items: r.data || [], table };
        }
      } else if (table === "receiving" && !canViewAllInvoices) {
        data = { success: true, items: await getVisibleReceivingRows(), table };
      } else if (table === "receiving_details") {
        let operationIds: string[] = [];
        if (canViewAllInvoices) {
          const headers = await sb.from("receiving").select("operation_id")
            .eq("company_id", companyId).limit(500);
          if (headers.error) throw headers.error;
          operationIds = Array.from(new Set((headers.data || []).map((x: any) => x.operation_id).filter(Boolean)));
        } else {
          const headers = await getVisibleReceivingRows();
          operationIds = Array.from(new Set(headers.map((x: any) => x.operation_id).filter(Boolean)));
        }
        if (!operationIds.length) data = { success: true, items: [], table };
        else {
          r = await sb.from("receiving_details").select("*")
            .in("operation_id", operationIds).limit(rowLimit);
          if (r.error) throw r.error;
          data = { success: true, items: r.data || [], table };
        }
      } else if (detailScope[table]) {
        const scope = detailScope[table];
        const parents = await sb.from(scope.parent).select("id").eq("company_id", companyId).limit(500);
        if (parents.error) throw parents.error;
        const parentIds = (parents.data || []).map((row: any) => row.id).filter(Boolean);
        if (!parentIds.length) {
          data = { success: true, items: [], table };
        } else {
          r = await sb.from(table).select("*").in(scope.foreignKey, parentIds).limit(rowLimit);
          if (r.error) throw r.error;
          data = { success: true, items: r.data || [], table };
        }
      } else {
        r = await sb.from(table).select("*").eq("company_id", companyId).limit(rowLimit);
        if (r.error) throw r.error;
        data = { success: true, items: r.data || [], table };
      }
    } else {
      throw new Error("عملية مشتريات غير مدعومة: " + op);
    }

    if (error) throw new Error(error.message || "فشل التنفيذ");

    const result = (data && typeof data === "object") ? data : { data };
    return new Response(
      JSON.stringify(Object.assign({}, result, { operation: op, operation_id: operationId })),
      { status: 200, headers: cors }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ success: false, msg: e?.message || "فشل محرك المشتريات" }),
      { status: 400, headers: cors }
    );
  }
});