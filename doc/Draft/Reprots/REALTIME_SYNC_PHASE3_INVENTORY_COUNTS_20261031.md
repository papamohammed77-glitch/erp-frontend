# تقرير إصلاح عزل inventory_counts — المرحلة الثالثة / 2026-10-31

**المستودع:** `papamohammed77-glitch/erp-frontend` — `main`  
**Supabase Production:** `fiilmooggumokxanwiyx`  
**حالة المعالجة:** FIX APPLIED / SQL VERIFIED / SOURCE READBACK VERIFIED  
**حالة اختبار الواجهة:** NOT RUN — لا يوجد مستخدم نشط بدور Counter حاليًا.  
**حالة مهمة Realtime الكلية:** OPEN.

## 1. السبب الجذري قبل الإصلاح
كان الجدول `public.inventory_counts` يحتوي:
- RLS enabled.
- سياسة واحدة `allow_all_inventory_counts` من نوع `FOR ALL` للدور `public`.
- شرط السياسة الوحيد `auth.role() = 'authenticated'` دون `company_id` أو صلاحية تشغيلية.
- منح مباشر لكل من `anon` و`authenticated` على SELECT/INSERT/UPDATE/DELETE.
- الجدول يحتوي عمود `company_id`.

مستهلكو الجدول في المصدر:
- Parent `main.html`: قراءة مع client filter للشركة، لكن هذا لا يعوض RLS.
- Warehouse Counter: قراءة آخر 30 سجلًا دون company filter.
- Van Sales وCounter: الكتابة عبر Edge Function `save-inventory-count`.
- Parent: الكتابة عبر RPC `inventory_control`.

## 2. تثبيت عقد الكتابة قبل التعديل
تم فحص Edge Function Production:
- الاسم: `save-inventory-count`
- الحالة: ACTIVE
- الإصدار: 5
- `verify_jwt=true`
- SHA256: `317b41026da7993765ce4be46265c651271710145499d5c6d92523d04e496725`
- ينشئ Supabase client باستخدام `SUPABASE_SERVICE_ROLE_KEY`.
- يتحقق من Bearer token بواسطة `auth.getUser`.
- يستخرج الشركة من سجل `users` المطابق لـ`auth_id`، ويرفض المستخدم غير الموجود/غير النشط.
- يوجه عمليات `COUNT_*` وعمليات التوافق القديمة إلى `inventory_count_engine` مع company_id المستخرج من المستخدم المصادق عليه.
- الدالة الداخلية `inventory_count_engine` لا يملك authenticated صلاحية EXECUTE عليها مباشرة؛ مسارها server-side.
- Parent يستخدم RPC `inventory_control`، وصلاحية authenticated لاستدعائها ما زالت موجودة. الدالة تتحقق من هوية المستخدم والشركة والصلاحيات.

كما تم مسح جميع ملفات HTML الثلاثين: لم يظهر direct DML على `inventory_counts`; مستهلكو الكتابة المرصودون يستخدمون Edge Function أو RPC. لذلك أمكن إزالة direct write grants من client roles دون تغيير مسار الكتابة المركزي.

## 3. التعديل المطبق في Supabase Production
Migration:
- الاسم: `harden_inventory_counts_tenant_read_boundary_20261031`
- الإصدار: `20261031171715`
- نتيجة التطبيق: SUCCESS.

التغييرات:
1. حذف سياسة `allow_all_inventory_counts`.
2. سحب جميع منح الجدول من `anon` و`authenticated`.
3. إعادة منح SELECT فقط إلى `authenticated`.
4. إنشاء سياسة `inventory_counts_select_company_authorized` من نوع SELECT وللدور authenticated فقط.
5. السياسة تشترط:
   - `company_id = app_private.current_user_company_id()`.
   - وجود سجل مستخدم مطابق لـ`auth.uid()` والشركة نفسها وحالته Active.
   - صلاحية تشغيلية معتمدة: reports/warehouse/warehouse_manager/warehouse_supervisor/general-count/branch-count/vehicle-count، أو دور مدير مخازن/مشرف مخازن/مدير عام، أو active_warehouse_role = جرد، أو wildcard كما هو متفق عليه في محرك الجرد.
6. لم تتغير صلاحيات `service_role`؛ بقيت INSERT/UPDATE متاحة له.
7. لم تتغير دوال الكتابة أو Edge Functions أو بيانات المخزون.

## 4. تعديل المصدر
الملف: `companies/company-1/warehouse/counter.html`

- أضيف تحقق من وجود `currentUser.company_id`.
- أضيف `.eq('company_id', companyId)` إلى استعلام سجل الجردات السابقة.
- لم يتم استبدال الدالة أو إعادة كتابة الملف.
- Commit: `2ddab280b9e0fc362e96f28acd897a2a3b6e1150`.
- Blob بعد إعادة القراءة: `928f510a4e18c938df126e1cba3f30d2aa825b5e`.
- Readback: PASS.

## 5. اختبارات Production بعد الإصلاح

### A. صلاحيات الجدول
نتيجة فحص `has_table_privilege`:
- anon SELECT/INSERT: false.
- authenticated SELECT: true.
- authenticated INSERT/UPDATE/DELETE: false.
- service_role INSERT/UPDATE: true.
- authenticated EXECUTE على `inventory_control`: true.
- authenticated EXECUTE مباشرة على `inventory_count_engine`: false.
**النتيجة: PASS.**

