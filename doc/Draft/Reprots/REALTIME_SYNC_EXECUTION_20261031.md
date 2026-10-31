# RAWAEA ERP — Realtime Synchronization Execution Checkpoint
**Date:** 2026-10-31  
**Repository:** `papamohammed77-glitch/erp-frontend` / `main`  
**Supabase project:** `fiilmooggumokxanwiyx`  
**Scope:** Resume the Production/application Realtime synchronization work; do not restart from the historical 72-table checkpoint.

## 1. Current evidence snapshot

| Evidence | Result | Classification |
|---|---|---|
| Supabase `supabase_realtime` publication | 81 published tables at 2026-10-31 16:53:54 UTC | CONFIRMED |
| Shared core | `companies/company-1/core.js` contains `RW_Realtime`; blob `a95ee6b29ff54b4a240ce4b81f9a535aa87686db` | CONFIRMED |
| Latest pre-fix main commit | `0b511d04ff9574b722f7531148dab2f6529a1eee` — loader runsheet subscription | CONFIRMED |
| Warehouse supervisor source | Handler named both `purchase_orders` and `stock_vouchers`, but subscription included only `purchase_orders` | DEFECT CONFIRMED |
| Production tables | `purchase_orders` and `stock_vouchers` are both in Realtime and both have `company_id uuid` | CONFIRMED |
| RLS | Enabled on `branches`, `customers`, `items`, `stock_branches`; policy counts respectively 6, 7, 7, 3 | CONFIRMED; policy predicates not audited in this checkpoint |
| Cloudflare served artifact identity | Not retrieved | UNKNOWN |
| Authenticated browser E2E | Not executed in this checkpoint | OPEN |
| Formal definitions for tests A–E | Not located in the available continuity record | UNKNOWN; do not invent their meanings |

## 2. Surgical correction applied

File: `companies/company-1/warehouse/supervisor.html`

Before:
```javascript
tables:['purchase_orders'],
```

After:
```javascript
tables:['purchase_orders','stock_vouchers'],
```

Reason: the existing `onEvent` handler explicitly reacts to both tables, while the Realtime subscription listened only to `purchase_orders`. This made stock-voucher changes invisible to the dashboard through this subscription.

- Change scope: one array value; no other code changed.
- Commit: `1ac88d795eaa6dbe9b6720b497cd4e1684e32651`
- New file blob: `792f8bbff15a0c724e47b6e6e28f2ffec903b024`
- Immediate GitHub readback: PASS; exact updated subscription line confirmed.
- Production schema/data: unchanged.
- Commit status endpoint: no status records returned; this is NOT a passing CI result.

## 3. Architecture observations requiring continued audit

1. `RW_Realtime.start` requires `appId`, `companyId`, `onEvent`, and verifies the company against `RW_Auth.getUser().company_id`. It filters subscribed tables by `company_id` by default. Preserve this guard.
2. The current `RW_DB.syncDown` implementation reads `customers`, `items`, `stock_branches`, and `branches` without explicit `.eq('company_id', ...)` client filters. RLS is enabled on all four tables, but this checkpoint did not inspect every policy predicate or prove the effective tenant boundary. Do not label this safe or unsafe until policy expressions and authenticated behavior are tested.
3. Recent source commits show Realtime integrations being added to warehouse Loader, warehouse Supervisor, and Purchasing Supervisor. This is evidence of incremental adoption, not proof that all PWAs or the parent `main.html` are connected.
4. The recent Purchasing Supervisor integration subscribes to `purchase_orders`. Its other data dependencies still require an event-to-view refresh audit.
5. A subscription being present in source and a table being in the publication do not prove delivery in a real authenticated browser session.

## 4. Next execution sequence — continue without restarting

