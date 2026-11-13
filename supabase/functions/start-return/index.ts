import { requireWarehouseRole, assertWarehouseMainBranch } from "../_shared/warehouse-auth.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
serve(async(req)=>{const origin=req.headers.get("Origin")||"*";const cors={"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};if(req.method==="OPTIONS")return new Response("ok",{headers:cors});try{const b=await req.json().catch(()=>({})),code=String(b?.runsheet_code||"").trim();if(!code)throw new Error("رقم الرانشيت مطلوب");const ah=req.headers.get("Authorization");if(!ah)throw new Error("غير مصرح");
const whActor = await requireWarehouseRole(supabase, ah, "مرتجعات");
await assertWarehouseMainBranch(supabase, whActor);const user=whActor.authUser;const pu=whActor.appUser;
const {data:active,error:re1}=await supabase.from("runsheets").select("runsheet_code").eq("company_id",pu.company_id).eq("status","Returning").eq("return_handler_id",pu.id).maybeSingle();
if(re1)throw new Error("فشل التحقق من المرتجعات النشطة: "+re1.message);
if(active)throw new Error("لديك بالفعل رانشيت قيد المرتجعات: "+active.runsheet_code+". أنهِه أو ألغِه أولاً.");
const {data:rs,error:re}=await supabase.from("runsheets").select("id,status").eq("company_id",pu.company_id).eq("runsheet_code",code).maybeSingle();
if(re)throw new Error("فشل قراءة الرانشيت: "+re.message);
if(!rs)throw new Error("الرانشيت غير موجود");
if(rs.status!=="Delivered")throw new Error("لا يمكن بدء المرتجعات");
const {data:details,error:detailsError}=await supabase.from("run_sheet_details").select("qty_loaded,qty_delivered,qty_returned").eq("runsheet_id",rs.id);
if(detailsError)throw new Error("فشل قراءة الكميات المتبقية للمرتجع: "+detailsError.message);
const hasPendingReturn=(details||[]).some(function(d){return (Number(d.qty_loaded)||0)-(Number(d.qty_delivered)||0)-(Number(d.qty_returned)||0)>0;});
if(!hasPendingReturn)throw new Error("لا توجد كمية متبقية مؤهلة للمرتجع في هذا الرانشيت");
const {data:updatedRows,error:up}=await supabase.from("runsheets").update({status:"Returning",return_handler_id:pu.id,return_start:new Date().toISOString()}).eq("id",rs.id).eq("company_id",pu.company_id).eq("status","Delivered").select("id");
if(up)throw new Error("فشل بدء المرتجعات: "+up.message);
if(!Array.isArray(updatedRows)||updatedRows.length!==1)throw new Error("تغيرت حالة الرانشيت أثناء بدء المرتجعات؛ حدّث القائمة وحاول مرة أخرى");return new Response(JSON.stringify({success:true,msg:"تم بدء المرتجعات"}),{headers:{...cors,"Content-Type":"application/json"}})}catch(e){return new Response(JSON.stringify({success:false,msg:e?.message||"فشل بدء المرتجعات"}),{status:400,headers:{...cors,"Content-Type":"application/json"}})}})