# Report217 — التحقيق الجنائي في الإدارة المالية بالنظام الأم

**التاريخ:** 2026-09-16
**المرحلة:** E2E / Mother Finance
**مصدر الحقيقة المعتمد:** `companies/company-1/main.html` في مستودع `papamohammed77-glitch/erp-frontend`، مع مطابقة Production/Database/Deployment Evidence.

> **النقطة الحاكمة التي يجب قراءتها بعناية:** هذا التقرير لا يعيد تعريف حالة المشروع من التقارير السابقة، ولا يبني قرارًا على الذاكرة. الحالة الحالية لهذه الجلسة بُنيت فقط من CURRENT GIT + CURRENT SOURCE + CURRENT PRODUCTION + CURRENT DATABASE + CURRENT DEPLOYMENT EVIDENCE. التقارير السابقة استُخدمت كدلائل بحث فقط.

## 1. Executive Result

تم تحديد سبب أخطاء Console في الإدارة المالية، وتم تنفيذ إصلاح Production الوحيد المثبت أنه مطلوب دون تعديل `main.html` من جانبي.

### الأخطاء المفحوصة

```text
main:14542 Uncaught ReferenceError: _renderPeriods is not defined
RW_Finance._goldOpenPeriod is not a function
POST /rest/v1/rpc/get_budget_vs_actual 403 (Forbidden)
RW_Finance._goldAddAsset is not a function
RW_Finance._goldTaxCode is not a function
```

### النتيجة الجنائية

هناك مساران سببا الأخطاء:

1. **Regression في commit `6b3b500f2da361b1522f6e9f33d87f64cb0e8114`**: تم تغيير dispatcher في `main.html` من الاستدعاء الداخلي للدوال الخاصة إلى `RW_Finance._render...`، بينما هذه الدوال لم تُصدّر بهذا الاسم على `RW_Finance`. الـparent commit `2af93b03a0bc5c46e2126d329154c6d176f0d098` كان يستعمل الاستدعاء الداخلي المباشر. لذلك العلاج الصحيح هو إعادة هذا الجزء تحديدًا إلى سلوك الـparent، وليس إضافة aliases غير لازمة للـrenderers.

2. **Gold Extension export drift**: الـGold Extension تُعرّف وتعيد `goldAddAsset`, `goldTaxCode`, `goldOpenPeriod`, `goldDispose`, `goldTaxSettle`, `goldDepreciate`, `goldChequeTransition` وغيرها، لكن نهاية `main.html` الحالية تربط فقط `RW_Finance._goldJournalList` إلى `RW_Finance_GoldExtension.journalList`. لذلك الـinline onclick الذي يستدعي `_goldAddAsset`, `_goldTaxCode`, `_goldOpenPeriod` يفشل. العلاج الصحيح هو إكمال طبقة aliases العامة إلى Gold Extension دون تغيير المنطق الداخلي للدوال.

3. **403 في `get_budget_vs_actual` Production**: الدالة موجودة في PostgreSQL، `SECURITY DEFINER`، وتفرض company context عبر `app_private.current_user_company_id()`. لكن `EXECUTE` كان متاحًا لـ`postgres` و`service_role` فقط، وليس `authenticated`. تم إصلاح ذلك في Production بمنح `EXECUTE` لـ`authenticated` مع إبقاء `anon` و`PUBLIC` بلا صلاحية.

## 2. Git Forensic Chain

### Current HEAD relevant to the failure

`6b3b500f2da361b1522f6e9f33d87f64cb0e8114`

رسالة commit:
`Refactor functions to use RW_Finance namespace`

والـparent المثبت مباشرة:
`2af93b03a0bc5c46e2126d329154c6d176f0d098`

Commit `6b3...` غيّر dispatcher في موضع ~14542 من:

```text
_renderJournalList()
_renderRecurringJournals()
_renderExpenses()
_renderCheques()
_renderBankReconcile()
_renderTax()
_renderAssets()
_renderPeriods()
```

إلى:

```text
RW_Finance._renderJournalList()
RW_Finance._renderRecurringJournals()
RW_Finance._renderExpenses()
RW_Finance._renderCheques()
RW_Finance._renderBankReconcile()
RW_Finance._renderTax()
RW_Finance._renderAssets()
RW_Finance._renderPeriods()
```

المسار التاريخي/الـparent يثبت أن التغيير في dispatcher هو موضع regression، وليس نقصًا في منطق المالية نفسه. fileciteturn1307file0L3-L7

كما يثبت commit الخاص بإضافة Gold Extension أن الدوال تعاد داخل Gold Extension بأسماء `gold*`، لكن الربط النهائي الذي ظهر بعد ذلك اقتصر على `_goldJournalList`. fileciteturn1317file0L3-L7 fileciteturn1317file0L59-L79

