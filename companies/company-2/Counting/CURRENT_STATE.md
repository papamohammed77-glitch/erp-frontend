# CountFlow — CURRENT_STATE

**Last Verified Event:** `LVE-2026-11-20-744-CountFlow-Engagement-Operation-Workflow`  
**Date:** 2026-11-20  
**Repository:** `papamohammed77-glitch/erp-frontend`  
**Application path:** `companies/company-2/Counting/`  
**Supabase project:** `rawaea-staging`  
**Project ref:** `hfzznsiprnwkpayskzhu`

## 1. Current source snapshots

| Artifact | Current Git blob SHA |
|---|---|
| `countflow-admin.html` | `79b33ded97a355a33a2eb1b6cd84441e9b78cebb` |
| `countflow.html` | `83969d45a0f446e5f9e74f8de2d943635484d3cd` |
| `Countflow-supervisor.html` | `409fb71b9bd92bfe1ea7a9f19bc18b4acc3742f2` |
| `README.md` | `fc98f54bb092ba68b9872c1c1d69524d4caf6241` |
| `ARCHITECTURE.md` | `0183e7cd6fe15c32c1df07b7e3f88e56e0b8a999` |
| `DEPLOYMENT.md` | `478fafbf6671e7d0d8b781baf9dc0414c9449bec` |
| `scripts/build-pages.sh` | `865629e8f1061f403f426f9c712d0ec00fdd9793` |
| `index.html` | `707a5a0f18674a93cab811be23ea9a13abb4a91b` |
| `countflow-core.js` | `43395393093ba9bba94959dc1cc71457327a4e5e` |
| `countflow-sw.js` | `7d8df96c832360817adcfa34f892bbf5a92f4b2a` |
| `manifest.webmanifest` | `dc5fa4e24234586c398da958e5a0463d7316d7fb` |
| `countflow-icon.svg` | `7540be49299b57849a8cb25a163981730571d6a5` |
| `_headers` | `799b5b51882d12ed2503fb41ad04633145d24468` |
| `functions/counting-provision-member/index.ts` | `22851e4653563af347d562cb9ccf86e408fb34a1` |
| `functions/counting-export-session/index.ts` | `511a28a4e4eeaa1e7e452db036ef374af4122acb` |
| `database/migrations/20261120170000_countflow_platform_owner_verified_email.sql` | `b59d12d4047ed2ce8ab5b0528b93fde6cd3a8591` | 
| `database/migrations/20261120171000_countflow_license_settings_unbounded_emails.sql` | `09dd07432dbec5a71cfeaa09198abb1d9ff640af` |
| `database/migrations/20261120200000_countflow_atomic_engagement_and_operation_create.sql` | `725ce36cdd06fde99e45ca6d4c7ce6539e2cfde2` |
| `database/migrations/README.md` | `ee02b814026f7f30a3fbeb9356c85085dde77d53` |

## 2. Verified Supabase structure

- 21 `count_*` tables; all 21 have RLS enabled.
- 70 CountFlow RLS policies.
- 72 validated foreign-key constraints; no unvalidated CountFlow constraints and no CountFlow table without a primary key.
- Zero grants to `anon`; zero authenticated TRUNCATE/TRIGGER/REFERENCES grants.
- `count_entries` client grants are SELECT and INSERT only (append-only).
- `count_assignments` has one `NULLS NOT DISTINCT` unique scope index, enabling atomic upsert for both global and location-specific assignments.
- Administrative audit triggers capture project/member/session/assignment/recount/rule/device/evidence changes; heartbeat-only device/member updates are suppressed. Export completion is explicitly logged with the authenticated supervisor and file integrity metadata.
- Expected balances must use the product's base unit and are locked after the first count or reconciliation.
- Reconciliation runs store `entry_count_snapshot`; approval checks the latest run, unchanged entry count, zero uncounted positions, no open recount tasks, and no unresolved critical alerts. Approval moves the session to `review` and freezes further count inserts.
- CountFlow private Broadcast authorization is scoped by project/session/member topic; live broadcast triggers are attached to operational tables.

## 3. Deployed Edge Functions

| Function | Version | JWT | State |
|---|---:|---|---|
| `counting-provision-member` | 4 | Required | ACTIVE |
| `counting-export-session` | 7 | Required | ACTIVE |

Both functions also authorize the platform owner only when the authenticated Auth email is owner@rawaea.com and is confirmed; ordinary supervisors still require active membership in the target engagement. The export function creates a 13-sheet XLSX or detailed CSV, stores the artifact in the private `counting-exports` bucket, and records SHA-256, size, row count, and a signed URL. All UI exports now use this server pipeline; it also includes import rejection details, evidence image links, device/presence, and session audit history. Successful export is itself written to the audit log; failed completion removes orphaned Storage objects.

## 4. Completed behavior and regression tests

