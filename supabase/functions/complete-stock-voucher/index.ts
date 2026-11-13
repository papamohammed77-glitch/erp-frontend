import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
serve(async(req)=>{
  const origin=req.headers.get('Origin')||'*'
  const h={"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"}
  if(req.method==='OPTIONS') return new Response('ok',{headers:h})
  try{
    const b=await req.json().catch(()=>({})), code=String(b?.voucher_code||'').trim()
    if(!code) throw new Error('رقم الإذن مطلوب')
    const ah=req.headers.get('Authorization'); if(!ah) throw new Error('غير مصرح')
    const {data:{user},error:ae}=await supabase.auth.getUser(ah.replace(/^Bearer\s+/i,'')); if(ae||!user?.id||!user?.email) throw new Error('جلسة غير صالحة')
    const {data:u,error:ue}=await supabase.from('users').select('company_id').eq('auth_id',user.id).maybeSingle(); if(ue||!u?.company_id) throw new Error('سياق الشركة غير محدد للمستخدم')
    const {data,error}=await supabase.rpc('complete_manual_stock_voucher_atomic',{p_company_id:u.company_id,p_voucher_code:code,p_user_email:user.email}); if(error) throw new Error(error.message)
    return new Response(JSON.stringify(data),{headers:{...h,'Content-Type':'application/json'}})
  }catch(e){return new Response(JSON.stringify({success:false,msg:e?.message||'فشل إكمال الإذن'}),{status:400,headers:{...h,'Content-Type':'application/json'}})}
})