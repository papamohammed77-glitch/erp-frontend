# CountFlow — نظام الجرد المستقل

> **النطاق:** منظومة CountFlow مستقلة عن RAWAEA ERP وعن قاعدة SMART ERP، وتتكون من:
> 1. النظام الأم لإدارة المنظومة والبيانات المرجعية والمستخدمين.
> 2. تطبيق مندوب الجرد الميداني.
> 3. لوحة مراقب/مشرف الجرد ومتابعة التنفيذ.
>
> قاعدة البيانات المستخدمة هي مشروع Supabase المستقل `rawaea-staging` (`hfzznsiprnwkpayskzhu`). جميع بيانات التشغيل الجديدة محصورة في جداول `count_*` ومخازن `counting-*`. لا تنفذ التطبيقات أي ترحيل للمخزون أو النقدية أو الحسابات أو قيود ERP.

## التطبيقات

- [countflow-admin.html — النظام الأم وإدارة CountFlow](./countflow-admin.html)
- [countflow.html — تطبيق مندوب الجرد](./countflow.html)
- [Countflow-supervisor.html — لوحة مراقب الجرد](./Countflow-supervisor.html)
- [counting-provision-member — Edge Function لإنشاء الأعضاء وإعادة تعيين كلمات المرور](./functions/counting-provision-member/index.ts)
- [counting-export-session — Edge Function للتصدير الخادمي الكبير](./functions/counting-export-session/index.ts)
- [DEPLOYMENT.md — نشر CountFlow على Cloudflare Pages مستقلاً](./DEPLOYMENT.md)

## ما يقدمه النظام حالياً

### مندوب الجرد
- تسجيل دخول Supabase Auth وربط العضوية بالمشروع.
- دعم العضوية في أكثر من مشروع مع إمكانية التبديل بينها.
- مسح باركود الموقع لتحديد الموقع النشط، ثم مسح الصنف بالكاميرا أو قارئ خارجي أو إدخال الكود يدوياً؛ إعادة مسح الصنف نفسه تزيد الكمية تلقائياً، ويُحفظ الصنف قبل الانتقال إلى صنف آخر. كشف الكاميرا محدود إلى 5 مرات في الثانية لتقليل استهلاك الهاتف.
- عرض بيانات الصنف وصورته ووحداته، مع التحقق من أن الوحدة والموقع تابعان للمشروع ومسموح بهما.
- تسجيل الكميات مع الوقت والعضو والجهاز ومعرّف عملية فريد.
- طابور Offline باستخدام IndexedDB ومزامنة idempotent عند عودة الاتصال.
- تسجيل حضور الجهاز وحالته؛ أول جهاز للعضو يُفعّل تلقائياً، وأي جهاز إضافي ينتظر موافقة المشرف، والجهاز المبطل لا يستطيع تسجيل عمليات جديدة.
- إرفاق صورة دليل العد بالعملية عند توفر الاتصال.
- تنفيذ مهام إعادة العد المسندة للمندوب دون كشف كمية العد السابقة.

### لوحة المشرف
- إنشاء مشروع الجرد الأول وتهيئة عضوية مالكه تلقائياً.
- إنشاء حسابات المندوبين والمراجعين والمشرفين الإضافيين عبر Edge Function موثقة ومحمية بـJWT.
- إعادة تعيين كلمة مرور العضو من داخل اللوحة.
- إيقاف العضوية واستئنافها، وإدارة الأجهزة وإبطالها أو إعادة تفعيلها.
- إدارة المواقع الهرمية والتعيينات على مستوى الموقع أو كامل المواقع، مع خريطة تغطية هرمية تعتمد RPC الخادم لإظهار المسار والمواضع المعدودة ونسبة التغطية.
- استيراد الأصناف من CSV وExcel، مع معاينة وربط أعمدة قابل للحفظ وإعادة الاستخدام.
- حفظ الدفعة والصفوف الخام ونتائج قبول/رفض كل صف وأسباب الرفض.
- ربط الكميات الدفترية بجلسة وموقع؛ الكتالوج وحده لا ينشئ رصيداً دفترّياً.
- مراقبة العمليات والحضور والأجهزة والأدلة والتنبيهات عبر private Broadcast مع تحديث احتياطي دوري؛ وصول الأحداث وزمن التأخير عبر أجهزة متعددة لم يثبتا بعد.
- قواعد تنبيه قابلة للضبط للكمية غير المعتادة، وتكرار المسح، ونسب فروقات الجرد.
- تسوية مرجعية، ومهام إعادة عد، ومراجعة نتائج إعادة العد، ثم اعتماد التسوية.
- تصدير CSV وExcel متعدد الأوراق، وحفظ الملفات في مخزن خاص مع سجل وبصمة SHA-256.

## بنية Supabase

### الجداول

