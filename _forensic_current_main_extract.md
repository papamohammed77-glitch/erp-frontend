# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=33524
FILE_BYTES=1916431
SHA256=ddef5312159de4ee4c217d68531161f300e390be18ddd3889c17cea1b854d33e
PATTERN var RW_Warehouse: [14507]
PATTERN var RW_HR: [31476]
PATTERN RW_HR: [31428, 31474, 31476, 31592, 31621]
PATTERN hr_list_employees: []
PATTERN hr_command_atomic: [31496]
PATTERN hr_query: [28704, 28807, 28851, 28972, 31495]
PATTERN hr_payroll_calculate_impl: []
PATTERN hr_payroll_post_impl: []
PATTERN employee_documents: [31592]
PATTERN hr_departments: [31592]
PATTERN hr_contracts: [31592]
PATTERN hr_work_schedules: [31592]
PATTERN hr_attendance_events: [31592]
PATTERN hr_leave_types: [31592]
PATTERN hr_requests: [31592]
PATTERN hr_salary_advances: [31592]
PATTERN hr_payroll_periods: [31592]
PATTERN hr_payslips: [31592]
PATTERN hr_command: [31496]
PATTERN employee-document: [23205, 31588, 31589]
PATTERN document-upload: []
PATTERN الموارد البشرية: [1574, 7941, 9272, 25167, 25199, 31414, 31474, 31590]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 31446-31656 around 31476 ---
31446:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
31447:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
31448: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
31449: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
31450: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
31451: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
31452:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
31453:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
31454:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
31455:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
31456:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
31457:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
31458:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
31459:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
31460:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
31461:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
31462:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
31463:         if (view === 'finance') { RW_Finance.render(); return; }
31464:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
31465:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
31466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
31467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
31468: 
31469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
31470:     }
31471: };
31472: window.RW_Views = RW_Views;
31473: // ============================================================
31474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
31475: // ============================================================
31476: var RW_HR = (function() {
31477:  'use strict';
31478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
31479:   var T=[
31480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
31481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
31482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
31483:   ];
31484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
31485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
31486:   function num(v){v=Number(v);return isFinite(v)?v:0}
31487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
31488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
31489:   function iso(v){return v?new Date(v).toISOString():null}
31490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
31491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
31492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
31493:   function opClear(k){if(k)delete H.ops[k]}
31494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
31495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
31496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
31497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
31498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
31499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
31500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
31501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
31502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
31503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
31504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
31505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
31506:  function modal(title,body,onSubmit,key){
31507:   var old=E('rw-hr-modal-root');
31508:   if(old)old.remove();
31509:   var r=document.createElement('div');
31510:   r.id='rw-hr-modal-root';
31511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
31512:   document.body.appendChild(r);
31513:   E('rw-hr-close').onclick=closeModal;
31514:   E('rw-hr-cancel').onclick=closeModal;
31515:   r.addEventListener('click',function(e){
31516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31517:     if(ac){
31518:       e.preventDefault();
31519:       handle(ac.getAttribute('data-hr-action'));
31520:     }
31521:   });
31522:   if(onSubmit===null){
31523:     var f=E('rw-hr-form');
31524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31525:   }else{
31526:     E('rw-hr-form').onsubmit=async function(e){
31527:       e.preventDefault();
31528:       var save=e.target.querySelector('button[type="submit"]');
31529:       try{
31530:         if(save){
31531:           save.disabled=true;
31532:           save.textContent='جارٍ الحفظ…';
31533:         }
31534:         await onSubmit(key||'form:'+Date.now());
31535:       }catch(err){
31536:         toast(err.message||'تعذر الحفظ','error');
31537:         if(save){
31538:           save.disabled=false;
31539:           save.textContent='حفظ';
31540:         }
31541:       }
31542:     };
31543:   }
31544: }
31545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
31546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
31547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
31548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
31549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
31550:   function employeeOpts(){return ppl()}
31551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
31553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
31555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
31556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
31557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
31558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
31559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
31560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
31561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
31562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
31563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
31564:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
31565:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
31566:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
31567:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
31568:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
31569:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
31570:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
31571:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
31572:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
31573:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
31574:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
31575:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
31576:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
31577:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
31578:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
31579:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
31580:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
31581:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
31582:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
31583:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
31584:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
31585:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
31586:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
31587:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
31588:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
31589:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
31590:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
31591:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
31592:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
31593:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
31594:   (function installModalResilience(){
31595:     document.addEventListener('click',function(e){
31596:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31597:       if(!ac)return;
31598:       var page=E('rw-page-container');
31599:       if(page&&page.contains(ac))return;
31600:       e.preventDefault();
31601:       handle(ac.getAttribute('data-hr-action'));
31602:     },true);
31603:     window.addEventListener('unhandledrejection',function(e){
31604:       var root=E('rw-hr-modal-root');
31605:       if(!root)return;
31606:       e.preventDefault();
31607:       var msg=e.reason&&(e.reason.message||String(e.reason));
31608:       if(msg)toast(msg,'error');
31609:     });
31610:     try{
31611:       var mo=new MutationObserver(function(){
31612:         var root=E('rw-hr-modal-root');
31613:         if(!root||!E('hr360'))return;
31614:         var f=E('rw-hr-form');
31615:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31616:       });
31617:       mo.observe(document.body,{childList:true,subtree:true});
31618:     }catch(e){}
31619:   }());
31620: 
31621: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
31622: 
31623: 
31624: // ============================================================
31625: // RW_CRM – إدارة علاقات العملاء (CRM)
31626: // ============================================================
31627: var RW_CRM = (function() {
31628:     'use strict';
31629: 
31630:     var state = {
31631:         customers: [],
31632:         assignees: [],
31633:         kpi: {},
31634:         search: '',
31635:         activeOnly: false,
31636:         searchTimer: null
31637:     };
31638: 
31639:     function _esc(s) {
31640:         return String(s == null ? '' : s)
31641:             .replace(/&/g, '&amp;')
31642:             .replace(/</g, '&lt;')
31643:             .replace(/>/g, '&gt;')
31644:             .replace(/"/g, '&quot;')
31645:             .replace(/'/g, '&#39;');
31646:     }
31647: 
31648:     function _fmtNum(n) {
31649:         return Number(n || 0).toLocaleString('ar-EG');
31650:     }
31651: 
31652:     function _fmtMoney(n) {
31653:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
31654:     }
31655: 
31656:     function _today() {
--- WINDOW 31466-31676 around 31496 ---
31466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
31467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
31468: 
31469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
31470:     }
31471: };
31472: window.RW_Views = RW_Views;
31473: // ============================================================
31474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
31475: // ============================================================
31476: var RW_HR = (function() {
31477:  'use strict';
31478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
31479:   var T=[
31480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
31481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
31482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
31483:   ];
31484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
31485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
31486:   function num(v){v=Number(v);return isFinite(v)?v:0}
31487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
31488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
31489:   function iso(v){return v?new Date(v).toISOString():null}
31490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
31491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
31492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
31493:   function opClear(k){if(k)delete H.ops[k]}
31494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
31495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
31496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
31497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
31498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
31499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
31500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
31501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
31502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
31503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
31504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
31505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
31506:  function modal(title,body,onSubmit,key){
31507:   var old=E('rw-hr-modal-root');
31508:   if(old)old.remove();
31509:   var r=document.createElement('div');
31510:   r.id='rw-hr-modal-root';
31511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
31512:   document.body.appendChild(r);
31513:   E('rw-hr-close').onclick=closeModal;
31514:   E('rw-hr-cancel').onclick=closeModal;
31515:   r.addEventListener('click',function(e){
31516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31517:     if(ac){
31518:       e.preventDefault();
31519:       handle(ac.getAttribute('data-hr-action'));
31520:     }
31521:   });
31522:   if(onSubmit===null){
31523:     var f=E('rw-hr-form');
31524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31525:   }else{
31526:     E('rw-hr-form').onsubmit=async function(e){
31527:       e.preventDefault();
31528:       var save=e.target.querySelector('button[type="submit"]');
31529:       try{
31530:         if(save){
31531:           save.disabled=true;
31532:           save.textContent='جارٍ الحفظ…';
31533:         }
31534:         await onSubmit(key||'form:'+Date.now());
31535:       }catch(err){
31536:         toast(err.message||'تعذر الحفظ','error');
31537:         if(save){
31538:           save.disabled=false;
31539:           save.textContent='حفظ';
31540:         }
31541:       }
31542:     };
31543:   }
31544: }
31545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
31546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
31547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
31548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
31549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
31550:   function employeeOpts(){return ppl()}
31551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
31553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
31555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
31556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
31557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
31558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
31559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
31560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
31561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
31562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
31563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
31564:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
31565:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
31566:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
31567:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
31568:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
31569:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
31570:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
31571:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
31572:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
31573:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
31574:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
31575:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
31576:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
31577:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
31578:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
31579:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
31580:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
31581:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
31582:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
31583:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
31584:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
31585:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
31586:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
31587:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
31588:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
31589:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
31590:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
31591:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
31592:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
31593:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
31594:   (function installModalResilience(){
31595:     document.addEventListener('click',function(e){
31596:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31597:       if(!ac)return;
31598:       var page=E('rw-page-container');
31599:       if(page&&page.contains(ac))return;
31600:       e.preventDefault();
31601:       handle(ac.getAttribute('data-hr-action'));
31602:     },true);
31603:     window.addEventListener('unhandledrejection',function(e){
31604:       var root=E('rw-hr-modal-root');
31605:       if(!root)return;
31606:       e.preventDefault();
31607:       var msg=e.reason&&(e.reason.message||String(e.reason));
31608:       if(msg)toast(msg,'error');
31609:     });
31610:     try{
31611:       var mo=new MutationObserver(function(){
31612:         var root=E('rw-hr-modal-root');
31613:         if(!root||!E('hr360'))return;
31614:         var f=E('rw-hr-form');
31615:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31616:       });
31617:       mo.observe(document.body,{childList:true,subtree:true});
31618:     }catch(e){}
31619:   }());
31620: 
31621: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
31622: 
31623: 
31624: // ============================================================
31625: // RW_CRM – إدارة علاقات العملاء (CRM)
31626: // ============================================================
31627: var RW_CRM = (function() {
31628:     'use strict';
31629: 
31630:     var state = {
31631:         customers: [],
31632:         assignees: [],
31633:         kpi: {},
31634:         search: '',
31635:         activeOnly: false,
31636:         searchTimer: null
31637:     };
31638: 
31639:     function _esc(s) {
31640:         return String(s == null ? '' : s)
31641:             .replace(/&/g, '&amp;')
31642:             .replace(/</g, '&lt;')
31643:             .replace(/>/g, '&gt;')
31644:             .replace(/"/g, '&quot;')
31645:             .replace(/'/g, '&#39;');
31646:     }
31647: 
31648:     function _fmtNum(n) {
31649:         return Number(n || 0).toLocaleString('ar-EG');
31650:     }
31651: 
31652:     function _fmtMoney(n) {
31653:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
31654:     }
31655: 
31656:     function _today() {
31657:         var d = new Date();
31658:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
31659:         return local.toISOString().slice(0, 10);
31660:     }
31661: 
31662:     function _statusLabel(s) {
31663:         var map = {
31664:             Open: 'مفتوحة',
31665:             'معلقة': 'معلقة',
31666:             completed: 'مكتملة',
31667:             'مكتملة': 'مكتملة',
31668:             cancelled: 'ملغاة',
31669:             'ملغاة': 'ملغاة'
31670:         };
31671:         return map[s] || s || 'غير محددة';
31672:     }
31673: 
31674:     function _statusClass(s) {
31675:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
31676:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
--- WINDOW 28674-28884 around 28704 ---
28674:                         '<td class="p-2">' +
28675:                         _esc(row.email) +
28676:                         '</td>' +
28677:                         '<td class="p-2">' +
28678:                         _esc(row.role) +
28679:                         '</td>' +
28680:                         '<td class="p-2">' +
28681:                         _esc(row.status) +
28682:                         '</td>' +
28683:                         '</tr>'
28684:                     );
28685:                 });
28686: 
28687:             html =
28688:                 '<h4 class="font-bold mb-3">قائمة الموظفين</h4>' +
28689:                 _table(
28690:                     [
28691:                         'الاسم',
28692:                         'البريد',
28693:                         'الدور',
28694:                         'الحالة'
28695:                     ],
28696:                     rows28
28697:                 );
28698:         }
28699: 
28700:         else if (reportId === 'hr-attendance') {
28701: 
28702:             var hrAttendanceReport =
28703:                 await supabase.rpc(
28704:                     'hr_query',
28705:                     {
28706:                         p_view: 'attendance',
28707:                         p_payload: {
28708:                             from: fromDate,
28709:                             to: toDate,
28710:                             limit: 5000
28711:                         }
28712:                     }
28713:                 );
28714: 
28715:             if (hrAttendanceReport.error) {
28716:                 throw hrAttendanceReport.error;
28717:             }
28718: 
28719:             var hrAttendancePayload =
28720:                 hrAttendanceReport.data || {};
28721: 
28722:             if (hrAttendancePayload.success === false) {
28723:                 throw new Error(
28724:                     hrAttendancePayload.msg ||
28725:                     hrAttendancePayload.code ||
28726:                     'لا توجد صلاحية أو مصدر صالح لتقرير الحضور'
28727:                 );
28728:             }
28729: 
28730:             var hrAttendanceRows =
28731:                 Array.isArray(hrAttendancePayload.rows)
28732:                     ? hrAttendancePayload.rows
28733:                     : [];
28734: 
28735:             var attendanceWorkedHours = 0;
28736:             var attendanceLateMinutes = 0;
28737:             var attendanceOvertimeHours = 0;
28738: 
28739:             var hrAttendanceTableRows =
28740:                 hrAttendanceRows.map(function(row) {
28741: 
28742:                     attendanceWorkedHours +=
28743:                         Number(row.worked_hours) || 0;
28744: 
28745:                     attendanceLateMinutes +=
28746:                         Number(row.late_minutes) || 0;
28747: 
28748:                     attendanceOvertimeHours +=
28749:                         Number(row.overtime_hours) || 0;
28750: 
28751:                     return (
28752:                         '<tr class="border-t">' +
28753:                         '<td class="p-2">' +
28754:                         _esc(row.attendance_date) +
28755:                         '</td>' +
28756:                         '<td class="p-2 font-semibold">' +
28757:                         _esc(row.employee_name || row.email || '') +
28758:                         '</td>' +
28759:                         '<td class="p-2">' +
28760:                         _esc(row.status || '') +
28761:                         '</td>' +
28762:                         '<td class="p-2 text-center">' +
28763:                         _esc(
28764:                             row.check_in
28765:                                 ? new Date(row.check_in).toLocaleTimeString(
28766:                                     'ar-EG',
28767:                                     {
28768:                                         hour: '2-digit',
28769:                                         minute: '2-digit'
28770:                                     }
28771:                                   )
28772:                                 : '-'
28773:                         ) +
28774:                         '</td>' +
28775:                         '<td class="p-2 text-center">' +
28776:                         _esc(
28777:                             row.check_out
28778:                                 ? new Date(row.check_out).toLocaleTimeString(
28779:                                     'ar-EG',
28780:                                     {
28781:                                         hour: '2-digit',
28782:                                         minute: '2-digit'
28783:                                     }
28784:                                   )
28785:                                 : '-'
28786:                         ) +
28787:                         '</td>' +
28788:                         '<td class="p-2 text-center font-bold">' +
28789:                         _fmtNum(row.worked_hours) +
28790:                         '</td>' +
28791:                         '<td class="p-2 text-center">' +
28792:                         _fmtNum(row.late_minutes) +
28793:                         '</td>' +
28794:                         '<td class="p-2 text-center">' +
28795:                         _fmtNum(row.overtime_hours) +
28796:                         '</td>' +
28797:                         '<td class="p-2 text-center">' +
28798:                         _fmtNum(row.absence_minutes) +
28799:                         '</td>' +
28800:                         '</tr>'
28801:                     );
28802:                 });
28803: 
28804:             html =
28805:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
28806:                 '<div class="mb-4 text-xs text-gray-500">' +
28807:                 'المصدر: Production hr_query(attendance)' +
28808:                 '</div>' +
28809:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
28810:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
28811:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
28812:                 '<div class="text-lg font-black">' +
28813:                 _fmtNum(hrAttendanceRows.length) +
28814:                 '</div></div>' +
28815:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
28816:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
28817:                 '<div class="text-lg font-black">' +
28818:                 _fmtNum(attendanceWorkedHours) +
28819:                 '</div></div>' +
28820:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
28821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
28822:                 '<div class="text-lg font-black">' +
28823:                 _fmtNum(attendanceLateMinutes) +
28824:                 '</div></div>' +
28825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
28826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
28827:                 '<div class="text-lg font-black">' +
28828:                 _fmtNum(attendanceOvertimeHours) +
28829:                 '</div></div>' +
28830:                 '</div>' +
28831:                 _table(
28832:                     [
28833:                         'التاريخ',
28834:                         'الموظف',
28835:                         'الحالة',
28836:                         'الدخول',
28837:                         'الخروج',
28838:                         'ساعات العمل',
28839:                         'التأخير بالدقائق',
28840:                         'الساعات الإضافية',
28841:                         'دقائق الغياب'
28842:                     ],
28843:                     hrAttendanceTableRows
28844:                 );
28845:         }
28846: 
28847:         else if (reportId === 'hr-salary') {
28848: 
28849:             var hrPayrollReport =
28850:                 await supabase.rpc(
28851:                     'hr_query',
28852:                     {
28853:                         p_view: 'payroll_runs',
28854:                         p_payload: {}
28855:                     }
28856:                 );
28857: 
28858:             if (hrPayrollReport.error) {
28859:                 throw hrPayrollReport.error;
28860:             }
28861: 
28862:             var hrPayrollPayload =
28863:                 hrPayrollReport.data || {};
28864: 
28865:             if (hrPayrollPayload.success === false) {
28866:                 throw new Error(
28867:                     hrPayrollPayload.msg ||
28868:                     hrPayrollPayload.code ||
28869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
28870:                 );
28871:             }
28872: 
28873:             var hrPayrollRows =
28874:                 Array.isArray(hrPayrollPayload.rows)
28875:                     ? hrPayrollPayload.rows
28876:                     : [];
28877: 
28878:             var filteredPayrollRows = [];
28879: 
28880:             var payrollGrossTotal = 0;
28881:             var payrollDeductionTotal = 0;
28882:             var payrollNetTotal = 0;
28883:             var payrollEmployeeTotal = 0;
28884: 
--- WINDOW 28777-28987 around 28807 ---
28777:                             row.check_out
28778:                                 ? new Date(row.check_out).toLocaleTimeString(
28779:                                     'ar-EG',
28780:                                     {
28781:                                         hour: '2-digit',
28782:                                         minute: '2-digit'
28783:                                     }
28784:                                   )
28785:                                 : '-'
28786:                         ) +
28787:                         '</td>' +
28788:                         '<td class="p-2 text-center font-bold">' +
28789:                         _fmtNum(row.worked_hours) +
28790:                         '</td>' +
28791:                         '<td class="p-2 text-center">' +
28792:                         _fmtNum(row.late_minutes) +
28793:                         '</td>' +
28794:                         '<td class="p-2 text-center">' +
28795:                         _fmtNum(row.overtime_hours) +
28796:                         '</td>' +
28797:                         '<td class="p-2 text-center">' +
28798:                         _fmtNum(row.absence_minutes) +
28799:                         '</td>' +
28800:                         '</tr>'
28801:                     );
28802:                 });
28803: 
28804:             html =
28805:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
28806:                 '<div class="mb-4 text-xs text-gray-500">' +
28807:                 'المصدر: Production hr_query(attendance)' +
28808:                 '</div>' +
28809:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
28810:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
28811:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
28812:                 '<div class="text-lg font-black">' +
28813:                 _fmtNum(hrAttendanceRows.length) +
28814:                 '</div></div>' +
28815:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
28816:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
28817:                 '<div class="text-lg font-black">' +
28818:                 _fmtNum(attendanceWorkedHours) +
28819:                 '</div></div>' +
28820:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
28821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
28822:                 '<div class="text-lg font-black">' +
28823:                 _fmtNum(attendanceLateMinutes) +
28824:                 '</div></div>' +
28825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
28826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
28827:                 '<div class="text-lg font-black">' +
28828:                 _fmtNum(attendanceOvertimeHours) +
28829:                 '</div></div>' +
28830:                 '</div>' +
28831:                 _table(
28832:                     [
28833:                         'التاريخ',
28834:                         'الموظف',
28835:                         'الحالة',
28836:                         'الدخول',
28837:                         'الخروج',
28838:                         'ساعات العمل',
28839:                         'التأخير بالدقائق',
28840:                         'الساعات الإضافية',
28841:                         'دقائق الغياب'
28842:                     ],
28843:                     hrAttendanceTableRows
28844:                 );
28845:         }
28846: 
28847:         else if (reportId === 'hr-salary') {
28848: 
28849:             var hrPayrollReport =
28850:                 await supabase.rpc(
28851:                     'hr_query',
28852:                     {
28853:                         p_view: 'payroll_runs',
28854:                         p_payload: {}
28855:                     }
28856:                 );
28857: 
28858:             if (hrPayrollReport.error) {
28859:                 throw hrPayrollReport.error;
28860:             }
28861: 
28862:             var hrPayrollPayload =
28863:                 hrPayrollReport.data || {};
28864: 
28865:             if (hrPayrollPayload.success === false) {
28866:                 throw new Error(
28867:                     hrPayrollPayload.msg ||
28868:                     hrPayrollPayload.code ||
28869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
28870:                 );
28871:             }
28872: 
28873:             var hrPayrollRows =
28874:                 Array.isArray(hrPayrollPayload.rows)
28875:                     ? hrPayrollPayload.rows
28876:                     : [];
28877: 
28878:             var filteredPayrollRows = [];
28879: 
28880:             var payrollGrossTotal = 0;
28881:             var payrollDeductionTotal = 0;
28882:             var payrollNetTotal = 0;
28883:             var payrollEmployeeTotal = 0;
28884: 
28885:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
28886: 
28887:                 var payrollRow = hrPayrollRows[pr] || {};
28888: 
28889:                 var periodStart =
28890:                     String(
28891:                         payrollRow.start_date ||
28892:                         ''
28893:                     ).slice(0, 10);
28894: 
28895:                 var periodEnd =
28896:                     String(
28897:                         payrollRow.end_date ||
28898:                         ''
28899:                     ).slice(0, 10);
28900: 
28901:                 if (
28902:                     periodStart &&
28903:                     periodEnd &&
28904:                     periodEnd < fromDate
28905:                 ) {
28906:                     continue;
28907:                 }
28908: 
28909:                 if (
28910:                     periodStart &&
28911:                     periodEnd &&
28912:                     periodStart > toDate
28913:                 ) {
28914:                     continue;
28915:                 }
28916: 
28917:                 filteredPayrollRows.push(
28918:                     payrollRow
28919:                 );
28920: 
28921:                 payrollGrossTotal +=
28922:                     Number(payrollRow.gross_total) || 0;
28923: 
28924:                 payrollDeductionTotal +=
28925:                     Number(payrollRow.deduction_total) || 0;
28926: 
28927:                 payrollNetTotal +=
28928:                     Number(payrollRow.net_total) || 0;
28929: 
28930:                 payrollEmployeeTotal +=
28931:                     Number(payrollRow.employee_count) || 0;
28932:             }
28933: 
28934:             var payrollTableRows =
28935:                 filteredPayrollRows.map(function(row) {
28936: 
28937:                     return (
28938:                         '<tr class="border-t">' +
28939:                         '<td class="p-2">' +
28940:                         _esc(row.run_no || '') +
28941:                         '</td>' +
28942:                         '<td class="p-2 font-semibold">' +
28943:                         _esc(row.period_code || '') +
28944:                         '</td>' +
28945:                         '<td class="p-2">' +
28946:                         _esc(row.start_date || '') +
28947:                         ' → ' +
28948:                         _esc(row.end_date || '') +
28949:                         '</td>' +
28950:                         '<td class="p-2 text-center">' +
28951:                         _fmtNum(row.employee_count) +
28952:                         '</td>' +
28953:                         '<td class="p-2 text-center">' +
28954:                         _fmtNum(row.gross_total) +
28955:                         '</td>' +
28956:                         '<td class="p-2 text-center">' +
28957:                         _fmtNum(row.deduction_total) +
28958:                         '</td>' +
28959:                         '<td class="p-2 text-center font-bold">' +
28960:                         _fmtNum(row.net_total) +
28961:                         '</td>' +
28962:                         '<td class="p-2">' +
28963:                         _esc(row.status || '') +
28964:                         '</td>' +
28965:                         '</tr>'
28966:                     );
28967:                 });
28968: 
28969:             html =
28970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
28971:                 '<div class="mb-4 text-xs text-gray-500">' +
28972:                 'المصدر: Production hr_query(payroll_runs)' +
28973:                 '</div>' +
28974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
28975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
28976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
28977:                 '<div class="text-lg font-black">' +
28978:                 _fmtNum(filteredPayrollRows.length) +
28979:                 '</div></div>' +
28980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
28981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
28982:                 '<div class="text-lg font-black">' +
28983:                 _fmtNum(payrollGrossTotal) +
28984:                 '</div></div>' +
28985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
28986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
28987:                 '<div class="text-lg font-black">' +
--- WINDOW 28821-29031 around 28851 ---
28821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
28822:                 '<div class="text-lg font-black">' +
28823:                 _fmtNum(attendanceLateMinutes) +
28824:                 '</div></div>' +
28825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
28826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
28827:                 '<div class="text-lg font-black">' +
28828:                 _fmtNum(attendanceOvertimeHours) +
28829:                 '</div></div>' +
28830:                 '</div>' +
28831:                 _table(
28832:                     [
28833:                         'التاريخ',
28834:                         'الموظف',
28835:                         'الحالة',
28836:                         'الدخول',
28837:                         'الخروج',
28838:                         'ساعات العمل',
28839:                         'التأخير بالدقائق',
28840:                         'الساعات الإضافية',
28841:                         'دقائق الغياب'
28842:                     ],
28843:                     hrAttendanceTableRows
28844:                 );
28845:         }
28846: 
28847:         else if (reportId === 'hr-salary') {
28848: 
28849:             var hrPayrollReport =
28850:                 await supabase.rpc(
28851:                     'hr_query',
28852:                     {
28853:                         p_view: 'payroll_runs',
28854:                         p_payload: {}
28855:                     }
28856:                 );
28857: 
28858:             if (hrPayrollReport.error) {
28859:                 throw hrPayrollReport.error;
28860:             }
28861: 
28862:             var hrPayrollPayload =
28863:                 hrPayrollReport.data || {};
28864: 
28865:             if (hrPayrollPayload.success === false) {
28866:                 throw new Error(
28867:                     hrPayrollPayload.msg ||
28868:                     hrPayrollPayload.code ||
28869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
28870:                 );
28871:             }
28872: 
28873:             var hrPayrollRows =
28874:                 Array.isArray(hrPayrollPayload.rows)
28875:                     ? hrPayrollPayload.rows
28876:                     : [];
28877: 
28878:             var filteredPayrollRows = [];
28879: 
28880:             var payrollGrossTotal = 0;
28881:             var payrollDeductionTotal = 0;
28882:             var payrollNetTotal = 0;
28883:             var payrollEmployeeTotal = 0;
28884: 
28885:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
28886: 
28887:                 var payrollRow = hrPayrollRows[pr] || {};
28888: 
28889:                 var periodStart =
28890:                     String(
28891:                         payrollRow.start_date ||
28892:                         ''
28893:                     ).slice(0, 10);
28894: 
28895:                 var periodEnd =
28896:                     String(
28897:                         payrollRow.end_date ||
28898:                         ''
28899:                     ).slice(0, 10);
28900: 
28901:                 if (
28902:                     periodStart &&
28903:                     periodEnd &&
28904:                     periodEnd < fromDate
28905:                 ) {
28906:                     continue;
28907:                 }
28908: 
28909:                 if (
28910:                     periodStart &&
28911:                     periodEnd &&
28912:                     periodStart > toDate
28913:                 ) {
28914:                     continue;
28915:                 }
28916: 
28917:                 filteredPayrollRows.push(
28918:                     payrollRow
28919:                 );
28920: 
28921:                 payrollGrossTotal +=
28922:                     Number(payrollRow.gross_total) || 0;
28923: 
28924:                 payrollDeductionTotal +=
28925:                     Number(payrollRow.deduction_total) || 0;
28926: 
28927:                 payrollNetTotal +=
28928:                     Number(payrollRow.net_total) || 0;
28929: 
28930:                 payrollEmployeeTotal +=
28931:                     Number(payrollRow.employee_count) || 0;
28932:             }
28933: 
28934:             var payrollTableRows =
28935:                 filteredPayrollRows.map(function(row) {
28936: 
28937:                     return (
28938:                         '<tr class="border-t">' +
28939:                         '<td class="p-2">' +
28940:                         _esc(row.run_no || '') +
28941:                         '</td>' +
28942:                         '<td class="p-2 font-semibold">' +
28943:                         _esc(row.period_code || '') +
28944:                         '</td>' +
28945:                         '<td class="p-2">' +
28946:                         _esc(row.start_date || '') +
28947:                         ' → ' +
28948:                         _esc(row.end_date || '') +
28949:                         '</td>' +
28950:                         '<td class="p-2 text-center">' +
28951:                         _fmtNum(row.employee_count) +
28952:                         '</td>' +
28953:                         '<td class="p-2 text-center">' +
28954:                         _fmtNum(row.gross_total) +
28955:                         '</td>' +
28956:                         '<td class="p-2 text-center">' +
28957:                         _fmtNum(row.deduction_total) +
28958:                         '</td>' +
28959:                         '<td class="p-2 text-center font-bold">' +
28960:                         _fmtNum(row.net_total) +
28961:                         '</td>' +
28962:                         '<td class="p-2">' +
28963:                         _esc(row.status || '') +
28964:                         '</td>' +
28965:                         '</tr>'
28966:                     );
28967:                 });
28968: 
28969:             html =
28970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
28971:                 '<div class="mb-4 text-xs text-gray-500">' +
28972:                 'المصدر: Production hr_query(payroll_runs)' +
28973:                 '</div>' +
28974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
28975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
28976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
28977:                 '<div class="text-lg font-black">' +
28978:                 _fmtNum(filteredPayrollRows.length) +
28979:                 '</div></div>' +
28980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
28981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
28982:                 '<div class="text-lg font-black">' +
28983:                 _fmtNum(payrollGrossTotal) +
28984:                 '</div></div>' +
28985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
28986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
28987:                 '<div class="text-lg font-black">' +
28988:                 _fmtNum(payrollDeductionTotal) +
28989:                 '</div></div>' +
28990:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
28991:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
28992:                 '<div class="text-lg font-black">' +
28993:                 _fmtNum(payrollNetTotal) +
28994:                 '</div></div>' +
28995:                 '</div>' +
28996:                 '<div class="mb-4 text-xs text-gray-500">' +
28997:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
28998:                 _fmtNum(payrollEmployeeTotal) +
28999:                 '</div>' +
29000:                 _table(
29001:                     [
29002:                         'رقم المسير',
29003:                         'الفترة',
29004:                         'النطاق',
29005:                         'الموظفون',
29006:                         'إجمالي الأجور',
29007:                         'الاستقطاعات',
29008:                         'الصافي',
29009:                         'الحالة'
29010:                     ],
29011:                     payrollTableRows
29012:                 );
29013:         }
29014:         else {
29015: 
29016:             html =
29017:                 '<div class="text-center py-4 text-gray-500">' +
29018:                 'هذا التقرير غير متوفر بعد' +
29019:                 '</div>';
29020:         }
29021: 
29022:         safeHTML(
29023:     resultDiv,
29024:     html +
29025:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
29026:     '<span>المصدر: Production</span>' +
29027:     '<span>آخر تنفيذ: ' +
29028:     _esc(
29029:         new Date().toLocaleString('ar-EG')
29030:     ) +
29031:     '</span>' +
--- WINDOW 28942-29152 around 28972 ---
28942:                         '<td class="p-2 font-semibold">' +
28943:                         _esc(row.period_code || '') +
28944:                         '</td>' +
28945:                         '<td class="p-2">' +
28946:                         _esc(row.start_date || '') +
28947:                         ' → ' +
28948:                         _esc(row.end_date || '') +
28949:                         '</td>' +
28950:                         '<td class="p-2 text-center">' +
28951:                         _fmtNum(row.employee_count) +
28952:                         '</td>' +
28953:                         '<td class="p-2 text-center">' +
28954:                         _fmtNum(row.gross_total) +
28955:                         '</td>' +
28956:                         '<td class="p-2 text-center">' +
28957:                         _fmtNum(row.deduction_total) +
28958:                         '</td>' +
28959:                         '<td class="p-2 text-center font-bold">' +
28960:                         _fmtNum(row.net_total) +
28961:                         '</td>' +
28962:                         '<td class="p-2">' +
28963:                         _esc(row.status || '') +
28964:                         '</td>' +
28965:                         '</tr>'
28966:                     );
28967:                 });
28968: 
28969:             html =
28970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
28971:                 '<div class="mb-4 text-xs text-gray-500">' +
28972:                 'المصدر: Production hr_query(payroll_runs)' +
28973:                 '</div>' +
28974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
28975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
28976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
28977:                 '<div class="text-lg font-black">' +
28978:                 _fmtNum(filteredPayrollRows.length) +
28979:                 '</div></div>' +
28980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
28981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
28982:                 '<div class="text-lg font-black">' +
28983:                 _fmtNum(payrollGrossTotal) +
28984:                 '</div></div>' +
28985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
28986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
28987:                 '<div class="text-lg font-black">' +
28988:                 _fmtNum(payrollDeductionTotal) +
28989:                 '</div></div>' +
28990:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
28991:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
28992:                 '<div class="text-lg font-black">' +
28993:                 _fmtNum(payrollNetTotal) +
28994:                 '</div></div>' +
28995:                 '</div>' +
28996:                 '<div class="mb-4 text-xs text-gray-500">' +
28997:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
28998:                 _fmtNum(payrollEmployeeTotal) +
28999:                 '</div>' +
29000:                 _table(
29001:                     [
29002:                         'رقم المسير',
29003:                         'الفترة',
29004:                         'النطاق',
29005:                         'الموظفون',
29006:                         'إجمالي الأجور',
29007:                         'الاستقطاعات',
29008:                         'الصافي',
29009:                         'الحالة'
29010:                     ],
29011:                     payrollTableRows
29012:                 );
29013:         }
29014:         else {
29015: 
29016:             html =
29017:                 '<div class="text-center py-4 text-gray-500">' +
29018:                 'هذا التقرير غير متوفر بعد' +
29019:                 '</div>';
29020:         }
29021: 
29022:         safeHTML(
29023:     resultDiv,
29024:     html +
29025:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
29026:     '<span>المصدر: Production</span>' +
29027:     '<span>آخر تنفيذ: ' +
29028:     _esc(
29029:         new Date().toLocaleString('ar-EG')
29030:     ) +
29031:     '</span>' +
29032:     '</div>'
29033: );
29034: 
29035:     } catch (e) {
29036: 
29037:         console.error(
29038:             'RW_Reports_Comprehensive._generateReport',
29039:             e
29040:         );
29041: 
29042:         safeHTML(
29043:             resultDiv,
29044:             '<div class="text-center py-8 text-red-500">' +
29045:             'فشل تحميل التقرير: ' +
29046:             _esc(
29047:                 e.message ||
29048:                 'خطأ غير معروف'
29049:             ) +
29050:             '</div>'
29051:         );
29052:     }
29053: }
29054: 
29055: function _exportReportCsv() {
29056:     var resultDiv = byId('report-result');
29057: 
29058:     if (!resultDiv) {
29059:         _showToast('لا يوجد تقرير للتصدير', 'info');
29060:         return;
29061:     }
29062: 
29063:     var table = resultDiv.querySelector('table');
29064: 
29065:     if (!table) {
29066:         _showToast('لا يوجد جدول قابل للتصدير', 'info');
29067:         return;
29068:     }
29069: 
29070:     var rows = table.querySelectorAll('tr');
29071:     var csv = [];
29072: 
29073:     function csvCell(value) {
29074:         var s = String(value == null ? '' : value)
29075:             .replace(/\r?\n|\r/g, ' ')
29076:             .replace(/"/g, '""');
29077: 
29078:         return '"' + s + '"';
29079:     }
29080: 
29081:     for (var i = 0; i < rows.length; i++) {
29082:         var cells = rows[i].querySelectorAll('th,td');
29083:         var line = [];
29084: 
29085:         for (var j = 0; j < cells.length; j++) {
29086:             line.push(csvCell(cells[j].innerText || ''));
29087:         }
29088: 
29089:         csv.push(line.join(','));
29090:     }
29091: 
29092:     var blob = new Blob(
29093:         ['\uFEFF' + csv.join('\r\n')],
29094:         { type: 'text/csv;charset=utf-8;' }
29095:     );
29096: 
29097:     var url = URL.createObjectURL(blob);
29098:     var a = document.createElement('a');
29099: 
29100:     a.href = url;
29101:     a.download =
29102:         'rawaea-report-' +
29103:         String(_currentReport || 'report') +
29104:         '-' +
29105:         new Date().toISOString().slice(0, 10) +
29106:         '.csv';
29107: 
29108:     document.body.appendChild(a);
29109:     a.click();
29110:     document.body.removeChild(a);
29111: 
29112:     URL.revokeObjectURL(url);
29113: }
29114: function _printReport() {
29115:     var resultDiv = byId('report-result');
29116: 
29117:     if (!resultDiv || !resultDiv.innerHTML) {
29118:         _showToast('لا يوجد تقرير للطباعة', 'info');
29119:         return;
29120:     }
29121: 
29122:     var printWindow = window.open('', '_blank');
29123: 
29124:     if (!printWindow) {
29125:         _showToast('الرجاء السماح بالنوافذ المنبثقة', 'warning');
29126:         return;
29127:     }
29128: 
29129:     var html =
29130:         '<!DOCTYPE html>' +
29131:         '<html dir="rtl">' +
29132:         '<head>' +
29133:         '<meta charset="UTF-8">' +
29134:         '<title>تقرير الروائع ERP</title>' +
29135:         '<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700;900&display=swap" rel="stylesheet">' +
29136:         '<style>' +
29137:         'body{font-family:Cairo,sans-serif;padding:20px;color:#111827}' +
29138:         'table{width:100%;border-collapse:collapse;margin-top:15px}' +
29139:         'th,td{border:1px solid #ddd;padding:8px}' +
29140:         'th{background:#f2f2f2;font-weight:800}' +
29141:         '.text-center{text-align:center}' +
29142:         '</style>' +
29143:         '</head>' +
29144:         '<body>' +
29145:         resultDiv.innerHTML +
29146:         '<script>window.onload=function(){window.print();};<\/script>' +
29147:         '</body></html>';
29148: 
29149:     printWindow.document.open();
29150:     printWindow.document.write(html);
29151:     printWindow.document.close();
29152: }
--- WINDOW 31465-31675 around 31495 ---
31465:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
31466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
31467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
31468: 
31469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
31470:     }
31471: };
31472: window.RW_Views = RW_Views;
31473: // ============================================================
31474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
31475: // ============================================================
31476: var RW_HR = (function() {
31477:  'use strict';
31478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
31479:   var T=[
31480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
31481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
31482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
31483:   ];
31484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
31485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
31486:   function num(v){v=Number(v);return isFinite(v)?v:0}
31487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
31488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
31489:   function iso(v){return v?new Date(v).toISOString():null}
31490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
31491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
31492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
31493:   function opClear(k){if(k)delete H.ops[k]}
31494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
31495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
31496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
31497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
31498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
31499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
31500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
31501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
31502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
31503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
31504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
31505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
31506:  function modal(title,body,onSubmit,key){
31507:   var old=E('rw-hr-modal-root');
31508:   if(old)old.remove();
31509:   var r=document.createElement('div');
31510:   r.id='rw-hr-modal-root';
31511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
31512:   document.body.appendChild(r);
31513:   E('rw-hr-close').onclick=closeModal;
31514:   E('rw-hr-cancel').onclick=closeModal;
31515:   r.addEventListener('click',function(e){
31516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31517:     if(ac){
31518:       e.preventDefault();
31519:       handle(ac.getAttribute('data-hr-action'));
31520:     }
31521:   });
31522:   if(onSubmit===null){
31523:     var f=E('rw-hr-form');
31524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31525:   }else{
31526:     E('rw-hr-form').onsubmit=async function(e){
31527:       e.preventDefault();
31528:       var save=e.target.querySelector('button[type="submit"]');
31529:       try{
31530:         if(save){
31531:           save.disabled=true;
31532:           save.textContent='جارٍ الحفظ…';
31533:         }
31534:         await onSubmit(key||'form:'+Date.now());
31535:       }catch(err){
31536:         toast(err.message||'تعذر الحفظ','error');
31537:         if(save){
31538:           save.disabled=false;
31539:           save.textContent='حفظ';
31540:         }
31541:       }
31542:     };
31543:   }
31544: }
31545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
31546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
31547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
31548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
31549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
31550:   function employeeOpts(){return ppl()}
31551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
31553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
31555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
31556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
31557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
31558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
31559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
31560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
31561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
31562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
31563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
31564:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
31565:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
31566:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
31567:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
31568:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
31569:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
31570:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
31571:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
31572:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
31573:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
31574:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
31575:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
31576:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
31577:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
31578:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
31579:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
31580:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
31581:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
31582:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
31583:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
31584:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
31585:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
31586:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
31587:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
31588:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
31589:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
31590:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
31591:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
31592:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
31593:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
31594:   (function installModalResilience(){
31595:     document.addEventListener('click',function(e){
31596:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31597:       if(!ac)return;
31598:       var page=E('rw-page-container');
31599:       if(page&&page.contains(ac))return;
31600:       e.preventDefault();
31601:       handle(ac.getAttribute('data-hr-action'));
31602:     },true);
31603:     window.addEventListener('unhandledrejection',function(e){
31604:       var root=E('rw-hr-modal-root');
31605:       if(!root)return;
31606:       e.preventDefault();
31607:       var msg=e.reason&&(e.reason.message||String(e.reason));
31608:       if(msg)toast(msg,'error');
31609:     });
31610:     try{
31611:       var mo=new MutationObserver(function(){
31612:         var root=E('rw-hr-modal-root');
31613:         if(!root||!E('hr360'))return;
31614:         var f=E('rw-hr-form');
31615:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31616:       });
31617:       mo.observe(document.body,{childList:true,subtree:true});
31618:     }catch(e){}
31619:   }());
31620: 
31621: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
31622: 
31623: 
31624: // ============================================================
31625: // RW_CRM – إدارة علاقات العملاء (CRM)
31626: // ============================================================
31627: var RW_CRM = (function() {
31628:     'use strict';
31629: 
31630:     var state = {
31631:         customers: [],
31632:         assignees: [],
31633:         kpi: {},
31634:         search: '',
31635:         activeOnly: false,
31636:         searchTimer: null
31637:     };
31638: 
31639:     function _esc(s) {
31640:         return String(s == null ? '' : s)
31641:             .replace(/&/g, '&amp;')
31642:             .replace(/</g, '&lt;')
31643:             .replace(/>/g, '&gt;')
31644:             .replace(/"/g, '&quot;')
31645:             .replace(/'/g, '&#39;');
31646:     }
31647: 
31648:     function _fmtNum(n) {
31649:         return Number(n || 0).toLocaleString('ar-EG');
31650:     }
31651: 
31652:     function _fmtMoney(n) {
31653:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
31654:     }
31655: 
31656:     function _today() {
31657:         var d = new Date();
31658:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
31659:         return local.toISOString().slice(0, 10);
31660:     }
31661: 
31662:     function _statusLabel(s) {
31663:         var map = {
31664:             Open: 'مفتوحة',
31665:             'معلقة': 'معلقة',
31666:             completed: 'مكتملة',
31667:             'مكتملة': 'مكتملة',
31668:             cancelled: 'ملغاة',
31669:             'ملغاة': 'ملغاة'
31670:         };
31671:         return map[s] || s || 'غير محددة';
31672:     }
31673: 
31674:     function _statusClass(s) {
31675:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
--- WINDOW 31562-31772 around 31592 ---
31562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
31563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
31564:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
31565:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
31566:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
31567:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
31568:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
31569:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
31570:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
31571:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
31572:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
31573:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
31574:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
31575:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
31576:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
31577:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
31578:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
31579:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
31580:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
31581:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
31582:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
31583:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
31584:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
31585:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
31586:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
31587:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
31588:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
31589:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
31590:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
31591:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
31592:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
31593:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
31594:   (function installModalResilience(){
31595:     document.addEventListener('click',function(e){
31596:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31597:       if(!ac)return;
31598:       var page=E('rw-page-container');
31599:       if(page&&page.contains(ac))return;
31600:       e.preventDefault();
31601:       handle(ac.getAttribute('data-hr-action'));
31602:     },true);
31603:     window.addEventListener('unhandledrejection',function(e){
31604:       var root=E('rw-hr-modal-root');
31605:       if(!root)return;
31606:       e.preventDefault();
31607:       var msg=e.reason&&(e.reason.message||String(e.reason));
31608:       if(msg)toast(msg,'error');
31609:     });
31610:     try{
31611:       var mo=new MutationObserver(function(){
31612:         var root=E('rw-hr-modal-root');
31613:         if(!root||!E('hr360'))return;
31614:         var f=E('rw-hr-form');
31615:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31616:       });
31617:       mo.observe(document.body,{childList:true,subtree:true});
31618:     }catch(e){}
31619:   }());
31620: 
31621: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
31622: 
31623: 
31624: // ============================================================
31625: // RW_CRM – إدارة علاقات العملاء (CRM)
31626: // ============================================================
31627: var RW_CRM = (function() {
31628:     'use strict';
31629: 
31630:     var state = {
31631:         customers: [],
31632:         assignees: [],
31633:         kpi: {},
31634:         search: '',
31635:         activeOnly: false,
31636:         searchTimer: null
31637:     };
31638: 
31639:     function _esc(s) {
31640:         return String(s == null ? '' : s)
31641:             .replace(/&/g, '&amp;')
31642:             .replace(/</g, '&lt;')
31643:             .replace(/>/g, '&gt;')
31644:             .replace(/"/g, '&quot;')
31645:             .replace(/'/g, '&#39;');
31646:     }
31647: 
31648:     function _fmtNum(n) {
31649:         return Number(n || 0).toLocaleString('ar-EG');
31650:     }
31651: 
31652:     function _fmtMoney(n) {
31653:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
31654:     }
31655: 
31656:     function _today() {
31657:         var d = new Date();
31658:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
31659:         return local.toISOString().slice(0, 10);
31660:     }
31661: 
31662:     function _statusLabel(s) {
31663:         var map = {
31664:             Open: 'مفتوحة',
31665:             'معلقة': 'معلقة',
31666:             completed: 'مكتملة',
31667:             'مكتملة': 'مكتملة',
31668:             cancelled: 'ملغاة',
31669:             'ملغاة': 'ملغاة'
31670:         };
31671:         return map[s] || s || 'غير محددة';
31672:     }
31673: 
31674:     function _statusClass(s) {
31675:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
31676:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
31677:         return 'bg-amber-100 text-amber-700';
31678:     }
31679: 
31680:     function _assignedLabel(customer) {
31681:         var rows = Array.isArray(customer && customer.assigned_to) ? customer.assigned_to : [];
31682:         if (!rows.length) return 'غير مسند';
31683:         var active = rows.filter(function(x) { return x && x.active !== false; });
31684:         if (!active.length) active = rows;
31685:         return active.slice(0, 2).map(function(x) {
31686:             return x.name || x.email || '—';
31687:         }).join('، ') + (active.length > 2 ? ' +' + (active.length - 2) : '');
31688:     }
31689: 
31690:     async function _loadDirectory() {
31691:         var res = await supabase.rpc('crm_customer_directory', {
31692:             p_search: state.search || null,
31693:             p_active_only: state.activeOnly,
31694:             p_limit: 200,
31695:             p_offset: 0
31696:         });
31697:         if (res.error) throw res.error;
31698: 
31699:         var payload = res.data || {};
31700:         state.customers = Array.isArray(payload.customers) ? payload.customers : [];
31701:         state.assignees = Array.isArray(payload.assignees) ? payload.assignees : [];
31702:         state.kpi = payload.kpi || {};
31703:         return payload;
31704:     }
31705: 
31706:     function _renderKpis() {
31707:         var k = state.kpi || {};
31708:         return '<div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">' +
31709:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">إجمالي العملاء</div><div class="text-2xl font-black text-indigo-600 mt-2">' + _fmtNum(k.total_customers) + '</div></div>' +
31710:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">عملاء نشطون</div><div class="text-2xl font-black text-green-600 mt-2">' + _fmtNum(k.active_customers) + '</div></div>' +
31711:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">ذمم مسجلة</div><div class="text-2xl font-black text-red-600 mt-2">' + _fmtMoney(k.master_debt_total) + '</div></div>' +
31712:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متابعات مفتوحة</div><div class="text-2xl font-black text-amber-600 mt-2">' + _fmtNum(k.open_followups) + '</div></div>' +
31713:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متأخرة</div><div class="text-2xl font-black text-rose-600 mt-2">' + _fmtNum(k.overdue_followups) + '</div></div>' +
31714:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">مستحقة اليوم</div><div class="text-2xl font-black text-blue-600 mt-2">' + _fmtNum(k.due_today) + '</div></div>' +
31715:         '</div>';
31716:     }
31717: 
31718:     function _renderTable() {
31719:         if (!state.customers.length) {
31720:             return '<div class="text-center py-16 text-gray-400"><div class="text-5xl mb-3">👥</div><div class="font-black text-lg">لا توجد عملاء مطابقون</div><div class="text-sm mt-2">غيّر البحث أو الفلاتر ثم أعد المحاولة.</div></div>';
31721:         }
31722: 
31723:         var html = '<div class="overflow-x-auto"><table class="w-full text-sm">' +
31724:             '<thead class="bg-slate-50"><tr>' +
31725:             '<th class="p-3 text-right">العميل</th>' +
31726:             '<th class="p-3 text-right">التواصل</th>' +
31727:             '<th class="p-3 text-right">التصنيف</th>' +
31728:             '<th class="p-3 text-center">المبيعات</th>' +
31729:             '<th class="p-3 text-center">الأوردرات</th>' +
31730:             '<th class="p-3 text-center">المتابعة القادمة</th>' +
31731:             '<th class="p-3 text-right">المسؤول</th>' +
31732:             '<th class="p-3 text-center">الإجراء</th>' +
31733:             '</tr></thead><tbody>';
31734: 
31735:         for (var i = 0; i < state.customers.length; i++) {
31736:             var c = state.customers[i] || {};
31737:             var overdue = Number(c.overdue_followups || 0) > 0;
31738:             var next = c.next_followup_date ? String(c.next_followup_date) : '—';
31739: 
31740:             html += '<tr class="border-b hover:bg-slate-50">' +
31741:                 '<td class="p-3"><div class="font-black">' + _esc(c.name) + '</div><div class="text-xs text-gray-400">' + _esc(c.customer_code) + '</div></td>' +
31742:                 '<td class="p-3"><div>' + _esc(c.phone || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.area || '—') + '</div></td>' +
31743:                 '<td class="p-3"><div class="font-bold">' + _esc(c.customer_type || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.payment_type || '—') + '</div></td>' +
31744:                 '<td class="p-3 text-center font-black">' + _fmtMoney(c.sales_total) + '</td>' +
31745:                 '<td class="p-3 text-center font-black">' + _fmtNum(c.order_count) + '</td>' +
31746:                 '<td class="p-3 text-center"><span class="px-2 py-1 rounded-full text-xs font-black ' + (overdue ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-700') + '">' + _esc(next) + '</span></td>' +
31747:                 '<td class="p-3">' + _esc(_assignedLabel(c)) + '</td>' +
31748:                 '<td class="p-3 text-center"><button type="button" data-crm-open360="' + _esc(c.id) + '" class="px-4 py-2 bg-indigo-600 text-white rounded-xl font-black">متابعة</button></td>' +
31749:             '</tr>';
31750:         }
31751: 
31752:         return html + '</tbody></table></div>';
31753:     }
31754: 
31755:     function _bindDirectory() {
31756:         var search = byId('crm-search');
31757:         if (search) {
31758:             search.value = state.search;
31759:             search.addEventListener('input', function() {
31760:                 state.search = search.value.trim();
31761:                 clearTimeout(state.searchTimer);
31762:                 state.searchTimer = setTimeout(function() {
31763:                     _loadDirectory().then(function() {
31764:                         safeHTML(byId('crm-customers-list'), _renderTable());
31765:                         _bindOpen360();
31766:                         safeHTML(byId('crm-kpis'), _renderKpis());
31767:                     }).catch(function(e) {
31768:                         showToast(e.message || 'فشل البحث', 'error');
31769:                     });
31770:                 }, 250);
31771:             });
31772:         }
--- RW_HR_FULL 31476-31621 ---
31476: var RW_HR = (function() {
31477:  'use strict';
31478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
31479:   var T=[
31480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
31481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
31482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
31483:   ];
31484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
31485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
31486:   function num(v){v=Number(v);return isFinite(v)?v:0}
31487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
31488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
31489:   function iso(v){return v?new Date(v).toISOString():null}
31490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
31491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
31492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
31493:   function opClear(k){if(k)delete H.ops[k]}
31494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
31495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
31496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
31497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
31498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
31499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
31500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
31501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
31502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
31503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
31504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
31505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
31506:  function modal(title,body,onSubmit,key){
31507:   var old=E('rw-hr-modal-root');
31508:   if(old)old.remove();
31509:   var r=document.createElement('div');
31510:   r.id='rw-hr-modal-root';
31511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
31512:   document.body.appendChild(r);
31513:   E('rw-hr-close').onclick=closeModal;
31514:   E('rw-hr-cancel').onclick=closeModal;
31515:   r.addEventListener('click',function(e){
31516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31517:     if(ac){
31518:       e.preventDefault();
31519:       handle(ac.getAttribute('data-hr-action'));
31520:     }
31521:   });
31522:   if(onSubmit===null){
31523:     var f=E('rw-hr-form');
31524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31525:   }else{
31526:     E('rw-hr-form').onsubmit=async function(e){
31527:       e.preventDefault();
31528:       var save=e.target.querySelector('button[type="submit"]');
31529:       try{
31530:         if(save){
31531:           save.disabled=true;
31532:           save.textContent='جارٍ الحفظ…';
31533:         }
31534:         await onSubmit(key||'form:'+Date.now());
31535:       }catch(err){
31536:         toast(err.message||'تعذر الحفظ','error');
31537:         if(save){
31538:           save.disabled=false;
31539:           save.textContent='حفظ';
31540:         }
31541:       }
31542:     };
31543:   }
31544: }
31545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
31546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
31547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
31548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
31549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
31550:   function employeeOpts(){return ppl()}
31551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
31553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
31554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
31555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
31556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
31557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
31558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
31559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
31560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
31561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
31562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
31563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
31564:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
31565:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
31566:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
31567:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
31568:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
31569:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
31570:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
31571:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
31572:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
31573:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
31574:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
31575:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
31576:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
31577:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
31578:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
31579:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
31580:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
31581:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
31582:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
31583:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
31584:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
31585:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
31586:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
31587:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
31588:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
31589:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
31590:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
31591:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
31592:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
31593:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
31594:   (function installModalResilience(){
31595:     document.addEventListener('click',function(e){
31596:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
31597:       if(!ac)return;
31598:       var page=E('rw-page-container');
31599:       if(page&&page.contains(ac))return;
31600:       e.preventDefault();
31601:       handle(ac.getAttribute('data-hr-action'));
31602:     },true);
31603:     window.addEventListener('unhandledrejection',function(e){
31604:       var root=E('rw-hr-modal-root');
31605:       if(!root)return;
31606:       e.preventDefault();
31607:       var msg=e.reason&&(e.reason.message||String(e.reason));
31608:       if(msg)toast(msg,'error');
31609:     });
31610:     try{
31611:       var mo=new MutationObserver(function(){
31612:         var root=E('rw-hr-modal-root');
31613:         if(!root||!E('hr360'))return;
31614:         var f=E('rw-hr-form');
31615:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
31616:       });
31617:       mo.observe(document.body,{childList:true,subtree:true});
31618:     }catch(e){}
31619:   }());
31620: 
31621: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
