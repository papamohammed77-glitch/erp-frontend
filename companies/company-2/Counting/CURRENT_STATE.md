# CountFlow — CURRENT_STATE

**Last Verified Event:** `LVE-2026-11-20-739-CountFlow-Pages-Build-Root-Fix`  
**Date:** 2026-11-20  
**Repository:** `papamohammed77-glitch/erp-frontend`  
**Application path:** `companies/company-2/Counting/`  
**Supabase project:** `rawaea-staging`  
**Project ref:** `hfzznsiprnwkpayskzhu`

## 1. Current source snapshots

| Artifact | Current Git blob SHA |
|---|---|
| `countflow-admin.html` | `0949a6cf92a7693ff3943ad0b67a312091a7746b` |
| `countflow.html` | `93ad77a682585b8ec04cdcf224e2ac81b28cb180` |
| `Countflow-supervisor.html` | `d6911066bdddd59e9a1b364463bcc82c30d2010e` |
| `README.md` | `0f747264c664fd9612c7bf810da23e3cd336ba6c` |
| `DEPLOYMENT.md` | `917d08a24f47890b51a09a2f54bdcb815e8e1dce` |
| `scripts/build-pages.sh` | `f3e068e3bdb12b35cbfe49d78053722ba056ceca` |
| `index.html` | `35636aa074e00d6557353d376ffc681bc32f3093` |
| `_headers` | `799b5b51882d12ed2503fb41ad04633145d24468` |
| `functions/counting-provision-member/index.ts` | `74af323b9efda52d01b0326ef71dc0fe5133fa3b` |
| `functions/counting-export-session/index.ts` | `e0f8f6faf67aee2b7478a1eb99b53c3b64caf0ba` |

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
| `counting-provision-member` | 3 | Required | ACTIVE |
| `counting-export-session` | 6 | Required | ACTIVE |

The export function verifies the authenticated supervisor membership, creates a 13-sheet XLSX or detailed CSV, stores the artifact in the private `counting-exports` bucket, and records SHA-256, size, row count, and a signed URL. All UI exports now use this server pipeline; it also includes import rejection details, evidence image links, device/presence, and session audit history. Successful export is itself written to the audit log; failed completion removes orphaned Storage objects.

## 4. Completed behavior and regression tests

Latest applied migration ledger entry: `20261119195750_countflow_import_batch_sku_lookup_index_v1`. The matching Git source filename is `20261119195630_countflow_import_batch_sku_lookup_index_v1.sql`; timestamp mapping is documented as drift, not an instruction to reapply.

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
- Updated README with the customer/operation model and global dashboard behavior.

### Source hashes
- countflow-admin.html: cc7df74be5e9190aac2980c86956e131f87f264e
- ARCHITECTURE.md: committed in 83303f8d8e1f23b1a505eeed39d6c776ede83010
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

