# CURRENT EXECUTION HANDOFF — BUYER LVE-587 — 2026-11-02

## Current status
- **Active task checkpoint:** Responsible Buyer (companies/company-1/purchasing/buyer.html) — PR #10 / LVE-587.
- **Source branch:** cto/buyer-field-workbench-lve-587; PR #10 remains OPEN and DRAFT, not merged.
- **Scope verified:** branch is 2 commits ahead of main, 0 behind; the only changed path is Buyer HTML (140 additions, 33 deletions).
- **Previous Buyer UI changes:** present in the work branch; see the independent final execution report below.
- **Additional PO idempotency patch:** exact surgical instructions documented, but NOT yet applied to GitHub Buyer source. Current CREATE_PO call does not pass operation_id.
- **Deployment:** Cloudflare served Buyer artifact identity is NOT VERIFIED. Do not claim deployed.
- **Browser E2E:** authenticated browser E2E is NOT RUN. Do not claim successful PO/invoice create-edit-delete round trips.
- **Invoice privacy:** current created_by filter is client-side only; server-side row confidentiality remains UNVERIFIED / unresolved.
- **Overall Buyer task:** PARTIAL / OWNER PATCH + E2E + SECURITY BOUNDARY + DEPLOYMENT GATES OPEN.

## Latest verified checkpoint
- Independent report: doc/Draft/Reprots/BUYER_LVE587_FINAL_EXECUTION_REPORT_20261102.md.
- Report commit on main: 6381f63c7cea22b2410dfdc4eb2c49b55353dcd5.
- PR: https://github.com/papamohammed77-glitch/erp-frontend/pull/10
- PR head commit observed: 5ae94d769a22b540f852d235694ccf4969862cfc.
- Buyer branch blob SHA: ac8be3839e7c30689e757cb8ae61c2957a8063be.
- Buyer main blob SHA at audit: 73d746571a10b1720bdd31631004abce0ac9afa1.
- Branch comparison: ahead_by=2, behind_by=0; one changed file, companies/company-1/purchasing/buyer.html.
- Branch source confirms one buyerOperationId() helper; the CREATE_PO request does not yet include operation_id.
- Branch source confirms zero cost_price references, nine retained tabs, and client-side invoice owner filtering.
- Prior recorded checks: inline JavaScript syntax PASS; item-search tests against 30 Production items PASS for exact barcode, item code, Arabic name, hamza normalization, Arabic numerals, empty and unknown queries.
- Prior Production negative-path checks rejected invalid PO/invoice items as expected. Before/after counts remained unchanged: purchase_orders 1; purchase_order_details 1; purchase_invoices 3; purchase_invoice_details 6; purchase_status_history 5; stock_branches 57; inventory_log 76; treasury 4; cash_box 8; supplier_ledger 2; journal_entries 19.
- These are static/search and negative-path checks; they are NOT successful create-flow tests or browser E2E.

## Exact owner patch — Buyer only
Inside createPO:async function(), immediately after the existing local variable initialization, add:
```javascript
var operationId=buyerOperationId();
```
Inside that same function's preConfirm, change the beginning of the request from:
```javascript
self.api('CREATE_PO',{supplier_id:supplier,
```
to:
```javascript
self.api('CREATE_PO',{operation_id:operationId,supplier_id:supplier,
```
Keep every other property and behavior unchanged. Do not redefine buyerOperationId(); it already exists. Generate the ID once per opened PO form, outside preConfirm, so retries from that form reuse it.

**Important:** this front-end patch alone does not prove Idempotency. Inspect the current Edge Function/RPC contract and demonstrate that the same operation ID returns the original result without creating a second PO. Do not change server code or SQL under this Buyer-only patch without a separate evidence-based scope decision.

## Required next actions — do not restart
1. Owner applies the two exact Buyer-only edits above to the intended Buyer copy; preserve a rollback copy first.
2. Read back the edited file and verify only the intended lines changed beyond the already-approved Buyer branch changes.
3. Inspect the live CREATE_PO Edge Function/RPC implementation and confirm the operation ID is persisted/enforced end-to-end.
4. Run a safe authenticated test: first successful PO draft, then retry with the exact same operation ID; verify exactly one PO and a stable returned result. Ensure deterministic cleanup or transaction rollback.
5. Run authenticated browser E2E for PO creation, invoice creation, invoice details, draft edit/delete, and validation failures.
6. Resolve or explicitly accept the server-side invoice-ownership boundary: client-side created_by filtering is not authorization. Do not represent it as data isolation.
7. Verify Cloudflare served Buyer artifact against the approved Git source after owner publication. A branch commit or GitHub merge is not deployment proof.
8. Append new evidence to the Buyer report and update this file only after the corresponding action is actually completed.

## Change-control boundaries
- This checkpoint concerns Buyer only. Do not modify main.html, core.js, Receiver, unrelated apps, schema, RLS, Edge Functions, or Production business data as part of the owner-side HTML patch.
- PR #10 remains Draft and unmerged. No merge or deployment was performed by this documentation update.
- Do not call the Buyer task complete until owner patch, Idempotency contract/runtime proof, authenticated E2E, invoice authorization decision, and served-artifact verification are each explicitly classified.

---
# CURRENT EXECUTION HANDOFF — REALTIME SYNCHRONIZATION — 2026-10-31

