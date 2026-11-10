// create-stock-voucher — authenticated voucher capability wrapper
// Supports CREATE / UPDATE-DRAFT / DELETE-DRAFT through the existing endpoint.
// Physical stock mutations remain delegated to the canonical voucher lifecycle RPCs.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase=createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const corsHeaders={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods":"POST, OPTIONS"
}

serve(async(req)=>{
  if(req.method==='OPTIONS'){
    return new Response('ok',{headers:corsHeaders})
  }

  try{
    const body=await req.json().catch(()=>({}))
    const action=String(body?.action||'create').trim().toLowerCase()
    const ah=req.headers.get('Authorization')

    if(!ah){
      throw new Error('غير مصرح')
    }

    const token=ah.replace(/^Bearer\s+/i,'')
    const {data:{user},error:ae}=await supabase.auth.getUser(token)

    if(ae||!user?.id||!user?.email){
      throw new Error('جلسة غير صالحة')
    }

    const {data:pu,error:ue}=await supabase
      .from('users')
      .select('company_id')
      .eq('auth_id',user.id)
      .maybeSingle()

    if(ue||!pu?.company_id){
      throw new Error('سياق الشركة غير محدد للمستخدم')
    }

    const companyId=pu.company_id

    if(action==='delete'){
      const code=String(
        body?.voucher_code||body?.voucherCode||''
      ).trim()

      if(!code){
        throw new Error('رقم الإذن مطلوب')
      }

      const {data,error}=await supabase.rpc(
        'delete_manual_stock_voucher_atomic',
        {
          p_company_id:companyId,
          p_voucher_code:code,
          p_user_email:user.email
        }
      )

      if(error){
        throw new Error(error.message)
      }

      return new Response(
        JSON.stringify(data),
        {headers:{...corsHeaders,'Content-Type':'application/json'}}
      )
    }

    const type=String(body?.type||'').trim()
    const items=Array.isArray(body?.items)
      ?body.items
      :[]
    const repId=body?.rep_id||body?.repId||null

    if(!type||!items.length){
      throw new Error('النوع والأصناف مطلوبة')
    }

    const normalized=items.map((item:any)=>({
      itemCode:String(item?.itemCode??'').trim(),
      qty:Number(item?.qty),
      itemName:item?.itemName||item?.itemCode||'',
      unit:item?.unit||'حبة',
      unitPrice:Number(item?.unitPrice)||0,
      notes:item?.notes||''
    }))

    for(const x of normalized){
      if(
        !x.itemCode||
        !Number.isFinite(x.qty)||
        x.qty<=0
      ){
        throw new Error('بيانات الصنف غير صالحة')
      }
    }

    if(action==='request-branch-receipt'){
      const sourceBranchId=String(body?.fromId||body?.from_id||'').trim()
      const reference=String(body?.reference||'').trim()
      const operationId=String(
        body?.operation_id||
        body?.operationId||
        req.headers.get('Idempotency-Key')||
        ''
      ).trim()

      if(!sourceBranchId||!reference||!operationId){
        throw new Error('فرع المصدر والمرجع ومفتاح العملية مطلوبة')
      }

      const {data,error}=await supabase.rpc(
        'create_branch_receipt_request_atomic',
        {
          p_company_id:companyId,
          p_source_branch_id:sourceBranchId,
          p_reference:reference,
          p_notes:body?.notes||'',
          p_created_by:user.email,
          p_items:normalized,
          p_operation_id:operationId
        }
      )

      if(error){
        throw new Error(error.message)
      }

      return new Response(
        JSON.stringify(data),
        {headers:{...corsHeaders,'Content-Type':'application/json'}}
      )
    }

    if(action==='update'){
      const code=String(
        body?.voucher_code||body?.voucherCode||''
      ).trim()

      const operationId=String(
        body?.operation_id||
        body?.operationId||
        req.headers.get('Idempotency-Key')||
        ''
      ).trim()

      if(!code){
        throw new Error('رقم الإذن مطلوب لتعديل المسودة')
      }

      if(!operationId){
        throw new Error('operation_id مطلوب لتعديل المسودة بأمان')
      }

      /*
       * The canonical UPDATE-DRAFT RPC intentionally resolves auth.uid().
       * Keep the caller JWT on the RPC client instead of downgrading the
       * database contract to an email-only service-role check.
       */
      const rpcClient=createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        {
          global:{
            headers:{
              Authorization:ah
            }
          }
        }
      )

      const {data,error}=await rpcClient.rpc(
        'update_manual_stock_voucher_atomic',
        {
          p_company_id:companyId,
          p_voucher_code:code,
          p_operation_id:operationId,
          p_reference:body?.reference||'',
          p_from_type:body?.fromType||'Branch',
          p_from_id:body?.fromId||null,
          p_to_type:body?.toType||'Branch',
          p_to_id:body?.toId||null,
          p_notes:body?.notes||'',
          p_items:normalized,
          p_rep_id:repId
        }
      )

      if(error){
        throw new Error(error.message)
      }

      return new Response(
        JSON.stringify(data),
        {headers:{...corsHeaders,'Content-Type':'application/json'}}
      )
    }

    if(action!=='create'){
      throw new Error('عملية الإذن غير مدعومة')
    }

    const suppliedOperationId=String(
      body?.operation_id||
      body?.operationId||
      req.headers.get('Idempotency-Key')||
      ''
    ).trim()||null

    const args10={
      p_company_id:companyId,
      p_type:type,
      p_reference:body?.reference||'',
      p_from_type:body?.fromType||'Branch',
      p_from_id:body?.fromId||null,
      p_to_type:body?.toType||'Branch',
      p_to_id:body?.toId||null,
      p_notes:body?.notes||'',
      p_created_by:user.email,
      p_items:normalized
    }

    const args12={
      ...args10,
      p_rep_id:repId,
      p_operation_id:suppliedOperationId
    }

    const {data,error}=
      repId||suppliedOperationId
        ?await supabase.rpc(
            'create_manual_stock_voucher_atomic',
            args12
          )
        :await supabase.rpc(
            'create_manual_stock_voucher_atomic',
            args10
          )

    if(error){
      throw new Error(error.message)
    }

    return new Response(
      JSON.stringify(data),
      {headers:{...corsHeaders,'Content-Type':'application/json'}}
    )
  }catch(e:any){
    return new Response(
      JSON.stringify({
        success:false,
        msg:e?.message||'فشل تنفيذ إذن المخزون'
      }),
      {
        status:400,
        headers:{...corsHeaders,'Content-Type':'application/json'}
      }
    )
  }
})