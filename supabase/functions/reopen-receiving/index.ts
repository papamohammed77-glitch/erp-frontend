import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const origin = req.headers.get("Origin") || "*";
  const cors = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, msg: "طريقة الطلب غير مدعومة" }), { status: 405, headers: cors });
  }
  if (!req.headers.get("Authorization")) {
    return new Response(JSON.stringify({ success: false, msg: "غير مصرح" }), { status: 401, headers: cors });
  }
  return new Response(JSON.stringify({
    success: false,
    code: "PURCHASE_RECEIVING_REOPEN_SUSPENDED",
    msg: "إعادة فتح أمر شراء بعد الاستلام موقوفة؛ يلزم مسار عكسي ذري يطابق حركات المخزون والذمم والقيود المالية."
  }), { status: 409, headers: cors });
});