## Current status
- **Active work:** Phase 3 — resolve remaining parent Realtime channel incompatibilities and complete freshness classification.
- **Phase 1:** COMPLETE only for source census / selected RLS definition review. The earlier 29-page count is corrected to 30 in Phase 2.
- **Phase 2:** Parent source/bootstrap trace COMPLETE; full page freshness classification and authenticated runtime proof remain OPEN.
- **Phase 3 inventory_counts:** Production tenant policy/grants corrected and SQL-tested; Counter query and general-count payload corrected in GitHub main. Counter/Edge Function browser E2E remains OPEN.
- **Overall mission:** OPEN. Do not claim all-app synchronization, two-company browser isolation, Cloudflare parity, or E2E completion.

## Latest verified checkpoint
- Phase 2 report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE2_PARENT_BOOTSTRAP_20261031.md`.
- Phase 3 report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE3_INVENTORY_COUNTS_20261031.md`.
- Master execution log: `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Latest Phase 3 report commit: `4ea534eaeb7ce4dee2fa68e8b0fbd1172265effd`.
- Latest master log commit: `e9e26ab230b359ab5b60a4f4668c9895569df220`.
- Production migration `harden_inventory_counts_tenant_read_boundary_20261031`, version `20261031171715`: applied successfully.
- `inventory_counts`: old permissive FOR ALL policy removed; new SELECT-only policy `inventory_counts_select_company_authorized` scopes by verified company and authorized active role/permissions. anon and authenticated direct writes revoked; authenticated SELECT retained; service_role writes retained.
- SQL verification: authorized warehouse user sees same-company fixture and not other-company fixture; unauthorized same-company user sees zero. All fixtures rolled back; zero residue.
- Privilege verification: anon SELECT/INSERT false; authenticated SELECT true and INSERT/UPDATE/DELETE false; service_role INSERT/UPDATE true; authenticated `inventory_control` EXECUTE true; direct authenticated `inventory_count_engine` EXECUTE false.
- Counter source commit for company filter: `2ddab280b9e0fc362e96f28acd897a2a3b6e1150`.
- Counter source commit for general-count payload: `204b36d7518a4fc88732f990ad3dfa0cec105124`; sends null when general entity is empty so Edge Function can resolve configured `app_settings.main_branch_id`. Production confirms main branch mapping exists and belongs to the same company.
- Edge Function `save-inventory-count`: ACTIVE v5, JWT required, uses service_role, resolves company from auth_id, and routes count writes through `inventory_count_engine`. Parent writes use guarded `inventory_control`.
- No active user currently has `active_warehouse_role='جرد'`; Counter browser E2E and real general-count submission remain OPEN.
- Parent direct channel incompatibilities: Sales Decision (not in publication and direct RLS denied), Loyalty (same), Customer Payments and Commission (service_role-only policies with authenticated browser client). Do not weaken RLS or add publication membership without proving an authorized read model.
- Parent source blob: `53b5a9e9d0433a785c3d5471a9c0d68c25497882`; 33,358 lines; parent uses its own Supabase client and 8 direct channels.
- Current HTML inventory: 30 files; 6 explicit `RW_Realtime.start`, 24 without explicit start. Do not treat absence as a defect.
- Production has active auth-linked users for only one company; real two-company browser E2E remains BLOCKED.
- Supabase Security Advisor after the RLS fix has no `inventory_counts` finding; unrelated findings remain: 24 RLS-enabled/no-policy tables, 3 SECURITY DEFINER views, 3 mutable-search-path functions, 20 anon and 121 authenticated executable SECURITY DEFINER functions, leaked-password protection disabled.

## Next executable actions — do not restart
1. Resolve authenticated refresh strategy for Sales Decision, Loyalty, Customer Payments, and Commission without exposing service-role-only tables.
2. Complete per-page freshness classification for all 30 HTML files by tracing actual timer callbacks, focus/visibility handlers, router bootstrap, and manual refresh paths.
3. Test HR, Inventory, Sales Targets, Purchasing, and Warehouse Vouchers Realtime under authenticated JWTs; use two real tenant identities in an isolated test environment before claiming cross-company isolation.
4. Run Counter Edge Function/general-count browser E2E when an authorized Counter identity is available; verify cleanup and resulting count state.
5. Verify Cloudflare served artifact separately from GitHub commits, then run browser E2E.
6. Write an independent report and update this file after each completed phase or material checkpoint.

## Handoff contract
Read section 8 of `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md` and the independent Phase 2/Phase 3 reports before continuing. Each phase must include exact evidence, timestamps, source SHAs, CONFIRMED/UNKNOWN/CONFLICT/UNVERIFIED findings, change/test ledger, rollback/cleanup, blockers, and next executable action.

**Truth rule:** reports are navigation/history, not truth. Re-query mutable Production and Cloudflare before claims. A commit is not deployment; a subscription declaration is not proof of event delivery. Do not weaken RLS to make a channel appear to work.

---

# CURRENT EXECUTION HANDOFF — REALTIME SYNCHRONIZATION — 2026-10-31

## Current status
- **Active work:** Phase 3 — resolve remaining parent Realtime channel incompatibilities and complete freshness classification; first P0 tenant-boundary subtask is closed.
- **Phase 1:** COMPLETE only for source census / selected RLS definition review. The earlier 29-page count is corrected to 30 in Phase 2.
- **Phase 2:** Parent source/bootstrap trace COMPLETE; complete page freshness classification and authenticated runtime proof remain OPEN.
- **Phase 3 inventory_counts subtask:** COMPLETE for Production RLS/grant correction and source query hardening; Counter/browser E2E remains OPEN.
- **Overall mission:** OPEN. Do not claim all-app synchronization, two-company browser isolation, Cloudflare parity, or E2E completion.

## Latest verified checkpoint
- Phase 2 report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE2_PARENT_BOOTSTRAP_20261031.md`.
- Phase 3 inventory-counts report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE3_INVENTORY_COUNTS_20261031.md`.
- Master execution log: `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Phase 3 report commit: `c7346670ec996760426cf4218f535855c205605c`.
- Master log update commit: `dba3c08c7a1d6376dd5e9f6f944e22dd725bc06d`.
- Production migration `harden_inventory_counts_tenant_read_boundary_20261031`, version `20261031171715`: applied successfully.
- `inventory_counts`: old permissive FOR ALL policy removed; new SELECT-only policy `inventory_counts_select_company_authorized` scopes by verified company and authorized active role/permissions. anon and authenticated direct writes revoked; authenticated SELECT retained; service_role writes retained.
- Verified privileges: anon SELECT/INSERT false; authenticated SELECT true and INSERT/UPDATE/DELETE false; service_role INSERT/UPDATE true; authenticated `inventory_control` EXECUTE true; direct authenticated `inventory_count_engine` EXECUTE false.
- SQL transaction test with simulated JWT: authorized warehouse user sees same-company test row and not other-company row; unauthorized same-company user sees zero rows. All fixtures rolled back; final residue count zero.
- Supabase Security Advisor rerun has no `inventory_counts` finding; separate security backlog remains (24 RLS-enabled tables without policies, 3 SECURITY DEFINER views, 3 mutable-search-path functions, 20 anon and 121 authenticated executable SECURITY DEFINER functions, leaked-password protection disabled).
- GitHub source patch: `companies/company-1/warehouse/counter.html` adds missing company guard and company filter to count-history query. Commit `2ddab280b9e0fc362e96f28acd897a2a3b6e1150`; readback PASS. **Cloudflare deployment not verified.**
- Edge Function `save-inventory-count`: ACTIVE v5, JWT required, uses service_role, resolves company from auth_id, and routes count writes through `inventory_count_engine`. Parent writes use guarded `inventory_control`.
- Open Counter issue: no active user currently has `active_warehouse_role='جرد'`; Counter browser E2E cannot be run. Its legacy general-count caller sends `entityId='MAIN'` although the Edge Function expects a branch UUID or null; investigate before closing the Counter workflow.
- Parent direct channel incompatibilities: Sales Decision (not in publication and direct RLS denied), Loyalty (same), Customer Payments and Commission (service_role-only policies with authenticated browser client). Do not weaken RLS or add publication membership without proving an authorized read model.
- Parent source blob: `53b5a9e9d0433a785c3d5471a9c0d68c25497882`; 33,358 lines; parent uses its own Supabase client and 8 direct channels.
- Current HTML inventory: 30 files; 6 explicit `RW_Realtime.start`, 24 without explicit start. Do not treat absence as a defect.
- Production has active auth-linked users for only one company; true two-company browser E2E remains BLOCKED.