Latest applied CountFlow migration by live ledger version: `20261120004422`, name `20261120200000_countflow_atomic_engagement_and_operation_create`. The owner/license migrations are recorded at live versions `20261119232523` and `20261119232615`; ledger versions are not identical to the Git source filename timestamps. See database/migrations/README.md for reconciliation.

- Continuous camera scanning (detection throttled to 200 ms), location barcode selection, repeated same-product scan quantity increment, and a save-before-switch safeguard.
- Import pipeline uses 1,000-row staging chunks and detailed row outcomes; location reads/import mapping are paginated.
- Base-unit conversion snapshots on count entries; reconciliation and exports use normalized quantities.
- Automatic quantity/repeat-scan alerts and automatic variance alerts after reconciliation.
- Recount tasks, review/approval, and finality/immutability gates.
- All XLSX/CSV exports use the server-side pipeline; the browser no longer builds large workbooks. The function has configured row limits (150k per major dataset, 250k combined) that have not yet been load-tested.
- Supervisor logout control; assignment upsert is atomic and duplicate-safe.

Executed seven SQL regression suites (all rollback-only; no persistent test data):
1. `tests/countflow_core_integration_rollback.sql`
2. `tests/countflow_unit_recount_rollback.sql`
3. `tests/countflow_anomaly_rollback.sql`
4. `tests/countflow_approval_finality_rollback.sql`
5. `tests/countflow_assignment_upsert_rollback.sql`
6. `tests/countflow_expected_balance_snapshot_rollback.sql`
7. `tests/countflow_admin_audit_rollback.sql`

Final residue check: zero CountFlow projects, members, sessions, products, entries, exports, and zero temporary test users.

## 5. Isolation and account state

The applications call CountFlow tables only and do not call ERP stock, sales, treasury, or accounting tables. However, the Supabase project itself still contains 70 non-CountFlow public tables, 24 Edge Functions, and 1,868 pre-existing Auth users. Six legacy functions have `verify_jwt=false`; none are CountFlow functions. These legacy objects were not modified because their ownership/usage is outside this task. Thus current separation is logical at the application/data-access level, not a physically clean Supabase project boundary.

There are currently zero CountFlow members and zero CountFlow projects. No existing Auth identity was assigned a CountFlow role. Permanent staff accounts were not fabricated because no employee roster/emails were supplied. The first supervisor must be created in Supabase Auth; after that, the supervisor app can create members through `counting-provision-member`.

## 6. Verification limits / next execution gates

- Playwright non-destructive smoke tests are prepared under `tests/e2e/` but were not run: no permanent supervisor/counter credentials or confirmed deployed app origin were available.
- The large export Edge Function is deployed and source-matched, but a real authenticated XLSX/CSV export has not yet been exercised end-to-end.
- The 90,000-row import rollback test was independently re-run on 2026-11-19 and passed; the 90,000-row export, camera-device compatibility matrix, offline queue recovery after browser termination, WebSocket Broadcast delivery under real concurrent clients, and 30–300 user load tests remain unverified.
- Global Supabase security advisor still reports 65 ERROR and 15 WARN on legacy objects; none are CountFlow findings. Performance advisor's single WARN concerns duplicate indexes on `public.erp_operation_registry`, outside CountFlow.
- Do not modify or delete legacy ERP tables/functions as part of CountFlow work. Do not create persistent accounts without a confirmed roster. Do not run any test that writes to ERP inventory, treasury, or accounting.

## 7. Safe continuation order

1. Obtain/confirm the actual CountFlow supervisor and counter roster and the published app origin.
2. Create the first supervisor Auth user, create the first CountFlow project, then provision named users through the supervisor app.
3. Run Playwright smoke tests with environment-injected credentials and a designated assigned location/product; the scan test must not click Save.
4. Run a dedicated, reversible CountFlow-only import test with representative CSV/XLSX and then a 90k-row load test in an isolated dataset.
5. Exercise one real authenticated server export and verify workbook sheets, signed URL, SHA-256, and export history.
6. Run concurrent Broadcast/load tests before making any scale-readiness claim.


## 8. LVE-2026-11-19-734 — Current verified continuation

**Operational source HEAD:** main / 3e963eaddb286d6e805e9c8028075df6b20387f5  
**CountFlow path delta:** 24 commits after the previous local state pin; 8 CountFlow files changed.  
**Live Supabase ledger:** 53 CountFlow migrations; 14 tracked SQL artifacts; 39 applied migrations have no standalone SQL source in the current Git folder. The two recent location/heatmap migrations 20261119195107 and 20261119195202 are absent from Git. The 19195630 source file maps to live ledger version 19195750. See Report734.

### Reverified tests (rollback-only)
- 90,000-row import: PASS; 90,000 submitted/staged/accepted/products, 90 chunks, one transaction ending in ROLLBACK.
- Location hierarchy/heatmap: PASS; cycle guard passed, 2 count events, path WH / A-01, 1 counted position, 100% coverage, refresh stable; transaction ended in ROLLBACK.
- Reconciliation after both runs: every one of the 21 count_* tables had exactly 0 rows; Auth remained 1,868; no QA identities remained.

