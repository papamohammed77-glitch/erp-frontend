import { requireWarehouseRole, assertWarehouseMainBranch } from "../_shared/warehouse-auth.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const corsHeaders = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, idempotency-key","Access-Control-Allow-Methods":"POST, OPTIONS"}
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
serve(async(req)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:corsHeaders})
 try{
  const rawBody=await req.text();if(!rawBody) throw new Error("Body فارغ");let body:any;try{body=JSON.parse(rawBody)}catch{throw new Error("صيغة JSON غير صالحة")}
  const runsheet_code=String(body?.runsheet_code||"").trim(),items=body?.items;if(!runsheet_code||!Array.isArray(items)||!items.length) throw new Error("البيانات غير مكتملة")
  const suppliedOperationId=String(body?.operation_id||req.headers.get("Idempotency-Key")||"").trim();if(suppliedOperationId&&!UUID_RE.test(suppliedOperationId)) throw new Error("operation_id غير صالح");const operationId=suppliedOperationId||null
  const authHeader=req.headers.get("Authorization");if(!authHeader) throw new Error("غير مصرح");
    const whActor = await requireWarehouseRole(supabase, authHeader, "تحضير");
    await assertWarehouseMainBranch(supabase, whActor);const user=whActor.authUser;const pubUser=whActor.appUser;
  const normalizedItems=items.map((item:any)=>({item_code:item?.item_code??item?.itemCode,picked_qty:item?.picked_qty??item?.pickedQty,notes:item?.notes??null}))
  const {data,error}=await supabase.rpc("complete_runsheet_picking",{p_company_id:pubUser.company_id,p_runsheet_code:runsheet_code,p_user_email:pubUser.email||user.email,p_items:normalizedItems,p_operation_id:operationId});if(error) throw new Error(error.message)
  return new Response(JSON.stringify(data),{headers:{...corsHeaders,"Content-Type":"application/json"}})
 }catch(error:any){return new Response(JSON.stringify({success:false,msg:error?.message||"فشل إنهاء التحضير"}),{status:400,headers:{...corsHeaders,"Content-Type":"application/json"}})}
})