### B. عزل الشركة
اختبار SQL داخل transaction:
- أُنشئ صف مؤقت للشركة الحالية وصف آخر بمعرف شركة مختلف اصطناعي.
- تم تبديل الدور إلى authenticated ومحاكاة JWT لمستخدم نشط لديه warehouse permission.
- النتيجة: صف الشركة نفسها ظاهر = 1؛ صف الشركة الأخرى ظاهر = 0.
- تمت `ROLLBACK` للمعاملة.
**النتيجة: PASS لنطاق policy isolation باستخدام JWT claims المحاكى.** هذا ليس بديلًا عن اختبار شركتين حقيقيتين في المتصفح.

### C. منع القراءة لغير المخولين
- أُنشئ صف مؤقت للشركة نفسها.
- استُخدم JWT لمستخدم نشط لا يحمل أي صلاحية من صلاحيات الجرد/المخازن/التقارير ولا دور Counter.
- النتيجة: الصف الظاهر = 0.
- تمت `ROLLBACK`.
**النتيجة: PASS.**

### D. تنظيف بيانات الاختبار
استعلام لاحق أعاد `remaining_test_rows = 0`.
**النتيجة: PASS — لا توجد بقايا اختبار.**

### E. فحص Advisor
أُعيد تشغيل Supabase Security Advisor بعد التعديل. لم يعد `inventory_counts` ضمن findings؛ بقيت findings أخرى مستقلة:
- 24 جدولًا RLS enabled بلا policies.
- 3 SECURITY DEFINER views.
- 3 functions ذات search_path mutable.
- 20 SECURITY DEFINER functions متاحة لـanon.
- 121 SECURITY DEFINER functions متاحة لـauthenticated.
- leaked-password protection disabled.
هذه الديون خارج نطاق إصلاح الجدول ويجب فرزها في مراجعة أمن مستقلة.

## 6. حدود التحقق
- عدد صفوف `inventory_counts` قبل الإصلاح كان صفرًا.
- استعلام المستخدمين النشطين أظهر مستخدمين مرتبطين بشركة واحدة فقط؛ لا يمكن إثبات عزل شركتين حقيقيتين في Production.
- لا يوجد مستخدم نشط حاليًا لديه `active_warehouse_role='جرد'` (العدد 0)، لذلك لم يُنفذ اختبار دخول Counter الفعلي.
- لم يتم استدعاء Edge Function من متصفح مستخدم حقيقي؛ تم فحص مصدرها وإعداداتها وصلاحيات RPC التي تعتمد عليها.
- تعديل `counter.html` موجود في GitHub main، لكن نشره على Cloudflare لم يُثبت بعد.
- لا يوجد تغيير في publication أو أي جدول آخر.

## 7. ملاحظة تشغيلية مفتوحة
في `warehouse/counter.html`, عندما يكون نوع الجرد `general` يرسل العميل القيمة `entityId='MAIN'` إذا كان الحقل فارغًا. Edge Function legacy contract يتعامل مع `entityId` كمعرف فرع UUID أو null كي يسترجع `app_settings.main_branch_id`. هذه نقطة توافق منفصلة يجب حسمها واختبارها قبل إغلاق Counter E2E؛ لم تُغيّر ضمن إصلاح RLS.

## 8. القرار
- RLS tenant boundary: FIXED IN PRODUCTION / SQL-VERIFIED.
- Direct client write surface: REMOVED for anon/authenticated.
- Counter client query: company-scoped in GitHub main / readback PASS.
- Central write paths: preserved.
- Cross-company browser E2E: OPEN/BLOCKED.
- Cloudflare parity: OPEN.
- Overall Realtime mission: OPEN.

## 9. الخطوة التالية
1. التحقق من توافق `general` count payload بين Counter و`save-inventory-count`، وتحديد دور Counter المطلوب فعليًا.
2. اختبار Edge Function وRPC بهوية تشغيلية مصرح بها في بيئة اختبار.
3. معالجة اشتراكات النظام الأم غير المتوافقة مع publication/RLS دون تخفيف عزل البيانات.
4. استكمال freshness matrix ثم E2E وCloudflare parity.


## 9. Counter general-count payload compatibility correction (2026-10-31)

A source/contract comparison found a second Counter defect:
- The UI permits an empty entity for `type='general'`, but sent `entityId='MAIN'`.
- The existing `save-inventory-count` Edge Function treats a non-null entityId as a branch UUID. It only resolves `app_settings.main_branch_id` when entityId is null.
- Production check confirmed one app_settings row for the active company, its main_branch_id is configured, resolves to an existing branch in the same company, and has no broken mapping.

Surgical source correction:
- Changed only the payload expression in `warehouse/counter.html` from `entityId:entity||'MAIN'` to `entityId:entity||null`.
- Commit: `204b36d7518a4fc88732f990ad3dfa0cec105124`.
- GitHub readback confirms the new expression and absence of the old sentinel.
- No Edge Function code, SQL data, or schema changed for this correction.

**Status:** SOURCE CONTRACT CORRECTED / READBACK PASS / EDGE FUNCTION RUNTIME TEST OPEN. No active user currently has `active_warehouse_role='جرد'`, so a real Counter submission was not executed. The configured main branch is verified in Production, but the complete general-count workflow must still be tested with an authorized Counter identity.