### Newly confirmed P1/P2 gaps — OPEN
1. Critical state tables still allow authenticated supervisor direct DML that bypasses their stronger RPC contracts:
   - count_reconciliation_runs UPDATE has a supervisor policy and no audit or state-guard trigger.
   - count_sessions UPDATE/DELETE has a supervisor policy; no server-side state-transition guard.
   - count_recount_tasks UPDATE/DELETE can bypass count_review_recount_task; audit exists but no transition guard.
   - count_import_rows UPDATE/DELETE has no trigger; count_commit_import_batch trusts row_status='staged' and does not fully revalidate the staged row.
   - count_alerts UPDATE is used directly by the supervisor UI and has no audit trigger or mandatory resolution reason.
2. Offline queue entries are tied to the currently loaded active/paused session. After approval moves the session to review, Counter no longer loads it and the local queue becomes hidden/non-syncable. The supervisor close gate has no per-device sync acknowledgement.
3. Supervisor setSession(status) reloads sessions before its automatic export, then reads the mutable global session.id. It can export the wrong session or throw after the close succeeds.
4. retryQueueBtn clears sync_error on all IndexedDB queue records, not only the current project/session/member.
5. counting-provision-member may return success with audit_warning after the Auth/password mutation if the audit insert fails.
6. Counter location loading has a 20,000-row hard stop without an explicit overflow error.

### Operational limits
- No CountFlow project/member/supervisor account exists.
- No real staff roster or confirmed app origin was supplied; do not assign any of the 1,868 legacy Auth users.
- No authenticated Browser E2E, real server export, physical camera test, cross-device Realtime test, or load test was performed.
- No DDL, persistent DML, ACL/RLS change, Edge deployment, or non-count_* write was performed.

### Next gate
Prepare and obtain approval for CS-CF-734-A/B: server-authoritative session/reconciliation/recount/import/alert state transitions plus offline queue close-handshake and stable export session ID. Do not apply until the exact change set, rollback, and acceptance tests are approved.


---

# LVE-2026-11-19-735 — CountFlow security containment checkpoint
**Report:** https://github.com/papamohammed77-glitch/rawaie-erp-New/blob/main/doc/Draft/Reprots/Report735_DAILY_CTO_SECURITY_BUYER_COUNTFLOW_20261119.md

## Current live state
- Project rawaea-staging ref hfzznsiprnwkpayskzhu, ACTIVE_HEALTHY.
- CountFlow: 21 count_* tables, 70 policies, 72 validated FKs; all 21 RLS enabled; no anon grants; all CountFlow tables empty; count_projects=0; count_members=0.
- Auth users 1,868; no CountFlow memberships or supervisor bootstrap identity confirmed.
- Two CountFlow Edge Functions remain JWT-required and source-matched.
- 2,027 Realtime warning attempts; realtime.messages partitioned parent has no child partitions.

## New P0 security blocker
The same Supabase project contains legacy ERP objects:
- 65 public tables outside CountFlow have RLS disabled.
- 56 legacy tables have anon DML grants.
- public.users has 1,871 rows, includes password_hash/permissions/role/auth_id columns, RLS disabled, and anon SELECT/INSERT/UPDATE/DELETE/TRUNCATE.
- role_permissions and categories also have anon CRUD.
- post_inventory_adjustment_atomic, receive_purchase_atomic, save_sales_invoice_atomic are SECURITY DEFINER and executable by anon; their actor lookup trusts p_user_email rather than binding it to auth.uid().
No values from password_hash or personal records were read; no RPC was called; no exploit was performed.

**Decision:** CountFlow is separate from SMART ERP by project ref, but rawaea-staging is not cleanly isolated from legacy ERP. Do not deploy CountFlow, provision users, or run write tests until an owner-approved containment design is implemented. Do not modify legacy objects without explicit approval.

## Other P1s retained from LVE734
- Direct authenticated DML on count_sessions, count_reconciliation_runs, count_recount_tasks, count_import_rows, count_alerts, count_import_batches bypasses stronger RPC/state guards.
- count_generate_recount_tasks accepts approved runs although count_reconcile_session rejects a new run when an approved run exists.
- Counter queue becomes hidden after session enters review/completed; retryQueueBtn clears sync_error globally.
- Supervisor setSession reloads sessions before exporting, so global session can point elsewhere/null.
- Broadcast sends are failing at realtime.messages partition layer; no child partitions; heatmap polling alone does not refresh all dashboard panels.
- No Service Worker/manifest in Counter or Supervisor; IndexedDB queue does not prove offline boot/recovery.
- 46 of 60 CountFlow/Counting migration ledger entries do not have independent SQL artifacts in the migration directory/archive is not replayable.

