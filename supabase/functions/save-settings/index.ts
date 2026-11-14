import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
}

function asPermissionArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String) : []
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }

  try {
    const body = await req.json().catch(() => null)
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error("بيانات الطلب غير صالحة")
    }

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) throw new Error("غير مصرح")

    const token = authHeader.replace(/^Bearer\s+/i, "").trim()
    if (!token) throw new Error("جلسة المصادقة غير صالحة")

    const { data: authData, error: authError } = await supabase.auth.getUser(token)
    if (authError || !authData?.user?.id || !authData.user.email) {
      throw new Error("جلسة المصادقة غير صالحة")
    }

    const authUser = authData.user

    const { data: userRow, error: userError } = await supabase
      .from("users")
      .select("id,auth_id,company_id,status,permissions,email")
      .eq("auth_id", authUser.id)
      .maybeSingle()

    if (userError || !userRow?.id || !userRow.company_id) {
      throw new Error("سياق الشركة غير محدد للمستخدم")
    }

    if ((userRow.status || "Active") !== "Active") {
      throw new Error("المستخدم غير نشط")
    }

    const meta = authUser.user_metadata || {}
    const metaPermissions = asPermissionArray(meta.permissions)
    const dbPermissions = asPermissionArray(userRow.permissions)

    const { data: ownerProfile, error: ownerError } = await supabase
      .from("owner_profile")
      .select("auth_user_id,owner_email")
      .eq("auth_user_id", authUser.id)
      .maybeSingle()

    if (ownerError) throw new Error("تعذر التحقق من ملف المالك")

    const ownerVerified =
      String(meta.isOwner).toLowerCase() === "true" &&
      metaPermissions.includes("*") &&
      dbPermissions.includes("*") &&
      !!ownerProfile?.auth_user_id

    const action = String(body?.action || "").trim().toLowerCase()

    if (action === "owner-credentials") {
      if (!ownerVerified) {
        throw new Error("صلاحية المالك مطلوبة لتعديل بيانات الدخول")
      }

      if (
        !authUser.email ||
        String(userRow.email || "").toLowerCase() !== String(authUser.email).toLowerCase() ||
        String(ownerProfile?.owner_email || "").toLowerCase() !== String(authUser.email).toLowerCase()
      ) {
        throw new Error("بيانات هوية المالك غير متطابقة؛ تم إيقاف التغيير حمايةً للحساب")
      }

      const lastSignIn = authUser.last_sign_in_at ? Date.parse(authUser.last_sign_in_at) : NaN
      const ageMs = Date.now() - lastSignIn
      if (!Number.isFinite(lastSignIn) || ageMs < -60000 || ageMs > 5 * 60 * 1000) {
        throw new Error("انتهت مهلة التحقق الأمني؛ أدخل كلمة المرور الحالية مرة أخرى")
      }

      const hasAlias = Object.prototype.hasOwnProperty.call(body, "new_login_alias")
      const hasPassword = Object.prototype.hasOwnProperty.call(body, "new_password")
      if (hasAlias === hasPassword) {
        throw new Error("يجب تحديد عملية واحدة فقط: تغيير معرف الدخول أو كلمة المرور")
      }

      if (hasAlias) {
        const oldEmail = String(authUser.email).trim().toLowerCase()
        const newEmail = String(body.new_login_alias || "").trim().toLowerCase()
        const aliasPattern = /^[a-z0-9][a-z0-9._+-]{0,63}@(rawaea|alrawae)\.com$/
        if (newEmail.length > 254 || !aliasPattern.test(newEmail)) {
          throw new Error("معرف الدخول يجب أن ينتهي بـ @rawaea.com أو @alrawae.com")
        }
        if (newEmail === oldEmail) {
          throw new Error("معرف الدخول الجديد مطابق للمعرف الحالي")
        }

        const { error: authUpdateError } = await supabase.auth.admin.updateUserById(
          authUser.id,
          { email: newEmail, email_confirm: true }
        )
        if (authUpdateError) throw new Error(authUpdateError.message || "تعذر تحديث معرف الدخول")

        const { data: syncResult, error: syncError } = await supabase.rpc("owner_login_alias_sync_atomic", {
          p_actor_user_id: userRow.id,
          p_auth_user_id: authUser.id,
          p_actor_email: oldEmail,
          p_expected_old_email: oldEmail,
          p_new_email: newEmail
        })

        if (syncError || !syncResult?.success || syncResult?.email !== newEmail) {
          const rollback = await supabase.auth.admin.updateUserById(
            authUser.id,
            { email: oldEmail, email_confirm: true }
          )
          if (rollback.error) {
            console.error("OWNER_ALIAS_CRITICAL_RECONCILIATION_REQUIRED", {
              auth_user_id: authUser.id,
              old_email: oldEmail,
              requested_email: newEmail,
              sync_error: syncError?.message || "IDENTITY_SYNC_RESPONSE_INVALID",
              rollback_error: rollback.error.message
            })
            return new Response(
              JSON.stringify({
                success: false,
                critical: true,
                reconciliation_required: true,
                error: "تعذر إكمال مزامنة هوية المالك وتعذر التراجع التلقائي. أوقفنا أي محاولة أخرى ويلزم تدخل مسؤول المشروع."
              }),
              { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            )
          }
          throw new Error("فشلت مزامنة سجل المالك؛ أُعيد معرف المصادقة القديم تلقائيًا ولم يُعتمد التغيير")
        }

        return new Response(
          JSON.stringify({
            success: true,
            changed: true,
            credential: "login_alias",
            email: newEmail,
            auth_user_id: authUser.id,
            user_id: userRow.id,
            email_confirmation_required: false
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }

      const newPassword = String(body.new_password || "")
      if (newPassword.length < 12 || newPassword.length > 128) {
        throw new Error("كلمة المرور يجب أن تكون من 12 إلى 128 حرفًا")
      }

      const { error: passwordError } = await supabase.auth.admin.updateUserById(
        authUser.id,
        { password: newPassword }
      )
      if (passwordError) throw new Error(passwordError.message || "تعذر تحديث كلمة المرور")

      const operationId = "OWNER_PASSWORD_CHANGE:" + authUser.id + ":" + Date.now()
      const { error: auditError } = await supabase.from("audit_log").insert({
        user_email: authUser.email,
        action: "update",
        table_name: "owner_credentials",
        record_id: authUser.id,
        old_data: { credential: "password" },
        new_data: { credential: "password", method: "owner_reauthenticated_admin_api" },
        company_id: userRow.company_id,
        actor_user_id: userRow.id,
        source_type: "authentication",
        operation_id: operationId
      })
      if (auditError) {
        console.error("OWNER_PASSWORD_AUDIT_WRITE_FAILED", {
          auth_user_id: authUser.id,
          operation_id: operationId,
          error: auditError.message
        })
      }

      return new Response(
        JSON.stringify({
          success: true,
          changed: true,
          credential: "password",
          audit_warning: !!auditError,
          email_confirmation_required: false
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (action === "license-admin") {
      if (!ownerVerified) throw new Error("صلاحية المالك مطلوبة لإدارة التراخيص")

      const targetCompanyId = String(body?.company_id || "").trim()
      const adminAction = String(body?.admin_action || "list").trim().toLowerCase()
      const payload = body?.payload && typeof body.payload === "object" ? body.payload : {}

      if (!["list", "detail", "save"].includes(adminAction)) {
        throw new Error("إجراء إدارة التراخيص غير مدعوم")
      }
      if ((adminAction === "detail" || adminAction === "save") && !targetCompanyId) {
        throw new Error("الشركة المستهدفة مطلوبة")
      }

      const { data, error } = await supabase.rpc("owner_license_admin_atomic", {
        p_action: adminAction,
        p_company_id: targetCompanyId || null,
        p_actor_user_id: userRow.id,
        p_actor_auth_id: authUser.id,
        p_actor_email: authUser.email,
        p_payload: payload
      })

      if (error) throw new Error(error.message)

      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const patchKeys = Object.keys(body as Record<string, unknown>)
    const licenseRequested = patchKeys.some((key) =>
      ["status", "trial_end_date", "subscription_end_date"].includes(key)
    )

    let ownerForSettings = false
    if (licenseRequested) {
      ownerForSettings =
        String(meta.isOwner).toLowerCase() === "true" &&
        metaPermissions.includes("*") &&
        dbPermissions.includes("*") &&
        !!ownerProfile?.auth_user_id

      if (!ownerForSettings) {
        throw new Error("صلاحية المالك مطلوبة لتعديل إعدادات الترخيص")
      }
    }

    const { data, error } = await supabase.rpc("save_system_settings_atomic", {
      p_company_id: userRow.company_id,
      p_actor_user_id: userRow.id,
      p_actor_email: authUser.email,
      p_owner_verified: ownerForSettings,
      p_settings: body
    })

    if (error) throw new Error(error.message)

    return new Response(
      JSON.stringify(data),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error?.message || "فشل تنفيذ الطلب"
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})