جميع الجداول التالية ضمن `public` ومفعّل عليها RLS:

| المجموعة | الجداول |
|---|---|
| المشروع والهوية | `count_projects`, `count_members`, `count_devices` |
| الجلسات والمواقع | `count_sessions`, `count_locations`, `count_assignments` |
| الكتالوج والاستيراد | `count_products`, `count_import_mappings`, `count_import_batches`, `count_import_rows`, `count_expected_balances` |
| عمليات العد | `count_entries`, `count_entry_images`, `count_presence` |
| الرقابة والتسوية | `count_anomaly_rules`, `count_alerts`, `count_reconciliation_runs`, `count_reconciliation_lines`, `count_recount_tasks` |
| التدقيق والتصدير | `count_audit_log`, `count_exports` |

- سجل `count_entries` append-only؛ لا تمنح واجهة العميل تحديث أو حذف عمليات العد.
- كل المفاتيح الخارجية لجداول CountFlow لها فهارس تغطية.
- تعيينات المواقع لا تُكشف بين المندوبين؛ المشرف يرى جميع التعيينات، والمندوب يرى تعييناته فقط.
- دوال التحقق الحساسة موجودة في `counting_private` مع `search_path` فارغ وصلاحيات تنفيذ محددة.
- `count_record_entry` يتحقق من العضوية والجلسة والصنف والموقع والوحدة والجهاز والتعيين، ويمنع إعادة استخدام مفتاح idempotency بحمولة مختلفة.
- كل عملية عد تحفظ `unit_factor_to_base` وقت الإدخال، وتولد `base_quantity`؛ تغيير تحويلات وحدات الصنف ممنوع أثناء وجود عدود في جلسة نشطة أو موقوفة أو قيد المراجعة.
- الوحدة الأساسية معاملها 1. الوحدة البديلة لا تُقبل إلا إذا كان لها معامل موجب `factor_to_base`؛ التسوية ومؤشرات الكميات تستخدم الكمية الأساسية المحفوظة لا الكمية المدخلة الخام.
- دالة `counting_private.session_effective_counts` هي المصدر الموحد للكمية النهائية: العد الأول أساس، وآخر إعادة عد معتمدة من المشرف تستبدله ولا تُجمع فوقه.
- قواعد الشذوذ الفعالة تولّد تنبيهات الكمية وتكرار العد من Trigger بعد كل عملية، وتُقيّم فروقات التسوية تلقائياً عند إنشاء التسوية؛ تنبيهات `count_alerts` تُبث عبر Broadcast.
- `count_record_recount_entry` يتحقق من إسناد المهمة والجهاز والوحدة، ويسجل جولة جديدة مرتبطة بالعد السابق.

### Realtime

تستخدم الواجهات قنوات Supabase Broadcast خاصة:
- `countflow:project:<project_id>` للمشرف.
- `countflow:session:<session_id>` للمشرف فقط، وتصل إليها عمليات العد والتنبيهات والحضور والتسوية.
- `countflow:member:<member_id>` للعضو نفسه، وتصل إليها تغييرات عضويته وجلساته وتعييناته وأجهزته ومهام إعادة العد.

تُفحص صلاحية الانضمام عبر RLS على `realtime.messages`. لا تُرسل عمليات العد إلى قناة المندوب، لتجنب كشف عدّ المندوبين الآخرين.

### Storage

كل الحاويات خاصة (Private):
- `counting-product-images`: صور الأصناف.
- `counting-evidence`: أدلة صور عمليات العد.
- `counting-exports`: ملفات CSV وXLSX المؤرشفة.

الروابط الموقعة قصيرة العمر؛ لا تحفظ الواجهات روابط عامة لملفات خاصة.

## الإعداد الأول

1. من Supabase Dashboard → Authentication → Users، أنشئ حساب المشرف الأول ببريد حقيقي وكلمة مرور يملكها مسؤول المشروع.
2. بعد إنشاء هوية مالك CountFlow المؤكدة في Supabase Auth (البريد المعتمد `owner@rawaea.com`)، سجّل الدخول إلى النظام الأم أو تطبيق المشرف. أنشئ تكليفاً جديداً بإدخال اسم الجهة واسم أول عملية ورقم التكليف؛ ينفّذ `count_create_engagement` إنشاء ملف التكليف وأول عملية ذرياً.
3. أنشئ حسابات المندوبين والمراجعين من تبويب الفريق. الحسابات تُنشأ وتُؤكد عبر Edge Function؛ استخدم كلمات مرور مؤقتة آمنة ثم سلّمها للمستخدمين عبر قناة آمنة.
4. أنشئ المواقع والأرفف أو استوردها.
5. استورد الأصناف واربط الأعمدة. إذا احتوى الملف على كميات دفترية، اختر جلسة الجرد وموقع كل رصيد.
6. أنشئ جلسة، ثم عيّن المندوبين إلى المواقع أو امنح عضواً نطاق جميع المواقع.
7. يدخل المندوب من countflow.html؛ يسجل الجهاز أول حضور عند الاتصال، ولا يسمح الخادم بالتسجيل من جهاز غير مسجل أو في انتظار الاعتماد أو مبطل.
8. بعد اكتمال العد، احتسب التسوية، وأنشئ مهام إعادة العد للفروقات، وراجع نتائجها والتنبيهات الحرجة قبل اعتماد التسوية. إعادة العد المعتمدة تستبدل كمية الجولة الأولى في التسوية اللاحقة، ولا تُجمع معها.
9. صدّر CSV أو مصنف Excel متعدد الأوراق من تبويب التقارير.

