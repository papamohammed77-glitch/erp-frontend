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
