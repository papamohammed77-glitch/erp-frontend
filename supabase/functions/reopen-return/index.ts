import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  const origin = req.headers.get("Origin") || "*";
  const corsHeaders = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({
      success: false,
      code: "METHOD_NOT_ALLOWED",
      msg: "طريقة الطلب غير مدعومة",
    }), { status: 405, headers: corsHeaders });
  }

  // Fail closed: the former implementation directly decremented stock_branches
  // without an inventory movement, reversal journal, credit-note reversal,
  // idempotency key, or a company-scoped atomic transaction.
  // Reopening a posted return must remain disabled until a compensating atomic
  // contract exists for stock, accounting, and driver-liability effects.
  return new Response(JSON.stringify({
    success: false,
    code: "REOPEN_RETURN_TEMPORARILY_DISABLED",
    msg: "إعادة فتح المرتجعات المكتملة متوقفة مؤقتًا لحماية المخزون والقيود المحاسبية. يلزم مسار عكس ذري معتمد قبل إتاحة التعديل.",
  }), { status: 409, headers: corsHeaders });
});