## صيغ الاستيراد

### الأصناف

الأعمدة القياسية المقترحة:

`sku, barcode, name, category, base_unit, units, expected_qty, location_code, image_url`

- `sku` و`name` إلزاميان.
- `units` مصفوفة JSON. الوحدة البديلة يجب أن تحتوي `name` و`factor_to_base` موجباً نسبةً إلى الوحدة الأساسية؛ مثال: `[{"name":"كرتونة","factor_to_base":12}]`.
- يمكن استيراد قائمة نصية مفصولة بعلامة `|` للتوثيق، لكنها لا تصبح وحدة قابلة للعد حتى يُعرّف معامل تحويل موجب. الوحدة الأساسية متاحة دائماً.
- `expected_qty` يحتاج جلسة محددة ويجب أن يكون دائماً بوحدة `base_unit` للصنف؛ يمنع النظام تغيير الرصيد الدفتري بعد أول عملية عد أو بعد إنشاء أول تسوية.
- `location_code` يربط الرصيد بموقع داخل المشروع.
- `image_url` يقبل HTTPS أو مساراً داخلياً، ولا يقبل HTTP أو مراجع غير آمنة.
- يمكن حفظ تخطيط الأعمدة لكل مشروع وصيغة، وتُحفظ الصفوف المصدرية الخام مع كل دفعة.

### المواقع

`code, name, location_type, parent_code, sort_order`

يدعم الهيكل الهرمي عبر `parent_code`.

## حدود العزل الفعلية في Supabase

تطبيقات CountFlow وعملياتها تستخدم جداول `count_*` فقط، ولا تستدعي جداول المخزون أو المبيعات أو الحسابات في ERP. لكن فحص المشروع الحي أثبت أن مشروع Supabase نفسه ما زال يحتوي على 70 جدولاً عاماً خارج نطاق CountFlow و24 Edge Functions قديمة، إضافة إلى 1,868 هوية Auth قديمة لا توجد لها عضويات CountFlow. لذلك العزل الحالي **عزل تطبيق/بيانات منطقي** وليس مشروع Supabase منفصلاً مادياً. لم تُحذف أو تُعدّل هذه الكيانات القديمة لأنها خارج النطاق وقد تكون مرتبطة بتطبيقات قائمة. إذا كان شرط التشغيل هو فصل مادي كامل، فيلزم مشروع Supabase مستقل تُنقل إليه جداول CountFlow وStorage وEdge Functions فقط.

- فحص الأمان العام للمشروع أعاد 65 حالة ERROR و15 WARN على الكيانات القديمة؛ لم تُسجل أي finding على جداول/دوال CountFlow. فحص الأداء أعاد تحذيراً واحداً عن فهارس مكررة في `public.erp_operation_registry`، خارج CountFlow.
- ست وظائف قديمة من أصل 24 تعمل مع `verify_jwt=false` (`cp-fixture-canary-20260814`, `start-picking-real-identity-e2e-20260815`, `complete-picking-closure-canary-20260814`, `cp-auth-canary-20260814`, `start-picking-e2e-fixture-20260815`, `task-inv-send-voucher-harness`). لم أغيّرها لأنها ليست وظائف CountFlow وقد تكون مرتبطة باختبارات/تطبيقات أخرى. وظيفتا CountFlow المنشورتان تفرضان JWT.

## المرجعية التنافسية وتجربة الاستخدام

اعتمدت مراجعة التجربة على توثيق الشركات نفسها، لا على الانطباعات التسويقية:

- **Odoo Barcode:** إسناد العد للمستخدم والموقع، مسح باركود الموقع ثم الصنف، تكرار مسح الصنف لزيادة الكمية، وإخفاء الكمية المتوقعة افتراضياً لتجنب تحيز العادّ. انعكس ذلك في تدفق المسح المستمر، اختيار الموقع بالباركود، وزيادة كمية الصنف عند تكرار مسحه.
  - https://www.odoo.com/documentation/19.0/applications/inventory_and_mrp/barcode/operations/adjustments.html