## No execution
No code, schema, ACL, RLS, account, deployment, or business-data changes were made. No new tests were run. Readiness remains BLOCKED for operation; read-only audit/documentation only.


**Documentation-only follow-up after LVE735:** Report735 and the LVE735 state/memory addenda were saved. The operational repo then received commit 2676526ee4214ae98aa89742b48cf40172cd1976 updating only companies/company-2/Counting/CURRENT_STATE.md; no app code, SQL migration, schema, ACL, or business data changed. The source-code baseline used for the audit remains 4f7fba271d35d463364a5659f8e181dabad41215.


---

## LVE-2026-11-20-736 — Independent CountFlow master and canonical app names

**Date:** 2026-11-20  
**Scope:** CountFlow only — `companies/company-2/Counting/` and Supabase project `rawaea-staging` (`hfzznsiprnwkpayskzhu`).

### Confirmed repository changes
- Renamed `Counter.html` to `countflow.html`; file contents were preserved byte-for-byte at rename time (blob `93ad77a682585b8ec04cdcf224e2ac81b28cb180`).
- Renamed `Counter-supervisor.html` to `Countflow-supervisor.html`; file contents were preserved byte-for-byte at rename time (blob `11101374a8f27d78d042f750b162dba9303174b6`).
- Removed the superseded filenames only after the canonical copies were committed. Directory listing confirms only the canonical names remain.
- Created `countflow-admin.html`, an independent Arabic RTL master UI for CountFlow. It authenticates with Supabase Auth and uses only the existing `count_*` contracts: project bootstrap, product catalog CRUD/activation, member provisioning through the existing JWT-protected `counting-provision-member` Edge Function, location hierarchy, planned session creation, and audit viewing.
- First-owner bootstrap is supported: an authenticated identity with no CountFlow memberships can create its own project; the existing `count_bootstrap_project_owner` trigger creates its active supervisor membership. Existing non-supervisor memberships are denied.
- Added the master UI to README and updated canonical app links. No link to RAWAEA `main.html`, `core.js`, or `rawaea-erp.pages.dev` was added.

### Verification
- JavaScript syntax compilation of the master page script: **PASS** (one inline script block).
- `tests/rollback-smoke.sql` on `rawaea-staging`: **PASS**. Owner bootstrap, entry idempotency, assignment boundary, recount creation/entry/review, reconciliation approval/freeze, anonymous RPC denial, and append-only ledger checks passed. Entire transaction rolled back.
- `tests/countflow_core_integration_rollback.sql` on `rawaea-staging`: **PASS**. Import preview/commit (2 accepted, 1 rejected), assignment boundary, entry idempotency, recount override and reconciliation KPI assertions passed. Entire transaction rolled back.
- Post-test row counts: `count_projects=0`, `count_members=0`, `count_products=0`, `count_sessions=0`, `count_entries=0`, `count_audit_log=0`; `auth.users=1868` unchanged.
- No persistent QA identities or operational fixtures were created.

### Not yet verified / remaining gates
- **UNKNOWN:** real browser E2E for sign-in, first-owner sign-up, master forms, field app and supervisor app; static JS syntax compilation is not a browser test.
- **UNKNOWN:** whether public Auth sign-up is enabled and whether email confirmation is required in the current Supabase Auth settings.
- **NOT DEPLOYED:** no Cloudflare Pages project, custom domain, DNS, or deployment configuration was changed. The final CountFlow domain remains to be selected and configured independently.
- **NOT CHANGED:** no Supabase schema, ACL, RLS, Auth account, Edge Function deployment, Storage bucket, or persistent business row was modified.
- **OUT OF SCOPE:** the 65 legacy non-CountFlow tables and their broad exposure in `rawaea-staging` remain untouched; no connection or operation was made against SMART ERP (`fiilmooggumokxanwiyx`).

### Current readiness
- Repository rename and initial master UI: **CONFIRMED**.
- Existing CountFlow transactional core rollback suites: **PASS**.
- Full operational readiness and production publication: **BLOCKED pending browser E2E, first-owner/Auth configuration verification, remediation of the CountFlow-specific P1 workflow gaps already recorded above, and independent domain setup**.

- Added `index.html` as the CountFlow domain root entry (redirects to the master dashboard), `_headers` with baseline browser security headers, and `DEPLOYMENT.md` with the separate Cloudflare Pages configuration. README links the deployment guide.
- Current Pages output directory is documented as `companies/company-2/Counting`; no Cloudflare project or DNS was changed.


## LVE-2026-11-20-737 — Closed-session export target integrity

