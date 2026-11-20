# CountFlow — Architecture & Operating Model

**Scope:** `companies/company-2/Counting/` only.  
**Backend:** Supabase project `rawaea-staging` — `hfzznsiprnwkpayskzhu`.  
**Isolation rule:** Never connect CountFlow to SMART ERP (`fiilmooggumokxanwiyx`) or load RAWAEA's `companies/company-1/core.js`.

## 1. Engagement and concurrent-operation model

CountFlow is the inventory-counting service provider's internal operating system. Contracting organizations are temporary and variable engagements, **not a permanent customer master**.

The existing schema already supports this separation without adding another business table:

- **Engagement workspace = one `count_projects` row.** `count_projects.name` stores the contracting party name (e.g. Carrefour); `code` is the unique engagement reference. It is not a canonical customer record and the same company name may appear in many separate engagements.
- **Named count operation = one `count_sessions` row.** `count_sessions.name` stores the exact operation/task name (e.g. "جرد شهر يناير 2027 - كارفور فرع المعادي"). Each operation belongs to one engagement workspace. A workspace may contain multiple named operations over its lifecycle.
- **Workforce = `count_members` + `count_assignments`.** Membership is scoped to the engagement; an assignment binds a member to a specific operation and optionally to a location. Removing an assignment removes that member from that operation only. It does not delete the Auth account, engagement membership, historical count entries, or their audit trail.
- **Independent repeat contracts.** A second Carrefour count is created as a new engagement workspace with a new unique code; it must not reuse or merge the earlier engagement's catalog, sites, team assignments, expected balances, evidence, or count history.
- **Concurrent work.** Multiple operations across multiple engagement workspaces may be active concurrently. Each operation has its own team assignments, count entries, imports, reconciliation, exports and status history.

The first engagement/operation pair is created atomically by `public.count_create_engagement(p_client_name,p_engagement_code,p_operation_name)`. The database transaction inserts the engagement workspace and the first planned operation together; a failed second insert cannot leave an incomplete engagement. The RPC is SECURITY INVOKER, requires `auth.uid()`, and is executable by `authenticated` but not `anon`.

The master and supervisor applications both use that contract. A new operation added later within an existing engagement is a new `count_sessions` row; the operation register provides historical search, status/date filters, sorting, paging, detail preview, printing, and server-generated exports.

## 2. Owner identity and authority boundary

The platform owner identity is reserved as `owner@rawaea.com`. Global authority is server-enforced and never derived from browser metadata:

- `counting_private.is_platform_owner()` recognizes only the authenticated Supabase Auth identity whose email is exactly `owner@rawaea.com` and whose email has been confirmed.
- `counting_private.is_member(uuid)` and `counting_private.is_supervisor(uuid)` include this verified platform-owner check, so RLS continues to authorize access through the existing policy contracts for every CountFlow engagement.
- The two server-side functions `counting-provision-member` and `counting-export-session` also accept the verified platform owner; ordinary users still require active supervisor membership in the target engagement.
- Public first-user sign-up was removed from the master login to prevent an arbitrary visitor from taking over initial ownership.
- **The Auth identity itself remains uncreated** in the latest database check (zero users with `owner@rawaea.com`). The owner must be provisioned through Supabase Auth and confirm this email before the owner login and global authority can be exercised. Do not assign one of the legacy Auth users by guess and do not create a password in SQL or chat.

A supervisor can create a new engagement and its first operation from the supervisor app. The database creates the supervisor membership for the authenticated creator. The verified platform owner can manage all engagements, including those created by other supervisors.

## 3. Master dashboard and operation register

The CountFlow master dashboard provides:

- **Engagement directory:** create and select an independent count engagement using the contracting party name and unique engagement code. The initial named count operation is created in the same transaction.
- **Users:** aggregate CountFlow memberships visible to the platform owner, with each row showing the engagement. User provisioning remains scoped to the selected engagement.
- **Operation register:** one searchable historical register across owner-visible engagements. Filters include contracting-party/operation/code search, operation status, and creation-date range. Columns are sortable and results are paginated.
- **Operation detail:** open a specific operation to view its team, current KPIs, import batches, reconciliation result, and export archive; add an existing engagement member or create a new account and assign it to that operation; remove a member from that operation without deleting their account or engagement membership.
- **Import/export/print:** import CSV/XLSX item catalogs and session expected balances using the existing staged CountFlow import RPCs. XLSX/CSV result exports use the server-side `counting-export-session` pipeline. The printable preview presents reconciliation details; the server XLSX remains the complete export artifact.
- **History preservation:** completed operations remain available for review, preview and export. Historical operations cannot be reopened or have their team/import altered from the supervisor UI.
- **Live refresh:** `count_sessions` and `count_members` Postgres Changes events invalidate the dashboard snapshot; the UI re-fetches authoritative rows through RLS. A 30-second visible-page reconciliation remains the fallback.

The supervisor page provides the same operation-level team assignment/removal and account provisioning flow, a searchable historical session register, existing CSV/XLSX staged import, server-side result export, and printable result preview.

## 4. RAWAEA architecture patterns adopted by principle, not by code

The reference implementation was inspected in:

- `companies/company-1/core.js`: `RW_Auth`, `RW_SW`, and `RW_Realtime`.
- `companies/company-1/sw.js` and `register-sw.js`.
- `companies/company-1/warehouse/picker.html` as an example PWA that uses Dexie/IndexedDB and loads the shared core.