## Next executable actions — do not restart
1. Resolve the Counter general-count payload mismatch and verify the expected active Counter role/permission contract; do not invent a user or production fixture.
2. Inspect and classify parent channels for Sales Decision, Loyalty, Customer Payments, and Commission. Preserve server-side-only access; use authorized refresh/read APIs rather than exposing their tables.
3. Finish the 30-page freshness matrix by tracing actual timer callbacks, focus/visibility handlers, router bootstrap, and manual refresh paths.
4. Test HR, Inventory, Sales Targets, Purchasing, and Warehouse Vouchers Realtime under authenticated JWTs. Use two real tenant identities in isolated test environment before claiming cross-company isolation.
5. Verify Cloudflare served artifact separately from GitHub commit, then run browser E2E.
6. Write an independent report and update this file after each completed phase or material checkpoint.

## Handoff contract
Read section 8 of `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md` and the independent Phase 2/Phase 3 reports before continuing. Each phase must include exact evidence, timestamps, source SHAs, CONFIRMED/UNKNOWN/CONFLICT/UNVERIFIED findings, change/test ledger, rollback/cleanup, blockers, and next executable action.

**Truth rule:** reports are navigation/history, not truth. Re-query mutable Production and Cloudflare before claims. A commit is not deployment; a subscription declaration is not proof of event delivery. Do not weaken RLS to make a channel appear to work.

---

# CURRENT EXECUTION HANDOFF — REALTIME SYNCHRONIZATION — 2026-10-31

## Current status
- **Active work:** Phase 3 — tenant-safety and Realtime channel compatibility remediation design, starting with `inventory_counts`.
- **Phase 1:** COMPLETE only for the source census and selected RLS definition review; its earlier 29-page count is corrected to 30 in Phase 2 because `index.html` was omitted.
- **Phase 2:** Parent source/bootstrap trace COMPLETE; complete page freshness classification and authenticated runtime proof PARTIAL/OPEN.
- **Overall mission:** OPEN. Do not claim all-app synchronization, cross-company runtime isolation, Cloudflare parity, or E2E completion.

