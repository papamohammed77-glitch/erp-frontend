import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, idempotency-key","Access-Control-Allow-Methods":"POST, OPTIONS"}

async function deterministicUuid(seed:string){
  const buf=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(seed))
  const hex=Array.from(new Uint8Array(buf)).map(x=>x.toString(16).padStart(2,"0")).join("")
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20,32)}`
}

serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders})
  try{
    const b=await req.json().catch(()=>({}))
    const po_code=String(b?.po_code||'').trim()
    const invoice_id=String(b?.invoice_id||'').trim()
    const rawItems=Array.isArray(b?.itemsReceived)?b.itemsReceived:[]
    if((!po_code&&!invoice_id)||!rawItems.length) throw new Error('البيانات غير مكتملة')
    if(invoice_id&&!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(invoice_id)) throw new Error('معرّف فاتورة السوق غير صالح')

    const ah=req.headers.get('Authorization')
    if(!ah) throw new Error('غير مصرح')
    const {data:{user},error:ae}=await supabase.auth.getUser(ah.replace('Bearer ',''))
    if(ae||!user?.id||!user?.email) throw new Error('جلسة غير صالحة')

    const {data:appUser,error:ue}=await supabase.from('users').select('company_id,status').eq('auth_id',user.id).maybeSingle()
    if(ue||!appUser?.company_id||appUser.status&&appUser.status!=='Active') throw new Error('سياق الشركة غير متاح للمستخدم المصادق عليه')

    // Resolve effective permissions using the caller JWT, never the service-role client.
    const profileClient=createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global:{headers:{Authorization:ah}},
        auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}
      }
    )
    const {data:profile,error:profileError}=await profileClient.rpc('get_my_effective_profile')
    if(
      profileError ||
      !profile?.id ||
      profile.auth_id!==user.id ||
      profile.company_id!==appUser.company_id ||
      String(profile.status||'').toLowerCase()!=='active'
    ) throw new Error('تعذر التحقق من هوية المستخدم ونطاق الشركة')

    const permissions=Array.isArray(profile.permissions)
      ? profile.permissions.map((x:any)=>String(x))
      : []
    const isOwner=profile.isOwner===true
    const activeReceivingRole=String(profile.active_warehouse_role||'').trim()==='استلام'
    const hasWarehousePermission=
      permissions.includes('*') ||
      permissions.includes('warehouse') ||
      permissions.includes('receiving')
    if(!isOwner && !(activeReceivingRole && hasWarehousePermission)){
      throw new Error('لا تملك صلاحية استلام أوامر الشراء')
    }

    const items=rawItems.map((x:any)=>({
      item_code:String(x?.itemCode??x?.item_code??'').trim(),
      received_qty:Number(x?.receivedQty??x?.received_qty)||0,
      item_name:x?.itemName||x?.item_name||x?.itemCode||x?.item_code||'',
      unit:x?.unit||'حبة',
      reason:x?.reason||null
    }))
    for(const x of items){
      if(!x.item_code||!Number.isFinite(x.received_qty)||x.received_qty<0) throw new Error('بيانات الاستلام غير صالحة')
    }
    if(!items.some((x:any)=>Number(x.received_qty)>0)){
      throw new Error('يجب إدخال كمية موجبة لصنف واحد على الأقل')
    }

    const supplied=String(b?.operation_id||req.headers.get('Idempotency-Key')||'').trim()
    const suppliedIsUuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(supplied)
    const operation_id=invoice_id
      ?(suppliedIsUuid?supplied:await deterministicUuid(user.id+'|'+appUser.company_id+'|QMP|'+invoice_id+'|'+JSON.stringify(items)+'|'+supplied))
      :(supplied||await deterministicUuid(user.id+'|'+appUser.company_id+'|'+JSON.stringify({po_code,items})))

    const rpcName=invoice_id?'receive_quick_market_purchase_atomic':'receive_purchase_atomic'
    const rpcArgs=invoice_id
      ?{
        p_company_id:appUser.company_id,
        p_invoice_id:invoice_id,
        p_user_email:user.email,
        p_items:items,
        p_operation_id:operation_id
      }
      :{
        p_company_id:appUser.company_id,
        p_po_code:po_code,
        p_user_email:user.email,
        p_items:items,
        p_operation_id:operation_id
      }
    const {data,error}=await supabase.rpc(rpcName,rpcArgs)
    if(error) throw new Error(error.message)
    return new Response(JSON.stringify({...data,operation_id}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
  }catch(e){
    return new Response(JSON.stringify({success:false,msg:e?.message||'فشل استلام البضاعة'}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})
  }
})