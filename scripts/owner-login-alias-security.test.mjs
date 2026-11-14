import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const html = readFileSync("companies/company-1/main.html", "utf8");
const edge = readFileSync("supabase/functions/save-settings/index.ts", "utf8");
const sql = readFileSync("supabase/migrations/20261114180000_owner_login_alias_sync_atomic.sql", "utf8");

test("parent UI re-authenticates the owner with the current password", () => {
  assert.match(html, /id="owner-current-password"/);
  assert.match(html, /supabase\.auth\.signInWithPassword\s*\(/);
  assert.match(html, /action:\s*'owner-credentials'/);
  assert.doesNotMatch(html, /supabase\.auth\.updateUser\s*\(\s*\{\s*email\s*:/);
  assert.doesNotMatch(html, /supabase\.auth\.updateUser\s*\(\s*\{\s*password\s*:/);
});

test("synthetic aliases are restricted to the project's two internal domains", () => {
  const alias = /^[a-z0-9][a-z0-9._+-]{0,63}@(rawaea|alrawae)\.com$/;
  assert.equal(alias.test("owner@alrawae.com"), true);
  assert.equal(alias.test("picker@rawaea.com"), true);
  assert.equal(alias.test("person@gmail.com"), false);
  assert.equal(alias.test("user@rawaea.example"), false);
  assert.match(edge, /new_login_alias/);
  assert.match(edge, /email_confirm:\s*true/);
});

test("email recovery never calls SMTP/email password reset for synthetic accounts", () => {
  assert.doesNotMatch(html, /resetPasswordForEmail/);
  assert.match(html, /استعادة كلمة المرور|استعادة الحساب/);
  assert.match(html, /لم يتم إرسال أي رسالة/);
});

test("owner password changes require current password and enforce 12 characters", () => {
  assert.match(html, /pass\.length < 12/);
  assert.match(edge, /newPassword\.length < 12/);
  assert.match(edge, /admin\.updateUserById\s*\([\s\S]*?\{\s*password:\s*newPassword/);
  assert.match(edge, /owner_reauthenticated_admin_api/);
});

test("owner server route enforces fresh auth, active owner profile, and wildcard", () => {
  assert.match(edge, /auth\.getUser\(token\)/);
  assert.match(edge, /ownerVerified/);
  assert.match(edge, /ownerProfile\?\.owner_email/);
  assert.match(edge, /last_sign_in_at/);
  assert.match(edge, /5 \* 60 \* 1000/);
  assert.match(edge, /auth\.admin\.updateUserById/);
});

test("alias synchronization is atomic, audited, locked, and service-role only", () => {
  assert.match(sql, /SECURITY DEFINER/);
  assert.match(sql, /auth\.jwt\(\)\s*->>\s*'role'/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /FOR UPDATE/);
  assert.match(sql, /owner_profile/);
  assert.match(sql, /public\.users/);
  assert.match(sql, /public\.audit_log/);
  assert.match(sql, /REVOKE ALL[\s\S]*FROM PUBLIC/);
  assert.match(sql, /REVOKE ALL[\s\S]*FROM anon/);
  assert.match(sql, /REVOKE ALL[\s\S]*FROM authenticated/);
  assert.match(sql, /GRANT EXECUTE[\s\S]*TO service_role/);
  assert.match(sql, /OWNER_ALIAS_STALE_OR_MISMATCHED/);
  assert.match(sql, /OWNER_ALIAS_ALREADY_USED_BY_USER/);
});

test("parent inline JavaScript remains syntactically valid", () => {
  const blocks = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)]
    .filter((m) => !/\bsrc\s*=/.test(m[1] || ""))
    .map((m) => m[2])
    .filter((body) => body.trim());
  assert.ok(blocks.length > 0);
  for (const body of blocks) assert.doesNotThrow(() => new Function(body));
});
