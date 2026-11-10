// cancel-return — cancel only a fresh, uncommitted Returns session.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { requireWarehouseRole, assertWarehouseMainBranch } from "../_shared/warehouse-auth.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

serve(async (req) => {
  const origin = req.headers.get("Origin") || "*"
  const corsHeaders = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  }
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  try {
    if (req.method !== "POST") throw new Error("طريقة الطلب غير مدعومة")

    const body = await req.json().catch(() => ({}))
    const runsheetCode = String(body?.runsheet_code || "").trim()
    if (!runsheetCode) throw new Error("رقم الرانشيت مطلوب")

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")
    const warehouseActor = await requireWarehouseRole(supabase, authHeader, "مرتجعات");
    await assertWarehouseMainBranch(supabase, warehouseActor);
    const token = authHeader.replace(/^Bearer\s+/i, "").trim()
    if (!token) throw new Error("جلسة غير صالحة")

    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user?.id) throw new Error("جلسة غير صالحة")

    const { data: appUser, error: userError } = await supabase
      .from("users")
      .select("id,company_id,status,permissions,role_id,active_warehouse_role")
      .eq("auth_id", user.id)
      .maybeSingle()

    if (userError) throw new Error("فشل قراءة ملف المستخدم: " + userError.message)
    if (!appUser?.id || !appUser?.company_id || (appUser.status && String(appUser.status).toLowerCase() !== "active")) {
      throw new Error("المستخدم غير موجود أو غير نشط")
    }

    const directPermissions = Array.isArray(appUser.permissions) ? appUser.permissions : []
    let rolePermissions: string[] = []
    if (appUser.role_id) {
      const { data: roleData, error: roleError } = await supabase
        .from("roles")
        .select("permissions")
        .eq("id", appUser.role_id)
        .eq("company_id", appUser.company_id)
        .maybeSingle()
      if (roleError) throw new Error("فشل التحقق من صلاحيات الدور")
      rolePermissions = Array.isArray(roleData?.permissions) ? roleData.permissions : []
    }

    const { data: ownerProfile, error: ownerError } = await supabase
      .from("owner_profile")
      .select("auth_user_id")
      .eq("auth_user_id", user.id)
      .maybeSingle()
    if (ownerError) throw new Error("فشل التحقق من ملف المالك")

    const verifiedOwner = directPermissions.includes("*") && !!ownerProfile?.auth_user_id
    const hasWarehousePermission =
      directPermissions.includes("warehouse") ||
      rolePermissions.includes("warehouse") ||
      verifiedOwner
    if (!hasWarehousePermission) throw new Error("ليس لديك صلاحية استخدام عمليات المخازن")
    if (!verifiedOwner && appUser.active_warehouse_role !== "مرتجعات" && appUser.active_warehouse_role !== "مخزن شامل") {
      throw new Error("الدور المخزني النشط لا يسمح بإلغاء المرتجعات")
    }

    const { data: runsheet, error: runsheetError } = await supabase
      .from("runsheets")
      .select("id,status,return_handler_id,return_start,return_end")
      .eq("company_id", appUser.company_id)
      .eq("runsheet_code", runsheetCode)
      .maybeSingle()

    if (runsheetError) throw new Error("فشل قراءة الرانشيت: " + runsheetError.message)
    if (!runsheet) throw new Error("الرانشيت غير موجود ضمن شركة المستخدم")
    if (runsheet.status !== "Returning") throw new Error("الرانشيت ليس قيد المرتجعات")
    if (runsheet.return_handler_id !== appUser.id) throw new Error("هذا الرانشيت غير مسند إليك")

    // A previously completed return may have already posted stock and financial effects.
    // Do not relabel it Delivered: a dedicated atomic reversal contract is required.
    if (runsheet.return_end) {
      throw new Error("هذا الرانشيت أُعيد فتحه بعد اكتمال المرتجعات؛ لا يمكن إلغاء جلسة إعادة الفتح قبل تسوية عكس المخزون والآثار المالية")
    }

    // Draft item quantities are device-local until complete-return commits them to order_details.
    // run_sheet_details is a derived projection; never reset its values directly here.
    const { data: updatedRows, error: updateError } = await supabase
      .from("runsheets")
      .update({
        status: "Delivered",
        return_handler_id: null,
        return_start: null,
        updated_at: new Date().toISOString()
      })
      .eq("id", runsheet.id)
      .eq("company_id", appUser.company_id)
      .eq("status", "Returning")
      .eq("return_handler_id", appUser.id)
      .is("return_end", null)
      .select("id")

    if (updateError) throw new Error("فشل إلغاء جلسة المرتجعات: " + updateError.message)
    if (!Array.isArray(updatedRows) || updatedRows.length !== 1) {
      throw new Error("تغيرت حالة الرانشيت أثناء الإلغاء؛ حدّث القائمة وحاول مرة أخرى")
    }

    return new Response(JSON.stringify({
      success: true,
      msg: "تم إلغاء جلسة المرتجعات. لم تُعدّل كميات المصدر أو المخزون."
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (error: any) {
    return new Response(JSON.stringify({
      success: false,
      msg: error?.message || "فشل إلغاء المرتجعات"
    }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
