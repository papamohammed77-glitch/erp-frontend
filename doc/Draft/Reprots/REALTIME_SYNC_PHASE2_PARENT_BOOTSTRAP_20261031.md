# تقرير المرحلة الثانية — تتبع النظام الأم ومسارات Realtime
**التاريخ:** 2026-10-31  
**المستودع:** `papamohammed77-glitch/erp-frontend`  
**الفرع:** `main`  
**مرجع Git tree عند الفحص:** `ad45e5dfd9bde80dd246c9f9a622ddf8a7568845`  
**حالة المرحلة:** PARTIAL — تم إغلاق عائق قراءة النظام الأم واكتمل تتبع مصدره، لكن مصفوفة freshness والاختبارات التشغيلية لم تُغلق.  
**حالة المهمة الكلية:** OPEN.

## 1. نطاق العمل ومعيار الإغلاق
تم استكمال الوصول إلى المصدر الكامل للنظام الأم، تتبع boot/auth/company context، وفحص قنوات Realtime المباشرة، ثم إعادة جرد جميع صفحات HTML الحالية تحت `companies/company-1/` ومطابقة الجداول المشتركة في القنوات مع إعدادات Production Supabase.

لا تُعد هذه المرحلة مكتملة بالكامل حتى يتم:
- تصنيف كل شاشة حسب مسار freshness الفعلي، وليس مجرد وجود كلمات `setInterval` أو `refresh`.
- إثبات event delivery تحت JWT حقيقي.
- إغلاق فجوات RLS والاشتراكات غير المتوافقة.
- إجراء اختبارات شركتين مستقلتين. الاختبارات الأخيرة غير ممكنة حاليًا بسبب عدم ظهور أكثر من شركة واحدة لها مستخدمون نشطون في استعلام Production.

## 2. حل عائق قراءة main.html
تم استخراج Git blob مباشرة بعد فشل قراءة الملف عبر واجهة المحتوى العادية:
- المسار: `companies/company-1/main.html`
- Blob SHA: `53b5a9e9d0433a785c3d5471a9c0d68c25497882`
- الحجم المسجل في Git tree: 1,892,593 bytes
- عدد الأسطر: 33,358
- النتيجة: المصدر الكامل أصبح متاحًا للفحص؛ فشل القراءة السابق كان حدًا في أداة الاسترجاع، وليس خللًا في الملف.

## 3. بنية النظام الأم المثبتة من المصدر
- `main.html` ينشئ Supabase client داخليًا في الأسطر 148–178.
- لا يحمل `companies/company-1/core.js` ولا يستدعي `RW_Realtime.start`.
- مسار تسجيل الدخول في `main.html` يبدأ من `RW_Auth.login`، ويسترجع سجل `users` بواسطة `auth_id = auth.uid()`، ثم يأخذ `company_id` والصلاحيات من سجل قاعدة البيانات قبل تشغيل النظام (تقريبًا الأسطر 1241–1311).
- `RW_STATE.app.company.id` يصبح سياق الشركة الذي تستخدمه وحدات النظام الأم.
- لذلك فالنظام الأم حاليًا تطبيق monolith مستقل بمحرك Supabase داخلي وقنوات Realtime مباشرة، وليس مستهلكًا لمحرك `RW_Realtime` المشترك.

### مسار التوجيه
`app.html` يسجل الدخول ثم يوجه المستخدم إلى `main.html` أو تطبيق مستقل بحسب owner/warehouse role/permissions. هذا يثبت مسار التوجيه فقط؛ ولا يثبت صلاحية الوصول إلى البيانات. التحقق النهائي يظل في مصادقة التطبيق وسياسات RLS وقواعد RPC.

## 4. جرد قنوات النظام الأم الثماني
المصدر: blob أعلاه. هذه قنوات موجودة في `main.html` وليست استدعاءات للمحرك المشترك.