- Fixed the confirmed mutable-global bug in `Countflow-supervisor.html`: closing a session previously called `loadSessions()`, which could replace the global `session` before the post-close entry-count/export calls. The export could therefore target another session or fail when no eligible session remained.
- `setSession` now captures the exact `targetSessionId` before asynchronous work and uses it for the close update, post-close entry count, and server export.
- `downloadServerExport` and `loadExportHistory` now accept an explicit session ID while retaining their existing current-session default for normal user-initiated exports.
- Static JavaScript compilation of the updated supervisor page: **PASS**.
- Browser export flow and signed-file download: **UNKNOWN / not run**; no authenticated browser session or persistent CountFlow project exists.
- No database schema/data/ACL/RLS change was required.


## LVE-2026-11-20-738 — Public Pages artifact allowlist

- Added `scripts/build-pages.sh` to construct `dist/` from an explicit allowlist: `index.html`, `countflow-admin.html`, `countflow.html`, `Countflow-supervisor.html`, and `_headers`.
- Database migrations/archive, SQL rollback tests, Edge Function source, README, CURRENT_STATE, and other development artifacts are deliberately excluded from the public Pages output.
- Updated `DEPLOYMENT.md`: Cloudflare Pages build command is `bash companies/company-2/Counting/scripts/build-pages.sh`; output directory is `companies/company-2/Counting/dist`.
- Local `bash -n` syntax check of the build script body: **PASS**. The remote Pages build itself has not been run.
- No Cloudflare Pages project, domain, DNS, or deployment was created or modified.

- Follow-up validation caught and corrected the build script's project-root resolution (`scripts/build-pages.sh` now resolves its parent directory rather than the scripts directory). A local fixture run of the corrected allowlist build: **PASS** — exactly five public files published, zero SQL/Markdown/TypeScript source artifacts copied.

- Final portable-listing revision of the Pages script passed the same isolated fixture test: exactly five allowlisted public files; no SQL/Markdown/TypeScript artifacts leaked into `dist/`.


---

## LVE-2026-11-20-740 — Owner-wide customer and concurrent count operations dashboard

**Scope:** CountFlow UI and documentation only. No Supabase schema/data/ACL/Auth/Edge Function change.

### Repository changes
- Updated countflow-admin.html:
  - Reframed count_projects as customer/client organizations and count_sessions as individual count operations.
  - Added the global **عمليات الجرد القائمة** view, aggregating planned/active/paused/review sessions across all projects visible to the signed-in supervisor identity; completed/closed sessions appear separately.
  - Updated the users view to aggregate membership rows across all projects visible to the signed-in identity and display each user's customer/project.
  - The add-member form still provisions only into the currently selected project; no cross-client membership is granted implicitly.
  - Project reads now use pagination rather than the former 200-project limit. Global member/session reads are batched and paginated.
  - Added Postgres Changes subscriptions for count_sessions and count_members; event messages trigger authoritative re-fetch through RLS. A 30-second foreground reconciliation remains as a fallback.
  - Fixed a project-creation context issue: after creating a new project, the master now selects and loads that exact new project instead of leaving the previous project selected.
- Added ARCHITECTURE.md documenting tenant boundaries, owner model, RAWAEA reference patterns, offline contract, Realtime contract and verification gates.
- Updated README with the customer/operation model and global dashboard behavior (blob 0e088a1f75ffde9964184d5502004c50717760ec).

### Source hashes
- countflow-admin.html: 4b0b8727b5cdcd1d979cc40db046e175c9133cad
- ARCHITECTURE.md: c1ec5b9cfa35d1f5f905f961a52acad88dd726c7
- Admin follow-up project-selection fix commit: f9fbb0af0c4e6e86fa42379db3318a1f99f2854f

### Verification
- Inline admin JavaScript compilation: **PASS** after the global dashboard changes and project-selection fix.
- CountFlow count_members and count_sessions are present in the supabase_realtime publication: **CONFIRMED**.
- Authenticated browser login, multi-project visibility, cross-project member aggregation and actual WebSocket delivery: **UNKNOWN / not run**; no confirmed owner identity or deployed CountFlow origin is available.
- No persistent owner account was created; no pre-existing legacy Auth identity was assigned.
- No Supabase DDL, DML, grants, RLS policies, Auth identities, Edge Functions, Storage objects or Realtime internals were changed.
- No Cloudflare Pages project, DNS or custom domain was created.

### Owner model clarification
- The current database trigger count_bootstrap_project_owner grants supervisor membership to the Auth identity that creates a project.
- The master dashboard can aggregate all projects for which the signed-in identity has active supervisor membership. To administer all customer projects under one owner account, create each customer project using that same identity.
- This is **not yet a separate platform-wide super-admin role** capable of seeing projects created by unrelated supervisors. Such a role needs an explicit server-side identity binding and RLS design; it must not be granted through browser metadata or an email-only condition.
- The CountFlow Auth account is still **NOT CREATED / NOT BOUND**. The owner's email must be confirmed before identity provisioning or assignment.

