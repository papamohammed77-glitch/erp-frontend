# RAWAEA ERP — SAVE-ITEM 401 / STALE AUTH SESSION FORENSIC REPORT
**Date:** 2026-10-30  
**Repository:** `papamohammed77-glitch/erp-frontend`  
**Branch:** `main`  
**Supabase project:** `SMART ERP` (`fiilmooggumokxanwiyx`)  
**Status:** ROOT CAUSE CONFIRMED · CENTRAL SOURCE PATCH COMMITTED · PRODUCTION E2E PENDING

## 1. Executive finding

The `401 UNAUTHORIZED_ASYMMETRIC_JWT` responses were caused by the warehouse data-entry app sending an expired user access token retained in the shared `RW_Auth.currentSession` snapshot.

The evidence does **not** support treating ES256 itself as unsupported, and does not support the earlier claim that a missing `apikey` header caused these failures.

## 2. Evidence from current Production logs

Supabase `function_edge_logs` for `POST /functions/v1/save-item` show:

- The same user access token used `ES256` and the same signing-key identifier across successful and failed requests.
- Token issue time: **2026-10-30 11:20:08 UTC** (13:20:08 Africa/Cairo).
- Token expiry: **2026-10-30 12:20:08 UTC** (14:20:08 Africa/Cairo).
- Requests returned **200** at 11:31, 11:37 and 11:41 UTC while the token was still valid.
- Requests returned **401 / UNAUTHORIZED_ASYMMETRIC_JWT** at 12:31, 12:34 and 12:35 UTC, after the token had expired. The log metadata retained the same issue/expiry values.
- A browser refresh-token request returned **200** at 12:42:26 UTC (14:42:26 Africa/Cairo).

The failure occurred at the gateway JWT validation stage; it was not an authorization failure returned by the `save-item` handler.

## 3. Source-level root cause

Current `main` source before the fix:

- `companies/company-1/core.js` creates the shared Supabase client.
- `RW_Auth.init()` and `doLogin()` copy the current session into the private `currentSession` variable.
- `RW_Auth.getToken()` synchronously returns `currentSession.access_token`.
- There was no `supabase.auth.onAuthStateChange` subscription to replace that local snapshot when supabase-js refreshed the persisted session.

Therefore the SDK could refresh the browser session while the shared application state continued returning the previous, expired access token to manual Edge Function callers.

Supabase JavaScript reference confirms that `onAuthStateChange` emits `TOKEN_REFRESHED` with the updated session and supports a synchronous callback:
https://supabase.com/docs/reference/javascript/auth-onauthstatechange

## 4. Surgical source correction applied

**File:** `companies/company-1/core.js`  
**Location:** immediately after `clearState()` inside `RW_Auth`.

Added a single central auth-state subscription that:
- Replaces `currentSession` and `currentUser` whenever Supabase emits a session event.
- Clears profile identity if a different authenticated user is observed.
- Calls `clearState()` on `SIGNED_OUT`.
- Performs no asynchronous Supabase calls inside the auth callback.

**Commit on main:** `260dd402ffa527dd6b5dc0980e523846f00172de`  
**New core.js blob:** `3cf992d8179a374b60622faba9e60dde43c9a21e`

No changes were made to:
- `warehouse/data.html`
- `save-item` Edge Function
- `verify_jwt`
- RLS, database schema, roles, or permissions
- Any other application file

## 5. Static verification

- Re-fetched `core.js` from `main` after commit: **PASS**.
- Confirmed the listener is present once, after `clearState()`: **PASS**.
- Parsed the complete updated JavaScript source with the JavaScript parser: **PASS**.
- Reviewed the commit diff: only the intended central auth listener was added to `core.js`.
- GitHub commit status checks: none were reported for this commit.

## 6. Production and E2E status — not yet verified

The following must remain explicitly open:

- Cloudflare Pages deployment of commit `260dd402...`: **UNKNOWN**; the served artifact could not be fetched through the available verification path.
- Authenticated browser test of the `TOKEN_REFRESHED` event updating `RW_Auth.getToken()`: **PENDING**.
- A post-deployment `save-item` request using the refreshed token: **PENDING**.
- Read-after-write verification for a real, authorized test item: **NOT RUN**.
- Post-fix Production log confirmation: **PENDING**.

The connected local browser was not available in this execution context, so no browser interaction or live save test is claimed.

## 7. Guardrails

- Keep `save-item verify_jwt = true`.
- Do not disable JWT verification.
- Do not put a secret/service-role key in browser code.
- Do not add an `apikey` header as a purported fix for this incident without separate evidence; successful and failed calls in the examined log sample share the same API-key metadata absence, while the decisive difference is that the failed requests used an expired user token.
- Do not create a test item in Production without an explicitly approved, identifiable test record and a cleanup/verification plan.

## 8. Next verification sequence

1. Confirm Cloudflare Pages serves the updated `companies/company-1/core.js` from `main`.
2. Load the warehouse data-entry app in an authenticated browser session.
3. Verify that after `TOKEN_REFRESHED`, the shared `RW_Auth.getToken()` reflects the new token without printing or exposing the JWT.
4. Exercise a safe, read-only authenticated request through the same central caller path.
5. Only then run an approved save test, capture the response status, and verify the record by re-reading it.
6. Query Supabase logs again and confirm no expired-token 401 for the tested request.
7. Update this report and `CURRENT_STATE.md` with the actual deployment and E2E evidence.

**Closure decision:** Root cause is confirmed and the shared-source correction is committed to `main`; the incident is **not operationally closed** until deployment and authenticated browser verification pass.