1. Inventory every PWA and parent view that reads shared operational entities; record its source path, core.js load, authenticated company source, subscribed tables, handlers, reconciliation behavior, and logout cleanup.
2. Compare each subscribed table to Production publication membership and confirm it has a valid `company_id` column; explicitly mark tables that require a different tenant-scope strategy.
3. Inspect RLS policy expressions for all tables read by `syncDown` and by Realtime consumers. Verify with authenticated company contexts; do not infer isolation from RLS being enabled alone.
4. Verify source syntax and behavior after each small change; preserve the shared Supabase client created by `core.js`.
5. Run authenticated E2E in two company contexts: create/update a harmless controlled record in company A, verify intended refresh in company A consumers and no visibility/update in company B; repeat for the key workflows. Do not use business production records as disposable fixtures.
6. Verify the served Cloudflare artifact against the exact Git blob/commit before claiming Production deployment.
7. Re-query publication membership and relevant Production invariants at the time of final reporting.
8. Record test A–E only after locating their original definitions or formally mapping them to explicitly approved cases. Do not fabricate historical test names.
9. Update this report and `CURRENT_STATE.md` after each verified closure.

## 5. Closure status

- Realtime publication count: **81 — VERIFIED**
- Shared engine in current core source: **PRESENT**
- Warehouse Supervisor stock-voucher subscription mismatch: **FIXED IN MAIN / READBACK VERIFIED**
- All application consumers: **NOT YET VERIFIED**
- Tenant isolation end-to-end: **NOT YET VERIFIED**
- Cloudflare deployment parity: **NOT YET VERIFIED**
- Full E2E A–E: **OPEN**
- Overall synchronization mission: **OPEN — NOT CLOSED**

No claim of full synchronization or 100% completion is authorized by this checkpoint.


## 6. Phase 1 — Application consumer census and RLS policy inspection (2026-10-31)

### Application entry-point census

Repository tree query returned 29 HTML entry points under `companies/company-1/`. Each file was fetched from `main` and scanned for shared-core loading and explicit `RW_Realtime.start` usage.

**Six entry points explicitly start Realtime:**

| Application | Subscribed tables |
|---|---|
| Purchasing Buyer | `purchase_orders` |
| Purchasing Supervisor | `purchase_orders` |
| Warehouse Loader | `runsheets` |
| Warehouse Manager | `stock_vouchers`, `purchase_orders` |
| Warehouse Receiver | `purchase_orders` |
| Warehouse Supervisor | `purchase_orders`, `stock_vouchers` |

**23 other HTML entry points do not contain an explicit `RW_Realtime.start` call in their current source.** This is a confirmed source observation, not yet a defect classification. Some may be intentionally read-only, router-driven, or use another refresh mechanism. The parent `main.html` and `app.html` also do not directly contain the scanned core/Realtime identifiers; their runtime loading path must be traced through the router/bootstrap before classification.

### RLS policy inspection

Production `pg_policies` definitions were queried for `branches`, `customers`, `items`, `stock_branches`, `purchase_orders`, `stock_vouchers`, and `runsheets`.

Confirmed:
- `branches`, `customers`, `items`, `purchase_orders`, `stock_vouchers`, and `runsheets` have company predicates in the inspected policies.
- `stock_branches` SELECT policies scope rows through an `EXISTS` lookup to `branches` where `branches.company_id = app_private.current_user_company_id()`; other specialized policies additionally constrain branch assignment/mobile branch.
- `customers` and `items` include specialized delivery and sales-entry policies; these require role-context E2E verification because policy permissiveness combines multiple SELECT policies.
- `purchase_orders` and `stock_vouchers` SELECT policies inspected here use `company_id = app_private.current_user_company_id()`.

Not established:
- Effective behavior under real authenticated JWTs for two separate companies.
- INSERT/UPDATE/DELETE policy completeness for every operational table.
- Realtime event delivery/visibility under authenticated tenant contexts.
- Whether any router or service worker injects refresh behavior for the 23 pages without explicit subscriptions.

### Phase 1 decision

**Phase 1 source census and policy-definition review: COMPLETE.**  
**Tenant isolation runtime proof: OPEN.**  
**All-app Realtime integration: OPEN.**

No further subscription was added during this phase. The next priority is tracing the parent/router bootstrap and classifying each of the 23 pages by actual data freshness requirement, then performing authenticated two-company isolation tests before broadening subscriptions.


## 7. Phase 2 — Runtime/bootstrap trace: findings and remaining gates

### Confirmed architecture