| الموضع | الوحدة | الجداول | الملاحظة المثبتة |
|---:|---|---|---|
| 3488 | Sales Decision | `sales_decision_policies`, `sales_decision_evaluations`, `sales_decision_approvals` | لا توجد الجداول الثلاثة في `supabase_realtime`، وسياسات RLS تمنع الوصول المباشر لـanon/authenticated. الاشتراك غير متوافق مع الإعداد الحالي. |
| 3839 | Sales Targets | `sales_target_plans`, `sales_target_assignments`, `sales_target_runs`, `sales_target_run_lines` | الجداول منشورة وسياسات SELECT تربط كل سجل بشركة المستخدم. القناة لا تضيف company filter صريحًا؛ تعتمد على RLS. |
| 4408 | Loyalty | `loyalty_programs`, `loyalty_rewards`, `loyalty_accounts`, `loyalty_transactions` | الجداول الأربعة غير منشورة وسياساتها تمنع direct access للمستخدمين. الاشتراك غير متوافق مع الإعداد الحالي. |
| 12381–12450 | Purchasing Gold | `purchase_requests`, `purchase_rfqs`, `purchase_quotations`, `purchase_invoices`, `purchase_returns`, `purchase_payments` | الجداول منشورة، RLS مفعّل، وسياسات الشركة موجودة؛ القناة تستخدم company filter في كل جدول. |
| 18271 | Inventory Control | `stock_branches`, `inventory_log`, `inventory_counts`, `inventory_stock_requests` | ثلاثة جداول لها نطاق شركة/فرع في السياسات؛ `inventory_counts` بها سياسة واسعة بلا tenant predicate — تفصيلها في القسم 7. |
| 20360 | Customer Payments | `sales_payment_receipts`, `sales_payment_allocations` | الجداول منشورة لكن السياسات المعروضة مخصصة لـservice_role فقط؛ القناة تعمل من عميل authenticated، وبالتالي لا يوجد دليل على أن المستخدمين العاديين يستطيعون تلقي أحداثها. |
| 21400 | Commission | `commission_plans`, `commission_assignments`, `commission_runs`, `commission_run_lines` | الجداول منشورة لكن سياسات الجداول الأربعة service_role فقط؛ القناة من عميل المستخدم لا تتوافق مع سياسة الوصول الحالية. |
| 31425 | HR | 24 جدولًا: employee_profiles, employee_attendance, employee_leave_requests, employee_documents, hr_departments, hr_positions, hr_employee_assignments, hr_employee_schedule_assignments, hr_work_schedules, hr_attendance_events, hr_work_entries, hr_leave_types, hr_leave_balances, hr_requests, hr_request_approvals, hr_salary_advances, hr_salary_components, hr_contracts, hr_contract_components, hr_payroll_periods, hr_payroll_runs, hr_payslips, hr_payslip_lines, hr_payroll_accounting_map | الجداول الـ24 منشورة وRLS مفعّل وسياسات SELECT موجودة؛ القناة لا تضيف company filter وتترك العزل لسياسات RLS. يلزم JWT runtime test. |

**تفسير مهم:** عدم وجود company filter في قناة لا يثبت وحده تسربًا إذا كانت RLS سليمة؛ لكنه يجعل صحة القناة معتمدة بالكامل على السياسات. وفي المقابل، وجود company filter في العميل ليس بديلًا عن RLS.

## 5. القنوات المباشرة خارج النظام الأم
### Sales Manager
- الملف: `companies/company-1/sales/manager.html`
- Blob SHA: `adbf6b72bb5e0ada488097f9615965be5f0806b8`
- الموضع: الأسطر 150–151.
- يستمع إلى جداول أهداف المبيعات الأربعة دون company filter صريح.
- Production يؤكد أن الجداول منشورة وسياسات SELECT تربط `company_id` بسجل المستخدم النشط. العزل يعتمد على RLS؛ اختبار Realtime تحت JWT ما زال مطلوبًا.

### Warehouse Vouchers
- الملف: `companies/company-1/warehouse/vouchers.html`
- Blob SHA: `85e709d0f41c189c6624a6160965d3b1a41960ba`
- الموضع: السطر 274.
- `stock_vouchers` عليها company filter.
- `stock_voucher_details` بلا company filter في الاشتراك، لكن سياسة SELECT تربط التفاصيل بـ`stock_vouchers` التابعة لشركة المستخدم.
- `stock_branches` عليها branch filter، وسياسات RLS تربط الفرع بشركة المستخدم ونطاق الفروع المسموح.
- لم يتم تعديل هذه القناة؛ يلزم إثبات runtime تحت JWT أولًا.

