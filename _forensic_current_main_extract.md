# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=30346
FILE_BYTES=1705478
SHA256=b9c8fe86863fbea98325aef387af8a4f022a7ff862370ebb2caa0a3cfa767b8f
PATTERN var RW_Warehouse: [13738]
PATTERN var RW_HR: [28298]
PATTERN RW_HR: [28250, 28296, 28298, 28414, 28443]
PATTERN hr_list_employees: []
PATTERN hr_command_atomic: [28318]
PATTERN hr_query: [26991, 27094, 27138, 27259, 28317]
PATTERN hr_payroll_calculate_impl: []
PATTERN hr_payroll_post_impl: []
PATTERN employee_documents: [28414]
PATTERN hr_departments: [28414]
PATTERN hr_contracts: [28414]
PATTERN hr_work_schedules: [28414]
PATTERN hr_attendance_events: [28414]
PATTERN hr_leave_types: [28414]
PATTERN hr_requests: [28414]
PATTERN hr_salary_advances: [28414]
PATTERN hr_payroll_periods: [28414]
PATTERN hr_payslips: [28414]
PATTERN hr_command: [28318]
PATTERN employee-document: [28410, 28411]
PATTERN document-upload: []
PATTERN الموارد البشرية: [1560, 7754, 9084, 23454, 23486, 28238, 28296, 28412]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 28268-28478 around 28298 ---
28268:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
28269:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
28270: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
28271: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
28272: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
28273: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
28274:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
28275:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
28276:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
28277:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
28278:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
28279:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
28280:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
28281:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
28282:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
28283:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
28284:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
28285:         if (view === 'finance') { RW_Finance.render(); return; }
28286:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
28287:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
28288:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
28289:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
28290: 
28291:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
28292:     }
28293: };
28294: window.RW_Views = RW_Views;
28295: // ============================================================
28296: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
28297: // ============================================================
28298: var RW_HR = (function() {
28299:  'use strict';
28300:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
28301:   var T=[
28302:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
28303:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
28304:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
28305:   ];
28306:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
28307:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
28308:   function num(v){v=Number(v);return isFinite(v)?v:0}
28309:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
28310:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
28311:   function iso(v){return v?new Date(v).toISOString():null}
28312:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
28313:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
28314:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
28315:   function opClear(k){if(k)delete H.ops[k]}
28316:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
28317:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
28318:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
28319:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
28320:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
28321:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
28322:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
28323:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
28324:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
28325:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
28326:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
28327:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
28328:  function modal(title,body,onSubmit,key){
28329:   var old=E('rw-hr-modal-root');
28330:   if(old)old.remove();
28331:   var r=document.createElement('div');
28332:   r.id='rw-hr-modal-root';
28333:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
28334:   document.body.appendChild(r);
28335:   E('rw-hr-close').onclick=closeModal;
28336:   E('rw-hr-cancel').onclick=closeModal;
28337:   r.addEventListener('click',function(e){
28338:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28339:     if(ac){
28340:       e.preventDefault();
28341:       handle(ac.getAttribute('data-hr-action'));
28342:     }
28343:   });
28344:   if(onSubmit===null){
28345:     var f=E('rw-hr-form');
28346:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28347:   }else{
28348:     E('rw-hr-form').onsubmit=async function(e){
28349:       e.preventDefault();
28350:       var save=e.target.querySelector('button[type="submit"]');
28351:       try{
28352:         if(save){
28353:           save.disabled=true;
28354:           save.textContent='جارٍ الحفظ…';
28355:         }
28356:         await onSubmit(key||'form:'+Date.now());
28357:       }catch(err){
28358:         toast(err.message||'تعذر الحفظ','error');
28359:         if(save){
28360:           save.disabled=false;
28361:           save.textContent='حفظ';
28362:         }
28363:       }
28364:     };
28365:   }
28366: }
28367: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
28368:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
28369:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
28370:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
28371:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
28372:   function employeeOpts(){return ppl()}
28373:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28374:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
28375:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28376:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
28377:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
28378:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
28379:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
28380:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
28381:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
28382:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
28383:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
28384:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
28385:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
28386:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
28387:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
28388:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
28389:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
28390:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
28391:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
28392:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
28393:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
28394:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
28395:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
28396:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
28397:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
28398:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
28399:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
28400:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
28401:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
28402:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
28403:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
28404:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
28405:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
28406:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
28407:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
28408:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
28409:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
28410:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
28411:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
28412:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
28413:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
28414:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
28415:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
28416:   (function installModalResilience(){
28417:     document.addEventListener('click',function(e){
28418:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28419:       if(!ac)return;
28420:       var page=E('rw-page-container');
28421:       if(page&&page.contains(ac))return;
28422:       e.preventDefault();
28423:       handle(ac.getAttribute('data-hr-action'));
28424:     },true);
28425:     window.addEventListener('unhandledrejection',function(e){
28426:       var root=E('rw-hr-modal-root');
28427:       if(!root)return;
28428:       e.preventDefault();
28429:       var msg=e.reason&&(e.reason.message||String(e.reason));
28430:       if(msg)toast(msg,'error');
28431:     });
28432:     try{
28433:       var mo=new MutationObserver(function(){
28434:         var root=E('rw-hr-modal-root');
28435:         if(!root||!E('hr360'))return;
28436:         var f=E('rw-hr-form');
28437:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28438:       });
28439:       mo.observe(document.body,{childList:true,subtree:true});
28440:     }catch(e){}
28441:   }());
28442: 
28443: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
28444: 
28445: 
28446: // ============================================================
28447: // RW_CRM – إدارة علاقات العملاء (CRM)
28448: // ============================================================
28449: var RW_CRM = (function() {
28450:     'use strict';
28451: 
28452:     var state = {
28453:         customers: [],
28454:         assignees: [],
28455:         kpi: {},
28456:         search: '',
28457:         activeOnly: false,
28458:         searchTimer: null
28459:     };
28460: 
28461:     function _esc(s) {
28462:         return String(s == null ? '' : s)
28463:             .replace(/&/g, '&amp;')
28464:             .replace(/</g, '&lt;')
28465:             .replace(/>/g, '&gt;')
28466:             .replace(/"/g, '&quot;')
28467:             .replace(/'/g, '&#39;');
28468:     }
28469: 
28470:     function _fmtNum(n) {
28471:         return Number(n || 0).toLocaleString('ar-EG');
28472:     }
28473: 
28474:     function _fmtMoney(n) {
28475:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
28476:     }
28477: 
28478:     function _today() {
--- WINDOW 28288-28498 around 28318 ---
28288:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
28289:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
28290: 
28291:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
28292:     }
28293: };
28294: window.RW_Views = RW_Views;
28295: // ============================================================
28296: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
28297: // ============================================================
28298: var RW_HR = (function() {
28299:  'use strict';
28300:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
28301:   var T=[
28302:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
28303:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
28304:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
28305:   ];
28306:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
28307:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
28308:   function num(v){v=Number(v);return isFinite(v)?v:0}
28309:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
28310:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
28311:   function iso(v){return v?new Date(v).toISOString():null}
28312:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
28313:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
28314:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
28315:   function opClear(k){if(k)delete H.ops[k]}
28316:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
28317:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
28318:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
28319:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
28320:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
28321:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
28322:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
28323:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
28324:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
28325:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
28326:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
28327:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
28328:  function modal(title,body,onSubmit,key){
28329:   var old=E('rw-hr-modal-root');
28330:   if(old)old.remove();
28331:   var r=document.createElement('div');
28332:   r.id='rw-hr-modal-root';
28333:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
28334:   document.body.appendChild(r);
28335:   E('rw-hr-close').onclick=closeModal;
28336:   E('rw-hr-cancel').onclick=closeModal;
28337:   r.addEventListener('click',function(e){
28338:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28339:     if(ac){
28340:       e.preventDefault();
28341:       handle(ac.getAttribute('data-hr-action'));
28342:     }
28343:   });
28344:   if(onSubmit===null){
28345:     var f=E('rw-hr-form');
28346:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28347:   }else{
28348:     E('rw-hr-form').onsubmit=async function(e){
28349:       e.preventDefault();
28350:       var save=e.target.querySelector('button[type="submit"]');
28351:       try{
28352:         if(save){
28353:           save.disabled=true;
28354:           save.textContent='جارٍ الحفظ…';
28355:         }
28356:         await onSubmit(key||'form:'+Date.now());
28357:       }catch(err){
28358:         toast(err.message||'تعذر الحفظ','error');
28359:         if(save){
28360:           save.disabled=false;
28361:           save.textContent='حفظ';
28362:         }
28363:       }
28364:     };
28365:   }
28366: }
28367: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
28368:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
28369:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
28370:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
28371:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
28372:   function employeeOpts(){return ppl()}
28373:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28374:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
28375:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28376:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
28377:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
28378:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
28379:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
28380:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
28381:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
28382:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
28383:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
28384:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
28385:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
28386:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
28387:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
28388:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
28389:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
28390:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
28391:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
28392:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
28393:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
28394:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
28395:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
28396:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
28397:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
28398:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
28399:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
28400:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
28401:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
28402:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
28403:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
28404:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
28405:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
28406:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
28407:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
28408:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
28409:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
28410:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
28411:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
28412:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
28413:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
28414:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
28415:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
28416:   (function installModalResilience(){
28417:     document.addEventListener('click',function(e){
28418:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28419:       if(!ac)return;
28420:       var page=E('rw-page-container');
28421:       if(page&&page.contains(ac))return;
28422:       e.preventDefault();
28423:       handle(ac.getAttribute('data-hr-action'));
28424:     },true);
28425:     window.addEventListener('unhandledrejection',function(e){
28426:       var root=E('rw-hr-modal-root');
28427:       if(!root)return;
28428:       e.preventDefault();
28429:       var msg=e.reason&&(e.reason.message||String(e.reason));
28430:       if(msg)toast(msg,'error');
28431:     });
28432:     try{
28433:       var mo=new MutationObserver(function(){
28434:         var root=E('rw-hr-modal-root');
28435:         if(!root||!E('hr360'))return;
28436:         var f=E('rw-hr-form');
28437:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28438:       });
28439:       mo.observe(document.body,{childList:true,subtree:true});
28440:     }catch(e){}
28441:   }());
28442: 
28443: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
28444: 
28445: 
28446: // ============================================================
28447: // RW_CRM – إدارة علاقات العملاء (CRM)
28448: // ============================================================
28449: var RW_CRM = (function() {
28450:     'use strict';
28451: 
28452:     var state = {
28453:         customers: [],
28454:         assignees: [],
28455:         kpi: {},
28456:         search: '',
28457:         activeOnly: false,
28458:         searchTimer: null
28459:     };
28460: 
28461:     function _esc(s) {
28462:         return String(s == null ? '' : s)
28463:             .replace(/&/g, '&amp;')
28464:             .replace(/</g, '&lt;')
28465:             .replace(/>/g, '&gt;')
28466:             .replace(/"/g, '&quot;')
28467:             .replace(/'/g, '&#39;');
28468:     }
28469: 
28470:     function _fmtNum(n) {
28471:         return Number(n || 0).toLocaleString('ar-EG');
28472:     }
28473: 
28474:     function _fmtMoney(n) {
28475:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
28476:     }
28477: 
28478:     function _today() {
28479:         var d = new Date();
28480:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
28481:         return local.toISOString().slice(0, 10);
28482:     }
28483: 
28484:     function _statusLabel(s) {
28485:         var map = {
28486:             Open: 'مفتوحة',
28487:             'معلقة': 'معلقة',
28488:             completed: 'مكتملة',
28489:             'مكتملة': 'مكتملة',
28490:             cancelled: 'ملغاة',
28491:             'ملغاة': 'ملغاة'
28492:         };
28493:         return map[s] || s || 'غير محددة';
28494:     }
28495: 
28496:     function _statusClass(s) {
28497:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
28498:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
--- WINDOW 26961-27171 around 26991 ---
26961:                         '<td class="p-2">' +
26962:                         _esc(row.email) +
26963:                         '</td>' +
26964:                         '<td class="p-2">' +
26965:                         _esc(row.role) +
26966:                         '</td>' +
26967:                         '<td class="p-2">' +
26968:                         _esc(row.status) +
26969:                         '</td>' +
26970:                         '</tr>'
26971:                     );
26972:                 });
26973: 
26974:             html =
26975:                 '<h4 class="font-bold mb-3">قائمة الموظفين</h4>' +
26976:                 _table(
26977:                     [
26978:                         'الاسم',
26979:                         'البريد',
26980:                         'الدور',
26981:                         'الحالة'
26982:                     ],
26983:                     rows28
26984:                 );
26985:         }
26986: 
26987:         else if (reportId === 'hr-attendance') {
26988: 
26989:             var hrAttendanceReport =
26990:                 await supabase.rpc(
26991:                     'hr_query',
26992:                     {
26993:                         p_view: 'attendance',
26994:                         p_payload: {
26995:                             from: fromDate,
26996:                             to: toDate,
26997:                             limit: 5000
26998:                         }
26999:                     }
27000:                 );
27001: 
27002:             if (hrAttendanceReport.error) {
27003:                 throw hrAttendanceReport.error;
27004:             }
27005: 
27006:             var hrAttendancePayload =
27007:                 hrAttendanceReport.data || {};
27008: 
27009:             if (hrAttendancePayload.success === false) {
27010:                 throw new Error(
27011:                     hrAttendancePayload.msg ||
27012:                     hrAttendancePayload.code ||
27013:                     'لا توجد صلاحية أو مصدر صالح لتقرير الحضور'
27014:                 );
27015:             }
27016: 
27017:             var hrAttendanceRows =
27018:                 Array.isArray(hrAttendancePayload.rows)
27019:                     ? hrAttendancePayload.rows
27020:                     : [];
27021: 
27022:             var attendanceWorkedHours = 0;
27023:             var attendanceLateMinutes = 0;
27024:             var attendanceOvertimeHours = 0;
27025: 
27026:             var hrAttendanceTableRows =
27027:                 hrAttendanceRows.map(function(row) {
27028: 
27029:                     attendanceWorkedHours +=
27030:                         Number(row.worked_hours) || 0;
27031: 
27032:                     attendanceLateMinutes +=
27033:                         Number(row.late_minutes) || 0;
27034: 
27035:                     attendanceOvertimeHours +=
27036:                         Number(row.overtime_hours) || 0;
27037: 
27038:                     return (
27039:                         '<tr class="border-t">' +
27040:                         '<td class="p-2">' +
27041:                         _esc(row.attendance_date) +
27042:                         '</td>' +
27043:                         '<td class="p-2 font-semibold">' +
27044:                         _esc(row.employee_name || row.email || '') +
27045:                         '</td>' +
27046:                         '<td class="p-2">' +
27047:                         _esc(row.status || '') +
27048:                         '</td>' +
27049:                         '<td class="p-2 text-center">' +
27050:                         _esc(
27051:                             row.check_in
27052:                                 ? new Date(row.check_in).toLocaleTimeString(
27053:                                     'ar-EG',
27054:                                     {
27055:                                         hour: '2-digit',
27056:                                         minute: '2-digit'
27057:                                     }
27058:                                   )
27059:                                 : '-'
27060:                         ) +
27061:                         '</td>' +
27062:                         '<td class="p-2 text-center">' +
27063:                         _esc(
27064:                             row.check_out
27065:                                 ? new Date(row.check_out).toLocaleTimeString(
27066:                                     'ar-EG',
27067:                                     {
27068:                                         hour: '2-digit',
27069:                                         minute: '2-digit'
27070:                                     }
27071:                                   )
27072:                                 : '-'
27073:                         ) +
27074:                         '</td>' +
27075:                         '<td class="p-2 text-center font-bold">' +
27076:                         _fmtNum(row.worked_hours) +
27077:                         '</td>' +
27078:                         '<td class="p-2 text-center">' +
27079:                         _fmtNum(row.late_minutes) +
27080:                         '</td>' +
27081:                         '<td class="p-2 text-center">' +
27082:                         _fmtNum(row.overtime_hours) +
27083:                         '</td>' +
27084:                         '<td class="p-2 text-center">' +
27085:                         _fmtNum(row.absence_minutes) +
27086:                         '</td>' +
27087:                         '</tr>'
27088:                     );
27089:                 });
27090: 
27091:             html =
27092:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
27093:                 '<div class="mb-4 text-xs text-gray-500">' +
27094:                 'المصدر: Production hr_query(attendance)' +
27095:                 '</div>' +
27096:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27097:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27098:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
27099:                 '<div class="text-lg font-black">' +
27100:                 _fmtNum(hrAttendanceRows.length) +
27101:                 '</div></div>' +
27102:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27103:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
27104:                 '<div class="text-lg font-black">' +
27105:                 _fmtNum(attendanceWorkedHours) +
27106:                 '</div></div>' +
27107:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27108:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27109:                 '<div class="text-lg font-black">' +
27110:                 _fmtNum(attendanceLateMinutes) +
27111:                 '</div></div>' +
27112:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27113:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27114:                 '<div class="text-lg font-black">' +
27115:                 _fmtNum(attendanceOvertimeHours) +
27116:                 '</div></div>' +
27117:                 '</div>' +
27118:                 _table(
27119:                     [
27120:                         'التاريخ',
27121:                         'الموظف',
27122:                         'الحالة',
27123:                         'الدخول',
27124:                         'الخروج',
27125:                         'ساعات العمل',
27126:                         'التأخير بالدقائق',
27127:                         'الساعات الإضافية',
27128:                         'دقائق الغياب'
27129:                     ],
27130:                     hrAttendanceTableRows
27131:                 );
27132:         }
27133: 
27134:         else if (reportId === 'hr-salary') {
27135: 
27136:             var hrPayrollReport =
27137:                 await supabase.rpc(
27138:                     'hr_query',
27139:                     {
27140:                         p_view: 'payroll_runs',
27141:                         p_payload: {}
27142:                     }
27143:                 );
27144: 
27145:             if (hrPayrollReport.error) {
27146:                 throw hrPayrollReport.error;
27147:             }
27148: 
27149:             var hrPayrollPayload =
27150:                 hrPayrollReport.data || {};
27151: 
27152:             if (hrPayrollPayload.success === false) {
27153:                 throw new Error(
27154:                     hrPayrollPayload.msg ||
27155:                     hrPayrollPayload.code ||
27156:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27157:                 );
27158:             }
27159: 
27160:             var hrPayrollRows =
27161:                 Array.isArray(hrPayrollPayload.rows)
27162:                     ? hrPayrollPayload.rows
27163:                     : [];
27164: 
27165:             var filteredPayrollRows = [];
27166: 
27167:             var payrollGrossTotal = 0;
27168:             var payrollDeductionTotal = 0;
27169:             var payrollNetTotal = 0;
27170:             var payrollEmployeeTotal = 0;
27171: 
--- WINDOW 27064-27274 around 27094 ---
27064:                             row.check_out
27065:                                 ? new Date(row.check_out).toLocaleTimeString(
27066:                                     'ar-EG',
27067:                                     {
27068:                                         hour: '2-digit',
27069:                                         minute: '2-digit'
27070:                                     }
27071:                                   )
27072:                                 : '-'
27073:                         ) +
27074:                         '</td>' +
27075:                         '<td class="p-2 text-center font-bold">' +
27076:                         _fmtNum(row.worked_hours) +
27077:                         '</td>' +
27078:                         '<td class="p-2 text-center">' +
27079:                         _fmtNum(row.late_minutes) +
27080:                         '</td>' +
27081:                         '<td class="p-2 text-center">' +
27082:                         _fmtNum(row.overtime_hours) +
27083:                         '</td>' +
27084:                         '<td class="p-2 text-center">' +
27085:                         _fmtNum(row.absence_minutes) +
27086:                         '</td>' +
27087:                         '</tr>'
27088:                     );
27089:                 });
27090: 
27091:             html =
27092:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
27093:                 '<div class="mb-4 text-xs text-gray-500">' +
27094:                 'المصدر: Production hr_query(attendance)' +
27095:                 '</div>' +
27096:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27097:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27098:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
27099:                 '<div class="text-lg font-black">' +
27100:                 _fmtNum(hrAttendanceRows.length) +
27101:                 '</div></div>' +
27102:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27103:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
27104:                 '<div class="text-lg font-black">' +
27105:                 _fmtNum(attendanceWorkedHours) +
27106:                 '</div></div>' +
27107:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27108:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27109:                 '<div class="text-lg font-black">' +
27110:                 _fmtNum(attendanceLateMinutes) +
27111:                 '</div></div>' +
27112:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27113:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27114:                 '<div class="text-lg font-black">' +
27115:                 _fmtNum(attendanceOvertimeHours) +
27116:                 '</div></div>' +
27117:                 '</div>' +
27118:                 _table(
27119:                     [
27120:                         'التاريخ',
27121:                         'الموظف',
27122:                         'الحالة',
27123:                         'الدخول',
27124:                         'الخروج',
27125:                         'ساعات العمل',
27126:                         'التأخير بالدقائق',
27127:                         'الساعات الإضافية',
27128:                         'دقائق الغياب'
27129:                     ],
27130:                     hrAttendanceTableRows
27131:                 );
27132:         }
27133: 
27134:         else if (reportId === 'hr-salary') {
27135: 
27136:             var hrPayrollReport =
27137:                 await supabase.rpc(
27138:                     'hr_query',
27139:                     {
27140:                         p_view: 'payroll_runs',
27141:                         p_payload: {}
27142:                     }
27143:                 );
27144: 
27145:             if (hrPayrollReport.error) {
27146:                 throw hrPayrollReport.error;
27147:             }
27148: 
27149:             var hrPayrollPayload =
27150:                 hrPayrollReport.data || {};
27151: 
27152:             if (hrPayrollPayload.success === false) {
27153:                 throw new Error(
27154:                     hrPayrollPayload.msg ||
27155:                     hrPayrollPayload.code ||
27156:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27157:                 );
27158:             }
27159: 
27160:             var hrPayrollRows =
27161:                 Array.isArray(hrPayrollPayload.rows)
27162:                     ? hrPayrollPayload.rows
27163:                     : [];
27164: 
27165:             var filteredPayrollRows = [];
27166: 
27167:             var payrollGrossTotal = 0;
27168:             var payrollDeductionTotal = 0;
27169:             var payrollNetTotal = 0;
27170:             var payrollEmployeeTotal = 0;
27171: 
27172:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
27173: 
27174:                 var payrollRow = hrPayrollRows[pr] || {};
27175: 
27176:                 var periodStart =
27177:                     String(
27178:                         payrollRow.start_date ||
27179:                         ''
27180:                     ).slice(0, 10);
27181: 
27182:                 var periodEnd =
27183:                     String(
27184:                         payrollRow.end_date ||
27185:                         ''
27186:                     ).slice(0, 10);
27187: 
27188:                 if (
27189:                     periodStart &&
27190:                     periodEnd &&
27191:                     periodEnd < fromDate
27192:                 ) {
27193:                     continue;
27194:                 }
27195: 
27196:                 if (
27197:                     periodStart &&
27198:                     periodEnd &&
27199:                     periodStart > toDate
27200:                 ) {
27201:                     continue;
27202:                 }
27203: 
27204:                 filteredPayrollRows.push(
27205:                     payrollRow
27206:                 );
27207: 
27208:                 payrollGrossTotal +=
27209:                     Number(payrollRow.gross_total) || 0;
27210: 
27211:                 payrollDeductionTotal +=
27212:                     Number(payrollRow.deduction_total) || 0;
27213: 
27214:                 payrollNetTotal +=
27215:                     Number(payrollRow.net_total) || 0;
27216: 
27217:                 payrollEmployeeTotal +=
27218:                     Number(payrollRow.employee_count) || 0;
27219:             }
27220: 
27221:             var payrollTableRows =
27222:                 filteredPayrollRows.map(function(row) {
27223: 
27224:                     return (
27225:                         '<tr class="border-t">' +
27226:                         '<td class="p-2">' +
27227:                         _esc(row.run_no || '') +
27228:                         '</td>' +
27229:                         '<td class="p-2 font-semibold">' +
27230:                         _esc(row.period_code || '') +
27231:                         '</td>' +
27232:                         '<td class="p-2">' +
27233:                         _esc(row.start_date || '') +
27234:                         ' → ' +
27235:                         _esc(row.end_date || '') +
27236:                         '</td>' +
27237:                         '<td class="p-2 text-center">' +
27238:                         _fmtNum(row.employee_count) +
27239:                         '</td>' +
27240:                         '<td class="p-2 text-center">' +
27241:                         _fmtNum(row.gross_total) +
27242:                         '</td>' +
27243:                         '<td class="p-2 text-center">' +
27244:                         _fmtNum(row.deduction_total) +
27245:                         '</td>' +
27246:                         '<td class="p-2 text-center font-bold">' +
27247:                         _fmtNum(row.net_total) +
27248:                         '</td>' +
27249:                         '<td class="p-2">' +
27250:                         _esc(row.status || '') +
27251:                         '</td>' +
27252:                         '</tr>'
27253:                     );
27254:                 });
27255: 
27256:             html =
27257:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27258:                 '<div class="mb-4 text-xs text-gray-500">' +
27259:                 'المصدر: Production hr_query(payroll_runs)' +
27260:                 '</div>' +
27261:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27262:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27263:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27264:                 '<div class="text-lg font-black">' +
27265:                 _fmtNum(filteredPayrollRows.length) +
27266:                 '</div></div>' +
27267:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27268:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27269:                 '<div class="text-lg font-black">' +
27270:                 _fmtNum(payrollGrossTotal) +
27271:                 '</div></div>' +
27272:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27273:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27274:                 '<div class="text-lg font-black">' +
--- WINDOW 27108-27318 around 27138 ---
27108:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27109:                 '<div class="text-lg font-black">' +
27110:                 _fmtNum(attendanceLateMinutes) +
27111:                 '</div></div>' +
27112:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27113:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27114:                 '<div class="text-lg font-black">' +
27115:                 _fmtNum(attendanceOvertimeHours) +
27116:                 '</div></div>' +
27117:                 '</div>' +
27118:                 _table(
27119:                     [
27120:                         'التاريخ',
27121:                         'الموظف',
27122:                         'الحالة',
27123:                         'الدخول',
27124:                         'الخروج',
27125:                         'ساعات العمل',
27126:                         'التأخير بالدقائق',
27127:                         'الساعات الإضافية',
27128:                         'دقائق الغياب'
27129:                     ],
27130:                     hrAttendanceTableRows
27131:                 );
27132:         }
27133: 
27134:         else if (reportId === 'hr-salary') {
27135: 
27136:             var hrPayrollReport =
27137:                 await supabase.rpc(
27138:                     'hr_query',
27139:                     {
27140:                         p_view: 'payroll_runs',
27141:                         p_payload: {}
27142:                     }
27143:                 );
27144: 
27145:             if (hrPayrollReport.error) {
27146:                 throw hrPayrollReport.error;
27147:             }
27148: 
27149:             var hrPayrollPayload =
27150:                 hrPayrollReport.data || {};
27151: 
27152:             if (hrPayrollPayload.success === false) {
27153:                 throw new Error(
27154:                     hrPayrollPayload.msg ||
27155:                     hrPayrollPayload.code ||
27156:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27157:                 );
27158:             }
27159: 
27160:             var hrPayrollRows =
27161:                 Array.isArray(hrPayrollPayload.rows)
27162:                     ? hrPayrollPayload.rows
27163:                     : [];
27164: 
27165:             var filteredPayrollRows = [];
27166: 
27167:             var payrollGrossTotal = 0;
27168:             var payrollDeductionTotal = 0;
27169:             var payrollNetTotal = 0;
27170:             var payrollEmployeeTotal = 0;
27171: 
27172:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
27173: 
27174:                 var payrollRow = hrPayrollRows[pr] || {};
27175: 
27176:                 var periodStart =
27177:                     String(
27178:                         payrollRow.start_date ||
27179:                         ''
27180:                     ).slice(0, 10);
27181: 
27182:                 var periodEnd =
27183:                     String(
27184:                         payrollRow.end_date ||
27185:                         ''
27186:                     ).slice(0, 10);
27187: 
27188:                 if (
27189:                     periodStart &&
27190:                     periodEnd &&
27191:                     periodEnd < fromDate
27192:                 ) {
27193:                     continue;
27194:                 }
27195: 
27196:                 if (
27197:                     periodStart &&
27198:                     periodEnd &&
27199:                     periodStart > toDate
27200:                 ) {
27201:                     continue;
27202:                 }
27203: 
27204:                 filteredPayrollRows.push(
27205:                     payrollRow
27206:                 );
27207: 
27208:                 payrollGrossTotal +=
27209:                     Number(payrollRow.gross_total) || 0;
27210: 
27211:                 payrollDeductionTotal +=
27212:                     Number(payrollRow.deduction_total) || 0;
27213: 
27214:                 payrollNetTotal +=
27215:                     Number(payrollRow.net_total) || 0;
27216: 
27217:                 payrollEmployeeTotal +=
27218:                     Number(payrollRow.employee_count) || 0;
27219:             }
27220: 
27221:             var payrollTableRows =
27222:                 filteredPayrollRows.map(function(row) {
27223: 
27224:                     return (
27225:                         '<tr class="border-t">' +
27226:                         '<td class="p-2">' +
27227:                         _esc(row.run_no || '') +
27228:                         '</td>' +
27229:                         '<td class="p-2 font-semibold">' +
27230:                         _esc(row.period_code || '') +
27231:                         '</td>' +
27232:                         '<td class="p-2">' +
27233:                         _esc(row.start_date || '') +
27234:                         ' → ' +
27235:                         _esc(row.end_date || '') +
27236:                         '</td>' +
27237:                         '<td class="p-2 text-center">' +
27238:                         _fmtNum(row.employee_count) +
27239:                         '</td>' +
27240:                         '<td class="p-2 text-center">' +
27241:                         _fmtNum(row.gross_total) +
27242:                         '</td>' +
27243:                         '<td class="p-2 text-center">' +
27244:                         _fmtNum(row.deduction_total) +
27245:                         '</td>' +
27246:                         '<td class="p-2 text-center font-bold">' +
27247:                         _fmtNum(row.net_total) +
27248:                         '</td>' +
27249:                         '<td class="p-2">' +
27250:                         _esc(row.status || '') +
27251:                         '</td>' +
27252:                         '</tr>'
27253:                     );
27254:                 });
27255: 
27256:             html =
27257:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27258:                 '<div class="mb-4 text-xs text-gray-500">' +
27259:                 'المصدر: Production hr_query(payroll_runs)' +
27260:                 '</div>' +
27261:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27262:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27263:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27264:                 '<div class="text-lg font-black">' +
27265:                 _fmtNum(filteredPayrollRows.length) +
27266:                 '</div></div>' +
27267:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27268:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27269:                 '<div class="text-lg font-black">' +
27270:                 _fmtNum(payrollGrossTotal) +
27271:                 '</div></div>' +
27272:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27273:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27274:                 '<div class="text-lg font-black">' +
27275:                 _fmtNum(payrollDeductionTotal) +
27276:                 '</div></div>' +
27277:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27278:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
27279:                 '<div class="text-lg font-black">' +
27280:                 _fmtNum(payrollNetTotal) +
27281:                 '</div></div>' +
27282:                 '</div>' +
27283:                 '<div class="mb-4 text-xs text-gray-500">' +
27284:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
27285:                 _fmtNum(payrollEmployeeTotal) +
27286:                 '</div>' +
27287:                 _table(
27288:                     [
27289:                         'رقم المسير',
27290:                         'الفترة',
27291:                         'النطاق',
27292:                         'الموظفون',
27293:                         'إجمالي الأجور',
27294:                         'الاستقطاعات',
27295:                         'الصافي',
27296:                         'الحالة'
27297:                     ],
27298:                     payrollTableRows
27299:                 );
27300:         }
27301:         else {
27302: 
27303:             html =
27304:                 '<div class="text-center py-4 text-gray-500">' +
27305:                 'هذا التقرير غير متوفر بعد' +
27306:                 '</div>';
27307:         }
27308: 
27309:         safeHTML(
27310:     resultDiv,
27311:     html +
27312:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
27313:     '<span>المصدر: Production</span>' +
27314:     '<span>آخر تنفيذ: ' +
27315:     _esc(
27316:         new Date().toLocaleString('ar-EG')
27317:     ) +
27318:     '</span>' +
--- WINDOW 27229-27439 around 27259 ---
27229:                         '<td class="p-2 font-semibold">' +
27230:                         _esc(row.period_code || '') +
27231:                         '</td>' +
27232:                         '<td class="p-2">' +
27233:                         _esc(row.start_date || '') +
27234:                         ' → ' +
27235:                         _esc(row.end_date || '') +
27236:                         '</td>' +
27237:                         '<td class="p-2 text-center">' +
27238:                         _fmtNum(row.employee_count) +
27239:                         '</td>' +
27240:                         '<td class="p-2 text-center">' +
27241:                         _fmtNum(row.gross_total) +
27242:                         '</td>' +
27243:                         '<td class="p-2 text-center">' +
27244:                         _fmtNum(row.deduction_total) +
27245:                         '</td>' +
27246:                         '<td class="p-2 text-center font-bold">' +
27247:                         _fmtNum(row.net_total) +
27248:                         '</td>' +
27249:                         '<td class="p-2">' +
27250:                         _esc(row.status || '') +
27251:                         '</td>' +
27252:                         '</tr>'
27253:                     );
27254:                 });
27255: 
27256:             html =
27257:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27258:                 '<div class="mb-4 text-xs text-gray-500">' +
27259:                 'المصدر: Production hr_query(payroll_runs)' +
27260:                 '</div>' +
27261:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27262:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27263:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27264:                 '<div class="text-lg font-black">' +
27265:                 _fmtNum(filteredPayrollRows.length) +
27266:                 '</div></div>' +
27267:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27268:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27269:                 '<div class="text-lg font-black">' +
27270:                 _fmtNum(payrollGrossTotal) +
27271:                 '</div></div>' +
27272:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27273:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27274:                 '<div class="text-lg font-black">' +
27275:                 _fmtNum(payrollDeductionTotal) +
27276:                 '</div></div>' +
27277:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27278:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
27279:                 '<div class="text-lg font-black">' +
27280:                 _fmtNum(payrollNetTotal) +
27281:                 '</div></div>' +
27282:                 '</div>' +
27283:                 '<div class="mb-4 text-xs text-gray-500">' +
27284:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
27285:                 _fmtNum(payrollEmployeeTotal) +
27286:                 '</div>' +
27287:                 _table(
27288:                     [
27289:                         'رقم المسير',
27290:                         'الفترة',
27291:                         'النطاق',
27292:                         'الموظفون',
27293:                         'إجمالي الأجور',
27294:                         'الاستقطاعات',
27295:                         'الصافي',
27296:                         'الحالة'
27297:                     ],
27298:                     payrollTableRows
27299:                 );
27300:         }
27301:         else {
27302: 
27303:             html =
27304:                 '<div class="text-center py-4 text-gray-500">' +
27305:                 'هذا التقرير غير متوفر بعد' +
27306:                 '</div>';
27307:         }
27308: 
27309:         safeHTML(
27310:     resultDiv,
27311:     html +
27312:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
27313:     '<span>المصدر: Production</span>' +
27314:     '<span>آخر تنفيذ: ' +
27315:     _esc(
27316:         new Date().toLocaleString('ar-EG')
27317:     ) +
27318:     '</span>' +
27319:     '</div>'
27320: );
27321: 
27322:     } catch (e) {
27323: 
27324:         console.error(
27325:             'RW_Reports_Comprehensive._generateReport',
27326:             e
27327:         );
27328: 
27329:         safeHTML(
27330:             resultDiv,
27331:             '<div class="text-center py-8 text-red-500">' +
27332:             'فشل تحميل التقرير: ' +
27333:             _esc(
27334:                 e.message ||
27335:                 'خطأ غير معروف'
27336:             ) +
27337:             '</div>'
27338:         );
27339:     }
27340: }
27341: 
27342: function _exportReportCsv() {
27343:     var resultDiv = byId('report-result');
27344: 
27345:     if (!resultDiv) {
27346:         _showToast('لا يوجد تقرير للتصدير', 'info');
27347:         return;
27348:     }
27349: 
27350:     var table = resultDiv.querySelector('table');
27351: 
27352:     if (!table) {
27353:         _showToast('لا يوجد جدول قابل للتصدير', 'info');
27354:         return;
27355:     }
27356: 
27357:     var rows = table.querySelectorAll('tr');
27358:     var csv = [];
27359: 
27360:     function csvCell(value) {
27361:         var s = String(value == null ? '' : value)
27362:             .replace(/\r?\n|\r/g, ' ')
27363:             .replace(/"/g, '""');
27364: 
27365:         return '"' + s + '"';
27366:     }
27367: 
27368:     for (var i = 0; i < rows.length; i++) {
27369:         var cells = rows[i].querySelectorAll('th,td');
27370:         var line = [];
27371: 
27372:         for (var j = 0; j < cells.length; j++) {
27373:             line.push(csvCell(cells[j].innerText || ''));
27374:         }
27375: 
27376:         csv.push(line.join(','));
27377:     }
27378: 
27379:     var blob = new Blob(
27380:         ['\uFEFF' + csv.join('\r\n')],
27381:         { type: 'text/csv;charset=utf-8;' }
27382:     );
27383: 
27384:     var url = URL.createObjectURL(blob);
27385:     var a = document.createElement('a');
27386: 
27387:     a.href = url;
27388:     a.download =
27389:         'rawaea-report-' +
27390:         String(_currentReport || 'report') +
27391:         '-' +
27392:         new Date().toISOString().slice(0, 10) +
27393:         '.csv';
27394: 
27395:     document.body.appendChild(a);
27396:     a.click();
27397:     document.body.removeChild(a);
27398: 
27399:     URL.revokeObjectURL(url);
27400: }
27401: function _printReport() {
27402:     var resultDiv = byId('report-result');
27403: 
27404:     if (!resultDiv || !resultDiv.innerHTML) {
27405:         _showToast('لا يوجد تقرير للطباعة', 'info');
27406:         return;
27407:     }
27408: 
27409:     var printWindow = window.open('', '_blank');
27410: 
27411:     if (!printWindow) {
27412:         _showToast('الرجاء السماح بالنوافذ المنبثقة', 'warning');
27413:         return;
27414:     }
27415: 
27416:     var html =
27417:         '<!DOCTYPE html>' +
27418:         '<html dir="rtl">' +
27419:         '<head>' +
27420:         '<meta charset="UTF-8">' +
27421:         '<title>تقرير الروائع ERP</title>' +
27422:         '<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700;900&display=swap" rel="stylesheet">' +
27423:         '<style>' +
27424:         'body{font-family:Cairo,sans-serif;padding:20px;color:#111827}' +
27425:         'table{width:100%;border-collapse:collapse;margin-top:15px}' +
27426:         'th,td{border:1px solid #ddd;padding:8px}' +
27427:         'th{background:#f2f2f2;font-weight:800}' +
27428:         '.text-center{text-align:center}' +
27429:         '</style>' +
27430:         '</head>' +
27431:         '<body>' +
27432:         resultDiv.innerHTML +
27433:         '<script>window.onload=function(){window.print();};<\/script>' +
27434:         '</body></html>';
27435: 
27436:     printWindow.document.open();
27437:     printWindow.document.write(html);
27438:     printWindow.document.close();
27439: }
--- WINDOW 28287-28497 around 28317 ---
28287:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
28288:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
28289:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
28290: 
28291:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
28292:     }
28293: };
28294: window.RW_Views = RW_Views;
28295: // ============================================================
28296: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
28297: // ============================================================
28298: var RW_HR = (function() {
28299:  'use strict';
28300:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
28301:   var T=[
28302:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
28303:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
28304:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
28305:   ];
28306:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
28307:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
28308:   function num(v){v=Number(v);return isFinite(v)?v:0}
28309:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
28310:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
28311:   function iso(v){return v?new Date(v).toISOString():null}
28312:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
28313:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
28314:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
28315:   function opClear(k){if(k)delete H.ops[k]}
28316:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
28317:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
28318:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
28319:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
28320:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
28321:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
28322:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
28323:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
28324:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
28325:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
28326:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
28327:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
28328:  function modal(title,body,onSubmit,key){
28329:   var old=E('rw-hr-modal-root');
28330:   if(old)old.remove();
28331:   var r=document.createElement('div');
28332:   r.id='rw-hr-modal-root';
28333:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
28334:   document.body.appendChild(r);
28335:   E('rw-hr-close').onclick=closeModal;
28336:   E('rw-hr-cancel').onclick=closeModal;
28337:   r.addEventListener('click',function(e){
28338:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28339:     if(ac){
28340:       e.preventDefault();
28341:       handle(ac.getAttribute('data-hr-action'));
28342:     }
28343:   });
28344:   if(onSubmit===null){
28345:     var f=E('rw-hr-form');
28346:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28347:   }else{
28348:     E('rw-hr-form').onsubmit=async function(e){
28349:       e.preventDefault();
28350:       var save=e.target.querySelector('button[type="submit"]');
28351:       try{
28352:         if(save){
28353:           save.disabled=true;
28354:           save.textContent='جارٍ الحفظ…';
28355:         }
28356:         await onSubmit(key||'form:'+Date.now());
28357:       }catch(err){
28358:         toast(err.message||'تعذر الحفظ','error');
28359:         if(save){
28360:           save.disabled=false;
28361:           save.textContent='حفظ';
28362:         }
28363:       }
28364:     };
28365:   }
28366: }
28367: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
28368:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
28369:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
28370:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
28371:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
28372:   function employeeOpts(){return ppl()}
28373:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28374:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
28375:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28376:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
28377:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
28378:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
28379:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
28380:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
28381:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
28382:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
28383:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
28384:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
28385:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
28386:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
28387:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
28388:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
28389:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
28390:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
28391:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
28392:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
28393:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
28394:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
28395:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
28396:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
28397:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
28398:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
28399:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
28400:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
28401:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
28402:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
28403:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
28404:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
28405:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
28406:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
28407:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
28408:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
28409:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
28410:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
28411:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
28412:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
28413:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
28414:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
28415:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
28416:   (function installModalResilience(){
28417:     document.addEventListener('click',function(e){
28418:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28419:       if(!ac)return;
28420:       var page=E('rw-page-container');
28421:       if(page&&page.contains(ac))return;
28422:       e.preventDefault();
28423:       handle(ac.getAttribute('data-hr-action'));
28424:     },true);
28425:     window.addEventListener('unhandledrejection',function(e){
28426:       var root=E('rw-hr-modal-root');
28427:       if(!root)return;
28428:       e.preventDefault();
28429:       var msg=e.reason&&(e.reason.message||String(e.reason));
28430:       if(msg)toast(msg,'error');
28431:     });
28432:     try{
28433:       var mo=new MutationObserver(function(){
28434:         var root=E('rw-hr-modal-root');
28435:         if(!root||!E('hr360'))return;
28436:         var f=E('rw-hr-form');
28437:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28438:       });
28439:       mo.observe(document.body,{childList:true,subtree:true});
28440:     }catch(e){}
28441:   }());
28442: 
28443: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
28444: 
28445: 
28446: // ============================================================
28447: // RW_CRM – إدارة علاقات العملاء (CRM)
28448: // ============================================================
28449: var RW_CRM = (function() {
28450:     'use strict';
28451: 
28452:     var state = {
28453:         customers: [],
28454:         assignees: [],
28455:         kpi: {},
28456:         search: '',
28457:         activeOnly: false,
28458:         searchTimer: null
28459:     };
28460: 
28461:     function _esc(s) {
28462:         return String(s == null ? '' : s)
28463:             .replace(/&/g, '&amp;')
28464:             .replace(/</g, '&lt;')
28465:             .replace(/>/g, '&gt;')
28466:             .replace(/"/g, '&quot;')
28467:             .replace(/'/g, '&#39;');
28468:     }
28469: 
28470:     function _fmtNum(n) {
28471:         return Number(n || 0).toLocaleString('ar-EG');
28472:     }
28473: 
28474:     function _fmtMoney(n) {
28475:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
28476:     }
28477: 
28478:     function _today() {
28479:         var d = new Date();
28480:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
28481:         return local.toISOString().slice(0, 10);
28482:     }
28483: 
28484:     function _statusLabel(s) {
28485:         var map = {
28486:             Open: 'مفتوحة',
28487:             'معلقة': 'معلقة',
28488:             completed: 'مكتملة',
28489:             'مكتملة': 'مكتملة',
28490:             cancelled: 'ملغاة',
28491:             'ملغاة': 'ملغاة'
28492:         };
28493:         return map[s] || s || 'غير محددة';
28494:     }
28495: 
28496:     function _statusClass(s) {
28497:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
--- WINDOW 28384-28594 around 28414 ---
28384:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
28385:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
28386:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
28387:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
28388:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
28389:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
28390:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
28391:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
28392:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
28393:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
28394:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
28395:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
28396:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
28397:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
28398:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
28399:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
28400:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
28401:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
28402:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
28403:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
28404:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
28405:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
28406:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
28407:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
28408:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
28409:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
28410:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
28411:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
28412:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
28413:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
28414:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
28415:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
28416:   (function installModalResilience(){
28417:     document.addEventListener('click',function(e){
28418:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28419:       if(!ac)return;
28420:       var page=E('rw-page-container');
28421:       if(page&&page.contains(ac))return;
28422:       e.preventDefault();
28423:       handle(ac.getAttribute('data-hr-action'));
28424:     },true);
28425:     window.addEventListener('unhandledrejection',function(e){
28426:       var root=E('rw-hr-modal-root');
28427:       if(!root)return;
28428:       e.preventDefault();
28429:       var msg=e.reason&&(e.reason.message||String(e.reason));
28430:       if(msg)toast(msg,'error');
28431:     });
28432:     try{
28433:       var mo=new MutationObserver(function(){
28434:         var root=E('rw-hr-modal-root');
28435:         if(!root||!E('hr360'))return;
28436:         var f=E('rw-hr-form');
28437:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28438:       });
28439:       mo.observe(document.body,{childList:true,subtree:true});
28440:     }catch(e){}
28441:   }());
28442: 
28443: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
28444: 
28445: 
28446: // ============================================================
28447: // RW_CRM – إدارة علاقات العملاء (CRM)
28448: // ============================================================
28449: var RW_CRM = (function() {
28450:     'use strict';
28451: 
28452:     var state = {
28453:         customers: [],
28454:         assignees: [],
28455:         kpi: {},
28456:         search: '',
28457:         activeOnly: false,
28458:         searchTimer: null
28459:     };
28460: 
28461:     function _esc(s) {
28462:         return String(s == null ? '' : s)
28463:             .replace(/&/g, '&amp;')
28464:             .replace(/</g, '&lt;')
28465:             .replace(/>/g, '&gt;')
28466:             .replace(/"/g, '&quot;')
28467:             .replace(/'/g, '&#39;');
28468:     }
28469: 
28470:     function _fmtNum(n) {
28471:         return Number(n || 0).toLocaleString('ar-EG');
28472:     }
28473: 
28474:     function _fmtMoney(n) {
28475:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
28476:     }
28477: 
28478:     function _today() {
28479:         var d = new Date();
28480:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
28481:         return local.toISOString().slice(0, 10);
28482:     }
28483: 
28484:     function _statusLabel(s) {
28485:         var map = {
28486:             Open: 'مفتوحة',
28487:             'معلقة': 'معلقة',
28488:             completed: 'مكتملة',
28489:             'مكتملة': 'مكتملة',
28490:             cancelled: 'ملغاة',
28491:             'ملغاة': 'ملغاة'
28492:         };
28493:         return map[s] || s || 'غير محددة';
28494:     }
28495: 
28496:     function _statusClass(s) {
28497:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
28498:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
28499:         return 'bg-amber-100 text-amber-700';
28500:     }
28501: 
28502:     function _assignedLabel(customer) {
28503:         var rows = Array.isArray(customer && customer.assigned_to) ? customer.assigned_to : [];
28504:         if (!rows.length) return 'غير مسند';
28505:         var active = rows.filter(function(x) { return x && x.active !== false; });
28506:         if (!active.length) active = rows;
28507:         return active.slice(0, 2).map(function(x) {
28508:             return x.name || x.email || '—';
28509:         }).join('، ') + (active.length > 2 ? ' +' + (active.length - 2) : '');
28510:     }
28511: 
28512:     async function _loadDirectory() {
28513:         var res = await supabase.rpc('crm_customer_directory', {
28514:             p_search: state.search || null,
28515:             p_active_only: state.activeOnly,
28516:             p_limit: 200,
28517:             p_offset: 0
28518:         });
28519:         if (res.error) throw res.error;
28520: 
28521:         var payload = res.data || {};
28522:         state.customers = Array.isArray(payload.customers) ? payload.customers : [];
28523:         state.assignees = Array.isArray(payload.assignees) ? payload.assignees : [];
28524:         state.kpi = payload.kpi || {};
28525:         return payload;
28526:     }
28527: 
28528:     function _renderKpis() {
28529:         var k = state.kpi || {};
28530:         return '<div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">' +
28531:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">إجمالي العملاء</div><div class="text-2xl font-black text-indigo-600 mt-2">' + _fmtNum(k.total_customers) + '</div></div>' +
28532:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">عملاء نشطون</div><div class="text-2xl font-black text-green-600 mt-2">' + _fmtNum(k.active_customers) + '</div></div>' +
28533:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">ذمم مسجلة</div><div class="text-2xl font-black text-red-600 mt-2">' + _fmtMoney(k.master_debt_total) + '</div></div>' +
28534:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متابعات مفتوحة</div><div class="text-2xl font-black text-amber-600 mt-2">' + _fmtNum(k.open_followups) + '</div></div>' +
28535:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متأخرة</div><div class="text-2xl font-black text-rose-600 mt-2">' + _fmtNum(k.overdue_followups) + '</div></div>' +
28536:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">مستحقة اليوم</div><div class="text-2xl font-black text-blue-600 mt-2">' + _fmtNum(k.due_today) + '</div></div>' +
28537:         '</div>';
28538:     }
28539: 
28540:     function _renderTable() {
28541:         if (!state.customers.length) {
28542:             return '<div class="text-center py-16 text-gray-400"><div class="text-5xl mb-3">👥</div><div class="font-black text-lg">لا توجد عملاء مطابقون</div><div class="text-sm mt-2">غيّر البحث أو الفلاتر ثم أعد المحاولة.</div></div>';
28543:         }
28544: 
28545:         var html = '<div class="overflow-x-auto"><table class="w-full text-sm">' +
28546:             '<thead class="bg-slate-50"><tr>' +
28547:             '<th class="p-3 text-right">العميل</th>' +
28548:             '<th class="p-3 text-right">التواصل</th>' +
28549:             '<th class="p-3 text-right">التصنيف</th>' +
28550:             '<th class="p-3 text-center">المبيعات</th>' +
28551:             '<th class="p-3 text-center">الأوردرات</th>' +
28552:             '<th class="p-3 text-center">المتابعة القادمة</th>' +
28553:             '<th class="p-3 text-right">المسؤول</th>' +
28554:             '<th class="p-3 text-center">الإجراء</th>' +
28555:             '</tr></thead><tbody>';
28556: 
28557:         for (var i = 0; i < state.customers.length; i++) {
28558:             var c = state.customers[i] || {};
28559:             var overdue = Number(c.overdue_followups || 0) > 0;
28560:             var next = c.next_followup_date ? String(c.next_followup_date) : '—';
28561: 
28562:             html += '<tr class="border-b hover:bg-slate-50">' +
28563:                 '<td class="p-3"><div class="font-black">' + _esc(c.name) + '</div><div class="text-xs text-gray-400">' + _esc(c.customer_code) + '</div></td>' +
28564:                 '<td class="p-3"><div>' + _esc(c.phone || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.area || '—') + '</div></td>' +
28565:                 '<td class="p-3"><div class="font-bold">' + _esc(c.customer_type || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.payment_type || '—') + '</div></td>' +
28566:                 '<td class="p-3 text-center font-black">' + _fmtMoney(c.sales_total) + '</td>' +
28567:                 '<td class="p-3 text-center font-black">' + _fmtNum(c.order_count) + '</td>' +
28568:                 '<td class="p-3 text-center"><span class="px-2 py-1 rounded-full text-xs font-black ' + (overdue ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-700') + '">' + _esc(next) + '</span></td>' +
28569:                 '<td class="p-3">' + _esc(_assignedLabel(c)) + '</td>' +
28570:                 '<td class="p-3 text-center"><button type="button" data-crm-open360="' + _esc(c.id) + '" class="px-4 py-2 bg-indigo-600 text-white rounded-xl font-black">متابعة</button></td>' +
28571:             '</tr>';
28572:         }
28573: 
28574:         return html + '</tbody></table></div>';
28575:     }
28576: 
28577:     function _bindDirectory() {
28578:         var search = byId('crm-search');
28579:         if (search) {
28580:             search.value = state.search;
28581:             search.addEventListener('input', function() {
28582:                 state.search = search.value.trim();
28583:                 clearTimeout(state.searchTimer);
28584:                 state.searchTimer = setTimeout(function() {
28585:                     _loadDirectory().then(function() {
28586:                         safeHTML(byId('crm-customers-list'), _renderTable());
28587:                         _bindOpen360();
28588:                         safeHTML(byId('crm-kpis'), _renderKpis());
28589:                     }).catch(function(e) {
28590:                         showToast(e.message || 'فشل البحث', 'error');
28591:                     });
28592:                 }, 250);
28593:             });
28594:         }
--- RW_HR_FULL 28298-28443 ---
28298: var RW_HR = (function() {
28299:  'use strict';
28300:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
28301:   var T=[
28302:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
28303:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
28304:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
28305:   ];
28306:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
28307:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
28308:   function num(v){v=Number(v);return isFinite(v)?v:0}
28309:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
28310:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
28311:   function iso(v){return v?new Date(v).toISOString():null}
28312:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
28313:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
28314:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
28315:   function opClear(k){if(k)delete H.ops[k]}
28316:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
28317:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
28318:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
28319:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
28320:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
28321:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
28322:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
28323:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
28324:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
28325:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
28326:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
28327:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
28328:  function modal(title,body,onSubmit,key){
28329:   var old=E('rw-hr-modal-root');
28330:   if(old)old.remove();
28331:   var r=document.createElement('div');
28332:   r.id='rw-hr-modal-root';
28333:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
28334:   document.body.appendChild(r);
28335:   E('rw-hr-close').onclick=closeModal;
28336:   E('rw-hr-cancel').onclick=closeModal;
28337:   r.addEventListener('click',function(e){
28338:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28339:     if(ac){
28340:       e.preventDefault();
28341:       handle(ac.getAttribute('data-hr-action'));
28342:     }
28343:   });
28344:   if(onSubmit===null){
28345:     var f=E('rw-hr-form');
28346:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28347:   }else{
28348:     E('rw-hr-form').onsubmit=async function(e){
28349:       e.preventDefault();
28350:       var save=e.target.querySelector('button[type="submit"]');
28351:       try{
28352:         if(save){
28353:           save.disabled=true;
28354:           save.textContent='جارٍ الحفظ…';
28355:         }
28356:         await onSubmit(key||'form:'+Date.now());
28357:       }catch(err){
28358:         toast(err.message||'تعذر الحفظ','error');
28359:         if(save){
28360:           save.disabled=false;
28361:           save.textContent='حفظ';
28362:         }
28363:       }
28364:     };
28365:   }
28366: }
28367: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
28368:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
28369:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
28370:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
28371:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
28372:   function employeeOpts(){return ppl()}
28373:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28374:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
28375:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
28376:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
28377:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
28378:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
28379:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
28380:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
28381:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
28382:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
28383:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
28384:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
28385:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
28386:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
28387:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
28388:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
28389:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
28390:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
28391:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
28392:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
28393:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
28394:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
28395:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
28396:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
28397:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
28398:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
28399:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
28400:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
28401:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
28402:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
28403:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
28404:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
28405:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
28406:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
28407:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
28408:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
28409:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
28410:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
28411:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
28412:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
28413:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
28414:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
28415:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
28416:   (function installModalResilience(){
28417:     document.addEventListener('click',function(e){
28418:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
28419:       if(!ac)return;
28420:       var page=E('rw-page-container');
28421:       if(page&&page.contains(ac))return;
28422:       e.preventDefault();
28423:       handle(ac.getAttribute('data-hr-action'));
28424:     },true);
28425:     window.addEventListener('unhandledrejection',function(e){
28426:       var root=E('rw-hr-modal-root');
28427:       if(!root)return;
28428:       e.preventDefault();
28429:       var msg=e.reason&&(e.reason.message||String(e.reason));
28430:       if(msg)toast(msg,'error');
28431:     });
28432:     try{
28433:       var mo=new MutationObserver(function(){
28434:         var root=E('rw-hr-modal-root');
28435:         if(!root||!E('hr360'))return;
28436:         var f=E('rw-hr-form');
28437:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
28438:       });
28439:       mo.observe(document.body,{childList:true,subtree:true});
28440:     }catch(e){}
28441:   }());
28442: 
28443: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
