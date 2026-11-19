# CountFlow — Architecture & Operating Model

**Scope:** `companies/company-2/Counting/` only.  
**Backend:** Supabase project `rawaea-staging` — `hfzznsiprnwkpayskzhu`.  
**Isolation rule:** Never connect CountFlow to SMART ERP (`fiilmooggumokxanwiyx`) or load RAWAEA's `companies/company-1/core.js`.

## 1. Tenant and concurrent-count model

The existing CountFlow schema already provides the correct base hierarchy:

- **Client / customer organization = `count_projects` row.** Examples: Carrefour, Panda, a non-food retail complex, or a garment factory. Each project owns its catalog, location hierarchy, team memberships, assignments, devices, expected balances, evidence and audit scope.
- **A physical stocktake / count engagement = `count_sessions` row.** A client can have several sessions over time, and different client projects can have active sessions at the same time.
- **Workforce = `count_members` + `count_assignments`.** Membership is project-scoped; assignments are session- and optionally location-scoped. A counter assigned to one customer does not inherit access to another customer's data.
- **The same Auth identity can be a supervisor in several projects.** The existing `count_bootstrap_project_owner` trigger creates a supervisor membership for the Auth identity that creates a project. The owner account should create every customer project it is responsible for; customer supervisors and counters are provisioned within their own project.

This allows parallel execution without combining customer catalogs or count results. A project is not a single count operation: it is the tenant boundary for a client; sessions represent count operations.

## 2. Owner identity and authority boundary

The master UI already supports email/password sign-in and a first-owner sign-up path. An authenticated identity with no CountFlow memberships can create its first project; the database trigger then creates its supervisor membership.

Important distinction:

- This is currently a **project-owning supervisor identity**, not a separate platform-wide super-admin role.
- It can manage all projects in which it has an active supervisor membership. To maintain the intended owner-wide view, create each customer project using the same owner Auth identity.
- A user with a non-supervisor membership only is rejected from the master UI.
- No owner Auth identity has been created or bound in the current database. Do not assign one of the pre-existing legacy Auth users by guess. The owner email must be confirmed, then the user signs in or completes the explicit sign-up flow. The password is entered by the owner in the application and must not be shared in chat.
- A future platform-level owner role, capable of managing projects created by unrelated supervisors, requires a dedicated server-authoritative role contract and RLS changes. It must not be simulated by trusting user metadata or an email string in browser code.

## 3. Master dashboard global views

The master page now provides:

- **Client/project directory:** create and select customer projects. The selected project remains the context for product catalog, location hierarchy, member provisioning, planned sessions and audit.
- **Users:** aggregate membership rows across all projects visible to the signed-in owner, with the customer/project displayed on each row. The add-user form provisions into the currently selected project only.
- **Current count operations:** aggregate sessions across all owner-visible projects. Active, planned, paused and review sessions are visible together; completed/closed sessions are separated into history. Selecting a row changes the master context to that customer project.
- **Pagination:** project, member and session reads are paginated/batched instead of relying on the former 200-project ceiling or a single small response.
- **Live refresh:** `count_sessions` and `count_members` Postgres Changes events invalidate the dashboard snapshot; the UI re-fetches through RLS. A 30-second visible-page reconciliation is retained as a fallback. Realtime delivery still requires authenticated browser verification under concurrent users.

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

CountFlow should eventually have its own `countflow-core.js` and `countflow-sw.js`, configured only for the CountFlow Supabase project and CountFlow app paths.

## 5. Offline-first contract — current state and required completion

**Confirmed current behavior:** `countflow.html` stores count operations in native IndexedDB (`countflow-offline-v1`) with `client_event_id` as the key. Online replay uses `count_record_entry` or `count_record_recount_entry`, both designed around idempotent operation IDs.

**Known gaps that remain open:**

- No CountFlow Service Worker/manifest currently guarantees offline shell boot after a fresh navigation or browser restart.
- Queue replay requires the currently loaded session to be active/paused. Once the server moves the session to review/completed, pending local operations can become hidden and non-syncable.
- The retry control currently clears sync errors across all local queue records rather than only the active project/session/member/device.
- There is no per-device server acknowledgement barrier preventing a supervisor from closing a session while an offline device still has unacknowledged local entries.
- Browser-termination recovery, real-device offline boot, and authenticated multi-device synchronization remain unverified.

**Required safe implementation sequence:**

1. Add a CountFlow-only Service Worker and manifest. Cache only the approved app shell/static dependencies; never cache Auth responses, Supabase API payloads, signed URLs or business records.
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
- Realtime table publication: **CONFIRMED** for `count_members` and `count_sessions`; live event delivery: **UNKNOWN**.
- Supabase schema/data: **unchanged by this UI update**.
- Owner Auth account: **NOT CREATED / email not yet confirmed**.
- Offline shell boot and safe close barrier: **OPEN / NOT IMPLEMENTED**.
- Cloudflare deployment/domain: **NOT DEPLOYED**.