- `core.js` creates one shared Supabase client and `RW_Auth` hydrates the verified public profile through `get_my_effective_profile`.
- `RW_Realtime.start` rejects a missing appId/companyId/callback and rejects a companyId that differs from `RW_Auth.getUser().company_id`. This is a useful tenant guard and must be preserved.
- The engine defaults each table subscription to a `company_id=eq.<verified company>` filter, debounces events, reconciles after initial subscription/reconnection, periodically reconciles, and reconciles after a hidden page becomes visible.
- The engine currently normalizes each table's event list to `INSERT` and `UPDATE`; this checkpoint does not change that behavior. DELETE support needs a separate tenant-safe design review before implementation.
- Warehouse Vouchers (`warehouse/vouchers.html`) implements its own direct Supabase Realtime channels rather than calling `RW_Realtime.start`. Its channel filters `stock_vouchers` by company_id, listens to `stock_voucher_details` without a company filter, and filters `stock_branches` by branch_id. The detail/stock event scope must be verified against RLS and authenticated sessions before it is accepted as equivalent to the shared engine.

### Runtime/bootstrap trace limitation

- `app.html` redirects authenticated users to the parent `main.html` or a standalone app based on profile/metadata and role permissions.
- GitHub's file-content response for the very large `companies/company-1/main.html` returned an empty content body in this inspection, so the parent runtime's internal module/bootstrap path is **NOT VERIFIED**. Do not infer that parent has or lacks Realtime based on this failed read.
- Some non-subscribing pages have explicit focus/visibility/manual refresh behavior (e.g. POS and Warehouse Vouchers); others require individual inspection. No blanket "all 23 need Realtime" change is authorized.

### Phase 2 status

**Shared engine contract review: COMPLETE.**  
**Direct-channel exception identified: Warehouse Vouchers.**  
**Parent bootstrap trace: BLOCKED by unavailable large-file content response.**  
**Classification of all 23 non-explicit subscribers by operational freshness requirement: OPEN.**

Next: retrieve the parent source via a bounded raw/blob read, map each app's data dependencies to its actual refresh path (Realtime, focus/visibility, polling, explicit user refresh, or static/read-only), and test direct-channel event scoping. No broad subscription edits until this matrix is complete.


### Additional Phase 2 retrieval attempt

A second read attempt through the repository's raw-content endpoint also failed because the parent `main.html` exceeds the connector's supported response size. This confirms a tooling/read-size blocker, not a source-code defect. The next retrieval method must be a bounded Git blob/range extraction or local repository checkout; no parent-code conclusion is drawn.


## 8. Mandatory phase-by-phase handoff and continuation protocol

This section is binding for every subsequent assistant/CTO continuing the Realtime synchronization mission.

### Required record for EVERY phase

A phase is not reportable as complete until its report records all of the following:

1. **Phase identity:** phase number, title, start/update time (Africa/Cairo), scope, and explicit exit criteria.
2. **Truth sources:** exact GitHub repository/branch/commit/blob SHA; exact Production Supabase project and query time; exact Cloudflare URL/deployment identifier and observation time when applicable. Distinguish source code, deployed artifact, database state, and browser runtime.
3. **Inspection inventory:** every file, function, table, policy, trigger, publication, subscription, and consumer actually inspected. Record exclusions and why they were excluded.
4. **Findings classification:** CONFIRMED / UNKNOWN / CONFLICT / UNVERIFIED. Every material claim must point to a reproducible query, file path/line or blob SHA, runtime observation, or test result.
5. **Change ledger:** exact before/after behavior, file and function, minimal diff, commit SHA, migration/RPC/Edge Function identifier if applicable, and whether Production was changed. Never imply a Git commit is deployed.
6. **Test ledger:** test ID, setup, tenant/user role, action, expected result, actual result, evidence, cleanup/rollback result. Record PASS/FAIL/BLOCKED separately; a missing result is not PASS.
7. **Safety and recovery:** baseline, data impact, idempotency, concurrency implications, rollback procedure, and confirmation that test fixtures were removed/restored.
8. **Exit decision:** COMPLETE / OPEN / BLOCKED, exact evidence supporting the decision, unresolved risks, and next executable action with owner/tool prerequisite.

### Handoff header required in CURRENT_STATE.md

Every phase update must put the latest checkpoint at the top of CURRENT_STATE.md and include:
- current phase and exact status;
- last verified event and timestamp;
- latest report path and commit;
- current Git commit/branch and any known deployment parity status;
- Production facts with query timestamps;
- confirmed changes versus merely inspected facts;
- open blockers and risks;
- next action in executable order;
- explicit instruction not to repeat completed work or trust historical reports over current source/Production.

