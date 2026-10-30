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