- **Microsoft Dynamics 365:** أولوية مهام العد، قوائم أجهزة محمولة للعد الموجّه من المستخدم أو النظام والعد الموضعي، وحالة Pending review للفروقات. انعكس ذلك في إسناد المهام، إعادة العد، وحاجز اعتماد التسوية.
  - https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/cycle-counting
  - https://learn.microsoft.com/en-us/dynamics365/supply-chain/warehousing/tasks/define-cycle-counting
- **SAP EWM:** تصنيف ABC وتكرار العد بحسب أهمية الصنف، ومراقبة تقدم الجرد على مستوى الصنف والموقع. هذه مرجعية للمرحلة التالية الخاصة بجدولة Cycle Count وخريطة تغطية المستودع.
  - https://help.sap.com/docs/SAP_EXTENDED_WAREHOUSE_MANAGEMENT/25cf88dfa94c49e4a440f3f1d752b8a1/4cb4e7e04c1f1921e10000000a15822b.html
  - https://help.sap.com/docs/SAP_SUPPLY_CHAIN_MANAGEMENT/ce32eae1b3db423fb4625f3d692cae6f/4cb4ea364c1f1921e10000000a15822b.html
- **ERPNext:** Stock Reconciliation أداة لمواءمة الفعلي والدفترية وقد تنفذ أثر المخزون. CountFlow مستقل عمداً: لا يرحّل فروقات إلى مخزون أو دفتر أستاذ أو خزينة، ويصدر نتائج قابلة للمراجعة فقط.
  - https://docs.frappe.io/erpnext/stock-reconciliation

## الاختبارات والتحقق

### تم التحقق في قاعدة Supabase الحية

- 21 جدولاً من `count_*` موجودة ومفعّل عليها RLS.
- أزيلت جميع امتيازات `anon` المباشرة عن جداول CountFlow؛ وأزيلت امتيازات `TRUNCATE` و`TRIGGER` و`REFERENCES` من `authenticated`. RLS وحدها لا تحمي من TRUNCATE.
- `count_entries` بقي append-only من جهة العميل: صلاحيتا SELECT وINSERT فقط.
- اختبار تكاملي SQL محفوظ في `tests/countflow_core_integration_rollback.sql` ونُفذ بنجاح: تهيئة مالك المشروع، العضوية، الاستيراد (صفان مقبولان وصف مرفوض)، إنشاء الأرصدة الدفترية، الحضور والجهاز، العد، idempotency، منع العد خارج التعيين، التسوية، إنشاء مهام إعادة العد، إعادة العد، وإعادة التسوية.
- اختبار وحدات وتسوية محفوظ في `tests/countflow_unit_recount_rollback.sql` ونُفذ بنجاح: 2 كرتونة × 12 + 3 وحدات أساسية = 27؛ ثم إعادة عد معتمدة مقدارها 2 كرتونة = 24؛ أصبحت التسوية الثانية وKPI تساوي 24 لا 51. كما ثبت رفض وحدة بلا معامل تحويل ومنع تغيير معامل التحويل أثناء جلسة نشطة.
- اختبار تنبيهات محفوظ في `tests/countflow_anomaly_rollback.sql` ونُفذ بنجاح: تنبيه كمية، وتكرار عد، وتنبيه فرق تسوية حرج؛ ومنع اعتماد التسوية أثناء وجود التنبيه الحرج، ثم نجاح الاعتماد بعد معالجته.
- اختبار نهائية الاعتماد محفوظ في `tests/countflow_approval_finality_rollback.sql` ونُفذ بنجاح: رفض اعتماد تسوية بعد تغير بيانات العد، ورفض جولة ليست الأحدث، وتجميد الجلسة بعد الاعتماد ومنع أي إدخال لاحق.
- اختبار التعيينات محفوظ في `tests/countflow_assignment_upsert_rollback.sql` ونُفذ بنجاح: تعيين عام `location_id=NULL` وتعيين موقع محدد، مع تكرار upsert دون إنشاء صفوف مكررة.
- اختبار الأرصدة الدفترية محفوظ في `tests/countflow_expected_balance_snapshot_rollback.sql` ونُفذ بنجاح: فرض وحدة الأساس، السماح بتحديث الرصيد قبل أول عد، ومنع تغييره بعد بدء العد.
- اختبار سجل التدقيق محفوظ في `tests/countflow_admin_audit_rollback.sql` ونُفذ بنجاح: تدقيق المشروع والعضويات والجلسات والتعيينات وقواعد الشذوذ وتسجيل الجهاز، مع عدم إنشاء سجل جديد لكل heartbeat.
- الاختبارات السبعة تنفذ تحت دور `authenticated` بعد إنشاء مستخدمين مؤقتين، وتنتهي بـ`ROLLBACK`. تحققنا بعد التنفيذ من عدم بقاء حسابات أو مشاريع أو عمليات اختبار.
- Edge Function `counting-provision-member` نشطة بالإصدار 4 مع `verify_jwt=true`. تتحقق من JWT، وتسمح للمشرف النشط في التكليف أو لمالك CountFlow ذي البريد المؤكد `owner@rawaea.com` بإنشاء حسابات الأعضاء.
- Edge Function `counting-export-session` نشطة بالإصدار 7 مع `verify_jwt=true`؛ تصدر مصنف XLSX متعدد الأوراق أو CSV خادمياً، وتتحقق من عضوية المشرف النشط أو هوية المالك المؤكدة `owner@rawaea.com`، وتحفظ الملف الخاص مع SHA-256 ورابط موقّع. يُستخدم لجميع عمليات التصدير لتوحيد النتائج ومنع تحميل بناء المصنف على متصفح الهاتف. مصنف XLSX يتضمن 13 ورقة: الملخص، عمليات العد، التسوية، سجل التسويات، أداء المندوبين، تغطية المواقع، التنبيهات، إعادة العد، دفعات الاستيراد، أخطاء الاستيراد التفصيلية، أدلة الصور بروابط مؤقتة، الأجهزة والحضور، وسجل التدقيق. وCSV يصدّر تفاصيل العمليات.
- ملفات ترحيلات الإصلاحات الأخيرة محفوظة في `database/migrations/`، وتشمل تأمين الامتيازات، وتثبيت تحويلات الوحدات، والتنبيهات الآلية، وتجميد الجلسة ولقطة عدد العمليات عند الاعتماد.

