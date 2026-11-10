import { requireWarehouseRole, assertWarehouseMainBranch } from "../_shared/warehouse-auth.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")
    const whActor = await requireWarehouseRole(supabase, authHeader, "تحميل");
    await assertWarehouseMainBranch(supabase, whActor);
    const token = authHeader.replace(/^Bearer\s+/i, "").trim()
    if (!token) throw new Error("جلسة غير صالحة")

    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user?.id || !user?.email) throw new Error("جلسة غير صالحة")

    const body = await req.json()
    if (!body?.runsheet_code) throw new Error("رقم الرانشيت مطلوب")

    const { data: pubUser, error: userError } = await supabase
      .from("users")
      .select("id,company_id,status,auth_id,email")
      .eq("auth_id", user.id)
      .maybeSingle()
    if (userError) throw new Error("فشل قراءة المستخدم: " + userError.message)
    if (!pubUser?.id || !pubUser.company_id) throw new Error("المستخدم غير مسجل في النظام أو سياق الشركة غير محدد")
    if (pubUser.status && pubUser.status !== "Active") throw new Error("المستخدم غير نشط")

    const vehicleId = typeof body.vehicle_id === "string" ? body.vehicle_id.trim() : ""

    const rpcName = vehicleId
      ? "start_runsheet_loading_with_vehicle"
      : "start_runsheet_loading"
    const rpcArgs = vehicleId
      ? {
          p_company_id: pubUser.company_id,
          p_runsheet_code: body.runsheet_code,
          p_user_email: pubUser.email || user.email,
          p_vehicle_id: vehicleId,
        }
      : {
          p_company_id: pubUser.company_id,
          p_runsheet_code: body.runsheet_code,
          p_user_email: pubUser.email || user.email,
        }

    const { data, error } = await supabase.rpc(rpcName, rpcArgs)
    if (error) throw new Error(error.message)

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e: any) {
    return new Response(JSON.stringify({ success: false, msg: e?.message || "فشل بدء التحميل" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})