Patterns worth adopting:

1. A single app-scoped Supabase client and a clear auth/session lifecycle.
2. A small shared application core with explicit modules and contracts.
3. Service Worker update coordination and deterministic versioning.
4. Static shell/asset caching separated from business data.
5. Realtime events are invalidation signals; consumers re-fetch authoritative rows under RLS.
6. Reconciliation after subscription, after reconnect, on visibility return, and periodically.
7. Offline mutations are persisted locally with unique operation IDs, then replayed idempotently through server-side RPCs.

Patterns that must **not** be copied verbatim:

- RAWAEA `core.js` contains a hard-coded Supabase URL/ref for SMART ERP. Importing it would violate CountFlow isolation.
- RAWAEA's employee/company profile and role model is not the CountFlow tenant/membership model.
- The RAWAEA Service Worker is not a data-sync engine. It keeps HTML/API/runtime network-backed, caches only approved static presentation assets, and does not cache authentication or business records.

CountFlow now has its own `countflow-core.js` and `countflow-sw.js`, configured only for the CountFlow Supabase project and CountFlow app paths. The core creates the CountFlow client, exposes a reusable Postgres Changes + reconciliation helper, reports connectivity, and registers the CountFlow Service Worker. All three CountFlow pages load this core; the master dashboard uses its Postgres Changes helper. The field and supervisor pages retain their existing domain-specific channel handlers for now.

## 5. Offline-first contract — current state and required completion

**Confirmed current behavior:** `countflow.html` stores count operations in native IndexedDB (`countflow-offline-v1`) with `client_event_id` as the key. Online replay uses `count_record_entry` or `count_record_recount_entry`, both designed around idempotent operation IDs.

**Known gaps that remain open:**

- A CountFlow-only Service Worker and manifest have now been added. The worker precaches the three app shells, the core, manifest, icon and the three approved CDN runtime libraries; it uses network-first HTML with cached fallback, caches static assets, and never caches Supabase Auth/REST/Storage/Edge Function responses. This is **implemented but not browser-verified**; first-install offline boot and CDN cache success remain UNKNOWN.
- Queue replay requires the currently loaded session to be active/paused. Once the server moves the session to review/completed, pending local operations can become hidden and non-syncable.
- The retry control currently clears sync errors across all local queue records rather than only the active project/session/member/device.
- There is no per-device server acknowledgement barrier preventing a supervisor from closing a session while an offline device still has unacknowledged local entries.
- Browser-termination recovery, real-device offline boot, and authenticated multi-device synchronization remain unverified.

**Required safe implementation sequence:**

1. **DONE — implementation:** Add a CountFlow-only Service Worker and manifest. Cache only the approved app shell/static dependencies; never cache Auth responses, Supabase API payloads, signed URLs or business records. Browser verification is still required.
2. Preserve IndexedDB operations with project/session/member/device identity, immutable event ID and payload hash.
3. Implement a server-authoritative close barrier: a session cannot be finalized while a registered device has unacknowledged operations, unless the supervisor explicitly revokes/records that device through an audited recovery path.
4. Replay acknowledged queue items through idempotent RPCs without allowing a closed-session write to bypass the state machine.
5. Scope retry and queue display to the exact signed-in user, project, session and device; never bulk-clear unrelated errors.
6. Add authenticated browser E2E tests for first online boot, offline reload, offline entry, browser termination/restart, reconnect, duplicate replay, multi-device concurrency and close-barrier enforcement.

## 6. Realtime contract

RAWAEA's `RW_Realtime` uses Postgres Changes subscriptions and a reconciliation callback. It does not treat the event payload as a trusted business snapshot. CountFlow's admin dashboard now follows that principle for project-scoped session/member events.

CountFlow field/supervisor apps still use their existing private Broadcast contracts in parts of the UI. Prior audit records include Broadcast delivery warnings in the hosted Realtime message path. Do not claim real-time delivery is proven until browser tests confirm it across two authenticated devices. Keep authoritative reads and polling reconciliation as a fallback; do not modify Supabase-managed `realtime.messages` partition internals manually.

## 7. Safety boundaries

- No CountFlow action posts inventory, accounting, cash or ERP transactions.
- No SMART ERP project ref, credentials, tables, RPCs, Edge Functions or domains are used.
- The legacy non-CountFlow objects in `rawaea-staging` remain outside scope and must not be changed as part of this work.
- Never expose a service-role key in a browser.
- Do not create persistent owner/staff identities or use legacy Auth users without a confirmed roster and explicit identity mapping.
- Keep QA data synthetic, CountFlow-only, rollbackable and residue-checked.

## 8. Verification status at LVE-740

- Admin JavaScript syntax: **PASS**.
- Master UI global member/session aggregation: **implemented; browser behavior UNKNOWN**.
- CountFlow Core and Service Worker syntax: **PASS**; build fixture publishes all nine allowlisted files and excludes private artifacts. Real offline boot remains **UNKNOWN**.
- Realtime table publication: **CONFIRMED** for `count_members` and `count_sessions`; live event delivery: **UNKNOWN**.
- Supabase schema/data: **unchanged by this UI update**.
- Owner Auth account: **NOT CREATED / email not yet confirmed**.
- Offline shell boot and safe close barrier: **OPEN / NOT IMPLEMENTED**.
- Cloudflare deployment/domain: **NOT DEPLOYED**.
