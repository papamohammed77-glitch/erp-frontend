import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { canAdjustStock, canAccessAdjustmentBranch } from "./warehouse-adjustment-access.mjs";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

async function getActor(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("مصادقة مطلوبة");

  const { data: { user }, error: authError } =
    await db.auth.getUser(authHeader.replace(/^Bearer\s+/i, ""));
  if (authError || !user?.id) throw new Error("جلسة غير صالحة");

  // Use the same effective permission contract as the parent and warehouse hub.
  // This includes direct permissions, role.permissions, and role_permissions.
  const profileClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    }
  );
  const { data: profile, error: profileError } = await profileClient.rpc("get_my_effective_profile");
  if (
    profileError ||
    !profile?.id ||
    profile.auth_id !== user.id ||
    !profile.company_id ||
    String(profile.status || "").toLowerCase() !== "active"
  ) throw new Error("تعذر التحقق من هوية المستخدم ونطاق الشركة");

  if (!canAdjustStock(profile)) {
    throw new Error("لا تملك صلاحية تحديث أرصدة المخزون");
  }

  return { user, profile, companyId: profile.company_id };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => ({}));
    const { branch_id, adjustment_type, voucher_code, reason, items } = body;

    if (
      !branch_id ||
      !adjustment_type ||
      !voucher_code ||
      !reason ||
      !Array.isArray(items) ||
      !items.length
    ) throw new Error("البيانات غير مكتملة");

    const { user, profile, companyId } = await getActor(req);

    const { data: branch, error: branchError } = await db
      .from("branches")
      .select("id,branch_code,is_active")
      .eq("id", branch_id)
      .eq("company_id", companyId)
      .maybeSingle();

    if (branchError) throw branchError;
    if (!branch || branch.is_active === false) throw new Error("الفرع غير نشط أو غير تابع للشركة الحالية");
    if (!canAccessAdjustmentBranch(profile, branch)) {
      throw new Error("فرع التسوية خارج نطاق الفروع المصرح بها للمخزن الشامل");
    }

    const effects = [];
    for (const item of items) {
      const qty = Number(item?.qty);
      const itemCode = String(item?.item_code || "").trim();
      if (!itemCode || !Number.isFinite(qty)) throw new Error("بيانات الصنف غير صالحة");

      const { data: itemRow, error: itemError } = await db
        .from("items")
        .select("id,item_code")
        .eq("company_id", companyId)
        .eq("item_code", itemCode)
        .maybeSingle();

      if (itemError) throw itemError;
      if (!itemRow) throw new Error("الصنف غير موجود: " + itemCode);

      effects.push({
        item_id: itemRow.id,
        item_code: itemRow.item_code,
        qty,
        operation_kind: String(item?.operation_kind || body?.operation_kind || "Adjustment").trim()
      });
    }

    // The canonical transaction remains unchanged: stock movement, inventory log,
    // idempotency, cost valuation, and the linked accounting journal stay centralized.
    const { data, error } = await db.rpc("post_inventory_adjustment_atomic", {
      p_company_id: companyId,
      p_branch_id: branch_id,
      p_adjustment_type: adjustment_type,
      p_voucher_code: voucher_code,
      p_reason: reason,
      p_user_email: user.email,
      p_items: effects
    });

    if (error) throw error;
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  } catch (error) {
    console.error("bulk-stock-adjustment", error);
    return new Response(JSON.stringify({
      success: false,
      msg: error instanceof Error ? error.message : "فشل تحديث الرصيد"
    }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
