import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((entry) => String(entry || "").trim()).filter(Boolean);
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed.map((entry) => String(entry || "").trim()).filter(Boolean);
      if (typeof parsed === "string" && parsed.trim()) return [parsed.trim()];
    } catch {
      if (value.trim()) return [value.trim()];
    }
  }
  return [];
}

async function requireReturnsActor(authHeader: string): Promise<{ authUser: any; appUser: any; verifiedOwner: boolean }> {
  const token = String(authHeader || "").replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new Error("جلسة غير صالحة");

  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  const authUser = authData?.user;
  if (authError || !authUser?.id) throw new Error("جلسة غير صالحة");

  const { data: appUser, error: userError } = await supabase
    .from("users")
    .select("id,auth_id,company_id,status,email,permissions,role_id,active_warehouse_role,default_branch_id,allowed_branch_ids")
    .eq("auth_id", authUser.id)
    .maybeSingle();

  if (userError) throw new Error("فشل التحقق من ملف المستخدم: " + userError.message);
  if (!appUser?.id || !appUser?.company_id || appUser.auth_id !== authUser.id) {
    throw new Error("ملف المستخدم أو سياق الشركة غير متاح");
  }
  if (appUser.status && String(appUser.status).toLowerCase() !== "active") {
    throw new Error("المستخدم غير نشط");
  }

  const permissions = normalizeStringArray(appUser.permissions);
  if (appUser.role_id) {
    const { data: role, error: roleError } = await supabase
      .from("roles")
      .select("permissions")
      .eq("id", appUser.role_id)
      .eq("company_id", appUser.company_id)
      .maybeSingle();
    if (roleError) throw new Error("تعذر قراءة صلاحيات الدور: " + roleError.message);
    permissions.push(...normalizeStringArray(role?.permissions));

    const { data: permissionRows, error: permissionError } = await supabase
      .from("role_permissions")
      .select("permission_key")
      .eq("role_id", appUser.role_id);
    if (permissionError) throw new Error("تعذر قراءة صلاحيات الدور التفصيلية: " + permissionError.message);
    (permissionRows || []).forEach((row: any) => {
      if (row?.permission_key) permissions.push(String(row.permission_key));
    });
  }

  let verifiedOwner = false;
  const metadata = authUser.user_metadata || {};
  if (metadata.isOwner === true || metadata.isOwner === "true") {
    const { data: ownerProfile, error: ownerError } = await supabase
      .from("owner_profile")
      .select("auth_user_id")
      .eq("auth_user_id", authUser.id)
      .maybeSingle();
    if (ownerError) throw new Error("فشل التحقق من ملف المالك");
    verifiedOwner = permissions.includes("*") && ownerProfile?.auth_user_id === authUser.id;
  }

  if (!verifiedOwner && !permissions.includes("warehouse")) {
    throw new Error("ليس لديك صلاحية استخدام عمليات المخازن");
  }
  const activeRole = String(appUser.active_warehouse_role || "");
  if (!verifiedOwner && activeRole !== "مرتجعات" && activeRole !== "مخزن شامل") {
    throw new Error("الدور المخزني النشط لا يسمح بالإبلاغ عن اختلافات المرتجعات");
  }

  if (!verifiedOwner) {
    const { data: settings, error: settingsError } = await supabase
      .from("app_settings")
      .select("main_branch_id")
      .eq("company_id", appUser.company_id)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (settingsError) throw new Error("تعذر تحديد الفرع الرئيسي: " + settingsError.message);
    const mainBranchId = settings?.main_branch_id;
    if (!mainBranchId) throw new Error("الفرع الرئيسي غير محدد للشركة");

    const { data: branch, error: branchError } = await supabase
      .from("branches")
      .select("id,branch_code,is_active")
      .eq("id", mainBranchId)
      .eq("company_id", appUser.company_id)
      .maybeSingle();
    if (branchError) throw new Error("تعذر التحقق من الفرع الرئيسي: " + branchError.message);
    if (!branch || branch.is_active === false) throw new Error("الفرع الرئيسي غير نشط أو لا يتبع الشركة");

    const allowed = normalizeStringArray(appUser.allowed_branch_ids);
    const defaultBranchId = String(appUser.default_branch_id || "");
    const canUseMainBranch =
      defaultBranchId === String(branch.id) ||
      allowed.includes("*") ||
      allowed.includes(String(branch.id)) ||
      allowed.includes(String(branch.branch_code));
    if (!canUseMainBranch) throw new Error("الفرع الرئيسي خارج نطاق الفروع المسموح بها للمستخدم");
  }

  return { authUser, appUser, verifiedOwner };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return jsonResponse({ success: false, code: "METHOD_NOT_ALLOWED", msg: "طريقة الطلب غير مدعومة" }, 405);
  }

  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("صيغة JSON غير صالحة");

    const runsheetId = String(body.runsheet_id || "").trim();
    const itemCode = String(body.item_code || "").trim();
    const discrepancyType = String(body.discrepancy_type || "").trim();
    const notes = String(body.notes || "").trim();
    const actualRaw = body.actual_qty;

    if (!runsheetId) throw new Error("runsheet_id مطلوب");
    if (!itemCode) throw new Error("يجب اختيار صنف من تفاصيل الرانشيت");
    if (actualRaw === undefined || actualRaw === null || String(actualRaw).trim() === "") {
      throw new Error("الكمية الفعلية مطلوبة");
    }

    const actualQty = Number(actualRaw);
    if (!Number.isFinite(actualQty) || actualQty < 0) throw new Error("الكمية الفعلية يجب أن تكون رقمًا غير سالب");
    const validTypes = ["surplus", "shortage", "wrong_item", "other"];
    if (!validTypes.includes(discrepancyType)) throw new Error("نوع الاختلاف غير صحيح");
    if (discrepancyType === "other" && !notes) throw new Error("يرجى وصف الاختلاف الآخر");

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("غير مصرح");
    const actor = await requireReturnsActor(authHeader);
    const appUser = actor.appUser;

    const { data: runsheet, error: runsheetError } = await supabase
      .from("runsheets")
      .select("id,company_id,status,return_handler_id,runsheet_code")
      .eq("id", runsheetId)
      .eq("company_id", appUser.company_id)
      .maybeSingle();

    if (runsheetError) throw new Error("فشل التحقق من الرانشيت: " + runsheetError.message);
    if (!runsheet) throw new Error("الرانشيت غير موجود ضمن شركة المستخدم");
    if (runsheet.status !== "Returning") throw new Error("لا يمكن الإبلاغ إلا عن رانشيت قيد المرتجعات");
    if (runsheet.return_handler_id !== appUser.id) throw new Error("هذا الرانشيت غير مسند إلى المستخدم الحالي");

    const { data: detail, error: detailError } = await supabase
      .from("run_sheet_details")
      .select("id,item_code,item_name,qty_loaded,qty_delivered")
      .eq("runsheet_id", runsheet.id)
      .eq("item_code", itemCode)
      .maybeSingle();

    if (detailError) throw new Error("فشل قراءة تفاصيل الصنف: " + detailError.message);
    if (!detail?.item_code) throw new Error("الصنف غير موجود ضمن تفاصيل هذا الرانشيت");

    const expectedQty = Math.max(
      0,
      (Number(detail.qty_loaded) || 0) - (Number(detail.qty_delivered) || 0),
    );
    if (expectedQty <= 0) throw new Error("لا توجد كمية متبقية متوقعة لهذا الصنف");

    if (discrepancyType === "shortage" && actualQty >= expectedQty) {
      throw new Error("بلاغ النقص يتطلب كمية فعلية أقل من الكمية المتوقعة");
    }
    if (discrepancyType === "surplus" && actualQty <= expectedQty) {
      throw new Error("بلاغ الزيادة يتطلب كمية فعلية أكبر من الكمية المتوقعة");
    }

    let actualItemCode: string | null = null;
    let actualItemName: string | null = null;
    if (discrepancyType === "wrong_item") {
      const actualIdentifier = String(body.actual_item_code || "").trim();
      if (!actualIdentifier || actualQty <= 0) throw new Error("كود الصنف الموجود فعليًا والكمية الفعلية مطلوبان");
      let actualItem: any = null;
      const byCode = await supabase
        .from("items")
        .select("item_code,name")
        .eq("company_id", appUser.company_id)
        .eq("item_code", actualIdentifier)
        .maybeSingle();
      if (byCode.error) throw new Error("فشل التحقق من الصنف الفعلي: " + byCode.error.message);
      actualItem = byCode.data;
      if (!actualItem) {
        const byBarcode = await supabase
          .from("items")
          .select("item_code,name")
          .eq("company_id", appUser.company_id)
          .eq("barcode", actualIdentifier)
          .maybeSingle();
        if (byBarcode.error) throw new Error("فشل التحقق من باركود الصنف الفعلي: " + byBarcode.error.message);
        actualItem = byBarcode.data;
      }
      if (!actualItem?.item_code) throw new Error("الصنف الفعلي غير موجود في دليل أصناف الشركة");
      actualItemCode = String(actualItem.item_code);
      actualItemName = String(actualItem.name || actualItem.item_code);
      if (actualItemCode === detail.item_code) throw new Error("الباركود المدخل يعود إلى الصنف المتوقع نفسه");
    }

    const differenceQty = actualQty - expectedQty;
    const insertData = {
      runsheet_id: runsheet.id,
      company_id: appUser.company_id,
      item_code: detail.item_code,
      item_name: detail.item_name || detail.item_code,
      expected_qty: expectedQty,
      actual_qty: actualQty,
      difference_qty: differenceQty,
      discrepancy_type: discrepancyType,
      reported_by: appUser.id,
      status: "pending",
      notes: notes || null,
      expected_item_code: detail.item_code,
      expected_item_name: detail.item_name || detail.item_code,
      ...(actualItemCode ? { actual_item_code: actualItemCode } : {}),
      ...(actualItemName ? { actual_item_name: actualItemName } : {}),
    };

    const { data: inserted, error: insertError } = await supabase
      .from("stock_discrepancies")
      .insert(insertData)
      .select("id")
      .single();
    if (insertError) throw new Error("فشل حفظ بلاغ الاختلاف: " + insertError.message);

    const { error: auditError } = await supabase.from("audit_log").insert({
      user_email: appUser.email || actor.authUser.email,
      action: "report_discrepancy",
      table_name: "stock_discrepancies",
      record_id: inserted.id,
      new_data: insertData,
      ip_address: req.headers.get("x-forwarded-for") || null,
      user_agent: req.headers.get("user-agent") || null,
    });
    if (auditError) console.warn("[report-discrepancy] audit_log insert failed:", auditError.message);

    return jsonResponse({
      success: true,
      msg: "تم تسجيل بلاغ الاختلاف وإرساله للمراجعة",
      discrepancy_id: inserted.id,
      discrepancy_type: discrepancyType,
      expected_qty: expectedQty,
      actual_qty: actualQty,
      difference_qty: differenceQty,
    });
  } catch (error: any) {
    console.error("[report-discrepancy] request rejected:", error?.message || error);
    return jsonResponse({
      success: false,
      code: "RETURN_DISCREPANCY_REJECTED",
      msg: error?.message || "فشل تسجيل بلاغ الاختلاف",
    }, 400);
  }
});
