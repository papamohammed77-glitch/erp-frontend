import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin") || "*"
  const cors = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
    "Access-Control-Allow-Methods": "POST, OPTIONS"
  }
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors })

  try {
    const body = await req.json().catch(() => ({}))
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")
    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""))
    if (authError || !user?.id || !user.email) throw new Error("جلسة غير صالحة")

    const { data: appUser, error: userError } = await supabase
      .from("users")
      .select("company_id,status")
      .eq("auth_id", user.id)
      .maybeSingle()
    if (userError || !appUser?.company_id || (appUser.status && appUser.status !== "Active")) {
      throw new Error("المستخدم غير موجود أو غير نشط")
    }
    const companyId = appUser.company_id

    const operation = String(body?.operation || "").trim().toUpperCase()
    const payload = body?.payload && typeof body.payload === "object" ? body.payload : {}
    const operationId = String(body?.operation_id || req.headers.get("Idempotency-Key") || "").trim() || null

    if (operation) {
      let data: unknown
      let error: { message?: string } | null = null
      if (operation.startsWith("COUNT_")) {
        const r = await supabase.rpc("inventory_count_engine", {
          p_company_id: companyId,
          p_user_email: user.email,
          p_operation: operation.slice(6),
          p_payload: payload,
          p_operation_id: operationId
        })
        data = r.data; error = r.error
      } else if (operation.startsWith("REQUEST_")) {
        const r = await supabase.rpc("inventory_stock_request_engine", {
          p_company_id: companyId,
          p_user_email: user.email,
          p_operation: operation.slice(8),
          p_payload: payload,
          p_operation_id: operationId
        })
        data = r.data; error = r.error
      } else if (operation === "SNAPSHOT") {
        const r = await supabase.rpc("inventory_stock_snapshot", {
          p_company_id: companyId,
          p_user_email: user.email,
          p_branch_id: payload?.branch_id || null,
          p_query: payload?.query || null,
          p_low_only: payload?.low_only === true,
          p_limit: Number(payload?.limit || 200),
          p_offset: Number(payload?.offset || 0)
        })
        data = r.data; error = r.error
      } else if (operation === "MOVEMENTS") {
        const r = await supabase.rpc("inventory_movement_report", {
          p_company_id: companyId,
          p_user_email: user.email,
          p_from_date: payload?.from_date || null,
          p_to_date: payload?.to_date || null,
          p_branch_id: payload?.branch_id || null,
          p_item_id: payload?.item_id || null,
          p_movement_type: payload?.movement_type || null,
          p_query: payload?.query || null,
          p_limit: Number(payload?.limit || 200),
          p_offset: Number(payload?.offset || 0)
        })
        data = r.data; error = r.error
      } else if (operation === "REPLENISHMENT") {
        const r = await supabase.rpc("inventory_replenishment_report", {
          p_company_id: companyId,
          p_user_email: user.email,
          p_branch_id: payload?.branch_id || null,
          p_limit: Number(payload?.limit || 200),
          p_offset: Number(payload?.offset || 0)
        })
        data = r.data; error = r.error
      } else {
        throw new Error("عملية مخزون غير مدعومة")
      }
      if (error) throw new Error(error.message || "فشل تنفيذ عملية المخزون")
      return new Response(JSON.stringify(data), { headers: { ...cors, "Content-Type": "application/json" } })
    }

    // Backward-compatible legacy create-inventory-count contract.
    const type = String(body?.type || "").trim()
    const entityId = body?.entityId || null
    const reference = String(body?.reference || "").trim()
    const items = Array.isArray(body?.items) ? body.items : []
    if (!type || !items.length) throw new Error("نوع الجرد والأصناف مطلوبة")
    if (!['branch','vehicle','general'].includes(type)) throw new Error("نوع الجرد غير مدعوم")

    let targetBranchId: string | null = null
    if (type === "branch" || type === "general") {
      targetBranchId = entityId
      if (!targetBranchId) {
        const { data: settings, error: settingsError } = await supabase
          .from("app_settings")
          .select("main_branch_id")
          .eq("company_id", companyId)
          .order("created_at", { ascending: true })
          .limit(1)
          .maybeSingle()
        if (settingsError) throw new Error(settingsError.message)
        targetBranchId = settings?.main_branch_id || null
      }
    } else {
      let vehicle: { id: string; mobile_branch_id: string | null } | null = null

      // Preferred contract: entityId is the vehicle UUID.
      if (entityId) {
        try {
          const parsedId = String(entityId).trim()
          if (parsedId) {
            const { data: byId, error: byIdError } = await supabase
              .from("vehicles")
              .select("id,mobile_branch_id")
              .eq("id", parsedId)
              .eq("company_id", companyId)
              .maybeSingle()
            if (byIdError) throw byIdError
            vehicle = byId || null
          }
        } catch {
          vehicle = null
        }
      }

      // Backward-compatible contract used by the current Van Sales PWA:
      // entityId is the authenticated driver's email.
      if (!vehicle && typeof entityId === "string" && entityId.includes("@")) {
        const driverEmail = entityId.trim().toLowerCase()
        const { data: actor, error: actorError } = await supabase
          .from("users")
          .select("id,company_id,status,role")
          .eq("auth_id", user.id)
          .eq("company_id", companyId)
          .maybeSingle()
        if (actorError || !actor) throw new Error("هوية مندوب البيع غير صالحة للشركة")
        if (actor.status && actor.status !== "Active") throw new Error("مندوب البيع غير نشط")
        if (user.email?.trim().toLowerCase() !== driverEmail) throw new Error("هوية الجرد لا تطابق المستخدم المصادق عليه")

        const { data: assignment, error: assignmentError } = await supabase
          .from("fleet_vehicle_sales_rep_assignments")
          .select("vehicle_id")
          .eq("company_id", companyId)
          .eq("sales_rep_user_id", actor.id)
          .eq("is_primary", true)
          .is("end_at", null)
          .maybeSingle()
        if (assignmentError) throw assignmentError

        if (assignment?.vehicle_id) {
          const { data: assignedVehicle, error: assignedVehicleError } = await supabase
            .from("vehicles")
            .select("id,mobile_branch_id")
            .eq("id", assignment.vehicle_id)
            .eq("company_id", companyId)
            .maybeSingle()
          if (assignedVehicleError) throw assignedVehicleError
          vehicle = assignedVehicle || null
        }

        if (!vehicle) {
          const { data: driverVehicle, error: driverVehicleError } = await supabase
            .from("vehicles")
            .select("id,mobile_branch_id")
            .eq("driver_id", actor.id)
            .eq("company_id", companyId)
            .eq("status", "Active")
            .maybeSingle()
          if (driverVehicleError) throw driverVehicleError
          vehicle = driverVehicle || null
        }
      }

      if (!vehicle) throw new Error("المركبة غير صالحة للشركة")
      targetBranchId = vehicle.mobile_branch_id || null
    }
    if (!targetBranchId) throw new Error("وجهة الجرد غير محددة")
    const { data: branch, error: branchError } = await supabase
      .from("branches")
      .select("id")
      .eq("id", targetBranchId)
      .eq("company_id", companyId)
      .maybeSingle()
    if (branchError || !branch) throw new Error("فرع الجرد غير صالح للشركة")

    const countOperationId = String(body?.operation_id || `LEGACY-COUNT:${companyId}:${type}:${entityId || targetBranchId}:${reference || 'NOREF'}:${new Date().toISOString().slice(0,10)}`)
    const created = await supabase.rpc("inventory_count_engine", {
      p_company_id: companyId,
      p_user_email: user.email,
      p_operation: "CREATE",
      p_payload: {
        type,
        entity_id: entityId || targetBranchId,
        reference: reference || `جرد ${new Date().toLocaleDateString('ar-EG')}`,
        notes: String(body?.notes || "")
      },
      p_operation_id: countOperationId
    })
    if (created.error) throw new Error(created.error.message)
    const countId = created.data?.count_id
    if (!countId) throw new Error("تعذر إنشاء جلسة الجرد")

    for (const item of items) {
      const line = await supabase.rpc("inventory_count_engine", {
        p_company_id: companyId,
        p_user_email: user.email,
        p_operation: "UPSERT_LINE",
        p_payload: {
          count_id: countId,
          branch_id: targetBranchId,
          item_code: String(item?.itemCode || "").trim(),
          counted_qty: Number(item?.qty || 0),
          notes: String(item?.notes || "")
        },
        p_operation_id: null
      })
      if (line.error) throw new Error(line.error.message)
    }

    return new Response(JSON.stringify({
      success: true,
      msg: "تم حفظ الجرد في جلسة آمنة",
      count_id: countId,
      company_id: companyId,
      branch_id: targetBranchId,
      status: created.data?.status || "InProgress"
    }), { headers: { ...cors, "Content-Type": "application/json" } })
  } catch (e) {
    return new Response(JSON.stringify({ success: false, msg: e instanceof Error ? e.message : "فشل حفظ الجرد" }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" }
    })
  }
})
