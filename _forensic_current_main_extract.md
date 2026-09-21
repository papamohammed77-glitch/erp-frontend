# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=31543
FILE_BYTES=1805016
SHA256=be8672624649b9141e6f050e84f77a864e6deffa949b19857052ac5748d50246
PATTERN var RW_Warehouse: [13746]
PATTERN var RW_HR: [29495]
PATTERN RW_HR: [29447, 29493, 29495, 29611, 29640]
PATTERN hr_list_employees: []
PATTERN hr_command_atomic: [29515]
PATTERN hr_query: [27195, 27298, 27342, 27463, 29514]
PATTERN hr_payroll_calculate_impl: []
PATTERN hr_payroll_post_impl: []
PATTERN employee_documents: [29611]
PATTERN hr_departments: [29611]
PATTERN hr_contracts: [29611]
PATTERN hr_work_schedules: [29611]
PATTERN hr_attendance_events: [29611]
PATTERN hr_leave_types: [29611]
PATTERN hr_requests: [29611]
PATTERN hr_salary_advances: [29611]
PATTERN hr_payroll_periods: [29611]
PATTERN hr_payslips: [29611]
PATTERN hr_command: [29515]
PATTERN employee-document: [29607, 29608]
PATTERN document-upload: []
PATTERN الموارد البشرية: [1564, 7762, 9092, 23658, 23690, 29433, 29493, 29609]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 29465-29675 around 29495 ---
29465:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
29466:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
29467: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
29468: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
29469: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
29470: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
29471:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
29472:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
29473:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
29474:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
29475:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
29476:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
29477:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
29478:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
29479:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
29480:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
29481:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
29482:         if (view === 'finance') { RW_Finance.render(); return; }
29483:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
29484:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
29485:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
29486:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
29487: 
29488:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
29489:     }
29490: };
29491: window.RW_Views = RW_Views;
29492: // ============================================================
29493: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
29494: // ============================================================
29495: var RW_HR = (function() {
29496:  'use strict';
29497:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
29498:   var T=[
29499:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
29500:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
29501:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
29502:   ];
29503:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
29504:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
29505:   function num(v){v=Number(v);return isFinite(v)?v:0}
29506:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
29507:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
29508:   function iso(v){return v?new Date(v).toISOString():null}
29509:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
29510:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
29511:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
29512:   function opClear(k){if(k)delete H.ops[k]}
29513:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
29514:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
29515:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
29516:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
29517:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
29518:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
29519:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
29520:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
29521:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
29522:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
29523:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
29524:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
29525:  function modal(title,body,onSubmit,key){
29526:   var old=E('rw-hr-modal-root');
29527:   if(old)old.remove();
29528:   var r=document.createElement('div');
29529:   r.id='rw-hr-modal-root';
29530:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
29531:   document.body.appendChild(r);
29532:   E('rw-hr-close').onclick=closeModal;
29533:   E('rw-hr-cancel').onclick=closeModal;
29534:   r.addEventListener('click',function(e){
29535:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29536:     if(ac){
29537:       e.preventDefault();
29538:       handle(ac.getAttribute('data-hr-action'));
29539:     }
29540:   });
29541:   if(onSubmit===null){
29542:     var f=E('rw-hr-form');
29543:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29544:   }else{
29545:     E('rw-hr-form').onsubmit=async function(e){
29546:       e.preventDefault();
29547:       var save=e.target.querySelector('button[type="submit"]');
29548:       try{
29549:         if(save){
29550:           save.disabled=true;
29551:           save.textContent='جارٍ الحفظ…';
29552:         }
29553:         await onSubmit(key||'form:'+Date.now());
29554:       }catch(err){
29555:         toast(err.message||'تعذر الحفظ','error');
29556:         if(save){
29557:           save.disabled=false;
29558:           save.textContent='حفظ';
29559:         }
29560:       }
29561:     };
29562:   }
29563: }
29564: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
29565:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
29566:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
29567:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
29568:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
29569:   function employeeOpts(){return ppl()}
29570:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29571:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
29572:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29573:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
29574:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
29575:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
29576:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
29577:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
29578:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
29579:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
29580:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
29581:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
29582:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
29583:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
29584:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
29585:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
29586:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
29587:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
29588:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
29589:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
29590:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
29591:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
29592:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
29593:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
29594:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
29595:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
29596:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
29597:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
29598:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
29599:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
29600:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
29601:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
29602:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
29603:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
29604:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
29605:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
29606:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
29607:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
29608:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
29609:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
29610:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
29611:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
29612:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
29613:   (function installModalResilience(){
29614:     document.addEventListener('click',function(e){
29615:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29616:       if(!ac)return;
29617:       var page=E('rw-page-container');
29618:       if(page&&page.contains(ac))return;
29619:       e.preventDefault();
29620:       handle(ac.getAttribute('data-hr-action'));
29621:     },true);
29622:     window.addEventListener('unhandledrejection',function(e){
29623:       var root=E('rw-hr-modal-root');
29624:       if(!root)return;
29625:       e.preventDefault();
29626:       var msg=e.reason&&(e.reason.message||String(e.reason));
29627:       if(msg)toast(msg,'error');
29628:     });
29629:     try{
29630:       var mo=new MutationObserver(function(){
29631:         var root=E('rw-hr-modal-root');
29632:         if(!root||!E('hr360'))return;
29633:         var f=E('rw-hr-form');
29634:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29635:       });
29636:       mo.observe(document.body,{childList:true,subtree:true});
29637:     }catch(e){}
29638:   }());
29639: 
29640: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
29641: 
29642: 
29643: // ============================================================
29644: // RW_CRM – إدارة علاقات العملاء (CRM)
29645: // ============================================================
29646: var RW_CRM = (function() {
29647:     'use strict';
29648: 
29649:     var state = {
29650:         customers: [],
29651:         assignees: [],
29652:         kpi: {},
29653:         search: '',
29654:         activeOnly: false,
29655:         searchTimer: null
29656:     };
29657: 
29658:     function _esc(s) {
29659:         return String(s == null ? '' : s)
29660:             .replace(/&/g, '&amp;')
29661:             .replace(/</g, '&lt;')
29662:             .replace(/>/g, '&gt;')
29663:             .replace(/"/g, '&quot;')
29664:             .replace(/'/g, '&#39;');
29665:     }
29666: 
29667:     function _fmtNum(n) {
29668:         return Number(n || 0).toLocaleString('ar-EG');
29669:     }
29670: 
29671:     function _fmtMoney(n) {
29672:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
29673:     }
29674: 
29675:     function _today() {
--- WINDOW 29485-29695 around 29515 ---
29485:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
29486:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
29487: 
29488:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
29489:     }
29490: };
29491: window.RW_Views = RW_Views;
29492: // ============================================================
29493: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
29494: // ============================================================
29495: var RW_HR = (function() {
29496:  'use strict';
29497:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
29498:   var T=[
29499:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
29500:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
29501:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
29502:   ];
29503:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
29504:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
29505:   function num(v){v=Number(v);return isFinite(v)?v:0}
29506:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
29507:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
29508:   function iso(v){return v?new Date(v).toISOString():null}
29509:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
29510:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
29511:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
29512:   function opClear(k){if(k)delete H.ops[k]}
29513:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
29514:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
29515:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
29516:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
29517:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
29518:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
29519:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
29520:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
29521:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
29522:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
29523:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
29524:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
29525:  function modal(title,body,onSubmit,key){
29526:   var old=E('rw-hr-modal-root');
29527:   if(old)old.remove();
29528:   var r=document.createElement('div');
29529:   r.id='rw-hr-modal-root';
29530:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
29531:   document.body.appendChild(r);
29532:   E('rw-hr-close').onclick=closeModal;
29533:   E('rw-hr-cancel').onclick=closeModal;
29534:   r.addEventListener('click',function(e){
29535:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29536:     if(ac){
29537:       e.preventDefault();
29538:       handle(ac.getAttribute('data-hr-action'));
29539:     }
29540:   });
29541:   if(onSubmit===null){
29542:     var f=E('rw-hr-form');
29543:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29544:   }else{
29545:     E('rw-hr-form').onsubmit=async function(e){
29546:       e.preventDefault();
29547:       var save=e.target.querySelector('button[type="submit"]');
29548:       try{
29549:         if(save){
29550:           save.disabled=true;
29551:           save.textContent='جارٍ الحفظ…';
29552:         }
29553:         await onSubmit(key||'form:'+Date.now());
29554:       }catch(err){
29555:         toast(err.message||'تعذر الحفظ','error');
29556:         if(save){
29557:           save.disabled=false;
29558:           save.textContent='حفظ';
29559:         }
29560:       }
29561:     };
29562:   }
29563: }
29564: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
29565:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
29566:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
29567:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
29568:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
29569:   function employeeOpts(){return ppl()}
29570:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29571:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
29572:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29573:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
29574:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
29575:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
29576:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
29577:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
29578:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
29579:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
29580:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
29581:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
29582:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
29583:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
29584:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
29585:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
29586:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
29587:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
29588:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
29589:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
29590:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
29591:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
29592:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
29593:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
29594:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
29595:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
29596:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
29597:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
29598:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
29599:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
29600:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
29601:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
29602:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
29603:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
29604:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
29605:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
29606:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
29607:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
29608:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
29609:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
29610:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
29611:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
29612:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
29613:   (function installModalResilience(){
29614:     document.addEventListener('click',function(e){
29615:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29616:       if(!ac)return;
29617:       var page=E('rw-page-container');
29618:       if(page&&page.contains(ac))return;
29619:       e.preventDefault();
29620:       handle(ac.getAttribute('data-hr-action'));
29621:     },true);
29622:     window.addEventListener('unhandledrejection',function(e){
29623:       var root=E('rw-hr-modal-root');
29624:       if(!root)return;
29625:       e.preventDefault();
29626:       var msg=e.reason&&(e.reason.message||String(e.reason));
29627:       if(msg)toast(msg,'error');
29628:     });
29629:     try{
29630:       var mo=new MutationObserver(function(){
29631:         var root=E('rw-hr-modal-root');
29632:         if(!root||!E('hr360'))return;
29633:         var f=E('rw-hr-form');
29634:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29635:       });
29636:       mo.observe(document.body,{childList:true,subtree:true});
29637:     }catch(e){}
29638:   }());
29639: 
29640: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
29641: 
29642: 
29643: // ============================================================
29644: // RW_CRM – إدارة علاقات العملاء (CRM)
29645: // ============================================================
29646: var RW_CRM = (function() {
29647:     'use strict';
29648: 
29649:     var state = {
29650:         customers: [],
29651:         assignees: [],
29652:         kpi: {},
29653:         search: '',
29654:         activeOnly: false,
29655:         searchTimer: null
29656:     };
29657: 
29658:     function _esc(s) {
29659:         return String(s == null ? '' : s)
29660:             .replace(/&/g, '&amp;')
29661:             .replace(/</g, '&lt;')
29662:             .replace(/>/g, '&gt;')
29663:             .replace(/"/g, '&quot;')
29664:             .replace(/'/g, '&#39;');
29665:     }
29666: 
29667:     function _fmtNum(n) {
29668:         return Number(n || 0).toLocaleString('ar-EG');
29669:     }
29670: 
29671:     function _fmtMoney(n) {
29672:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
29673:     }
29674: 
29675:     function _today() {
29676:         var d = new Date();
29677:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
29678:         return local.toISOString().slice(0, 10);
29679:     }
29680: 
29681:     function _statusLabel(s) {
29682:         var map = {
29683:             Open: 'مفتوحة',
29684:             'معلقة': 'معلقة',
29685:             completed: 'مكتملة',
29686:             'مكتملة': 'مكتملة',
29687:             cancelled: 'ملغاة',
29688:             'ملغاة': 'ملغاة'
29689:         };
29690:         return map[s] || s || 'غير محددة';
29691:     }
29692: 
29693:     function _statusClass(s) {
29694:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
29695:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
--- WINDOW 27165-27375 around 27195 ---
27165:                         '<td class="p-2">' +
27166:                         _esc(row.email) +
27167:                         '</td>' +
27168:                         '<td class="p-2">' +
27169:                         _esc(row.role) +
27170:                         '</td>' +
27171:                         '<td class="p-2">' +
27172:                         _esc(row.status) +
27173:                         '</td>' +
27174:                         '</tr>'
27175:                     );
27176:                 });
27177: 
27178:             html =
27179:                 '<h4 class="font-bold mb-3">قائمة الموظفين</h4>' +
27180:                 _table(
27181:                     [
27182:                         'الاسم',
27183:                         'البريد',
27184:                         'الدور',
27185:                         'الحالة'
27186:                     ],
27187:                     rows28
27188:                 );
27189:         }
27190: 
27191:         else if (reportId === 'hr-attendance') {
27192: 
27193:             var hrAttendanceReport =
27194:                 await supabase.rpc(
27195:                     'hr_query',
27196:                     {
27197:                         p_view: 'attendance',
27198:                         p_payload: {
27199:                             from: fromDate,
27200:                             to: toDate,
27201:                             limit: 5000
27202:                         }
27203:                     }
27204:                 );
27205: 
27206:             if (hrAttendanceReport.error) {
27207:                 throw hrAttendanceReport.error;
27208:             }
27209: 
27210:             var hrAttendancePayload =
27211:                 hrAttendanceReport.data || {};
27212: 
27213:             if (hrAttendancePayload.success === false) {
27214:                 throw new Error(
27215:                     hrAttendancePayload.msg ||
27216:                     hrAttendancePayload.code ||
27217:                     'لا توجد صلاحية أو مصدر صالح لتقرير الحضور'
27218:                 );
27219:             }
27220: 
27221:             var hrAttendanceRows =
27222:                 Array.isArray(hrAttendancePayload.rows)
27223:                     ? hrAttendancePayload.rows
27224:                     : [];
27225: 
27226:             var attendanceWorkedHours = 0;
27227:             var attendanceLateMinutes = 0;
27228:             var attendanceOvertimeHours = 0;
27229: 
27230:             var hrAttendanceTableRows =
27231:                 hrAttendanceRows.map(function(row) {
27232: 
27233:                     attendanceWorkedHours +=
27234:                         Number(row.worked_hours) || 0;
27235: 
27236:                     attendanceLateMinutes +=
27237:                         Number(row.late_minutes) || 0;
27238: 
27239:                     attendanceOvertimeHours +=
27240:                         Number(row.overtime_hours) || 0;
27241: 
27242:                     return (
27243:                         '<tr class="border-t">' +
27244:                         '<td class="p-2">' +
27245:                         _esc(row.attendance_date) +
27246:                         '</td>' +
27247:                         '<td class="p-2 font-semibold">' +
27248:                         _esc(row.employee_name || row.email || '') +
27249:                         '</td>' +
27250:                         '<td class="p-2">' +
27251:                         _esc(row.status || '') +
27252:                         '</td>' +
27253:                         '<td class="p-2 text-center">' +
27254:                         _esc(
27255:                             row.check_in
27256:                                 ? new Date(row.check_in).toLocaleTimeString(
27257:                                     'ar-EG',
27258:                                     {
27259:                                         hour: '2-digit',
27260:                                         minute: '2-digit'
27261:                                     }
27262:                                   )
27263:                                 : '-'
27264:                         ) +
27265:                         '</td>' +
27266:                         '<td class="p-2 text-center">' +
27267:                         _esc(
27268:                             row.check_out
27269:                                 ? new Date(row.check_out).toLocaleTimeString(
27270:                                     'ar-EG',
27271:                                     {
27272:                                         hour: '2-digit',
27273:                                         minute: '2-digit'
27274:                                     }
27275:                                   )
27276:                                 : '-'
27277:                         ) +
27278:                         '</td>' +
27279:                         '<td class="p-2 text-center font-bold">' +
27280:                         _fmtNum(row.worked_hours) +
27281:                         '</td>' +
27282:                         '<td class="p-2 text-center">' +
27283:                         _fmtNum(row.late_minutes) +
27284:                         '</td>' +
27285:                         '<td class="p-2 text-center">' +
27286:                         _fmtNum(row.overtime_hours) +
27287:                         '</td>' +
27288:                         '<td class="p-2 text-center">' +
27289:                         _fmtNum(row.absence_minutes) +
27290:                         '</td>' +
27291:                         '</tr>'
27292:                     );
27293:                 });
27294: 
27295:             html =
27296:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
27297:                 '<div class="mb-4 text-xs text-gray-500">' +
27298:                 'المصدر: Production hr_query(attendance)' +
27299:                 '</div>' +
27300:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27301:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27302:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
27303:                 '<div class="text-lg font-black">' +
27304:                 _fmtNum(hrAttendanceRows.length) +
27305:                 '</div></div>' +
27306:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27307:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
27308:                 '<div class="text-lg font-black">' +
27309:                 _fmtNum(attendanceWorkedHours) +
27310:                 '</div></div>' +
27311:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27312:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27313:                 '<div class="text-lg font-black">' +
27314:                 _fmtNum(attendanceLateMinutes) +
27315:                 '</div></div>' +
27316:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27317:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27318:                 '<div class="text-lg font-black">' +
27319:                 _fmtNum(attendanceOvertimeHours) +
27320:                 '</div></div>' +
27321:                 '</div>' +
27322:                 _table(
27323:                     [
27324:                         'التاريخ',
27325:                         'الموظف',
27326:                         'الحالة',
27327:                         'الدخول',
27328:                         'الخروج',
27329:                         'ساعات العمل',
27330:                         'التأخير بالدقائق',
27331:                         'الساعات الإضافية',
27332:                         'دقائق الغياب'
27333:                     ],
27334:                     hrAttendanceTableRows
27335:                 );
27336:         }
27337: 
27338:         else if (reportId === 'hr-salary') {
27339: 
27340:             var hrPayrollReport =
27341:                 await supabase.rpc(
27342:                     'hr_query',
27343:                     {
27344:                         p_view: 'payroll_runs',
27345:                         p_payload: {}
27346:                     }
27347:                 );
27348: 
27349:             if (hrPayrollReport.error) {
27350:                 throw hrPayrollReport.error;
27351:             }
27352: 
27353:             var hrPayrollPayload =
27354:                 hrPayrollReport.data || {};
27355: 
27356:             if (hrPayrollPayload.success === false) {
27357:                 throw new Error(
27358:                     hrPayrollPayload.msg ||
27359:                     hrPayrollPayload.code ||
27360:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27361:                 );
27362:             }
27363: 
27364:             var hrPayrollRows =
27365:                 Array.isArray(hrPayrollPayload.rows)
27366:                     ? hrPayrollPayload.rows
27367:                     : [];
27368: 
27369:             var filteredPayrollRows = [];
27370: 
27371:             var payrollGrossTotal = 0;
27372:             var payrollDeductionTotal = 0;
27373:             var payrollNetTotal = 0;
27374:             var payrollEmployeeTotal = 0;
27375: 
--- WINDOW 27268-27478 around 27298 ---
27268:                             row.check_out
27269:                                 ? new Date(row.check_out).toLocaleTimeString(
27270:                                     'ar-EG',
27271:                                     {
27272:                                         hour: '2-digit',
27273:                                         minute: '2-digit'
27274:                                     }
27275:                                   )
27276:                                 : '-'
27277:                         ) +
27278:                         '</td>' +
27279:                         '<td class="p-2 text-center font-bold">' +
27280:                         _fmtNum(row.worked_hours) +
27281:                         '</td>' +
27282:                         '<td class="p-2 text-center">' +
27283:                         _fmtNum(row.late_minutes) +
27284:                         '</td>' +
27285:                         '<td class="p-2 text-center">' +
27286:                         _fmtNum(row.overtime_hours) +
27287:                         '</td>' +
27288:                         '<td class="p-2 text-center">' +
27289:                         _fmtNum(row.absence_minutes) +
27290:                         '</td>' +
27291:                         '</tr>'
27292:                     );
27293:                 });
27294: 
27295:             html =
27296:                 '<h4 class="font-bold mb-3">تقرير الحضور والانصراف</h4>' +
27297:                 '<div class="mb-4 text-xs text-gray-500">' +
27298:                 'المصدر: Production hr_query(attendance)' +
27299:                 '</div>' +
27300:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27301:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27302:                 '<div class="text-xs text-blue-700">عدد السجلات</div>' +
27303:                 '<div class="text-lg font-black">' +
27304:                 _fmtNum(hrAttendanceRows.length) +
27305:                 '</div></div>' +
27306:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27307:                 '<div class="text-xs text-emerald-700">ساعات العمل</div>' +
27308:                 '<div class="text-lg font-black">' +
27309:                 _fmtNum(attendanceWorkedHours) +
27310:                 '</div></div>' +
27311:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27312:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27313:                 '<div class="text-lg font-black">' +
27314:                 _fmtNum(attendanceLateMinutes) +
27315:                 '</div></div>' +
27316:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27317:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27318:                 '<div class="text-lg font-black">' +
27319:                 _fmtNum(attendanceOvertimeHours) +
27320:                 '</div></div>' +
27321:                 '</div>' +
27322:                 _table(
27323:                     [
27324:                         'التاريخ',
27325:                         'الموظف',
27326:                         'الحالة',
27327:                         'الدخول',
27328:                         'الخروج',
27329:                         'ساعات العمل',
27330:                         'التأخير بالدقائق',
27331:                         'الساعات الإضافية',
27332:                         'دقائق الغياب'
27333:                     ],
27334:                     hrAttendanceTableRows
27335:                 );
27336:         }
27337: 
27338:         else if (reportId === 'hr-salary') {
27339: 
27340:             var hrPayrollReport =
27341:                 await supabase.rpc(
27342:                     'hr_query',
27343:                     {
27344:                         p_view: 'payroll_runs',
27345:                         p_payload: {}
27346:                     }
27347:                 );
27348: 
27349:             if (hrPayrollReport.error) {
27350:                 throw hrPayrollReport.error;
27351:             }
27352: 
27353:             var hrPayrollPayload =
27354:                 hrPayrollReport.data || {};
27355: 
27356:             if (hrPayrollPayload.success === false) {
27357:                 throw new Error(
27358:                     hrPayrollPayload.msg ||
27359:                     hrPayrollPayload.code ||
27360:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27361:                 );
27362:             }
27363: 
27364:             var hrPayrollRows =
27365:                 Array.isArray(hrPayrollPayload.rows)
27366:                     ? hrPayrollPayload.rows
27367:                     : [];
27368: 
27369:             var filteredPayrollRows = [];
27370: 
27371:             var payrollGrossTotal = 0;
27372:             var payrollDeductionTotal = 0;
27373:             var payrollNetTotal = 0;
27374:             var payrollEmployeeTotal = 0;
27375: 
27376:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
27377: 
27378:                 var payrollRow = hrPayrollRows[pr] || {};
27379: 
27380:                 var periodStart =
27381:                     String(
27382:                         payrollRow.start_date ||
27383:                         ''
27384:                     ).slice(0, 10);
27385: 
27386:                 var periodEnd =
27387:                     String(
27388:                         payrollRow.end_date ||
27389:                         ''
27390:                     ).slice(0, 10);
27391: 
27392:                 if (
27393:                     periodStart &&
27394:                     periodEnd &&
27395:                     periodEnd < fromDate
27396:                 ) {
27397:                     continue;
27398:                 }
27399: 
27400:                 if (
27401:                     periodStart &&
27402:                     periodEnd &&
27403:                     periodStart > toDate
27404:                 ) {
27405:                     continue;
27406:                 }
27407: 
27408:                 filteredPayrollRows.push(
27409:                     payrollRow
27410:                 );
27411: 
27412:                 payrollGrossTotal +=
27413:                     Number(payrollRow.gross_total) || 0;
27414: 
27415:                 payrollDeductionTotal +=
27416:                     Number(payrollRow.deduction_total) || 0;
27417: 
27418:                 payrollNetTotal +=
27419:                     Number(payrollRow.net_total) || 0;
27420: 
27421:                 payrollEmployeeTotal +=
27422:                     Number(payrollRow.employee_count) || 0;
27423:             }
27424: 
27425:             var payrollTableRows =
27426:                 filteredPayrollRows.map(function(row) {
27427: 
27428:                     return (
27429:                         '<tr class="border-t">' +
27430:                         '<td class="p-2">' +
27431:                         _esc(row.run_no || '') +
27432:                         '</td>' +
27433:                         '<td class="p-2 font-semibold">' +
27434:                         _esc(row.period_code || '') +
27435:                         '</td>' +
27436:                         '<td class="p-2">' +
27437:                         _esc(row.start_date || '') +
27438:                         ' → ' +
27439:                         _esc(row.end_date || '') +
27440:                         '</td>' +
27441:                         '<td class="p-2 text-center">' +
27442:                         _fmtNum(row.employee_count) +
27443:                         '</td>' +
27444:                         '<td class="p-2 text-center">' +
27445:                         _fmtNum(row.gross_total) +
27446:                         '</td>' +
27447:                         '<td class="p-2 text-center">' +
27448:                         _fmtNum(row.deduction_total) +
27449:                         '</td>' +
27450:                         '<td class="p-2 text-center font-bold">' +
27451:                         _fmtNum(row.net_total) +
27452:                         '</td>' +
27453:                         '<td class="p-2">' +
27454:                         _esc(row.status || '') +
27455:                         '</td>' +
27456:                         '</tr>'
27457:                     );
27458:                 });
27459: 
27460:             html =
27461:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27462:                 '<div class="mb-4 text-xs text-gray-500">' +
27463:                 'المصدر: Production hr_query(payroll_runs)' +
27464:                 '</div>' +
27465:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27466:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27467:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27468:                 '<div class="text-lg font-black">' +
27469:                 _fmtNum(filteredPayrollRows.length) +
27470:                 '</div></div>' +
27471:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27472:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27473:                 '<div class="text-lg font-black">' +
27474:                 _fmtNum(payrollGrossTotal) +
27475:                 '</div></div>' +
27476:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27477:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27478:                 '<div class="text-lg font-black">' +
--- WINDOW 27312-27522 around 27342 ---
27312:                 '<div class="text-xs text-amber-700">دقائق التأخير</div>' +
27313:                 '<div class="text-lg font-black">' +
27314:                 _fmtNum(attendanceLateMinutes) +
27315:                 '</div></div>' +
27316:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27317:                 '<div class="text-xs text-purple-700">ساعات الإضافي</div>' +
27318:                 '<div class="text-lg font-black">' +
27319:                 _fmtNum(attendanceOvertimeHours) +
27320:                 '</div></div>' +
27321:                 '</div>' +
27322:                 _table(
27323:                     [
27324:                         'التاريخ',
27325:                         'الموظف',
27326:                         'الحالة',
27327:                         'الدخول',
27328:                         'الخروج',
27329:                         'ساعات العمل',
27330:                         'التأخير بالدقائق',
27331:                         'الساعات الإضافية',
27332:                         'دقائق الغياب'
27333:                     ],
27334:                     hrAttendanceTableRows
27335:                 );
27336:         }
27337: 
27338:         else if (reportId === 'hr-salary') {
27339: 
27340:             var hrPayrollReport =
27341:                 await supabase.rpc(
27342:                     'hr_query',
27343:                     {
27344:                         p_view: 'payroll_runs',
27345:                         p_payload: {}
27346:                     }
27347:                 );
27348: 
27349:             if (hrPayrollReport.error) {
27350:                 throw hrPayrollReport.error;
27351:             }
27352: 
27353:             var hrPayrollPayload =
27354:                 hrPayrollReport.data || {};
27355: 
27356:             if (hrPayrollPayload.success === false) {
27357:                 throw new Error(
27358:                     hrPayrollPayload.msg ||
27359:                     hrPayrollPayload.code ||
27360:                     'لا توجد صلاحية أو مصدر صالح لتقرير الرواتب'
27361:                 );
27362:             }
27363: 
27364:             var hrPayrollRows =
27365:                 Array.isArray(hrPayrollPayload.rows)
27366:                     ? hrPayrollPayload.rows
27367:                     : [];
27368: 
27369:             var filteredPayrollRows = [];
27370: 
27371:             var payrollGrossTotal = 0;
27372:             var payrollDeductionTotal = 0;
27373:             var payrollNetTotal = 0;
27374:             var payrollEmployeeTotal = 0;
27375: 
27376:             for (var pr = 0; pr < hrPayrollRows.length; pr++) {
27377: 
27378:                 var payrollRow = hrPayrollRows[pr] || {};
27379: 
27380:                 var periodStart =
27381:                     String(
27382:                         payrollRow.start_date ||
27383:                         ''
27384:                     ).slice(0, 10);
27385: 
27386:                 var periodEnd =
27387:                     String(
27388:                         payrollRow.end_date ||
27389:                         ''
27390:                     ).slice(0, 10);
27391: 
27392:                 if (
27393:                     periodStart &&
27394:                     periodEnd &&
27395:                     periodEnd < fromDate
27396:                 ) {
27397:                     continue;
27398:                 }
27399: 
27400:                 if (
27401:                     periodStart &&
27402:                     periodEnd &&
27403:                     periodStart > toDate
27404:                 ) {
27405:                     continue;
27406:                 }
27407: 
27408:                 filteredPayrollRows.push(
27409:                     payrollRow
27410:                 );
27411: 
27412:                 payrollGrossTotal +=
27413:                     Number(payrollRow.gross_total) || 0;
27414: 
27415:                 payrollDeductionTotal +=
27416:                     Number(payrollRow.deduction_total) || 0;
27417: 
27418:                 payrollNetTotal +=
27419:                     Number(payrollRow.net_total) || 0;
27420: 
27421:                 payrollEmployeeTotal +=
27422:                     Number(payrollRow.employee_count) || 0;
27423:             }
27424: 
27425:             var payrollTableRows =
27426:                 filteredPayrollRows.map(function(row) {
27427: 
27428:                     return (
27429:                         '<tr class="border-t">' +
27430:                         '<td class="p-2">' +
27431:                         _esc(row.run_no || '') +
27432:                         '</td>' +
27433:                         '<td class="p-2 font-semibold">' +
27434:                         _esc(row.period_code || '') +
27435:                         '</td>' +
27436:                         '<td class="p-2">' +
27437:                         _esc(row.start_date || '') +
27438:                         ' → ' +
27439:                         _esc(row.end_date || '') +
27440:                         '</td>' +
27441:                         '<td class="p-2 text-center">' +
27442:                         _fmtNum(row.employee_count) +
27443:                         '</td>' +
27444:                         '<td class="p-2 text-center">' +
27445:                         _fmtNum(row.gross_total) +
27446:                         '</td>' +
27447:                         '<td class="p-2 text-center">' +
27448:                         _fmtNum(row.deduction_total) +
27449:                         '</td>' +
27450:                         '<td class="p-2 text-center font-bold">' +
27451:                         _fmtNum(row.net_total) +
27452:                         '</td>' +
27453:                         '<td class="p-2">' +
27454:                         _esc(row.status || '') +
27455:                         '</td>' +
27456:                         '</tr>'
27457:                     );
27458:                 });
27459: 
27460:             html =
27461:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27462:                 '<div class="mb-4 text-xs text-gray-500">' +
27463:                 'المصدر: Production hr_query(payroll_runs)' +
27464:                 '</div>' +
27465:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27466:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27467:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27468:                 '<div class="text-lg font-black">' +
27469:                 _fmtNum(filteredPayrollRows.length) +
27470:                 '</div></div>' +
27471:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27472:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27473:                 '<div class="text-lg font-black">' +
27474:                 _fmtNum(payrollGrossTotal) +
27475:                 '</div></div>' +
27476:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27477:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27478:                 '<div class="text-lg font-black">' +
27479:                 _fmtNum(payrollDeductionTotal) +
27480:                 '</div></div>' +
27481:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27482:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
27483:                 '<div class="text-lg font-black">' +
27484:                 _fmtNum(payrollNetTotal) +
27485:                 '</div></div>' +
27486:                 '</div>' +
27487:                 '<div class="mb-4 text-xs text-gray-500">' +
27488:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
27489:                 _fmtNum(payrollEmployeeTotal) +
27490:                 '</div>' +
27491:                 _table(
27492:                     [
27493:                         'رقم المسير',
27494:                         'الفترة',
27495:                         'النطاق',
27496:                         'الموظفون',
27497:                         'إجمالي الأجور',
27498:                         'الاستقطاعات',
27499:                         'الصافي',
27500:                         'الحالة'
27501:                     ],
27502:                     payrollTableRows
27503:                 );
27504:         }
27505:         else {
27506: 
27507:             html =
27508:                 '<div class="text-center py-4 text-gray-500">' +
27509:                 'هذا التقرير غير متوفر بعد' +
27510:                 '</div>';
27511:         }
27512: 
27513:         safeHTML(
27514:     resultDiv,
27515:     html +
27516:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
27517:     '<span>المصدر: Production</span>' +
27518:     '<span>آخر تنفيذ: ' +
27519:     _esc(
27520:         new Date().toLocaleString('ar-EG')
27521:     ) +
27522:     '</span>' +
--- WINDOW 27433-27643 around 27463 ---
27433:                         '<td class="p-2 font-semibold">' +
27434:                         _esc(row.period_code || '') +
27435:                         '</td>' +
27436:                         '<td class="p-2">' +
27437:                         _esc(row.start_date || '') +
27438:                         ' → ' +
27439:                         _esc(row.end_date || '') +
27440:                         '</td>' +
27441:                         '<td class="p-2 text-center">' +
27442:                         _fmtNum(row.employee_count) +
27443:                         '</td>' +
27444:                         '<td class="p-2 text-center">' +
27445:                         _fmtNum(row.gross_total) +
27446:                         '</td>' +
27447:                         '<td class="p-2 text-center">' +
27448:                         _fmtNum(row.deduction_total) +
27449:                         '</td>' +
27450:                         '<td class="p-2 text-center font-bold">' +
27451:                         _fmtNum(row.net_total) +
27452:                         '</td>' +
27453:                         '<td class="p-2">' +
27454:                         _esc(row.status || '') +
27455:                         '</td>' +
27456:                         '</tr>'
27457:                     );
27458:                 });
27459: 
27460:             html =
27461:                 '<h4 class="font-bold mb-3">تقرير الرواتب</h4>' +
27462:                 '<div class="mb-4 text-xs text-gray-500">' +
27463:                 'المصدر: Production hr_query(payroll_runs)' +
27464:                 '</div>' +
27465:                 '<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">' +
27466:                 '<div class="bg-blue-50 border border-blue-100 rounded-xl p-3 text-center">' +
27467:                 '<div class="text-xs text-blue-700">عدد مسيرات الرواتب</div>' +
27468:                 '<div class="text-lg font-black">' +
27469:                 _fmtNum(filteredPayrollRows.length) +
27470:                 '</div></div>' +
27471:                 '<div class="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-center">' +
27472:                 '<div class="text-xs text-emerald-700">إجمالي الأجور</div>' +
27473:                 '<div class="text-lg font-black">' +
27474:                 _fmtNum(payrollGrossTotal) +
27475:                 '</div></div>' +
27476:                 '<div class="bg-amber-50 border border-amber-100 rounded-xl p-3 text-center">' +
27477:                 '<div class="text-xs text-amber-700">إجمالي الاستقطاعات</div>' +
27478:                 '<div class="text-lg font-black">' +
27479:                 _fmtNum(payrollDeductionTotal) +
27480:                 '</div></div>' +
27481:                 '<div class="bg-purple-50 border border-purple-100 rounded-xl p-3 text-center">' +
27482:                 '<div class="text-xs text-purple-700">صافي الرواتب</div>' +
27483:                 '<div class="text-lg font-black">' +
27484:                 _fmtNum(payrollNetTotal) +
27485:                 '</div></div>' +
27486:                 '</div>' +
27487:                 '<div class="mb-4 text-xs text-gray-500">' +
27488:                 'إجمالي عدد الموظفين داخل المسيرات: ' +
27489:                 _fmtNum(payrollEmployeeTotal) +
27490:                 '</div>' +
27491:                 _table(
27492:                     [
27493:                         'رقم المسير',
27494:                         'الفترة',
27495:                         'النطاق',
27496:                         'الموظفون',
27497:                         'إجمالي الأجور',
27498:                         'الاستقطاعات',
27499:                         'الصافي',
27500:                         'الحالة'
27501:                     ],
27502:                     payrollTableRows
27503:                 );
27504:         }
27505:         else {
27506: 
27507:             html =
27508:                 '<div class="text-center py-4 text-gray-500">' +
27509:                 'هذا التقرير غير متوفر بعد' +
27510:                 '</div>';
27511:         }
27512: 
27513:         safeHTML(
27514:     resultDiv,
27515:     html +
27516:     '<div class="mt-4 pt-3 border-t text-xs text-gray-400 flex flex-wrap justify-between gap-2">' +
27517:     '<span>المصدر: Production</span>' +
27518:     '<span>آخر تنفيذ: ' +
27519:     _esc(
27520:         new Date().toLocaleString('ar-EG')
27521:     ) +
27522:     '</span>' +
27523:     '</div>'
27524: );
27525: 
27526:     } catch (e) {
27527: 
27528:         console.error(
27529:             'RW_Reports_Comprehensive._generateReport',
27530:             e
27531:         );
27532: 
27533:         safeHTML(
27534:             resultDiv,
27535:             '<div class="text-center py-8 text-red-500">' +
27536:             'فشل تحميل التقرير: ' +
27537:             _esc(
27538:                 e.message ||
27539:                 'خطأ غير معروف'
27540:             ) +
27541:             '</div>'
27542:         );
27543:     }
27544: }
27545: 
27546: function _exportReportCsv() {
27547:     var resultDiv = byId('report-result');
27548: 
27549:     if (!resultDiv) {
27550:         _showToast('لا يوجد تقرير للتصدير', 'info');
27551:         return;
27552:     }
27553: 
27554:     var table = resultDiv.querySelector('table');
27555: 
27556:     if (!table) {
27557:         _showToast('لا يوجد جدول قابل للتصدير', 'info');
27558:         return;
27559:     }
27560: 
27561:     var rows = table.querySelectorAll('tr');
27562:     var csv = [];
27563: 
27564:     function csvCell(value) {
27565:         var s = String(value == null ? '' : value)
27566:             .replace(/\r?\n|\r/g, ' ')
27567:             .replace(/"/g, '""');
27568: 
27569:         return '"' + s + '"';
27570:     }
27571: 
27572:     for (var i = 0; i < rows.length; i++) {
27573:         var cells = rows[i].querySelectorAll('th,td');
27574:         var line = [];
27575: 
27576:         for (var j = 0; j < cells.length; j++) {
27577:             line.push(csvCell(cells[j].innerText || ''));
27578:         }
27579: 
27580:         csv.push(line.join(','));
27581:     }
27582: 
27583:     var blob = new Blob(
27584:         ['\uFEFF' + csv.join('\r\n')],
27585:         { type: 'text/csv;charset=utf-8;' }
27586:     );
27587: 
27588:     var url = URL.createObjectURL(blob);
27589:     var a = document.createElement('a');
27590: 
27591:     a.href = url;
27592:     a.download =
27593:         'rawaea-report-' +
27594:         String(_currentReport || 'report') +
27595:         '-' +
27596:         new Date().toISOString().slice(0, 10) +
27597:         '.csv';
27598: 
27599:     document.body.appendChild(a);
27600:     a.click();
27601:     document.body.removeChild(a);
27602: 
27603:     URL.revokeObjectURL(url);
27604: }
27605: function _printReport() {
27606:     var resultDiv = byId('report-result');
27607: 
27608:     if (!resultDiv || !resultDiv.innerHTML) {
27609:         _showToast('لا يوجد تقرير للطباعة', 'info');
27610:         return;
27611:     }
27612: 
27613:     var printWindow = window.open('', '_blank');
27614: 
27615:     if (!printWindow) {
27616:         _showToast('الرجاء السماح بالنوافذ المنبثقة', 'warning');
27617:         return;
27618:     }
27619: 
27620:     var html =
27621:         '<!DOCTYPE html>' +
27622:         '<html dir="rtl">' +
27623:         '<head>' +
27624:         '<meta charset="UTF-8">' +
27625:         '<title>تقرير الروائع ERP</title>' +
27626:         '<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700;900&display=swap" rel="stylesheet">' +
27627:         '<style>' +
27628:         'body{font-family:Cairo,sans-serif;padding:20px;color:#111827}' +
27629:         'table{width:100%;border-collapse:collapse;margin-top:15px}' +
27630:         'th,td{border:1px solid #ddd;padding:8px}' +
27631:         'th{background:#f2f2f2;font-weight:800}' +
27632:         '.text-center{text-align:center}' +
27633:         '</style>' +
27634:         '</head>' +
27635:         '<body>' +
27636:         resultDiv.innerHTML +
27637:         '<script>window.onload=function(){window.print();};<\/script>' +
27638:         '</body></html>';
27639: 
27640:     printWindow.document.open();
27641:     printWindow.document.write(html);
27642:     printWindow.document.close();
27643: }
--- WINDOW 29484-29694 around 29514 ---
29484:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
29485:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
29486:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
29487: 
29488:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
29489:     }
29490: };
29491: window.RW_Views = RW_Views;
29492: // ============================================================
29493: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
29494: // ============================================================
29495: var RW_HR = (function() {
29496:  'use strict';
29497:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
29498:   var T=[
29499:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
29500:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
29501:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
29502:   ];
29503:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
29504:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
29505:   function num(v){v=Number(v);return isFinite(v)?v:0}
29506:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
29507:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
29508:   function iso(v){return v?new Date(v).toISOString():null}
29509:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
29510:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
29511:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
29512:   function opClear(k){if(k)delete H.ops[k]}
29513:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
29514:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
29515:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
29516:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
29517:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
29518:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
29519:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
29520:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
29521:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
29522:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
29523:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
29524:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
29525:  function modal(title,body,onSubmit,key){
29526:   var old=E('rw-hr-modal-root');
29527:   if(old)old.remove();
29528:   var r=document.createElement('div');
29529:   r.id='rw-hr-modal-root';
29530:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
29531:   document.body.appendChild(r);
29532:   E('rw-hr-close').onclick=closeModal;
29533:   E('rw-hr-cancel').onclick=closeModal;
29534:   r.addEventListener('click',function(e){
29535:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29536:     if(ac){
29537:       e.preventDefault();
29538:       handle(ac.getAttribute('data-hr-action'));
29539:     }
29540:   });
29541:   if(onSubmit===null){
29542:     var f=E('rw-hr-form');
29543:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29544:   }else{
29545:     E('rw-hr-form').onsubmit=async function(e){
29546:       e.preventDefault();
29547:       var save=e.target.querySelector('button[type="submit"]');
29548:       try{
29549:         if(save){
29550:           save.disabled=true;
29551:           save.textContent='جارٍ الحفظ…';
29552:         }
29553:         await onSubmit(key||'form:'+Date.now());
29554:       }catch(err){
29555:         toast(err.message||'تعذر الحفظ','error');
29556:         if(save){
29557:           save.disabled=false;
29558:           save.textContent='حفظ';
29559:         }
29560:       }
29561:     };
29562:   }
29563: }
29564: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
29565:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
29566:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
29567:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
29568:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
29569:   function employeeOpts(){return ppl()}
29570:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29571:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
29572:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29573:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
29574:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
29575:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
29576:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
29577:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
29578:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
29579:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
29580:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
29581:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
29582:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
29583:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
29584:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
29585:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
29586:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
29587:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
29588:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
29589:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
29590:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
29591:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
29592:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
29593:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
29594:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
29595:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
29596:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
29597:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
29598:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
29599:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
29600:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
29601:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
29602:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
29603:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
29604:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
29605:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
29606:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
29607:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
29608:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
29609:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
29610:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
29611:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
29612:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
29613:   (function installModalResilience(){
29614:     document.addEventListener('click',function(e){
29615:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29616:       if(!ac)return;
29617:       var page=E('rw-page-container');
29618:       if(page&&page.contains(ac))return;
29619:       e.preventDefault();
29620:       handle(ac.getAttribute('data-hr-action'));
29621:     },true);
29622:     window.addEventListener('unhandledrejection',function(e){
29623:       var root=E('rw-hr-modal-root');
29624:       if(!root)return;
29625:       e.preventDefault();
29626:       var msg=e.reason&&(e.reason.message||String(e.reason));
29627:       if(msg)toast(msg,'error');
29628:     });
29629:     try{
29630:       var mo=new MutationObserver(function(){
29631:         var root=E('rw-hr-modal-root');
29632:         if(!root||!E('hr360'))return;
29633:         var f=E('rw-hr-form');
29634:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29635:       });
29636:       mo.observe(document.body,{childList:true,subtree:true});
29637:     }catch(e){}
29638:   }());
29639: 
29640: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
29641: 
29642: 
29643: // ============================================================
29644: // RW_CRM – إدارة علاقات العملاء (CRM)
29645: // ============================================================
29646: var RW_CRM = (function() {
29647:     'use strict';
29648: 
29649:     var state = {
29650:         customers: [],
29651:         assignees: [],
29652:         kpi: {},
29653:         search: '',
29654:         activeOnly: false,
29655:         searchTimer: null
29656:     };
29657: 
29658:     function _esc(s) {
29659:         return String(s == null ? '' : s)
29660:             .replace(/&/g, '&amp;')
29661:             .replace(/</g, '&lt;')
29662:             .replace(/>/g, '&gt;')
29663:             .replace(/"/g, '&quot;')
29664:             .replace(/'/g, '&#39;');
29665:     }
29666: 
29667:     function _fmtNum(n) {
29668:         return Number(n || 0).toLocaleString('ar-EG');
29669:     }
29670: 
29671:     function _fmtMoney(n) {
29672:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
29673:     }
29674: 
29675:     function _today() {
29676:         var d = new Date();
29677:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
29678:         return local.toISOString().slice(0, 10);
29679:     }
29680: 
29681:     function _statusLabel(s) {
29682:         var map = {
29683:             Open: 'مفتوحة',
29684:             'معلقة': 'معلقة',
29685:             completed: 'مكتملة',
29686:             'مكتملة': 'مكتملة',
29687:             cancelled: 'ملغاة',
29688:             'ملغاة': 'ملغاة'
29689:         };
29690:         return map[s] || s || 'غير محددة';
29691:     }
29692: 
29693:     function _statusClass(s) {
29694:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
--- WINDOW 29581-29791 around 29611 ---
29581:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
29582:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
29583:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
29584:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
29585:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
29586:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
29587:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
29588:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
29589:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
29590:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
29591:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
29592:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
29593:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
29594:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
29595:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
29596:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
29597:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
29598:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
29599:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
29600:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
29601:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
29602:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
29603:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
29604:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
29605:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
29606:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
29607:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
29608:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
29609:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
29610:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
29611:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
29612:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
29613:   (function installModalResilience(){
29614:     document.addEventListener('click',function(e){
29615:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29616:       if(!ac)return;
29617:       var page=E('rw-page-container');
29618:       if(page&&page.contains(ac))return;
29619:       e.preventDefault();
29620:       handle(ac.getAttribute('data-hr-action'));
29621:     },true);
29622:     window.addEventListener('unhandledrejection',function(e){
29623:       var root=E('rw-hr-modal-root');
29624:       if(!root)return;
29625:       e.preventDefault();
29626:       var msg=e.reason&&(e.reason.message||String(e.reason));
29627:       if(msg)toast(msg,'error');
29628:     });
29629:     try{
29630:       var mo=new MutationObserver(function(){
29631:         var root=E('rw-hr-modal-root');
29632:         if(!root||!E('hr360'))return;
29633:         var f=E('rw-hr-form');
29634:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29635:       });
29636:       mo.observe(document.body,{childList:true,subtree:true});
29637:     }catch(e){}
29638:   }());
29639: 
29640: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
29641: 
29642: 
29643: // ============================================================
29644: // RW_CRM – إدارة علاقات العملاء (CRM)
29645: // ============================================================
29646: var RW_CRM = (function() {
29647:     'use strict';
29648: 
29649:     var state = {
29650:         customers: [],
29651:         assignees: [],
29652:         kpi: {},
29653:         search: '',
29654:         activeOnly: false,
29655:         searchTimer: null
29656:     };
29657: 
29658:     function _esc(s) {
29659:         return String(s == null ? '' : s)
29660:             .replace(/&/g, '&amp;')
29661:             .replace(/</g, '&lt;')
29662:             .replace(/>/g, '&gt;')
29663:             .replace(/"/g, '&quot;')
29664:             .replace(/'/g, '&#39;');
29665:     }
29666: 
29667:     function _fmtNum(n) {
29668:         return Number(n || 0).toLocaleString('ar-EG');
29669:     }
29670: 
29671:     function _fmtMoney(n) {
29672:         return Number(n || 0).toLocaleString('ar-EG') + ' EGP';
29673:     }
29674: 
29675:     function _today() {
29676:         var d = new Date();
29677:         var local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
29678:         return local.toISOString().slice(0, 10);
29679:     }
29680: 
29681:     function _statusLabel(s) {
29682:         var map = {
29683:             Open: 'مفتوحة',
29684:             'معلقة': 'معلقة',
29685:             completed: 'مكتملة',
29686:             'مكتملة': 'مكتملة',
29687:             cancelled: 'ملغاة',
29688:             'ملغاة': 'ملغاة'
29689:         };
29690:         return map[s] || s || 'غير محددة';
29691:     }
29692: 
29693:     function _statusClass(s) {
29694:         if (s === 'completed' || s === 'مكتملة') return 'bg-green-100 text-green-700';
29695:         if (s === 'cancelled' || s === 'ملغاة') return 'bg-gray-100 text-gray-600';
29696:         return 'bg-amber-100 text-amber-700';
29697:     }
29698: 
29699:     function _assignedLabel(customer) {
29700:         var rows = Array.isArray(customer && customer.assigned_to) ? customer.assigned_to : [];
29701:         if (!rows.length) return 'غير مسند';
29702:         var active = rows.filter(function(x) { return x && x.active !== false; });
29703:         if (!active.length) active = rows;
29704:         return active.slice(0, 2).map(function(x) {
29705:             return x.name || x.email || '—';
29706:         }).join('، ') + (active.length > 2 ? ' +' + (active.length - 2) : '');
29707:     }
29708: 
29709:     async function _loadDirectory() {
29710:         var res = await supabase.rpc('crm_customer_directory', {
29711:             p_search: state.search || null,
29712:             p_active_only: state.activeOnly,
29713:             p_limit: 200,
29714:             p_offset: 0
29715:         });
29716:         if (res.error) throw res.error;
29717: 
29718:         var payload = res.data || {};
29719:         state.customers = Array.isArray(payload.customers) ? payload.customers : [];
29720:         state.assignees = Array.isArray(payload.assignees) ? payload.assignees : [];
29721:         state.kpi = payload.kpi || {};
29722:         return payload;
29723:     }
29724: 
29725:     function _renderKpis() {
29726:         var k = state.kpi || {};
29727:         return '<div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">' +
29728:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">إجمالي العملاء</div><div class="text-2xl font-black text-indigo-600 mt-2">' + _fmtNum(k.total_customers) + '</div></div>' +
29729:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">عملاء نشطون</div><div class="text-2xl font-black text-green-600 mt-2">' + _fmtNum(k.active_customers) + '</div></div>' +
29730:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">ذمم مسجلة</div><div class="text-2xl font-black text-red-600 mt-2">' + _fmtMoney(k.master_debt_total) + '</div></div>' +
29731:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متابعات مفتوحة</div><div class="text-2xl font-black text-amber-600 mt-2">' + _fmtNum(k.open_followups) + '</div></div>' +
29732:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">متأخرة</div><div class="text-2xl font-black text-rose-600 mt-2">' + _fmtNum(k.overdue_followups) + '</div></div>' +
29733:             '<div class="bg-white rounded-2xl border p-4"><div class="text-xs text-gray-500">مستحقة اليوم</div><div class="text-2xl font-black text-blue-600 mt-2">' + _fmtNum(k.due_today) + '</div></div>' +
29734:         '</div>';
29735:     }
29736: 
29737:     function _renderTable() {
29738:         if (!state.customers.length) {
29739:             return '<div class="text-center py-16 text-gray-400"><div class="text-5xl mb-3">👥</div><div class="font-black text-lg">لا توجد عملاء مطابقون</div><div class="text-sm mt-2">غيّر البحث أو الفلاتر ثم أعد المحاولة.</div></div>';
29740:         }
29741: 
29742:         var html = '<div class="overflow-x-auto"><table class="w-full text-sm">' +
29743:             '<thead class="bg-slate-50"><tr>' +
29744:             '<th class="p-3 text-right">العميل</th>' +
29745:             '<th class="p-3 text-right">التواصل</th>' +
29746:             '<th class="p-3 text-right">التصنيف</th>' +
29747:             '<th class="p-3 text-center">المبيعات</th>' +
29748:             '<th class="p-3 text-center">الأوردرات</th>' +
29749:             '<th class="p-3 text-center">المتابعة القادمة</th>' +
29750:             '<th class="p-3 text-right">المسؤول</th>' +
29751:             '<th class="p-3 text-center">الإجراء</th>' +
29752:             '</tr></thead><tbody>';
29753: 
29754:         for (var i = 0; i < state.customers.length; i++) {
29755:             var c = state.customers[i] || {};
29756:             var overdue = Number(c.overdue_followups || 0) > 0;
29757:             var next = c.next_followup_date ? String(c.next_followup_date) : '—';
29758: 
29759:             html += '<tr class="border-b hover:bg-slate-50">' +
29760:                 '<td class="p-3"><div class="font-black">' + _esc(c.name) + '</div><div class="text-xs text-gray-400">' + _esc(c.customer_code) + '</div></td>' +
29761:                 '<td class="p-3"><div>' + _esc(c.phone || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.area || '—') + '</div></td>' +
29762:                 '<td class="p-3"><div class="font-bold">' + _esc(c.customer_type || '—') + '</div><div class="text-xs text-gray-400">' + _esc(c.payment_type || '—') + '</div></td>' +
29763:                 '<td class="p-3 text-center font-black">' + _fmtMoney(c.sales_total) + '</td>' +
29764:                 '<td class="p-3 text-center font-black">' + _fmtNum(c.order_count) + '</td>' +
29765:                 '<td class="p-3 text-center"><span class="px-2 py-1 rounded-full text-xs font-black ' + (overdue ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-700') + '">' + _esc(next) + '</span></td>' +
29766:                 '<td class="p-3">' + _esc(_assignedLabel(c)) + '</td>' +
29767:                 '<td class="p-3 text-center"><button type="button" data-crm-open360="' + _esc(c.id) + '" class="px-4 py-2 bg-indigo-600 text-white rounded-xl font-black">متابعة</button></td>' +
29768:             '</tr>';
29769:         }
29770: 
29771:         return html + '</tbody></table></div>';
29772:     }
29773: 
29774:     function _bindDirectory() {
29775:         var search = byId('crm-search');
29776:         if (search) {
29777:             search.value = state.search;
29778:             search.addEventListener('input', function() {
29779:                 state.search = search.value.trim();
29780:                 clearTimeout(state.searchTimer);
29781:                 state.searchTimer = setTimeout(function() {
29782:                     _loadDirectory().then(function() {
29783:                         safeHTML(byId('crm-customers-list'), _renderTable());
29784:                         _bindOpen360();
29785:                         safeHTML(byId('crm-kpis'), _renderKpis());
29786:                     }).catch(function(e) {
29787:                         showToast(e.message || 'فشل البحث', 'error');
29788:                     });
29789:                 }, 250);
29790:             });
29791:         }
--- RW_HR_FULL 29495-29640 ---
29495: var RW_HR = (function() {
29496:  'use strict';
29497:   var H={tab:'dashboard',actor:null,companyId:null,employees:[],branches:[],channel:null,timer:null,busy:false,ops:{}};
29498:   var T=[
29499:     ['dashboard','لوحة التحكم','fa-chart-pie'],['employees','الموظفون','fa-users'],['organization','الهيكل','fa-sitemap'],
29500:     ['contracts','العقود','fa-file-contract'],['attendance','الحضور','fa-clock'],['leaves','الإجازات','fa-calendar-days'],
29501:     ['requests','الطلبات','fa-list-check'],['advances','السلف','fa-hand-holding-dollar'],['payroll','الرواتب','fa-money-check-dollar'],['documents','المستندات','fa-folder-open']
29502:   ];
29503:   function E(id){return typeof byId==='function'?byId(id):document.getElementById(id)}
29504:   function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;')}
29505:   function num(v){v=Number(v);return isFinite(v)?v:0}
29506:   function money(v){return num(v).toLocaleString('ar-EG',{maximumFractionDigits:2})}
29507:   function date(v){return v?String(v).slice(0,10).split('-').reverse().join('/'):'-'}
29508:   function iso(v){return v?new Date(v).toISOString():null}
29509:   function toast(m,k){if(typeof showToast==='function')return showToast(m,k||'success');if(typeof Swal!=='undefined')return Swal.fire({toast:true,position:'top-end',icon:k||'success',title:m,showConfirmButton:false,timer:2600});alert(m)}
29510:   function safe(el,html){if(!el)return;if(typeof safeHTML==='function')safeHTML(el,html);else el.innerHTML=html}
29511:   function opKey(k){if(!H.ops[k])H.ops[k]='MOTHER-HR:'+k+':'+Date.now()+':'+Math.random().toString(36).slice(2,10);return H.ops[k]}
29512:   function opClear(k){if(k)delete H.ops[k]}
29513:   async function actor(){var a=await supabase.auth.getUser();if(a.error||!a.data.user)throw Error('جلسة المستخدم غير صالحة');var u=await supabase.from('users').select('id,email,company_id,role,name,status,phone,employee_id,default_branch_id,active_warehouse_role').eq('auth_id',a.data.user.id).maybeSingle();if(u.error)throw u.error;if(!u.data||!u.data.id||!u.data.company_id)throw Error('تعذر تحديد سياق الموظف والشركة');H.actor=u.data;H.companyId=u.data.company_id}
29514:   async function q(view,payload){var r=await supabase.rpc('hr_query',{p_view:view,p_payload:payload||{}});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل قراءة HR');return r.data}
29515:   async function c(command,payload,key){var k=key||('cmd:'+command);var r=await supabase.rpc('hr_command_atomic',{p_command:command,p_payload:payload||{},p_operation_id:opKey(k),p_actor_user_id:H.actor.id,p_actor_email:H.actor.email});if(r.error)throw r.error;if(!r.data||r.data.success===false)throw Error((r.data&&(r.data.msg||r.data.code))||'فشل تنفيذ أمر HR');opClear(k);return r.data}
29516:   function btn(text,action,cls){return '<button type="button" data-hr-action="'+esc(action)+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(cls||'bg-indigo-600 text-white hover:bg-indigo-700')+'">'+esc(text)+'</button>'}
29517:   function badge(text,k){var m={ok:'bg-emerald-50 text-emerald-700 border-emerald-100',warn:'bg-amber-50 text-amber-700 border-amber-100',bad:'bg-rose-50 text-rose-700 border-rose-100',info:'bg-blue-50 text-blue-700 border-blue-100',muted:'bg-slate-50 text-slate-600 border-slate-100'};return '<span class="inline-flex items-center px-2.5 py-1 rounded-full border text-[11px] font-black '+(m[k]||m.muted)+'">'+esc(text)+'</span>'}
29518:   function card(title,sub,body,actions){return '<section class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden"><div class="px-6 py-5 bg-slate-50/80 border-b flex flex-col lg:flex-row lg:items-center justify-between gap-3"><div><h3 class="font-black text-slate-800">'+esc(title)+'</h3><p class="text-xs text-slate-500 mt-1">'+esc(sub||'')+'</p></div><div class="flex flex-wrap gap-2">'+(actions||'')+'</div></div><div class="p-6">'+body+'</div></section>'}
29519:   function stat(title,value,icon,cls){return '<div class="bg-white rounded-2xl border border-slate-100 p-5 shadow-sm"><div class="flex items-center justify-between"><div><div class="text-xs text-slate-500 font-bold">'+esc(title)+'</div><div class="text-2xl font-black mt-2">'+esc(value)+'</div></div><div class="w-11 h-11 rounded-2xl flex items-center justify-center '+(cls||'bg-indigo-50 text-indigo-700')+'"><i class="fas '+icon+'"></i></div></div></div>'}
29520:   function table(headers,rows){if(!rows||!rows.length)return '<div class="py-10 text-center text-slate-400 font-bold">لا توجد بيانات</div>';return '<div class="overflow-auto"><table class="min-w-full text-sm"><thead><tr>'+headers.map(function(h){return '<th class="px-4 py-3 text-right bg-slate-50 text-slate-500 font-black whitespace-nowrap">'+esc(h)+'</th>'}).join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>'}
29521:   function tr(cells){return '<tr class="border-t border-slate-100 hover:bg-slate-50/70">'+cells.map(function(x){return '<td class="px-4 py-3 align-top">'+x+'</td>'}).join('')+'</tr>'}
29522:   function field(label,id,value,type,extra){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><input id="'+esc(id)+'" type="'+esc(type||'text')+'" value="'+esc(value==null?'':value)+'" '+(extra||'')+' class="w-full px-4 py-3 rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-200"></label>'}
29523:   function textarea(label,id,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><textarea id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200 min-h-[95px] focus:outline-none focus:ring-2 focus:ring-indigo-200">'+esc(value||'')+'</textarea></label>'}
29524:   function select(label,id,list,value){return '<label class="block"><span class="block text-xs font-black text-slate-600 mb-2">'+esc(label)+'</span><select id="'+esc(id)+'" class="w-full px-4 py-3 rounded-xl border border-slate-200">'+(list||[]).map(function(x){return '<option value="'+esc(x.value)+'"'+(String(x.value)===String(value==null?'':value)?' selected':'')+'>'+esc(x.label)+'</option>'}).join('')+'</select></label>'}
29525:  function modal(title,body,onSubmit,key){
29526:   var old=E('rw-hr-modal-root');
29527:   if(old)old.remove();
29528:   var r=document.createElement('div');
29529:   r.id='rw-hr-modal-root';
29530:   r.innerHTML='<div class="fixed inset-0 z-[1200] bg-slate-950/60 backdrop-blur-sm flex items-center justify-center p-4"><div class="bg-white w-full max-w-6xl max-h-[94vh] overflow-hidden rounded-3xl shadow-2xl flex flex-col"><div class="flex items-center justify-between px-6 py-4 bg-slate-50 border-b"><div><div class="font-black text-lg">'+esc(title)+'</div><div class="text-xs text-slate-500 mt-1">تحكم مركزي من النظام الأم</div></div><button id="rw-hr-close" type="button" class="w-10 h-10 rounded-xl bg-white border text-lg">×</button></div><form id="rw-hr-form" class="overflow-y-auto p-6">'+body+'<div class="flex justify-end gap-2 mt-6 pt-4 border-t"><button type="button" id="rw-hr-cancel" class="px-5 py-3 rounded-xl bg-slate-100 font-black">إلغاء</button><button class="px-5 py-3 rounded-xl bg-indigo-600 text-white font-black">حفظ</button></div></form></div></div>';
29531:   document.body.appendChild(r);
29532:   E('rw-hr-close').onclick=closeModal;
29533:   E('rw-hr-cancel').onclick=closeModal;
29534:   r.addEventListener('click',function(e){
29535:     var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29536:     if(ac){
29537:       e.preventDefault();
29538:       handle(ac.getAttribute('data-hr-action'));
29539:     }
29540:   });
29541:   if(onSubmit===null){
29542:     var f=E('rw-hr-form');
29543:     if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29544:   }else{
29545:     E('rw-hr-form').onsubmit=async function(e){
29546:       e.preventDefault();
29547:       var save=e.target.querySelector('button[type="submit"]');
29548:       try{
29549:         if(save){
29550:           save.disabled=true;
29551:           save.textContent='جارٍ الحفظ…';
29552:         }
29553:         await onSubmit(key||'form:'+Date.now());
29554:       }catch(err){
29555:         toast(err.message||'تعذر الحفظ','error');
29556:         if(save){
29557:           save.disabled=false;
29558:           save.textContent='حفظ';
29559:         }
29560:       }
29561:     };
29562:   }
29563: }
29564: function closeModal(){var r=E('rw-hr-modal-root');if(r)r.remove()}
29565:   function ppl(){return H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'}).map(function(e){return{value:e.id,label:(e.name||e.email)+' — '+e.email}})}
29566:   async function loadPeople(){var d=await q('employees');H.employees=d.rows||[];return H.employees}
29567:   async function loadBranches(){var r=await supabase.from('branches').select('id,branch_code,name,is_active').eq('company_id',H.companyId).order('name');if(r.error)throw r.error;H.branches=r.data||[];return H.branches}
29568:   function branches(){return H.branches.filter(function(x){return x.is_active!==false}).map(function(x){return{value:x.id,label:(x.branch_code||'')+' — '+x.name}})}
29569:   function employeeOpts(){return ppl()}
29570:   function deptOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29571:   function posOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.title}})}
29572:   function scheduleOpts(rows){return (rows||[]).map(function(x){return{value:x.id,label:x.name}})}
29573:   function tabbar(){return '<div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-2 flex gap-2 flex-wrap">'+T.map(function(x){return '<button type="button" data-hr-tab="'+x[0]+'" class="px-4 py-2.5 rounded-xl font-black text-sm '+(H.tab===x[0]?'bg-indigo-600 text-white':'text-slate-600 hover:bg-slate-50')+'"><i class="fas '+x[2]+' ml-1"></i>'+x[1]+'</button>'}).join('')+'</div>'}
29574:   function employeeMeta(e){return '<div class="space-y-2 text-sm"><div><span class="text-slate-500">القسم:</span> <b>'+esc(e.department_name||e.department||'-')+'</b></div><div><span class="text-slate-500">الوظيفة:</span> <b>'+esc(e.position_name||e.job_title||e.role||'-')+'</b></div><div><span class="text-slate-500">الفرع:</span> <b>'+esc(e.branch_name||'-')+'</b></div><div><span class="text-slate-500">العقد:</span> '+(e.contract_status==='active'?badge('فعال','ok'):badge(e.contract_status||'غير موجود','muted'))+'</div></div>'}
29575:   async function dashboard(cn){var d=await q('dashboard'),today=new Date().toISOString().slice(0,10),a=await q('attendance',{from:today,to:today,limit:100}),r=await q('request_approvals');var ar=a.rows||[],pending=(r.rows||[]).filter(function(x){return x.status==='pending'}).length;cn.innerHTML='<div class="space-y-5"><div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">'+stat('الموظفون',d.employees||0,'fa-users')+stat('النشطون',d.active_employees||0,'fa-user-check','bg-emerald-50 text-emerald-700')+stat('العقود الفعالة',d.contracts||0,'fa-file-contract','bg-sky-50 text-sky-700')+stat('طلبات الإجازة',d.pending_leaves||0,'fa-calendar-days','bg-amber-50 text-amber-700')+stat('اعتمادات معلقة',pending,'fa-list-check','bg-rose-50 text-rose-700')+'</div><div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الحضور اليوم','ملخص مباشر من سجلات الحضور',table(['الموظف','الدخول','الخروج','الساعات','التأخير'],ar.slice(0,15).map(function(x){return tr([esc(x.employee_name||x.email),esc(x.check_in?new Date(x.check_in).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),esc(x.check_out?new Date(x.check_out).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'}):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):badge('في الموعد','ok')])})),btn('فتح الحضور','tab:attendance','bg-slate-100 text-slate-700'))+card('الأعمال الحرجة','نقاط تحتاج متابعة', '<div class="grid gap-3"><div class="p-4 rounded-2xl bg-amber-50 border border-amber-100 flex justify-between"><span>عقود تنتهي خلال 30 يومًا</span><b>'+esc(d.contracts_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-rose-50 border border-rose-100 flex justify-between"><span>مستندات تنتهي خلال 30 يومًا</span><b>'+esc(d.documents_expiring_30d||0)+'</b></div><div class="p-4 rounded-2xl bg-blue-50 border border-blue-100 flex justify-between"><span>طلبات في الاعتماد</span><b>'+esc(d.pending_requests||0)+'</b></div></div>')+'</div></div>'}
29576:   async function employeesTab(cn){await loadPeople();var rows=H.employees.filter(function(e){return String(e.role||'').toLowerCase()!=='owner'&&e.role!=='مالك'});cn.innerHTML=card('دليل الموظفين','Employee 360 من مركز واحد','<div class="flex gap-2 mb-5"><input id="hr-emp-search" class="flex-1 px-4 py-3 rounded-xl border" placeholder="بحث بالاسم أو البريد أو الرقم أو الوظيفة">'+btn('ملف موظف','new-profile')+'</div><div id="hr-emp-grid" class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">'+rows.map(function(e){var total=num(e.basic_salary)+num(e.housing_allowance)+num(e.transport_allowance)+num(e.other_allowance)-num(e.default_deduction);return '<article data-eid="'+esc(e.id)+'" class="p-5 bg-white border border-slate-100 rounded-2xl cursor-pointer hover:shadow-md"><div class="flex items-center gap-3"><div class="w-14 h-14 rounded-2xl bg-indigo-600 text-white flex items-center justify-center text-xl font-black">'+esc((e.name||'?')[0])+'</div><div class="min-w-0"><div class="font-black truncate">'+esc(e.name)+'</div><div class="text-xs text-slate-500 truncate">'+esc(e.position_name||e.job_title||e.role||'-')+'</div></div></div><div class="mt-4">'+employeeMeta(e)+'</div><div class="mt-4 pt-3 border-t flex justify-between text-sm"><span class="text-slate-500">التعويض الحالي</span><b class="text-indigo-700">'+money(total)+' EGP</b></div></article>'}).join('')+'</div>');var s=E('hr-emp-search');if(s)s.oninput=function(){var v=s.value.toLowerCase();cn.querySelectorAll('[data-eid]').forEach(function(el){var e=rows.filter(function(x){return x.id===el.getAttribute('data-eid')})[0]||{};var h=[e.name,e.email,e.employee_number,e.job_title,e.department_name,e.position_name].join(' ').toLowerCase();el.style.display=!v||h.indexOf(v)>-1?'':'none'})};cn.querySelectorAll('[data-eid]').forEach(function(el){el.onclick=function(){open360(el.getAttribute('data-eid'))}})}
29577:   function buildTree(ds){var by={},root=[];(ds||[]).forEach(function(x){by[x.id]={id:x.id,name:x.name,code:x.code,parent:x.parent_department_id,manager:x.manager_employee_id,children:[]}});Object.keys(by).forEach(function(k){var x=by[k];if(x.parent&&by[x.parent])by[x.parent].children.push(x);else root.push(x)});function node(x,depth){var manager=H.employees.filter(function(e){return e.id===x.manager})[0];return '<div class="mr-'+Math.min(depth*3,12)+' rounded-2xl border border-slate-100 p-4 bg-white shadow-sm"><div class="flex justify-between gap-3"><div><div class="font-black">'+esc(x.name)+'</div><div class="text-xs text-slate-500">'+esc(x.code||'-')+(manager?' · مدير: '+esc(manager.name):'')+'</div></div>'+badge(x.children.length+' فرعي','info')+'</div>'+(x.children.length?'<div class="mt-3 space-y-3 border-r-2 border-slate-100 pr-4">'+x.children.map(function(c){return node(c,depth+1)}).join('')+'</div>':'')+'</div>'}return root.map(function(x){return node(x,0)}).join('')||'<div class="py-10 text-center text-slate-400 font-bold">لم تُنشأ إدارات بعد</div>'}
29578:   async function organizationTab(cn){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions'),a=await q('assignments'),s=await q('schedules');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الشجرة التنظيمية','العلاقات الإدارية الفعلية',buildTree(d.rows),btn('إدارة جديدة','new-dept'))+card('الإدارات','السجل الإداري',table(['الكود','الاسم','المدير','الحالة'],(d.rows||[]).map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([esc(x.code),esc(x.name),esc(m?m.name:'-'),x.is_active?badge('نشط','ok'):badge('غير نشط','muted')])})))+card('الوظائف','دليل المسميات والمستويات',table(['الكود','المسمى','القسم','المستوى'],(p.rows||[]).map(function(x){return tr([esc(x.code),esc(x.title),esc(x.department_name||'-'),esc(x.level||'-')])})),btn('وظيفة جديدة','new-pos'))+card('التعيينات','تاريخ ربط الموظف بالقسم والوظيفة والفرع',table(['الموظف','القسم','الوظيفة','الفرع','المدير','من','إلى'],(a.rows||[]).slice(0,150).map(function(x){return tr([esc(x.employee_name),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc((H.employees.filter(function(e){return e.id===x.manager_employee_id})[0]||{}).name||'-'),date(x.effective_from),date(x.effective_to)])})),btn('تعيين جديد','new-asg'))+card('جداول العمل','وردية + سماح + إضافي',table(['الكود','الاسم','بداية','نهاية','ساعات','إضافي'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.shift_start||'-'),esc(x.shift_end||'-'),money(x.daily_hours),money(x.overtime_multiplier)])})),btn('جدول جديد','new-schedule')+' '+btn('تعيين جدول','new-schedule-asg','bg-slate-100 text-slate-700'))+'</div>'}
29579:   async function contractsTab(cn){await loadPeople();var p=await q('positions'),s=await q('schedules'),d=await q('contracts'),cc=await q('contract_components');var rows=(d.rows||[]).map(function(x){var actions=btn('تفاصيل','open-employee:'+x.employee_id,'bg-slate-100 text-slate-700');return tr([esc(x.contract_no),esc(x.employee_name),esc(x.position_title||'-'),date(x.start_date),date(x.end_date),esc(x.pay_cycle||'-'),x.status==='active'?badge('فعال','ok'):badge(x.status||'-','muted'),actions])});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('العقود','التوظيف + التعويض + الجدول',table(['العقد','الموظف','الوظيفة','من','إلى','الدفع','الحالة',''],rows),btn('عقد جديد','new-contract'))+card('مكونات العقود','الاستحقاقات والخصومات الخاصة بالعقد',table(['العقد','الموظف','المكوّن','القيمة','فعال',''],(cc.rows||[]).map(function(x){return tr([esc(x.contract_no),esc(x.employee_name),esc(x.component_name||x.component_code||'-'),money(x.value),x.is_active?badge('نعم','ok'):badge('لا','muted'),x.is_active?btn('تعطيل','deactivate-cc:'+x.id,'bg-rose-50 text-rose-700 border border-rose-100'):'' ])})),btn('إضافة مكوّن','new-contract-component'))+'</div>'}
29580:   async function attendanceTab(cn){var d=await q('attendance',{limit:250}),e=await q('attendance_events',{limit:150});cn.innerHTML='<div class="space-y-5">'+card('الحضور والانصراف','يمكن التصفية بالتاريخ من النموذج أو مراجعة آخر السجلات',table(['التاريخ','الموظف','الحالة','الدخول','الخروج','الساعات','التأخير','الإضافي'],(d.rows||[]).map(function(x){return tr([date(x.attendance_date),esc(x.employee_name),esc(x.status),esc(x.check_in?new Date(x.check_in).toLocaleString('ar-EG'):'-'),esc(x.check_out?new Date(x.check_out).toLocaleString('ar-EG'):'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-',x.overtime_hours?badge(money(x.overtime_hours),'info'):'-'])})),btn('تسجيل يوم','attendance-day'))+card('الأحداث الخام','check-in / check-out قبل التجميع',table(['الوقت','الموظف','النوع','المصدر','الجهاز'],(e.rows||[]).map(function(x){return tr([esc(x.occurred_at?new Date(x.occurred_at).toLocaleString('ar-EG'):'-'),esc(x.employee_name||'-'),esc(x.event_type),esc(x.source||'-'),esc(x.device_id||'-')])})),btn('تسجيل حدث','attendance-event','bg-slate-100 text-slate-700'))+'</div>'}
29581:   async function leavesTab(cn){var l=await q('leaves'),b=await q('leave_balances'),t=await q('leave_types');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('طلبات الإجازات','طلب + اعتماد + رفض + إلغاء',table(['الموظف','النوع','من','إلى','المرفق','الحالة','إجراء'],(l.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-leave:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-leave:'+x.id,'bg-rose-600 text-white'):x.status==='approved'?btn('إلغاء','cancel-leave:'+x.id,'bg-amber-500 text-white'):'';return tr([esc(x.employee_name),esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),x.attachment_document_id?badge('مرفق','ok'):badge('لا يوجد','muted'),esc(x.status),a])})),btn('طلب إجازة','new-leave'))+card('الأرصدة','افتتاحي + مستحق + مستخدم + تعديل',table(['الموظف','النوع','السنة','المتاح','المستخدم'],(b.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.leave_type_name),esc(x.year),money(x.available_balance),money(x.used)])})),btn('ضبط رصيد','adjust-balance'))+card('أنواع الإجازات','الحصة + القيود + المستندات',table(['الكود','الاسم','مدفوعة','الحصة','حد متصل','مرفق','نصف يوم'],(t.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),x.paid?badge('نعم','ok'):badge('لا','muted'),money(x.annual_quota),esc(x.max_continuous_days||'-'),x.requires_attachment?badge('مطلوب','warn'):badge('لا','muted'),x.allow_half_day?badge('متاح','info'):badge('لا','muted')])})),btn('نوع جديد','new-leave-type'))+'</div>'}
29582:   async function requestsTab(cn){var r=await q('requests'),a=await q('request_approvals'),map={};(a.rows||[]).forEach(function(x){(map[x.request_id]||(map[x.request_id]=[])).push(x)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('الطلبات','مسار اعتماد متعدد الخطوات',table(['رقم','الموظف','النوع','الموضوع','الحالة','الخطوة','إجراء'],(r.rows||[]).map(function(x){var cur=(map[x.id]||[]).filter(function(z){return Number(z.step_no)===Number(x.current_step)})[0],can=x.status==='pending_approval'&&cur&&cur.status==='pending'&&(cur.approver_employee_id===H.actor.id||(!cur.approver_employee_id&&cur.approver_role&&String(cur.approver_role).toLowerCase()===String(H.actor.role||'').toLowerCase()));var ac=can?btn('اعتماد','approve-request:'+x.id,'bg-emerald-600 text-white')+' '+btn('رفض','reject-request:'+x.id,'bg-rose-600 text-white'):'';return tr([esc(x.request_no),esc(x.employee_name),esc(x.request_type),esc(x.subject),esc(x.status),esc(x.current_step)+' / '+esc(x.total_steps),ac])})),btn('طلب جديد','new-request'))+card('الاعتمادات','من هو المخول بالخطوة الحالية',table(['الطلب','الخطوة','المعتمد','الدور','الحالة','نفذ بواسطة'],(a.rows||[]).map(function(x){return tr([esc(x.request_no),esc(x.step_no),esc(x.approver_employee_id||'-'),esc(x.approver_role||'-'),esc(x.status),esc(x.acted_by||'-')])})))+'</div>'}
29583:   async function advancesTab(cn){var d=await q('advances');cn.innerHTML=card('السلف','إنشاء واعتماد وصرف',table(['الرقم','الموظف','القيمة','القسط','المتبقي','الحالة','إجراء'],(d.rows||[]).map(function(x){var a=x.status==='pending'?btn('اعتماد','approve-advance:'+x.id):x.status==='approved'?btn('صرف','disburse-advance:'+x.id):'';return tr([esc(x.advance_no),esc(x.employee_name),money(x.amount),money(x.installment_amount),money(x.remaining_balance),esc(x.status),a])})),btn('سلفة جديدة','new-advance'))}
29584:   async function payrollTab(cn){var p=await q('payroll_periods'),r=await q('payroll_runs'),s=await q('salary_components'),m=await q('payroll_accounting_map'),sl=await q('payslips');cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('فترات الرواتب','الفترة هي بوابة الحساب والاعتماد',table(['الفترة','من','إلى','الدفع','الحالة','إجراء'],(p.rows||[]).map(function(x){var a=x.status==='open'?btn('حساب','calculate-payroll:'+x.id):'';return tr([esc(x.period_code),date(x.start_date),date(x.end_date),date(x.pay_date),esc(x.status),a])})),btn('فترة جديدة','new-pay-period'))+card('تشغيل الرواتب','حساب → اعتماد → نشر',table(['التشغيل','الفترة','الحالة','الإجمالي','الخصومات','الصافي','إجراء'],(r.rows||[]).map(function(x){var a=x.status==='calculated'?btn('اعتماد','approve-payroll:'+x.id,'bg-emerald-600 text-white'):x.status==='approved'?btn('نشر','post-payroll:'+x.id):'';return tr([esc(x.run_no||x.id),esc(x.period_code),esc(x.status),money(x.gross_total),money(x.deduction_total),money(x.net_total),a])})))+card('مكونات الراتب','استحقاق/خصم + طريقة الحساب',table(['الكود','الاسم','النوع','طريقة الحساب','القيمة'],(s.rows||[]).map(function(x){return tr([esc(x.code),esc(x.name),esc(x.component_type),esc(x.calculation_type),money(x.default_value)])})),btn('مكوّن جديد','new-salary-component'))+card('الربط المحاسبي','حساب المصروف وحساب الالتزام',table(['المصروف','الالتزام','الحالة'],(m.rows||[]).map(function(x){return tr([esc(x.expense_account_name||x.expense_account_code||'-'),esc(x.liability_account_name||x.liability_account_code||'-'),x.is_active?badge('فعال','ok'):badge('غير فعال','muted')])})),btn('ضبط الربط','payroll-map'))+'</div>'+card('كشوف الرواتب','المخرجات النهائية',table(['الموظف','الفترة','الإجمالي','الخصومات','الصافي','الحالة'],(sl.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})));}
29585:   async function documentsTab(cn){var d=await q('documents'),e=await q('documents_expiring',{to:new Date(Date.now()+30*86400000).toISOString().slice(0,10)});cn.innerHTML='<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('مستندات الموظفين','مستندات خاصة بالشركة والموظف',table(['الموظف','الاسم','النوع','الانتهاء','الحالة',''],(d.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),esc(x.document_type),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):'' ])})),btn('مستند جديد','new-document'))+card('ينتهي قريبًا','خلال 30 يومًا',table(['الموظف','المستند','الانتهاء'],(e.rows||[]).map(function(x){return tr([esc(x.employee_name),esc(x.document_name||'-'),badge(date(x.expires_at),'warn')])})))+'</div>'}
29586:   async function open360(id){await loadPeople();var emp=H.employees.filter(function(x){return x.id===id})[0];if(!emp)return;modal('Employee 360','<div id="hr360" class="min-h-[240px]">جاري تحميل الملف...</div>',null,'360:'+id);try{var z=await Promise.all([q('assignments',{employee_id:id}),q('contracts'),q('attendance',{employee_id:id,limit:30}),q('leaves',{employee_id:id}),q('leave_balances',{employee_id:id}),q('payslips',{employee_id:id}),q('documents',{employee_id:id}),q('advances',{employee_id:id}),q('work_entries',{employee_id:id})]);var as=z[0].rows||[],ct=(z[1].rows||[]).filter(function(x){return x.employee_id===id}),at=z[2].rows||[],lv=z[3].rows||[],bl=z[4].rows||[],ps=z[5].rows||[],dc=z[6].rows||[],av=z[7].rows||[],we=z[8].rows||[];var current=ct[0]||{};var html='<div class="space-y-5">'+card('الهوية الوظيفية','الملف الأساسي', '<div class="grid grid-cols-1 md:grid-cols-3 gap-4"><div><span class="text-slate-500 text-xs">الاسم</span><div class="font-black text-lg">'+esc(emp.name)+'</div></div><div><span class="text-slate-500 text-xs">البريد</span><div class="font-bold">'+esc(emp.email)+'</div></div><div><span class="text-slate-500 text-xs">الرقم الوظيفي</span><div class="font-bold">'+esc(emp.employee_number||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهاتف</span><div class="font-bold">'+esc(emp.phone||'-')+'</div></div><div><span class="text-slate-500 text-xs">الهوية</span><div class="font-bold">'+esc(emp.national_id||'-')+'</div></div><div><span class="text-slate-500 text-xs">العنوان</span><div class="font-bold">'+esc(emp.address||'-')+'</div></div></div>',btn('تعديل الملف','edit-profile:'+id))+card('الوضع الحالي','القسم + الوظيفة + الفرع + العقد','<div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm"><div class="p-3 rounded-xl bg-slate-50">القسم<br><b>'+esc(emp.department_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الوظيفة<br><b>'+esc(emp.position_name||emp.job_title||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">الفرع<br><b>'+esc(emp.branch_name||'-')+'</b></div><div class="p-3 rounded-xl bg-slate-50">العقد<br><b>'+esc(current.contract_no||emp.contract_no||'-')+'</b></div></div>',btn('عقد جديد','new-contract:'+id))+card('التعويض','قيم الراتب الأساسية', '<div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm"><div class="p-3 rounded-xl bg-indigo-50">أساسي<br><b>'+money(emp.basic_salary)+'</b></div><div class="p-3 rounded-xl bg-slate-50">سكن<br><b>'+money(emp.housing_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">نقل<br><b>'+money(emp.transport_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">أخرى<br><b>'+money(emp.other_allowance)+'</b></div><div class="p-3 rounded-xl bg-slate-50">خصم<br><b>'+money(emp.default_deduction)+'</b></div></div>')+'<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">'+card('التعيينات','السجل التنظيمي',table(['من','إلى','القسم','الوظيفة','الفرع','مدير'],as.map(function(x){var m=H.employees.filter(function(e){return e.id===x.manager_employee_id})[0];return tr([date(x.effective_from),date(x.effective_to),esc(x.department_name||'-'),esc(x.position_name||'-'),esc(x.branch_name||'-'),esc(m?m.name:'-')])})))+card('الحضور','آخر 30 يومًا',table(['التاريخ','الحالة','دخول','خروج','الساعات','تأخير'],at.slice(0,15).map(function(x){return tr([date(x.attendance_date),esc(x.status),esc(x.check_in||'-'),esc(x.check_out||'-'),money(x.worked_hours),x.late_minutes?badge(x.late_minutes+' د','warn'):'-'])})))+'</div><div class="grid grid-cols-1 xl:grid-cols-3 gap-5">'+card('الإجازات','الطلبات والأرصدة',table(['النوع','من','إلى','الحالة'],lv.slice(0,20).map(function(x){return tr([esc(x.leave_type_name||x.leave_type||'-'),date(x.start_date),date(x.end_date),esc(x.status)])})))+card('الأرصدة','الرصيد الحالي',table(['النوع','السنة','المتاح'],bl.map(function(x){return tr([esc(x.leave_type_name),esc(x.year),money(x.available_balance)])})))+card('السلف','الالتزامات النشطة',table(['الرقم','القيمة','المتبقي','الحالة'],av.slice(0,20).map(function(x){return tr([esc(x.advance_no),money(x.amount),money(x.remaining_balance),esc(x.status)])})))+'</div>'+card('الرواتب','الكشوف الأخيرة',table(['الدورة','الإجمالي','الخصومات','الصافي','الحالة'],ps.slice(0,12).map(function(x){return tr([esc(x.period_code),money(x.gross),money(x.deductions),money(x.net),esc(x.status||'-')])})))+card('المستندات','الملفات المرتبطة بالموظف',table(['الاسم','النوع','الانتهاء','الحالة',''],dc.map(function(x){return tr([esc(x.document_name||'-'),esc(x.document_type||'-'),date(x.expires_at),esc(x.status||'-'),x.storage_path?btn('فتح','open-doc:'+x.id,'bg-slate-100 text-slate-700'):''])})),btn('مستند جديد','new-document:'+id))+card('ساعات العمل','work entries',table(['التاريخ','النوع','الساعات','الحالة'],we.slice(0,30).map(function(x){return tr([date(x.work_date),esc(x.entry_type),money(x.hours),esc(x.status||'-')])})))+'</div>';E('hr360').innerHTML=html}catch(e){safe(E('hr360'),'<div class="p-8 text-center text-rose-600 font-bold">'+esc(e.message)+'</div>')}}
29587:   async function profileForm(id){await loadPeople();var e=H.employees.filter(function(x){return x.id===id})[0];if(!e)return;var body='<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','f-number',e.employee_number||'')+field('المسمى الوظيفي','f-title',e.job_title||'')+field('تاريخ التعيين','f-hire',e.hire_date||'','date')+field('نوع التوظيف','f-type',e.employment_type||'دوام كامل')+field('الأساسي','f-basic',e.basic_salary||0,'number')+field('بدل السكن','f-house',e.housing_allowance||0,'number')+field('بدل النقل','f-trans',e.transport_allowance||0,'number')+field('بدلات أخرى','f-other',e.other_allowance||0,'number')+field('خصم افتراضي','f-ded',e.default_deduction||0,'number')+field('الميلاد','f-birth',e.birth_date||'','date')+field('الهوية','f-national',e.national_id||'')+field('العنوان','f-address',e.address||'')+field('جهة اتصال طوارئ','f-emergency',e.emergency_contact_name||'')+field('هاتف الطوارئ','f-emergency-phone',e.emergency_contact_phone||'')+'</div>'+textarea('ملاحظات','f-notes',e.profile_notes||'');modal('تعديل ملف الموظف',body,async function(k){await c('employee.profile.upsert',{employee_id:id,employee_number:E('f-number').value,job_title:E('f-title').value,hire_date:E('f-hire').value||null,employment_type:E('f-type').value,basic_salary:num(E('f-basic').value),housing_allowance:num(E('f-house').value),transport_allowance:num(E('f-trans').value),other_allowance:num(E('f-other').value),default_deduction:num(E('f-ded').value),status:e.profile_status||'active',notes:E('f-notes').value,birth_date:E('f-birth').value||null,national_id:E('f-national').value,address:E('f-address').value,emergency_contact_name:E('f-emergency').value,emergency_contact_phone:E('f-emergency-phone').value},k);closeModal();toast('تم حفظ الملف');render()},'profile:'+id)}
29588:   async function newProfile(){await loadPeople();var body=select('حساب النظام','p-employee',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('الرقم الوظيفي','p-number','')+field('المسمى الوظيفي','p-title','')+field('تاريخ التعيين','p-hire','','date')+field('نوع التوظيف','p-type','دوام كامل')+field('الأساسي','p-basic',0,'number')+field('بدل السكن','p-house',0,'number')+field('بدل النقل','p-trans',0,'number')+field('بدلات أخرى','p-other',0,'number')+field('خصم افتراضي','p-ded',0,'number')+'</div>';modal('إنشاء ملف موظف',body,async function(k){await c('employee.profile.upsert',{employee_id:E('p-employee').value,employee_number:E('p-number').value,job_title:E('p-title').value,hire_date:E('p-hire').value||null,employment_type:E('p-type').value,basic_salary:num(E('p-basic').value),housing_allowance:num(E('p-house').value),transport_allowance:num(E('p-trans').value),other_allowance:num(E('p-other').value),default_deduction:num(E('p-ded').value),status:'active'},k);closeModal();toast('تم إنشاء الملف');render()},'new-profile')}
29589:   async function simple(title,body,cmd,payloadFn,key){modal(title,body,async function(k){var p=payloadFn();await c(cmd,p,k);closeModal();toast('تم الحفظ');render()},key)}
29590:   async function newDept(){await loadPeople();var d=await q('departments');simple('إدارة جديدة',field('الكود','x-code','')+field('الاسم','x-name','')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+select('الإدارة الأعلى','x-parent',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)), '')+textarea('الوصف','x-desc',''),'org.department.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,manager_employee_id:E('x-manager').value||null,parent_department_id:E('x-parent').value||null,description:E('x-desc').value,is_active:true}},'new-dept')}
29591:   async function newPos(){var d=await q('departments');simple('وظيفة جديدة',field('الكود','x-code','')+field('المسمى','x-title','')+select('القسم','x-dept',[{value:'',label:'بدون'}].concat(deptOpts(d.rows)),'')+field('المستوى','x-level','')+field('نوع التوظيف','x-type',''),'org.position.upsert',function(){return{code:E('x-code').value,title:E('x-title').value,department_id:E('x-dept').value||null,level:E('x-level').value,employment_type:E('x-type').value,is_active:true}},'new-pos')}
29592:   async function newAsg(){await Promise.all([loadPeople(),loadBranches()]);var d=await q('departments'),p=await q('positions');simple('تعيين تنظيمي',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الفرع','x-branch',branches(),'')+select('القسم','x-dept',deptOpts(d.rows),'')+select('الوظيفة','x-pos',posOpts(p.rows),'')+select('المدير','x-manager',[{value:'',label:'بدون'}].concat(employeeOpts()),'')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date')+select('رئيسي','x-primary',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+'</div>'+textarea('ملاحظات','x-notes',''),'org.assignment.upsert',function(){return{employee_id:E('x-emp').value,branch_id:E('x-branch').value||null,department_id:E('x-dept').value||null,position_id:E('x-pos').value||null,manager_employee_id:E('x-manager').value||null,effective_from:E('x-from').value,effective_to:E('x-to').value||null,is_primary:E('x-primary').value==='true',notes:E('x-notes').value}},'new-asg')}
29593:   async function newSchedule(){simple('جدول عمل',field('الكود','x-code','')+field('الاسم','x-name','')+field('المنطقة الزمنية','x-zone','Africa/Cairo')+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('البداية','x-start','','time')+field('النهاية','x-end','','time')+field('دقائق الراحة','x-break',0,'number')+field('الساعات اليومية','x-hours',8,'number')+field('سماح دخول','x-gi',0,'number')+field('سماح خروج','x-go',0,'number')+field('مضاعف الإضافي','x-ot',1.5,'number')+'</div>'+textarea('القالب الأسبوعي JSON','x-week','{}'),'schedule.upsert',function(){var w={};try{w=JSON.parse(E('x-week').value||'{}')}catch(e){throw Error('القالب الأسبوعي غير صالح')}return{code:E('x-code').value,name:E('x-name').value,timezone:E('x-zone').value,weekly_template:w,shift_start:E('x-start').value||null,shift_end:E('x-end').value||null,break_minutes:num(E('x-break').value),daily_hours:num(E('x-hours').value),grace_in_minutes:num(E('x-gi').value),grace_out_minutes:num(E('x-go').value),overtime_multiplier:num(E('x-ot').value),auto_checkout:false,is_active:true}},'new-schedule')}
29594:   async function newScheduleAsg(){await loadPeople();var s=await q('schedules');simple('تعيين جدول للموظف',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('الجدول','x-schedule',scheduleOpts(s.rows),'')+field('من','x-from',new Date().toISOString().slice(0,10),'date')+field('إلى','x-to','','date'),'schedule.assign',function(){return{employee_id:E('x-emp').value,schedule_id:E('x-schedule').value,effective_from:E('x-from').value,effective_to:E('x-to').value||null}},'new-schedule-asg')}
29595:   async function newContract(id){await loadPeople();var p=await q('positions'),s=await q('schedules');simple('عقد موظف',select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+field('رقم العقد','x-no','')+select('الوظيفة','x-pos',[{value:'',label:'بدون'}].concat(posOpts(p.rows)),'')+select('الحالة','x-status',[{value:'active',label:'فعال'},{value:'inactive',label:'غير فعال'}],'active')+select('دورة الدفع','x-pay',[{value:'monthly',label:'شهري'},{value:'half_monthly',label:'نصف شهري'},{value:'weekly',label:'أسبوعي'},{value:'daily',label:'يومي'}],'monthly')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('البداية','x-start','','date')+field('النهاية','x-end','','date')+field('نهاية التجربة','x-prob','','date')+field('الأساسي','x-basic',0,'number')+field('السكن','x-house',0,'number')+field('النقل','x-trans',0,'number')+field('بدلات أخرى','x-other',0,'number')+field('خصم','x-ded',0,'number')+select('الجدول','x-schedule',[{value:'',label:'بدون'}].concat(scheduleOpts(s.rows)),'')+field('تنبيه التجديد بالأيام','x-renewal',30,'number')+'</div>'+textarea('ملاحظات','x-notes',''),'contract.upsert',function(){return{employee_id:E('x-emp').value,contract_no:E('x-no').value,position_id:E('x-pos').value||null,contract_type:'permanent',start_date:E('x-start').value,end_date:E('x-end').value||null,probation_end:E('x-prob').value||null,status:E('x-status').value,pay_cycle:E('x-pay').value,currency:'EGP',basic_salary:num(E('x-basic').value),housing_allowance:num(E('x-house').value),transport_allowance:num(E('x-trans').value),other_allowance:num(E('x-other').value),default_deduction:num(E('x-ded').value),schedule_id:E('x-schedule').value||null,renewal_notice_days:num(E('x-renewal').value),notes:E('x-notes').value}},'new-contract:'+String(id||''))}
29596:   async function newContractComponent(){var cts=await q('contracts'),sc=await q('salary_components');simple('مكوّن عقد',select('العقد','x-contract',(cts.rows||[]).map(function(x){return{value:x.id,label:x.contract_no+' — '+x.employee_name}}),'')+select('المكوّن','x-comp',(sc.rows||[]).map(function(x){return{value:x.id,label:x.name+' — '+x.component_type}}),'')+field('القيمة','x-value',0,'number'),'contract.component.upsert',function(){return{contract_id:E('x-contract').value,component_id:E('x-comp').value,value:num(E('x-value').value),is_active:true}},'new-contract-component')}
29597:   async function attendanceDay(){await loadPeople();simple('تسجيل يوم حضور',select('الموظف','x-emp',employeeOpts(),H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-4 gap-4">'+field('التاريخ','x-date',new Date().toISOString().slice(0,10),'date')+select('الحالة','x-status',[{value:'present',label:'حاضر'},{value:'absent',label:'غائب'},{value:'leave',label:'إجازة'},{value:'late',label:'متأخر'}],'present')+field('الدخول','x-in','','datetime-local')+field('الخروج','x-out','','datetime-local')+field('ساعات العمل','x-hours',0,'number')+field('التأخير بالدقائق','x-late',0,'number')+field('الانصراف المبكر','x-early',0,'number')+field('الإضافي','x-ot',0,'number')+field('غياب بالدقائق','x-absence',0,'number')+field('جدول UUID','x-schedule','')+'</div>'+textarea('سبب التصحيح','x-reason',''),'attendance.day.upsert',function(){return{employee_id:E('x-emp').value,attendance_date:E('x-date').value,status:E('x-status').value,check_in:iso(E('x-in').value),check_out:iso(E('x-out').value),worked_hours:num(E('x-hours').value),late_minutes:num(E('x-late').value),early_leave_minutes:num(E('x-early').value),overtime_hours:num(E('x-ot').value),absence_minutes:num(E('x-absence').value),schedule_id:E('x-schedule').value||null,source:'mother_hr',correction_reason:E('x-reason').value||null}},'attendance-day')}
29598:   async function attendanceEvent(){await loadPeople();simple('حدث حضور خام',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('النوع','x-type',[{value:'check_in',label:'دخول'},{value:'check_out',label:'خروج'}],'check_in')+field('وقت الحدث','x-at','','datetime-local')+field('الجهاز','x-dev','')+textarea('Metadata JSON','x-meta','{}'),'attendance.event.record',function(){var m={};try{m=JSON.parse(E('x-meta').value||'{}')}catch(e){throw Error('Metadata JSON غير صالح')}if(!E('x-at').value)throw Error('وقت الحدث مطلوب');return{employee_id:E('x-emp').value,event_type:E('x-type').value,occurred_at:iso(E('x-at').value),source:'mother_hr',device_id:E('x-dev').value||null,metadata:m}},'attendance-event')}
29599:   async function newLeave(){await loadPeople();var t=await q('leave_types');var emp=employeeOpts();var initial=H.actor.id;var docs=(await q('documents',{employee_id:initial})).rows||[];var body=select('الموظف','x-emp',emp,initial)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div id="leave-attachment-hint" class="hidden mt-3 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-800 text-sm font-bold">هذا النوع يتطلب مستندًا. اختر مستندًا موجودًا لهذا الموظف.</div><div id="leave-doc-wrap" class="hidden mt-4">'+select('المستند المرفق','x-doc',[{value:'',label:'اختر مستندًا'}].concat(docs.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}})),'')+'</div><div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">'+field('من','x-start',new Date().toISOString().slice(0,10),'date')+field('إلى','x-end',new Date().toISOString().slice(0,10),'date')+'</div>'+textarea('السبب','x-reason','');modal('طلب إجازة',body,async function(k){var chosen=(t.rows||[]).filter(function(x){return x.id===E('x-type').value})[0];if(!chosen)throw Error('اختر نوع الإجازة');var eid=E('x-emp').value;if(eid!==initial){var nd=(await q('documents',{employee_id:eid})).rows||[];if(chosen.requires_attachment){var opts=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=opts.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')}}if(chosen.requires_attachment&&!E('x-doc').value)throw Error('هذا النوع يتطلب مستندًا مرفقًا');await c('leave.request.create',{employee_id:eid,leave_type_id:E('x-type').value,leave_type:chosen.name,start_date:E('x-start').value,end_date:E('x-end').value,reason:E('x-reason').value,attachment_document_id:E('x-doc').value||null},k);closeModal();toast('تم إنشاء طلب الإجازة');render()},'new-leave');var type=E('x-type'),empSel=E('x-emp'),sync=function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0],need=!!(ch&&ch.requires_attachment);E('leave-attachment-hint').classList.toggle('hidden',!need);E('leave-doc-wrap').classList.toggle('hidden',!need)};type.onchange=sync;empSel.onchange=async function(){var ch=(t.rows||[]).filter(function(x){return x.id===type.value})[0];if(!ch||!ch.requires_attachment)return;var nd=(await q('documents',{employee_id:empSel.value})).rows||[],o=[{value:'',label:'اختر مستندًا'}].concat(nd.map(function(x){return{value:x.id,label:(x.document_name||x.document_type)+' — '+date(x.expires_at)}}));E('x-doc').innerHTML=o.map(function(x){return '<option value="'+esc(x.value)+'">'+esc(x.label)+'</option>'}).join('')};sync()}
29600:   async function leaveType(){simple('نوع إجازة',field('الكود','x-code','')+field('الاسم','x-name','')+field('الحصة السنوية','x-quota',0,'number')+field('أقصى أيام متصلة','x-max','', 'number')+select('مدفوعة','x-paid',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],'true')+select('مرفق مطلوب','x-att',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('نصف يوم','x-half',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'leave.type.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,annual_quota:num(E('x-quota').value),max_continuous_days:E('x-max').value?num(E('x-max').value):null,paid:E('x-paid').value==='true',requires_attachment:E('x-att').value==='true',allow_half_day:E('x-half').value==='true',is_active:true}},'new-leave-type')}
29601:   async function balance(){await loadPeople();var t=await q('leave_types');simple('ضبط رصيد',select('الموظف','x-emp',employeeOpts(),H.actor.id)+select('نوع الإجازة','x-type',(t.rows||[]).map(function(x){return{value:x.id,label:x.name}}),'')+'<div class="grid grid-cols-1 md:grid-cols-5 gap-4">'+field('السنة','x-year',new Date().getFullYear(),'number')+field('افتتاحي','x-opening',0,'number')+field('مستحق','x-accrued',0,'number')+field('مستخدم','x-used',0,'number')+field('تعديل','x-adjusted',0,'number')+'</div>','leave.balance.adjust',function(){return{employee_id:E('x-emp').value,leave_type_id:E('x-type').value,year:parseInt(E('x-year').value,10),opening_balance:num(E('x-opening').value),accrued:num(E('x-accrued').value),used:num(E('x-used').value),adjusted:num(E('x-adjusted').value)}},'adjust-balance')}
29602:   async function requestNew(){await loadPeople();var stepOpts=[{value:'',label:'— دور معتمد —'}];var roles=[];H.employees.forEach(function(e){if(e.role&&roles.indexOf(e.role)<0)roles.push(e.role)});var body=select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('نوع الطلب','x-type','')+field('الموضوع','x-subject','')+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+select('المعتمد 1','x-a1',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 1','x-r1',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 2','x-a2',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 2','x-r2',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+select('المعتمد 3','x-a3',[{value:'',label:'بالدور'}].concat(employeeOpts()),'')+select('الدور 3','x-r3',stepOpts.concat(roles.map(function(r){return{value:r,label:r}})),'')+'</div>'+textarea('بيانات الطلب JSON','x-payload','{}');simple('طلب HR',body,'request.create',function(){var steps=[];[1,2,3].forEach(function(i){var emp=E('x-a'+i).value,role=E('x-r'+i).value;if(emp||role)steps.push({step_no:i,approver_employee_id:emp||null,approver_role:role||null})});var payload={};try{payload=JSON.parse(E('x-payload').value||'{}')}catch(e){throw Error('بيانات JSON غير صالحة')}if(!steps.length)throw Error('أضف خطوة اعتماد واحدة على الأقل');return{employee_id:E('x-emp').value,request_type:E('x-type').value,subject:E('x-subject').value,approval_steps:steps,payload:payload}},'new-request')}
29603:   async function advance(){await loadPeople();simple('سلفة',select('الموظف','x-emp',employeeOpts(),H.actor.id)+field('القيمة','x-amount',0,'number')+field('عدد الأقساط','x-count',1,'number')+field('قيمة القسط','x-install','', 'number')+field('بداية الاستقطاع','x-start',new Date().toISOString().slice(0,10),'date')+textarea('ملاحظات','x-notes',''),'advance.create',function(){var a=num(E('x-amount').value),k=Math.max(1,parseInt(E('x-count').value,10)||1);return{employee_id:E('x-emp').value,amount:a,installment_count:k,installment_amount:E('x-install').value?num(E('x-install').value):a/k,start_period:E('x-start').value,notes:E('x-notes').value}},'new-advance')}
29604:   async function salaryComponent(){simple('مكوّن راتب',field('الكود','x-code','')+field('الاسم','x-name','')+select('النوع','x-type',[{value:'earning',label:'استحقاق'},{value:'deduction',label:'خصم'}],'earning')+select('طريقة الحساب','x-calc',[{value:'fixed',label:'ثابت'},{value:'percent_basic',label:'نسبة من الأساسي'}],'fixed')+field('القيمة','x-value',0,'number')+select('ضريبي','x-tax',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false')+select('تأميني','x-pension',[{value:'false',label:'لا'},{value:'true',label:'نعم'}],'false'),'salary.component.upsert',function(){return{code:E('x-code').value,name:E('x-name').value,component_type:E('x-type').value,calculation_type:E('x-calc').value,default_value:num(E('x-value').value),taxable:E('x-tax').value==='true',pensionable:E('x-pension').value==='true',is_active:true}},'new-salary-component')}
29605:   async function payPeriod(){simple('فترة رواتب',field('كود الفترة','x-code','')+'<div class="grid grid-cols-1 md:grid-cols-3 gap-4">'+field('من','x-start','','date')+field('إلى','x-end','','date')+field('تاريخ الدفع','x-pay','','date')+'</div>'+select('الحالة','x-status',[{value:'open',label:'مفتوحة'},{value:'closed',label:'مغلقة'}],'open'),'payroll.period.upsert',function(){return{period_code:E('x-code').value,start_date:E('x-start').value,end_date:E('x-end').value,pay_date:E('x-pay').value||null,status:E('x-status').value}},'new-pay-period')}
29606:   async function payrollMap(){var m=(await q('payroll_accounting_map')).rows||[],x=m[0]||{},ac=await supabase.from('chart_of_accounts').select('id,account_code,account_name').eq('company_id',H.companyId).order('account_code');if(ac.error)throw ac.error;var opts=(ac.data||[]).map(function(a){return{value:a.id,label:a.account_code+' — '+a.account_name}});simple('الربط المحاسبي',select('حساب المصروف','x-expense',opts,x.expense_account_id||'')+select('حساب الالتزام','x-liability',opts,x.liability_account_id||'')+select('فعال','x-active',[{value:'true',label:'نعم'},{value:'false',label:'لا'}],x.is_active===false?'false':'true'),'payroll.accounting.map',function(){return{expense_account_id:E('x-expense').value,liability_account_id:E('x-liability').value,is_active:E('x-active').value==='true'}},'payroll-map')}
29607:   async function documentForm(id){await loadPeople();var body=select('الموظف','x-emp',employeeOpts(),id||H.actor.id)+'<div class="grid grid-cols-1 md:grid-cols-2 gap-4">'+field('نوع المستند','x-type','identity')+field('اسم العرض','x-name','')+field('الانتهاء','x-expiry','','date')+'</div><label class="block"><span class="block text-xs font-black text-slate-600 mb-2">الملف</span><input id="x-file" type="file" class="w-full px-4 py-3 rounded-xl border"></label>'+textarea('ملاحظات','x-notes','');modal('مستند موظف',body,async function(k){var f=E('x-file').files[0];if(!f)throw Error('اختر الملف');var eid=E('x-emp').value;var clean=f.name.replace(/[^\w\u0600-\u06ff.\- ]+/g,'_');var path=H.companyId+'/'+eid+'/'+Date.now()+'_'+clean;var u=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type||undefined});if(u.error)throw u.error;try{await c('document.metadata.upsert',{employee_id:eid,document_type:E('x-type').value,storage_path:path,document_name:E('x-name').value||f.name,mime_type:f.type||'application/octet-stream',expires_at:E('x-expiry').value||null,status:'active',notes:E('x-notes').value},k)}catch(e){await supabase.storage.from('employee-documents').remove([path]).catch(function(){});throw e}closeModal();toast('تم رفع المستند');render()},'document:'+String(id||'new'))}
29608:   async function openDoc(id){var d=await q('documents'),x=(d.rows||[]).filter(function(z){return z.id===id})[0];if(!x||!x.storage_path)throw Error('المستند غير متاح');var u=await supabase.storage.from('employee-documents').createSignedUrl(x.storage_path,300);if(u.error)throw u.error;window.open(u.data.signedUrl,'_blank','noopener')}
29609:   async function render(){var cn=E('rw-page-container');if(!cn||H.busy)return;H.busy=true;try{if(!H.actor)await actor();if(!H.employees.length)await loadPeople();if(!H.branches.length)await loadBranches();if(typeof safeText==='function'){safeText(E('rw-header-title'),'الموارد البشرية');safeText(E('rw-header-subtitle'),'منصة HR المركزية — الملف والهيكل والحضور والإجازات والطلبات والرواتب والمستندات')}safe(cn,'<div class="p-2 sm:p-4 space-y-5"><div class="bg-gradient-to-r from-slate-900 to-indigo-800 text-white rounded-3xl p-6 shadow-lg"><div class="flex flex-col lg:flex-row justify-between gap-4"><div><div class="text-xs font-black text-indigo-200">RAWAEA HR CONTROL CENTER</div><h2 class="text-2xl sm:text-3xl font-black mt-2">إدارة دورة حياة الموظف من النظام الأم</h2><p class="text-sm text-slate-200 mt-2">بيانات HR موحدة، أوامر مركزية، صلاحيات tenant-aware، وتحديث لحظي.</p></div><div>'+btn('تحديث','refresh','bg-indigo-500 text-white')+'</div></div></div>'+tabbar()+'<div id="rw-hr-content"></div></div>');cn.onclick=function(e){var tb=e.target.closest&&e.target.closest('[data-hr-tab]');if(tb){H.tab=tb.getAttribute('data-hr-tab');render();return}var ac=e.target.closest&&e.target.closest('[data-hr-action]');if(ac)handle(ac.getAttribute('data-hr-action'))};var ctn=E('rw-hr-content');if(H.tab==='dashboard')await dashboard(ctn);else if(H.tab==='employees')await employeesTab(ctn);else if(H.tab==='organization')await organizationTab(ctn);else if(H.tab==='contracts')await contractsTab(ctn);else if(H.tab==='attendance')await attendanceTab(ctn);else if(H.tab==='leaves')await leavesTab(ctn);else if(H.tab==='requests')await requestsTab(ctn);else if(H.tab==='advances')await advancesTab(ctn);else if(H.tab==='payroll')await payrollTab(ctn);else if(H.tab==='documents')await documentsTab(ctn)}catch(e){safe(E('rw-page-container'),'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل منصة HR</h3><p class="text-slate-500 mt-2">'+esc(e.message)+'</p>'+btn('إعادة المحاولة','refresh')+'</div>')}finally{H.busy=false}}
29610:   async function handle(a){var p=a.split(':'),k=p.shift(),id=p.join(':');try{if(k==='refresh')return render();if(k==='tab')return H.tab=id,render();if(k==='new-profile')return newProfile();if(k==='open-employee')return open360(id);if(k==='edit-profile')return profileForm(id);if(k==='new-dept')return newDept();if(k==='new-pos')return newPos();if(k==='new-asg')return newAsg();if(k==='new-schedule')return newSchedule();if(k==='new-schedule-asg')return newScheduleAsg();if(k==='new-contract')return newContract(id);if(k==='new-contract-component')return newContractComponent();if(k==='deactivate-cc'){await c('contract.component.deactivate',{contract_component_id:id},'deactivate-cc:'+id);toast('تم تعطيل المكوّن');return render()}if(k==='attendance-day')return attendanceDay();if(k==='attendance-event')return attendanceEvent();if(k==='new-leave')return newLeave();if(k==='new-leave-type')return leaveType();if(k==='adjust-balance')return balance();if(k==='new-request')return requestNew();if(k==='approve-request'){await c('request.approve',{request_id:id},'approve-request:'+id);toast('تم اعتماد الطلب');return render()}if(k==='reject-request'){await c('request.reject',{request_id:id,reason:'رفض من النظام الأم'},'reject-request:'+id);toast('تم رفض الطلب');return render()}if(k==='new-advance')return advance();if(k==='approve-advance'){await c('advance.approve',{advance_id:id},'approve-advance:'+id);toast('تم اعتماد السلفة');return render()}if(k==='disburse-advance'){await c('advance.disburse',{advance_id:id},'disburse-advance:'+id);toast('تم صرف السلفة');return render()}if(k==='new-pay-period')return payPeriod();if(k==='calculate-payroll'){await c('payroll.run.calculate',{period_id:id},'calculate-payroll:'+id);toast('تم حساب الرواتب');return render()}if(k==='new-salary-component')return salaryComponent();if(k==='payroll-map')return payrollMap();if(k==='approve-payroll'){await c('payroll.run.approve',{payroll_run_id:id},'approve-payroll:'+id);toast('تم اعتماد التشغيل');return render()}if(k==='post-payroll'){await c('payroll.run.post',{payroll_run_id:id},'post-payroll:'+id);toast('تم نشر التشغيل');return render()}if(k==='new-document')return documentForm(id);if(k==='open-doc'){return openDoc(id)}if(k==='approve-leave'){await c('leave.request.approve',{leave_request_id:id},'approve-leave:'+id);toast('تم اعتماد الإجازة');return render()}if(k==='reject-leave'){await c('leave.request.reject',{leave_request_id:id,notes:'رفض من النظام الأم'},'reject-leave:'+id);toast('تم رفض الإجازة');return render()}if(k==='cancel-leave'){await c('leave.request.cancel',{leave_request_id:id},'cancel-leave:'+id);toast('تم إلغاء الإجازة');return render()}throw Error('إجراء HR غير معروف: '+a)}catch(e){toast(e.message,'error')}}
29611:   function realtime(){try{if(H.channel)supabase.removeChannel(H.channel);var tables=['employee_profiles','employee_attendance','employee_leave_requests','employee_documents','hr_departments','hr_positions','hr_employee_assignments','hr_employee_schedule_assignments','hr_work_schedules','hr_attendance_events','hr_work_entries','hr_leave_types','hr_leave_balances','hr_requests','hr_request_approvals','hr_salary_advances','hr_salary_components','hr_contracts','hr_contract_components','hr_payroll_periods','hr_payroll_runs','hr_payslips','hr_payslip_lines','hr_payroll_accounting_map'];H.channel=supabase.channel('rw-hr-mother-final');tables.forEach(function(t){H.channel.on('postgres_changes',{event:'*',schema:'public',table:t},function(){clearTimeout(H.timer);H.timer=setTimeout(function(){render()},700)})});H.channel.subscribe()}catch(e){console.warn('RW_HR realtime',e)}}
29612:   // Resilience layer: modal actions work outside the page-container, async form errors become visible, and 360 is truly read-only.
29613:   (function installModalResilience(){
29614:     document.addEventListener('click',function(e){
29615:       var ac=e.target.closest&&e.target.closest('[data-hr-action]');
29616:       if(!ac)return;
29617:       var page=E('rw-page-container');
29618:       if(page&&page.contains(ac))return;
29619:       e.preventDefault();
29620:       handle(ac.getAttribute('data-hr-action'));
29621:     },true);
29622:     window.addEventListener('unhandledrejection',function(e){
29623:       var root=E('rw-hr-modal-root');
29624:       if(!root)return;
29625:       e.preventDefault();
29626:       var msg=e.reason&&(e.reason.message||String(e.reason));
29627:       if(msg)toast(msg,'error');
29628:     });
29629:     try{
29630:       var mo=new MutationObserver(function(){
29631:         var root=E('rw-hr-modal-root');
29632:         if(!root||!E('hr360'))return;
29633:         var f=E('rw-hr-form');
29634:         if(f&&f.lastElementChild)f.lastElementChild.style.display='none';
29635:       });
29636:       mo.observe(document.body,{childList:true,subtree:true});
29637:     }catch(e){}
29638:   }());
29639: 
29640: realtime(); return { render: render, reload: render, openEmployee360: open360 }; }()); window.RW_HR = RW_HR;