### Remaining gates
1. Confirm the owner email and complete the first-owner Auth sign-in/sign-up flow; do not share the password in chat.
2. Run browser E2E against the actual CountFlow Pages origin with that account and at least two synthetic customer projects.
3. Verify user isolation by logging in as one customer supervisor and confirming that the other customer is invisible.
4. Continue the P1 offline queue close-handshake work; add a CountFlow-only Service Worker/manifest and offline shell boot without caching business data.
5. Verify cross-device Postgres Changes delivery and keep periodic reconciliation as a fallback.
6. Complete the remaining direct-DML/state-machine and Broadcast audit items before operational readiness is claimed.



---

## LVE-2026-11-20-741 — Independent CountFlow Core and offline PWA shell

### Implemented repository changes
- Added CountFlow-only runtime core: countflow-core.js.
  - Own Supabase URL and publishable key are pinned to rawaea-staging (hfzznsiprnwkpayskzhu); no SMART ERP URL/ref or core.js dependency.
  - Shared client factory used by admin, field and supervisor pages.
  - Reusable Postgres Changes invalidation helper with debounced authoritative refresh, visibility refresh and periodic reconciliation.
  - Connectivity binding helper.
  - Automatic registration of CountFlow-only Service Worker.
- Added countflow-sw.js and manifest.webmanifest plus countflow-icon.svg.
  - Precaches CountFlow app shells and approved runtime libraries (Supabase JS, PapaParse, SheetJS).
  - Network-first navigation with cached shell fallback; cache-first approved static assets.
  - Supabase Auth/REST/Storage/Edge Function requests remain network-only; no business rows, signed URLs or auth responses are cached.
  - Service Worker updates do not force-reload open tabs, avoiding an automatic navigation during field work.
- Integrated CountFlow Core, manifest and Service Worker registration into all three apps.
- Owner dashboard now uses the shared Core Postgres Changes helper for count_sessions/count_members; the 30-second reconciliation fallback remains.
- Updated Pages allowlist to publish the three pages, Core, Service Worker, manifest, icon, index and headers only.
- Updated README, ARCHITECTURE and DEPLOYMENT documentation.

### Verification
- JavaScript syntax compilation: **PASS** for all three inline application scripts, countflow-core.js and countflow-sw.js.
- Pages build fixture: **PASS** — exactly 9 allowlisted browser artifacts; zero SQL/Markdown/TypeScript/private test files in output.
- CountFlow tables count_members and count_sessions are in supabase_realtime publication: **CONFIRMED**.
- Supabase project row check: count_projects=0, count_members=0, count_sessions=0, count_entries=0. No test or owner data created.
- Real browser offline boot, cached CDN availability, PWA installation, offline write/restart/reconnect, and cross-device Postgres Changes delivery: **UNKNOWN / not run**.
- Queue close-handshake and per-device server acknowledgement barrier: **OPEN**. The Service Worker makes the shell available; it does not solve the known post-close queue replay gap.
- No Supabase schema, DML, ACL/RLS, Auth identity, Edge Function, Storage or Realtime-internal change.
- No Cloudflare Pages deployment, DNS or custom domain change.

### Remaining gates
1. Confirm the owner's email; sign up or sign in through the master page. Password is entered only in the app, never in chat.
2. Create each customer project using the same owner identity so the existing bootstrap trigger adds its supervisor membership to each project.
3. Run browser E2E for offline first boot, offline navigation/reload, cached Supabase JS/CDN libraries, queue durability, browser restart and reconnect.
4. Implement the server-authoritative session close barrier before relying on offline counts at session finalization.
5. Verify two-client concurrent operations and user isolation in authenticated browser sessions.
6. Continue direct-DML/state-transition remediation and cross-device Realtime validation before operational readiness.



## LVE-2026-11-20-742 — Corrected CountFlow engagement model and platform owner binding

**Scope:** CountFlow only; Supabase project `rawaea-staging` (`hfzznsiprnwkpayskzhu`).

### Confirmed business-model correction
- External organizations (e.g. Carrefour, Panda, warehouses, factories) are variable contracting parties, not a permanent customer master owned by CountFlow.
- Existing `count_projects` records are now presented as **independent count-engagement workspaces / تكليفات جرد**. The same contracting party can have multiple separate workspaces and sessions over time. No permanent customer registry or client deduplication was introduced.
- The database's unique `count_projects.code` constraint remains: each engagement receives its own unique engagement code. The engagement name may repeat.

### Owner authorization change — applied and verified
- Added `counting_private.is_platform_owner()`, which recognizes only the authenticated Supabase Auth identity whose email is exactly `owner@rawaea.com` and whose email is confirmed.
- Updated `counting_private.is_member(uuid)` and `counting_private.is_supervisor(uuid)` so this verified platform owner can administer all CountFlow workspaces through the existing RLS policy contracts.
- Authorization does not trust `user_metadata`, browser state, or a client-supplied email.
- Migration source: `database/migrations/20261120170000_countflow_platform_owner_verified_email.sql`.
- Database verification: helper function exists; both helper definitions contain the owner gate; projects/members/sessions remain 0.
- **Owner Auth account is NOT created yet:** read-only check found 0 Auth users with `owner@rawaea.com`. No password was generated or stored. Owner login screen now pre-fills this email and public self-signup was removed to prevent arbitrary first-user takeover.