### Continuation rules

- Read this checkpoint and the linked detailed report first; then independently refresh current GitHub and Production evidence before any new change.
- Do not trust this report as a substitute for re-verification of mutable Production or deployment state.
- Do not infer a defect from absence of an explicit Realtime call until router/bootstrap, polling, focus/visibility refresh, and user-triggered refresh have been inspected.
- Do not broaden Realtime subscriptions without validating table publication, RLS, tenant filter semantics, event payload behavior, and the consumer's reconciliation callback.
- Preserve `RW_Realtime.start` verified-profile tenant guard. Never trust caller-supplied company metadata as the authority.
- Do not mark a phase complete because documentation was written. Code change, deployment, and runtime proof are separate states.
- Never claim Cloudflare parity, authenticated E2E, or full synchronization without direct evidence from the relevant environment.

### Phase ledger at this update

| Phase | Scope | Status | Evidence / blocker |
|---|---|---|---|
| 1 | 29-page consumer census and selected Production RLS policy-definition review | COMPLETE (source/policy-definition scope only) | Section 6; tenant runtime isolation remains open |
| 2 | Shared engine contract and app bootstrap/freshness trace | IN PROGRESS / PARTIAL | Section 7; parent main.html retrieval blocked by connector size limit; bounded Git blob/local checkout required |
| 3 | Close tenant isolation and direct-channel scoping gaps | NOT STARTED | Requires authenticated two-company tests and direct-channel policy/event proof |
| 4 | App-by-app freshness matrix and surgical Realtime integration | NOT STARTED | Must follow parent/router trace and classify each consumer |
| 5 | Authenticated end-to-end synchronization tests | NOT STARTED | Requires test identities/roles and controlled fixtures |
| 6 | Cloudflare artifact/deployment parity | NOT STARTED | Requires deployed URL/version and served-source evidence |
| 7 | Final closure, residual debt register, and handoff | NOT STARTED | Depends on phases 3–6 |

This ledger is a handoff map, not a claim that future phases have been executed.


## 9. Phase 2 parent bootstrap trace — completed source retrieval and critical findings (2026-10-31)

Detailed independent report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE2_PARENT_BOOTSTRAP_20261031.md`.

### Corrected source inventory
A fresh recursive Git tree query returned **30 HTML files** under `companies/company-1/`, not 29 as stated in section 6. The earlier census omitted `companies/company-1/index.html`, the actual landing page linking to `app.html` and `main.html`. There are 6 explicit `RW_Realtime.start` consumers and 24 other HTML files without that explicit call. This correction supersedes the earlier count; it does not imply all 24 need Realtime.

### Parent source now inspected
- `main.html` blob SHA: `53b5a9e9d0433a785c3d5471a9c0d68c25497882`; 33,358 lines; 1,892,593 bytes in Git tree.
- The parent creates its own Supabase client and does not load `core.js` or invoke `RW_Realtime.start`.
- Parent authentication obtains company_id and permissions from the `users` row matched by auth_id, then enters the parent shell.
- Eight direct parent Realtime channels are mapped in the independent report. Several are incompatible with current publication/RLS configuration; others depend on RLS without explicit company filters.

### Critical Production finding: inventory_counts
Production shows `inventory_counts` has RLS enabled but its only policy is `allow_all_inventory_counts`, FOR ALL / role public, with `USING (auth.role() = 'authenticated')` and no company predicate. Authenticated has SELECT/INSERT/UPDATE/DELETE grants. The table has `company_id`.
- Parent reads it with a client-side company filter (line 17437) and subscribes without a company filter (line 18274).
- Warehouse Counter reads the latest 30 rows with no company filter (`warehouse/counter.html`, line 137).
- Parent writes through the guarded `inventory_control` RPC; the internal `inventory_count_engine` is not directly executable by authenticated.
- The table had zero rows at inspection; therefore no current row disclosure was observed, but the policy is a confirmed tenant-isolation defect and direct write bypass risk once data exists.
- Do not patch this policy blindly. First confirm the Counter/van-sales Edge Function contract and authorized count roles; then implement company-and-role-scoped SELECT and remove unnecessary direct write grants while preserving the validated RPC path.

### Realtime channel compatibility findings
- Sales Decision (3 tables) and Loyalty (4 tables): not in `supabase_realtime`; their RLS policies deny direct anon/authenticated access.
- Customer Payments (2 tables) and Commission (4 tables): published, but the inspected policies are service_role-only while the parent subscribes from an authenticated client.
- Sales Targets (4 tables), Purchasing Gold (6 tables), and HR (24 tables): published with RLS policies; HR and some other direct channels rely on RLS without explicit company filters.
- Warehouse Vouchers direct channel filters `stock_vouchers`, but not `stock_voucher_details`; the latter's RLS policy scopes through its parent voucher. Runtime proof remains open.

### Runtime isolation blocker
The active-user inventory query returned active auth-linked users for only one company; `inventory_counts` had zero rows. Therefore two-company authenticated E2E and observed cross-tenant Realtime tests remain BLOCKED, not PASS.

### Phase 2 decision
- Parent source/bootstrap trace: COMPLETE.
- Full 30-page behavioral freshness classification: PARTIAL.
- Authenticated Realtime delivery and tenant-isolation runtime proof: OPEN/BLOCKED.
- No application code, schema, data, publication, or Cloudflare deployment was changed in this phase.
- Independent Phase 2 report commit: `43fdbba23b2368c71bfc96c1cdbd111a99c12c0f`.
- Overall Realtime synchronization: OPEN.

Next priority is the `inventory_counts` tenant-safety repair design, followed by reconciliation of parent channels whose publication/RLS settings cannot deliver events to authenticated clients. See the independent report for evidence and exact file locations.


## 10. Phase 3 subtask — inventory_counts tenant boundary repair (2026-10-31)

Independent report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE3_INVENTORY_COUNTS_20261031.md`.

