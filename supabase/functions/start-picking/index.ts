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
    const rawBody = await req.text()
    let body: any = {}
    if (rawBody.trim()) { try { body = JSON.parse(rawBody) } catch { throw new Error("صيغة JSON غير صالحة") } }
    let runsheet_code = body?.runsheet_code
    if (!runsheet_code && body?.body) { try { runsheet_code = typeof body.body === "string" ? JSON.parse(body.body).runsheet_code : body.body.runsheet_code } catch {} }
    if (!runsheet_code) throw new Error("رقم الرانشيت مطلوب")
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")
    const whActor = await requireWarehouseRole(supabase, authHeader, "تحضير");
    await assertWarehouseMainBranch(supabase, whActor);
    const user = whActor.authUser;
    const pubUser = whActor.appUser;
    const companyId = pubUser.company_id
    const { data: runsheet, error: runsheetError } = await supabase.from("runsheets").select("id,status,picker_id,picker_start").eq("company_id", companyId).eq("runsheet_code", runsheet_code).maybeSingle()
    if (runsheetError) throw new Error("خطأ في البحث عن الرانشيت: " + runsheetError.message)
    if (!runsheet) throw new Error("الرانشيت غير موجود")
    if (runsheet.status === "Picking") {
      if (runsheet.picker_id === pubUser.id) return new Response(JSON.stringify({ success:true,msg:"التحضير بدأ بالفعل",runsheet_id:runsheet.id,status:runsheet.status,picker_id:runsheet.picker_id,picker_start:runsheet.picker_start }), { headers:{...corsHeaders,"Content-Type":"application/json"} })
      throw new Error("الرانشيت قيد التحضير بواسطة مستخدم آخر")
    }
    if (!["Open","Confirmed"].includes(runsheet.status)) throw new Error("لا يمكن بدء التحضير في هذه الحالة")
    const { data: updatedRows, error: updateError } = await supabase.from("runsheets").update({ status:"Picking",picker_id:pubUser.id,picker_start:new Date().toISOString(),picking_reservation_released:false }).eq("id",runsheet.id).eq("company_id",companyId).in("status",["Open","Confirmed"]).select("id,status,picker_id,picker_start,picking_reservation_released")
    if (updateError) throw new Error("فشل تحديث قاعدة البيانات: " + updateError.message)
    if (!updatedRows || updatedRows.length !== 1) {
      const { data: currentRunsheet, error: retryReadError } = await supabase.from("runsheets").select("id,status,picker_id,picker_start").eq("id",runsheet.id).eq("company_id",companyId).maybeSingle()
      if (retryReadError) throw new Error("فشل التحقق من حالة الرانشيت بعد المحاولة: " + retryReadError.message)
      if (currentRunsheet?.status === "Picking" && currentRunsheet.picker_id === pubUser.id) return new Response(JSON.stringify({ success:true,msg:"التحضير بدأ بالفعل",runsheet_id:currentRunsheet.id,status:currentRunsheet.status,picker_id:currentRunsheet.picker_id,picker_start:currentRunsheet.picker_start }), { headers:{...corsHeaders,"Content-Type":"application/json"} })
      throw new Error("الرانشيت انتقل إلى حالة التحضير بواسطة طلب آخر أو لم يعد صالحًا للبدء")
    }
    return new Response(JSON.stringify({ success:true,msg:"تم بدء التحضير",runsheet_id:updatedRows[0].id,status:updatedRows[0].status,picker_id:updatedRows[0].picker_id,picker_start:updatedRows[0].picker_start }), { headers:{...corsHeaders,"Content-Type":"application/json"} })
  } catch (error:any) {
    return new Response(JSON.stringify({ success:false,msg:error?.message || "فشل بدء التحضير" }), { status:400,headers:{...corsHeaders,"Content-Type":"application/json"} })
  }
})