### لم يُختبر بعد — لا تعتبره معتمداً للإنتاج واسع النطاق

- أُضيفت حزمة Playwright غير مدمرة في `tests/e2e/` لاختبار دخول المشرف والمندوب ومسح الموقع وتكرار الصنف دون حفظ؛ لكنها لم تُشغّل لعدم وجود حسابات CountFlow دائمة أو عنوان نشر مؤكد. كما لم يُنفذ تصدير XLSX/CSV خادمي من جلسة مستخدم فعلية رغم نشر الوظيفة والتحقق من JWT ومطابقة المصدر.
- اختبار استيراد 90,000 صنف محفوظ في tests/import_90k_rollback.sql أُعيد تشغيله في 19 نوفمبر داخل BEGIN/ROLLBACK ونجح: 90,000 صف staged/accepted و90,000 صنف داخل المعاملة، دون أي بيانات باقية. لم يُختبر تصدير 90,000 سجل أو قياس حمل بمئات المستخدمين؛ حدود التصدير الخادمي 150 ألف صف لكل مجموعة و250 ألف صف مجمع ما زالت غير مختبرة.
- لم يُختبر Broadcast end-to-end عبر اتصالات WebSocket متزامنة تحت الحمل.
- لم تُختبر كاميرات أجهزة Android فعلية متعددة أو قارئات باركود مختلفة.
- لم تُختبر رحلة Offline حقيقية تتضمن إغلاق المتصفح وإعادة فتحه واستعادة الطابور.
- لم يُختبر رفع وتنزيل صور الأدلة والملفات الموقعة من جلسات مستخدمين فعلية.
- لم يُنشأ بعد حساب مشرف بشري أو حسابات أعضاء حقيقية؛ لا توجد قائمة بريد/أسماء مستخدمين مؤكدة. لا يجوز إسناد أدوار إلى 1,868 مستخدماً قديماً في Auth أو إنشاء حسابات بأسماء وهمية.
- فحص JavaScript النحوي للـ inline scripts في التطبيقين نجح عبر parser/compile check، مع عدم وجود معرّفات DOM مفقودة أو مكررة في المراجعة الساكنة؛ لكنه لا يغني عن اختبار المتصفح الفعلي.


### تحقق إضافي منفذ في 19 نوفمبر 2026

