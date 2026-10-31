# RAWAEA ERP — GLOBAL REALTIME & DATA SYNCHRONIZATION FORENSIC AUDIT
Date: 2026-10-31
Repository: papamohammed77-glitch/erp-frontend
Branch: feat/global-realtime-sync-audit-20261031
Production project: fiilmooggumokxanwiyx

## Executive status
- Audit is source-backed for 27 standalone HTML application pages under companies/company-1.
- Shared core is loaded by 26/27 pages; warehouse/picker.html is the exception.
- Only two standalone pages contain postgres_changes subscriptions: sales/manager.html and warehouse/vouchers.html.
- core.js has no central Realtime subscription manager.
- Production publication contains 72 public tables. Of 27 selected business tables, 18 are published and 9 are absent.
- No Production DDL or business data was changed.
- Two surgical source fixes were committed to this isolated branch; neither was merged to main nor deployed.

## Source census
27 pages reviewed:
- delivery: driver, supervisor
- office: accountant, finance-manager, general-manager, hr, owner
- purchasing: buyer, supervisor
- sales: manager, order-taker, pos, supervisor, telesales, van-sales
- store: index, track
- warehouse: counter, data, loader, manager, picker, receiver, returns, supervisor, unloader, vouchers

Static census: core.js is included in 26 pages; Realtime syntax is present only in sales/manager.html and warehouse/vouchers.html. Other pages use direct Supabase CRUD/RPC/Edge calls, polling in a subset, or manual reload flows. These are source indicators, not proof of runtime behavior.

## Confirmed source corrections
### 1. RW_DB.syncDown destructive ordering
Before correction, syncDown cleared each Dexie table before checking the corresponding Supabase result error. A failed query could replace valid local data with an empty array.
Correction in core.js: fetch all four datasets (customers, items, stock_branches, branches), validate all responses and array payloads before mutation, then replace all four tables inside one Dexie read/write transaction. Failure preserves the prior local snapshot.
Commit: 8d49625a4b636cae8ed3c6a45f4794eb808f86b9
Core blob: 65fbc2ab4680e64af61937aa15cd5983ec923290

### 2. warehouse/receiver.html overwrote the shared Supabase client
The page loaded ../core.js, then executed: var supabase = window.supabase;. This replaced the initialized client with the library namespace; its direct supabase.from(...) calls therefore targeted the wrong object.
Correction: removed the overwrite and documented that ../core.js owns client initialization.
Commit: 4ae9c651fac43a63abe267ee7af0963dfb8be432
Receiver blob: 597bf3df5e147b7da8237ecd320b8422e33aa73b

## Existing Realtime implementations
### sales/manager.html
Subscribes to sales_target_plans, sales_target_assignments, sales_target_runs, sales_target_run_lines and refreshes the selected plan dashboard. Subscription config has no explicit company filter; actual visibility remains governed by authenticated RLS. Runtime isolation and reconnect behavior are unverified.

### warehouse/vouchers.html
Subscribes to stock_vouchers (company_id filter), stock_voucher_details (no explicit company filter), and stock_branches (branch_id filter when source branch exists). It has debounced refresh and connection status handling. Runtime reconnect, stale-event recovery, and RLS behavior remain unverified.

## Live Production publication snapshot
Captured at 2026-10-31 15:29:17 UTC (17:29 Africa/Cairo).
- Publication exists: supabase_realtime
- Public tables in publication: 72
- Required business tables checked: 27
- Required tables present: 18
- Required tables absent: branches, customer_ledger, customers, daily_settlements, items, purchase_order_details, purchase_orders, supplier_ledger, suppliers

The nine absent tables were inspected for RLS, primary keys, and company scope. All nine have RLS enabled and primary keys. branches, customers, items, daily_settlements, purchase_orders, suppliers have company_id. customer_ledger, purchase_order_details, supplier_ledger do not have company_id and their SELECT policies scope via parent-table relationships. This does not automatically authorize adding all nine to Realtime: subscription contracts, authenticated SELECT behavior, tenant isolation, event payload requirements, and data volume must be validated table by table.

## Architectural conclusion
Realtime is page-specific, not a system-wide shared service. A central service is a valid target, but must be introduced in compatibility stages:
1. Define event-to-refresh contracts per application and parent tab.
2. Add a shared Realtime manager with explicit company/branch scoping, deduplicated subscriptions, channel cleanup, status reporting, reconnect/resubscribe, and authoritative re-fetch after events.
3. Integrate the parent system separately. main.html is 1,892,593 bytes and the GitHub file-content connector returned an empty payload for it in this run; no parent source modification was attempted.
4. Add reconciliation fallback so missed Realtime events cannot leave a view stale indefinitely.
5. Add idempotent operation tests and authenticated cross-app E2E.

## Not done / closure gates
- No Production publication, RLS, policy, replica identity, or business data changes.
- No proof Cloudflare serves this branch's code; branch is not deployed.
- No authenticated browser E2E was available in this run.
- No proof yet for every writer-to-database-to-consumer-to-parent-tab chain.
- No central Realtime manager has been added yet; adding it before mapping each page's actual data dependencies risks incorrect refreshes and excess subscriptions.
- No claim of 100% closure is made.

## Required next execution
1. Inspect picker.html independent Supabase initialization and decide whether/how to adopt core without breaking its existing flows.
2. Extract parent main.html through a size-safe Git blob workflow and map each tab's source tables and refresh entry point.
3. Build a table-to-consumer matrix and classify each path: realtime, polling, manual, or missing.
4. Test existing subscriptions and RLS in authenticated sessions.
5. Implement the central service in a separate branch commit, migrate one low-risk consumer at a time, then expand.
6. Add only required publication tables after validating RLS and consumer contracts; avoid blanket publication changes.
7. Run production-safe E2E with uniquely tagged disposable test records and verified cleanup, then compare database state and all relevant UIs.
8. Verify deployment artifact identity before updating the authoritative checkpoint.