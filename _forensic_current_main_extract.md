# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=34547
FILE_BYTES=2028837
SHA256=a47b9a276df3f1815c72c60f875b3640204d86816c67181fd85a7c148e151932
PATTERN var RW_Warehouse: [14739]
PATTERN var RW_HR: [32476]
PATTERN RW_HR: [32428, 32474, 32476, 32610, 32639]
PATTERN hr_list_employees: []
PATTERN hr_command_atomic: [32496]
PATTERN hr_query: [29704, 29807, 29851, 29972, 32495]
PATTERN hr_payroll_calculate_impl: []
PATTERN hr_payroll_post_impl: []
PATTERN employee_documents: [32610]
PATTERN hr_departments: [32610]
PATTERN hr_contracts: [32610]
PATTERN hr_work_schedules: [32610]
PATTERN hr_attendance_events: [32610]
PATTERN hr_leave_types: [32610]
PATTERN hr_requests: [32610]
PATTERN hr_salary_advances: [23699, 23739, 32610]
PATTERN hr_payroll_periods: [32610]
PATTERN hr_payslips: [32610]
PATTERN hr_command: [32496]
PATTERN employee-document: [24204, 32606, 32607]
PATTERN document-upload: []
PATTERN الموارد البشرية: [1585, 7957, 9288, 26167, 26199, 32414, 32474, 32608]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 32446-32656 around 32476 ---
32446:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
32447:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
32448: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
32449: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
32450: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
32451: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
32452:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
32453:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
32454:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
32455:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
32456:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
32457:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
32458:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
32459:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
32460:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
32461:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
32462:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
32463:         if (view === 'finance') { RW_Finance.render(); return; }
32464:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
32465:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
32466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
32467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
32468: 
32469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
32470:     }
32471: };
32472: window.RW_Views = RW_Views;
32473: // ============================================================
32474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
32475: // ============================================================
32476: var RW_HR = (function() {
32477:  'use strict';
32478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
32479:   var T=[
32480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
32481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
32482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
32483:   ];
32484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
32485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
32486:   function num(v){v=Number(v);return isFinite(v)?v:0}
32487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
32488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
32489:   function iso(v){return v?new Date(v).toISOString():null}
32490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
32491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
32492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
32493:   function opClear(k){if(k)delete H.ops[k]}
32494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
32495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
32496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
32497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
32498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
32499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
32500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
32501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
32502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
32503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
32504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
32505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
32506:  function modal(title,body,onSubmit,key){
32507:   var old=E('rw-hr-modal-root');
32508:   if(old)old.remove();
32509:   var r=document.createElement('div');
32510:   r.id='rw-hr-modal-root';
32511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
32512:   document.body.appendChild(r);
32513:   E('rw-hr-close').onclick=closeModal;
32514:   E('rw-hr-cancel').onclick=closeModal;
32515:   r.addEventListener('click',function(e){
32516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32517:     if(ac){
32518:       e.preventDefault();
32519:       handle(ac.getAttribute('data-hr-action'));
32520:     }
32521:   });
32522:   if(onSubmit===null){
32523:     var f=E('rw-hr-form');
32524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32525:   }else{
32526:     E('rw-hr-form').onsubmit=async function(e){
32527:       e.preventDefault();
32528:       var save=e.target.querySelector('button[type="submit"]');
32529:       try{
32530:         if(save){
32531:           save.disabled=true;
32532:           save.textContent='جارٍ الحفظ…';
32533:         }
32534:         await onSubmit(key||'form:'+Date.now());
32535:       }catch(err){
32536:         toast(err.message||'تعذر الحفظ','error');
32537:         if(save){
32538:           save.disabled=false;
32539:           save.textContent='حفظ';
32540:         }
32541:       }
32542:     };
32543:   }
32544: }
32545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
32546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
32547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
32548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
32549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
32550:   function employeeOpts(){return ppl()}
32551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
32553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
32555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
32556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
32557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
32558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
32559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
32560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
32561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
32562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
32563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
32564:   async function advancesTab(cn){
32565:  var d=await q('advances'),types={SALARY_ADVANCE:'سلفة راتب',TEMPORARY_ADVANCE:'سلفة مؤقتة',EMPLOYEE_LOAN:'قرض موظف',OPERATIONAL_CUSTODY:'عهدة تشغيلية',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};
32566:  var financial=d.financial_balances||[],debt=0,payable=0;
32567:  financial.forEach(function(x){var b=num(x.outstanding_balance);if(b>0)debt+=b;else if(b<0)payable+=Math.abs(b)});
32568:  var financialBody='<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-5">'+stat('إجمالي المديونية على الموظفين',money(debt)+' ج.م','fa-file-invoice-dollar','bg-amber-50 text-amber-700')+stat('مستحقات الموظفين لدى الشركة',money(payable)+' ج.م','fa-hand-holding-usd','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الأرصدة من القيود المرحلة فقط. الموجب على الموظف، والسالب مستحق له. طلبات السلف غير المصروفة لا تدخل في هذه الأرقام.</div>'+table(['الموظف','الحالة','طبيعة الذمة','الحساب','إجمالي المدين','إجمالي الدائن','الرصيد واتجاهه'],financial.map(function(x){var b=num(x.outstanding_balance),dir=b>0?badge('على الموظف','warn'):b<0?badge('مستحق للموظف','ok'):badge('متزن','muted');return tr([esc(x.employee_name||'-'),esc(x.employee_status||'-'),esc(types[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',dir+' <b class="mr-2">'+money(Math.abs(b))+' ج.م</b>'])}));
32569:  cn.innerHTML='<div class="space-y-5">'+card('المديونيات والأرصدة المالية المرحلة','مصدر موحد من دفتر الموظفين دون تعديل أرصدة',financialBody)+card('السلف والقروض','طلب → اعتماد → سند صرف مركزي → سداد نقدي عبر Receipts أو استقطاع رواتب حسب النوع',table(['الرقم','الموظف','نوع التمويل','القيمة','القسط','المتبقي','الحالة','سند الصرف','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف عبر Payments','disburse-advance:'+x.id,'bg-emerald-600 text-white'):'';return tr([esc(x.advance_no),esc(x.employee_name),esc(types[x.advance_nature||'SALARY_ADVANCE']),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),x.cash_box_id?badge('مرحل','ok'):badge('غير مصروف','warn'),a])})),btn('طلب سلفة/قرض جديد','new-advance'))+'</div>';
32570: }
32571:   async function disburseAdvance(id){
32572:     var tr=await supabase.from('treasury').select('id,account_name,account_code,type,current_balance,is_active').eq('company_id',H.companyId).eq('is_active',true).in('type',['Cash','Bank']).order('account_name');
32573:     if(tr.error)throw tr.error;
32574:     var rows=tr.data||[];
32575:     if(!rows.length){toast('لا توجد خزينة أو حساب بنكي فعال للصرف','error');return;}
32576:     var opts=rows.map(function(x){return '<option value="'+esc(x.id)+'">'+esc(x.account_name||x.account_code)+' · '+esc(x.type)+' · '+money(x.current_balance)+'</option>';}).join('');
32577:     var r=await Swal.fire({title:'صرف السلفة عبر سند Payments',html:'<div class="text-right text-sm text-slate-600 mb-2">سيتم إنشاء سند صرف مركزي وقيد محاسبي وربطه بالسلفة والموظف.</div><select id="hr-advance-treasury" class="swal2-select w-full">'+opts+'</select>',showCancelButton:true,confirmButtonText:'إنشاء سند الصرف',cancelButtonText:'إلغاء',preConfirm:function(){var t=E('hr-advance-treasury');if(!t||!t.value){Swal.showValidationMessage('اختر خزينة الصرف');return false;}return t.value;}});
32578:     if(!r.isConfirmed)return;
32579:     await c('advance.disburse',{advance_id:id,treasury_id:r.value},'disburse-advance:'+id);
32580:     toast('تم الصرف من خلال سند Payments مركزي وربطه بالسلفة','success');
32581:     return render();
32582:   }
32583:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
32584:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
32585:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[],fb=z[7].financial_balances||[],fl=z[7].financial_ledger||[];var financialReceivable=0,financialPayable=0;fb.forEach(function(x){var balance=num(x.outstanding_balance);if(balance>0)financialReceivable+=balance;else if(balance<0)financialPayable+=Math.abs(balance)});var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الموقف المالي المرحّل','ملخص مستقل لكل حساب وطبيعة ذمة — دون مقاصة بين ما على الموظف وما له','<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">'+stat('إجمالي المديونية على الموظف',money(financialReceivable)+' ج.م','fa-arrow-up','bg-amber-50 text-amber-700')+stat('إجمالي المستحق للموظف',money(financialPayable)+' ج.م','fa-arrow-down','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الموجب يمثل مديونية على الموظف، والسالب يمثل مبلغًا مستحقًا له. هذه الأرقام ناتجة عن قيود Posted فقط.</div>'+table(['طبيعة الذمة','الحساب','مدين','دائن','الرصيد','الاتجاه'],fb.map(function(x){var b=num(x.outstanding_balance),n={OPERATIONAL_CUSTODY:'عهدة تشغيلية',TEMPORARY_ADVANCE:'سلفة مؤقتة',SALARY_ADVANCE:'سلفة راتب',EMPLOYEE_LOAN:'قرض موظف',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};return tr([esc(n[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',money(Math.abs(b))+' ج.م',b>0?badge('على الموظف','warn'):b<0?badge('مستحق له','ok'):badge('متزن','muted')])})))+card('آخر الحركات المالية المرحّلة','آخر 30 حركة — RPC يعيد 200 كحد أقصى',table(['التاريخ','رقم القيد','نوع القيد','الحساب','المرجع / البيان','مدين','دائن'],fl.slice(0,30).map(function(x){return tr([date(x.entry_date),esc(x.entry_code||'-'),esc(x.entry_type||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),esc(x.reference||x.description||'-'),money(x.debit)+' ج.م',money(x.credit)+' ج.م'])})))+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
32586:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
32587:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
32588:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
32589:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
32590:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
32591:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
32592:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
32593:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
32594:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
32595:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
32596:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
32597:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
32598:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
32599:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
32600:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
32601:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
32602:   async function advance(){await loadPeople();simple('سلفة أو قرض موظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع التمويل','x-nature',[{value:'SALARY_ADVANCE',label:'سلفة راتب — تستقطع من الرواتب'},{value:'TEMPORARY_ADVANCE',label:'سلفة مؤقتة — تسدد نقدًا أو بتسوية معتمدة'},{value:'EMPLOYEE_LOAN',label:'قرض موظف — أقساط أو سداد نقدي'}],'SALARY_ADVANCE')+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,advance_nature:E('x-nature').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
32603:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
32604:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
32605:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
32606:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
32607:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
32608:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
32609:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance')return disburseAdvance(id);if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
32610:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var refresh=function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)};var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},refresh)});H.channel.on('postgres_changes',{event:'*',schema:'public',table:'journal_lines',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'*',schema:'public',table:'cash_box',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'journal_entries',filter:'status=eq.Posted'},refresh);H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
32611:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
32612:   (function installModalResilience(){
32613:     document.addEventListener('click',function(e){
32614:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32615:       if(!ac)return;
32616:       var page=E('rw-page-container');
32617:       if(page&&page.contains(ac))return;
32618:       e.preventDefault();
32619:       handle(ac.getAttribute('data-hr-action'));
32620:     },true);
32621:     window.addEventListener('unhandledrejection',function(e){
32622:       var root=E('rw-hr-modal-root');
32623:       if(!root)return;
32624:       e.preventDefault();
32625:       var msg=e.reason&&(e.reason.message||String(e.reason));
32626:       if(msg)toast(msg,'error');
32627:     });
32628:     try{
32629:       var mo=new MutationObserver(function(){
32630:         var root=E('rw-hr-modal-root');
32631:         if(!root||!E('hr360'))return;
32632:         var f=E('rw-hr-form');
32633:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32634:       });
32635:       mo.observe(document.body,{childList:true,subtree:true});
32636:     }catch(e){}
32637:   }());
32638: 
32639: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
32640: 
32641: 
32642: // ============================================================
32643: // RW_CRM – إدارة علاقات العملاء (CRM)
32644: // ============================================================
32645: var RW_CRM = (function() {
32646:     'use strict';
32647: 
32648:     var state = {
32649:         customers: [],
32650:         assignees: [],
32651:         kpi: {},
32652:         search: '',
32653:         activeOnly: false,
32654:         searchTimer: null
32655:     };
32656: 
--- WINDOW 32466-32676 around 32496 ---
32466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
32467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
32468: 
32469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
32470:     }
32471: };
32472: window.RW_Views = RW_Views;
32473: // ============================================================
32474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
32475: // ============================================================
32476: var RW_HR = (function() {
32477:  'use strict';
32478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
32479:   var T=[
32480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
32481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
32482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
32483:   ];
32484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
32485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
32486:   function num(v){v=Number(v);return isFinite(v)?v:0}
32487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
32488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
32489:   function iso(v){return v?new Date(v).toISOString():null}
32490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
32491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
32492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
32493:   function opClear(k){if(k)delete H.ops[k]}
32494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
32495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
32496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
32497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
32498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
32499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
32500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
32501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
32502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
32503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
32504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
32505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
32506:  function modal(title,body,onSubmit,key){
32507:   var old=E('rw-hr-modal-root');
32508:   if(old)old.remove();
32509:   var r=document.createElement('div');
32510:   r.id='rw-hr-modal-root';
32511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
32512:   document.body.appendChild(r);
32513:   E('rw-hr-close').onclick=closeModal;
32514:   E('rw-hr-cancel').onclick=closeModal;
32515:   r.addEventListener('click',function(e){
32516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32517:     if(ac){
32518:       e.preventDefault();
32519:       handle(ac.getAttribute('data-hr-action'));
32520:     }
32521:   });
32522:   if(onSubmit===null){
32523:     var f=E('rw-hr-form');
32524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32525:   }else{
32526:     E('rw-hr-form').onsubmit=async function(e){
32527:       e.preventDefault();
32528:       var save=e.target.querySelector('button[type="submit"]');
32529:       try{
32530:         if(save){
32531:           save.disabled=true;
32532:           save.textContent='جارٍ الحفظ…';
32533:         }
32534:         await onSubmit(key||'form:'+Date.now());
32535:       }catch(err){
32536:         toast(err.message||'تعذر الحفظ','error');
32537:         if(save){
32538:           save.disabled=false;
32539:           save.textContent='حفظ';
32540:         }
32541:       }
32542:     };
32543:   }
32544: }
32545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
32546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
32547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
32548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
32549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
32550:   function employeeOpts(){return ppl()}
32551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
32553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
32555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
32556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
32557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
32558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
32559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
32560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
32561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
32562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
32563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
32564:   async function advancesTab(cn){
32565:  var d=await q('advances'),types={SALARY_ADVANCE:'سلفة راتب',TEMPORARY_ADVANCE:'سلفة مؤقتة',EMPLOYEE_LOAN:'قرض موظف',OPERATIONAL_CUSTODY:'عهدة تشغيلية',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};
32566:  var financial=d.financial_balances||[],debt=0,payable=0;
32567:  financial.forEach(function(x){var b=num(x.outstanding_balance);if(b>0)debt+=b;else if(b<0)payable+=Math.abs(b)});
32568:  var financialBody='<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-5">'+stat('إجمالي المديونية على الموظفين',money(debt)+' ج.م','fa-file-invoice-dollar','bg-amber-50 text-amber-700')+stat('مستحقات الموظفين لدى الشركة',money(payable)+' ج.م','fa-hand-holding-usd','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الأرصدة من القيود المرحلة فقط. الموجب على الموظف، والسالب مستحق له. طلبات السلف غير المصروفة لا تدخل في هذه الأرقام.</div>'+table(['الموظف','الحالة','طبيعة الذمة','الحساب','إجمالي المدين','إجمالي الدائن','الرصيد واتجاهه'],financial.map(function(x){var b=num(x.outstanding_balance),dir=b>0?badge('على الموظف','warn'):b<0?badge('مستحق للموظف','ok'):badge('متزن','muted');return tr([esc(x.employee_name||'-'),esc(x.employee_status||'-'),esc(types[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',dir+' <b class="mr-2">'+money(Math.abs(b))+' ج.م</b>'])}));
32569:  cn.innerHTML='<div class="space-y-5">'+card('المديونيات والأرصدة المالية المرحلة','مصدر موحد من دفتر الموظفين دون تعديل أرصدة',financialBody)+card('السلف والقروض','طلب → اعتماد → سند صرف مركزي → سداد نقدي عبر Receipts أو استقطاع رواتب حسب النوع',table(['الرقم','الموظف','نوع التمويل','القيمة','القسط','المتبقي','الحالة','سند الصرف','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف عبر Payments','disburse-advance:'+x.id,'bg-emerald-600 text-white'):'';return tr([esc(x.advance_no),esc(x.employee_name),esc(types[x.advance_nature||'SALARY_ADVANCE']),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),x.cash_box_id?badge('مرحل','ok'):badge('غير مصروف','warn'),a])})),btn('طلب سلفة/قرض جديد','new-advance'))+'</div>';
32570: }
32571:   async function disburseAdvance(id){
32572:     var tr=await supabase.from('treasury').select('id,account_name,account_code,type,current_balance,is_active').eq('company_id',H.companyId).eq('is_active',true).in('type',['Cash','Bank']).order('account_name');
32573:     if(tr.error)throw tr.error;
32574:     var rows=tr.data||[];
32575:     if(!rows.length){toast('لا توجد خزينة أو حساب بنكي فعال للصرف','error');return;}
32576:     var opts=rows.map(function(x){return '<option value="'+esc(x.id)+'">'+esc(x.account_name||x.account_code)+' · '+esc(x.type)+' · '+money(x.current_balance)+'</option>';}).join('');
32577:     var r=await Swal.fire({title:'صرف السلفة عبر سند Payments',html:'<div class="text-right text-sm text-slate-600 mb-2">سيتم إنشاء سند صرف مركزي وقيد محاسبي وربطه بالسلفة والموظف.</div><select id="hr-advance-treasury" class="swal2-select w-full">'+opts+'</select>',showCancelButton:true,confirmButtonText:'إنشاء سند الصرف',cancelButtonText:'إلغاء',preConfirm:function(){var t=E('hr-advance-treasury');if(!t||!t.value){Swal.showValidationMessage('اختر خزينة الصرف');return false;}return t.value;}});
32578:     if(!r.isConfirmed)return;
32579:     await c('advance.disburse',{advance_id:id,treasury_id:r.value},'disburse-advance:'+id);
32580:     toast('تم الصرف من خلال سند Payments مركزي وربطه بالسلفة','success');
32581:     return render();
32582:   }
32583:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
32584:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
32585:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[],fb=z[7].financial_balances||[],fl=z[7].financial_ledger||[];var financialReceivable=0,financialPayable=0;fb.forEach(function(x){var balance=num(x.outstanding_balance);if(balance>0)financialReceivable+=balance;else if(balance<0)financialPayable+=Math.abs(balance)});var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الموقف المالي المرحّل','ملخص مستقل لكل حساب وطبيعة ذمة — دون مقاصة بين ما على الموظف وما له','<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">'+stat('إجمالي المديونية على الموظف',money(financialReceivable)+' ج.م','fa-arrow-up','bg-amber-50 text-amber-700')+stat('إجمالي المستحق للموظف',money(financialPayable)+' ج.م','fa-arrow-down','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الموجب يمثل مديونية على الموظف، والسالب يمثل مبلغًا مستحقًا له. هذه الأرقام ناتجة عن قيود Posted فقط.</div>'+table(['طبيعة الذمة','الحساب','مدين','دائن','الرصيد','الاتجاه'],fb.map(function(x){var b=num(x.outstanding_balance),n={OPERATIONAL_CUSTODY:'عهدة تشغيلية',TEMPORARY_ADVANCE:'سلفة مؤقتة',SALARY_ADVANCE:'سلفة راتب',EMPLOYEE_LOAN:'قرض موظف',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};return tr([esc(n[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',money(Math.abs(b))+' ج.م',b>0?badge('على الموظف','warn'):b<0?badge('مستحق له','ok'):badge('متزن','muted')])})))+card('آخر الحركات المالية المرحّلة','آخر 30 حركة — RPC يعيد 200 كحد أقصى',table(['التاريخ','رقم القيد','نوع القيد','الحساب','المرجع / البيان','مدين','دائن'],fl.slice(0,30).map(function(x){return tr([date(x.entry_date),esc(x.entry_code||'-'),esc(x.entry_type||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),esc(x.reference||x.description||'-'),money(x.debit)+' ج.م',money(x.credit)+' ج.م'])})))+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
32586:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
32587:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
32588:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
32589:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
32590:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
32591:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
32592:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
32593:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
32594:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
32595:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
32596:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
32597:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
32598:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
32599:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
32600:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
32601:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
32602:   async function advance(){await loadPeople();simple('سلفة أو قرض موظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع التمويل','x-nature',[{value:'SALARY_ADVANCE',label:'سلفة راتب — تستقطع من الرواتب'},{value:'TEMPORARY_ADVANCE',label:'سلفة مؤقتة — تسدد نقدًا أو بتسوية معتمدة'},{value:'EMPLOYEE_LOAN',label:'قرض موظف — أقساط أو سداد نقدي'}],'SALARY_ADVANCE')+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,advance_nature:E('x-nature').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
32603:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
32604:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
32605:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
32606:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
32607:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
32608:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
32609:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance')return disburseAdvance(id);if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
32610:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var refresh=function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)};var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},refresh)});H.channel.on('postgres_changes',{event:'*',schema:'public',table:'journal_lines',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'*',schema:'public',table:'cash_box',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'journal_entries',filter:'status=eq.Posted'},refresh);H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
32611:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
32612:   (function installModalResilience(){
32613:     document.addEventListener('click',function(e){
32614:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32615:       if(!ac)return;
32616:       var page=E('rw-page-container');
32617:       if(page&&page.contains(ac))return;
32618:       e.preventDefault();
32619:       handle(ac.getAttribute('data-hr-action'));
32620:     },true);
32621:     window.addEventListener('unhandledrejection',function(e){
32622:       var root=E('rw-hr-modal-root');
32623:       if(!root)return;
32624:       e.preventDefault();
32625:       var msg=e.reason&&(e.reason.message||String(e.reason));
32626:       if(msg)toast(msg,'error');
32627:     });
32628:     try{
32629:       var mo=new MutationObserver(function(){
32630:         var root=E('rw-hr-modal-root');
32631:         if(!root||!E('hr360'))return;
32632:         var f=E('rw-hr-form');
32633:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32634:       });
32635:       mo.observe(document.body,{childList:true,subtree:true});
32636:     }catch(e){}
32637:   }());
32638: 
32639: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
32640: 
32641: 
32642: // ============================================================
32643: // RW_CRM – إدارة علاقات العملاء (CRM)
32644: // ============================================================
32645: var RW_CRM = (function() {
32646:     'use strict';
32647: 
32648:     var state = {
32649:         customers: [],
32650:         assignees: [],
32651:         kpi: {},
32652:         search: '',
32653:         activeOnly: false,
32654:         searchTimer: null
32655:     };
32656: 
32657:     function _esc(s) {
32658:         return String(s == null ? '' : s)
32659:             .replace(/&/g, '&amp;')
32660:             .replace(/</g, '&lt;')
32661:             .replace(/>/g, '&gt;')
32662:             .replace(/"/g, '&quot;')
32663:             .replace(/'/g, '&#39;');
32664:     }
32665: 
32666:     function _fmtNum(n) {
32667:         return Number(n || 0).toLocaleString('ar-EG');
32668:     }
32669: 
32670:     function _fmtMoney(n) {
32671:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
32672:     }
32673: 
32674:     function _today() {
32675:         var d = new Date();
32676:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
--- WINDOW 29674-29884 around 29704 ---
29674:                         '<td class="p-2">' +
29675:                         _esc(row.email) +
29676:                         '</td>' +
29677:                         '<td class="p-2">' +
29678:                         _esc(row.role) +
29679:                         '</td>' +
29680:                         '<td class="p-2">' +
29681:                         _esc(row.status) +
29682:                         '</td>' +
29683:                         '</tr>'
29684:                     );
29685:                 });
29686: 
29687:             html =
29688:                 '<h4 class="font-bold mb-3">قائمة الموظفين</h4>' +
29689:                 _table(
29690:                     [
29691:                         'الاسم',
29692:                         'البريد',
29693:                         'الدور',
29694:                         'الحالة'
29695:                     ],
29696:                     rows28
29697:                 );
29698:         }
29699: 
29700:         else if (reportId === 'hr-attendance') {
29701: 
29702:             var hrAttendanceReport =
29703:                 await supabase.rpc(
29704:                     'hr_query',
29705:                     {
29706:                         p_view: 'attendance',
29707:                         p_payload: {
29708:                             from: fromDate,
29709:                             to: toDate,
29710:                             limit: 5000
29711:                         }
29712:                     }
29713:                 );
29714: 
29715:             if (hrAttendanceReport.error) {
29716:                 throw hrAttendanceReport.error;
29717:             }
29718: 
29719:             var hrAttendancePayload =
29720:                 hrAttendanceReport.data || {};
29721: 
29722:             if (hrAttendancePayload.success === false) {
29723:                 throw new Error(
29724:                     hrAttendancePayload.msg ||
29725:                     hrAttendancePayload.code ||
29726:                     'لا توجد صلاحية أو مصدر صالح لتقرير الحضور'
29727:                 );
29728:             }
29729: 
29730:             var hrAttendanceRows =
29731:                 Array.isArray(hrAttendancePayload.rows)
29732:                     ? hrAttendancePayload.rows
29733:                     : [];
29734: 
29735:             var attendanceWorkedHours = 0;
29736:             var attendanceLateMinutes = 0;
29737:             var attendanceOvertimeHours = 0;
29738: 
29739:             var hrAttendanceTableRows =
29740:                 hrAttendanceRows.map(function(row) {
29741: 
29742:                     attendanceWorkedHours +=
29743:                         Number(row.worked_hours) || 0;
29744: 
29745:                     attendanceLateMinutes +=
29746:                         Number(row.late_minutes) || 0;
29747: 
29748:                     attendanceOvertimeHours +=
29749:                         Number(row.overtime_hours) || 0;
29750: 
29751:                     return (
29752:                         '<tr class="border-t">' +
29753:                         '<td class="p-2">' +
29754:                         _esc(row.attendance_date) +
29755:                         '</td>' +
29756:                         '<td class="p-2 font-semibold">' +
29757:                         _esc(row.employee_name || row.email || '') +
29758:                         '</td>' +
29759:                         '<td class="p-2">' +
29760:                         _esc(row.status || '') +
29761:                         '</td>' +
29762:                         '<td class="p-2 text-center">' +
29763:                         _esc(
29764:                             row.check_in
29765:                                 ? new Date(row.check_in).toLocaleTimeString(
29766:                                     'ar-EG',
29767:                                     {
29768:                                         hour: '2-digit',
29769:                                         minute: '2-digit'
29770:                                     }
29771:                                   )
29772:                                 : '-'
29773:                         ) +
29774:                         '</td>' +
29775:                         '<td class="p-2 text-center">' +
29776:                         _esc(
29777:                             row.check_out
29778:                                 ? new Date(row.check_out).toLocaleTimeString(
29779:                                     'ar-EG',
29780:                                     {
29781:                                         hour: '2-digit',
29782:                                         minute: '2-digit'
29783:                                     }
29784:                                   )
29785:                                 : '-'
29786:                         ) +
29787:                         '</td>' +
29788:                         '<td class="p-2 text-center font-bold">' +
29789:                         _fmtNum(row.worked_hours) +
29790:                         '</td>' +
29791:                         '<td class="p-2 text-center">' +
29792:                         _fmtNum(row.late_minutes) +
29793:                         '</td>' +
29794:                         '<td class="p-2 text-center">' +
29795:                         _fmtNum(row.overtime_hours) +
29796:                         '</td>' +
29797:                         '<td class="p-2 text-center">' +
29798:                         _fmtNum(row.absence_minutes) +
29799:                         '</td>' +
29800:                         '</tr>'
29801:                     );
29802:                 });
29803: 
29804:             html =
29805:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
29806:                 '<div class="mb-4 text-xs text-gray-500">' +
29807:                 'المصدر: Production hr_query(attendance)' +
29808:                 '</div>' +
29809:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
29810:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
29811:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
29812:                 '<div class="text-lg font-black">' +
29813:                 _fmtNum(hrAttendanceRows.length) +
29814:                 '</div></div>' +
29815:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
29816:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
29817:                 '<div class="text-lg font-black">' +
29818:                 _fmtNum(attendanceWorkedHours) +
29819:                 '</div></div>' +
29820:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
29821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
29822:                 '<div class="text-lg font-black">' +
29823:                 _fmtNum(attendanceLateMinutes) +
29824:                 '</div></div>' +
29825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
29826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
29827:                 '<div class="text-lg font-black">' +
29828:                 _fmtNum(attendanceOvertimeHours) +
29829:                 '</div></div>' +
29830:                 '</div>' +
29831:                 _table(
29832:                     [
29833:                         'التاريخ',
29834:                         'الموظف',
29835:                         'الحالة',
29836:                         'الدخول',
29837:                         'الخروج',
29838:                         'ساعات العمل',
29839:                         'التأخير بالدقائق',
29840:                         'الساعات الإضافية',
29841:                         'دقائق الغياب'
29842:                     ],
29843:                     hrAttendanceTableRows
29844:                 );
29845:         }
29846: 
29847:         else if (reportId === 'hr-salary') {
29848: 
29849:             var hrPayrollReport =
29850:                 await supabase.rpc(
29851:                     'hr_query',
29852:                     {
29853:                         p_view: 'payroll_runs',
29854:                         p_payload: {}
29855:                     }
29856:                 );
29857: 
29858:             if (hrPayrollReport.error) {
29859:                 throw hrPayrollReport.error;
29860:             }
29861: 
29862:             var hrPayrollPayload =
29863:                 hrPayrollReport.data || {};
29864: 
29865:             if (hrPayrollPayload.success === false) {
29866:                 throw new Error(
29867:                     hrPayrollPayload.msg ||
29868:                     hrPayrollPayload.code ||
29869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
29870:                 );
29871:             }
29872: 
29873:             var hrPayrollRows =
29874:                 Array.isArray(hrPayrollPayload.rows)
29875:                     ? hrPayrollPayload.rows
29876:                     : [];
29877: 
29878:             var filteredPayrollRows = [];
29879: 
29880:             var payrollGrossTotal = 0;
29881:             var payrollDeductionTotal = 0;
29882:             var payrollNetTotal = 0;
29883:             var payrollEmployeeTotal = 0;
29884: 
--- WINDOW 29777-29987 around 29807 ---
29777:                             row.check_out
29778:                                 ? new Date(row.check_out).toLocaleTimeString(
29779:                                     'ar-EG',
29780:                                     {
29781:                                         hour: '2-digit',
29782:                                         minute: '2-digit'
29783:                                     }
29784:                                   )
29785:                                 : '-'
29786:                         ) +
29787:                         '</td>' +
29788:                         '<td class="p-2 text-center font-bold">' +
29789:                         _fmtNum(row.worked_hours) +
29790:                         '</td>' +
29791:                         '<td class="p-2 text-center">' +
29792:                         _fmtNum(row.late_minutes) +
29793:                         '</td>' +
29794:                         '<td class="p-2 text-center">' +
29795:                         _fmtNum(row.overtime_hours) +
29796:                         '</td>' +
29797:                         '<td class="p-2 text-center">' +
29798:                         _fmtNum(row.absence_minutes) +
29799:                         '</td>' +
29800:                         '</tr>'
29801:                     );
29802:                 });
29803: 
29804:             html =
29805:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
29806:                 '<div class="mb-4 text-xs text-gray-500">' +
29807:                 'المصدر: Production hr_query(attendance)' +
29808:                 '</div>' +
29809:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
29810:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
29811:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
29812:                 '<div class="text-lg font-black">' +
29813:                 _fmtNum(hrAttendanceRows.length) +
29814:                 '</div></div>' +
29815:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
29816:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
29817:                 '<div class="text-lg font-black">' +
29818:                 _fmtNum(attendanceWorkedHours) +
29819:                 '</div></div>' +
29820:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
29821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
29822:                 '<div class="text-lg font-black">' +
29823:                 _fmtNum(attendanceLateMinutes) +
29824:                 '</div></div>' +
29825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
29826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
29827:                 '<div class="text-lg font-black">' +
29828:                 _fmtNum(attendanceOvertimeHours) +
29829:                 '</div></div>' +
29830:                 '</div>' +
29831:                 _table(
29832:                     [
29833:                         'التاريخ',
29834:                         'الموظف',
29835:                         'الحالة',
29836:                         'الدخول',
29837:                         'الخروج',
29838:                         'ساعات العمل',
29839:                         'التأخير بالدقائق',
29840:                         'الساعات الإضافية',
29841:                         'دقائق الغياب'
29842:                     ],
29843:                     hrAttendanceTableRows
29844:                 );
29845:         }
29846: 
29847:         else if (reportId === 'hr-salary') {
29848: 
29849:             var hrPayrollReport =
29850:                 await supabase.rpc(
29851:                     'hr_query',
29852:                     {
29853:                         p_view: 'payroll_runs',
29854:                         p_payload: {}
29855:                     }
29856:                 );
29857: 
29858:             if (hrPayrollReport.error) {
29859:                 throw hrPayrollReport.error;
29860:             }
29861: 
29862:             var hrPayrollPayload =
29863:                 hrPayrollReport.data || {};
29864: 
29865:             if (hrPayrollPayload.success === false) {
29866:                 throw new Error(
29867:                     hrPayrollPayload.msg ||
29868:                     hrPayrollPayload.code ||
29869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
29870:                 );
29871:             }
29872: 
29873:             var hrPayrollRows =
29874:                 Array.isArray(hrPayrollPayload.rows)
29875:                     ? hrPayrollPayload.rows
29876:                     : [];
29877: 
29878:             var filteredPayrollRows = [];
29879: 
29880:             var payrollGrossTotal = 0;
29881:             var payrollDeductionTotal = 0;
29882:             var payrollNetTotal = 0;
29883:             var payrollEmployeeTotal = 0;
29884: 
29885:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
29886: 
29887:                 var payrollRow = hrPayrollRows[pr] || {};
29888: 
29889:                 var periodStart =
29890:                     String(
29891:                         payrollRow.start_date ||
29892:                         ''
29893:                     ).slice(0, 10);
29894: 
29895:                 var periodEnd =
29896:                     String(
29897:                         payrollRow.end_date ||
29898:                         ''
29899:                     ).slice(0, 10);
29900: 
29901:                 if (
29902:                     periodStart &&
29903:                     periodEnd &&
29904:                     periodEnd < fromDate
29905:                 ) {
29906:                     continue;
29907:                 }
29908: 
29909:                 if (
29910:                     periodStart &&
29911:                     periodEnd &&
29912:                     periodStart > toDate
29913:                 ) {
29914:                     continue;
29915:                 }
29916: 
29917:                 filteredPayrollRows.push(
29918:                     payrollRow
29919:                 );
29920: 
29921:                 payrollGrossTotal +=
29922:                     Number(payrollRow.gross_total) || 0;
29923: 
29924:                 payrollDeductionTotal +=
29925:                     Number(payrollRow.deduction_total) || 0;
29926: 
29927:                 payrollNetTotal +=
29928:                     Number(payrollRow.net_total) || 0;
29929: 
29930:                 payrollEmployeeTotal +=
29931:                     Number(payrollRow.employee_count) || 0;
29932:             }
29933: 
29934:             var payrollTableRows =
29935:                 filteredPayrollRows.map(function(row) {
29936: 
29937:                     return (
29938:                         '<tr class="border-t">' +
29939:                         '<td class="p-2">' +
29940:                         _esc(row.run_no || '') +
29941:                         '</td>' +
29942:                         '<td class="p-2 font-semibold">' +
29943:                         _esc(row.period_code || '') +
29944:                         '</td>' +
29945:                         '<td class="p-2">' +
29946:                         _esc(row.start_date || '') +
29947:                         ' → ' +
29948:                         _esc(row.end_date || '') +
29949:                         '</td>' +
29950:                         '<td class="p-2 text-center">' +
29951:                         _fmtNum(row.employee_count) +
29952:                         '</td>' +
29953:                         '<td class="p-2 text-center">' +
29954:                         _fmtNum(row.gross_total) +
29955:                         '</td>' +
29956:                         '<td class="p-2 text-center">' +
29957:                         _fmtNum(row.deduction_total) +
29958:                         '</td>' +
29959:                         '<td class="p-2 text-center font-bold">' +
29960:                         _fmtNum(row.net_total) +
29961:                         '</td>' +
29962:                         '<td class="p-2">' +
29963:                         _esc(row.status || '') +
29964:                         '</td>' +
29965:                         '</tr>'
29966:                     );
29967:                 });
29968: 
29969:             html =
29970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
29971:                 '<div class="mb-4 text-xs text-gray-500">' +
29972:                 'المصدر: Production hr_query(payroll_runs)' +
29973:                 '</div>' +
29974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
29975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
29976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
29977:                 '<div class="text-lg font-black">' +
29978:                 _fmtNum(filteredPayrollRows.length) +
29979:                 '</div></div>' +
29980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
29981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
29982:                 '<div class="text-lg font-black">' +
29983:                 _fmtNum(payrollGrossTotal) +
29984:                 '</div></div>' +
29985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
29986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
29987:                 '<div class="text-lg font-black">' +
--- WINDOW 29821-30031 around 29851 ---
29821:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
29822:                 '<div class="text-lg font-black">' +
29823:                 _fmtNum(attendanceLateMinutes) +
29824:                 '</div></div>' +
29825:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
29826:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
29827:                 '<div class="text-lg font-black">' +
29828:                 _fmtNum(attendanceOvertimeHours) +
29829:                 '</div></div>' +
29830:                 '</div>' +
29831:                 _table(
29832:                     [
29833:                         'التاريخ',
29834:                         'الموظف',
29835:                         'الحالة',
29836:                         'الدخول',
29837:                         'الخروج',
29838:                         'ساعات العمل',
29839:                         'التأخير بالدقائق',
29840:                         'الساعات الإضافية',
29841:                         'دقائق الغياب'
29842:                     ],
29843:                     hrAttendanceTableRows
29844:                 );
29845:         }
29846: 
29847:         else if (reportId === 'hr-salary') {
29848: 
29849:             var hrPayrollReport =
29850:                 await supabase.rpc(
29851:                     'hr_query',
29852:                     {
29853:                         p_view: 'payroll_runs',
29854:                         p_payload: {}
29855:                     }
29856:                 );
29857: 
29858:             if (hrPayrollReport.error) {
29859:                 throw hrPayrollReport.error;
29860:             }
29861: 
29862:             var hrPayrollPayload =
29863:                 hrPayrollReport.data || {};
29864: 
29865:             if (hrPayrollPayload.success === false) {
29866:                 throw new Error(
29867:                     hrPayrollPayload.msg ||
29868:                     hrPayrollPayload.code ||
29869:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
29870:                 );
29871:             }
29872: 
29873:             var hrPayrollRows =
29874:                 Array.isArray(hrPayrollPayload.rows)
29875:                     ? hrPayrollPayload.rows
29876:                     : [];
29877: 
29878:             var filteredPayrollRows = [];
29879: 
29880:             var payrollGrossTotal = 0;
29881:             var payrollDeductionTotal = 0;
29882:             var payrollNetTotal = 0;
29883:             var payrollEmployeeTotal = 0;
29884: 
29885:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
29886: 
29887:                 var payrollRow = hrPayrollRows[pr] || {};
29888: 
29889:                 var periodStart =
29890:                     String(
29891:                         payrollRow.start_date ||
29892:                         ''
29893:                     ).slice(0, 10);
29894: 
29895:                 var periodEnd =
29896:                     String(
29897:                         payrollRow.end_date ||
29898:                         ''
29899:                     ).slice(0, 10);
29900: 
29901:                 if (
29902:                     periodStart &&
29903:                     periodEnd &&
29904:                     periodEnd < fromDate
29905:                 ) {
29906:                     continue;
29907:                 }
29908: 
29909:                 if (
29910:                     periodStart &&
29911:                     periodEnd &&
29912:                     periodStart > toDate
29913:                 ) {
29914:                     continue;
29915:                 }
29916: 
29917:                 filteredPayrollRows.push(
29918:                     payrollRow
29919:                 );
29920: 
29921:                 payrollGrossTotal +=
29922:                     Number(payrollRow.gross_total) || 0;
29923: 
29924:                 payrollDeductionTotal +=
29925:                     Number(payrollRow.deduction_total) || 0;
29926: 
29927:                 payrollNetTotal +=
29928:                     Number(payrollRow.net_total) || 0;
29929: 
29930:                 payrollEmployeeTotal +=
29931:                     Number(payrollRow.employee_count) || 0;
29932:             }
29933: 
29934:             var payrollTableRows =
29935:                 filteredPayrollRows.map(function(row) {
29936: 
29937:                     return (
29938:                         '<tr class="border-t">' +
29939:                         '<td class="p-2">' +
29940:                         _esc(row.run_no || '') +
29941:                         '</td>' +
29942:                         '<td class="p-2 font-semibold">' +
29943:                         _esc(row.period_code || '') +
29944:                         '</td>' +
29945:                         '<td class="p-2">' +
29946:                         _esc(row.start_date || '') +
29947:                         ' → ' +
29948:                         _esc(row.end_date || '') +
29949:                         '</td>' +
29950:                         '<td class="p-2 text-center">' +
29951:                         _fmtNum(row.employee_count) +
29952:                         '</td>' +
29953:                         '<td class="p-2 text-center">' +
29954:                         _fmtNum(row.gross_total) +
29955:                         '</td>' +
29956:                         '<td class="p-2 text-center">' +
29957:                         _fmtNum(row.deduction_total) +
29958:                         '</td>' +
29959:                         '<td class="p-2 text-center font-bold">' +
29960:                         _fmtNum(row.net_total) +
29961:                         '</td>' +
29962:                         '<td class="p-2">' +
29963:                         _esc(row.status || '') +
29964:                         '</td>' +
29965:                         '</tr>'
29966:                     );
29967:                 });
29968: 
29969:             html =
29970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
29971:                 '<div class="mb-4 text-xs text-gray-500">' +
29972:                 'المصدر: Production hr_query(payroll_runs)' +
29973:                 '</div>' +
29974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
29975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
29976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
29977:                 '<div class="text-lg font-black">' +
29978:                 _fmtNum(filteredPayrollRows.length) +
29979:                 '</div></div>' +
29980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
29981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
29982:                 '<div class="text-lg font-black">' +
29983:                 _fmtNum(payrollGrossTotal) +
29984:                 '</div></div>' +
29985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
29986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
29987:                 '<div class="text-lg font-black">' +
29988:                 _fmtNum(payrollDeductionTotal) +
29989:                 '</div></div>' +
29990:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
29991:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
29992:                 '<div class="text-lg font-black">' +
29993:                 _fmtNum(payrollNetTotal) +
29994:                 '</div></div>' +
29995:                 '</div>' +
29996:                 '<div class="mb-4 text-xs text-gray-500">' +
29997:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
29998:                 _fmtNum(payrollEmployeeTotal) +
29999:                 '</div>' +
30000:                 _table(
30001:                     [
30002:                         'رقم المسير',
30003:                         'الفترة',
30004:                         'النطاق',
30005:                         'الموظفون',
30006:                         'إجمالي الأجور',
30007:                         'الاستقطاعات',
30008:                         'الصافي',
30009:                         'الحالة'
30010:                     ],
30011:                     payrollTableRows
30012:                 );
30013:         }
30014:         else {
30015: 
30016:             html =
30017:                 '<div class="text-center py-4 text-gray-500">' +
30018:                 'هذا التقرير غير متوفر بعد' +
30019:                 '</div>';
30020:         }
30021: 
30022:         safeHTML(
30023:     resultDiv,
30024:     html +
30025:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
30026:     '<span>المصدر: Production</span>' +
30027:     '<span>آخر تنفيذ: ' +
30028:     _esc(
30029:         new Date().toLocaleString('ar-EG')
30030:     ) +
30031:     '</span>' +
--- WINDOW 29942-30152 around 29972 ---
29942:                         '<td class="p-2 font-semibold">' +
29943:                         _esc(row.period_code || '') +
29944:                         '</td>' +
29945:                         '<td class="p-2">' +
29946:                         _esc(row.start_date || '') +
29947:                         ' → ' +
29948:                         _esc(row.end_date || '') +
29949:                         '</td>' +
29950:                         '<td class="p-2 text-center">' +
29951:                         _fmtNum(row.employee_count) +
29952:                         '</td>' +
29953:                         '<td class="p-2 text-center">' +
29954:                         _fmtNum(row.gross_total) +
29955:                         '</td>' +
29956:                         '<td class="p-2 text-center">' +
29957:                         _fmtNum(row.deduction_total) +
29958:                         '</td>' +
29959:                         '<td class="p-2 text-center font-bold">' +
29960:                         _fmtNum(row.net_total) +
29961:                         '</td>' +
29962:                         '<td class="p-2">' +
29963:                         _esc(row.status || '') +
29964:                         '</td>' +
29965:                         '</tr>'
29966:                     );
29967:                 });
29968: 
29969:             html =
29970:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
29971:                 '<div class="mb-4 text-xs text-gray-500">' +
29972:                 'المصدر: Production hr_query(payroll_runs)' +
29973:                 '</div>' +
29974:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
29975:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
29976:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
29977:                 '<div class="text-lg font-black">' +
29978:                 _fmtNum(filteredPayrollRows.length) +
29979:                 '</div></div>' +
29980:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
29981:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
29982:                 '<div class="text-lg font-black">' +
29983:                 _fmtNum(payrollGrossTotal) +
29984:                 '</div></div>' +
29985:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
29986:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
29987:                 '<div class="text-lg font-black">' +
29988:                 _fmtNum(payrollDeductionTotal) +
29989:                 '</div></div>' +
29990:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
29991:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
29992:                 '<div class="text-lg font-black">' +
29993:                 _fmtNum(payrollNetTotal) +
29994:                 '</div></div>' +
29995:                 '</div>' +
29996:                 '<div class="mb-4 text-xs text-gray-500">' +
29997:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
29998:                 _fmtNum(payrollEmployeeTotal) +
29999:                 '</div>' +
30000:                 _table(
30001:                     [
30002:                         'رقم المسير',
30003:                         'الفترة',
30004:                         'النطاق',
30005:                         'الموظفون',
30006:                         'إجمالي الأجور',
30007:                         'الاستقطاعات',
30008:                         'الصافي',
30009:                         'الحالة'
30010:                     ],
30011:                     payrollTableRows
30012:                 );
30013:         }
30014:         else {
30015: 
30016:             html =
30017:                 '<div class="text-center py-4 text-gray-500">' +
30018:                 'هذا التقرير غير متوفر بعد' +
30019:                 '</div>';
30020:         }
30021: 
30022:         safeHTML(
30023:     resultDiv,
30024:     html +
30025:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
30026:     '<span>المصدر: Production</span>' +
30027:     '<span>آخر تنفيذ: ' +
30028:     _esc(
30029:         new Date().toLocaleString('ar-EG')
30030:     ) +
30031:     '</span>' +
30032:     '</div>'
30033: );
30034: 
30035:     } catch (e) {
30036: 
30037:         console.error(
30038:             'RW_Reports_Comprehensive._generateReport',
30039:             e
30040:         );
30041: 
30042:         safeHTML(
30043:             resultDiv,
30044:             '<div class="text-center py-8 text-red-500">' +
30045:             'فشل تحميل التقرير: ' +
30046:             _esc(
30047:                 e.message ||
30048:                 'خطأ غير معروف'
30049:             ) +
30050:             '</div>'
30051:         );
30052:     }
30053: }
30054: 
30055: function _exportReportCsv() {
30056:     var resultDiv = byId('report-result');
30057: 
30058:     if (!resultDiv) {
30059:         _showToast('لا يوجد تقرير للتصدير', 'info');
30060:         return;
30061:     }
30062: 
30063:     var table = resultDiv.querySelector('table');
30064: 
30065:     if (!table) {
30066:         _showToast('لا يوجد جدول قابل للتصدير', 'info');
30067:         return;
30068:     }
30069: 
30070:     var rows = table.querySelectorAll('tr');
30071:     var csv = [];
30072: 
30073:     function csvCell(value) {
30074:         var s = String(value == null ? '' : value)
30075:             .replace(/\r?\n|\r/g, ' ')
30076:             .replace(/"/g, '""');
30077: 
30078:         return '"' + s + '"';
30079:     }
30080: 
30081:     for (var i = 0; i < rows.length; i++) {
30082:         var cells = rows[i].querySelectorAll('th,td');
30083:         var line = [];
30084: 
30085:         for (var j = 0; j < cells.length; j++) {
30086:             line.push(csvCell(cells[j].innerText || ''));
30087:         }
30088: 
30089:         csv.push(line.join(','));
30090:     }
30091: 
30092:     var blob = new Blob(
30093:         ['\uFEFF' + csv.join('\r\n')],
30094:         { type: 'text/csv;charset=utf-8;' }
30095:     );
30096: 
30097:     var url = URL.createObjectURL(blob);
30098:     var a = document.createElement('a');
30099: 
30100:     a.href = url;
30101:     a.download =
30102:         'rawaea-report-' +
30103:         String(_currentReport || 'report') +
30104:         '-' +
30105:         new Date().toISOString().slice(0, 10) +
30106:         '.csv';
30107: 
30108:     document.body.appendChild(a);
30109:     a.click();
30110:     document.body.removeChild(a);
30111: 
30112:     URL.revokeObjectURL(url);
30113: }
30114: function _printReport() {
30115:     var resultDiv = byId('report-result');
30116: 
30117:     if (!resultDiv || !resultDiv.innerHTML) {
30118:         _showToast('لا يوجد تقرير للطباعة', 'info');
30119:         return;
30120:     }
30121: 
30122:     var printWindow = window.open('', '_blank');
30123: 
30124:     if (!printWindow) {
30125:         _showToast('الرجاء السماح بالنوافذ المنبثقة', 'warning');
30126:         return;
30127:     }
30128: 
30129:     var html =
30130:         '<!DOCTYPE html>' +
30131:         '<html dir="rtl">' +
30132:         '<head>' +
30133:         '<meta charset="UTF-8">' +
30134:         '<title>تقرير الروائع ERP</title>' +
30135:         '<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700;900&display=swap" rel="stylesheet">' +
30136:         '<style>' +
30137:         'body{font-family:Cairo,sans-serif;padding:20px;color:#111827}' +
30138:         'table{width:100%;border-collapse:collapse;margin-top:15px}' +
30139:         'th,td{border:1px solid #ddd;padding:8px}' +
30140:         'th{background:#f2f2f2;font-weight:800}' +
30141:         '.text-center{text-align:center}' +
30142:         '</style>' +
30143:         '</head>' +
30144:         '<body>' +
30145:         resultDiv.innerHTML +
30146:         '<script>window.onload=function(){window.print();};<\/script>' +
30147:         '</body></html>';
30148: 
30149:     printWindow.document.open();
30150:     printWindow.document.write(html);
30151:     printWindow.document.close();
30152: }
--- WINDOW 32465-32675 around 32495 ---
32465:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
32466:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
32467:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
32468: 
32469:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
32470:     }
32471: };
32472: window.RW_Views = RW_Views;
32473: // ============================================================
32474: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
32475: // ============================================================
32476: var RW_HR = (function() {
32477:  'use strict';
32478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
32479:   var T=[
32480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
32481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
32482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
32483:   ];
32484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
32485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
32486:   function num(v){v=Number(v);return isFinite(v)?v:0}
32487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
32488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
32489:   function iso(v){return v?new Date(v).toISOString():null}
32490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
32491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
32492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
32493:   function opClear(k){if(k)delete H.ops[k]}
32494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
32495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
32496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
32497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
32498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
32499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
32500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
32501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
32502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
32503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
32504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
32505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
32506:  function modal(title,body,onSubmit,key){
32507:   var old=E('rw-hr-modal-root');
32508:   if(old)old.remove();
32509:   var r=document.createElement('div');
32510:   r.id='rw-hr-modal-root';
32511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
32512:   document.body.appendChild(r);
32513:   E('rw-hr-close').onclick=closeModal;
32514:   E('rw-hr-cancel').onclick=closeModal;
32515:   r.addEventListener('click',function(e){
32516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32517:     if(ac){
32518:       e.preventDefault();
32519:       handle(ac.getAttribute('data-hr-action'));
32520:     }
32521:   });
32522:   if(onSubmit===null){
32523:     var f=E('rw-hr-form');
32524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32525:   }else{
32526:     E('rw-hr-form').onsubmit=async function(e){
32527:       e.preventDefault();
32528:       var save=e.target.querySelector('button[type="submit"]');
32529:       try{
32530:         if(save){
32531:           save.disabled=true;
32532:           save.textContent='جارٍ الحفظ…';
32533:         }
32534:         await onSubmit(key||'form:'+Date.now());
32535:       }catch(err){
32536:         toast(err.message||'تعذر الحفظ','error');
32537:         if(save){
32538:           save.disabled=false;
32539:           save.textContent='حفظ';
32540:         }
32541:       }
32542:     };
32543:   }
32544: }
32545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
32546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
32547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
32548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
32549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
32550:   function employeeOpts(){return ppl()}
32551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
32553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
32555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
32556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
32557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
32558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
32559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
32560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
32561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
32562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
32563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
32564:   async function advancesTab(cn){
32565:  var d=await q('advances'),types={SALARY_ADVANCE:'سلفة راتب',TEMPORARY_ADVANCE:'سلفة مؤقتة',EMPLOYEE_LOAN:'قرض موظف',OPERATIONAL_CUSTODY:'عهدة تشغيلية',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};
32566:  var financial=d.financial_balances||[],debt=0,payable=0;
32567:  financial.forEach(function(x){var b=num(x.outstanding_balance);if(b>0)debt+=b;else if(b<0)payable+=Math.abs(b)});
32568:  var financialBody='<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-5">'+stat('إجمالي المديونية على الموظفين',money(debt)+' ج.م','fa-file-invoice-dollar','bg-amber-50 text-amber-700')+stat('مستحقات الموظفين لدى الشركة',money(payable)+' ج.م','fa-hand-holding-usd','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الأرصدة من القيود المرحلة فقط. الموجب على الموظف، والسالب مستحق له. طلبات السلف غير المصروفة لا تدخل في هذه الأرقام.</div>'+table(['الموظف','الحالة','طبيعة الذمة','الحساب','إجمالي المدين','إجمالي الدائن','الرصيد واتجاهه'],financial.map(function(x){var b=num(x.outstanding_balance),dir=b>0?badge('على الموظف','warn'):b<0?badge('مستحق للموظف','ok'):badge('متزن','muted');return tr([esc(x.employee_name||'-'),esc(x.employee_status||'-'),esc(types[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',dir+' <b class="mr-2">'+money(Math.abs(b))+' ج.م</b>'])}));
32569:  cn.innerHTML='<div class="space-y-5">'+card('المديونيات والأرصدة المالية المرحلة','مصدر موحد من دفتر الموظفين دون تعديل أرصدة',financialBody)+card('السلف والقروض','طلب → اعتماد → سند صرف مركزي → سداد نقدي عبر Receipts أو استقطاع رواتب حسب النوع',table(['الرقم','الموظف','نوع التمويل','القيمة','القسط','المتبقي','الحالة','سند الصرف','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف عبر Payments','disburse-advance:'+x.id,'bg-emerald-600 text-white'):'';return tr([esc(x.advance_no),esc(x.employee_name),esc(types[x.advance_nature||'SALARY_ADVANCE']),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),x.cash_box_id?badge('مرحل','ok'):badge('غير مصروف','warn'),a])})),btn('طلب سلفة/قرض جديد','new-advance'))+'</div>';
32570: }
32571:   async function disburseAdvance(id){
32572:     var tr=await supabase.from('treasury').select('id,account_name,account_code,type,current_balance,is_active').eq('company_id',H.companyId).eq('is_active',true).in('type',['Cash','Bank']).order('account_name');
32573:     if(tr.error)throw tr.error;
32574:     var rows=tr.data||[];
32575:     if(!rows.length){toast('لا توجد خزينة أو حساب بنكي فعال للصرف','error');return;}
32576:     var opts=rows.map(function(x){return '<option value="'+esc(x.id)+'">'+esc(x.account_name||x.account_code)+' · '+esc(x.type)+' · '+money(x.current_balance)+'</option>';}).join('');
32577:     var r=await Swal.fire({title:'صرف السلفة عبر سند Payments',html:'<div class="text-right text-sm text-slate-600 mb-2">سيتم إنشاء سند صرف مركزي وقيد محاسبي وربطه بالسلفة والموظف.</div><select id="hr-advance-treasury" class="swal2-select w-full">'+opts+'</select>',showCancelButton:true,confirmButtonText:'إنشاء سند الصرف',cancelButtonText:'إلغاء',preConfirm:function(){var t=E('hr-advance-treasury');if(!t||!t.value){Swal.showValidationMessage('اختر خزينة الصرف');return false;}return t.value;}});
32578:     if(!r.isConfirmed)return;
32579:     await c('advance.disburse',{advance_id:id,treasury_id:r.value},'disburse-advance:'+id);
32580:     toast('تم الصرف من خلال سند Payments مركزي وربطه بالسلفة','success');
32581:     return render();
32582:   }
32583:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
32584:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
32585:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[],fb=z[7].financial_balances||[],fl=z[7].financial_ledger||[];var financialReceivable=0,financialPayable=0;fb.forEach(function(x){var balance=num(x.outstanding_balance);if(balance>0)financialReceivable+=balance;else if(balance<0)financialPayable+=Math.abs(balance)});var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الموقف المالي المرحّل','ملخص مستقل لكل حساب وطبيعة ذمة — دون مقاصة بين ما على الموظف وما له','<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">'+stat('إجمالي المديونية على الموظف',money(financialReceivable)+' ج.م','fa-arrow-up','bg-amber-50 text-amber-700')+stat('إجمالي المستحق للموظف',money(financialPayable)+' ج.م','fa-arrow-down','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الموجب يمثل مديونية على الموظف، والسالب يمثل مبلغًا مستحقًا له. هذه الأرقام ناتجة عن قيود Posted فقط.</div>'+table(['طبيعة الذمة','الحساب','مدين','دائن','الرصيد','الاتجاه'],fb.map(function(x){var b=num(x.outstanding_balance),n={OPERATIONAL_CUSTODY:'عهدة تشغيلية',TEMPORARY_ADVANCE:'سلفة مؤقتة',SALARY_ADVANCE:'سلفة راتب',EMPLOYEE_LOAN:'قرض موظف',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};return tr([esc(n[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',money(Math.abs(b))+' ج.م',b>0?badge('على الموظف','warn'):b<0?badge('مستحق له','ok'):badge('متزن','muted')])})))+card('آخر الحركات المالية المرحّلة','آخر 30 حركة — RPC يعيد 200 كحد أقصى',table(['التاريخ','رقم القيد','نوع القيد','الحساب','المرجع / البيان','مدين','دائن'],fl.slice(0,30).map(function(x){return tr([date(x.entry_date),esc(x.entry_code||'-'),esc(x.entry_type||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),esc(x.reference||x.description||'-'),money(x.debit)+' ج.م',money(x.credit)+' ج.م'])})))+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
32586:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
32587:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
32588:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
32589:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
32590:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
32591:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
32592:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
32593:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
32594:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
32595:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
32596:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
32597:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
32598:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
32599:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
32600:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
32601:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
32602:   async function advance(){await loadPeople();simple('سلفة أو قرض موظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع التمويل','x-nature',[{value:'SALARY_ADVANCE',label:'سلفة راتب — تستقطع من الرواتب'},{value:'TEMPORARY_ADVANCE',label:'سلفة مؤقتة — تسدد نقدًا أو بتسوية معتمدة'},{value:'EMPLOYEE_LOAN',label:'قرض موظف — أقساط أو سداد نقدي'}],'SALARY_ADVANCE')+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,advance_nature:E('x-nature').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
32603:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
32604:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
32605:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
32606:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
32607:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
32608:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
32609:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance')return disburseAdvance(id);if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
32610:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var refresh=function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)};var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},refresh)});H.channel.on('postgres_changes',{event:'*',schema:'public',table:'journal_lines',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'*',schema:'public',table:'cash_box',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'journal_entries',filter:'status=eq.Posted'},refresh);H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
32611:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
32612:   (function installModalResilience(){
32613:     document.addEventListener('click',function(e){
32614:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32615:       if(!ac)return;
32616:       var page=E('rw-page-container');
32617:       if(page&&page.contains(ac))return;
32618:       e.preventDefault();
32619:       handle(ac.getAttribute('data-hr-action'));
32620:     },true);
32621:     window.addEventListener('unhandledrejection',function(e){
32622:       var root=E('rw-hr-modal-root');
32623:       if(!root)return;
32624:       e.preventDefault();
32625:       var msg=e.reason&&(e.reason.message||String(e.reason));
32626:       if(msg)toast(msg,'error');
32627:     });
32628:     try{
32629:       var mo=new MutationObserver(function(){
32630:         var root=E('rw-hr-modal-root');
32631:         if(!root||!E('hr360'))return;
32632:         var f=E('rw-hr-form');
32633:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32634:       });
32635:       mo.observe(document.body,{childList:true,subtree:true});
32636:     }catch(e){}
32637:   }());
32638: 
32639: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
32640: 
32641: 
32642: // ============================================================
32643: // RW_CRM – إدارة علاقات العملاء (CRM)
32644: // ============================================================
32645: var RW_CRM = (function() {
32646:     'use strict';
32647: 
32648:     var state = {
32649:         customers: [],
32650:         assignees: [],
32651:         kpi: {},
32652:         search: '',
32653:         activeOnly: false,
32654:         searchTimer: null
32655:     };
32656: 
32657:     function _esc(s) {
32658:         return String(s == null ? '' : s)
32659:             .replace(/&/g, '&amp;')
32660:             .replace(/</g, '&lt;')
32661:             .replace(/>/g, '&gt;')
32662:             .replace(/"/g, '&quot;')
32663:             .replace(/'/g, '&#39;');
32664:     }
32665: 
32666:     function _fmtNum(n) {
32667:         return Number(n || 0).toLocaleString('ar-EG');
32668:     }
32669: 
32670:     function _fmtMoney(n) {
32671:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
32672:     }
32673: 
32674:     function _today() {
32675:         var d = new Date();
--- WINDOW 32580-32790 around 32610 ---
32580:     toast('تم الصرف من خلال سند Payments مركزي وربطه بالسلفة','success');
32581:     return render();
32582:   }
32583:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
32584:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
32585:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[],fb=z[7].financial_balances||[],fl=z[7].financial_ledger||[];var financialReceivable=0,financialPayable=0;fb.forEach(function(x){var balance=num(x.outstanding_balance);if(balance>0)financialReceivable+=balance;else if(balance<0)financialPayable+=Math.abs(balance)});var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الموقف المالي المرحّل','ملخص مستقل لكل حساب وطبيعة ذمة — دون مقاصة بين ما على الموظف وما له','<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">'+stat('إجمالي المديونية على الموظف',money(financialReceivable)+' ج.م','fa-arrow-up','bg-amber-50 text-amber-700')+stat('إجمالي المستحق للموظف',money(financialPayable)+' ج.م','fa-arrow-down','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الموجب يمثل مديونية على الموظف، والسالب يمثل مبلغًا مستحقًا له. هذه الأرقام ناتجة عن قيود Posted فقط.</div>'+table(['طبيعة الذمة','الحساب','مدين','دائن','الرصيد','الاتجاه'],fb.map(function(x){var b=num(x.outstanding_balance),n={OPERATIONAL_CUSTODY:'عهدة تشغيلية',TEMPORARY_ADVANCE:'سلفة مؤقتة',SALARY_ADVANCE:'سلفة راتب',EMPLOYEE_LOAN:'قرض موظف',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};return tr([esc(n[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',money(Math.abs(b))+' ج.م',b>0?badge('على الموظف','warn'):b<0?badge('مستحق له','ok'):badge('متزن','muted')])})))+card('آخر الحركات المالية المرحّلة','آخر 30 حركة — RPC يعيد 200 كحد أقصى',table(['التاريخ','رقم القيد','نوع القيد','الحساب','المرجع / البيان','مدين','دائن'],fl.slice(0,30).map(function(x){return tr([date(x.entry_date),esc(x.entry_code||'-'),esc(x.entry_type||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),esc(x.reference||x.description||'-'),money(x.debit)+' ج.م',money(x.credit)+' ج.م'])})))+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
32586:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
32587:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
32588:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
32589:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
32590:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
32591:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
32592:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
32593:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
32594:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
32595:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
32596:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
32597:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
32598:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
32599:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
32600:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
32601:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
32602:   async function advance(){await loadPeople();simple('سلفة أو قرض موظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع التمويل','x-nature',[{value:'SALARY_ADVANCE',label:'سلفة راتب — تستقطع من الرواتب'},{value:'TEMPORARY_ADVANCE',label:'سلفة مؤقتة — تسدد نقدًا أو بتسوية معتمدة'},{value:'EMPLOYEE_LOAN',label:'قرض موظف — أقساط أو سداد نقدي'}],'SALARY_ADVANCE')+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,advance_nature:E('x-nature').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
32603:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
32604:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
32605:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
32606:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
32607:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
32608:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
32609:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance')return disburseAdvance(id);if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
32610:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var refresh=function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)};var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},refresh)});H.channel.on('postgres_changes',{event:'*',schema:'public',table:'journal_lines',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'*',schema:'public',table:'cash_box',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'journal_entries',filter:'status=eq.Posted'},refresh);H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
32611:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
32612:   (function installModalResilience(){
32613:     document.addEventListener('click',function(e){
32614:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32615:       if(!ac)return;
32616:       var page=E('rw-page-container');
32617:       if(page&&page.contains(ac))return;
32618:       e.preventDefault();
32619:       handle(ac.getAttribute('data-hr-action'));
32620:     },true);
32621:     window.addEventListener('unhandledrejection',function(e){
32622:       var root=E('rw-hr-modal-root');
32623:       if(!root)return;
32624:       e.preventDefault();
32625:       var msg=e.reason&&(e.reason.message||String(e.reason));
32626:       if(msg)toast(msg,'error');
32627:     });
32628:     try{
32629:       var mo=new MutationObserver(function(){
32630:         var root=E('rw-hr-modal-root');
32631:         if(!root||!E('hr360'))return;
32632:         var f=E('rw-hr-form');
32633:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32634:       });
32635:       mo.observe(document.body,{childList:true,subtree:true});
32636:     }catch(e){}
32637:   }());
32638: 
32639: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
32640: 
32641: 
32642: // ============================================================
32643: // RW_CRM – إدارة علاقات العملاء (CRM)
32644: // ============================================================
32645: var RW_CRM = (function() {
32646:     'use strict';
32647: 
32648:     var state = {
32649:         customers: [],
32650:         assignees: [],
32651:         kpi: {},
32652:         search: '',
32653:         activeOnly: false,
32654:         searchTimer: null
32655:     };
32656: 
32657:     function _esc(s) {
32658:         return String(s == null ? '' : s)
32659:             .replace(/&/g, '&amp;')
32660:             .replace(/</g, '&lt;')
32661:             .replace(/>/g, '&gt;')
32662:             .replace(/"/g, '&quot;')
32663:             .replace(/'/g, '&#39;');
32664:     }
32665: 
32666:     function _fmtNum(n) {
32667:         return Number(n || 0).toLocaleString('ar-EG');
32668:     }
32669: 
32670:     function _fmtMoney(n) {
32671:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
32672:     }
32673: 
32674:     function _today() {
32675:         var d = new Date();
32676:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
32677:         return local.toISOString().slice(0, 10);
32678:     }
32679: 
32680:     function _statusLabel(s) {
32681:         var map = {
32682:             Open: 'مفتوحة',
32683:             'معلقة': 'معلقة',
32684:             completed: 'مكتملة',
32685:             'مكتملة': 'مكتملة',
32686:             cancelled: 'ملغاة',
32687:             'ملغاة': 'ملغاة'
32688:         };
32689:         return map[s] || s || 'غير محددة';
32690:     }
32691: 
32692:     function _statusClass(s) {
32693:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
32694:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
32695:         return 'bg-amber-100 text-amber-700';
32696:     }
32697: 
32698:     function _assignedLabel(customer) {
32699:         var rows = Array.isArray(customer && customer.assigned_to) ? customer.assigned_to : [];
32700:         if (!rows.length) return 'غير مسند';
32701:         var active = rows.filter(function(x) { return x && x.active !== false; });
32702:         if (!active.length) active = rows;
32703:         return active.slice(0, 2).map(function(x) {
32704:             return x.name || x.email || '—';
32705:         }).join('، ') + (active.length > 2 ? ' +' + (active.length - 2) : '');
32706:     }
32707: 
32708:     async function _loadDirectory() {
32709:         var res = await supabase.rpc('crm_customer_directory', {
32710:             p_search: state.search || null,
32711:             p_active_only: state.activeOnly,
32712:             p_limit: 200,
32713:             p_offset: 0
32714:         });
32715:         if (res.error) throw res.error;
32716: 
32717:         var payload = res.data || {};
32718:         state.customers = Array.isArray(payload.customers) ? payload.customers : [];
32719:         state.assignees = Array.isArray(payload.assignees) ? payload.assignees : [];
32720:         state.kpi = payload.kpi || {};
32721:         return payload;
32722:     }
32723: 
32724:     function _renderKpis() {
32725:         var k = state.kpi || {};
32726:         return '<div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">' +
32727:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">إجمالي العملاء</div><div class="text-2xl font-black text-indigo-600 mt-2">' + _fmtNum(k.total_customers) + '</div></div>' +
32728:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">عملاء نشطون</div><div class="text-2xl font-black text-green-600 mt-2">' + _fmtNum(k.active_customers) + '</div></div>' +
32729:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">ذمم مسجلة</div><div class="text-2xl font-black text-red-600 mt-2">' + _fmtMoney(k.master_debt_total) + '</div></div>' +
32730:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متابعات مفتوحة</div><div class="text-2xl font-black text-amber-600 mt-2">' + _fmtNum(k.open_followups) + '</div></div>' +
32731:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متأخرة</div><div class="text-2xl font-black text-rose-600 mt-2">' + _fmtNum(k.overdue_followups) + '</div></div>' +
32732:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">مستحقة اليوم</div><div class="text-2xl font-black text-blue-600 mt-2">' + _fmtNum(k.due_today) + '</div></div>' +
32733:         '</div>';
32734:     }
32735: 
32736:     function _renderTable() {
32737:         if (!state.customers.length) {
32738:             return '<div class="text-center py-16 text-gray-400"><div class="text-5xl mb-3">👥</div><div class="font-black text-lg">لا توجد عملاء مطابقون</div><div class="text-sm mt-2">غيّر البحث أو الفلاتر ثم أعد المحاولة.</div></div>';
32739:         }
32740: 
32741:         var html = '<div class="overflow-x-auto"><table class="w-full text-sm">' +
32742:             '<thead class="bg-slate-50"><tr>' +
32743:             '<th class="p-3 text-right">العميل</th>' +
32744:             '<th class="p-3 text-right">التواصل</th>' +
32745:             '<th class="p-3 text-right">التصنيف</th>' +
32746:             '<th class="p-3 text-center">المبيعات</th>' +
32747:             '<th class="p-3 text-center">الأوردرات</th>' +
32748:             '<th class="p-3 text-center">المتابعة القادمة</th>' +
32749:             '<th class="p-3 text-right">المسؤول</th>' +
32750:             '<th class="p-3 text-center">الإجراء</th>' +
32751:             '</tr></thead><tbody>';
32752: 
32753:         for (var i = 0; i < state.customers.length; i++) {
32754:             var c = state.customers[i] || {};
32755:             var overdue = Number(c.overdue_followups || 0) > 0;
32756:             var next = c.next_followup_date ? String(c.next_followup_date) : '—';
32757: 
32758:             html += '<tr class="border-b hover:bg-slate-50">' +
32759:                 '<td class="p-3"><div class="font-black">' + _esc(c.name) + '</div><div class="text-xs text-gray-400">' + _esc(c.customer_code) + '</div></td>' +
32760:                 '<td class="p-3"><div>' + _esc(c.phone || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.area || '—') + '</div></td>' +
32761:                 '<td class="p-3"><div class="font-bold">' + _esc(c.customer_type || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.payment_type || '—') + '</div></td>' +
32762:                 '<td class="p-3 text-center font-black">' + _fmtMoney(c.sales_total) + '</td>' +
32763:                 '<td class="p-3 text-center font-black">' + _fmtNum(c.order_count) + '</td>' +
32764:                 '<td class="p-3 text-center"><span class="px-2 py-1 rounded-full text-xs font-black ' + (overdue ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-700') + '">' + _esc(next) + '</span></td>' +
32765:                 '<td class="p-3">' + _esc(_assignedLabel(c)) + '</td>' +
32766:                 '<td class="p-3 text-center"><button type="button" data-crm-open360="' + _esc(c.id) + '" class="px-4 py-2 bg-indigo-600 text-white rounded-xl font-black">متابعة</button></td>' +
32767:             '</tr>';
32768:         }
32769: 
32770:         return html + '</tbody></table></div>';
32771:     }
32772: 
32773:     function _bindDirectory() {
32774:         var search = byId('crm-search');
32775:         if (search) {
32776:             search.value = state.search;
32777:             search.addEventListener('input', function() {
32778:                 state.search = search.value.trim();
32779:                 clearTimeout(state.searchTimer);
32780:                 state.searchTimer = setTimeout(function() {
32781:                     _loadDirectory().then(function() {
32782:                         safeHTML(byId('crm-customers-list'), _renderTable());
32783:                         _bindOpen360();
32784:                         safeHTML(byId('crm-kpis'), _renderKpis());
32785:                     }).catch(function(e) {
32786:                         showToast(e.message || 'فشل البحث', 'error');
32787:                     });
32788:                 }, 250);
32789:             });
32790:         }
--- RW_HR_FULL 32476-32639 ---
32476: var RW_HR = (function() {
32477:  'use strict';
32478:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
32479:   var T=[
32480:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
32481:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
32482:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
32483:   ];
32484:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
32485:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
32486:   function num(v){v=Number(v);return isFinite(v)?v:0}
32487:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
32488:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
32489:   function iso(v){return v?new Date(v).toISOString():null}
32490:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
32491:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
32492:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
32493:   function opClear(k){if(k)delete H.ops[k]}
32494:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
32495:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
32496:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
32497:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
32498:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
32499:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
32500:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
32501:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
32502:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
32503:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
32504:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
32505:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
32506:  function modal(title,body,onSubmit,key){
32507:   var old=E('rw-hr-modal-root');
32508:   if(old)old.remove();
32509:   var r=document.createElement('div');
32510:   r.id='rw-hr-modal-root';
32511:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
32512:   document.body.appendChild(r);
32513:   E('rw-hr-close').onclick=closeModal;
32514:   E('rw-hr-cancel').onclick=closeModal;
32515:   r.addEventListener('click',function(e){
32516:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32517:     if(ac){
32518:       e.preventDefault();
32519:       handle(ac.getAttribute('data-hr-action'));
32520:     }
32521:   });
32522:   if(onSubmit===null){
32523:     var f=E('rw-hr-form');
32524:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32525:   }else{
32526:     E('rw-hr-form').onsubmit=async function(e){
32527:       e.preventDefault();
32528:       var save=e.target.querySelector('button[type="submit"]');
32529:       try{
32530:         if(save){
32531:           save.disabled=true;
32532:           save.textContent='جارٍ الحفظ…';
32533:         }
32534:         await onSubmit(key||'form:'+Date.now());
32535:       }catch(err){
32536:         toast(err.message||'تعذر الحفظ','error');
32537:         if(save){
32538:           save.disabled=false;
32539:           save.textContent='حفظ';
32540:         }
32541:       }
32542:     };
32543:   }
32544: }
32545: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
32546:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
32547:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
32548:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
32549:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
32550:   function employeeOpts(){return ppl()}
32551:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32552:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
32553:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
32554:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
32555:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
32556:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
32557:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
32558:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
32559:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
32560:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
32561:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
32562:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
32563:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
32564:   async function advancesTab(cn){
32565:  var d=await q('advances'),types={SALARY_ADVANCE:'سلفة راتب',TEMPORARY_ADVANCE:'سلفة مؤقتة',EMPLOYEE_LOAN:'قرض موظف',OPERATIONAL_CUSTODY:'عهدة تشغيلية',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};
32566:  var financial=d.financial_balances||[],debt=0,payable=0;
32567:  financial.forEach(function(x){var b=num(x.outstanding_balance);if(b>0)debt+=b;else if(b<0)payable+=Math.abs(b)});
32568:  var financialBody='<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-5">'+stat('إجمالي المديونية على الموظفين',money(debt)+' ج.م','fa-file-invoice-dollar','bg-amber-50 text-amber-700')+stat('مستحقات الموظفين لدى الشركة',money(payable)+' ج.م','fa-hand-holding-usd','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الأرصدة من القيود المرحلة فقط. الموجب على الموظف، والسالب مستحق له. طلبات السلف غير المصروفة لا تدخل في هذه الأرقام.</div>'+table(['الموظف','الحالة','طبيعة الذمة','الحساب','إجمالي المدين','إجمالي الدائن','الرصيد واتجاهه'],financial.map(function(x){var b=num(x.outstanding_balance),dir=b>0?badge('على الموظف','warn'):b<0?badge('مستحق للموظف','ok'):badge('متزن','muted');return tr([esc(x.employee_name||'-'),esc(x.employee_status||'-'),esc(types[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',dir+' <b class="mr-2">'+money(Math.abs(b))+' ج.م</b>'])}));
32569:  cn.innerHTML='<div class="space-y-5">'+card('المديونيات والأرصدة المالية المرحلة','مصدر موحد من دفتر الموظفين دون تعديل أرصدة',financialBody)+card('السلف والقروض','طلب → اعتماد → سند صرف مركزي → سداد نقدي عبر Receipts أو استقطاع رواتب حسب النوع',table(['الرقم','الموظف','نوع التمويل','القيمة','القسط','المتبقي','الحالة','سند الصرف','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف عبر Payments','disburse-advance:'+x.id,'bg-emerald-600 text-white'):'';return tr([esc(x.advance_no),esc(x.employee_name),esc(types[x.advance_nature||'SALARY_ADVANCE']),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),x.cash_box_id?badge('مرحل','ok'):badge('غير مصروف','warn'),a])})),btn('طلب سلفة/قرض جديد','new-advance'))+'</div>';
32570: }
32571:   async function disburseAdvance(id){
32572:     var tr=await supabase.from('treasury').select('id,account_name,account_code,type,current_balance,is_active').eq('company_id',H.companyId).eq('is_active',true).in('type',['Cash','Bank']).order('account_name');
32573:     if(tr.error)throw tr.error;
32574:     var rows=tr.data||[];
32575:     if(!rows.length){toast('لا توجد خزينة أو حساب بنكي فعال للصرف','error');return;}
32576:     var opts=rows.map(function(x){return '<option value="'+esc(x.id)+'">'+esc(x.account_name||x.account_code)+' · '+esc(x.type)+' · '+money(x.current_balance)+'</option>';}).join('');
32577:     var r=await Swal.fire({title:'صرف السلفة عبر سند Payments',html:'<div class="text-right text-sm text-slate-600 mb-2">سيتم إنشاء سند صرف مركزي وقيد محاسبي وربطه بالسلفة والموظف.</div><select id="hr-advance-treasury" class="swal2-select w-full">'+opts+'</select>',showCancelButton:true,confirmButtonText:'إنشاء سند الصرف',cancelButtonText:'إلغاء',preConfirm:function(){var t=E('hr-advance-treasury');if(!t||!t.value){Swal.showValidationMessage('اختر خزينة الصرف');return false;}return t.value;}});
32578:     if(!r.isConfirmed)return;
32579:     await c('advance.disburse',{advance_id:id,treasury_id:r.value},'disburse-advance:'+id);
32580:     toast('تم الصرف من خلال سند Payments مركزي وربطه بالسلفة','success');
32581:     return render();
32582:   }
32583:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
32584:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
32585:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[],fb=z[7].financial_balances||[],fl=z[7].financial_ledger||[];var financialReceivable=0,financialPayable=0;fb.forEach(function(x){var balance=num(x.outstanding_balance);if(balance>0)financialReceivable+=balance;else if(balance<0)financialPayable+=Math.abs(balance)});var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الموقف المالي المرحّل','ملخص مستقل لكل حساب وطبيعة ذمة — دون مقاصة بين ما على الموظف وما له','<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">'+stat('إجمالي المديونية على الموظف',money(financialReceivable)+' ج.م','fa-arrow-up','bg-amber-50 text-amber-700')+stat('إجمالي المستحق للموظف',money(financialPayable)+' ج.م','fa-arrow-down','bg-emerald-50 text-emerald-700')+'</div><div class="text-xs text-slate-500 mb-4">الموجب يمثل مديونية على الموظف، والسالب يمثل مبلغًا مستحقًا له. هذه الأرقام ناتجة عن قيود Posted فقط.</div>'+table(['طبيعة الذمة','الحساب','مدين','دائن','الرصيد','الاتجاه'],fb.map(function(x){var b=num(x.outstanding_balance),n={OPERATIONAL_CUSTODY:'عهدة تشغيلية',TEMPORARY_ADVANCE:'سلفة مؤقتة',SALARY_ADVANCE:'سلفة راتب',EMPLOYEE_LOAN:'قرض موظف',EMPLOYEE_REIMBURSEMENT_PAYABLE:'مستحقات موظف'};return tr([esc(n[x.party_nature]||x.party_nature||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),money(x.total_debit)+' ج.م',money(x.total_credit)+' ج.م',money(Math.abs(b))+' ج.م',b>0?badge('على الموظف','warn'):b<0?badge('مستحق له','ok'):badge('متزن','muted')])})))+card('آخر الحركات المالية المرحّلة','آخر 30 حركة — RPC يعيد 200 كحد أقصى',table(['التاريخ','رقم القيد','نوع القيد','الحساب','المرجع / البيان','مدين','دائن'],fl.slice(0,30).map(function(x){return tr([date(x.entry_date),esc(x.entry_code||'-'),esc(x.entry_type||'-'),esc((x.account_code||'')+' — '+(x.account_name||'')),esc(x.reference||x.description||'-'),money(x.debit)+' ج.م',money(x.credit)+' ج.م'])})))+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
32586:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
32587:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
32588:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
32589:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
32590:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
32591:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
32592:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
32593:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
32594:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
32595:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
32596:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
32597:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
32598:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
32599:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
32600:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
32601:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
32602:   async function advance(){await loadPeople();simple('سلفة أو قرض موظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع التمويل','x-nature',[{value:'SALARY_ADVANCE',label:'سلفة راتب — تستقطع من الرواتب'},{value:'TEMPORARY_ADVANCE',label:'سلفة مؤقتة — تسدد نقدًا أو بتسوية معتمدة'},{value:'EMPLOYEE_LOAN',label:'قرض موظف — أقساط أو سداد نقدي'}],'SALARY_ADVANCE')+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,advance_nature:E('x-nature').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
32603:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
32604:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
32605:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
32606:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
32607:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
32608:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
32609:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance')return disburseAdvance(id);if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
32610:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var refresh=function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)};var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},refresh)});H.channel.on('postgres_changes',{event:'*',schema:'public',table:'journal_lines',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'*',schema:'public',table:'cash_box',filter:'party_type=eq.Employee'},refresh);H.channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'journal_entries',filter:'status=eq.Posted'},refresh);H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
32611:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
32612:   (function installModalResilience(){
32613:     document.addEventListener('click',function(e){
32614:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
32615:       if(!ac)return;
32616:       var page=E('rw-page-container');
32617:       if(page&&page.contains(ac))return;
32618:       e.preventDefault();
32619:       handle(ac.getAttribute('data-hr-action'));
32620:     },true);
32621:     window.addEventListener('unhandledrejection',function(e){
32622:       var root=E('rw-hr-modal-root');
32623:       if(!root)return;
32624:       e.preventDefault();
32625:       var msg=e.reason&&(e.reason.message||String(e.reason));
32626:       if(msg)toast(msg,'error');
32627:     });
32628:     try{
32629:       var mo=new MutationObserver(function(){
32630:         var root=E('rw-hr-modal-root');
32631:         if(!root||!E('hr360'))return;
32632:         var f=E('rw-hr-form');
32633:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
32634:       });
32635:       mo.observe(document.body,{childList:true,subtree:true});
32636:     }catch(e){}
32637:   }());
32638: 
32639: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