### Master UI correction
- Updated `countflow-admin.html` terminology from permanent customer/project framing to independent count engagements.
- The owner login screen defaults to `owner@rawaea.com`; the unsafe public first-owner signup button/handler was removed.
- Commit: `098bf74d6a0a9e8a6971a5e591294f8e0cd44c0d`; blob: `2009a98015608d84eda96dab8b57a4499f3f18b1`.
- Migration commit: `52e358015b8151e11687bd87d43837bd4d698265`.

### Remaining explicit blockers / UNKNOWN
- The owner Auth identity still needs to be created/invited and its email confirmed through Supabase Auth; this connector does not expose an Auth Admin create/invite-user action. Do not create a fake account or disclose a password.
- The requested editable **إدارة التراخيص** screen and unlimited email-list behavior are not implemented yet. The exact RAWAEA license-screen contract could not be reliably extracted from the very large `company-1/main.html` source through the available GitHub file reader. Do not invent a licensing model or persist an arbitrary email list until its actual field semantics and authorization are verified. This does not authorize modifying SMART ERP.
- The independent engagement model is currently a UI/domain interpretation over the existing `count_projects` workspace table; no permanent client master table was created. Existing data is zero, so no conversion was required.
- Previously recorded P1s remain open: offline queue close/replay barrier, scoped retry reset, direct-DML state-transition bypasses, Realtime Broadcast delivery, import staging revalidation, and browser E2E.
- No browser E2E, Auth login, Cloudflare deployment, or live owner-access test has been performed.

### Safety and isolation
- CountFlow-only migration and CountFlow master HTML changed.
- No SMART ERP project, `company-1/main.html`, `core.js`, legacy ERP table/function, inventory, treasury, or accounting data was modified.
- No persistent CountFlow business data or Auth user was created.


## LVE-2026-11-20-743 — Owner license email settings and engagement terminology completion

### Implemented
- Added owner-only `public.count_platform_settings` with `license_emails text[]`; there is no application-level maximum count for email addresses.
- RLS enabled; three owner-only policies for SELECT/INSERT/UPDATE; no anon grants and no authenticated DELETE/TRUNCATE/TRIGGER/REFERENCES grants.
- Seeded one settings row containing `owner@rawaea.com` as the initial license-contact email. This is not an Auth user and does not confer login or authorization.
- Added **إدارة التراخيص** to `countflow-admin.html`: displays the fixed security owner identity, allows multiple license/contact emails (one per line), validates addresses, de-duplicates them, and saves/reloads the list. The email list does not grant access to CountFlow.
- Completed visible UI wording so the workspaces are called **تكليفات الجرد** and the contracting party name can repeat across separate engagements. No permanent customer master was created.
- The owner Auth identity remains email-confirmation-bound to `owner@rawaea.com`; public first-user signup remains removed.

### Verification
- Database: owner Auth users=0; engagement workspaces=0; memberships=0; count sessions=0.
- `count_platform_settings`: RLS=true, 3 policies, anon grants=0, unsafe authenticated grants=0, one initial settings row.
- Admin inline JavaScript syntax compilation: PASS.
- Security advisor still reports 65 legacy public tables without RLS and several legacy public SECURITY DEFINER warnings in `rawaea-staging`; these are outside CountFlow and intentionally untouched. No CountFlow finding was returned for `count_platform_settings` or `counting_private.is_platform_owner`.
- Performance advisor continues to show legacy findings including the duplicate index on `public.erp_operation_registry`; no legacy objects were changed.

### Source snapshots
- `countflow-admin.html`: `13ca11377cf3f05aad23c438c2869aeba3922ccc`.
- `20261120170000_countflow_platform_owner_verified_email.sql`: source file in `database/migrations/`.
- `20261120171000_countflow_license_settings_unbounded_emails.sql`: source file in `database/migrations/`.

### Still not complete / hard gates
- Owner Auth user creation and email confirmation have not occurred. The available connected Supabase actions do not expose Auth Admin invite/create-user; do not fake it or create credentials in SQL.
- The RAWAEA `main.html` license implementation could not be fully inspected through the available large-file reader; the CountFlow license screen therefore implements only an owner-controlled unbounded email contact list, not an invented subscription/expiry/seat licensing engine.
- Previously recorded P1s remain open: offline queue close/replay handshake, retry scoping, direct-DML state-transition bypasses, import staging revalidation, Broadcast delivery, and browser E2E.
- No authenticated browser E2E, real owner login, Cloudflare publication, or domain setup has been performed.

