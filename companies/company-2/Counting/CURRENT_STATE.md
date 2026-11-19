# CountFlow — CURRENT_STATE

**Last Verified Event:** `LVE-2026-11-19-CountFlow-Production-Safety-and-Export-Hardening`  
**Date:** 2026-11-19  
**Repository:** `papamohammed77-glitch/erp-frontend`  
**Application path:** `companies/company-2/Counting/`  
**Supabase project:** `rawaea-staging`  
**Project ref:** `hfzznsiprnwkpayskzhu`

## 1. Current source snapshots

| Artifact | Current Git blob SHA |
|---|---|
| `Counter.html` | `d0367e9581173811cfb884acb31800fbecc1d261` |
| `Counter-supervisor.html` | `e060cf2dfd6e35d80286ad9872d6001a3ed3b080` |
| `README.md` | `3cc8410ba283c9b8b62bcf491559962adc6a2689` |
| `functions/counting-provision-member/index.ts` | `74af323b9efda52d01b0326ef71dc0fe5133fa3b` |
| `functions/counting-export-session/index.ts` | `170336d3bcff9ee23ee97097d56737d60a4ac003` |

## 2. Verified Supabase structure

- 21 `count_*` tables; all 21 have RLS enabled.
- 70 CountFlow RLS policies.
- 72 validated foreign-key constraints; no unvalidated CountFlow constraints and no CountFlow table without a primary key.
- Zero grants to `anon`; zero authenticated TRUNCATE/TRIGGER/REFERENCES grants.
- `count_entries` client grants are SELECT and INSERT only (append-only).
- `count_assignments` has one `NULLS NOT DISTINCT` unique scope index, enabling atomic upsert for both global and location-specific assignments.
- Expected balances must use the product's base unit and are locked after the first count or reconciliation.
- Reconciliation runs store `entry_count_snapshot`; approval checks the latest run, unchanged entry count, zero uncounted positions, no open recount tasks, and no unresolved critical alerts. Approval moves the session to `review` and freezes further count inserts.
- CountFlow private Broadcast authorization is scoped by project/session/member topic; live broadcast triggers are attached to operational tables.

## 3. Deployed Edge Functions

| Function | Version | JWT | State |
|---|---:|---|---|
| `counting-provision-member` | 3 | Required | ACTIVE |
| `counting-export-session` | 4 | Required | ACTIVE |

The export function verifies the authenticated supervisor membership, creates a 13-sheet XLSX or detailed CSV, stores the artifact in the private `counting-exports` bucket, and records SHA-256, size, row count, and a signed URL. All UI exports now use this server pipeline; it also includes import rejection details, evidence image links, device/presence, and session audit history. Failed completion removes orphaned Storage objects.

## 4. Completed behavior and regression tests

Latest applied migration: `20261119193620_countflow_expected_balance_snapshot_guard_v1`.

- Continuous camera scanning (detection throttled to 200 ms), location barcode selection, repeated same-product scan quantity increment, and a save-before-switch safeguard.
- Import pipeline uses 1,000-row staging chunks and detailed row outcomes; location reads/import mapping are paginated.
- Base-unit conversion snapshots on count entries; reconciliation and exports use normalized quantities.
- Automatic quantity/repeat-scan alerts and automatic variance alerts after reconciliation.
- Recount tasks, review/approval, and finality/immutability gates.
- All XLSX/CSV exports use the server-side pipeline; the browser no longer builds large workbooks. The function has configured row limits (150k per major dataset, 250k combined) that have not yet been load-tested.
- Supervisor logout control; assignment upsert is atomic and duplicate-safe.

Executed SQL regression suites (all rollback-only; no persistent test data):
1. `tests/countflow_core_integration_rollback.sql`
2. `tests/countflow_unit_recount_rollback.sql`
3. `tests/countflow_anomaly_rollback.sql`
4. `tests/countflow_approval_finality_rollback.sql`
5. `tests/countflow_assignment_upsert_rollback.sql`
6. `tests/countflow_expected_balance_snapshot_rollback.sql`

Final residue check: zero CountFlow projects, members, sessions, products, entries, exports, and zero temporary test users.

## 5. Isolation and account state

The applications call CountFlow tables only and do not call ERP stock, sales, treasury, or accounting tables. However, the Supabase project itself still contains 70 non-CountFlow public tables, 24 Edge Functions, and 1,868 pre-existing Auth users. Six legacy functions have `verify_jwt=false`; none are CountFlow functions. These legacy objects were not modified because their ownership/usage is outside this task. Thus current separation is logical at the application/data-access level, not a physically clean Supabase project boundary.

There are currently zero CountFlow members and zero CountFlow projects. No existing Auth identity was assigned a CountFlow role. Permanent staff accounts were not fabricated because no employee roster/emails were supplied. The first supervisor must be created in Supabase Auth; after that, the supervisor app can create members through `counting-provision-member`.

## 6. Verification limits / next execution gates

- Playwright non-destructive smoke tests are prepared under `tests/e2e/` but were not run: no permanent supervisor/counter credentials or confirmed deployed app origin were available.
- The large export Edge Function is deployed and source-matched, but a real authenticated XLSX/CSV export has not yet been exercised end-to-end.
- 90,000-row import/export, camera-device compatibility matrix, offline queue recovery after browser termination, WebSocket Broadcast delivery under real concurrent clients, and 30–300 user load tests remain unverified.
- Global Supabase security advisor still reports 65 ERROR and 15 WARN on legacy objects; none are CountFlow findings. Performance advisor's single WARN concerns duplicate indexes on `public.erp_operation_registry`, outside CountFlow.
- Do not modify or delete legacy ERP tables/functions as part of CountFlow work. Do not create persistent accounts without a confirmed roster. Do not run any test that writes to ERP inventory, treasury, or accounting.

## 7. Safe continuation order

1. Obtain/confirm the actual CountFlow supervisor and counter roster and the published app origin.
2. Create the first supervisor Auth user, create the first CountFlow project, then provision named users through the supervisor app.
3. Run Playwright smoke tests with environment-injected credentials and a designated assigned location/product; the scan test must not click Save.
4. Run a dedicated, reversible CountFlow-only import test with representative CSV/XLSX and then a 90k-row load test in an isolated dataset.
5. Exercise one real authenticated server export and verify workbook sheets, signed URL, SHA-256, and export history.
6. Run concurrent Broadcast/load tests before making any scale-readiness claim.
