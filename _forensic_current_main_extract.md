# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=25541
FILE_BYTES=1425646
SHA256=e945c6244fcb7f8d85e1325a6f3d9fdd6965efb6f13bf340a85580eeefdc42ac
PATTERN var RW_Warehouse: [10969]
PATTERN var RW_HR: [23788]
PATTERN RW_HR: [23741, 23786, 23788, 23862, 24064]
PATTERN hr_list_employees: [23821]
PATTERN hr_command_atomic: []
PATTERN hr_query: []
PATTERN hr_payroll_calculate_impl: []
PATTERN hr_payroll_post_impl: []
PATTERN employee_documents: [23921, 24052]
PATTERN hr_departments: []
PATTERN hr_contracts: []
PATTERN hr_work_schedules: []
PATTERN hr_attendance_events: []
PATTERN hr_leave_types: []
PATTERN hr_requests: []
PATTERN hr_salary_advances: []
PATTERN hr_payroll_periods: []
PATTERN hr_payslips: []
PATTERN hr_command: []
PATTERN employee-document: [24052, 24057]
PATTERN document-upload: []
PATTERN الموارد البشرية: [1172, 5476, 6312, 19932, 19964, 23729, 23786, 23850, 23858]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 23758-23968 around 23788 ---
23758:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
23759:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
23760: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
23761: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
23762: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
23763: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
23764:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
23765:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
23766:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
23767:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
23768:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
23769:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
23770:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
23771:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
23772:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
23773:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
23774:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
23775:         if (view === 'finance') { RW_Finance.render(); return; }
23776:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
23777:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
23778:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
23779:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
23780: 
23781:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
23782:     }
23783: };
23784: window.RW_Views = RW_Views;
23785: // ============================================================
23786: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
23787: // ============================================================
23788: var RW_HR = (function() {
23789:     'use strict';
23790: 
23791:     var hrData = [];
23792: 
23793:     function _esc(s) {
23794:         return String(s == null ? '' : s)
23795:             .replace(/&/g, '&amp;')
23796:             .replace(/</g, '&lt;')
23797:             .replace(/>/g, '&gt;');
23798:     }
23799: 
23800:     function _escAttr(s) {
23801:         return _esc(s)
23802:             .replace(/\"/g, '&quot;')
23803:             .replace(/'/g, '&#39;');
23804:     }
23805: 
23806:     function _fmtNum(n) {
23807:         return Number(n || 0).toLocaleString('ar-EG');
23808:     }
23809: 
23810:     function _companyId() {
23811:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
23812:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
23813:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
23814:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
23815:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
23816:         }
23817:         return null;
23818:     }
23819: 
23820:     async function _loadEmployees() {
23821:         var res = await supabase.rpc('hr_list_employees');
23822:         if (res.error) throw res.error;
23823:         hrData = res.data || [];
23824:         return hrData;
23825:     }
23826: 
23827:     function _employeeCard(emp) {
23828:         var profileSalary = Number(emp.basic_salary || 0) +
23829:             Number(emp.housing_allowance || 0) +
23830:             Number(emp.transport_allowance || 0) +
23831:             Number(emp.other_allowance || 0) -
23832:             Number(emp.default_deduction || 0);
23833:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
23834:             '<div class="flex items-center gap-4 mb-4">' +
23835:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
23836:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
23837:             '</div>' +
23838:             '<div class="space-y-2 text-sm">' +
23839:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
23840:                 '<div class="flex justify-between"><span class="text-gray-500">الهاتف</span><span class="font-bold text-gray-700">' + _esc(emp.phone || '-') + '</span></div>' +
23841:                 '<div class="flex justify-between"><span class="text-gray-500">الحالة</span><span class="px-2 py-0.5 rounded-full text-xs font-bold ' + (emp.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700') + '">' + _esc(emp.status === 'Active' ? 'نشط' : 'غير نشط') + '</span></div>' +
23842:                 '<div class="flex justify-between"><span class="text-gray-500">صافي التعويض</span><span class="font-black text-indigo-600">' + _fmtNum(profileSalary) + ' EGP</span></div>' +
23843:             '</div>' +
23844:         '</div>';
23845:     }
23846: 
23847:     async function render() {
23848:         var container = byId('rw-page-container');
23849:         if (!container) return;
23850:         safeText(byId('rw-header-title'), 'الموارد البشرية');
23851:         safeText(byId('rw-header-subtitle'), 'ملفات الموظفين والتعويضات والحضور والإجازات والمستندات');
23852: 
23853:         if (!_companyId()) {
23854:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحديد سياق الشركة</h3></div>');
23855:             return;
23856:         }
23857: 
23858:         showLoader('جاري تحميل بيانات الموارد البشرية...');
23859:         try {
23860:             await _loadEmployees();
23861:         } catch (error) {
23862:             console.error('RW_HR.loadEmployees', error);
23863:             hideLoader();
23864:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل بيانات الموظفين</h3><p class="text-gray-500 mt-2">' + _esc(error.message || 'خطأ غير معروف') + '</p></div>');
23865:             return;
23866:         }
23867:         hideLoader();
23868: 
23869:         var activeEmployees = hrData.filter(function(emp) {
23870:             return !(emp.role === 'مالك' || emp.role === 'Owner');
23871:         });
23872: 
23873:         var html = '<div class="p-4 space-y-5">';
23874:         html += '<div class="grid grid-cols-1 md:grid-cols-4 gap-4">';
23875:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي الموظفين</div><div class="text-3xl font-black text-indigo-600 mt-2">' + activeEmployees.length + '</div></div>';
23876:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">الموظفون النشطون</div><div class="text-3xl font-black text-green-600 mt-2">' + activeEmployees.filter(function(e){return e.status==='Active';}).length + '</div></div>';
23877:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي التعويضات الشهرية</div><div class="text-3xl font-black text-blue-600 mt-2">' + _fmtNum(activeEmployees.reduce(function(sum,e){return sum + Number(e.basic_salary||0)+Number(e.housing_allowance||0)+Number(e.transport_allowance||0)+Number(e.other_allowance||0)-Number(e.default_deduction||0);},0)) + '</div></div>';
23878:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">ملفات موظفين بدون بطاقة</div><div class="text-3xl font-black text-amber-600 mt-2">' + activeEmployees.filter(function(e){return !e.profile_id;}).length + '</div></div>';
23879:         html += '</div>';
23880: 
23881:         html += '<div class="flex flex-col md:flex-row gap-3">';
23882:         html += '<input id="hr-search" class="flex-1 p-3 bg-white border rounded-xl" placeholder="بحث بالاسم أو البريد أو الرقم الوظيفي">';
23883:         html += '<button id="hr-refresh" class="px-5 py-3 bg-indigo-600 text-white rounded-xl font-bold">تحديث</button>';
23884:         html += '</div>';
23885: 
23886:         html += '<div id="hr-cards-container" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">';
23887:         html += activeEmployees.map(_employeeCard).join('');
23888:         html += '</div>';
23889:         html += '<div id="hr-empty" class="hidden text-center py-10 text-gray-500">لا توجد نتائج مطابقة.</div>';
23890:         html += '</div>';
23891:         safeHTML(container, html);
23892: 
23893:         var search = byId('hr-search');
23894:         if (search) {
23895:             search.addEventListener('input', function() {
23896:                 var q = search.value.trim().toLowerCase();
23897:                 var cards = byId('hr-cards-container').querySelectorAll('[data-hr-employee-id]');
23898:                 var visible = 0;
23899:                 for (var i = 0; i < cards.length; i++) {
23900:                     var empId = cards[i].getAttribute('data-hr-employee-id');
23901:                     var emp = hrData.filter(function(e){return e.id === empId;})[0];
23902:                     var hay = ((emp.name||'')+' '+(emp.email||'')+' '+(emp.employee_number||'')+' '+(emp.job_title||'')).toLowerCase();
23903:                     cards[i].style.display = !q || hay.indexOf(q) !== -1 ? '' : 'none';
23904:                     if (cards[i].style.display !== 'none') visible++;
23905:                 }
23906:                 byId('hr-empty').classList.toggle('hidden', visible !== 0);
23907:             });
23908:         }
23909:         var refresh = byId('hr-refresh');
23910:         if (refresh) refresh.addEventListener('click', function(){ render(); });
23911:         var cardNodes = container.querySelectorAll('[data-hr-employee-id]');
23912:         for (var c = 0; c < cardNodes.length; c++) {
23913:             cardNodes[c].addEventListener('click', function(){
23914:                 var id = this.getAttribute('data-hr-employee-id');
23915:                 _openModal(id);
23916:             });
23917:         }
23918:     }
23919: 
23920:     async function _loadDocuments(employeeId) {
23921:         var res = await supabase.from('employee_documents')
23922:             .select('id,document_type,storage_path,document_name,mime_type,expires_at,status,notes,created_at')
23923:             .eq('employee_id', employeeId)
23924:             .eq('company_id', _companyId())
23925:             .order('created_at', {ascending:false});
23926:         if (res.error) throw res.error;
23927:         return res.data || [];
23928:     }
23929: 
23930:     async function _loadAttendance(employeeId) {
23931:         var res = await supabase.from('employee_attendance')
23932:             .select('id,attendance_date,status,check_in,check_out,notes')
23933:             .eq('employee_id', employeeId)
23934:             .eq('company_id', _companyId())
23935:             .order('attendance_date',{ascending:false})
23936:             .limit(14);
23937:         if (res.error) throw res.error;
23938:         return res.data || [];
23939:     }
23940: 
23941:     async function _loadLeaves(employeeId) {
23942:         var res = await supabase.from('employee_leave_requests')
23943:             .select('id,leave_type,start_date,end_date,reason,status,requested_by,approved_by,approved_at,notes')
23944:             .eq('employee_id', employeeId)
23945:             .eq('company_id', _companyId())
23946:             .order('start_date',{ascending:false})
23947:             .limit(20);
23948:         if (res.error) throw res.error;
23949:         return res.data || [];
23950:     }
23951: 
23952:     async function _openModal(employeeId) {
23953:         var emp = hrData.filter(function(e){ return e.id === employeeId; })[0];
23954:         if (!emp) { showToast('الموظف غير موجود', 'error'); return; }
23955: 
23956:         showLoader('جاري تحميل ملف الموظف...');
23957:         try {
23958:             var docs = await _loadDocuments(employeeId);
23959:             var attendance = await _loadAttendance(employeeId);
23960:             var leaves = await _loadLeaves(employeeId);
23961:             hideLoader();
23962: 
23963:             var html = '<div class="text-right space-y-5" data-hr-modal="1">';
23964:             html += '<div class="bg-indigo-50 rounded-2xl p-5"><div class="flex justify-between gap-4"><div><h3 class="font-black text-xl">' + _esc(emp.name) + '</h3><p class="text-sm text-gray-500">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div><div class="text-left"><div class="text-xs text-gray-500">الرقم الوظيفي</div><div class="font-black">' + _esc(emp.employee_number || emp.employee_id || '-') + '</div></div></div></div>';
23965: 
23966:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">البيانات والوظيفة</h4><div class="grid grid-cols-2 gap-4 text-sm">';
23967:             html += '<div><span class="text-gray-500">البريد</span><div class="font-bold">' + _esc(emp.email) + '</div></div>';
23968:             html += '<div><span class="text-gray-500">الهاتف</span><div class="font-bold">' + _esc(emp.phone || '-') + '</div></div>';
--- WINDOW 23791-24001 around 23821 ---
23791:     var hrData = [];
23792: 
23793:     function _esc(s) {
23794:         return String(s == null ? '' : s)
23795:             .replace(/&/g, '&amp;')
23796:             .replace(/</g, '&lt;')
23797:             .replace(/>/g, '&gt;');
23798:     }
23799: 
23800:     function _escAttr(s) {
23801:         return _esc(s)
23802:             .replace(/\"/g, '&quot;')
23803:             .replace(/'/g, '&#39;');
23804:     }
23805: 
23806:     function _fmtNum(n) {
23807:         return Number(n || 0).toLocaleString('ar-EG');
23808:     }
23809: 
23810:     function _companyId() {
23811:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
23812:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
23813:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
23814:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
23815:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
23816:         }
23817:         return null;
23818:     }
23819: 
23820:     async function _loadEmployees() {
23821:         var res = await supabase.rpc('hr_list_employees');
23822:         if (res.error) throw res.error;
23823:         hrData = res.data || [];
23824:         return hrData;
23825:     }
23826: 
23827:     function _employeeCard(emp) {
23828:         var profileSalary = Number(emp.basic_salary || 0) +
23829:             Number(emp.housing_allowance || 0) +
23830:             Number(emp.transport_allowance || 0) +
23831:             Number(emp.other_allowance || 0) -
23832:             Number(emp.default_deduction || 0);
23833:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
23834:             '<div class="flex items-center gap-4 mb-4">' +
23835:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
23836:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
23837:             '</div>' +
23838:             '<div class="space-y-2 text-sm">' +
23839:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
23840:                 '<div class="flex justify-between"><span class="text-gray-500">الهاتف</span><span class="font-bold text-gray-700">' + _esc(emp.phone || '-') + '</span></div>' +
23841:                 '<div class="flex justify-between"><span class="text-gray-500">الحالة</span><span class="px-2 py-0.5 rounded-full text-xs font-bold ' + (emp.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700') + '">' + _esc(emp.status === 'Active' ? 'نشط' : 'غير نشط') + '</span></div>' +
23842:                 '<div class="flex justify-between"><span class="text-gray-500">صافي التعويض</span><span class="font-black text-indigo-600">' + _fmtNum(profileSalary) + ' EGP</span></div>' +
23843:             '</div>' +
23844:         '</div>';
23845:     }
23846: 
23847:     async function render() {
23848:         var container = byId('rw-page-container');
23849:         if (!container) return;
23850:         safeText(byId('rw-header-title'), 'الموارد البشرية');
23851:         safeText(byId('rw-header-subtitle'), 'ملفات الموظفين والتعويضات والحضور والإجازات والمستندات');
23852: 
23853:         if (!_companyId()) {
23854:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحديد سياق الشركة</h3></div>');
23855:             return;
23856:         }
23857: 
23858:         showLoader('جاري تحميل بيانات الموارد البشرية...');
23859:         try {
23860:             await _loadEmployees();
23861:         } catch (error) {
23862:             console.error('RW_HR.loadEmployees', error);
23863:             hideLoader();
23864:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل بيانات الموظفين</h3><p class="text-gray-500 mt-2">' + _esc(error.message || 'خطأ غير معروف') + '</p></div>');
23865:             return;
23866:         }
23867:         hideLoader();
23868: 
23869:         var activeEmployees = hrData.filter(function(emp) {
23870:             return !(emp.role === 'مالك' || emp.role === 'Owner');
23871:         });
23872: 
23873:         var html = '<div class="p-4 space-y-5">';
23874:         html += '<div class="grid grid-cols-1 md:grid-cols-4 gap-4">';
23875:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي الموظفين</div><div class="text-3xl font-black text-indigo-600 mt-2">' + activeEmployees.length + '</div></div>';
23876:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">الموظفون النشطون</div><div class="text-3xl font-black text-green-600 mt-2">' + activeEmployees.filter(function(e){return e.status==='Active';}).length + '</div></div>';
23877:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي التعويضات الشهرية</div><div class="text-3xl font-black text-blue-600 mt-2">' + _fmtNum(activeEmployees.reduce(function(sum,e){return sum + Number(e.basic_salary||0)+Number(e.housing_allowance||0)+Number(e.transport_allowance||0)+Number(e.other_allowance||0)-Number(e.default_deduction||0);},0)) + '</div></div>';
23878:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">ملفات موظفين بدون بطاقة</div><div class="text-3xl font-black text-amber-600 mt-2">' + activeEmployees.filter(function(e){return !e.profile_id;}).length + '</div></div>';
23879:         html += '</div>';
23880: 
23881:         html += '<div class="flex flex-col md:flex-row gap-3">';
23882:         html += '<input id="hr-search" class="flex-1 p-3 bg-white border rounded-xl" placeholder="بحث بالاسم أو البريد أو الرقم الوظيفي">';
23883:         html += '<button id="hr-refresh" class="px-5 py-3 bg-indigo-600 text-white rounded-xl font-bold">تحديث</button>';
23884:         html += '</div>';
23885: 
23886:         html += '<div id="hr-cards-container" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">';
23887:         html += activeEmployees.map(_employeeCard).join('');
23888:         html += '</div>';
23889:         html += '<div id="hr-empty" class="hidden text-center py-10 text-gray-500">لا توجد نتائج مطابقة.</div>';
23890:         html += '</div>';
23891:         safeHTML(container, html);
23892: 
23893:         var search = byId('hr-search');
23894:         if (search) {
23895:             search.addEventListener('input', function() {
23896:                 var q = search.value.trim().toLowerCase();
23897:                 var cards = byId('hr-cards-container').querySelectorAll('[data-hr-employee-id]');
23898:                 var visible = 0;
23899:                 for (var i = 0; i < cards.length; i++) {
23900:                     var empId = cards[i].getAttribute('data-hr-employee-id');
23901:                     var emp = hrData.filter(function(e){return e.id === empId;})[0];
23902:                     var hay = ((emp.name||'')+' '+(emp.email||'')+' '+(emp.employee_number||'')+' '+(emp.job_title||'')).toLowerCase();
23903:                     cards[i].style.display = !q || hay.indexOf(q) !== -1 ? '' : 'none';
23904:                     if (cards[i].style.display !== 'none') visible++;
23905:                 }
23906:                 byId('hr-empty').classList.toggle('hidden', visible !== 0);
23907:             });
23908:         }
23909:         var refresh = byId('hr-refresh');
23910:         if (refresh) refresh.addEventListener('click', function(){ render(); });
23911:         var cardNodes = container.querySelectorAll('[data-hr-employee-id]');
23912:         for (var c = 0; c < cardNodes.length; c++) {
23913:             cardNodes[c].addEventListener('click', function(){
23914:                 var id = this.getAttribute('data-hr-employee-id');
23915:                 _openModal(id);
23916:             });
23917:         }
23918:     }
23919: 
23920:     async function _loadDocuments(employeeId) {
23921:         var res = await supabase.from('employee_documents')
23922:             .select('id,document_type,storage_path,document_name,mime_type,expires_at,status,notes,created_at')
23923:             .eq('employee_id', employeeId)
23924:             .eq('company_id', _companyId())
23925:             .order('created_at', {ascending:false});
23926:         if (res.error) throw res.error;
23927:         return res.data || [];
23928:     }
23929: 
23930:     async function _loadAttendance(employeeId) {
23931:         var res = await supabase.from('employee_attendance')
23932:             .select('id,attendance_date,status,check_in,check_out,notes')
23933:             .eq('employee_id', employeeId)
23934:             .eq('company_id', _companyId())
23935:             .order('attendance_date',{ascending:false})
23936:             .limit(14);
23937:         if (res.error) throw res.error;
23938:         return res.data || [];
23939:     }
23940: 
23941:     async function _loadLeaves(employeeId) {
23942:         var res = await supabase.from('employee_leave_requests')
23943:             .select('id,leave_type,start_date,end_date,reason,status,requested_by,approved_by,approved_at,notes')
23944:             .eq('employee_id', employeeId)
23945:             .eq('company_id', _companyId())
23946:             .order('start_date',{ascending:false})
23947:             .limit(20);
23948:         if (res.error) throw res.error;
23949:         return res.data || [];
23950:     }
23951: 
23952:     async function _openModal(employeeId) {
23953:         var emp = hrData.filter(function(e){ return e.id === employeeId; })[0];
23954:         if (!emp) { showToast('الموظف غير موجود', 'error'); return; }
23955: 
23956:         showLoader('جاري تحميل ملف الموظف...');
23957:         try {
23958:             var docs = await _loadDocuments(employeeId);
23959:             var attendance = await _loadAttendance(employeeId);
23960:             var leaves = await _loadLeaves(employeeId);
23961:             hideLoader();
23962: 
23963:             var html = '<div class="text-right space-y-5" data-hr-modal="1">';
23964:             html += '<div class="bg-indigo-50 rounded-2xl p-5"><div class="flex justify-between gap-4"><div><h3 class="font-black text-xl">' + _esc(emp.name) + '</h3><p class="text-sm text-gray-500">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div><div class="text-left"><div class="text-xs text-gray-500">الرقم الوظيفي</div><div class="font-black">' + _esc(emp.employee_number || emp.employee_id || '-') + '</div></div></div></div>';
23965: 
23966:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">البيانات والوظيفة</h4><div class="grid grid-cols-2 gap-4 text-sm">';
23967:             html += '<div><span class="text-gray-500">البريد</span><div class="font-bold">' + _esc(emp.email) + '</div></div>';
23968:             html += '<div><span class="text-gray-500">الهاتف</span><div class="font-bold">' + _esc(emp.phone || '-') + '</div></div>';
23969:             html += '<div><span class="text-gray-500">القسم</span><div class="font-bold">' + _esc(emp.department || '-') + '</div></div>';
23970:             html += '<div><span class="text-gray-500">المسمى</span><div class="font-bold">' + _esc(emp.job_title || '-') + '</div></div>';
23971:             html += '<div><span class="text-gray-500">تاريخ الالتحاق</span><div class="font-bold">' + _esc(emp.hire_date || '-') + '</div></div>';
23972:             html += '<div><span class="text-gray-500">نوع التوظيف</span><div class="font-bold">' + _esc(emp.employment_type || '-') + '</div></div>';
23973:             html += '</div><div class="flex justify-end mt-4"><button id="hr-edit-profile" class="px-5 py-2 bg-indigo-600 text-white rounded-xl font-bold">تعديل الملف</button></div></div>';
23974: 
23975:             var totalComp = Number(emp.basic_salary||0)+Number(emp.housing_allowance||0)+Number(emp.transport_allowance||0)+Number(emp.other_allowance||0)-Number(emp.default_deduction||0);
23976:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">التعويضات المسجلة فعليًا</h4><div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">';
23977:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">أساسي</div><div class="font-black">'+_fmtNum(emp.basic_salary)+' EGP</div></div>';
23978:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">سكن</div><div class="font-black">'+_fmtNum(emp.housing_allowance)+' EGP</div></div>';
23979:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">نقل</div><div class="font-black">'+_fmtNum(emp.transport_allowance)+' EGP</div></div>';
23980:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">بدلات أخرى</div><div class="font-black">'+_fmtNum(emp.other_allowance)+' EGP</div></div>';
23981:             html += '<div class="bg-indigo-50 rounded-xl p-3"><div class="text-indigo-600 text-xs">الصافي المسجل</div><div class="font-black text-indigo-700">'+_fmtNum(totalComp)+' EGP</div></div>';
23982:             html += '</div></div>';
23983: 
23984:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الحضور والانصراف</h4><button id="hr-add-attendance" class="px-4 py-2 bg-emerald-600 text-white rounded-xl font-bold text-sm">تسجيل يوم</button></div>';
23985:             html += '<div class="overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-gray-500"><th class="p-2">التاريخ</th><th class="p-2">الحالة</th><th class="p-2">دخول</th><th class="p-2">خروج</th><th class="p-2">ملاحظات</th></tr></thead><tbody>';
23986:             html += attendance.map(function(a){return '<tr class="border-t"><td class="p-2">'+_esc(a.attendance_date)+'</td><td class="p-2 font-bold">'+_esc(a.status)+'</td><td class="p-2">'+_esc(a.check_in||'-')+'</td><td class="p-2">'+_esc(a.check_out||'-')+'</td><td class="p-2">'+_esc(a.notes||'-')+'</td></tr>';}).join('');
23987:             html += '</tbody></table></div></div>';
23988: 
23989:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الإجازات</h4><button id="hr-add-leave" class="px-4 py-2 bg-amber-600 text-white rounded-xl font-bold text-sm">طلب إجازة</button></div>';
23990:             html += leaves.map(function(l){var actions=l.status==='pending' ? '<button data-leave-approve="'+_escAttr(l.id)+'" class="px-3 py-1 bg-green-100 text-green-700 rounded-lg text-xs font-bold">اعتماد</button> <button data-leave-reject="'+_escAttr(l.id)+'" class="px-3 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-bold">رفض</button>' : ''; return '<div class="border-t py-3"><div class="flex justify-between"><div><b>'+_esc(l.leave_type)+'</b> — '+_esc(l.start_date)+' إلى '+_esc(l.end_date)+'</div><span class="font-bold">'+_esc(l.status)+'</span></div><div class="text-xs text-gray-500 mt-1">'+_esc(l.reason||'-')+'</div><div class="mt-2">'+actions+'</div></div>';}).join('');
23991:             if (!leaves.length) html += '<div class="text-center py-4 text-gray-400">لا توجد طلبات إجازة</div>';
23992:             html += '</div>';
23993: 
23994:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">المستندات</h4><button id="hr-upload-doc" class="px-4 py-2 bg-blue-600 text-white rounded-xl font-bold text-sm">رفع مستند</button></div>';
23995:             html += '<div class="space-y-2">';
23996:             for (var d=0; d<docs.length; d++) {
23997:                 html += '<div class="flex items-center justify-between border rounded-xl p-3"><div><div class="font-bold">'+_esc(docs[d].document_name||docs[d].document_type)+'</div><div class="text-xs text-gray-500">'+_esc(docs[d].document_type)+' — '+_esc(docs[d].expires_at||'بدون انتهاء')+'</div></div><button data-doc-id="'+_escAttr(docs[d].id)+'" data-doc-path="'+_escAttr(docs[d].storage_path||'')+'" class="px-3 py-1 bg-gray-100 rounded-lg text-xs font-bold">فتح</button></div>';
23998:             }
23999:             if (!docs.length) html += '<div class="text-center py-4 text-gray-400">لا توجد مستندات</div>';
24000:             html += '</div></div>';
24001:             html += '</div>';
--- WINDOW 23891-24101 around 23921 ---
23891:         safeHTML(container, html);
23892: 
23893:         var search = byId('hr-search');
23894:         if (search) {
23895:             search.addEventListener('input', function() {
23896:                 var q = search.value.trim().toLowerCase();
23897:                 var cards = byId('hr-cards-container').querySelectorAll('[data-hr-employee-id]');
23898:                 var visible = 0;
23899:                 for (var i = 0; i < cards.length; i++) {
23900:                     var empId = cards[i].getAttribute('data-hr-employee-id');
23901:                     var emp = hrData.filter(function(e){return e.id === empId;})[0];
23902:                     var hay = ((emp.name||'')+' '+(emp.email||'')+' '+(emp.employee_number||'')+' '+(emp.job_title||'')).toLowerCase();
23903:                     cards[i].style.display = !q || hay.indexOf(q) !== -1 ? '' : 'none';
23904:                     if (cards[i].style.display !== 'none') visible++;
23905:                 }
23906:                 byId('hr-empty').classList.toggle('hidden', visible !== 0);
23907:             });
23908:         }
23909:         var refresh = byId('hr-refresh');
23910:         if (refresh) refresh.addEventListener('click', function(){ render(); });
23911:         var cardNodes = container.querySelectorAll('[data-hr-employee-id]');
23912:         for (var c = 0; c < cardNodes.length; c++) {
23913:             cardNodes[c].addEventListener('click', function(){
23914:                 var id = this.getAttribute('data-hr-employee-id');
23915:                 _openModal(id);
23916:             });
23917:         }
23918:     }
23919: 
23920:     async function _loadDocuments(employeeId) {
23921:         var res = await supabase.from('employee_documents')
23922:             .select('id,document_type,storage_path,document_name,mime_type,expires_at,status,notes,created_at')
23923:             .eq('employee_id', employeeId)
23924:             .eq('company_id', _companyId())
23925:             .order('created_at', {ascending:false});
23926:         if (res.error) throw res.error;
23927:         return res.data || [];
23928:     }
23929: 
23930:     async function _loadAttendance(employeeId) {
23931:         var res = await supabase.from('employee_attendance')
23932:             .select('id,attendance_date,status,check_in,check_out,notes')
23933:             .eq('employee_id', employeeId)
23934:             .eq('company_id', _companyId())
23935:             .order('attendance_date',{ascending:false})
23936:             .limit(14);
23937:         if (res.error) throw res.error;
23938:         return res.data || [];
23939:     }
23940: 
23941:     async function _loadLeaves(employeeId) {
23942:         var res = await supabase.from('employee_leave_requests')
23943:             .select('id,leave_type,start_date,end_date,reason,status,requested_by,approved_by,approved_at,notes')
23944:             .eq('employee_id', employeeId)
23945:             .eq('company_id', _companyId())
23946:             .order('start_date',{ascending:false})
23947:             .limit(20);
23948:         if (res.error) throw res.error;
23949:         return res.data || [];
23950:     }
23951: 
23952:     async function _openModal(employeeId) {
23953:         var emp = hrData.filter(function(e){ return e.id === employeeId; })[0];
23954:         if (!emp) { showToast('الموظف غير موجود', 'error'); return; }
23955: 
23956:         showLoader('جاري تحميل ملف الموظف...');
23957:         try {
23958:             var docs = await _loadDocuments(employeeId);
23959:             var attendance = await _loadAttendance(employeeId);
23960:             var leaves = await _loadLeaves(employeeId);
23961:             hideLoader();
23962: 
23963:             var html = '<div class="text-right space-y-5" data-hr-modal="1">';
23964:             html += '<div class="bg-indigo-50 rounded-2xl p-5"><div class="flex justify-between gap-4"><div><h3 class="font-black text-xl">' + _esc(emp.name) + '</h3><p class="text-sm text-gray-500">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div><div class="text-left"><div class="text-xs text-gray-500">الرقم الوظيفي</div><div class="font-black">' + _esc(emp.employee_number || emp.employee_id || '-') + '</div></div></div></div>';
23965: 
23966:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">البيانات والوظيفة</h4><div class="grid grid-cols-2 gap-4 text-sm">';
23967:             html += '<div><span class="text-gray-500">البريد</span><div class="font-bold">' + _esc(emp.email) + '</div></div>';
23968:             html += '<div><span class="text-gray-500">الهاتف</span><div class="font-bold">' + _esc(emp.phone || '-') + '</div></div>';
23969:             html += '<div><span class="text-gray-500">القسم</span><div class="font-bold">' + _esc(emp.department || '-') + '</div></div>';
23970:             html += '<div><span class="text-gray-500">المسمى</span><div class="font-bold">' + _esc(emp.job_title || '-') + '</div></div>';
23971:             html += '<div><span class="text-gray-500">تاريخ الالتحاق</span><div class="font-bold">' + _esc(emp.hire_date || '-') + '</div></div>';
23972:             html += '<div><span class="text-gray-500">نوع التوظيف</span><div class="font-bold">' + _esc(emp.employment_type || '-') + '</div></div>';
23973:             html += '</div><div class="flex justify-end mt-4"><button id="hr-edit-profile" class="px-5 py-2 bg-indigo-600 text-white rounded-xl font-bold">تعديل الملف</button></div></div>';
23974: 
23975:             var totalComp = Number(emp.basic_salary||0)+Number(emp.housing_allowance||0)+Number(emp.transport_allowance||0)+Number(emp.other_allowance||0)-Number(emp.default_deduction||0);
23976:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">التعويضات المسجلة فعليًا</h4><div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">';
23977:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">أساسي</div><div class="font-black">'+_fmtNum(emp.basic_salary)+' EGP</div></div>';
23978:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">سكن</div><div class="font-black">'+_fmtNum(emp.housing_allowance)+' EGP</div></div>';
23979:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">نقل</div><div class="font-black">'+_fmtNum(emp.transport_allowance)+' EGP</div></div>';
23980:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">بدلات أخرى</div><div class="font-black">'+_fmtNum(emp.other_allowance)+' EGP</div></div>';
23981:             html += '<div class="bg-indigo-50 rounded-xl p-3"><div class="text-indigo-600 text-xs">الصافي المسجل</div><div class="font-black text-indigo-700">'+_fmtNum(totalComp)+' EGP</div></div>';
23982:             html += '</div></div>';
23983: 
23984:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الحضور والانصراف</h4><button id="hr-add-attendance" class="px-4 py-2 bg-emerald-600 text-white rounded-xl font-bold text-sm">تسجيل يوم</button></div>';
23985:             html += '<div class="overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-gray-500"><th class="p-2">التاريخ</th><th class="p-2">الحالة</th><th class="p-2">دخول</th><th class="p-2">خروج</th><th class="p-2">ملاحظات</th></tr></thead><tbody>';
23986:             html += attendance.map(function(a){return '<tr class="border-t"><td class="p-2">'+_esc(a.attendance_date)+'</td><td class="p-2 font-bold">'+_esc(a.status)+'</td><td class="p-2">'+_esc(a.check_in||'-')+'</td><td class="p-2">'+_esc(a.check_out||'-')+'</td><td class="p-2">'+_esc(a.notes||'-')+'</td></tr>';}).join('');
23987:             html += '</tbody></table></div></div>';
23988: 
23989:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الإجازات</h4><button id="hr-add-leave" class="px-4 py-2 bg-amber-600 text-white rounded-xl font-bold text-sm">طلب إجازة</button></div>';
23990:             html += leaves.map(function(l){var actions=l.status==='pending' ? '<button data-leave-approve="'+_escAttr(l.id)+'" class="px-3 py-1 bg-green-100 text-green-700 rounded-lg text-xs font-bold">اعتماد</button> <button data-leave-reject="'+_escAttr(l.id)+'" class="px-3 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-bold">رفض</button>' : ''; return '<div class="border-t py-3"><div class="flex justify-between"><div><b>'+_esc(l.leave_type)+'</b> — '+_esc(l.start_date)+' إلى '+_esc(l.end_date)+'</div><span class="font-bold">'+_esc(l.status)+'</span></div><div class="text-xs text-gray-500 mt-1">'+_esc(l.reason||'-')+'</div><div class="mt-2">'+actions+'</div></div>';}).join('');
23991:             if (!leaves.length) html += '<div class="text-center py-4 text-gray-400">لا توجد طلبات إجازة</div>';
23992:             html += '</div>';
23993: 
23994:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">المستندات</h4><button id="hr-upload-doc" class="px-4 py-2 bg-blue-600 text-white rounded-xl font-bold text-sm">رفع مستند</button></div>';
23995:             html += '<div class="space-y-2">';
23996:             for (var d=0; d<docs.length; d++) {
23997:                 html += '<div class="flex items-center justify-between border rounded-xl p-3"><div><div class="font-bold">'+_esc(docs[d].document_name||docs[d].document_type)+'</div><div class="text-xs text-gray-500">'+_esc(docs[d].document_type)+' — '+_esc(docs[d].expires_at||'بدون انتهاء')+'</div></div><button data-doc-id="'+_escAttr(docs[d].id)+'" data-doc-path="'+_escAttr(docs[d].storage_path||'')+'" class="px-3 py-1 bg-gray-100 rounded-lg text-xs font-bold">فتح</button></div>';
23998:             }
23999:             if (!docs.length) html += '<div class="text-center py-4 text-gray-400">لا توجد مستندات</div>';
24000:             html += '</div></div>';
24001:             html += '</div>';
24002: 
24003:             Swal.fire({title:'ملف الموظف: '+_esc(emp.name),html:html,width:'980px',showCloseButton:true,showConfirmButton:false,didOpen:function(){
24004:                 var editBtn=byId('hr-edit-profile'); if(editBtn) editBtn.addEventListener('click',function(){_editProfile(emp);});
24005:                 var attBtn=byId('hr-add-attendance'); if(attBtn) attBtn.addEventListener('click',function(){_addAttendance(emp);});
24006:                 var leaveBtn=byId('hr-add-leave'); if(leaveBtn) leaveBtn.addEventListener('click',function(){_addLeave(emp);});
24007:                 var uploadBtn=byId('hr-upload-doc'); if(uploadBtn) uploadBtn.addEventListener('click',function(){_uploadDocument(emp);});
24008:                 var approveNodes=document.querySelectorAll('[data-leave-approve]'); for(var ai=0;ai<approveNodes.length;ai++) approveNodes[ai].addEventListener('click',function(){_setLeaveStatus(this.getAttribute('data-leave-approve'),'approved',emp);});
24009:                 var rejectNodes=document.querySelectorAll('[data-leave-reject]'); for(var ri=0;ri<rejectNodes.length;ri++) rejectNodes[ri].addEventListener('click',function(){_setLeaveStatus(this.getAttribute('data-leave-reject'),'rejected',emp);});
24010:                 var docNodes=document.querySelectorAll('[data-doc-path]'); for(var di=0;di<docNodes.length;di++) docNodes[di].addEventListener('click',function(){_openDocument(this.getAttribute('data-doc-path'));});
24011:             }});
24012:         } catch(error) {
24013:             hideLoader();
24014:             showToast('تعذر تحميل ملف الموظف: '+(error.message||'خطأ غير معروف'),'error');
24015:         }
24016:     }
24017: 
24018:     async function _editProfile(emp) {
24019:         var html='<div class="text-right space-y-3">'+
24020:             '<input id="hr-p-number" class="w-full p-2 border rounded" placeholder="الرقم الوظيفي" value="'+_escAttr(emp.employee_number||emp.employee_id||'')+'">'+
24021:             '<input id="hr-p-department" class="w-full p-2 border rounded" placeholder="القسم" value="'+_escAttr(emp.department||'')+'">'+
24022:             '<input id="hr-p-title" class="w-full p-2 border rounded" placeholder="المسمى الوظيفي" value="'+_escAttr(emp.job_title||emp.role||'')+'">'+
24023:             '<input id="hr-p-hire-date" type="date" class="w-full p-2 border rounded" value="'+_escAttr(emp.hire_date||'')+'">'+
24024:             '<input id="hr-p-type" class="w-full p-2 border rounded" placeholder="نوع التوظيف" value="'+_escAttr(emp.employment_type||'')+'">'+
24025:             '<div class="grid grid-cols-2 gap-2"><input id="hr-p-basic" type="number" min="0" class="p-2 border rounded" placeholder="الأساسي" value="'+Number(emp.basic_salary||0)+'"><input id="hr-p-housing" type="number" min="0" class="p-2 border rounded" placeholder="بدل السكن" value="'+Number(emp.housing_allowance||0)+'"><input id="hr-p-transport" type="number" min="0" class="p-2 border rounded" placeholder="بدل النقل" value="'+Number(emp.transport_allowance||0)+'"><input id="hr-p-other" type="number" min="0" class="p-2 border rounded" placeholder="بدلات أخرى" value="'+Number(emp.other_allowance||0)+'"><input id="hr-p-deduct" type="number" min="0" class="p-2 border rounded" placeholder="خصم ثابت" value="'+Number(emp.default_deduction||0)+'"></div>'+
24026:             '<textarea id="hr-p-notes" class="w-full p-2 border rounded" placeholder="ملاحظات">'+_esc(emp.profile_notes||'')+'</textarea></div>';
24027:         Swal.fire({title:'تعديل ملف الموظف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_upsert_employee_profile',{p_employee_id:emp.id,p_employee_number:byId('hr-p-number').value.trim()||null,p_department:byId('hr-p-department').value.trim()||null,p_job_title:byId('hr-p-title').value.trim()||null,p_hire_date:byId('hr-p-hire-date').value||null,p_employment_type:byId('hr-p-type').value.trim()||null,p_basic_salary:Number(byId('hr-p-basic').value||0),p_housing_allowance:Number(byId('hr-p-housing').value||0),p_transport_allowance:Number(byId('hr-p-transport').value||0),p_other_allowance:Number(byId('hr-p-other').value||0),p_default_deduction:Number(byId('hr-p-deduct').value||0),p_status:(emp.profile_status||'active'),p_notes:byId('hr-p-notes').value.trim()||null}).then(function(res){if(res.error) throw res.error; return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ ملف الموظف','success');Swal.close();render();}}).catch(function(e){showToast('فشل حفظ الملف: '+(e.message||'خطأ غير معروف'),'error');});
24028:     }
24029: 
24030:     async function _addAttendance(emp) {
24031:         var html='<div class="text-right space-y-3"><input id="hr-att-date" type="date" class="w-full p-2 border rounded" value="'+new Date().toISOString().slice(0,10)+'"><select id="hr-att-status" class="w-full p-2 border rounded"><option value="present">حاضر</option><option value="late">متأخر</option><option value="absent">غائب</option><option value="leave">إجازة</option><option value="holiday">عطلة</option></select><input id="hr-att-in" type="datetime-local" class="w-full p-2 border rounded"><input id="hr-att-out" type="datetime-local" class="w-full p-2 border rounded"><textarea id="hr-att-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24032:         Swal.fire({title:'تسجيل حضور/انصراف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){var toISO=function(id){var v=byId(id).value;return v?new Date(v).toISOString():null;};return supabase.rpc('hr_save_attendance',{p_employee_id:emp.id,p_attendance_date:byId('hr-att-date').value,p_status:byId('hr-att-status').value,p_check_in:toISO('hr-att-in'),p_check_out:toISO('hr-att-out'),p_notes:byId('hr-att-notes').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ الحضور','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل حفظ الحضور: '+(e.message||'خطأ غير معروف'),'error');});
24033:     }
24034: 
24035:     async function _addLeave(emp) {
24036:         var html='<div class="text-right space-y-3"><input id="hr-leave-type" class="w-full p-2 border rounded" placeholder="نوع الإجازة"><div class="grid grid-cols-2 gap-2"><input id="hr-leave-start" type="date" class="p-2 border rounded"><input id="hr-leave-end" type="date" class="p-2 border rounded"></div><textarea id="hr-leave-reason" class="w-full p-2 border rounded" placeholder="السبب"></textarea></div>';
24037:         Swal.fire({title:'طلب إجازة',html:html,showCancelButton:true,confirmButtonText:'إرسال',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_create_leave_request',{p_employee_id:emp.id,p_leave_type:byId('hr-leave-type').value.trim(),p_start_date:byId('hr-leave-start').value,p_end_date:byId('hr-leave-end').value,p_reason:byId('hr-leave-reason').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم إنشاء طلب الإجازة','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل إنشاء الإجازة: '+(e.message||'خطأ غير معروف'),'error');});
24038:     }
24039: 
24040:     async function _setLeaveStatus(id,status,emp) {
24041:         var res=await supabase.rpc('hr_set_leave_status',{
24042:             p_leave_request_id:id,
24043:             p_status:status,
24044:             p_notes:null
24045:         });
24046:         if(res.error){showToast('فشل تحديث الإجازة: '+res.error.message,'error');return;}
24047:         showToast(status==='approved'?'تم اعتماد الإجازة':'تم رفض الإجازة','success');
24048:         _openModal(emp.id);
24049:     }
24050:     async function _uploadDocument(emp) {
24051:         var html='<div class="text-right space-y-3"><select id="hr-doc-type" class="w-full p-2 border rounded"><option value="identity">صورة الهوية</option><option value="contract">عقد العمل</option><option value="other">مستند آخر</option></select><input id="hr-doc-expiry" type="date" class="w-full p-2 border rounded"><input id="hr-doc-file" type="file" class="w-full p-2 border rounded"><textarea id="hr-doc-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24052:         Swal.fire({title:'رفع مستند الموظف',html:html,showCancelButton:true,confirmButtonText:'رفع',cancelButtonText:'إلغاء',preConfirm:async function(){var file=byId('hr-doc-file').files[0];if(!file)throw new Error('اختر ملفًا أولاً');var company=_companyId();var safeName=file.name.replace(/[^a-zA-Z0-9._-]+/g,'_');var path=company+'/'+emp.id+'/'+Date.now()+'_'+safeName;var up=await supabase.storage.from('employee-documents').upload(path,file,{upsert:false,contentType:file.type||'application/octet-stream'});if(up.error)throw up.error;var ins=await supabase.from('employee_documents').insert({company_id:company,employee_id:emp.id,document_type:byId('hr-doc-type').value,storage_path:path,document_name:file.name,mime_type:file.type||null,expires_at:byId('hr-doc-expiry').value||null,status:'active',notes:byId('hr-doc-notes').value.trim()||null,created_by:(RW_STATE&&RW_STATE.app&&RW_STATE.app.currentUser&&RW_STATE.app.currentUser.email)||''});if(ins.error){await supabase.storage.from('employee-documents').remove([path]);throw ins.error;}return true;}}).then(function(res){if(res.isConfirmed){showToast('تم رفع المستند','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل رفع المستند: '+(e.message||'خطأ غير معروف'),'error');});
24053:     }
24054: 
24055:     async function _openDocument(path) {
24056:         if (!path) { showToast('مسار المستند غير موجود','error'); return; }
24057:         var res=await supabase.storage.from('employee-documents').createSignedUrl(path,300);
24058:         if(res.error){showToast('تعذر فتح المستند: '+res.error.message,'error');return;}
24059:         window.open(res.data.signedUrl,'_blank','noopener');
24060:     }
24061: 
24062:     return { render: render, _openModal: _openModal };
24063: })();
24064: window.RW_HR = RW_HR;
24065: // ============================================================
24066: // RW_CRM – إدارة علاقات العملاء (CRM)
24067: // ============================================================
24068: var RW_CRM = (function() {
24069:     'use strict';
24070: 
24071:     var customersData = [];
24072: 
24073:     function _esc(s) {
24074:         return String(s == null ? '' : s)
24075:             .replace(/&/g, '&amp;')
24076:             .replace(/</g, '&lt;')
24077:             .replace(/>/g, '&gt;');
24078:     }
24079: 
24080:     function _escAttr(s) {
24081:         return _esc(s)
24082:             .replace(/\"/g, '&quot;')
24083:             .replace(/'/g, '&#39;');
24084:     }
24085: 
24086:     function _fmtNum(n) {
24087:         return Number(n || 0).toLocaleString('ar-EG');
24088:     }
24089: 
24090:     function _companyId() {
24091:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
24092:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
24093:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
24094:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
24095:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
24096:         }
24097:         return null;
24098:     }
24099: 
24100:     async function _loadCustomers() {
24101:         var res = await supabase.from('customers')
--- WINDOW 24022-24232 around 24052 ---
24022:             '<input id="hr-p-title" class="w-full p-2 border rounded" placeholder="المسمى الوظيفي" value="'+_escAttr(emp.job_title||emp.role||'')+'">'+
24023:             '<input id="hr-p-hire-date" type="date" class="w-full p-2 border rounded" value="'+_escAttr(emp.hire_date||'')+'">'+
24024:             '<input id="hr-p-type" class="w-full p-2 border rounded" placeholder="نوع التوظيف" value="'+_escAttr(emp.employment_type||'')+'">'+
24025:             '<div class="grid grid-cols-2 gap-2"><input id="hr-p-basic" type="number" min="0" class="p-2 border rounded" placeholder="الأساسي" value="'+Number(emp.basic_salary||0)+'"><input id="hr-p-housing" type="number" min="0" class="p-2 border rounded" placeholder="بدل السكن" value="'+Number(emp.housing_allowance||0)+'"><input id="hr-p-transport" type="number" min="0" class="p-2 border rounded" placeholder="بدل النقل" value="'+Number(emp.transport_allowance||0)+'"><input id="hr-p-other" type="number" min="0" class="p-2 border rounded" placeholder="بدلات أخرى" value="'+Number(emp.other_allowance||0)+'"><input id="hr-p-deduct" type="number" min="0" class="p-2 border rounded" placeholder="خصم ثابت" value="'+Number(emp.default_deduction||0)+'"></div>'+
24026:             '<textarea id="hr-p-notes" class="w-full p-2 border rounded" placeholder="ملاحظات">'+_esc(emp.profile_notes||'')+'</textarea></div>';
24027:         Swal.fire({title:'تعديل ملف الموظف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_upsert_employee_profile',{p_employee_id:emp.id,p_employee_number:byId('hr-p-number').value.trim()||null,p_department:byId('hr-p-department').value.trim()||null,p_job_title:byId('hr-p-title').value.trim()||null,p_hire_date:byId('hr-p-hire-date').value||null,p_employment_type:byId('hr-p-type').value.trim()||null,p_basic_salary:Number(byId('hr-p-basic').value||0),p_housing_allowance:Number(byId('hr-p-housing').value||0),p_transport_allowance:Number(byId('hr-p-transport').value||0),p_other_allowance:Number(byId('hr-p-other').value||0),p_default_deduction:Number(byId('hr-p-deduct').value||0),p_status:(emp.profile_status||'active'),p_notes:byId('hr-p-notes').value.trim()||null}).then(function(res){if(res.error) throw res.error; return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ ملف الموظف','success');Swal.close();render();}}).catch(function(e){showToast('فشل حفظ الملف: '+(e.message||'خطأ غير معروف'),'error');});
24028:     }
24029: 
24030:     async function _addAttendance(emp) {
24031:         var html='<div class="text-right space-y-3"><input id="hr-att-date" type="date" class="w-full p-2 border rounded" value="'+new Date().toISOString().slice(0,10)+'"><select id="hr-att-status" class="w-full p-2 border rounded"><option value="present">حاضر</option><option value="late">متأخر</option><option value="absent">غائب</option><option value="leave">إجازة</option><option value="holiday">عطلة</option></select><input id="hr-att-in" type="datetime-local" class="w-full p-2 border rounded"><input id="hr-att-out" type="datetime-local" class="w-full p-2 border rounded"><textarea id="hr-att-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24032:         Swal.fire({title:'تسجيل حضور/انصراف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){var toISO=function(id){var v=byId(id).value;return v?new Date(v).toISOString():null;};return supabase.rpc('hr_save_attendance',{p_employee_id:emp.id,p_attendance_date:byId('hr-att-date').value,p_status:byId('hr-att-status').value,p_check_in:toISO('hr-att-in'),p_check_out:toISO('hr-att-out'),p_notes:byId('hr-att-notes').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ الحضور','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل حفظ الحضور: '+(e.message||'خطأ غير معروف'),'error');});
24033:     }
24034: 
24035:     async function _addLeave(emp) {
24036:         var html='<div class="text-right space-y-3"><input id="hr-leave-type" class="w-full p-2 border rounded" placeholder="نوع الإجازة"><div class="grid grid-cols-2 gap-2"><input id="hr-leave-start" type="date" class="p-2 border rounded"><input id="hr-leave-end" type="date" class="p-2 border rounded"></div><textarea id="hr-leave-reason" class="w-full p-2 border rounded" placeholder="السبب"></textarea></div>';
24037:         Swal.fire({title:'طلب إجازة',html:html,showCancelButton:true,confirmButtonText:'إرسال',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_create_leave_request',{p_employee_id:emp.id,p_leave_type:byId('hr-leave-type').value.trim(),p_start_date:byId('hr-leave-start').value,p_end_date:byId('hr-leave-end').value,p_reason:byId('hr-leave-reason').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم إنشاء طلب الإجازة','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل إنشاء الإجازة: '+(e.message||'خطأ غير معروف'),'error');});
24038:     }
24039: 
24040:     async function _setLeaveStatus(id,status,emp) {
24041:         var res=await supabase.rpc('hr_set_leave_status',{
24042:             p_leave_request_id:id,
24043:             p_status:status,
24044:             p_notes:null
24045:         });
24046:         if(res.error){showToast('فشل تحديث الإجازة: '+res.error.message,'error');return;}
24047:         showToast(status==='approved'?'تم اعتماد الإجازة':'تم رفض الإجازة','success');
24048:         _openModal(emp.id);
24049:     }
24050:     async function _uploadDocument(emp) {
24051:         var html='<div class="text-right space-y-3"><select id="hr-doc-type" class="w-full p-2 border rounded"><option value="identity">صورة الهوية</option><option value="contract">عقد العمل</option><option value="other">مستند آخر</option></select><input id="hr-doc-expiry" type="date" class="w-full p-2 border rounded"><input id="hr-doc-file" type="file" class="w-full p-2 border rounded"><textarea id="hr-doc-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24052:         Swal.fire({title:'رفع مستند الموظف',html:html,showCancelButton:true,confirmButtonText:'رفع',cancelButtonText:'إلغاء',preConfirm:async function(){var file=byId('hr-doc-file').files[0];if(!file)throw new Error('اختر ملفًا أولاً');var company=_companyId();var safeName=file.name.replace(/[^a-zA-Z0-9._-]+/g,'_');var path=company+'/'+emp.id+'/'+Date.now()+'_'+safeName;var up=await supabase.storage.from('employee-documents').upload(path,file,{upsert:false,contentType:file.type||'application/octet-stream'});if(up.error)throw up.error;var ins=await supabase.from('employee_documents').insert({company_id:company,employee_id:emp.id,document_type:byId('hr-doc-type').value,storage_path:path,document_name:file.name,mime_type:file.type||null,expires_at:byId('hr-doc-expiry').value||null,status:'active',notes:byId('hr-doc-notes').value.trim()||null,created_by:(RW_STATE&&RW_STATE.app&&RW_STATE.app.currentUser&&RW_STATE.app.currentUser.email)||''});if(ins.error){await supabase.storage.from('employee-documents').remove([path]);throw ins.error;}return true;}}).then(function(res){if(res.isConfirmed){showToast('تم رفع المستند','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل رفع المستند: '+(e.message||'خطأ غير معروف'),'error');});
24053:     }
24054: 
24055:     async function _openDocument(path) {
24056:         if (!path) { showToast('مسار المستند غير موجود','error'); return; }
24057:         var res=await supabase.storage.from('employee-documents').createSignedUrl(path,300);
24058:         if(res.error){showToast('تعذر فتح المستند: '+res.error.message,'error');return;}
24059:         window.open(res.data.signedUrl,'_blank','noopener');
24060:     }
24061: 
24062:     return { render: render, _openModal: _openModal };
24063: })();
24064: window.RW_HR = RW_HR;
24065: // ============================================================
24066: // RW_CRM – إدارة علاقات العملاء (CRM)
24067: // ============================================================
24068: var RW_CRM = (function() {
24069:     'use strict';
24070: 
24071:     var customersData = [];
24072: 
24073:     function _esc(s) {
24074:         return String(s == null ? '' : s)
24075:             .replace(/&/g, '&amp;')
24076:             .replace(/</g, '&lt;')
24077:             .replace(/>/g, '&gt;');
24078:     }
24079: 
24080:     function _escAttr(s) {
24081:         return _esc(s)
24082:             .replace(/\"/g, '&quot;')
24083:             .replace(/'/g, '&#39;');
24084:     }
24085: 
24086:     function _fmtNum(n) {
24087:         return Number(n || 0).toLocaleString('ar-EG');
24088:     }
24089: 
24090:     function _companyId() {
24091:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
24092:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
24093:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
24094:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
24095:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
24096:         }
24097:         return null;
24098:     }
24099: 
24100:     async function _loadCustomers() {
24101:         var res = await supabase.from('customers')
24102:             .select('id,customer_code,name,phone,area,debt,is_active')
24103:             .eq('company_id', _companyId())
24104:             .order('name',{ascending:true});
24105:         if (res.error) throw res.error;
24106:         customersData = res.data || [];
24107:         return customersData;
24108:     }
24109: 
24110:     function _table(customers) {
24111:         if (!customers.length) return '<div class="text-center py-10 text-gray-500">لا يوجد عملاء</div>';
24112:         var html='<div class="overflow-x-auto"><table class="w-full text-sm"><thead class="bg-gray-50"><tr><th class="p-3 text-right">العميل</th><th class="p-3 text-right">الهاتف</th><th class="p-3 text-right">المنطقة</th><th class="p-3 text-center">الرصيد</th><th class="p-3 text-center">الإجراء</th></tr></thead><tbody>';
24113:         for(var i=0;i<customers.length;i++){
24114:             var c=customers[i];
24115:             html+='<tr class="border-b hover:bg-gray-50" data-crm-customer="'+_escAttr(c.customer_code)+'">'+
24116:                 '<td class="p-3"><div class="font-bold">'+_esc(c.name)+'</div><div class="text-xs text-gray-400">'+_esc(c.customer_code)+'</div></td>'+
24117:                 '<td class="p-3">'+_esc(c.phone||'-')+'</td>'+
24118:                 '<td class="p-3">'+_esc(c.area||'-')+'</td>'+
24119:                 '<td class="p-3 text-center font-black '+(Number(c.debt)>0?'text-red-600':'text-green-600')+'">'+_fmtNum(c.debt)+' EGP</td>'+
24120:                 '<td class="p-3 text-center"><button data-crm-open="'+_escAttr(c.customer_code)+'" class="px-4 py-2 bg-indigo-100 text-indigo-700 rounded-lg font-bold">متابعة</button></td>'+
24121:             '</tr>';
24122:         }
24123:         return html+'</tbody></table></div>';
24124:     }
24125: 
24126:     async function render() {
24127:         var container=byId('rw-page-container'); if(!container) return;
24128:         safeText(byId('rw-header-title'),'إدارة علاقات العملاء (CRM)');
24129:         safeText(byId('rw-header-subtitle'),'سجل الاتصالات والمتابعات والإجراءات القادمة للعملاء');
24130:         if(!_companyId()){safeHTML(container,'<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">سياق الشركة غير محدد</h3></div>');return;}
24131:         showLoader('جاري تحميل العملاء...');
24132:         try{await _loadCustomers();}catch(e){hideLoader();safeHTML(container,'<div class="rw-card p-8 text-center"><h3 class="font-black text-xl">تعذر تحميل العملاء</h3><p class="text-gray-500 mt-2">'+_esc(e.message||'خطأ غير معروف')+'</p></div>');return;}
24133:         hideLoader();
24134: 
24135:         var html='<div class="p-4 space-y-5">';
24136:         html+='<div class="grid grid-cols-1 md:grid-cols-4 gap-4">';
24137:         html+='<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي العملاء</div><div class="text-3xl font-black text-indigo-600 mt-2">'+customersData.length+'</div></div>';
24138:         html+='<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">عملاء نشطون</div><div class="text-3xl font-black text-green-600 mt-2">'+customersData.filter(function(c){return c.is_active!==false;}).length+'</div></div>';
24139:         html+='<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي الذمم</div><div class="text-3xl font-black text-red-600 mt-2">'+_fmtNum(customersData.reduce(function(s,c){return s+Number(c.debt||0);},0))+' EGP</div></div>';
24140:         html+='<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">تحتاج متابعة</div><div id="crm-open-count" class="text-3xl font-black text-amber-600 mt-2">—</div></div>';
24141:         html+='</div>';
24142:         html+='<div class="flex flex-col md:flex-row gap-3"><input id="crm-search" class="flex-1 p-3 bg-white border rounded-xl" placeholder="بحث بالاسم أو الكود أو الهاتف"><button id="crm-refresh" class="px-5 py-3 bg-indigo-600 text-white rounded-xl font-bold">تحديث</button></div>';
24143:         html+='<div id="crm-customers-list" class="bg-white rounded-2xl border overflow-hidden">'+_table(customersData)+'</div></div>';
24144:         safeHTML(container,html);
24145: 
24146:         var search=byId('crm-search');
24147:         if(search) search.addEventListener('input',function(){var q=search.value.trim().toLowerCase();var filtered=customersData.filter(function(c){return !q||((c.name||'')+' '+(c.customer_code||'')+' '+(c.phone||'')).toLowerCase().indexOf(q)!==-1;});safeHTML(byId('crm-customers-list'),_table(filtered));_bindCustomerButtons();});
24148:         var refresh=byId('crm-refresh'); if(refresh) refresh.addEventListener('click',render);
24149:         _bindCustomerButtons();
24150:         _loadOpenCount();
24151:     }
24152: 
24153:     function _bindCustomerButtons(){
24154:         var buttons=document.querySelectorAll('[data-crm-open]');
24155:         for(var i=0;i<buttons.length;i++) buttons[i].addEventListener('click',function(){_openFollowupModal(this.getAttribute('data-crm-open'));});
24156:     }
24157: 
24158:     async function _loadOpenCount(){
24159:         var res=await supabase.from('customer_followups').select('id',{count:'exact',head:true}).eq('company_id',_companyId()).in('status',['Open','معلقة']);
24160:         var el=byId('crm-open-count'); if(el) el.textContent=res.error?'—':String(res.count||0);
24161:     }
24162: 
24163:     async function _openFollowupModal(customerCode){
24164:         var cust=customersData.filter(function(c){return c.customer_code===customerCode;})[0];
24165:         if(!cust){showToast('العميل غير موجود','error');return;}
24166:         showLoader('جاري تحميل سجل المتابعة...');
24167:         var res=await supabase.from('customer_followups').select('id,followup_date,followup_type,subject,notes,assigned_to,status,created_by,created_at,completed_at').eq('company_id',_companyId()).eq('customer_id',customerCode).order('followup_date',{ascending:false}).order('created_at',{ascending:false});
24168:         hideLoader();
24169:         if(res.error){showToast('فشل تحميل المتابعة: '+res.error.message,'error');return;}
24170:         var followups=res.data||[];
24171:         var html='<div class="text-right space-y-5">';
24172:         html+='<div class="bg-indigo-50 rounded-2xl p-5"><div class="flex justify-between"><div><h3 class="font-black text-xl">'+_esc(cust.name)+'</h3><p class="text-sm text-gray-500">'+_esc(cust.customer_code)+'</p></div><div class="text-left font-black">'+_fmtNum(cust.debt)+' EGP</div></div><div class="flex gap-2 mt-3"><a href="tel:'+_escAttr(cust.phone||'')+'" class="px-4 py-2 bg-green-600 text-white rounded-xl text-xs font-bold">اتصال</a><a href="https://wa.me/'+_escAttr(String(cust.phone||'').replace(/\D/g,''))+'" target="_blank" rel="noopener" class="px-4 py-2 bg-emerald-600 text-white rounded-xl text-xs font-bold">واتساب</a></div></div>';
24173:         html+='<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">إضافة متابعة</h4><div class="grid grid-cols-1 md:grid-cols-4 gap-3"><input id="crm-date" type="date" class="p-2 border rounded" value="'+new Date().toISOString().slice(0,10)+'"><select id="crm-type" class="p-2 border rounded"><option value="Call">هاتف</option><option value="WhatsApp">واتساب</option><option value="Visit">زيارة</option><option value="Email">بريد</option><option value="Other">أخرى</option></select><select id="crm-status" class="p-2 border rounded"><option value="Open">مفتوحة</option><option value="completed">مكتملة</option><option value="cancelled">ملغاة</option></select><input id="crm-assigned" class="p-2 border rounded" placeholder="مسؤول المتابعة"></div><input id="crm-subject" class="w-full mt-3 p-2 border rounded" placeholder="موضوع المتابعة"><textarea id="crm-notes" class="w-full mt-3 p-2 border rounded" rows="3" placeholder="ملاحظات وتفاصيل الإجراء"></textarea><div class="flex justify-end mt-3"><button id="crm-save-followup" class="px-6 py-2 bg-indigo-600 text-white rounded-xl font-bold">حفظ المتابعة</button></div></div>';
24174:         html+='<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-3">السجل</h4>';
24175:         if(!followups.length) html+='<div class="text-center py-6 text-gray-400">لا توجد متابعات سابقة</div>';
24176:         for(var i=0;i<followups.length;i++){var f=followups[i];html+='<div class="border-t py-3"><div class="flex justify-between"><div><b>'+_esc(f.subject||f.followup_type||'متابعة')+'</b><div class="text-xs text-gray-500">'+_esc(f.followup_date)+' — '+_esc(f.assigned_to||'-')+'</div></div><span class="px-2 py-1 rounded-full text-xs font-bold '+(f.status==='completed'?'bg-green-100 text-green-700':f.status==='cancelled'?'bg-red-100 text-red-700':'bg-yellow-100 text-yellow-700')+'">'+_esc(f.status)+'</span></div><p class="text-sm mt-2">'+_esc(f.notes||'-')+'</p></div>';}
24177:         html+='</div></div>';
24178:         Swal.fire({title:'متابعة العميل: '+_esc(cust.name),html:html,width:'900px',showCloseButton:true,showConfirmButton:false,didOpen:function(){var save=byId('crm-save-followup');if(save)save.addEventListener('click',async function(){var current=(RW_STATE&&RW_STATE.app&&RW_STATE.app.currentUser)||{};var payload={customerCode:customerCode};var r=await supabase.rpc('crm_save_customer_followup',{p_customer_code:customerCode,p_followup_date:byId('crm-date').value,p_followup_type:byId('crm-type').value,p_status:byId('crm-status').value,p_subject:byId('crm-subject').value.trim()||null,p_notes:byId('crm-notes').value.trim()||null,p_assigned_to:byId('crm-assigned').value.trim()||current.email||null});if(r.error){showToast('فشل الحفظ: '+r.error.message,'error');return;}showToast('تم حفظ المتابعة','success');Swal.close();_openFollowupModal(customerCode);});}});
24179:     }
24180: 
24181:     return {render:render,_openFollowupModal:_openFollowupModal};
24182: })();
24183: window.RW_CRM = RW_CRM;
24184: 	// ============================================================
24185: // RW_SalesReturnsManagement – Parent Management for Sales Returns
24186: // ============================================================
24187: var RW_SalesReturnsManagement = (function() {
24188:     'use strict';
24189: 
24190:     var state = {
24191:         rows: [],
24192:         assignees: [],
24193:         page: 0,
24194:         limit: 50,
24195:         timer: null
24196:     };
24197: 
24198:     function _esc(s) {
24199:         return String(s == null ? '' : s)
24200:             .replace(/&/g, '&amp;')
24201:             .replace(/</g, '&lt;')
24202:             .replace(/>/g, '&gt;')
24203:             .replace(/"/g, '&quot;')
24204:             .replace(/'/g, '&#39;');
24205:     }
24206: 
24207:     function _companyId() {
24208:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
24209:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
24210:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
24211:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
24212:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
24213:         }
24214:         return null;
24215:     }
24216: 
24217:     function _today() {
24218:         return new Date().toISOString().slice(0, 10);
24219:     }
24220: 
24221:     async function _token() {
24222:         var s = await supabase.auth.getSession();
24223:         if (!s || s.error || !s.data || !s.data.session || !s.data.session.access_token) {
24224:             throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
24225:         }
24226:         return s.data.session.access_token;
24227:     }
24228: 
24229:     async function _api(action, payload) {
24230:         var token = await _token();
24231:         var body = payload || {};
24232:         body.action = action;
--- RW_HR_FULL 23788-24064 ---
23788: var RW_HR = (function() {
23789:     'use strict';
23790: 
23791:     var hrData = [];
23792: 
23793:     function _esc(s) {
23794:         return String(s == null ? '' : s)
23795:             .replace(/&/g, '&amp;')
23796:             .replace(/</g, '&lt;')
23797:             .replace(/>/g, '&gt;');
23798:     }
23799: 
23800:     function _escAttr(s) {
23801:         return _esc(s)
23802:             .replace(/\"/g, '&quot;')
23803:             .replace(/'/g, '&#39;');
23804:     }
23805: 
23806:     function _fmtNum(n) {
23807:         return Number(n || 0).toLocaleString('ar-EG');
23808:     }
23809: 
23810:     function _companyId() {
23811:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
23812:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
23813:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
23814:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
23815:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
23816:         }
23817:         return null;
23818:     }
23819: 
23820:     async function _loadEmployees() {
23821:         var res = await supabase.rpc('hr_list_employees');
23822:         if (res.error) throw res.error;
23823:         hrData = res.data || [];
23824:         return hrData;
23825:     }
23826: 
23827:     function _employeeCard(emp) {
23828:         var profileSalary = Number(emp.basic_salary || 0) +
23829:             Number(emp.housing_allowance || 0) +
23830:             Number(emp.transport_allowance || 0) +
23831:             Number(emp.other_allowance || 0) -
23832:             Number(emp.default_deduction || 0);
23833:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
23834:             '<div class="flex items-center gap-4 mb-4">' +
23835:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
23836:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
23837:             '</div>' +
23838:             '<div class="space-y-2 text-sm">' +
23839:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
23840:                 '<div class="flex justify-between"><span class="text-gray-500">الهاتف</span><span class="font-bold text-gray-700">' + _esc(emp.phone || '-') + '</span></div>' +
23841:                 '<div class="flex justify-between"><span class="text-gray-500">الحالة</span><span class="px-2 py-0.5 rounded-full text-xs font-bold ' + (emp.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700') + '">' + _esc(emp.status === 'Active' ? 'نشط' : 'غير نشط') + '</span></div>' +
23842:                 '<div class="flex justify-between"><span class="text-gray-500">صافي التعويض</span><span class="font-black text-indigo-600">' + _fmtNum(profileSalary) + ' EGP</span></div>' +
23843:             '</div>' +
23844:         '</div>';
23845:     }
23846: 
23847:     async function render() {
23848:         var container = byId('rw-page-container');
23849:         if (!container) return;
23850:         safeText(byId('rw-header-title'), 'الموارد البشرية');
23851:         safeText(byId('rw-header-subtitle'), 'ملفات الموظفين والتعويضات والحضور والإجازات والمستندات');
23852: 
23853:         if (!_companyId()) {
23854:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحديد سياق الشركة</h3></div>');
23855:             return;
23856:         }
23857: 
23858:         showLoader('جاري تحميل بيانات الموارد البشرية...');
23859:         try {
23860:             await _loadEmployees();
23861:         } catch (error) {
23862:             console.error('RW_HR.loadEmployees', error);
23863:             hideLoader();
23864:             safeHTML(container, '<div class="rw-card p-8 text-center"><div class="text-5xl mb-3">⚠️</div><h3 class="font-black text-xl">تعذر تحميل بيانات الموظفين</h3><p class="text-gray-500 mt-2">' + _esc(error.message || 'خطأ غير معروف') + '</p></div>');
23865:             return;
23866:         }
23867:         hideLoader();
23868: 
23869:         var activeEmployees = hrData.filter(function(emp) {
23870:             return !(emp.role === 'مالك' || emp.role === 'Owner');
23871:         });
23872: 
23873:         var html = '<div class="p-4 space-y-5">';
23874:         html += '<div class="grid grid-cols-1 md:grid-cols-4 gap-4">';
23875:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي الموظفين</div><div class="text-3xl font-black text-indigo-600 mt-2">' + activeEmployees.length + '</div></div>';
23876:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">الموظفون النشطون</div><div class="text-3xl font-black text-green-600 mt-2">' + activeEmployees.filter(function(e){return e.status==='Active';}).length + '</div></div>';
23877:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">إجمالي التعويضات الشهرية</div><div class="text-3xl font-black text-blue-600 mt-2">' + _fmtNum(activeEmployees.reduce(function(sum,e){return sum + Number(e.basic_salary||0)+Number(e.housing_allowance||0)+Number(e.transport_allowance||0)+Number(e.other_allowance||0)-Number(e.default_deduction||0);},0)) + '</div></div>';
23878:         html += '<div class="bg-white rounded-2xl border p-5"><div class="text-xs text-gray-500">ملفات موظفين بدون بطاقة</div><div class="text-3xl font-black text-amber-600 mt-2">' + activeEmployees.filter(function(e){return !e.profile_id;}).length + '</div></div>';
23879:         html += '</div>';
23880: 
23881:         html += '<div class="flex flex-col md:flex-row gap-3">';
23882:         html += '<input id="hr-search" class="flex-1 p-3 bg-white border rounded-xl" placeholder="بحث بالاسم أو البريد أو الرقم الوظيفي">';
23883:         html += '<button id="hr-refresh" class="px-5 py-3 bg-indigo-600 text-white rounded-xl font-bold">تحديث</button>';
23884:         html += '</div>';
23885: 
23886:         html += '<div id="hr-cards-container" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">';
23887:         html += activeEmployees.map(_employeeCard).join('');
23888:         html += '</div>';
23889:         html += '<div id="hr-empty" class="hidden text-center py-10 text-gray-500">لا توجد نتائج مطابقة.</div>';
23890:         html += '</div>';
23891:         safeHTML(container, html);
23892: 
23893:         var search = byId('hr-search');
23894:         if (search) {
23895:             search.addEventListener('input', function() {
23896:                 var q = search.value.trim().toLowerCase();
23897:                 var cards = byId('hr-cards-container').querySelectorAll('[data-hr-employee-id]');
23898:                 var visible = 0;
23899:                 for (var i = 0; i < cards.length; i++) {
23900:                     var empId = cards[i].getAttribute('data-hr-employee-id');
23901:                     var emp = hrData.filter(function(e){return e.id === empId;})[0];
23902:                     var hay = ((emp.name||'')+' '+(emp.email||'')+' '+(emp.employee_number||'')+' '+(emp.job_title||'')).toLowerCase();
23903:                     cards[i].style.display = !q || hay.indexOf(q) !== -1 ? '' : 'none';
23904:                     if (cards[i].style.display !== 'none') visible++;
23905:                 }
23906:                 byId('hr-empty').classList.toggle('hidden', visible !== 0);
23907:             });
23908:         }
23909:         var refresh = byId('hr-refresh');
23910:         if (refresh) refresh.addEventListener('click', function(){ render(); });
23911:         var cardNodes = container.querySelectorAll('[data-hr-employee-id]');
23912:         for (var c = 0; c < cardNodes.length; c++) {
23913:             cardNodes[c].addEventListener('click', function(){
23914:                 var id = this.getAttribute('data-hr-employee-id');
23915:                 _openModal(id);
23916:             });
23917:         }
23918:     }
23919: 
23920:     async function _loadDocuments(employeeId) {
23921:         var res = await supabase.from('employee_documents')
23922:             .select('id,document_type,storage_path,document_name,mime_type,expires_at,status,notes,created_at')
23923:             .eq('employee_id', employeeId)
23924:             .eq('company_id', _companyId())
23925:             .order('created_at', {ascending:false});
23926:         if (res.error) throw res.error;
23927:         return res.data || [];
23928:     }
23929: 
23930:     async function _loadAttendance(employeeId) {
23931:         var res = await supabase.from('employee_attendance')
23932:             .select('id,attendance_date,status,check_in,check_out,notes')
23933:             .eq('employee_id', employeeId)
23934:             .eq('company_id', _companyId())
23935:             .order('attendance_date',{ascending:false})
23936:             .limit(14);
23937:         if (res.error) throw res.error;
23938:         return res.data || [];
23939:     }
23940: 
23941:     async function _loadLeaves(employeeId) {
23942:         var res = await supabase.from('employee_leave_requests')
23943:             .select('id,leave_type,start_date,end_date,reason,status,requested_by,approved_by,approved_at,notes')
23944:             .eq('employee_id', employeeId)
23945:             .eq('company_id', _companyId())
23946:             .order('start_date',{ascending:false})
23947:             .limit(20);
23948:         if (res.error) throw res.error;
23949:         return res.data || [];
23950:     }
23951: 
23952:     async function _openModal(employeeId) {
23953:         var emp = hrData.filter(function(e){ return e.id === employeeId; })[0];
23954:         if (!emp) { showToast('الموظف غير موجود', 'error'); return; }
23955: 
23956:         showLoader('جاري تحميل ملف الموظف...');
23957:         try {
23958:             var docs = await _loadDocuments(employeeId);
23959:             var attendance = await _loadAttendance(employeeId);
23960:             var leaves = await _loadLeaves(employeeId);
23961:             hideLoader();
23962: 
23963:             var html = '<div class="text-right space-y-5" data-hr-modal="1">';
23964:             html += '<div class="bg-indigo-50 rounded-2xl p-5"><div class="flex justify-between gap-4"><div><h3 class="font-black text-xl">' + _esc(emp.name) + '</h3><p class="text-sm text-gray-500">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div><div class="text-left"><div class="text-xs text-gray-500">الرقم الوظيفي</div><div class="font-black">' + _esc(emp.employee_number || emp.employee_id || '-') + '</div></div></div></div>';
23965: 
23966:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">البيانات والوظيفة</h4><div class="grid grid-cols-2 gap-4 text-sm">';
23967:             html += '<div><span class="text-gray-500">البريد</span><div class="font-bold">' + _esc(emp.email) + '</div></div>';
23968:             html += '<div><span class="text-gray-500">الهاتف</span><div class="font-bold">' + _esc(emp.phone || '-') + '</div></div>';
23969:             html += '<div><span class="text-gray-500">القسم</span><div class="font-bold">' + _esc(emp.department || '-') + '</div></div>';
23970:             html += '<div><span class="text-gray-500">المسمى</span><div class="font-bold">' + _esc(emp.job_title || '-') + '</div></div>';
23971:             html += '<div><span class="text-gray-500">تاريخ الالتحاق</span><div class="font-bold">' + _esc(emp.hire_date || '-') + '</div></div>';
23972:             html += '<div><span class="text-gray-500">نوع التوظيف</span><div class="font-bold">' + _esc(emp.employment_type || '-') + '</div></div>';
23973:             html += '</div><div class="flex justify-end mt-4"><button id="hr-edit-profile" class="px-5 py-2 bg-indigo-600 text-white rounded-xl font-bold">تعديل الملف</button></div></div>';
23974: 
23975:             var totalComp = Number(emp.basic_salary||0)+Number(emp.housing_allowance||0)+Number(emp.transport_allowance||0)+Number(emp.other_allowance||0)-Number(emp.default_deduction||0);
23976:             html += '<div class="bg-white border rounded-2xl p-5"><h4 class="font-black mb-4">التعويضات المسجلة فعليًا</h4><div class="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">';
23977:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">أساسي</div><div class="font-black">'+_fmtNum(emp.basic_salary)+' EGP</div></div>';
23978:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">سكن</div><div class="font-black">'+_fmtNum(emp.housing_allowance)+' EGP</div></div>';
23979:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">نقل</div><div class="font-black">'+_fmtNum(emp.transport_allowance)+' EGP</div></div>';
23980:             html += '<div class="bg-gray-50 rounded-xl p-3"><div class="text-gray-500 text-xs">بدلات أخرى</div><div class="font-black">'+_fmtNum(emp.other_allowance)+' EGP</div></div>';
23981:             html += '<div class="bg-indigo-50 rounded-xl p-3"><div class="text-indigo-600 text-xs">الصافي المسجل</div><div class="font-black text-indigo-700">'+_fmtNum(totalComp)+' EGP</div></div>';
23982:             html += '</div></div>';
23983: 
23984:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الحضور والانصراف</h4><button id="hr-add-attendance" class="px-4 py-2 bg-emerald-600 text-white rounded-xl font-bold text-sm">تسجيل يوم</button></div>';
23985:             html += '<div class="overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-gray-500"><th class="p-2">التاريخ</th><th class="p-2">الحالة</th><th class="p-2">دخول</th><th class="p-2">خروج</th><th class="p-2">ملاحظات</th></tr></thead><tbody>';
23986:             html += attendance.map(function(a){return '<tr class="border-t"><td class="p-2">'+_esc(a.attendance_date)+'</td><td class="p-2 font-bold">'+_esc(a.status)+'</td><td class="p-2">'+_esc(a.check_in||'-')+'</td><td class="p-2">'+_esc(a.check_out||'-')+'</td><td class="p-2">'+_esc(a.notes||'-')+'</td></tr>';}).join('');
23987:             html += '</tbody></table></div></div>';
23988: 
23989:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">الإجازات</h4><button id="hr-add-leave" class="px-4 py-2 bg-amber-600 text-white rounded-xl font-bold text-sm">طلب إجازة</button></div>';
23990:             html += leaves.map(function(l){var actions=l.status==='pending' ? '<button data-leave-approve="'+_escAttr(l.id)+'" class="px-3 py-1 bg-green-100 text-green-700 rounded-lg text-xs font-bold">اعتماد</button> <button data-leave-reject="'+_escAttr(l.id)+'" class="px-3 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-bold">رفض</button>' : ''; return '<div class="border-t py-3"><div class="flex justify-between"><div><b>'+_esc(l.leave_type)+'</b> — '+_esc(l.start_date)+' إلى '+_esc(l.end_date)+'</div><span class="font-bold">'+_esc(l.status)+'</span></div><div class="text-xs text-gray-500 mt-1">'+_esc(l.reason||'-')+'</div><div class="mt-2">'+actions+'</div></div>';}).join('');
23991:             if (!leaves.length) html += '<div class="text-center py-4 text-gray-400">لا توجد طلبات إجازة</div>';
23992:             html += '</div>';
23993: 
23994:             html += '<div class="bg-white border rounded-2xl p-5"><div class="flex justify-between items-center mb-4"><h4 class="font-black">المستندات</h4><button id="hr-upload-doc" class="px-4 py-2 bg-blue-600 text-white rounded-xl font-bold text-sm">رفع مستند</button></div>';
23995:             html += '<div class="space-y-2">';
23996:             for (var d=0; d<docs.length; d++) {
23997:                 html += '<div class="flex items-center justify-between border rounded-xl p-3"><div><div class="font-bold">'+_esc(docs[d].document_name||docs[d].document_type)+'</div><div class="text-xs text-gray-500">'+_esc(docs[d].document_type)+' — '+_esc(docs[d].expires_at||'بدون انتهاء')+'</div></div><button data-doc-id="'+_escAttr(docs[d].id)+'" data-doc-path="'+_escAttr(docs[d].storage_path||'')+'" class="px-3 py-1 bg-gray-100 rounded-lg text-xs font-bold">فتح</button></div>';
23998:             }
23999:             if (!docs.length) html += '<div class="text-center py-4 text-gray-400">لا توجد مستندات</div>';
24000:             html += '</div></div>';
24001:             html += '</div>';
24002: 
24003:             Swal.fire({title:'ملف الموظف: '+_esc(emp.name),html:html,width:'980px',showCloseButton:true,showConfirmButton:false,didOpen:function(){
24004:                 var editBtn=byId('hr-edit-profile'); if(editBtn) editBtn.addEventListener('click',function(){_editProfile(emp);});
24005:                 var attBtn=byId('hr-add-attendance'); if(attBtn) attBtn.addEventListener('click',function(){_addAttendance(emp);});
24006:                 var leaveBtn=byId('hr-add-leave'); if(leaveBtn) leaveBtn.addEventListener('click',function(){_addLeave(emp);});
24007:                 var uploadBtn=byId('hr-upload-doc'); if(uploadBtn) uploadBtn.addEventListener('click',function(){_uploadDocument(emp);});
24008:                 var approveNodes=document.querySelectorAll('[data-leave-approve]'); for(var ai=0;ai<approveNodes.length;ai++) approveNodes[ai].addEventListener('click',function(){_setLeaveStatus(this.getAttribute('data-leave-approve'),'approved',emp);});
24009:                 var rejectNodes=document.querySelectorAll('[data-leave-reject]'); for(var ri=0;ri<rejectNodes.length;ri++) rejectNodes[ri].addEventListener('click',function(){_setLeaveStatus(this.getAttribute('data-leave-reject'),'rejected',emp);});
24010:                 var docNodes=document.querySelectorAll('[data-doc-path]'); for(var di=0;di<docNodes.length;di++) docNodes[di].addEventListener('click',function(){_openDocument(this.getAttribute('data-doc-path'));});
24011:             }});
24012:         } catch(error) {
24013:             hideLoader();
24014:             showToast('تعذر تحميل ملف الموظف: '+(error.message||'خطأ غير معروف'),'error');
24015:         }
24016:     }
24017: 
24018:     async function _editProfile(emp) {
24019:         var html='<div class="text-right space-y-3">'+
24020:             '<input id="hr-p-number" class="w-full p-2 border rounded" placeholder="الرقم الوظيفي" value="'+_escAttr(emp.employee_number||emp.employee_id||'')+'">'+
24021:             '<input id="hr-p-department" class="w-full p-2 border rounded" placeholder="القسم" value="'+_escAttr(emp.department||'')+'">'+
24022:             '<input id="hr-p-title" class="w-full p-2 border rounded" placeholder="المسمى الوظيفي" value="'+_escAttr(emp.job_title||emp.role||'')+'">'+
24023:             '<input id="hr-p-hire-date" type="date" class="w-full p-2 border rounded" value="'+_escAttr(emp.hire_date||'')+'">'+
24024:             '<input id="hr-p-type" class="w-full p-2 border rounded" placeholder="نوع التوظيف" value="'+_escAttr(emp.employment_type||'')+'">'+
24025:             '<div class="grid grid-cols-2 gap-2"><input id="hr-p-basic" type="number" min="0" class="p-2 border rounded" placeholder="الأساسي" value="'+Number(emp.basic_salary||0)+'"><input id="hr-p-housing" type="number" min="0" class="p-2 border rounded" placeholder="بدل السكن" value="'+Number(emp.housing_allowance||0)+'"><input id="hr-p-transport" type="number" min="0" class="p-2 border rounded" placeholder="بدل النقل" value="'+Number(emp.transport_allowance||0)+'"><input id="hr-p-other" type="number" min="0" class="p-2 border rounded" placeholder="بدلات أخرى" value="'+Number(emp.other_allowance||0)+'"><input id="hr-p-deduct" type="number" min="0" class="p-2 border rounded" placeholder="خصم ثابت" value="'+Number(emp.default_deduction||0)+'"></div>'+
24026:             '<textarea id="hr-p-notes" class="w-full p-2 border rounded" placeholder="ملاحظات">'+_esc(emp.profile_notes||'')+'</textarea></div>';
24027:         Swal.fire({title:'تعديل ملف الموظف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_upsert_employee_profile',{p_employee_id:emp.id,p_employee_number:byId('hr-p-number').value.trim()||null,p_department:byId('hr-p-department').value.trim()||null,p_job_title:byId('hr-p-title').value.trim()||null,p_hire_date:byId('hr-p-hire-date').value||null,p_employment_type:byId('hr-p-type').value.trim()||null,p_basic_salary:Number(byId('hr-p-basic').value||0),p_housing_allowance:Number(byId('hr-p-housing').value||0),p_transport_allowance:Number(byId('hr-p-transport').value||0),p_other_allowance:Number(byId('hr-p-other').value||0),p_default_deduction:Number(byId('hr-p-deduct').value||0),p_status:(emp.profile_status||'active'),p_notes:byId('hr-p-notes').value.trim()||null}).then(function(res){if(res.error) throw res.error; return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ ملف الموظف','success');Swal.close();render();}}).catch(function(e){showToast('فشل حفظ الملف: '+(e.message||'خطأ غير معروف'),'error');});
24028:     }
24029: 
24030:     async function _addAttendance(emp) {
24031:         var html='<div class="text-right space-y-3"><input id="hr-att-date" type="date" class="w-full p-2 border rounded" value="'+new Date().toISOString().slice(0,10)+'"><select id="hr-att-status" class="w-full p-2 border rounded"><option value="present">حاضر</option><option value="late">متأخر</option><option value="absent">غائب</option><option value="leave">إجازة</option><option value="holiday">عطلة</option></select><input id="hr-att-in" type="datetime-local" class="w-full p-2 border rounded"><input id="hr-att-out" type="datetime-local" class="w-full p-2 border rounded"><textarea id="hr-att-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24032:         Swal.fire({title:'تسجيل حضور/انصراف',html:html,showCancelButton:true,confirmButtonText:'حفظ',cancelButtonText:'إلغاء',preConfirm:function(){var toISO=function(id){var v=byId(id).value;return v?new Date(v).toISOString():null;};return supabase.rpc('hr_save_attendance',{p_employee_id:emp.id,p_attendance_date:byId('hr-att-date').value,p_status:byId('hr-att-status').value,p_check_in:toISO('hr-att-in'),p_check_out:toISO('hr-att-out'),p_notes:byId('hr-att-notes').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم حفظ الحضور','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل حفظ الحضور: '+(e.message||'خطأ غير معروف'),'error');});
24033:     }
24034: 
24035:     async function _addLeave(emp) {
24036:         var html='<div class="text-right space-y-3"><input id="hr-leave-type" class="w-full p-2 border rounded" placeholder="نوع الإجازة"><div class="grid grid-cols-2 gap-2"><input id="hr-leave-start" type="date" class="p-2 border rounded"><input id="hr-leave-end" type="date" class="p-2 border rounded"></div><textarea id="hr-leave-reason" class="w-full p-2 border rounded" placeholder="السبب"></textarea></div>';
24037:         Swal.fire({title:'طلب إجازة',html:html,showCancelButton:true,confirmButtonText:'إرسال',cancelButtonText:'إلغاء',preConfirm:function(){return supabase.rpc('hr_create_leave_request',{p_employee_id:emp.id,p_leave_type:byId('hr-leave-type').value.trim(),p_start_date:byId('hr-leave-start').value,p_end_date:byId('hr-leave-end').value,p_reason:byId('hr-leave-reason').value.trim()||null}).then(function(res){if(res.error)throw res.error;return res.data;});}}).then(function(res){if(res.isConfirmed){showToast('تم إنشاء طلب الإجازة','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل إنشاء الإجازة: '+(e.message||'خطأ غير معروف'),'error');});
24038:     }
24039: 
24040:     async function _setLeaveStatus(id,status,emp) {
24041:         var res=await supabase.rpc('hr_set_leave_status',{
24042:             p_leave_request_id:id,
24043:             p_status:status,
24044:             p_notes:null
24045:         });
24046:         if(res.error){showToast('فشل تحديث الإجازة: '+res.error.message,'error');return;}
24047:         showToast(status==='approved'?'تم اعتماد الإجازة':'تم رفض الإجازة','success');
24048:         _openModal(emp.id);
24049:     }
24050:     async function _uploadDocument(emp) {
24051:         var html='<div class="text-right space-y-3"><select id="hr-doc-type" class="w-full p-2 border rounded"><option value="identity">صورة الهوية</option><option value="contract">عقد العمل</option><option value="other">مستند آخر</option></select><input id="hr-doc-expiry" type="date" class="w-full p-2 border rounded"><input id="hr-doc-file" type="file" class="w-full p-2 border rounded"><textarea id="hr-doc-notes" class="w-full p-2 border rounded" placeholder="ملاحظات"></textarea></div>';
24052:         Swal.fire({title:'رفع مستند الموظف',html:html,showCancelButton:true,confirmButtonText:'رفع',cancelButtonText:'إلغاء',preConfirm:async function(){var file=byId('hr-doc-file').files[0];if(!file)throw new Error('اختر ملفًا أولاً');var company=_companyId();var safeName=file.name.replace(/[^a-zA-Z0-9._-]+/g,'_');var path=company+'/'+emp.id+'/'+Date.now()+'_'+safeName;var up=await supabase.storage.from('employee-documents').upload(path,file,{upsert:false,contentType:file.type||'application/octet-stream'});if(up.error)throw up.error;var ins=await supabase.from('employee_documents').insert({company_id:company,employee_id:emp.id,document_type:byId('hr-doc-type').value,storage_path:path,document_name:file.name,mime_type:file.type||null,expires_at:byId('hr-doc-expiry').value||null,status:'active',notes:byId('hr-doc-notes').value.trim()||null,created_by:(RW_STATE&&RW_STATE.app&&RW_STATE.app.currentUser&&RW_STATE.app.currentUser.email)||''});if(ins.error){await supabase.storage.from('employee-documents').remove([path]);throw ins.error;}return true;}}).then(function(res){if(res.isConfirmed){showToast('تم رفع المستند','success');Swal.close();_openModal(emp.id);}}).catch(function(e){showToast('فشل رفع المستند: '+(e.message||'خطأ غير معروف'),'error');});
24053:     }
24054: 
24055:     async function _openDocument(path) {
24056:         if (!path) { showToast('مسار المستند غير موجود','error'); return; }
24057:         var res=await supabase.storage.from('employee-documents').createSignedUrl(path,300);
24058:         if(res.error){showToast('تعذر فتح المستند: '+res.error.message,'error');return;}
24059:         window.open(res.data.signedUrl,'_blank','noopener');
24060:     }
24061: 
24062:     return { render: render, _openModal: _openModal };
24063: })();
24064: window.RW_HR = RW_HR;