## Latest verified checkpoint
- Detailed Phase 2 report: `doc/Draft/Reprots/REALTIME_SYNC_PHASE2_PARENT_BOOTSTRAP_20261031.md`.
- Master execution log: `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Phase 2 report commit: `43fdbba23b2368c71bfc96c1cdbd111a99c12c0f`.
- Master log update commit: `88f458779888b7cc7e60409bcd9804f774f0ef8a`.
- Parent source retrieved completely from Git blob: `companies/company-1/main.html`, blob `53b5a9e9d0433a785c3d5471a9c0d68c25497882`, 33,358 lines. Parent has its own Supabase client and 8 direct Realtime channels; it does not load `core.js` or call `RW_Realtime.start`.
- Current HTML inventory: 30 files under `companies/company-1/`; 6 explicitly call `RW_Realtime.start`, 24 do not. The 24 must not be treated as defects by absence alone.
- Standalone direct-channel exceptions: `sales/manager.html` and `warehouse/vouchers.html`.
- **P0 confirmed Production policy defect:** `inventory_counts` has RLS enabled but its only policy is `allow_all_inventory_counts` FOR ALL with only `auth.role()='authenticated'`; no company predicate, despite company_id. Authenticated has all CRUD grants. `warehouse/counter.html` line 137 reads latest rows without company filter. Table had 0 rows at audit, so no actual disclosure was observed, but future rows would be exposed across tenants by this policy. Parent direct read is line 17437 and Realtime listener line 18274.
- Parent `inventory_control` RPC checks authenticated actor/company/permissions; `inventory_count_engine` is not directly executable by authenticated. Preserve this guarded path.
- Parent subscriptions that are incompatible with current DB setup: Sales Decision (not published and direct access denied), Loyalty (not published and direct access denied), Customer Payments and Commission (service_role-only RLS policies while browser client is authenticated). Do not add these tables to publication or weaken RLS merely to make channels subscribe.
- Sales Targets, Purchasing Gold, and HR channels have publication membership and RLS policies; HR and other direct channels rely on RLS without explicit company filters. Runtime proof remains open.
- Production `inventory_counts` had zero rows; active auth-linked users were found for only one company. Two-company E2E is BLOCKED until a separate test tenant/user is available.
- No application code, Production schema/data/policy, publication, or Cloudflare deployment was changed during Phase 2.

## Next executable actions — do not restart
1. Inspect the existing `save-inventory-count` Edge Function contract and all caller paths; confirm whether any client requires direct table writes.
2. Confirm Counter and van-sales count-role semantics. Design a company-and-role-scoped SELECT policy for `inventory_counts`; remove direct write grants only after caller inventory proves all writes use the guarded function/RPC path.
3. Make a minimal, reversible RLS correction and add the missing company filter to `warehouse/counter.html`; verify read isolation, intended count roles, and write path before declaring fixed.
4. Reconcile parent direct channels with incompatible publication/RLS settings; retain data privacy and use only an already-authorized API/refresh path.
5. Finish per-page freshness classification for all 30 HTML files, then authenticated two-company Realtime E2E in an isolated test environment.
6. Verify Cloudflare served artifacts separately from Git commits; finish the remaining app integration and E2E phases.
7. Append a standalone report and update this file after every completed phase or material checkpoint.

## Handoff contract
Read section 8 of `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md` and the independent Phase 2 report before continuing. Record exact evidence, timestamps, source SHAs, findings classification, change/test ledger, cleanup/rollback, blockers, and next action.

**Truth rule:** reports are navigation/history, not truth. Re-query mutable Production and deployed Cloudflare state before claims. A commit is not deployment; a subscription declaration is not proof of event delivery. Do not modify RLS/publication until the intended role/company contract is established.

---

# CURRENT EXECUTION HANDOFF — REALTIME SYNCHRONIZATION — 2026-10-31

## Current status
- **Active phase:** Phase 2 — parent/router bootstrap and per-application freshness trace.
- **Phase 1:** COMPLETE for the 29-entry-point source census and selected Production RLS policy-definition review only. This does NOT prove authenticated tenant isolation.
- **Phase 2:** PARTIAL. Shared `RW_Realtime` contract reviewed; Warehouse Vouchers direct-channel exception identified. Parent `main.html` remains UNVERIFIED because connector content retrieval failed due file size. This is a tooling blocker, not proof of a source defect.
- **Overall mission:** OPEN. Do not claim all-app synchronization, Cloudflare parity, or end-to-end completion.

## Last verified event
- The latest Phase 2 report and mandatory handoff protocol were committed to `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Report commit: `fa2b9ef19dbcc209f0456df4915b63dfbf3919f2`.
- Phase 1 census: 29 HTML entry points; 6 explicit shared-engine starters; 23 without explicit `RW_Realtime.start` in their own source. The 23 are not automatically defects.
- Shared engine guard: `RW_Realtime.start` checks requested company against `RW_Auth.getUser().company_id`; preserve this guard.
- Direct-channel exception: `warehouse/vouchers.html` listens to `stock_voucher_details` without explicit company filter; verify effective RLS and authenticated event behavior before changing it.
- Production publication: 81 tables, as recorded in the earlier timestamped Production query. Refresh this fact before relying on it.

## Required next actions — do not restart
1. Obtain `companies/company-1/main.html` through a bounded Git blob/API read or a local repository checkout; previous connector whole-file and raw-content reads failed due size.
2. Trace the parent/router bootstrap and identify how it loads shared core and each app.
3. Build the 29-entry-point freshness matrix: shared Realtime / direct Realtime / polling / focus-visibility refresh / explicit manual refresh / read-only-static / UNKNOWN. Cite file/function/line or blob SHA for each classification.
4. Inspect all direct Realtime channels and their table filters; validate company scope and RLS.
5. Run authenticated two-company tests before broadening subscriptions.
6. Only then make minimal app-specific changes; verify Git readback, deployment parity, and browser E2E separately.
7. Append a phase report and update this file after EVERY completed phase or material checkpoint.