## 3. Current Source Evidence

الملف الحالي `companies/company-1/main.html` هو Source of Truth لهذا المسار، وعدد الأسطر المثبت في آخر forensic extract هو 24,134 سطرًا، مع SHA256:

`06452de29b1a55c7e3a63a50c7267c70561d93cca4743c84c2387767b11da675`

ويظهر فيه `RW_Finance` والdispatcher المالي في نفس النسخة الحالية. fileciteturn1334file0L2-L2

## 4. Current Production Evidence

### `get_budget_vs_actual`

تعريف Production الحالي:

- الاسم: `get_budget_vs_actual`
- التوقيع: `(integer, integer, uuid)`
- `SECURITY DEFINER = true`
- يستخرج company context عبر `app_private.current_user_company_id()`.

قبل الإصلاح كان `information_schema.routine_privileges` يثبت EXECUTE لـ`postgres` و`service_role` فقط، مع غياب `authenticated`؛ وهذا يفسر الـHTTP 403 مباشرة.

تم تنفيذ Production migration:

```sql
BEGIN;
REVOKE ALL ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) TO authenticated, service_role;
COMMIT;
```

### Production verification

بعد التنفيذ أصبح:

```text
authenticated -> EXECUTE
postgres       -> EXECUTE
service_role   -> EXECUTE
anon           -> no EXECUTE
PUBLIC         -> no EXECUTE
```

كما تمت محاكاة سياق `authenticated` داخل transaction اعتمادًا على `auth_id` حقيقي من جدول `users`؛ وقد أعادت الدالة سياق الشركة الصحيح وأعادت صفوف الميزانية/الفعلية دون 403. لم يتم إنشاء أي بيانات دائمة أثناء الاختبار.

## 5. Production Finance Contract Review

تمت مراجعة التعريفات الحالية للدوال المرتبطة بالأزرار المتأثرة. الوضع الحالي المثبت:

- `finance_open_period` موجود ويستخدم company context guard.
- `finance_close_period` موجود ويستخدم company context guard وفحوصات إغلاق متعددة.
- `finance_save_expense` موجود ويدعم operation idempotency عبر `operation_id`.
- `save_fixed_asset` موجود ويستخدم company context guard وoperation registry.
- `post_fixed_asset_depreciation` موجود ويستخدم period guard وoperation idempotency.
- `finance_dispose_asset` موجود ويستخدم company context guard وoperation idempotency وjournal posting.
- `finance_save_tax_code` موجود ويستخدم company context guard والتحقق من الحسابات.
- `finance_tax_settle` موجود ويستخدم company context guard وoperation idempotency.
- `finance_transition_cheque` موجود ويطبق state transition rules.

لم يتم اختراع جدول جديد لأن البنية الحالية للدوال والـtables تغطي الـcontracts اللازمة للأخطاء الحالية.

## 6. Forensic Decision — لماذا لا نعيد بناء Finance Renderer الآن

الخلل في `RW_Finance` الحالي ليس فقدًا جوهريًا لمنطق `journalList/renderPeriods/renderAssets/...`؛ الدوال موجودة داخل scope الداخلي. Commit `6b3...` فقط جعل dispatcher يشير إلى أسماء غير مُصدّرة. لذلك إعادة كتابة Finance module بالكامل ستكون توسعًا غير مبرر ومخالفة لمنهجية surgical repair.

## 7. Surgical Change Set — Mother main.html

**ممنوع تعديل الملف من طرف المساعد. هذه التعديلات خاصة بالمالك لتطبيقها على Source of Truth الحالي فقط. لا تستخدم `Current/PWA/main2` للاستبدال النهائي.**

### CHANGE A — إصلاح dispatcher عند موضع الخطأ ~14542

**ابحث عن المقطع الذي يبدأ بهذه السطور وينتهي تحديدًا بالسطر الأخير التالي:**

```text
else if (tab === 'journal-list') RW_Finance._renderJournalList();
else if (tab === 'recurring-journals') RW_Finance._renderRecurringJournals();
else if (tab === 'expenses') RW_Finance._renderExpenses();
else if (tab === 'cheques') RW_Finance._renderCheques();
else if (tab === 'bank-reconcile') RW_Finance._renderBankReconcile();
else if (tab === 'tax') RW_Finance._renderTax();
else if (tab === 'assets') RW_Finance._renderAssets();
else if (tab === 'periods') RW_Finance._renderPeriods();
```

**احذف المقطع كاملًا واستبدله كاملًا بهذا المقطع:**

```text
else if (tab === 'journal-list') _renderJournalList();
else if (tab === 'recurring-journals') _renderRecurringJournals();
else if (tab === 'expenses') _renderExpenses();
else if (tab === 'cheques') _renderCheques();
else if (tab === 'bank-reconcile') _renderBankReconcile();
else if (tab === 'tax') _renderTax();
else if (tab === 'assets') _renderAssets();
else if (tab === 'periods') _renderPeriods();
```