- أُضيف الترحيل الحي `database/migrations/20261119195303_countflow_rpc_and_immutable_ledger_acl_hardening_v1.sql`: سحب تنفيذ RPC الخاصة بـCountFlow من `anon` و`PUBLIC`، وإعادة منح التنفيذ لـ`authenticated` فقط على الدوال التشغيلية غير المشغلة؛ كما أُزيلت امتيازات UPDATE/DELETE/TRUNCATE على سجل التدقيق ولقطات التسوية وسجل العد append-only.
- أُضيف الاختبار القابل لإعادة التشغيل `tests/rollback-smoke.sql` ونُفذ على قاعدة `rawaea-staging` بنجاح. شمل تهيئة مالك المشروع، إنشاء مندوب، نطاق التعيين، رفض موقع غير مسند، idempotency، العد الأول، التسوية، إعادة العد، مراجعتها، واعتماد التسوية وتجميدها، والتحقق من منع anon RPC ومنع تعديل السجلات غير القابلة للتعديل.
- نتيجة الاختبار: `PASS`. أُنشئت بيانات الاختبار ومستخدمو Auth الاصطناعيون داخل معاملة واحدة وانتهت بـ`ROLLBACK`. تحققنا بعدها من بقاء مشاريع CountFlow وأعضائه وأصنافه ومواقعه وجلساته وعملياته وسجل تدقيقه عند صفر، وبقاء عدد مستخدمي Auth كما كان (1,868).
- حالة Edge Functions بعد تحديث صلاحية المالك: `counting-provision-member` الإصدار 4 و`counting-export-session` الإصدار 7؛ كلاهما `ACTIVE` و`verify_jwt=true`. لم يُخفّف شرط JWT.
- فحص JavaScript للـ inline scripts في الملفين نجح عبر compile check، ولم تظهر معرّفات DOM ثابتة مفقودة أو مكررة.


- أُعيد تشغيل **مجموعة الاختبارات التسعة كاملة** في 19 نوفمبر 2026، وكلها PASS: الاختبارات السبعة الأصلية (التكامل الأساسي، الوحدات وإعادة العد، التنبيهات، نهائية الاعتماد، التعيينات، لقطة الرصيد الدفتري، سجل التدقيق)، بالإضافة إلى `tests/rollback-smoke.sql` لاختبار العزل وامتيازات RPC والسجل غير القابل للتعديل. جميعها تبدأ بـBEGIN وتنتهي بـROLLBACK؛ لم تُترك بيانات اختبار.
- تم تحديث سجل الترحيل في المسار المعتمد `database/migrations/` ليشمل `20261119195303_countflow_rpc_and_immutable_ledger_acl_hardening_v1.sql` المطابق للتغيير المطبق في Supabase.


- اختبار تحميل الاستيراد محفوظ في `tests/import_90k_rollback.sql` ونُفذ بنجاح: 90,000 صنف في 90 دفعة × 1,000 صف؛ 90,000 صف staged ومقبول و90,000 صنف committed داخل معاملة Rollback. أُضيف الفهرس `count_import_rows_batch_sku_lower_idx` لتسريع كشف تكرار SKU داخل الدفعة، وثبت استخدام PostgreSQL له عبر EXPLAIN Index Scan.


- تحسين تطبيق المندوب: مؤشر «عملياتي» أصبح يستعلم عن العدد الفعلي الكامل بـ`count: exact` بدلاً من عدّ آخر 40 سطراً فقط، وسجل العمليات يعرض اسم الصنف ورمزه وموقعه والكمية والتوقيت. فحص JavaScript بعد التعديل نجح.


- تحسين المزامنة دون اتصال: أصبح التطبيق يوقف إعادة محاولة العمليات التي رفضها الخادم نهائياً، ويحفظ سبب الرفض محلياً ويعرض قائمة عمليات تحتاج مراجعة مع زر إعادة المحاولة بعد التصحيح. العمليات لا تُحذف تلقائياً عند الرفض، ولا تُعاد محاولتها كل 12 ثانية بلا نهاية. هذا تحسين في معالجة أخطاء المزامنة؛ لم يُختبر بعد عبر متصفح فعلي مع فصل الشبكة وإعادتها.

## حدود العزل والسلامة

- لا توجد RPC في CountFlow ترحّل المخزون أو تنشئ قيداً محاسبياً أو حركة خزينة.
- التسوية واعتمادها مخرجات رقابية داخل CountFlow فقط؛ لا تغير أرصدة ERP.
- مشروع Supabase يحتوي أيضاً جداول ERP قديمة غير تابعة لـCountFlow. لم تُعدّل سياساتها أو بياناتها. أظهر Security Advisor تحذيرات RLS في تلك الجداول القديمة؛ يجب معالجتها في مشروعها/تطبيقها المالك بعد مراجعة عقودها، لا بتغيير عشوائي داخل مشروع CountFlow.
- جميع اختبارات التكامل نُفذت في نطاق معاملات Rollback ولم تترك بيانات تشغيلية تجريبية.


## نتائج التحقق الإضافي — 19 نوفمبر 2026