## Handoff contract
Read the mandatory phase-by-phase protocol in `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`, section 8. Each phase record must include exact evidence sources and timestamps, inspected inventory, CONFIRMED/UNKNOWN/CONFLICT/UNVERIFIED findings, change ledger, test ledger, rollback/cleanup, exit decision, blockers, and next executable action.

**Truth rule:** reports are navigation and history, not the source of truth. Re-query mutable Production and deployed Cloudflare state at the time of any final claim. Never equate a commit with deployment or a subscription with proven synchronization.

---

# PHASE 1 COMPLETE — REALTIME CONSUMER CENSUS & RLS REVIEW — 2026-10-31

- Detailed record: `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md` (Phase 1, section 6).
- Repository census: 29 HTML entry points; 6 explicitly call `RW_Realtime.start`; 23 do not explicitly start it in their own source. Do not call the 23 defects until router/bootstrap and freshness requirements are traced.
- Current explicit subscribers: Purchasing Buyer (`purchase_orders`), Purchasing Supervisor (`purchase_orders`), Warehouse Loader (`runsheets`), Warehouse Manager (`stock_vouchers,purchase_orders`), Warehouse Receiver (`purchase_orders`), Warehouse Supervisor (`purchase_orders,stock_vouchers`).
- Production RLS definitions inspected for branches, customers, items, stock_branches, purchase_orders, stock_vouchers, runsheets. Tenant company predicates exist in the inspected policies; stock_branches is scoped through the owning branch relation.
- Runtime two-company isolation, all mutation policy completeness, and Realtime delivery under authenticated JWTs remain OPEN.
- Phase 1 source census/policy-definition review: COMPLETE. Overall synchronization: OPEN.
- Next priority: trace parent/router bootstrap, classify all 23 non-explicit subscribers by freshness requirement, then run authenticated cross-company isolation tests before adding more subscriptions.
- Phase 1 report commit: `ec88aff753672a5de49018fddaef2e47d360ee01`.

---

# LATEST VERIFIED CHECKPOINT — 2026-10-31 — REALTIME SYNCHRONIZATION CONTINUATION

