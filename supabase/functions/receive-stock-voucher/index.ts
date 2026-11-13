// receive-stock-voucher — thin capability wrapper
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, idempotency-key","Access-Control-Allow-Methods":"POST, OPTIONS"}
serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders})
 try{
  const b=await req.json().catch(()=>({})),code=String(b?.voucher_code||'').trim();let items=Array.isArray(b?.receivedItems)?b.receivedItems:[];const suppliedOperationId=String(b?.operation_id||req.headers.get('Idempotency-Key')||'').trim();if(!code) throw new Error('رقم الإذن مطلوب')
  const ah=req.headers.get('Authorization');if(!ah) throw new Error('غير مصرح');const {data:{user},error:ae}=await supabase.auth.getUser(ah.replace('Bearer ',''));if(ae||!user?.id||!user?.email) throw new Error('جلسة غير صالحة')
  const {data:u,error:ue}=await supabase.from('users').select('id,company_id').eq('auth_id',user.id).maybeSingle();if(ue||!u?.company_id) throw new Error('سياق الشركة غير محدد للمستخدم')
  const c=u.company_id,{data:v,error:ve}=await supabase.from('stock_vouchers').select('id,status,to_id').eq('company_id',c).eq('voucher_code',code).maybeSingle();if(ve||!v) throw new Error('الإذن غير موجود');if(!v.to_id) throw new Error('وجهة الإذن غير محددة')
  const fullRemainingRequest=items.length===0;let op=suppliedOperationId;if(!op){if(!fullRemainingRequest) throw new Error('operation_id مطلوب للاستلام الجزئي الآمن');op='UI-RECEIVE-REMAINDER:'+c+':'+v.id}
  if(fullRemainingRequest){const {data:d,error:de}=await supabase.from('stock_voucher_details').select('item_id,item_code,qty,received_qty').eq('voucher_id',v.id);if(de) throw new Error(de.message);items=(d||[]).map(x=>({itemId:x.item_id,itemCode:x.item_code,receivedQty:Number(x.qty||0)-Number(x.received_qty||0)})).filter(x=>x.receivedQty>0)}
  if(v.status!=='Sent'&&!fullRemainingRequest) throw new Error('يمكن استلام الأذونات المرسلة فقط')
  const effects=[];for(const x of items){const q=Number(x?.receivedQty??0),itemCode=String(x?.itemCode||'').trim();if(q<=0) continue;if(!itemCode) throw new Error('كود الصنف مطلوب');let resolved=null;if(x?.itemId){const r=await supabase.from('items').select('id,item_code').eq('id',x.itemId).maybeSingle();resolved=r.data||null}if(!resolved){const r=await supabase.from('items').select('id,item_code').eq('item_code',itemCode).maybeSingle();if(r.error||!r.data) throw new Error('الصنف غير موجود: '+itemCode);resolved=r.data}effects.push({direction:'IN',branch_id:v.to_id,item_id:resolved.id,item_code:resolved.item_code,qty:q})}
  if(!effects.length){if(fullRemainingRequest&&v.status==='Received') return new Response(JSON.stringify({success:true,duplicate:true,voucher_code:code,operation:'RECEIVE',status:v.status,operation_id:op}),{headers:{...corsHeaders,'Content-Type':'application/json'}});throw new Error('لا توجد كميات متبقية للاستلام')}
  const {data,error}=await supabase.rpc('post_manual_stock_voucher_atomic',{p_company_id:c,p_voucher_code:code,p_operation:'RECEIVE',p_user_email:user.email,p_effects:effects,p_operation_id:op});if(error) throw new Error(error.message)
  return new Response(JSON.stringify(data),{headers:{...corsHeaders,'Content-Type':'application/json'}})
 }catch(e){return new Response(JSON.stringify({success:false,msg:e?.message||'فشل استلام الإذن'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})}
})