- اختبار المواقع الهرمية وخريطة التغطية في tests/countflow_location_heatmap_rollback.sql نجح داخل BEGIN/ROLLBACK: cycle guard passed، مسار WH / A-01، عمليتا عد، موضع معدود واحد، تغطية 100%، وrefresh_stable=true. بعد rollback بقيت جداول CountFlow الـ21 كلها فارغة.
- فحص قاعدة البيانات كشف أن جداول workflow الحرجة ما زالت تمنح المشرف authenticated بعض UPDATE/DELETE المباشر، بما يتجاوز بعض ضوابط RPC. التفاصيل والملفات المتأثرة في Report734.
- طابور Offline يحتاج handshake قبل اعتماد/إغلاق الجلسة؛ بعد انتقال الجلسة إلى review/completed قد تختفي العمليات المحلية من الواجهة ولا يمكن إرسالها إلى الخادم.
- التصدير التلقائي بعد إغلاق الجلسة يعتمد على متغير session عام يُعاد تعيينه قبل الاستعلام والتصدير؛ يلزم التقاط session_id قبل إعادة التحميل.
- لم يُنفذ أي تعديل DDL/ACL/RLS أو تعديل على التطبيقات التشغيلية في هذا التدقيق. جميع الفجوات أعلاه OPEN حتى اعتماد Change Set واختباره.


## 2026-11-19 — live CTO re-verification addendum

The following findings supersede any earlier wording that could be read as proof of live Broadcast delivery or complete workflow DML isolation.

### Realtime delivery is currently failing at the database send layer

- The live `realtime.messages` partitioned parent had **zero child partitions** at the time of inspection.
- PostgreSQL logs contained **1,992** `WarnSendingBroadcastMessage` warnings between `2026-11-19 19:01` and `20:26 UTC`; the logged context included `public.countflow_broadcast_changes`.
- The Supabase `realtime.send` function catches send exceptions and emits a warning, so the originating business transaction can succeed while its Broadcast message is not persisted for delivery.
- The 12 CountFlow Broadcast trigger tables are therefore not proof of event delivery. A WebSocket channel reaching `SUBSCRIBED` is also not proof that a database event arrived.
- The only periodic supervisor refresh found in the current UI is the 10-second heatmap refresh. Counter's 12-second queue sync and 30-second presence heartbeat do not refresh all supervisor views. Alerts, sessions, assignments, device changes, and evidence views have no equivalent broad polling fallback.
- Cross-user/cross-device delivery, reconnect, duplicate/out-of-order handling, and latency remain **UNVERIFIED**; the observed database send path is **FAILED** for the logged window. Do not describe CountFlow as live-synchronized until the platform partition issue is resolved and an authenticated event-delivery test passes.

### Workflow-table direct-DML boundary is broader than the previous update/delete finding

The live `authenticated` role has table-level `INSERT, UPDATE, DELETE` grants on the six workflow tables below, and the RLS policies generally check supervisor/project scope rather than enforcing a legal state transition:

- `count_sessions`: direct INSERT/UPDATE/DELETE.
- `count_reconciliation_runs`: direct INSERT/UPDATE.
- `count_recount_tasks`: direct INSERT/UPDATE/DELETE.
- `count_import_batches`: direct INSERT/UPDATE/DELETE.
- `count_import_rows`: direct INSERT/UPDATE/DELETE; no audit or state-guard trigger was present.
- `count_alerts`: direct INSERT/UPDATE; no audit or state-guard trigger was present.

This permits a supervisor-scoped client to bypass the corresponding validated RPC paths. Examples include inserting an already-approved reconciliation run, marking a recount task reviewed without the review RPC, inserting a staged import row without the staging validator, and dismissing a critical alert without a server-enforced reason. The import commit routine trusts staged row state, so the import-row boundary is especially sensitive. These are **OPEN P1** findings; no exploit or persistent DML was executed.

### Approval finality and post-approval recount are inconsistent

- `count_generate_recount_tasks` accepts a reconciliation run in either `computed` or `approved` status.
- The supervisor UI's generate-recount action does not block an approved run.
- `count_reconcile_session` rejects a new reconciliation when an approved run already exists.

A recount task can therefore be created after approval without a supported path to incorporate it into a new approved reconciliation. Treat approval as final until the owner explicitly chooses a superseding-approval model. This is **OPEN P1**.

### Offline close and export correctness

- Counter's IndexedDB queue view and sync routine are scoped to the current session. Once the supervisor changes the session to `review` or `completed`, the Counter session selector may stop selecting that session; queued events can become invisible and unsyncable.
- No server-side per-device close barrier or durable queue acknowledgement exists in the current schema. A session can be marked complete without proving that every registered device has flushed its local queue. **OPEN P1**.
- The supervisor's `setSession` path reloads sessions before exporting, while the export helper reads a mutable global `session.id`. The export can target a different session or fail after the selected session changes. **OPEN P2**.

### Provisioning audit and test status

- `counting-provision-member` remains deployed and source-matched, but its current behavior can return success with `audit_warning` after the Auth/member mutation when the audit insert fails. **OPEN P2**; do not treat a successful response as proof of a complete audit record.
- `tests/rollback-smoke.sql` was executed in this review and passed. It ended with `ROLLBACK`; all 21 CountFlow tables remained at zero rows and Auth user count remained 1,868. No committed QA data was left.
- No human CountFlow supervisor, member roster, authenticated browser E2E, real device offline journey, or deployed app origin has been verified. Do not assign roles to the 1,868 legacy Auth users.