- Detailed execution record: `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Supabase Production `supabase_realtime` publication count: **81 tables**, directly queried at 2026-10-31 16:53:54 UTC.
- Current shared core `companies/company-1/core.js` contains `RW_Realtime`; blob SHA: `a95ee6b29ff54b4a240ce4b81f9a535aa87686db`.
- Latest source before this checkpoint: `0b511d04ff9574b722f7531148dab2f6529a1eee`, wiring warehouse Loader to tenant-scoped Realtime.
- Confirmed/fixed defect: warehouse Supervisor handled `stock_vouchers` events but subscribed only to `purchase_orders`. Production confirms both tables are published and both contain `company_id`. Surgical source correction adds `stock_vouchers` to the subscription.
- Fix commit: `1ac88d795eaa6dbe9b6720b497cd4e1684e32651`; file readback PASS.
- Documentation commit: `1399e75379c5a7f98b08f2a333f1f094eceb0141`.
- No Supabase schema/data change was made. The commit status endpoint returned no status records; do not report CI PASS.
- RLS is enabled on `branches`, `customers`, `items`, and `stock_branches`; policy expressions and authenticated cross-company behavior remain to be audited.
- All-app consumer census, Cloudflare served-artifact parity, authenticated browser E2E, and formal test A–E mapping remain OPEN. Do not claim full synchronization.
- Next: continue app-by-app source census and policy inspection, then authenticated cross-company E2E and Cloudflare parity verification. Preserve the verified company scope guard in `RW_Realtime.start`.

---

# LATEST VERIFIED CHECKPOINT — 2026-10-30 — SAVE-ITEM 401 / SHARED AUTH SESSION

## الحالة المثبتة حتى الآن

- **النطاق:** إصلاح خطأ `401 UNAUTHORIZED_ASYMMETRIC_JWT` عند استدعاء `save-item` من تطبيق مدخل بيانات الأصناف.
- **المستودع والفرع:** `papamohammed77-glitch/erp-frontend` / `main` فقط.
- **السبب الجذري المؤكد:** `RW_Auth.getToken()` كان يعيد access token قديمًا من `currentSession` بعد انتهاء صلاحيته، لأن `core.js` لم يكن يزامن النسخة المحلية مع حدث `TOKEN_REFRESHED` من Supabase.
- **دليل Production:** الرمز نفسه (ES256) نجح قبل انتهاء صلاحيته عند 11:31 و11:37 و11:41 UTC، وانتهت صلاحيته عند 12:20:08 UTC، ثم فشلت طلبات 12:31 و12:34 و12:35 UTC بـ401 و`UNAUTHORIZED_ASYMMETRIC_JWT`. ظهر طلب تجديد جلسة ناجح 200 عند 12:42:26 UTC. هذا يثبت أن ES256 ليس سببًا بحد ذاته.
- **تصحيح المصدر:** أضيف مستمع `supabase.auth.onAuthStateChange` مركزي داخل `RW_Auth` في `companies/company-1/core.js` لتحديث `currentSession/currentUser` عند وصول أحداث الجلسة، ومسح الحالة عند `SIGNED_OUT`.
- **Commit main:** `260dd402ffa527dd6b5dc0980e523846f00172de`.
- **Core blob بعد التعديل:** `3cf992d8179a374b60622faba9e60dde43c9a21e`.
- **التحقق الساكن:** إعادة جلب الملف من `main` PASS؛ وجود listener في موضعه PASS؛ تحليل JavaScript كاملًا PASS؛ التغيير محصور في `core.js`.
- **GitHub Actions:** شُغّل workflow رقم `41057760629` عند commit التوثيق؛ فشل فحص Inventory static audit بسبب علامتي `TODO` موجودتين في `companies/company-1/main.html`، وهي خارج نطاق التعديل، وتخطى اختبار المتصفح. لا يُعد ذلك اختبارًا أو فشلًا لإصلاح المصادقة.
- **ما لم يتغير:** `warehouse/data.html`، وEdge Function `save-item`، و`verify_jwt=true`، وRLS وقاعدة البيانات والصلاحيات.
- **ملاحظة تصحيحية:** لا يوجد دليل أن غياب `apikey` تسبب في هذه الواقعة؛ الطلبات الناجحة والفاشلة في عينة السجلات أظهرت غياب بيانات apikey نفسها. لا تُكرر تعديل apikey كحل مزعوم دون دليل مستقل.
- **حالة Cloudflare/Production:** هوية الملف المنشور بعد commit غير متحققة؛ لا يوجد تأكيد أن Pages قد نشرت التعديل.
- **حالة E2E:** لم يتوفر اتصال المتصفح المحلي في سياق التنفيذ؛ اختبار `TOKEN_REFRESHED` ثم طلب Edge مصادق عليه وإعادة القراءة ما زال PENDING. لا تعتبر المشكلة مغلقة تشغيليًا.
- **Edge Function:** `save-item` ما زالت ACTIVE version 16 و`verify_jwt=true`. لا تغيّرها ولا تعطل التحقق.
- **التقرير:** `doc/Draft/Reprots/SUPABASE_SAVE_ITEM_401_STALE_SESSION_FORENSIC_20261030.md`.

## الخطوة التالية الإلزامية

1. إثبات أن Cloudflare Pages تخدم نسخة `core.js` التي تحتوي listener الجديد.
2. فتح تطبيق مدخل البيانات بجلسة مستخدم مصادق عليها.
3. التحقق من أن `TOKEN_REFRESHED` يحدّث `RW_Auth.getToken()` دون كشف قيمة JWT.
4. تنفيذ طلب قراءة فقط عبر مسار Edge المركزي بعد التجديد.
5. بعد موافقة/اعتماد سجل اختبار آمن فقط، اختبار `save-item` ثم إعادة قراءة السجل.
6. مراجعة سجلات Supabase للطلب نفسه، ثم تحديث هذا الملف والتقرير بالنتائج الفعلية.

**حالة الإغلاق:** ROOT CAUSE CONFIRMED · MAIN SOURCE PATCH COMMITTED · DEPLOYMENT/E2E PENDING.

---

# LATEST VERIFIED CHECKPOINT — 2026-10-27 — DELIVERY SUPERVISOR → PARENT ASSIGNMENTS

## الحالة الحالية المثبتة في هذه الجلسة

- **النطاق:** ظهور إسنادات تطبيق مشرف التوصيل داخل النظام الأم: إدارة الشحن والتوصيل ← مناديب التوصيل.
- **المستودع التشغيلي:** `papamohammed77-glitch/erp-frontend`.
- **HEAD الكود وقت المطابقة قبل تحديث سجل الحالة:** `229dffddb7983df014369d6dc94157d102c2749e` — `Document delivery supervisor parent integration correction and verification`. تحديثات هذا السجل لاحقة وتوثيقية فقط.
- **مصدر النظام الأم:** `companies/company-1/main.html`; يحتوي المصدر الحالي على جدول منفصل لإسنادات الرانشيت من مشرف التوصيل. Blob SHA الظاهر في شجرة Git الحالية: `0c1745081e8d17480433ed527d77cac9f5292021`.
- **تعديل الواجهة:** `cb62612a174f5b1a8d5aa5a41a4c3e5747bb73fc` — أضاف عرض `runsheet_assignments` إلى `RW_DeliveryLogistics.agents()`.
- **تعديل عقد Production:** Migration `20261027_delivery_supervisor_parent_runsheet_assignments.sql` في commit `41475240d2685cb7a7919e372e1e9ba10539f3e6`.
- **فحص Production المباشر في هذه الجلسة:** `delivery_logistics_query(..., 'agents', ...)` أعاد `success=true` و`registered_agent_rows=0` و`assigned_runsheet_rows=2` و`assigned_rows_with_name=2`. لم تُنشأ أو تُعدّل بيانات أعمال.
- **السبب الجذري:** إسناد المشرف محفوظ في `runsheets.deliverer_id → users.id`، بينما سجل اللوجستيات المستقل محفوظ في `delivery_agents`. الواجهة القديمة كانت تعرض السجل الثاني فقط؛ لذلك لم تُظهر إسنادات الرانشيت إذا لم يوجد سجل لوجستيات مرتبط. الإصلاح يعرض الإسنادات من مصدرها التشغيلي دون اختلاق سجلات مندوبين.
- **ما لم يُثبت بعد:** لم تتوفر في هذه الجلسة هوية نشر Cloudflare أو عنوان Production المنشور المؤكد، ولم يُنفّذ HTTP E2E من جلسة مستخدم فعلية. لذلك الحالة `CORRECTED — PRODUCTION UI VERIFICATION PENDING` وليست `100% CLOSED`.
- **التقرير الكامل:** [DELIVERY_SUPERVISOR_PARENT_INTEGRATION_CLOSEOUT_20261027.md](doc/Draft/Reprots/DELIVERY_SUPERVISOR_PARENT_INTEGRATION_CLOSEOUT_20261027.md).
- **الخطوة التالية الوحيدة:** مطابقة الملف المنشور فعليًا في Cloudflare مع مصدر Git الحالي، ثم فتح تبويب «مناديب التوصيل» بجلسة مصادق عليها والتأكد من ظهور الإسنادين. لا تُعدّل RPC أو بيانات Production ما لم يظهر Defect جديد مثبت.

---

# LATEST AUTHORITATIVE CHECKPOINT — 2026-09-23 18:05 UTC

## Current Mother Source
- HEAD: `3eedbc60a940f8d4fffadb9d152bd362c3f8be04`
- Parent: `9429006baa94eb92ffd5f215e2b085288681b94f`
- `companies/company-1/main.html` blob: `6ea44f1a26ce6069855842dc9010a21acc726ad9`
- Latest HEAD commit `3eedbc...` changes only `_forensic_current_main_extract.md`.

## Current Syntax Incident
The `main:6805 Unexpected token 'var'` defect is reproduced from current source and from GitHub Actions.
Root cause: commit `9429006...` deleted the two `function openModal(code) {` declarations in `RW_Customers` and `RW_Suppliers`, leaving their bodies and closing braces intact.

## Surgical Owner Fix — main.html
Restore only these two declarations:
1. Immediately before `const c = code ? data.find(x => x.customer_code === code) : null;` in `RW_Customers`:
```javascript
    function openModal(code) {
        const c = code ? data.find(x => x.customer_code === code) : null;
```
2. Immediately before `const s = code ? data.find(x => x.supplier_code === code) : null;` in `RW_Suppliers`:
```javascript
    function openModal(code) {
        const s = code ? data.find(x => x.supplier_code === code) : null;
```

Do not replace full functions and do not touch `_handleSave`.

## Verification
- Current-source Node parse: FAIL before patch.
- In-memory two-line repair: PASS.
- GitHub Actions run `35876538098`, syntax job `107233790170`: FAIL at exact line 6805 with same error.
- No assistant write has been made to `main.html`.

## Deployment/E2E
- Existing CI syntax gate is present and correctly detected the regression.
- Publish/served artifact identity: OPEN.
- Authenticated browser E2E: OPEN.
- Tailwind CDN message is a separate non-blocking production warning; not part of this syntax closure.

## Continuity
Do not reopen Report320 Branch/Fleet closures or closed inventory contracts without new CURRENT evidence.

---

# RAWAEA ERP — CURRENT STATE

> هذا الملف هو Living Execution State وليس مصدرًا أعمى للحالة الحالية. يجب دائمًا مطابقة محتواه مع CURRENT GIT + CURRENT SOURCE + CURRENT PRODUCTION + CURRENT DATABASE + CURRENT DEPLOYMENT EVIDENCE.

## Current Session

- **Date:** 2026-09-16
- **Current repository:** `papamohammed77-glitch/erp-frontend`
- **Source of Truth:** `companies/company-1/main.html`
- **Main HEAD:** `6b3b500f2da361b1522f6e9f33d87f64cb0e8114`
- **HEAD message:** `Refactor functions to use RW_Finance namespace`
- **HEAD parent:** `2af93b03a0bc5c46e2126d329154c6d176f0d098`
- **Current main extract:** 24,134 lines; SHA256 `06452de29b1a55c7e3a63a50c7267c70561d93cca4743c84c2387767b11da675`

## Current Verified Findings

### Mother Finance Console defects

1. `main:14542 Uncaught ReferenceError: _renderPeriods is not defined`
   - Root cause: commit `6b3...` changed eight internal renderer calls to `RW_Finance._render...`, but those renderer functions are not exposed under those names.
   - Correct owner fix: restore the parent commit's internal calls in that exact eight-line dispatcher block.

2. `RW_Finance._goldOpenPeriod is not a function`
3. `RW_Finance._goldAddAsset is not a function`
4. `RW_Finance._goldTaxCode is not a function`
   - Root cause: Gold Extension exports `gold*` functions, while public `RW_Finance` only had `_goldJournalList` bound.
   - Correct owner fix: add explicit `_gold*` aliases at the final namespace binding.

5. `get_budget_vs_actual` returned HTTP 403 from the REST RPC path.
   - Production function exists and is company-context aware.
   - Root cause proven from `information_schema.routine_privileges`: `authenticated` lacked EXECUTE.
   - Production fix applied: grant EXECUTE to `authenticated` and `service_role`; revoke PUBLIC/anon.
   - Authenticated DB-context verification passed in transaction.

## Production Change Applied

```sql
BEGIN;
REVOKE ALL ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) TO authenticated, service_role;
COMMIT;
```

## Current Architecture Decision

- `forensic_main_assembly.yml` is already correct and points to:
  - repository: `papamohammed77-glitch/erp-frontend`
  - path: `companies/company-1/main.html`
  - ref: `main`
  - `published_main_is_authoritative`
  - `historical_reference_only` for fragments.
- `Current/PWA/main2` remains historical/advisory only.
- Mother `main.html` was **not edited by the assistant**; owner applies surgical source changes.
- Production changes are performed directly by the assistant when proven necessary.

## Current Owner Action Required

Apply the surgical changes documented in:

`doc/Draft/Reprots/Report217_MOTHER_FINANCE_FORENSIC_E2E_20260916.md`

Required source changes:

- CHANGE A: restore the eight internal `RW_Finance` renderer calls at the dispatcher around line 14542.
- CHANGE B: bind all required `_gold*` aliases to `RW_Finance_GoldExtension`.
- Apply the modal UX replacements specified in the same report before declaring the source-side Finance E2E closure.

## What Is Closed

- Production permission root cause for `get_budget_vs_actual`: **CLOSED / PRODUCTION VERIFIED**.
- `forensic_main_assembly.yml` source-of-truth path: **VERIFIED**.

## What Is Not Yet Closed

- Real browser E2E after owner applies CHANGE A/B.
- Visual/interactive validation of the improved asset/tax/disposal/period modals.
- Final Finance E2E zero-console-error pass.

## Required Next Session Start

1. Read this file, but verify all claims against current sources.
2. Check the latest `erp-frontend` commit and its parent.
3. Open current `companies/company-1/main.html`.
4. Confirm CHANGE A and CHANGE B were actually applied; do not repair them again if already present.
5. Open Finance and execute real clicks in the browser.
6. Capture the exact first new Console error and trace it to source → public export → RPC → Production.
7. Re-check Production function signatures and privileges before any backend edit.
8. Only then proceed to the next open Finance closure unit.

## Continuity Rule

No previous report, assistant summary, or historical fragment overrides current Git/Source/Production/Database evidence.


---

# LATEST AUTHORITATIVE CHECKPOINT — 2026-09-24 — MOTHER SUPPLIERS / RESPONSIBLE BUYER

## Current primary-source truth
- Repository HEAD: `47ff966a23e89b19666485ac239455ec9a06a79d`
- Parent: `3bd5ab664608e7a7632ce978d7b50c3181508516`
- `companies/company-1/main.html` blob: `2b14edfaaa2dc1c64af386a187b795aca9e239a9`
- Source line count verified: 32,075
- Assistant direct modification to `main.html`: NO

## Reconciled history
Commit `3bd5ab...` introduced the current Responsible Buyer smart-search UI.
Commit `47ff966...` updated only forensic documentation.
Older Report326 source blob `f4e707...` is historical.

## Defect and root cause
Target:
`RW_Suppliers.openModal(code)` → `#supp-rep`, line **6938**

The page has:
`var supabase = RW_SUPABASE_CLIENT;`
inside a private IIFE and also exposes:
`window.RW_SUPABASE_CLIENT = client;`

The smart search was embedded in an inline HTML event handler and called:
`supabase.rpc(...)`

The inline handler cannot close over the IIFE-local variable, so `supabase` resolves to the global UMD SDK namespace, producing:
`Uncaught TypeError: supabase.rpc is not a function`

## Exact owner fix
Replace only the single existing `#supp-rep` element inside `RW_Suppliers.openModal(code)`.

Change only:
`supabase.rpc('get_supplier_purchase_reps', ...)`
to:
`window.RW_SUPABASE_CLIENT.rpc('get_supplier_purchase_reps', ...)`

Complete replacement:
`doc/Draft/Reprots/Report327_MOTHER_SUPPLIER_PURCHASE_REP_INLINE_SCOPE_FORENSIC_CLOSURE_20260924.md`

## Production
- `get_supplier_purchase_reps(text)`: canonical SECURITY DEFINER.
- authenticated EXECUTE = true.
- anon EXECUTE = false.
- company-aware and permission-aware.
- `save-supplier`: Version 5 ACTIVE, verify_jwt=true.
- No new Edge Function.
- No Production schema change.
- No inventory/accounting workflow change.

Current baseline:
- suppliers = 2
- inventory_log = 6
- stock_branches = 48
- supplier_ledger = 0
- journal_entries = 8

## Verification
- `#supp-rep` occurrence in current source = 1.
- In-memory corrected RPC receiver = 1.
- Corrected inline handler parse = PASS.
- Production baseline unchanged.
- Existing same-day Supplier → Purchase → Stock → Ledger → Journal E2E remains valid and is not reopened.

## Closure
- Root cause = PROVEN.
- Production backend/data contract = CLOSED / VERIFIED.
- Mother source surgical patch = READY / OWNER ACTION.
- Published artifact identity = OPEN.
- Authenticated Browser E2E after Owner publish = OPEN.
- Responsible Buyer smart-search UI = PARTIALLY CLOSED.

## Exact next resumption
1. Apply Report327 single `#supp-rep` replacement.
2. Parse complete `main.html`.
3. Owner commit/publish.
4. Verify served artifact identity.
5. Run authenticated Browser E2E: Suppliers → Add Supplier → Responsible Buyer search/select → save → reopen → clear → save.
6. Verify Console/Network and `purchase_rep` persistence.
7. Fresh Production snapshot.
8. Update CURRENT_STATE.

## PHASE 2 IN PROGRESS — RUNTIME/BOOTSTRAP TRACE — 2026-10-31

- Phase 2 findings appended to `doc/Draft/Reprots/REALTIME_SYNC_EXECUTION_20261031.md`.
- Shared `RW_Realtime` contract reviewed: verified-profile company guard, company_id filters by default, debounced event delivery, initial/reconnect/periodic/visibility reconciliation.
- Warehouse Vouchers uses a direct channel; `stock_voucher_details` subscription currently has no explicit company filter and requires authenticated RLS/event-scope verification. Do not assume it is equivalent to shared engine.
- Parent `main.html` could not be retrieved by either bounded file fetch or raw-content fetch due response-size limits. Parent runtime status remains UNKNOWN, not defective.
- Do not add broad subscriptions to all 23 pages without classifying their actual freshness requirements.
- Next: retrieve parent source through a bounded Git blob/range or local checkout, complete per-app freshness matrix, then test authenticated tenant isolation.
- Latest phase 2 report commit: `dc42fd54e09c95796aff5c17975fe0460d78cf11`.

---