### Isolation
Only CountFlow master UI and CountFlow-specific migrations/settings were changed. SMART ERP, `company-1/main.html`, `core.js`, all legacy ERP tables/functions, and business balances were not touched.

---

## LVE-2026-11-20-744 — CountFlow engagement + named operation workflow

**Scope:** CountFlow only — companies/company-2/Counting/ and Supabase rawaea-staging (hfzznsiprnwkpayskzhu).

### Business model and data contract — CONFIRMED
- The contracting organization is variable per contract; it is not a permanent customer master.
- count_projects is the independent engagement workspace / ملف تكليف الجرد: name stores the contracting-party name and code is the unique engagement reference. The same contracting-party name may appear in separate workspaces with distinct codes.
- count_sessions.name is the operation name / اسم عملية الجرد, e.g. جرد شهر يناير 2027 - كارفور فرع المعادي.
- count_members remains engagement-scoped. count_assignments binds members to a specific operation and optionally to a location.
- Removing a count_assignments row removes that user from the selected operation only; it does not delete the Auth identity, engagement membership, or historic count_entries.

### Database change — APPLIED / VERIFIED
- Added public.count_create_engagement(p_client_name,p_engagement_code,p_operation_name) as a SECURITY INVOKER RPC. It validates input and inserts the engagement workspace and first planned operation in one transaction.
- Authenticated EXECUTE=true; anon EXECUTE=false.
- The live ledger contains the three owner/license/engagement migration names. The latest live version is 20261120004422; the two owner/license entries are 20261119232523 and 20261119232615.
- count_assignments RLS remains enabled; anon grants=0; existing supervisor/owner RLS scope protects assignment operations.

### Master UI — IMPLEMENTED
- countflow-admin.html creates a new engagement and its first named operation together using the RPC.
- Added the historical operation register across owner-visible engagements: search by contracting-party name, operation name or engagement code; filter by status and creation-date range; sortable columns; 50-row pagination.
- Operation detail provides team management, adding an existing engagement member, creating an account and assigning it to the selected operation, removing from this operation only, current metrics, import history, reconciliation lines, export archive, print preview, and XLSX/CSV export through the server function.
- Coverage display derives from the actual count_session_kpis contract (expected_positions/counted_positions, or total_products/counted_products fallback); it does not assume a non-existent coverage_percent_total key.

### Supervisor UI — IMPLEMENTED
- Countflow-supervisor.html creates a new engagement and first named operation from an inline validated form using the same atomic RPC.
- Operation history is searchable by operation name, status and date range, with open/select behavior for completed historical operations.
- Operation assignment list has a remove-from-this-operation action. Creating a new member provisions the identity/membership through the existing Edge Function, then assigns that member to the selected editable operation.
- Completed/cancelled operations are historical in the supervisor UI: team/import/state-change controls are disabled; preview and export remain available.
- Supervisor engagement and operation history loaders now use the existing paginated fetch helper rather than a single 500-row session cap; the helper has an explicit 200,000-row safety ceiling and throws if exceeded.
- Added printable reconciliation preview. It reads up to 5,000 detail rows for print; use server XLSX for the complete result export.
- Existing staged CSV/XLSX import and server export paths are reused; no parallel pipeline/table was introduced.

### Edge Functions — DEPLOYED / CONFIRMED
- counting-provision-member: version 4, ACTIVE, verify_jwt=true; permits active supervisor in target engagement or confirmed platform owner.
- counting-export-session: version 7, ACTIVE, verify_jwt=true; permits active supervisor in target engagement or confirmed platform owner.
- Ordinary member access remains bounded by engagement membership and operation assignment rules.

### Verification
- Inline JavaScript syntax compilation: master PASS, supervisor PASS, field page PASS.
- Database residue check: count_projects=0, count_sessions=0, count_members=0, count_assignments=0, count_entries=0, count_import_batches=0, count_exports=0.
- Auth owner account matching owner@rawaea.com=0. No new Auth identity or password was created.
- RPC privilege check: authenticated=true / anon=false. count_assignments RLS=true and anon grants=0.
- Security advisor still reports the known 65 public legacy tables without RLS; no CountFlow-specific finding for the new owner helper, license settings, or engagement RPC was returned. Legacy ERP objects were deliberately not changed.

### Not run / UNKNOWN
- No authenticated browser E2E was run: no confirmed owner Auth login or deployed CountFlow origin is available.
- Real create-member, import commit, signed XLSX/CSV download, print dialog, cross-browser UI and concurrent-device behavior are not yet browser-verified.
- No Cloudflare deployment, DNS or domain modification was made.
- Previously recorded CountFlow P1s remain open: offline queue close/replay barrier, retry scoping, direct-DML/state-transition bypasses, import staging revalidation and cross-client Broadcast delivery.

### Isolation
No SMART ERP project, company-1/main.html, core.js, legacy ERP table/function, stock, treasury or accounting object was changed. No persistent CountFlow business or Auth test data was created.