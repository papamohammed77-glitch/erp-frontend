# CountFlow — النشر المستقل على Cloudflare Pages

## نطاق النشر

- مجلد مخرجات Cloudflare Pages: `companies/company-2/Counting/dist` (قائمة ملفات مسموح بها فقط)
- صفحة الجذر: `index.html` وتحوّل إلى `countflow-admin.html`.
- النظام الأم: `/countflow-admin.html`
- تطبيق المندوب: `/countflow.html`
- لوحة المشرف: `/Countflow-supervisor.html`
- Supabase: المشروع `rawaea-staging` فقط (`hfzznsiprnwkpayskzhu`).

## إنشاء مشروع Cloudflare Pages منفصل

1. أنشئ مشروع Pages جديداً باسم CountFlow في حساب Cloudflare، ولا تربطه بمشروع Pages الخاص بـRAWAEA.
2. اربط مستودع `papamohammed77-glitch/erp-frontend` والفرع `main`.
3. Build command: `bash companies/company-2/Counting/scripts/build-pages.sh`.
4. عيّن Build output directory إلى `companies/company-2/Counting/dist`.
5. لا تستخدم `companies/company-1` ولا `rawaea-erp.pages.dev` كجذر أو alias أو redirect.
6. اختبر صفحات الإدارة والمشرف والمندوب على عنوان Pages المؤقت قبل ربط دومين مخصص.
7. أضف دومين CountFlow المخصص بعد أن يحدده مالك المشروع؛ لا توجد قيمة دومين مؤكدة في هذا المستند، ولا يجوز تخمينها.

يُنشئ السكربت `dist` من قائمة سماح تضم صفحات HTML الأربعة وملف `_headers` فقط. لا ينسخ `database/` أو `functions/` أو `tests/` أو ملفات Markdown أو SQL أو TypeScript إلى المخرجات العامة.

## حدود النشر الحالية

- ملفات الواجهة تستخدم Supabase Publishable Key فقط. لا تضف Service Role Key إلى ملفات الواجهة أو متغيرات Vite/Pages العامة.
- Edge Functions الخاصة بـCountFlow يجب أن تبقى على مشروع `rawaea-staging`، مع JWT verification مفعّل.
- قبل الإطلاق: نفّذ اختبار متصفح فعلي لتسجيل الدخول، bootstrap أول مالك، إنشاء مشروع، إنشاء مستخدم عبر Edge Function، وإكمال دورة جرد تجريبية قابلة للحذف.
- لا يتم اعتبار إنشاء ملفات Pages أو هذا الدليل بمثابة نشر فعلي. لم يُنشأ مشروع Cloudflare Pages ولم يتم تعديل DNS أو الدومين في LVE-736.
