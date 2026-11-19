import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

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
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const displayName = String(body.display_name || "").trim();
    const username = String(body.username || email).trim();
    const role = String(body.role || "counter");
    if (!projectId || !email || password.length < 10 || !displayName || !username || !["counter", "auditor", "supervisor"].includes(role))
      return reply({ error: "INVALID_INPUT" }, 400);
    const { data: membership, error: membershipError } = await admin.from("count_members")
      .select("role,status").eq("project_id", projectId).eq("user_id", authData.user.id).maybeSingle();
    if (membershipError || membership?.role !== "supervisor" || membership?.status !== "active")
      return reply({ error: "SUPERVISOR_REQUIRED" }, 403);
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { counting_display_name: displayName }
    });
    if (createError || !created.user) return reply({ error: createError?.message || "USER_CREATE_FAILED" }, 400);
    const { error: insertError } = await admin.from("count_members").insert({
      project_id: projectId, user_id: created.user.id, display_name: displayName, username, role, status: "active"
    });
    if (insertError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return reply({ error: insertError.message }, 409);
    }
    await admin.from("count_audit_log").insert({
      project_id: projectId, actor_id: authData.user.id, action: "member.created",
      entity_type: "member", details: { email, username, role }
    });
    return reply({ ok: true, user_id: created.user.id, username });
  } catch (error) {
    return reply({ error: error instanceof Error ? error.message : "INTERNAL_ERROR" }, 500);
  }
});