**ينتهي المقطع عند:**
`else if (tab === 'periods') _renderPeriods();`

هذا هو إصلاح regression المثبت، وهو مطابق لعقد الـparent. fileciteturn1307file0L7-L7

### CHANGE B — إغلاق Gold alias drift

**ابحث عن العنصر الكامل في آخر `RW_Finance` وبنهاية الملف الحالي:**

```text
window.RW_Finance = RW_Finance;
RW_Finance._goldJournalList = RW_Finance_GoldExtension.journalList;
```

**احذفه كاملًا، بما في ذلك السطر الأخير، واستبدله بهذا العنصر الكامل:**

```text
window.RW_Finance = RW_Finance;
RW_Finance._goldJournalList = RW_Finance_GoldExtension.journalList;
RW_Finance._goldJournalDetail = RW_Finance_GoldExtension.journalDetail;
RW_Finance._goldReverse = RW_Finance_GoldExtension.reverse;
RW_Finance._goldNewRecurring = RW_Finance_GoldExtension.newRecurring;
RW_Finance._goldRunRecurring = RW_Finance_GoldExtension.runRecurring;
RW_Finance._goldNewCheque = RW_Finance_GoldExtension.newCheque;
RW_Finance._goldNewBank = RW_Finance_GoldExtension.newBank;
RW_Finance._goldCloseBank = RW_Finance_GoldExtension.closeBank;
RW_Finance._goldClosePeriod = RW_Finance_GoldExtension.closePeriod;
RW_Finance._goldReopenPeriod = RW_Finance_GoldExtension.reopenPeriod;
RW_Finance._goldAddAsset = RW_Finance_GoldExtension.goldAddAsset;
RW_Finance._goldDepreciate = RW_Finance_GoldExtension.goldDepreciate;
RW_Finance._goldDispose = RW_Finance_GoldExtension.goldDispose;
RW_Finance._goldTaxCode = RW_Finance_GoldExtension.goldTaxCode;
RW_Finance._goldTaxSettle = RW_Finance_GoldExtension.goldTaxSettle;
RW_Finance._goldOpenPeriod = RW_Finance_GoldExtension.goldOpenPeriod;
RW_Finance._goldChequeTransition = RW_Finance_GoldExtension.goldChequeTransition;
```

هذا يغلق أسماء الـinline onclick الحالية التي تتوقع `_gold*`، دون نسخ أو تكرار أي business function. مصدر الأسماء الموجودة داخل Gold Extension مثبت في return object الحالي. fileciteturn1317file0L59-L79

## 8. Modal Improvement — التصميم المطلوب بعد إصلاح alias

الـGold modals الحالية تعمل بشكل بدائي في بعض المواضع، وأهم مشكلة مثبتة من المصدر هي أنها تطلب UUIDs للحسابات يدويًا في:

- `goldAddAsset`
- `goldDispose`
- `goldTaxCode`

وهذا ليس مستوى UX مناسبًا للنظام الأم. تحسينها لا يتطلب تغيير الـProduction contract؛ المطلوب هو استبدال حقول UUID اليدوية بقوائم حسابات محاسبية يتم تحميلها مسبقًا من `chart_of_accounts` مع company scope، والتحقق داخل `preConfirm`، مع `showLoaderOnConfirm` ومنع الإغلاق أثناء الحفظ.

### قاعدة التنفيذ

لا تُغيّر توقيعات RPC الحالية. الـfrontend يتولى اختيار IDs الصحيحة، والـRPC يبقى المرجع النهائي للتحقق والصحة.

## 9. لماذا لم أعدل Production في أجزاء غير لازمة

لم تظهر حاجة مثبتة لإنشاء tables جديدة في هذه الجولة. كما أن البنية الحالية تحتوي بالفعل على:

- fixed assets
- tax codes
- periods
- cheques
- bank reconciliation
- expense categories
- cost centers
- journal entries/lines

لذلك إنشاء جداول بديلة أو duplicate finance engines الآن سيخلق دينًا معماريًا جديدًا، وهو غير مسموح.

## 10. `forensic_main_assembly.yml`

تم فتح الملف الحالي، ومحتواه مثبت بأنه يشير بالفعل إلى:

```yaml
repository: papamohammed77-glitch/erp-frontend
path: companies/company-1/main.html
ref: main
mode: published_main_is_authoritative
fragment_mode: historical_reference_only
```

وبالتالي لا يوجد تغيير مطلوب في هذا الملف في هذه الجولة. fileciteturn1331file0L2-L10

## 11. Report216 وCURRENT_STATE

