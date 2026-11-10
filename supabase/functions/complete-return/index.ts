import { requireWarehouseRole, assertWarehouseMainBranch } from "../_shared/warehouse-auth.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const body = await req.json().catch(() => ({}))
    const runsheet_code = body?.runsheet_code ?? null
    const order_code = body?.order_code ?? null
    const items = body?.items
    const is_pos_return = body?.is_pos_return === true

    if ((!runsheet_code && !order_code) || !Array.isArray(items) || !items.length) {
      throw new Error("البيانات غير مكتملة")
    }

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""))
    if (authError || !user?.id || !user.email) throw new Error("جلسة غير صالحة")

    const { data: appUser, error: userError } = await supabase
      .from("users")
      .select("id,company_id,status,email,permissions,role_id,active_warehouse_role")
      .eq("auth_id", user.id)
      .maybeSingle()

    if (userError || !appUser?.id || !appUser?.company_id || (appUser.status && String(appUser.status).toLowerCase() !== "active")) {
      throw new Error("سياق الشركة أو ملف المستخدم غير متاح للمستخدم المصادق عليه")
    }

    // A runsheet return is a warehouse operation; a POS/order-only return must keep its own contract.
    if (runsheet_code) {
      const whActor = await requireWarehouseRole(supabase, authHeader, "مرتجعات");
      await assertWarehouseMainBranch(supabase, whActor);
      const directPermissions = Array.isArray(appUser.permissions) ? appUser.permissions : []
      let rolePermissions = []
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
      if (!verifiedOwner && !["مرتجعات","مخزن شامل"].includes(appUser.active_warehouse_role)) {
        throw new Error("الدور المخزني النشط لا يسمح بإنهاء المرتجعات")
      }

      const { data: runsheet, error: runsheetError } = await supabase
        .from("runsheets")
        .select("id,status,return_handler_id")
        .eq("company_id", appUser.company_id)
        .eq("runsheet_code", runsheet_code)
        .maybeSingle()

      if (runsheetError) throw new Error("فشل التحقق من الرانشيت: " + runsheetError.message)
      if (!runsheet) throw new Error("الرانشيت غير موجود ضمن شركة المستخدم")
      if (runsheet.status !== "Returning") throw new Error("الرانشيت ليس قيد المرتجعات")
      if (runsheet.return_handler_id !== appUser.id) throw new Error("هذا الرانشيت غير مسند إليك")
    }

    const { data, error } = await supabase.rpc("complete_sales_return_credit_note_atomic", {
      p_company_id: appUser.company_id,
      p_runsheet_code: runsheet_code,
      p_order_code: order_code,
      p_is_pos_return: is_pos_return,
      p_user_email: appUser.email || user.email,
      p_items: items,
      p_reason: String(body?.reason || "مرتجع بضاعة")
    })

    if (error) throw new Error(error.message)

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  } catch (e) {
    return new Response(JSON.stringify({
      success: false,
      msg: e?.message || "فشل إنهاء المرتجعات"
    }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
