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
    const requireAny = (keys: string[]) => {
      if (!isOwner && !keys.some((key) => effectivePermissions.includes(key))) {
        throw new Error("لا تملك صلاحية تنفيذ عملية المشتريات المطلوبة");
      }
    };
    const requireAll = (keys: string[]) => {
      if (!isOwner && !keys.every((key) => effectivePermissions.includes(key))) {
        throw new Error("تتطلب هذه العملية صلاحيات المشتريات والمالية");
      }
    };

    if (op === "SAVE_SETTINGS") {
      requireAny(["purchases", "settings"]);
    } else if (["POST_INVOICE", "POST_PAYMENT", "POST_RETURN"].includes(op)) {
      requireAll(["purchases", "finance"]);
    } else if (op === "CANCEL_DOCUMENT" && ["PurchaseInvoice", "PurchasePayment", "PurchaseReturn"].includes(String(p.document_type || ""))) {
      requireAll(["purchases", "finance"]);
    } else if (op === "GET_SUMMARY" || op === "GET_REPORTS") {
      requireAny(["purchases", "finance", "reports"]);
    } else if (op === "SAVE_SUPPLIER") {
      ({ data, error } = await call("save_supplier_atomic", {
        p_auth_user_id: user.id,
        p_company_id: companyId,
        p_user_email: user.email,
        p_supplier: p.supplier || {},
        p_is_edit: p.is_edit === true,
        p_supplier_code: p.supplier_code || null
      }));
    } else if (op === "GET_DATA") {
      const table = String(p.table || "");
      if (table === "treasury") requireAny(["finance"]);
      else if (table === "suppliers") requireAny(["purchases", "suppliers"]);
      else requireAny(["purchases", "finance"]);
    } else if (op === "SAVE_SUPPLIER") {
      requireAny(["purchases", "suppliers"]);
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

    if (op === "CREATE_REQUEST") {
      ({ data, error } = await call("purchase_create_request_atomic", {
        p_company_id: companyId,
        p_title: p.title,
        p_required_by: p.required_by || null,
        p_requested_by: user.email,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
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
        p_currency: p.currency || "SAR",
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
    } else if (op === "CREATE_INVOICE") {
      ({ data, error } = await call("purchase_create_invoice_atomic_v2", {
        p_company_id: companyId,
        p_supplier_id: p.supplier_id,
        p_purchase_order_id: p.purchase_order_id || null,
        p_branch_id: p.branch_id || null,
        p_due_date: p.due_date || null,
        p_currency: p.currency || "SAR",
        p_created_by: user.email,
        p_supplier_invoice_no: p.supplier_invoice_no || null,
        p_notes: p.notes || null,
        p_items: p.items || [],
        p_operation_id: operationId
      }));
    } else if (op === "POST_INVOICE") {
      ({ data, error } = await call("purchase_post_invoice_atomic", {
        p_company_id: companyId,
        p_invoice_id: p.id,
        p_actor: user.email
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
      ({ data, error } = await call("purchase_get_dashboard", {
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
    } else if (op === "GET_DATA") {
      const table = String(p.table || "");
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
        "suppliers",
        "items",
        "branches",
        "treasury"
      ];
      if (!allowed.includes(table)) throw new Error("جدول غير مدعوم");
      const r = await sb.from(table).select("*").eq("company_id", companyId).limit(Math.min(Number(p.limit || 300), 500));
      if (r.error) throw r.error;
      data = { success: true, items: r.data || [], table };
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