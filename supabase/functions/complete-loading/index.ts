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
    const code = body?.runsheet_code
    const raw = body?.items
    if (!code || !Array.isArray(raw) || !raw.length) throw new Error("البيانات غير مكتملة")

    const { data: pubUser, error: userError } = await supabase
      .from("users")
      .select("id,company_id,status,auth_id,email")
      .eq("auth_id", user.id)
      .maybeSingle()
    if (userError) throw new Error("فشل قراءة المستخدم: " + userError.message)
    if (!pubUser?.id || !pubUser.company_id) throw new Error("المستخدم غير مسجل في النظام أو سياق الشركة غير محدد")
    if (pubUser.status && pubUser.status !== "Active") throw new Error("المستخدم غير نشط")

    const items = raw.map((x: any) => ({
      item_code: x?.item_code ?? x?.itemCode,
      loaded_qty: Number(x?.loaded_qty ?? x?.loadedQty ?? 0),
    }))
    if (items.some((x: any) => !x.item_code || x.loaded_qty <= 0)) throw new Error("بيانات التحميل غير صالحة")

    const { data: r, error: re } = await supabase
      .from("runsheets")
      .select("id,loader_id")
      .eq("company_id", pubUser.company_id)
      .eq("runsheet_code", code)
      .maybeSingle()
    if (re) throw new Error("خطأ في البحث عن الرانشيت: " + re.message)
    if (!r) throw new Error("الرانشيت غير موجود")
    if (r.loader_id !== pubUser.id) throw new Error("هذه عملية تحميل مسندة إلى مستخدم آخر");

    const { data, error } = await supabase.rpc("complete_runsheet_loading", {
      p_company_id: pubUser.company_id,
      p_runsheet_id: r.id,
      p_items: items,
      p_user_email: pubUser.email || user.email,
    })
    if (error) throw new Error(error.message)

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e: any) {
    return new Response(JSON.stringify({ success: false, msg: e?.message || "فشل إنهاء التحميل" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})