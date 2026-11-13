import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const corsHeaders = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"}
serve(async (req) => {
 if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
 try {
  const body = await req.json().catch(() => ({})), voucher_code = body?.voucher_code
  if (!voucher_code) throw new Error("رقم الإذن مطلوب")
  const authHeader = req.headers.get("Authorization"); if (!authHeader) throw new Error("غير مصرح")
  const token = authHeader.replace("Bearer ", "")
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user?.id || !user?.email) throw new Error("جلسة غير صالحة")
  const { data: publicUser, error: userError } = await supabase.from("users").select("id, company_id").eq("auth_id", user.id).maybeSingle()
  if (userError || !publicUser?.company_id) throw new Error("سياق الشركة غير محدد للمستخدم")
  const { data, error } = await supabase.rpc("send_stock_voucher_atomic", {p_company_id: publicUser.company_id,p_voucher_code: voucher_code,p_user_email: user.email})
  if (error) throw new Error(error.message)
  return new Response(JSON.stringify(data), {headers:{...corsHeaders,"Content-Type":"application/json"}})
 } catch (error:any) { return new Response(JSON.stringify({success:false,msg:error?.message||"فشل إرسال الإذن"}), {status:400,headers:{...corsHeaders,"Content-Type":"application/json"}}) }
})