### Production migration applied
- Migration: `harden_inventory_counts_tenant_read_boundary_20261031`
- Version: `20261031171715`
- Result: SUCCESS.
- Removed the permissive `allow_all_inventory_counts` policy.
- Replaced it with SELECT-only `inventory_counts_select_company_authorized`, scoped to `app_private.current_user_company_id()` and an active user with approved inventory/warehouse/report role or permission.
- Revoked all table privileges from `anon` and `authenticated`, then granted SELECT only to authenticated.
- `service_role` retains its server-side privileges; authenticated retains EXECUTE on guarded `inventory_control` and cannot directly execute `inventory_count_engine`.

### Client source correction
- `companies/company-1/warehouse/counter.html`: added a missing-company guard and `.eq('company_id', companyId)` to the completed-count history query.
- Commit: `2ddab280b9e0fc362e96f28acd897a2a3b6e1150`.
- GitHub readback verified; Cloudflare deployment not verified.

### Verification
- Authenticated SELECT: allowed.
- Authenticated INSERT/UPDATE/DELETE: denied by grants.
- anon SELECT/INSERT: denied by grants.
- service_role INSERT/UPDATE: retained.
- `inventory_control` execute: retained; direct authenticated `inventory_count_engine` execute: denied.
- Simulated JWT for authorized warehouse user: same-company temporary row visible; other-company temporary row invisible.
- Simulated JWT for active same-company user without count/warehouse/report scope: same-company row invisible.
- All tests ran in a transaction and were rolled back; follow-up count confirmed zero remaining test rows.
- Supabase Security Advisor rerun: no `inventory_counts` finding; unrelated findings remain (24 RLS-enabled/no-policy tables, 3 SECURITY DEFINER views, 3 mutable-search-path functions, 20 anon-executable and 121 authenticated-executable SECURITY DEFINER functions, leaked-password protection disabled).

### Remaining gates
- No active user currently has `active_warehouse_role='جرد'`; Counter browser E2E remains untested.
- Production has active auth-linked users for only one company; real two-company browser E2E remains blocked.
- Counter's legacy `general` count sends `entityId='MAIN'`, while Edge Function expects a branch UUID or null; investigate/fix separately.
- Overall Realtime remains OPEN; no publication broadening or Cloudflare deployment was done.

Phase 3 inventory_counts tenant-boundary subtask: **COMPLETE for SQL policy/grant boundary and source query hardening; runtime browser/Counter E2E remains OPEN.**