## 6. تصحيح جرد صفحات HTML
إعادة استخراج Git tree الحالي أظهرت **30 ملف HTML** تحت `companies/company-1/`، وليس 29 كما ورد في سجل المرحلة الأولى. سبب الفرق أن `companies/company-1/index.html` — صفحة اختيار وجهة الدخول إلى `app.html` أو `main.html` — لم تدخل في العد السابق. هذا تصحيح موثق، وليس تغييرًا في ملفات النظام.

من أصل 30:
- 6 ملفات تستدعي `RW_Realtime.start` صراحةً: Purchasing Buyer, Purchasing Supervisor, Warehouse Loader, Warehouse Manager, Warehouse Receiver, Warehouse Supervisor.
- 24 ملفًا لا تستدعي `RW_Realtime.start` صراحةً في مصدرها.
- وجود آليات مباشرة أخرى مثبت في: `main.html` (8 قنوات)، `sales/manager.html` (قناتان)، `warehouse/vouchers.html` (قناتان).
- وُجدت مؤشرات timer/focus/visibility في صفحات منها: delivery/driver, office/accountant, sales/order-taker, sales/pos, sales/telesales, warehouse/loader, warehouse/picker, warehouse/returns, warehouse/vouchers. هذه مؤشرات مصدرية؛ لم تُصنف كل واحدة بعد إلى polling بيانات فعلي أو مؤقت واجهة.
- `warehouse/counter.html` لا يحتوي اشتراكًا صريحًا، لكنه يقرأ سجل الجرد مباشرة.
- الصفحات التي لم يظهر فيها أي من مؤشرات البحث لا تُصنف تلقائيًا read-only؛ تبقى UNKNOWN حتى فحص مسار التحميل والتحديث الفعلي.

## 7. اكتشاف أمني حرج — inventory_counts
تم فحص Production مباشرة:

### تعريف السياسة والصلاحيات
- الجدول: `public.inventory_counts`
- RLS: enabled
- السياسة الوحيدة: `allow_all_inventory_counts`
- الدور: `public`
- الأمر: `ALL`
- `USING`: `auth.role() = 'authenticated'`
- لا يوجد tenant predicate في السياسة رغم أن الجدول يحتوي `company_id`.
- `authenticated` لديه SELECT/INSERT/UPDATE/DELETE grants على الجدول.
- الجدول لا يحتوي حاليًا أي صفوف عند فحص العدد الكلي: 0؛ لذلك لم يُرصد تسرب بيانات فعلي في لحظة الفحص، لكن السياسة تسمح بنطاق وصول غير معزول عند وجود بيانات.

### مستهلكات المصدر
- `main.html` يقرأ `inventory_counts` في السطر 17437 مع client-side `.eq('company_id', companyId)`. هذا الفلتر قابل للإزالة من العميل ولا يعوض RLS.
- `main.html` يشترك في أحداث `inventory_counts` في السطر 18274 دون company filter.
- `warehouse/counter.html` يقرأ آخر 30 سجلًا في السطر 137 دون أي company filter.
- الكتابة في النظام الأم تمر عبر RPC `inventory_control`؛ الدالة SECURITY DEFINER وتتحقق من `auth.uid()`، المستخدم النشط، الشركة، وصلاحية العملية. صلاحية authenticated على الدالة موجودة.
- الدالة الداخلية `inventory_count_engine` لا يملك authenticated صلاحية EXECUTE عليها مباشرة وفق فحص `has_function_privilege`.

### الاستنتاج
**CONFIRMED — فجوة عزل tenant في RLS للجدول، ومستهلك counter لديه استعلام غير مقيد بالشركة.**  
**UNVERIFIED — لم يُثبت تسرب صفوف بين شركتين في runtime؛ Production لم يُظهر صفوفًا في الجدول، كما أن استعلام المستخدمين النشطين أظهر شركة واحدة فقط.**

هذه أولوية P0 قبل توسيع Realtime. لا يتم تغيير السياسة أو الصلاحيات عشوائيًا: يجب أولًا تثبيت أدوار الجرد التي يحق لها قراءة السجل، والتأكد من عقد Edge Function `save-inventory-count`، ثم إعداد سياسة SELECT مقيدة بالشركة/الدور وإزالة أي direct write لا يحتاجه التطبيق. يجب أن تظل عمليات الإنشاء والتعديل والاعتماد عبر المسار المعتمد ذي التحقق والتدقيق وidempotency.

