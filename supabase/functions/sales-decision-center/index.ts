import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"}

serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
  try{
    const body=await req.json().catch(()=>({}))
    const operation=String(body?.operation||'').trim().toUpperCase()
    const ah=req.headers.get('Authorization')
    if(!ah) throw new Error('غير مصرح')
    const {data:{user},error:ae}=await supabase.auth.getUser(ah.replace('Bearer ',''))
    if(ae||!user?.id||!user?.email) throw new Error('جلسة غير صالحة')
    const {data:u,error:ue}=await supabase.from('users').select('id,company_id,status,permissions').eq('auth_id',user.id).maybeSingle()
    if(ue||!u?.company_id||u.status!=='Active') throw new Error('سياق المستخدم غير صالح')
    const readOps=['GET_POLICY','VALIDATE_ORDER','GET_PENDING_APPROVALS']
    const writeOps=['SAVE_POLICY','PUBLISH_POLICY','APPROVE_EVALUATION']
    if(!readOps.includes(operation)&&!writeOps.includes(operation)) throw new Error('عملية Sales Decision غير مدعومة')
    const permissions=Array.isArray(u.permissions)?u.permissions:[]
    const owner=permissions.includes('*')
    const canRead=owner||permissions.some((x:string)=>['orders','sales_manager','sales_supervisor','general_manager','reports'].includes(x))
    const canWrite=owner||permissions.some((x:string)=>['sales_manager','general_manager'].includes(x))
    if(readOps.includes(operation)&&!canRead) throw new Error('لا توجد صلاحية قراءة مركز قرار المبيعات')
    if(writeOps.includes(operation)&&!canWrite) throw new Error('لا توجد صلاحية إدارة مركز قرار المبيعات')
    const {data,error}=await supabase.rpc('sales_decision_engine_atomic',{
      p_company_id:u.company_id,
      p_operation:operation,
      p_user_email:user.email,
      p_policy_id:body?.policy_id||null,
      p_payload:body?.payload||{},
      p_operation_id:body?.operation_id||null
    })
    if(error) throw new Error(error.message)
    return new Response(JSON.stringify(data),{headers:{...cors,"Content-Type":"application/json"}})
  }catch(e){
    return new Response(JSON.stringify({success:false,msg:e?.message||'فشل تنفيذ مركز قرار المبيعات'}),{status:400,headers:{...cors,"Content-Type":"application/json"}})
  }
})