المسار الذي طُلب فتحه لـ`Report216` وكذلك `CURRENT_STATE.md` لم يُحلّا في `erp-frontend` الحالي بواسطة GitHub Contents API؛ لذلك لم أعتبرهما Current Truth ولم أبنِ قرارًا عليهما.

تم بدلًا من ذلك الرجوع إلى:

- current Git commits
- parent commit
- current source extract
- current Production PostgreSQL
- current Production routine privileges
- current DB function definitions
- deployment evidence الموجودة في Supabase

وهذا متوافق مع مبدأ عدم الثقة في التقرير عند اختلافه مع Primary Source.

## 12. Verification Matrix

| Check | Result |
|---|---|
| Latest relevant Git commit checked | PASS |
| Parent commit checked | PASS |
| Current Mother source identified | PASS |
| Namespace regression identified | PASS |
| Gold alias drift identified | PASS |
| Production `get_budget_vs_actual` exists | PASS |
| Production 403 privilege root cause proven | PASS |
| Production grant fixed | PASS |
| Authenticated-context DB test | PASS |
| `forensic_main_assembly.yml` source-of-truth path | PASS |
| Mother `main.html` modified by assistant | NO — intentionally not modified |
| Real browser click E2E executed by assistant | NOT AVAILABLE |

## 13. What is proven / what is not proven

### Proven

- سبب `_renderPeriods` هو dispatcher namespace regression.
- سبب `_goldOpenPeriod`, `_goldAddAsset`, `_goldTaxCode` هو alias/export drift.
- سبب 403 هو غياب EXECUTE لـ`authenticated` على `get_budget_vs_actual`.
- Production database fix تم تطبيقه والتحقق منه.
- `forensic_main_assembly.yml` بالفعل يحدد Mother main كـSource of Truth.

### Not yet proven

- نجاح النقر الفعلي داخل متصفح بعد أن يطبق المالك CHANGE A وCHANGE B.
- نجاح جميع modal journeys بصريًا لأن المساعد لا يملك browser session لهذا المستودع.

## 14. Final Self-Audit

### What I Proved

أثبتت مواضع الخطأ من current source/commit/Production وليس من التقرير.

### What I Fixed

تم إصلاح Production privilege الخاص بـ`get_budget_vs_actual`.

### What I Did Not Modify

لم أعدل `main.html` احترامًا للفصل بين مسؤولية Production ومسؤولية مالك النظام الأم.

### What I Initially Considered and Rejected

إعادة بناء Finance renderer بالكامل، إضافة aliases عشوائية لكل renderer، أو إنشاء جداول بديلة؛ وكلها رُفضت لأن الـPrimary Evidence أثبت أن المشكلة أضيق ويمكن حلها جراحيًا.

### What Could Still Be Wrong

إذا كان هناك inline onclick غير موجود ضمن aliases التي تم استخراجها من Gold Extension فقد يحتاج alias إضافيًا؛ لكنه لا يُفترض قبل إثبات وجود المستهلك في current source.

### Final Closure Status

**Production budget-report privilege closure: CLOSED.**

**Mother source closure: OWNER ACTION REQUIRED — CHANGE A + CHANGE B + modal upgrades.**

لا يجوز إعلان Finance E2E = 100% Closed قبل إعادة تحميل `main.html` بعد دمج المالك للتعديلات وتشغيل clicks الفعلية والتحقق من Console.

## 15. تعليمات للمساعد القادم — كيف يبدأ التحقيق الجنائي

1. افتح `CURRENT_STATE.md` إن وُجد، لكن صنّف كل بند قبل استخدامه.
2. افتح آخر commit لـ`erp-frontend` ثم افتح parent commit مباشرة.
3. افتح current `companies/company-1/main.html`، وليس `Current/PWA/main2`، لأن الأخير تاريخي فقط.
4. حدّد consumer من الـonclick أو dispatcher أولًا، ثم trace إلى exported function، ثم إلى RPC.
5. عند ظهور `is not a function` ابحث ثلاث نقاط منفصلة: function declaration، return object، public namespace binding.
6. عند ظهور HTTP 403 لا تعدّل SQL business logic قبل فحص `routine_privileges`.
7. عند ظهور أي finance modal failure افحص RPC signature في Production قبل تعديل frontend arguments.
8. لا تنشئ table أو Edge Function جديدة إلا إذا أثبت الـcurrent schema أن capability المطلوبة غير موجودة أصلًا.
9. بعد كل Production DDL: query verification + runtime-context verification.
10. بعد كل owner source change: لا تعتبر المهمة مغلقة إلا بعد browser reload، فتح التبويب، الضغط على الزر، ثم zero new Console errors.
11. لا تعد إصلاح نقطة مثبت إغلاقها بالفعل ما لم يظهر regression جديد بدليل current source/current runtime.