## 8. توافق RLS مع قنوات النظام الأم — ملخص Production
- Sales Decision: 3 جداول غير منشورة، RLS يمنع direct access.
- Loyalty: 4 جداول غير منشورة، RLS يمنع direct access.
- Customer Payments: جدولان منشوران، سياساتهما service_role فقط.
- Commission: 4 جداول منشورة، سياساتها service_role فقط.
- Sales Targets: 4 جداول منشورة، RLS company-scoped.
- Purchasing Gold: 6 جداول منشورة، RLS company-scoped.
- HR: 24 جدولًا منشورًا، RLS مفعّل وسياسات قراءة موجودة.
- Inventory Control: `inventory_counts` هي الاستثناء الحرج؛ بقية الجداول لها نطاق شركة/فرع في السياسات التي فُحصت.

لا تعني هذه النتائج أن القنوات وصلت فعليًا إلى المتصفح؛ لم يتم تنفيذ authenticated browser event test في هذه المرحلة.

## 9. عائق اختبارات الشركتين
- استعلام Production عن المستخدمين النشطين ذوي `auth_id` أعاد مستخدمين تابعين لشركة واحدة فقط.
- جدول `inventory_counts` كان فارغًا وقت الفحص.
- لذلك لا يمكن إعلان نجاح cross-company isolation أو اختبار تسرب Realtime بين شركتين حقيقيتين.
- لا ننشئ مستخدمين أو بيانات اختبار في Production دون خطة اختبار معتمدة ومسار تنظيف مثبت.

## 10. Security Advisor snapshot
أعاد Supabase Security Advisor عند `2026-10-31T17:12:40.056Z`:
- 24 جدولًا RLS enabled بلا policies.
- 3 views مصنفة SECURITY DEFINER.
- 20 SECURITY DEFINER functions متاحة لـanon.
- 121 SECURITY DEFINER functions متاحة لـauthenticated.
- تحذير leaked-password protection disabled.
هذه نتائج أمنية مستقلة تحتاج فرزًا حسب قابلية الوصول والاستخدام؛ لا تعني تلقائيًا أن كل عنصر منها قابل للاستغلال، ولا تُعالج جماعيًا ضمن مهمة Realtime دون مراجعة العقود.

## 11. ما لم يتغير
- لم يُعدّل أي ملف تطبيق.
- لم تتغير أي سياسة أو بيانات أو schema في Supabase.
- لم يتم نشر أي تعديل على Cloudflare.
- لم يُثبت CI أو browser E2E.
- لا يوجد ادعاء بأن المزامنة الكاملة تحققت.

## 12. قرار المرحلة والخطوات التنفيذية التالية
**Phase 2 — Parent source/bootstrap trace: COMPLETE.**  
**Phase 2 — Full freshness classification and runtime proof: PARTIAL / OPEN.**  
**Overall Realtime mission: OPEN.**

الأولوية التالية:
1. مراجعة عقد Edge Function `save-inventory-count` ودور `warehouse/counter.html`، ثم إعداد إصلاح tenant-safe لـ`inventory_counts` (RLS + استعلام counter) دون المساس بمسار RPC.
2. فحص صلاحيات/عقود Sales Decision وLoyalty وCustomer Payments وCommission لتحديد هل تُستبدل هذه الاشتراكات بمسار تحديث مصرح أم تُلغى؛ لا نضيف الجداول إلى publication لمجرد جعل الاشتراك يعمل.
3. استكمال مصفوفة freshness لكل صفحة من الـ30، والتحقق من دلالة كل timer/focus handler.
4. تنفيذ اختبار Realtime وRLS بهويات شركتين في بيئة اختبار معزولة.
5. بعد اجتياز الاختبارات، الانتقال إلى تكاملات التطبيقات ثم مطابقة Cloudflare والـE2E.

**قاعدة السلامة:** لا تُعدّل سياسة Production أو توسع publication أو تضف اشتراكًا قبل إثبات صلاحية الدور، نطاق الشركة، الجداول المطلوبة، ومصدر refresh البديل.