### Migration source archive

The exact recorded SQL for all 60 `counting_*` and `countflow_*` migration-ledger rows is archived at [COUNTFLOW_APPLIED_MIGRATION_LEDGER_ARCHIVE_20261119.md](./database/COUNTFLOW_APPLIED_MIGRATION_LEDGER_ARCHIVE_20261119.md). It is an evidence archive only and must not be applied or replayed.


## إدارة تكليفات الجرد وسجل العمليات

- `count_projects` يمثل **ملف تكليف مستقل** يحمل اسم الجهة المتعاقدة ورقم التكليف الفريد؛ وليس سجلاً دائماً للعملاء. يمكن تكرار اسم كارفور أو بنده في تكليفات جديدة بأرقام مختلفة من دون دمج الكتالوج أو الفريق أو نتائج الجرد.
- `count_sessions.name` هو **اسم عملية الجرد** داخل التكليف، مثل «جرد شهر يناير 2027 - كارفور فرع المعادي». يمكن أن يحتوي التكليف على أكثر من عملية جرد خلال عمره.
- ينشئ النظام الأم أو تطبيق المشرف ملف التكليف وأول عملية عبر RPC `count_create_engagement` في معاملة واحدة؛ لذلك لا يُترك تكليف جديد بلا عملية أولى عند فشل جزء من الإنشاء.
- سجل عمليات الجرد في النظام الأم يعرض العمليات الحالية والتاريخية عبر جميع التكليفات التي يحق للمالك رؤيتها، مع البحث باسم الجهة أو العملية أو رقم التكليف، وفلاتر الحالة والتاريخ، وفرز الأعمدة وترقيم الصفحات.
- يمكن فتح أي عملية لمعاينة فريقها وملخص العدّ والتسوية ودفعات الاستيراد وملفات التصدير السابقة. المعاينة تدعم الطباعة، بينما ملف Excel الخادمي هو التصدير الكامل متعدد الأوراق.
- يمكن إضافة عضو حالي من التكليف إلى العملية أو إنشاء حساب جديد وإسناده مباشرة. إخراج المستخدم يحذف إسناد العملية الحالية فقط، ولا يحذف حساب Auth ولا عضويته في التكليف ولا عمليات العد المسجلة سابقاً.
- الاستيراد CSV/XLSX يمر عبر دفعات CountFlow المرحلية ومعاينة وفحص واعتماد الصفوف. الكميات الدفترية ترتبط بعملية الجرد المحددة ولا تنشئ حركات مخزون في ERP.
- تطبيق المشرف يوفر سجل عمليات تاريخي قابل للبحث والاختيار، وإدارة فريق العملية، والاستيراد، والتصدير الخادمي، ومعاينة النتائج وطباعتها. العمليات المكتملة تظل للمعاينة والتصدير، ولا يعاد فتحها من واجهة المشرف.
- التحديثات اللحظية في شاشة المالك تعتمد Postgres Changes ثم إعادة جلب البيانات من RLS، مع مصالحة احتياطية كل 30 ثانية.
- هوية المالك الأمنية مرتبطة ببريد Auth المؤكد `owner@rawaea.com`. في آخر فحص قاعدة البيانات لم يكن حساب Auth بهذا البريد قد أُنشئ بعد؛ لا يعتبر البريد الموجود في قائمة إعدادات التراخيص بديلاً عن حساب دخول مؤكد. راجع `ARCHITECTURE.md`.

## مرجع المعمارية

راجع `ARCHITECTURE.md` لمعرفة نموذج تكليف الجرد وعملية الجرد، حدود صلاحية المالك، فصل CountFlow عن SMART ERP، الدروس المعمارية المستفادة من RAWAEA، وفجوات Offline وRealtime المتبقية.



### CountFlow runtime / PWA

- [countflow-core.js](./countflow-core.js) — isolated Supabase client factory, connectivity hooks, Postgres Changes invalidation/reconciliation helper, and CountFlow Service Worker registration.
- [countflow-sw.js](./countflow-sw.js) — CountFlow-only offline app-shell/static-asset worker. Supabase Auth/API/Storage/Edge Function requests remain network-only and are never cached.
- [manifest.webmanifest](./manifest.webmanifest) and [countflow-icon.svg](./countflow-icon.svg) — independent CountFlow PWA identity.
- The Pages build allowlist includes these four runtime assets. The offline shell is implemented, but real offline boot/restart/reconnect has not yet been verified in a browser. The existing IndexedDB queue close-barrier gap remains open; see ARCHITECTURE.md.

