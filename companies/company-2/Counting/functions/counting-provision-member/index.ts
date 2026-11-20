import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function findAuthUserByEmail(admin: any, normalizedEmail: string) {
  const perPage = 1000;
  const maxPages = 50;
  for (let page = 1; page <= maxPages; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw new Error("AUTH_USER_LOOKUP_FAILED: " + error.message);
    const users = data?.users || [];
    const matches = users.filter((u: any) =>
      String(u.email || "").trim().toLowerCase() === normalizedEmail
    );
    if (matches.length > 1) throw new Error("DUPLICATE_AUTH_EMAIL_IDENTITIES");
    if (matches.length === 1) return matches[0];
    if (users.length < perPage) return null;
  }
  throw new Error("AUTH_USER_LOOKUP_LIMIT_REACHED");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "METHOD_NOT_ALLOWED" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) return reply({ error: "UNAUTHORIZED" }, 401);
    const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: authData, error: authError } = await caller.auth.getUser();
    if (authError || !authData.user) return reply({ error: "UNAUTHORIZED" }, 401);
    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const body = await req.json();
    const projectId = String(body.project_id || "");
    const action = String(body.action || "create");
    if (!projectId) return reply({ error: "INVALID_INPUT" }, 400);
    const isPlatformOwner =
      String(authData.user.email || "").trim().toLowerCase() === "owner@rawaea.com" &&
      Boolean(authData.user.email_confirmed_at);
    if (!isPlatformOwner) {
      const { data: membership, error: membershipError } = await admin.from("count_members")
        .select("role,status").eq("project_id", projectId).eq("user_id", authData.user.id).maybeSingle();
      if (membershipError || membership?.role !== "supervisor" || membership?.status !== "active")
        return reply({ error: "SUPERVISOR_REQUIRED" }, 403);
    }

    if (action === "reset_password") {
      const memberId = String(body.member_id || "");
      const newPassword = String(body.new_password || "");
      if (!memberId || newPassword.length < 10) return reply({ error: "INVALID_INPUT" }, 400);
      const { data: target, error: targetError } = await admin.from("count_members")
        .select("id,user_id,role,display_name").eq("project_id", projectId).eq("id", memberId).maybeSingle();
      if (targetError || !target) return reply({ error: "MEMBER_NOT_FOUND" }, 404);
      const { error: updateError } = await admin.auth.admin.updateUserById(target.user_id, { password: newPassword });
      if (updateError) return reply({ error: updateError.message }, 400);
      const { error: auditError } = await admin.from("count_audit_log").insert({
        project_id: projectId, actor_id: authData.user.id, action: "member.password_reset",
        entity_type: "member", entity_id: target.id, details: { role: target.role }
      });
      return reply({ ok: true, action, member_id: target.id, audit_warning: auditError?.message || null });
    }

    if (action !== "create") return reply({ error: "UNSUPPORTED_ACTION" }, 400);
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const displayName = String(body.display_name || "").trim();
    const username = String(body.username || email).trim();
    const role = String(body.role || "counter");
    if (!email || !displayName || !username || !["counter", "auditor", "supervisor"].includes(role))
      return reply({ error: "INVALID_INPUT" }, 400);
    if (email === "owner@rawaea.com") {
      return reply({ error: "PLATFORM_OWNER_IDENTITY_CANNOT_BE_ADDED_AS_A_TEAM_MEMBER" }, 409);
    }

    // Reuse a confirmed Auth identity without changing its password or metadata.
    // A password is required only when the email does not yet exist in Auth.
    let authUser = await findAuthUserByEmail(admin, email);
    let accountCreated = false;
    let accountReused = false;
    if (authUser) {
      if (!authUser.email_confirmed_at) {
        return reply({
          error: "ACCOUNT_EXISTS_UNCONFIRMED",
          message: "يوجد حساب Auth بهذا البريد لكنه غير مؤكد. أكمل تأكيد الحساب أولاً؛ لم تُغيّر كلمة مروره."
        }, 409);
      }
      accountReused = true;
    } else {
      if (password.length < 10) return reply({ error: "PASSWORD_REQUIRED_FOR_NEW_ACCOUNT" }, 400);
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email, password, email_confirm: true, user_metadata: { counting_display_name: displayName }
      });
      if (createError || !created.user) {
        return reply({ error: createError?.message || "USER_CREATE_FAILED" }, 400);
      }
      authUser = created.user;
      accountCreated = true;
    }

    const { data: existingMembership, error: membershipLookupError } = await admin.from("count_members")
      .select("id,role,status,display_name,username")
      .eq("project_id", projectId).eq("user_id", authUser.id).maybeSingle();
    if (membershipLookupError) {
      if (accountCreated) await admin.auth.admin.deleteUser(authUser.id);
      return reply({ error: "MEMBERSHIP_LOOKUP_FAILED: " + membershipLookupError.message }, 500);
    }
    if (existingMembership) {
      if (existingMembership.status !== "active") {
        if (accountCreated) await admin.auth.admin.deleteUser(authUser.id);
        return reply({
          error: "MEMBERSHIP_EXISTS_NOT_ACTIVE",
          membership_id: existingMembership.id,
          membership_status: existingMembership.status,
          message: "الحساب مرتبط بهذا التكليف بعضوية غير نشطة. لا نعيد تفعيلها تلقائياً؛ استخدم إدارة المستخدمين لاستئناف العضوية."
        }, 409);
      }
      const { error: auditError } = await admin.from("count_audit_log").insert({
        project_id: projectId, actor_id: authData.user.id, action: "member.reused",
        entity_type: "member", entity_id: existingMembership.id,
        details: { email, username: existingMembership.username, role: existingMembership.role, auth_identity_reused: true }
      });
      return reply({
        ok: true, user_id: authUser.id, member_id: existingMembership.id,
        username: existingMembership.username, role: existingMembership.role,
        account_reused: true, membership_reused: true,
        existing_password_changed: false, audit_warning: auditError?.message || null
      });
    }

    const { data: memberRecord, error: insertError } = await admin.from("count_members").insert({
      project_id: projectId, user_id: authUser.id, display_name: displayName, username, role, status: "active"
    }).select("id").single();
    if (insertError || !memberRecord) {
      if (accountCreated) await admin.auth.admin.deleteUser(authUser.id);
      return reply({ error: insertError?.message || "MEMBERSHIP_CREATE_FAILED" }, 409);
    }
    const { error: auditError } = await admin.from("count_audit_log").insert({
      project_id: projectId, actor_id: authData.user.id, action: accountReused ? "member.attached_existing_auth" : "member.created",
      entity_type: "member", entity_id: memberRecord.id,
      details: { email, username, role, account_reused: accountReused, existing_password_changed: !accountCreated, password_initialized: accountCreated }
    });
    return reply({
      ok: true, user_id: authUser.id, member_id: memberRecord.id, username,
      account_reused: accountReused, membership_reused: false,
      existing_password_changed: false, password_initialized: accountCreated,
      audit_warning: auditError?.message || null
    });
  } catch (error) {
    return reply({ error: error instanceof Error ? error.message : "INTERNAL_ERROR" }, 500);
  }
});