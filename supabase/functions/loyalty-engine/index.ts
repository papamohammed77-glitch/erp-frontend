import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, idempotency-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ success:false, msg:'POST فقط' }), { status:405, headers:{...corsHeaders,'Content-Type':'application/json'} })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const operation = String(body?.operation || '').trim()
    const payload = body?.payload && typeof body.payload === 'object' ? body.payload : {}
    const operationId = String(body?.operation_id || req.headers.get('Idempotency-Key') || '').trim() || null
    if (!operation) throw new Error('operation مطلوب')

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Authorization مطلوب')
    const token = authHeader.replace(/^Bearer\s+/i, '')
    const { data:{user}, error:authError } = await supabase.auth.getUser(token)
    if (authError || !user?.id || !user?.email) throw new Error('جلسة غير صالحة')

    const { data:userRow, error:userError } = await supabase
      .from('users')
      .select('id,company_id,email,status')
      .eq('auth_id', user.id)
      .maybeSingle()
    if (userError || !userRow?.company_id) throw new Error('سياق الشركة غير محدد للمستخدم')
    if (userRow.status && userRow.status !== 'Active') throw new Error('المستخدم غير نشط')

    const enriched = { ...payload }
    if (enriched && typeof enriched === 'object' && enriched.customer_id == null && body?.customer_id) enriched.customer_id = body.customer_id
    if (enriched && typeof enriched === 'object' && enriched.order_id == null && body?.order_id) enriched.order_id = body.order_id

    const { data, error } = await supabase.rpc('loyalty_engine_atomic', {
      p_company_id: userRow.company_id,
      p_operation: operation,
      p_user_email: user.email,
      p_payload: enriched,
      p_operation_id: operationId
    })
    if (error) throw new Error(error.message)

    return new Response(JSON.stringify(data), { headers:{...corsHeaders,'Content-Type':'application/json'} })
  } catch (e) {
    return new Response(JSON.stringify({ success:false, msg:e instanceof Error ? e.message : 'فشل محرك الولاء' }), { status:400, headers:{...corsHeaders,'Content-Type':'application/json'} })
  }
})
