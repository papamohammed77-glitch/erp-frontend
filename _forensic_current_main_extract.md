# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=23315
FILE_BYTES=1288078
SHA256=8358f2f1f267f91b27b0745a6a2f4530366dab712272f74d6cad64e8df8d02a1
PATTERN var RW_Warehouse: [10950]
PATTERN loadInventoryControl: [13235, 13812, 21513]
PATTERN loadReceiving: [10954, 13813, 21539]
PATTERN loadVouchers: [11123, 11444, 11452, 11574, 11639, 13816, 21540]
PATTERN loadVoucherForm: [11104, 11679, 13822, 21541, 21542, 21543, 21544]
PATTERN loadPicking: [11683, 13831, 21530]
PATTERN loadLoading: [11735, 13834, 21531]
PATTERN loadDelivery: [11824, 13837, 21532]
PATTERN loadReturn: [11873, 13840, 21533]
PATTERN loadUnloading: [11922, 13843, 21538]
PATTERN loadVehicleCount: [12084, 13846, 21545]
PATTERN loadBranchCount: [12468, 13847, 21546]
PATTERN loadGeneralCount: [12499, 13848, 21547]
PATTERN inventory-stock-snapshot: []
PATTERN inventory_stock_snapshot: []
PATTERN inventory_movement_report: []
PATTERN inventory_replenishment_report: []
PATTERN inventory_count_engine: []
PATTERN receive-purchase: [8972]
PATTERN complete-return: [13173]
PATTERN complete-order-delivery: [13079]
PATTERN Idempotency-Key: [8845, 8972, 9095, 11411, 11429, 11634, 12714, 12840]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 13205-13335 around 13235 ---
13205:             if (json.success) {
13206:                 showToast('تم التفريغ بنجاح', 'success');
13207:                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13208:             } else {
13209:                 showToast(json.msg || 'فشل التفريغ', 'error');
13210:             }
13211:         }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13212:     });
13213: }
13214: function _changeStatus(code, funcName) {
13215:     showLoader('جاري تحديث الحالة...');
13216:     supabase.auth.getSession().then(function(ses) {
13217:         var t = ses.data.session ? ses.data.session.access_token : null;
13218:         return fetch(SUPABASE_URL + '/functions/v1/' + funcName, {
13219:             method: 'POST',
13220:             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13221:             body: JSON.stringify({ runsheet_code: code })
13222:         });
13223:     }).then(function(res) { return res.json(); }).then(function(json) {
13224:         hideLoader();
13225:         if (json.success) {
13226:             showToast('تم بنجاح', 'success');
13227:         } else {
13228:             showToast(json.msg || 'فشل', 'error');
13229:         }
13230:     }).catch(function(e) {
13231:         hideLoader();
13232:         showToast('فشل الاتصال', 'error');
13233:     });
13234: }
13235:     async function loadInventoryControl() {
13236:         var c = byId('rw-page-container');
13237:         if (!c) return;
13238: 
13239:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) ||
13240:             (typeof _rwCompanyId === 'function' ? _rwCompanyId() : null);
13241:         if (!companyId) {
13242:             showToast('سياق الشركة غير محدد', 'error');
13243:             return;
13244:         }
13245: 
13246:         var state = {
13247:             tab: 'snapshot',
13248:             branchId: '',
13249:             query: '',
13250:             lowOnly: false,
13251:             movementType: '',
13252:             fromDate: '',
13253:             toDate: '',
13254:             snapshot: [],
13255:             movements: [],
13256:             replenishment: [],
13257:             counts: [],
13258:             requests: [],
13259:             branches: [],
13260:             busy: false
13261:         };
13262: 
13263:         function escIC(v) {
13264:             return String(v == null ? '' : v)
13265:                 .replace(/&/g, '&amp;')
13266:                 .replace(/</g, '&lt;')
13267:                 .replace(/>/g, '&gt;')
13268:                 .replace(/"/g, '&quot;')
13269:                 .replace(/'/g, '&#39;');
13270:         }
13271: 
13272:         function fmtIC(v) {
13273:             return Number(v || 0).toLocaleString('ar-EG');
13274:         }
13275: 
13276:         async function callIC(operation, payload) {
13277:             var res = await supabase.rpc('inventory_control', {
13278:                 p_operation: operation,
13279:                 p_payload: payload || {}
13280:             });
13281:             if (res.error) throw res.error;
13282:             var data = res.data;
13283:             if (data && data.success === false) {
13284:                 throw new Error(data.msg || 'فشل تنفيذ العملية');
13285:             }
13286:             return data || { success: true };
13287:         }
13288: 
13289:         function branchOptions(selected) {
13290:             var h = '<option value="">كل المخازن والفروع</option>';
13291:             for (var i = 0; i < state.branches.length; i++) {
13292:                 var b = state.branches[i];
13293:                 h += '<option value="' + escIC(b.id) + '"' +
13294:                     (String(selected || '') === String(b.id) ? ' selected' : '') + '>' +
13295:                     escIC(b.name || b.branch_code) + '</option>';
13296:             }
13297:             return h;
13298:         }
13299: 
13300:         function renderShell() {
13301:             safeText(byId('rw-header-title'), 'مركز التحكم في المخزون');
13302:             safeHTML(c,
13303:                 '<div class="p-4 space-y-4">' +
13304:                 '<div class="bg-white rounded-2xl shadow-sm border p-4">' +
13305:                     '<div class="flex flex-wrap items-center justify-between gap-3 mb-4">' +
13306:                         '<div>' +
13307:                             '<div class="text-xl font-black text-slate-800">مركز التحكم في المخزون</div>' +
13308:                             '<div class="text-sm text-slate-500 mt-1">لوحة رقابة مركزية فوق رصيد المخزون والحركة والاحتياجات والجرد وطلبات المخزون</div>' +
13309:                         '</div>' +
13310:                         '<div class="flex gap-2">' +
13311:                             '<button id="ic-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث البيانات</button>' +
13312:                             '<button id="ic-new-count" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">جلسة جرد جديدة</button>' +
13313:                         '</div>' +
13314:                     '</div>' +
13315:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13316:                         '<div class="rounded-2xl bg-blue-50 border border-blue-100 p-4"><div class="text-xs text-blue-700 font-bold">بنود المخزون المعروضة</div><div id="ic-kpi-lines" class="text-2xl font-black text-blue-900 mt-1">0</div></div>' +
13317:                         '<div class="rounded-2xl bg-amber-50 border border-amber-100 p-4"><div class="text-xs text-amber-700 font-bold">بنود منخفضة</div><div id="ic-kpi-low" class="text-2xl font-black text-amber-900 mt-1">0</div></div>' +
13318:                         '<div class="rounded-2xl bg-emerald-50 border border-emerald-100 p-4"><div class="text-xs text-emerald-700 font-bold">بنود تحتاج إعادة طلب</div><div id="ic-kpi-repl" class="text-2xl font-black text-emerald-900 mt-1">0</div></div>' +
13319:                         '<div class="rounded-2xl bg-purple-50 border border-purple-100 p-4"><div class="text-xs text-purple-700 font-bold">جلسات الجرد النشطة</div><div id="ic-kpi-counts" class="text-2xl font-black text-purple-900 mt-1">0</div></div>' +
13320:                     '</div>' +
13321:                 '</div>' +
13322:                 '<div class="bg-white rounded-2xl shadow-sm border p-3">' +
13323:                     '<div class="flex flex-wrap gap-2">' +
13324:                         '<button data-ic-tab="snapshot" class="ic-tab px-4 py-2 rounded-xl font-bold bg-blue-600 text-white">الرصيد</button>' +
13325:                         '<button data-ic-tab="movements" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الحركات</button>' +
13326:                         '<button data-ic-tab="replenishment" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">إعادة الطلب</button>' +
13327:                         '<button data-ic-tab="counts" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الجرد</button>' +
13328:                         '<button data-ic-tab="requests" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">طلبات المخزون</button>' +
13329:                     '</div>' +
13330:                 '</div>' +
13331:                 '<div id="ic-filters" class="bg-white rounded-2xl shadow-sm border p-4"></div>' +
13332:                 '<div id="ic-content" class="bg-white rounded-2xl shadow-sm border overflow-auto"></div>' +
13333:                 '</div>'
13334:             );
13335: 
--- WINDOW 13782-13912 around 13812 ---
13782: 
13783:         var branchRes = await supabase.from('branches')
13784:             .select('id,branch_code,name')
13785:             .eq('company_id', companyId)
13786:             .eq('is_active', true)
13787:             .order('name');
13788:         if (branchRes.error) {
13789:             showToast(branchRes.error.message, 'error');
13790:             return;
13791:         }
13792:         state.branches = branchRes.data || [];
13793: 
13794:         renderShell();
13795:         renderTabButtons();
13796:         renderFilters();
13797:         await refreshAll();
13798: 
13799:         try {
13800:             if (window._rwInventoryControlChannel) {
13801:                 await supabase.removeChannel(window._rwInventoryControlChannel);
13802:             }
13803:             var channel = supabase.channel('rw-inventory-control-' + companyId);
13804:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
13805:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
13806:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
13807:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
13808:             window._rwInventoryControlChannel = channel.subscribe();
13809:         } catch (e) {}
13810:     }
13811:     return {
13812: 			loadInventoryControl: loadInventoryControl,
13813:             loadReceiving: loadReceiving,
13814:     _applyReceiving: _applyReceiving,
13815:     _showReceivingDetails: _showReceivingDetails,
13816:     loadVouchers: loadVouchers,
13817:     _applyVouchers: _applyVouchers,
13818:     _viewVoucherDetails: _viewVoucherDetails,
13819:     _sendVoucher: _sendVoucher,
13820:     _receiveVoucher: _receiveVoucher,
13821:     _openNewVoucherModal: _openNewVoucherModal,
13822:     loadVoucherForm: loadVoucherForm,
13823:     _searchVoucherItem: _searchVoucherItem,
13824:     _addVoucherItem: _addVoucherItem,
13825:     _renderVoucherCart: _renderVoucherCart,
13826:     _updateVoucherQty: _updateVoucherQty,
13827:     _updateVoucherPrice: _updateVoucherPrice,
13828:     _removeVoucherItem: _removeVoucherItem,
13829:     _clearVoucherCart: _clearVoucherCart,
13830:     _saveAndSendVoucher: _saveAndSendVoucher,
13831:     loadPicking: loadPicking,
13832:     _applyPicking: _applyPicking,
13833:     _showPickingDetails: _showPickingDetails,
13834:     loadLoading: loadLoading,
13835:     _applyLoading: _applyLoading,
13836:     _showLoadingDetails: _showLoadingDetails,
13837:     loadDelivery: loadDelivery,
13838:     _applyDelivery: _applyDelivery,
13839:     _showDeliveryDetails: _showDeliveryDetails,
13840:     loadReturn: loadReturn,
13841:     _applyReturn: _applyReturn,
13842:     _showReturnDetails: _showReturnDetails,
13843:     loadUnloading: loadUnloading,
13844:     _applyUnloading: _applyUnloading,
13845:     _showUnloadingDetails: _showUnloadingDetails,
13846:     loadVehicleCount: loadVehicleCount,
13847:     loadBranchCount: loadBranchCount,
13848:     loadGeneralCount: loadGeneralCount,
13849:     loadSettlement: loadSettlement,
13850:     _searchDriver: _searchDriver,
13851:     _selectDriver: _selectDriver,
13852:     _startBarcodeScanner: _startBarcodeScanner,
13853:     _searchInvItem: _searchInvItem,
13854:     _addToInvCart: _addToInvCart,
13855:     _renderInvCart: _renderInvCart,
13856:     _updateInvCartQty: _updateInvCartQty,
13857:     _removeInvCartItem: _removeInvCartItem,
13858:     _saveVehicleCount: _saveVehicleCount,
13859:     _saveBranchCount: _saveBranchCount,
13860:     _saveGeneralCount: _saveGeneralCount,
13861:     _saveInvCount: _saveInvCount,
13862:     _onSettlementRsChange: _onSettlementRsChange,
13863:     _saveSettlement: _saveSettlement,
13864:     _openPickingModal: _openPickingModal,
13865:     _openLoadingModal: _openLoadingModal,
13866:     _openDeliveryModal: _openDeliveryModal,
13867:     _openReturnModal: _openReturnModal,
13868:     _startPicking: _changeStatus,
13869:     _startLoading: _changeStatus,
13870:     _startDelivery: _changeStatus,
13871:     _startReturn: _changeStatus,
13872:     _confirmUnload: _confirmUnload,
13873:     _changeStatus: _changeStatus
13874:     };
13875: })();
13876: window.RW_Warehouse = RW_Warehouse;
13877: // ============================================================
13878: // RW_Finance – الحسابات والمالية (وحدة كاملة - Supabase مباشر)
13879: // ============================================================
13880: var RW_Finance = (function() {
13881:     function _showLoader(m) { try { if (typeof showLoader === 'function') showLoader(m || 'جاري التحميل...'); } catch(e) { console.error(e); } }
13882:     function _hideLoader() { try { if (typeof hideLoader === 'function') hideLoader(); } catch(e) { console.error(e); } }
13883:     function _showToast(m, t) { try { if (typeof showToast === 'function') showToast(m, t || 'success'); } catch(e) { alert(m); } }
13884:     function _fmtNum(n) { return parseFloat(n || 0).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
13885:     function _esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
13886: 
13887:     function _companyId() {
13888:         var id = null;
13889:         if (typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.app) {
13890:             id = RW_STATE.app.companyId || null;
13891:         }
13892:         if (!id && typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.user) {
13893:             id = RW_STATE.user.companyId || null;
13894:         }
13895:         if (!id) throw new Error('سياق الشركة غير محدد');
13896:         return id;
13897:     }
13898:     var _cache = { loaded: false, accountsTree: [], accountsFlat: [], treasury: [] };
13899: 
13900:     function _loadAllData(callback) {
13901:         if (_cache.loaded) { if (callback) callback(); return; }
13902:         var companyId;
13903:         try {
13904:             companyId = _companyId();
13905:         } catch (e) {
13906:             _showToast(e.message || 'سياق الشركة غير محدد', 'error');
13907:             if (callback) callback();
13908:             return;
13909:         }
13910: 
13911:         _showLoader('جاري تحميل البيانات المالية...');
13912:         Promise.all([
--- WINDOW 21483-21613 around 21513 ---
21483:             'receiving':'الاستلام',
21484:             'picking':'التحضير',
21485:             'loading':'التحميل',
21486:             'delivery':'التوصيل',
21487:             'return':'المرتجعات',
21488: 			'sales-returns':'إدارة مرتجعات المبيعات',
21489:             'unloading':'التفريغ',
21490:             'vouchers':'الأذونات المخزنية',
21491:             'transfer':'تحويل مخزني',
21492:             'direct-sale':'صرف سيارة بيع مباشر',
21493:             'direct-return':'استلام مرتجع سيارة',
21494:             'supplier-return':'مرتجع لمورد',
21495:             'vehicle-count':'جرد سيارة',
21496:             'branch-count':'جرد فرع',
21497:             'general-count':'جرد عام',
21498:             'finance':'الإدارة المالية',
21499:             'reports-dashboard':'لوحة القيادة',
21500:             'reports-detailed':'التقارير التفصيلية',
21501:             'reports-comprehensive':'التقارير الشاملة',
21502:             'audit-log':'سجل التدقيق',
21503:             'hr':'الموارد البشرية',
21504:             'crm':'إدارة علاقات العملاء'
21505:         };
21506:         safeText(byId('rw-header-title'), titles[view] || view);
21507: 
21508:         if (view === 'dashboard') { RW_Dashboard.render(); return; }
21509:         if (view === 'items') { RW_Items.render(); return; }
21510:         if (view === 'customers') { RW_Customers.render(); return; }
21511:         if (view === 'suppliers') { RW_Suppliers.render(); return; }
21512:         if (view === 'branches') { RW_Branches.render(); return; }
21513: 		if (view === 'inventory-control') { RW_Warehouse.loadInventoryControl(); return; }
21514:         if (view === 'settings') { RW_Settings.render(); return; }
21515:         if (view === 'hr') { RW_HR.render(); return; }
21516:         if (view === 'crm') { RW_CRM.render(); return; }
21517:         if (view === 'users') { RW_Users.render(); return; }
21518:         if (view === 'roles') { RW_Roles.render(); return; }
21519:         if (view === 'license') { RW_OwnerLicense.render(); return; }
21520:         if (view === 'telesales') { RW_TeleSales.render(); return; }
21521:         if (view === 'pos') { RW_POS.render(); return; }
21522:         if (view === 'orders') { RW_Orders.render(); return; }
21523: 		if (view === 'quotes') { RW_SalesQuotes.render(); return; }
21524: 		if (view === 'price-lists') { RW_PriceLists.render(); return; }
21525: 		if (view === 'promotions') { RW_Promotions.render(); return; }
21526:         if (view === 'runsheets') { RW_Runsheets.render(); return; }
21527:         if (view === 'online-store') { RW_OnlineStore.render(); return; }
21528:         if (view === 'purchases') { RW_Purchases.renderOrders(); return; }
21529:         if (view === 'purchase-pos') { RW_Purchases.renderPOS(); return; }
21530:         if (view === 'picking') { RW_Warehouse.loadPicking(); return; }
21531:         if (view === 'loading') { RW_Warehouse.loadLoading(); return; }
21532:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
21533:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
21534: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
21535: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
21536: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
21537: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
21538:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
21539:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
21540:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
21541:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
21542:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
21543:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
21544:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
21545:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
21546:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
21547:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
21548:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
21549:         if (view === 'finance') { RW_Finance.render(); return; }
21550:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
21551:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
21552:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
21553:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
21554: 
21555:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
21556:     }
21557: };
21558: window.RW_Views = RW_Views;
21559: // ============================================================
21560: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
21561: // ============================================================
21562: var RW_HR = (function() {
21563:     'use strict';
21564: 
21565:     var hrData = [];
21566: 
21567:     function _esc(s) {
21568:         return String(s == null ? '' : s)
21569:             .replace(/&/g, '&amp;')
21570:             .replace(/</g, '&lt;')
21571:             .replace(/>/g, '&gt;');
21572:     }
21573: 
21574:     function _escAttr(s) {
21575:         return _esc(s)
21576:             .replace(/\"/g, '&quot;')
21577:             .replace(/'/g, '&#39;');
21578:     }
21579: 
21580:     function _fmtNum(n) {
21581:         return Number(n || 0).toLocaleString('ar-EG');
21582:     }
21583: 
21584:     function _companyId() {
21585:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
21586:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
21587:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
21588:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
21589:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
21590:         }
21591:         return null;
21592:     }
21593: 
21594:     async function _loadEmployees() {
21595:         var res = await supabase.rpc('hr_list_employees');
21596:         if (res.error) throw res.error;
21597:         hrData = res.data || [];
21598:         return hrData;
21599:     }
21600: 
21601:     function _employeeCard(emp) {
21602:         var profileSalary = Number(emp.basic_salary || 0) +
21603:             Number(emp.housing_allowance || 0) +
21604:             Number(emp.transport_allowance || 0) +
21605:             Number(emp.other_allowance || 0) -
21606:             Number(emp.default_deduction || 0);
21607:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
21608:             '<div class="flex items-center gap-4 mb-4">' +
21609:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
21610:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
21611:             '</div>' +
21612:             '<div class="space-y-2 text-sm">' +
21613:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
--- WINDOW 8942-9072 around 8972 ---
8942:       var poRes = await supabase.from('purchase_orders').select('*').eq('company_id', companyId).eq('po_code', poCode).maybeSingle();
8943:       if (poRes.error || !poRes.data) throw new Error('أمر الشراء غير موجود');
8944:       var dRes = await supabase.from('purchase_order_details').select('*').eq('po_id', poRes.data.id).order('created_at', { ascending: true });
8945:       if (dRes.error) throw dRes.error;
8946:       var rows = dRes.data || [], h = '<div class="text-right"><div class="grid grid-cols-2 gap-3 mb-4"><div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-gray-500">المورد</div><div class="font-bold">' + esc(poRes.data.supplier_name) + '</div></div><div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-gray-500">الحالة</div><div class="font-bold">' + esc(poRes.data.status) + '</div></div></div><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">المطلوب</th><th class="p-2 text-center">المستلم</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">السعر</th></tr></thead><tbody>';
8947:       for (var i = 0; i < rows.length; i++) { var r = rows[i], ordered = Number(r.qty_ordered) || 0, received = Number(r.qty_received) || 0; h += '<tr class="border-b"><td class="p-2 font-semibold">' + esc(r.item_name || r.item_code) + '</td><td class="p-2 text-center">' + ordered + '</td><td class="p-2 text-center">' + received + '</td><td class="p-2 text-center font-bold">' + Math.max(0, ordered - received) + '</td><td class="p-2 text-center">' + (Number(r.unit_price) || 0).toLocaleString() + '</td></tr>'; }
8948:       h += '</tbody></table><div class="mt-4 font-black text-lg">الإجمالي: ' + (Number(poRes.data.total_amount) || 0).toLocaleString() + ' EGP</div></div>';
8949:       hideLoader(); Swal.fire({ title: 'تفاصيل ' + esc(poCode), html: h, width: '820px', showConfirmButton: false, showCloseButton: true });
8950:     } catch (e) { hideLoader(); showToast(e.message || 'فشل تحميل التفاصيل', 'error'); }
8951:   }
8952: 
8953:   async function openReceive(poCode) {
8954:     showLoader('جاري جلب تفاصيل الاستلام...');
8955:     try {
8956:       var companyId = companyIdOrFail();
8957:       var poRes = await supabase.from('purchase_orders').select('*').eq('company_id', companyId).eq('po_code', poCode).maybeSingle();
8958:       if (poRes.error || !poRes.data) throw new Error('أمر الشراء غير موجود');
8959:       var itemsRes = await supabase.from('purchase_order_details').select('*').eq('po_id', poRes.data.id).order('created_at', { ascending: true });
8960:       if (itemsRes.error) throw itemsRes.error;
8961:       hideLoader();
8962:       var items = itemsRes.data || [], html = '<div class="text-right"><div class="mb-3 text-sm text-gray-500">يمكن استلام الكمية المتبقية فقط. إعادة المحاولة تستخدم نفس هوية العملية إذا بقيت النافذة مفتوحة.</div><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">المطلوب</th><th class="p-2 text-center">المستلم</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">الاستلام الآن</th><th class="p-2">سبب/ملاحظة</th></tr></thead><tbody>';
8963:       for (var i = 0; i < items.length; i++) { var it = items[i], ordered = Number(it.qty_ordered) || 0, received = Number(it.qty_received) || 0, remaining = Math.max(0, ordered - received); html += '<tr class="border-b"><td class="p-2 font-semibold">' + esc(it.item_name || it.item_code) + '<div class="text-xs text-gray-400">' + esc(it.item_code) + '</div></td><td class="p-2 text-center">' + ordered + '</td><td class="p-2 text-center">' + received + '</td><td class="p-2 text-center font-bold">' + remaining + '</td><td class="p-2 text-center"><input type="number" id="rec-qty-' + i + '" value="' + remaining + '" max="' + remaining + '" min="0" step="0.01" class="w-24 p-1 border rounded text-center"></td><td class="p-2"><input type="text" id="rec-note-' + i + '" class="w-36 p-1 border rounded" placeholder="اختياري"></td></tr>'; }
8964:       html += '</tbody></table></div>';
8965:       Swal.fire({ title: 'استلام بضاعة: ' + esc(poCode), html: html, width: '1000px', showCancelButton: true, confirmButtonText: 'اعتماد الاستلام', confirmButtonColor: '#10b981', cancelButtonText: 'إلغاء', preConfirm: function() { var received = [], hasQty = false; for (var i = 0; i < items.length; i++) { var q = Number(document.getElementById('rec-qty-' + i).value) || 0, remaining = Math.max(0, (Number(items[i].qty_ordered) || 0) - (Number(items[i].qty_received) || 0)); if (q < 0 || q > remaining) { Swal.showValidationMessage('الكمية غير صالحة للصنف: ' + (items[i].item_code || '')); return false; } if (q > 0) { hasQty = true; received.push({ itemCode: items[i].item_code, itemName: items[i].item_name, unit: items[i].unit, receivedQty: q, reason: (document.getElementById('rec-note-' + i).value || '').trim() }); } } if (!hasQty) { Swal.showValidationMessage('أدخل كمية استلام واحدة على الأقل'); return false; } return received; } }).then(async function(r) {
8966:         if (!r.isConfirmed || !r.value || !r.value.length) return;
8967:         showLoader('جاري حفظ الاستلام...');
8968:         try {
8969:           var ses = await supabase.auth.getSession(), token = ses && ses.data && ses.data.session ? ses.data.session.access_token : null;
8970:           if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
8971:           var receiveOperationId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now()) + '-' + Math.random();
8972:           var res = await fetch(SUPABASE_URL + '/functions/v1/receive-purchase', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Idempotency-Key': receiveOperationId }, body: JSON.stringify({ po_code: poCode, itemsReceived: r.value, operation_id: receiveOperationId }) });
8973:           var json = await res.json();
8974:           if (!res.ok || !json || !json.success) throw new Error((json && json.msg) || 'فشل الاستلام');
8975:           hideLoader(); showToast(json.duplicate ? 'تم استرجاع نتيجة الاستلام السابق' : 'تم الاستلام بنجاح', 'success'); await renderOrders();
8976:         } catch (e) { hideLoader(); showToast(e.message || 'فشل الاتصال', 'error'); }
8977:       });
8978:     } catch (e) { hideLoader(); showToast(e.message || 'فشل تحميل الاستلام', 'error'); }
8979:   }
8980: 
8981:   async function renderPOS() {
8982:     var c = byId('rw-page-container'); if (!c) return;
8983:     safeText(byId('rw-header-title'), 'نقطة شراء');
8984:     if (!RW_STATE.data.items || !RW_STATE.data.items.length) { showLoader('جاري تحميل الأصناف...'); try { await RW_Data.loadItems(); } finally { hideLoader(); } }
8985:     if (!RW_STATE.data.suppliers || !RW_STATE.data.suppliers.length) {
8986:       var companyId = companyIdOrFail(), sRes = await supabase.from('suppliers').select('*').eq('company_id', companyId).eq('is_active', true).order('name', { ascending: true });
8987:       if (sRes.error) { showToast('تعذر تحميل الموردين', 'error'); RW_STATE.data.suppliers = []; } else RW_STATE.data.suppliers = sRes.data || [];
8988:     }
8989:     safeHTML(c, '<div class="grid grid-cols-1 lg:grid-cols-4 gap-6 p-4"><div class="lg:col-span-1 space-y-4"><div class="bg-white p-4 rounded-xl shadow-sm"><label class="text-sm font-bold">اختيار المورد</label><select id="po-supplier" class="w-full p-2.5 bg-gray-50 border rounded-lg"></select></div><div class="bg-white p-4 rounded-xl shadow-sm"><label class="text-sm font-bold">البحث عن صنف بالاسم أو الكود أو الباركود</label><input type="text" id="po-search" oninput="RW_Purchases._searchItem(this.value)" placeholder="ابحث..." class="w-full p-2.5 bg-gray-50 border rounded-lg"><div id="po-dropdown" class="absolute z-50 bg-white shadow-xl rounded-xl max-h-72 overflow-y-auto hidden border"></div></div></div><div class="lg:col-span-3 bg-white rounded-xl shadow-md overflow-hidden flex flex-col min-h-[520px]"><div class="bg-emerald-700 text-white p-4 flex justify-between"><h2 class="font-bold text-lg">أمر شراء جديد</h2><span id="po-count">0</span></div><div class="flex-1 overflow-y-auto p-4"><table class="w-full text-right"><thead><tr class="text-xs text-gray-500"><th class="p-2">الصنف</th><th class="p-2 text-center">سعر الشراء</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">الإجمالي</th><th></th></tr></thead><tbody id="po-cart-body"><tr><td colspan="5" class="p-8 text-center">لا توجد أصناف</td></tr></tbody></table></div><div class="p-4 bg-gray-50 border-t flex justify-between"><div><span class="text-gray-500">الإجمالي:</span><span id="po-total" class="text-3xl font-bold">0</span></div><div class="flex gap-2"><button onclick="RW_Purchases._clearCart()" class="px-4 py-2 bg-red-500 text-white rounded-lg">مسح</button><button onclick="RW_Purchases._savePO()" class="px-6 py-2 bg-emerald-600 text-white rounded-lg">حفظ أمر الشراء</button></div></div></div></div>');
8990:     loadSuppliers(); renderPOCart();
8991:   }
8992: 
8993:   function loadSuppliers() {
8994:     var sel = byId('po-supplier'); if (!sel) return;
8995:     var suppliers = RW_STATE.data.suppliers || [], h = '<option value="">-- اختر مورداً --</option>';
8996:     for (var i = 0; i < suppliers.length; i++) h += '<option value="' + esc(suppliers[i].id) + '">' + esc(suppliers[i].name || suppliers[i].supplier_code || '') + '</option>';
8997:     safeHTML(sel, h);
8998:   }
8999: 
9000:   function searchItem(q) {
9001:     var dd = byId('po-dropdown'); if (!dd) return; var query = (q || '').trim().toLowerCase(); if (!query) { dd.classList.add('hidden'); return; }
9002:     var items = RW_STATE.data.items || [], f = items.filter(function(i) { return (((i.name || '') + ' ' + (i.item_code || '') + ' ' + (i.barcode || '')).toLowerCase().indexOf(query) !== -1); }).slice(0, 25);
9003:     if (!f.length) { safeHTML(dd, '<div class="p-3 text-center text-gray-500">لا توجد نتائج</div>'); dd.classList.remove('hidden'); return; }
9004:     var h = '';
9005:     for (var i = 0; i < f.length; i++) { var item = f[i]; h += '<div onclick="RW_Purchases._addToCart(\'' + escJs(item.item_code) + '\')" class="p-3 hover:bg-emerald-50 cursor-pointer flex justify-between border-b"><div><div class="font-bold">' + esc(item.name || item.item_code) + '</div><div class="text-xs text-gray-400">' + esc(item.item_code) + (item.barcode ? ' | ' + esc(item.barcode) : '') + '</div></div><div class="text-emerald-600 font-bold">' + (Number(item.cost_price) || 0).toLocaleString() + ' EGP</div></div>'; }
9006:     safeHTML(dd, h); dd.classList.remove('hidden');
9007:   }
9008: 
9009:   function addToCart(code) {
9010:     var items = RW_STATE.data.items || [], item = null;
9011:     for (var i = 0; i < items.length; i++) if (items[i].item_code === code) { item = items[i]; break; }
9012:     if (!item) return;
9013:     for (var j = 0; j < cart.length; j++) if (cart[j].code === code) { cart[j].qty++; renderPOCart(); return; }
9014:     cart.push({ code: item.item_code, name: item.name, price: Number(item.cost_price) || 0, unit: item.unit || 'حبة', qty: 1 });
9015:     if (byId('po-search')) byId('po-search').value = '';
9016:     if (byId('po-dropdown')) byId('po-dropdown').classList.add('hidden');
9017:     renderPOCart();
9018:   }
9019: 
9020:   function updateQty(idx, v) { var q = Number(v); if (!Number.isFinite(q) || q <= 0) cart.splice(idx, 1); else cart[idx].qty = q; renderPOCart(); }
9021:   function updatePrice(idx, v) { var price = Number(v); if (!Number.isFinite(price) || price < 0) return; cart[idx].price = price; renderPOCart(); }
9022:   function removeItem(idx) { cart.splice(idx, 1); renderPOCart(); }
9023:   function clearCart() { cart = []; renderPOCart(); }
9024: 
9025:   function renderPOCart() {
9026:     var tb = byId('po-cart-body'), totalEl = byId('po-total'), countEl = byId('po-count'); if (!tb) return;
9027:     if (!cart.length) { safeHTML(tb, '<tr><td colspan="5" class="p-8 text-center">لا توجد أصناف</td></tr>'); safeText(totalEl, '0'); safeText(countEl, '0'); return; }
9028:     var total = 0, h = '';
9029:     for (var i = 0; i < cart.length; i++) { var it = cart[i], line = (Number(it.price) || 0) * (Number(it.qty) || 0); total += line; h += '<tr class="border-b"><td class="p-2 font-bold">' + esc(it.name) + '<div class="text-xs text-gray-400">' + esc(it.code) + '</div></td><td class="p-2 text-center"><input type="number" min="0" step="0.01" value="' + (Number(it.price) || 0) + '" onchange="RW_Purchases._updatePrice(' + i + ',this.value)" class="w-24 p-1 border rounded text-center"></td><td class="p-2 text-center"><input type="number" min="0.01" step="0.01" value="' + (Number(it.qty) || 0) + '" onchange="RW_Purchases._updateQty(' + i + ',this.value)" class="w-20 p-1 border rounded text-center"></td><td class="p-2 text-center font-bold">' + line.toLocaleString() + '</td><td class="p-2 text-center"><button onclick="RW_Purchases._removeItem(' + i + ')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>'; }
9030:     safeHTML(tb, h); safeText(totalEl, total.toLocaleString()); safeText(countEl, String(cart.length));
9031:   }
9032: 
9033:   async function savePO() {
9034:     var supplierId = byId('po-supplier') ? byId('po-supplier').value : '';
9035:     if (!supplierId) { showToast('اختر مورداً', 'warning'); return; }
9036:     if (!cart.length) { showToast('أضف أصنافاً', 'warning'); return; }
9037:     var supplier = null, suppliers = RW_STATE.data.suppliers || [];
9038:     for (var i = 0; i < suppliers.length; i++) if (suppliers[i].id === supplierId) { supplier = suppliers[i]; break; }
9039:     if (!supplier) { showToast('المورد غير موجود', 'error'); return; }
9040:     showLoader('جاري الحفظ...');
9041:     try {
9042:       var ses = await supabase.auth.getSession(), token = ses && ses.data && ses.data.session ? ses.data.session.access_token : null;
9043:       if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
9044:       var res = await fetch(SUPABASE_URL + '/functions/v1/save-purchase-order', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token }, body: JSON.stringify({ orderHeader: { supplierId: supplier.id, supplierName: supplier.name || supplier.supplier_code || '' }, itemsList: cart }) });
9045:       var json = await res.json();
9046:       if (!res.ok || !json || !json.success) throw new Error((json && json.msg) || 'فشل حفظ أمر الشراء');
9047:       hideLoader(); showToast('تم الحفظ: ' + (json.poID || ''), 'success'); cart = []; renderPOCart();
9048:     } catch (e) { hideLoader(); showToast(e.message || 'فشل الاتصال', 'error'); }
9049:   }
9050: 
9051:   return { renderOrders: renderOrders, renderPOS: renderPOS, _filterOrders: filterOrders, _openPO: openPO, _openReceive: openReceive, _searchItem: searchItem, _addToCart: addToCart, _updateQty: updateQty, _updatePrice: updatePrice, _removeItem: removeItem, _clearCart: clearCart, _savePO: savePO };
9052: })();
9053: window.RW_Purchases = RW_Purchases;
9054: 	
9055: var RW_PurchaseGold = (function () {
9056:   'use strict';
9057: 
9058:   var active = 'dashboard';
9059: 
9060:   function esc(v) {
9061:     return String(v == null ? '' : v)
9062:       .replace(/&/g,'&amp;')
9063:       .replace(/</g,'&lt;')
9064:       .replace(/>/g,'&gt;')
9065:       .replace(/"/g,'&quot;')
9066:       .replace(/'/g,'&#39;');
9067:   }
9068: 
9069:   function companyId() {
9070:     var id = _rwCompanyId();
9071:     if (!id) throw new Error('سياق الشركة غير محدد');
9072:     return id;
--- RW_Warehouse_FULL 10950-13875 ---
10950: var RW_Warehouse = (function() {
10951:     function esc(s) { return String(s||'').replace(/[&<>]/g, function(m) { return m==='&'?'&amp;':m==='<'?'&lt;':'&gt;'; }); }
10952: 
10953:     // ==================== RECEIVING (سجل الاستلام) ====================
10954:     async function loadReceiving() {
10955:         var c = byId('rw-page-container');
10956:         if (!c) return;
10957: 
10958:         safeText(byId('rw-header-title'), 'الاستلام (Receiving)');
10959:         safeHTML(c, '<div class="p-4">' +
10960:             '<div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">' +
10961:                 '<input type="text" id="rec-filter-id" placeholder="رقم العملية..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10962:                 '<input type="text" id="rec-filter-po" placeholder="رقم أمر الشراء..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10963:                 '<input type="text" id="rec-filter-resp" placeholder="المسؤول..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10964:                 '<input type="date" id="rec-filter-date-from" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyReceiving()">' +
10965:                 '<input type="date" id="rec-filter-date-to" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyReceiving()">' +
10966:                 '<button onclick="RW_Warehouse._applyReceiving()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>' +
10967:             '</div></div>' +
10968:             '<div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr>' +
10969:                 '<th class="p-3">رقم العملية</th><th class="p-3">التاريخ</th><th class="p-3">أمر الشراء</th><th class="p-3">المسؤول</th><th class="p-3">الأصناف</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th>' +
10970:             '</tr></thead><tbody id="rec-table"><tr><td colspan="7" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>' +
10971:         '</div>');
10972: 
10973:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
10974:         if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
10975: 
10976:         var res = await supabase.from('receiving')
10977:             .select('*')
10978:             .eq('company_id', companyId)
10979:             .order('date', { ascending: false });
10980:         if (res.error) { showToast(res.error.message, 'error'); return; }
10981: 
10982:         var rows = res.data || [];
10983:         var opIds = rows.map(function(r) { return r.operation_id; }).filter(Boolean);
10984:         var counts = {};
10985:         if (opIds.length) {
10986:             var detailsRes = await supabase.from('receiving_details')
10987:                 .select('operation_id')
10988:                 .in('operation_id', opIds);
10989:             if (detailsRes.error) { showToast(detailsRes.error.message, 'error'); return; }
10990:             var details = detailsRes.data || [];
10991:             for (var i = 0; i < details.length; i++) {
10992:                 counts[details[i].operation_id] = (counts[details[i].operation_id] || 0) + 1;
10993:             }
10994:         }
10995: 
10996:         window._receivingData = rows.map(function(r) {
10997:             var x = Object.assign({}, r);
10998:             x.itemsCount = counts[r.operation_id] || 0;
10999:             return x;
11000:         });
11001:         _applyReceiving();
11002:     }
11003: 
11004:     function _applyReceiving() {
11005:         var d = window._receivingData || [];
11006:         var id = (byId('rec-filter-id')?.value || '').trim().toLowerCase();
11007:         var po = (byId('rec-filter-po')?.value || '').trim().toLowerCase();
11008:         var resp = (byId('rec-filter-resp')?.value || '').trim().toLowerCase();
11009:         var fd = byId('rec-filter-date-from')?.value;
11010:         var td = byId('rec-filter-date-to')?.value;
11011: 
11012:         if (id) d = d.filter(function(r) { return String(r.operation_id || '').toLowerCase().indexOf(id) !== -1; });
11013:         if (po) d = d.filter(function(r) { return String(r.po_number || '').toLowerCase().indexOf(po) !== -1; });
11014:         if (resp) d = d.filter(function(r) { return String(r.responsible || '').toLowerCase().indexOf(resp) !== -1; });
11015:         if (fd) d = d.filter(function(r) { return r.date >= fd; });
11016:         if (td) d = d.filter(function(r) { return r.date <= td; });
11017: 
11018:         var tb = byId('rec-table');
11019:         if (!tb) return;
11020:         if (!d.length) { safeHTML(tb, '<tr><td colspan="7" class="text-center py-8">لا توجد عمليات استلام</td></tr>'); return; }
11021: 
11022:         var h = '';
11023:         d.forEach(function(op) {
11024:             var opId = String(op.operation_id || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
11025:             h += "<tr class=\"border-b hover:bg-gray-50 cursor-pointer\" onclick=\"RW_Warehouse._showReceivingDetails('" + opId + "')\">" +
11026:                 '<td class="p-3 font-bold text-blue-600">' + esc(op.operation_id || '') + '</td>' +
11027:                 '<td class="p-3">' + esc(op.date || '') + '</td>' +
11028:                 '<td class="p-3">' + esc(op.po_number || '---') + '</td>' +
11029:                 '<td class="p-3">' + esc(op.responsible || '---') + '</td>' +
11030:                 '<td class="p-3 text-center">' + Number(op.itemsCount || 0) + '</td>' +
11031:                 '<td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-green-100 text-green-700">' + esc(op.status || 'مكتمل') + '</span></td>' +
11032:                 "<td class=\"p-3 text-center\"><button class=\"text-blue-600\" onclick=\"event.stopPropagation(); RW_Warehouse._showReceivingDetails('" + opId + "')\"><i class=\"fa-solid fa-eye\"></i></button></td>" +
11033:             '</tr>';
11034:         });
11035:         safeHTML(tb, h);
11036:     }
11037: 
11038: async function _showReceivingDetails(opId) {
11039:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11040:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11041:     showLoader('جاري التحميل...');
11042:     var opRes = await supabase.from('receiving')
11043:         .select('operation_id')
11044:         .eq('company_id', companyId)
11045:         .eq('operation_id', opId)
11046:         .maybeSingle();
11047: 
11048:     if (opRes.error || !opRes.data) {
11049:         hideLoader();
11050:         showToast('عملية الاستلام غير موجودة في الشركة الحالية', 'error');
11051:         return;
11052:     }
11053: 
11054:     var detRes = await supabase.from('receiving_details')
11055:         .select('*')
11056:         .eq('operation_id', opRes.data.operation_id);
11057: 
11058:     hideLoader();
11059: 
11060:     var details = detRes.data || [];
11061:     if (!details.length) {
11062:         showToast('لا توجد تفاصيل', 'info');
11063:         return;
11064:     }
11065: 
11066:     var h = '<div class="text-right"><table class="w-full border text-sm"><thead class="bg-gray-100"><tr>' +
11067:         '<th class="p-2">الكود</th>' +
11068:         '<th class="p-2">الصنف</th>' +
11069:         '<th class="p-2 text-center">الوحدة</th>' +
11070:         '<th class="p-2 text-center">المطلوب</th>' +
11071:         '<th class="p-2 text-center">الفعلي</th>' +
11072:         '<th class="p-2 text-center">الفرق</th>' +
11073:         '<th class="p-2">السبب</th>' +
11074:         '</tr></thead><tbody>';
11075: 
11076:     details.forEach(function(d) {
11077:         h += '<tr>' +
11078:             '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
11079:             '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
11080:             '<td class="p-2 border text-center">' + esc(d.unit || '') + '</td>' +
11081:             '<td class="p-2 border text-center">' + (d.qty_expected || 0) + '</td>' +
11082:             '<td class="p-2 border text-center font-bold">' + (d.qty_received || 0) + '</td>' +
11083:             '<td class="p-2 border text-center">' + (d.difference || 0) + '</td>' +
11084:             '<td class="p-2 border">' + esc(d.reason || '') + '</td>' +
11085:             '</tr>';
11086:     });
11087: 
11088:     h += '</tbody></table></div>';
11089: 
11090:     Swal.fire({
11091:         title: 'تفاصيل الاستلام: ' + esc(opRes.data.operation_id),
11092:         html: h,
11093:         width: '800px',
11094:         showCloseButton: true,
11095:         showConfirmButton: false
11096:     });
11097: }
11098: 
11099:     // ==================== VOUCHER FORM – نماذج الأذونات الأربعة ====================
11100:     var voucherCart = [];
11101:     var currentVoucherType = '';
11102:     var currentVoucherConfig = {};
11103: 
11104:     function loadVoucherForm(type) {
11105:         voucherCart = [];
11106:         currentVoucherType = type;
11107:         var configs = {            'Transfer':      { title: 'تحويل مخزني', entityLabel: 'الفرع المحول إليه', showPrice: false, fromType: 'Branch', fromId: null, toType: 'Branch', toId: null, endpoint: 'save-voucher' },
11108:             'DirectSale':    { title: 'صرف سيارة بيع مباشر', entityLabel: 'المندوب / السيارة', showPrice: true, fromType: 'Branch', fromId: null, toType: 'Vehicle', toId: null, endpoint: 'save-voucher' },
11109:             'DirectReturn':  { title: 'استلام مرتجع سيارة', entityLabel: 'المندوب / السيارة', showPrice: true, fromType: 'Vehicle', fromId: null, toType: 'Branch', toId: null, endpoint: 'save-voucher' },
11110:             'SupplierReturn':{ title: 'مرتجع لمورد', entityLabel: 'المورد', showPrice: true, fromType: 'Branch', fromId: null, toType: 'Supplier', toId: null, endpoint: 'save-voucher' }
11111:         };
11112:         var cfg = configs[type];
11113:         if (!cfg) { showToast('نوع غير معروف', 'error'); return; }
11114:         currentVoucherConfig = cfg;
11115: 
11116:         var c = byId('rw-page-container');
11117:         if (!c) return;
11118:         safeText(byId('rw-header-title'), cfg.title);
11119:         safeHTML(c, `<div class="p-4">
11120:             <div class="bg-white rounded-2xl shadow-sm border p-4">
11121:                 <div class="flex justify-between items-center mb-4">
11122:                     <h2 class="text-xl font-bold"><i class="fa-solid fa-file-signature ml-2 text-indigo-600"></i>${cfg.title}</h2>
11123:                     <button onclick="RW_Warehouse.loadVouchers()" class="text-gray-500 hover:text-gray-700"><i class="fa-solid fa-xmark text-xl"></i></button>
11124:                 </div>
11125:                 <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
11126:     <div>
11127:         <label class="block text-sm font-bold mb-1">${cfg.entityLabel}</label>
11128:         <select id="voucherEntitySelect" class="border rounded-lg p-2 w-full"><option value="">-- اختر --</option></select>
11129:     </div>
11130:     <div>
11131:         <label class="block text-sm font-bold mb-1">مرجع الإذن</label>
11132:         <input id="voucherReference" class="border rounded-lg p-2 w-full" placeholder="مرجع الإذن...">
11133:     </div>
11134:     <div>
11135:         <label class="block text-sm font-bold mb-1">ملاحظات</label>
11136:         <textarea id="voucherNotesLarge" rows="2" class="border rounded-lg p-2 w-full" placeholder="ملاحظات..."></textarea>
11137:     </div>
11138: </div> 
11139: <label class="block text-sm font-bold mb-1">بحث عن صنف</label>
11140:                     <div class="relative">
11141:                         <input type="text" id="voucherItemSearch" oninput="RW_Warehouse._searchVoucherItem(this.value)" autocomplete="off" placeholder="ابحث بالاسم أو الباركود..." class="border rounded-lg p-2 w-full">
11142:                         <div id="voucherSearchResults" class="absolute z-50 left-0 right-0 mt-1 bg-white shadow-xl rounded-xl max-h-60 overflow-y-auto hidden border"></div>
11143:                     </div>
11144:                 </div>
11145:                 <div class="mb-4 overflow-y-auto" style="max-height:300px;" id="voucherItemsTable">
11146:                     <div class="text-center py-8 text-gray-400">أضف أصنافاً</div>
11147:                 </div>
11148:                 <div class="p-3 bg-gray-50 rounded-lg flex justify-between items-center mb-4">
11149:                     <span class="font-bold">عدد الأصناف: <span id="voucherTotalItems">0</span></span>
11150:                 </div>
11151:                 <div class="flex justify-end gap-3">
11152:                     <button onclick="RW_Warehouse._clearVoucherCart()" class="px-4 py-2 bg-gray-500 text-white rounded-lg font-bold">مسح الكل</button>
11153:                     <button onclick="RW_Warehouse._saveAndSendVoucher()" class="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold">حفظ وإرسال (Sent)</button>
11154:                 </div>
11155:             </div>
11156:         </div>`);
11157: 
11158:         _loadVoucherEntityOptions(type);
11159:         _renderVoucherCart();
11160:     }
11161: 
11162: async function _loadVoucherEntityOptions(type) {
11163:     var select = byId('voucherEntitySelect');
11164:     if (!select) return;
11165: 
11166:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11167:     if (!companyId) {
11168:         showToast('سياق الشركة غير محدد', 'error');
11169:         return;
11170:     }
11171: 
11172:     if (type === 'Transfer') {
11173:         var branchRes = await supabase.from('branches')
11174:             .select('id, branch_code, name')
11175:             .eq('company_id', companyId)
11176:             .eq('is_active', true)
11177:             .order('name');
11178:         if (branchRes.error) { showToast(branchRes.error.message, 'error'); return; }
11179: 
11180:         var branchHtml = '<option value="">-- اختر فرعاً --</option>';
11181:         var branches = branchRes.data || [];
11182:         for (var i = 0; i < branches.length; i++) {
11183:             branchHtml += '<option value="' + branches[i].id + '">' +
11184:                 (branches[i].name || branches[i].branch_code || '') +
11185:                 '</option>';
11186:         }
11187:         safeHTML(select, branchHtml);
11188:         return;
11189:     }
11190: 
11191: 	if (type === 'SupplierReturn') {
11192:         var supplierRes = await supabase.from('suppliers')
11193:             .select('id, supplier_code, name')
11194:             .eq('company_id', companyId)
11195:             .eq('is_active', true)
11196:             .order('name');
11197:         if (supplierRes.error) { showToast(supplierRes.error.message, 'error'); return; }
11198: 
11199:         var supplierHtml = '<option value="">-- اختر مورداً --</option>';
11200:         var suppliers = supplierRes.data || [];
11201:         for (var s = 0; s < suppliers.length; s++) {
11202:             supplierHtml += '<option value="' + suppliers[s].id + '">' + (suppliers[s].name || suppliers[s].supplier_code || '') + '</option>';
11203:         }
11204:         safeHTML(select, supplierHtml);
11205:         return;
11206:     }
11207: 
11208:     var driverRoles = type === 'DirectSale'
11209:         ? ['مندوب بيع مباشر']
11210:         : ['driver', 'سائق', 'مندوب', 'مندوب بيع مباشر'];
11211: 
11212:     var usersRes = await supabase.from('users')
11213:         .select('id, email, name, role')
11214:         .eq('company_id', companyId)
11215:         .in('role', driverRoles)
11216:         .eq('status', 'Active');
11217:     if (usersRes.error) { showToast(usersRes.error.message, 'error'); return; }
11218: 
11219:     var drivers = usersRes.data || [];
11220:     var driverIds = drivers.map(function(d) { return d.id; });
11221:     if (!driverIds.length) {
11222:         safeHTML(select, '<option value="">-- لا توجد سيارات متاحة --</option>');
11223:         return;
11224:     }
11225: 
11226:     var vehicleRes = await supabase.from('vehicles')
11227:         .select('id, vehicle_code, license_plate, driver_id')
11228:         .eq('company_id', companyId)
11229:         .eq('status', 'Active')
11230:         .in('driver_id', driverIds)
11231:         .order('vehicle_code');
11232:     if (vehicleRes.error) { showToast(vehicleRes.error.message, 'error'); return; }
11233: 
11234:     var driverMap = {};
11235:     for (var d = 0; d < drivers.length; d++) driverMap[drivers[d].id] = drivers[d];
11236: 
11237:     var vehicleHtml = '<option value="">-- اختر سيارة --</option>';
11238:     var vehicles = vehicleRes.data || [];
11239:     for (var v = 0; v < vehicles.length; v++) {
11240:         var vehicle = vehicles[v];
11241:         var driver = driverMap[vehicle.driver_id] || {};
11242:         var label = (driver.name || driver.email || '') + ' — ' + (vehicle.vehicle_code || vehicle.license_plate || vehicle.id);
11243:         vehicleHtml += '<option value="' + vehicle.id + '">' + label + '</option>';
11244:     }
11245:     safeHTML(select, vehicleHtml);
11246: }
11247: 
11248:     function _searchVoucherItem(query) {
11249:         var div = byId('voucherSearchResults');
11250:         if (!div) return;
11251:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
11252:         var items = RW_STATE.data.items || [];
11253:         var q = query.toLowerCase();
11254:         var filtered = items.filter(function(i) { return (i.name || '').toLowerCase().indexOf(q) !== -1 || (i.item_code || '').toLowerCase().indexOf(q) !== -1; });
11255:         if (filtered.length > 0) {
11256:             var html = '';
11257:             for (var idx = 0; idx < Math.min(filtered.length, 20); idx++) {
11258:                 var item = filtered[idx];
11259:                 html += '<div onclick="RW_Warehouse._addVoucherItem(\'' + item.item_code + '\')" class="p-3 hover:bg-indigo-50 cursor-pointer flex justify-between border-b"><div><div class="font-bold">' + item.name + '</div><div class="text-xs text-gray-400">' + item.item_code + '</div></div><div class="font-bold text-indigo-600">' + (item.qty || 0) + ' ' + (item.unit || '') + '</div></div>';
11260:             }
11261:             safeHTML(div, html); div.classList.remove('hidden');
11262:         } else { div.classList.add('hidden'); }
11263:     }
11264: 
11265:     function _addVoucherItem(itemCode) {
11266:         var items = RW_STATE.data.items || [];
11267:         var item = null;
11268:         for (var i = 0; i < items.length; i++) { if (items[i].item_code === itemCode) { item = items[i]; break; } }
11269:         if (!item) return;
11270:         var existing = null;
11271:         for (var j = 0; j < voucherCart.length; j++) { if (voucherCart[j].code === itemCode) { existing = voucherCart[j]; break; } }
11272:         if (existing) { existing.qty++; } else {
11273:             voucherCart.push({ code: item.item_code, name: item.name, unit: item.unit || 'حبة', qty: 1, price: currentVoucherConfig.showPrice ? (Number(item.sales_price) || 0) : 0 });
11274:         }
11275:         byId('voucherItemSearch').value = '';
11276:         byId('voucherSearchResults').classList.add('hidden');
11277:         _renderVoucherCart();
11278:     }
11279: 
11280:     function _renderVoucherCart() {
11281:         var tbody = byId('voucherItemsTable');
11282:         var countSpan = byId('voucherTotalItems');
11283:         if (voucherCart.length === 0) { safeHTML(tbody, '<div class="text-center py-8 text-gray-400">أضف أصنافاً</div>'); if (countSpan) countSpan.innerText = '0'; return; }
11284:         var html = '<table class="w-full text-right border"><thead class="bg-gray-100 text-xs uppercase"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية</th>';
11285:         if (currentVoucherConfig.showPrice) html += '<th class="p-2 text-center">السعر</th>';
11286:         html += '<th class="p-2 text-center">حذف</th></tr></thead><tbody>';
11287:         for (var i = 0; i < voucherCart.length; i++) {
11288:             var item = voucherCart[i];
11289:             html += '<tr class="border-b"><td class="p-2"><div class="font-bold">' + item.name + '</div><div class="text-xs text-gray-400">' + item.code + '</div></td><td class="p-2 text-center"><input type="number" value="' + item.qty + '" onchange="RW_Warehouse._updateVoucherQty(' + i + ', this.value)" class="w-16 p-1 border rounded text-center" min="1"></td>';
11290:             if (currentVoucherConfig.showPrice) html += '<td class="p-2 text-center"><input type="number" value="' + item.price + '" onchange="RW_Warehouse._updateVoucherPrice(' + i + ', this.value)" class="w-20 p-1 border rounded text-center" step="0.01" min="0"></td>';
11291:             html += '<td class="p-2 text-center"><button onclick="RW_Warehouse._removeVoucherItem(' + i + ')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>';
11292:         }
11293:         html += '</tbody></table>';
11294:         safeHTML(tbody, html);
11295:         if (countSpan) countSpan.innerText = String(voucherCart.length);
11296:     }
11297: 
11298:     function _updateVoucherQty(idx, val) { var q = parseInt(val); if (q > 0) voucherCart[idx].qty = q; else voucherCart.splice(idx, 1); _renderVoucherCart(); }
11299:     function _updateVoucherPrice(idx, val) { voucherCart[idx].price = parseFloat(val) || 0; _renderVoucherCart(); }
11300:     function _removeVoucherItem(idx) { voucherCart.splice(idx, 1); _renderVoucherCart(); }
11301:     function _clearVoucherCart() { voucherCart = []; _renderVoucherCart(); }
11302: 
11303: async function _saveAndSendVoucher() {
11304:     if (voucherCart.length === 0) { showToast('أضف أصنافاً للإذن', 'warning'); return; }
11305: 
11306:     var entity = byId('voucherEntitySelect') ? byId('voucherEntitySelect').value : '';
11307:     if (!entity) { showToast('يرجى اختيار ' + currentVoucherConfig.entityLabel, 'warning'); return; }
11308: 
11309:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11310:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11311: 
11312:     var notes = byId('voucherNotesLarge') ? byId('voucherNotesLarge').value : '';
11313:     var reference = byId('voucherReference') ? byId('voucherReference').value.trim() : '';
11314:     if (!reference) { showToast('مرجع الإذن مطلوب', 'warning'); return; }
11315: 
11316:     var settingsRes = await supabase.from('app_settings')
11317:         .select('main_branch_id')
11318:         .eq('company_id', companyId)
11319:         .order('created_at', { ascending: true })
11320:         .limit(1)
11321:         .maybeSingle();
11322:     if (settingsRes.error) { showToast(settingsRes.error.message, 'error'); return; }
11323: 
11324:     var mainBranchId = settingsRes.data ? settingsRes.data.main_branch_id : null;
11325:     if (!mainBranchId) { showToast('الفرع الرئيسي غير محدد', 'error'); return; }
11326: 
11327:     var fromId = null;
11328:     var toId = null;
11329:     var repId = null;
11330: 
11331:     if (currentVoucherType === 'Transfer') {
11332:         fromId = mainBranchId;
11333:         toId = entity;
11334:     } else if (currentVoucherType === 'DirectSale') {
11335:         fromId = mainBranchId;
11336:         toId = entity;
11337: 
11338:         var directSaleVehicleRes = await supabase.from('vehicles')
11339:             .select('id, driver_id')
11340:             .eq('company_id', companyId)
11341:             .eq('id', entity)
11342:             .eq('status', 'Active')
11343:             .maybeSingle();
11344:         if (directSaleVehicleRes.error) { showToast(directSaleVehicleRes.error.message, 'error'); return; }
11345:         if (!directSaleVehicleRes.data || !directSaleVehicleRes.data.driver_id) {
11346:             showToast('المركبة المختارة لا ترتبط بمندوب بيع مباشر', 'error');
11347:             return;
11348:         }
11349:         repId = directSaleVehicleRes.data.driver_id;
11350:     } else if (currentVoucherType === 'DirectReturn') {
11351:         fromId = entity;
11352:         toId = mainBranchId;
11353:     } else if (currentVoucherType === 'SupplierReturn') {
11354:         fromId = mainBranchId;
11355:         toId = entity;
11356:     } else {
11357:         showToast('نوع الإذن غير مدعوم', 'error');
11358:         return;
11359:     }
11360: 
11361:     var items = [];
11362:     for (var i = 0; i < voucherCart.length; i++) {
11363:         items.push({
11364:             itemCode: voucherCart[i].code,
11365:             qty: voucherCart[i].qty,
11366:             unitPrice: voucherCart[i].price || 0,
11367:             notes: ''
11368:         });
11369:     }
11370: 
11371:     window._warehouseVoucherOperations = window._warehouseVoucherOperations || {};
11372:     var fingerprint = [
11373:         companyId,
11374:         currentVoucherType,
11375:         entity,
11376:         reference,
11377:         notes,
11378:         repId || '',
11379:         JSON.stringify(items)
11380:     ].join('|');
11381:     var operationId = window._warehouseVoucherOperations[fingerprint];
11382:     if (!operationId) {
11383:         operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('WHV-' + Date.now() + '-' + Math.random().toString(36).slice(2));
11384:         window._warehouseVoucherOperations[fingerprint] = operationId;
11385:     }
11386: 
11387:     showLoader('جاري حفظ وإرسال الإذن...');
11388:     var ses = await supabase.auth.getSession();
11389:     var token = ses.data.session ? ses.data.session.access_token : null;
11390:     if (!token) { hideLoader(); showToast('انتهت الجلسة', 'error'); return; }
11391: 
11392:     try {
11393:         var createBody = {
11394:             type: currentVoucherType,
11395:             reference: reference,
11396:             fromType: currentVoucherType === 'DirectReturn' ? 'Vehicle' : 'Branch',
11397:             fromId: fromId,
11398:             toType: currentVoucherType === 'DirectSale' || currentVoucherType === 'DirectReturn' ? (currentVoucherType === 'DirectSale' ? 'Vehicle' : 'Branch') : (currentVoucherType === 'SupplierReturn' ? 'Supplier' : 'Branch'),
11399:             toId: toId,
11400:             items: items,
11401:             notes: notes,
11402:             rep_id: repId,
11403:             operation_id: operationId
11404:         };
11405: 
11406:         var createRes = await fetch(RW_SUPABASE_URL + '/functions/v1/create-stock-voucher', {
11407:             method: 'POST',
11408:             headers: {
11409:                 'Content-Type': 'application/json',
11410:                 'Authorization': 'Bearer ' + token,
11411:                 'Idempotency-Key': operationId
11412:             },
11413:             body: JSON.stringify(createBody)
11414:         });
11415: 
11416:         var createJson = await createRes.json().catch(function() { return {}; });
11417:         if (!createRes.ok || !createJson.success) {
11418:             throw new Error(createJson.msg || createJson.error || 'فشل حفظ الإذن');
11419:         }
11420: 
11421:         var voucherCode = createJson.voucherId || createJson.voucher_code;
11422:         if (!voucherCode) throw new Error('لم يُرجع إنشاء الإذن رقمًا صالحًا');
11423: 
11424:         var sendRes = await fetch(RW_SUPABASE_URL + '/functions/v1/send-stock-voucher', {
11425:             method: 'POST',
11426:             headers: {
11427:                 'Content-Type': 'application/json',
11428:                 'Authorization': 'Bearer ' + token,
11429:                 'Idempotency-Key': operationId
11430:             },
11431:             body: JSON.stringify({ voucher_code: voucherCode })
11432:         });
11433: 
11434:         var sendJson = await sendRes.json().catch(function() { return {}; });
11435:         if (!sendRes.ok || !sendJson.success) {
11436:             throw new Error(sendJson.msg || sendJson.error || 'فشل الإرسال');
11437:         }
11438: 
11439:         hideLoader();
11440:         delete window._warehouseVoucherOperations[fingerprint];
11441:         showToast(sendJson.duplicate ? 'تم استرجاع نتيجة الإذن السابقة' : ('تم إنشاء وإرسال الإذن ' + voucherCode), 'success');
11442:         voucherCart = [];
11443:         _renderVoucherCart();
11444:         if (typeof loadVouchers === 'function') await loadVouchers();
11445:     } catch (e) {
11446:         hideLoader();
11447:         showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس العملية', 'error');
11448:     }
11449: }
11450: 
11451:     // ==================== VOUCHERS LIST – عرض الأذونات مع فصل ====================
11452:     async function loadVouchers() {
11453:         var c = byId('rw-page-container'); if (!c) return;
11454:         safeText(byId('rw-header-title'), 'الأذونات المخزنية');
11455:         safeHTML(c, `<div class="p-4">
11456:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">
11457:                 <div class="flex flex-wrap items-center gap-2 mb-3">
11458:                     <select id="v-filter-type" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm"><option value="">كل الأنواع</option><option value="Transfer">تحويل</option><option value="DirectSale">صرف مباشر</option><option value="DirectReturn">مرتجع مباشر</option><option value="SupplierReturn">مرتجع لمورد</option><option value="Picking">تحضير</option><option value="Loading">تحميل</option><option value="Return">مرتجع</option><option value="Unloading">تفريغ</option><option value="Adjustment">جرد</option></select>
11459:                     <select id="v-filter-status" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm"><option value="">كل الحالات</option><option value="Draft">مسودة</option><option value="Sent">مُرسل</option><option value="Received">مُستلم</option><option value="Completed">مكتمل</option></select>
11460:                     <input type="date" id="v-filter-from" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm">
11461:                     <input type="date" id="v-filter-to" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm">
11462:                     <input type="text" id="v-search" oninput="RW_Warehouse._applyVouchers()" placeholder="بحث برقم الإذن..." class="p-2 bg-white border rounded-lg text-sm w-40">
11463:                     <button onclick="RW_Warehouse._openNewVoucherModal()" class="bg-indigo-600 text-white px-4 py-2 rounded-xl font-bold text-sm"><i class="fa-solid fa-plus ml-1"></i> إذن جديد</button>
11464:                     <label class="flex items-center gap-2 ml-3 text-sm"><input type="checkbox" id="v-show-all" onchange="RW_Warehouse._applyVouchers()"> <span class="font-bold">إظهار الكل (يشمل التلقائية)</span></label>
11465:                 </div>
11466:             </div>
11467:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh" id="vouchers-table-container">
11468:                 <table class="w-full"><thead class="bg-gray-800 text-white sticky top-0"><tr><th class="p-3">رقم الإذن</th><th class="p-3">النوع</th><th class="p-3">التاريخ</th><th class="p-3">الحالة</th><th class="p-3">المرجع</th><th class="p-3">من</th><th class="p-3">إلى</th><th class="p-3 text-center">إجراءات</th></tr></thead><tbody id="vouchers-tbody"><tr><td colspan="8" class="text-center py-8">جاري التحميل...</td></tr></tbody></table>
11469:             </div>
11470:         </div>`);
11471:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11472: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11473: var res = await supabase.from('stock_vouchers').select('*').eq('company_id', companyId).order('voucher_date', { ascending: false });
11474:         window._vouchersData = res.data || [];
11475:         _applyVouchers();
11476:     }
11477: 
11478:     function _applyVouchers() {
11479:         var d = window._vouchersData || [];
11480:         var type = byId('v-filter-type') ? byId('v-filter-type').value : '';
11481:         var status = byId('v-filter-status') ? byId('v-filter-status').value : '';
11482:         var from = byId('v-filter-from') ? byId('v-filter-from').value : '';
11483:         var to = byId('v-filter-to') ? byId('v-filter-to').value : '';
11484:         var search = (byId('v-search') ? byId('v-search').value : '').toLowerCase();
11485:         var showAll = byId('v-show-all') ? byId('v-show-all').checked : false;
11486:         
11487:         if (!showAll) {
11488:             d = d.filter(function(v) { return v.source === 'Manual' || (v.source !== 'Manual' && v.type === 'Adjustment'); });
11489:         }
11490:         if (type) d = d.filter(function(v) { return v.type === type; });
11491:         if (status) d = d.filter(function(v) { return v.status === status; });
11492:         if (from) d = d.filter(function(v) { return v.voucher_date >= from; });
11493:         if (to) d = d.filter(function(v) { return v.voucher_date <= to; });
11494:         if (search) d = d.filter(function(v) { return (v.voucher_code||'').toLowerCase().indexOf(search) !== -1; });
11495:         var tb = byId('vouchers-tbody'); if (!tb) return;
11496:         if (!d.length) { safeHTML(tb, '<tr><td colspan="8" class="text-center py-8">لا توجد أذونات</td></tr>'); return; }
11497:         RW_Table.paginate('vouchers-tbody', d, 1, 50, function(v) {
11498:             var statusBadge = { 'Draft':'bg-gray-100 text-gray-600', 'Sent':'bg-blue-100 text-blue-700', 'Received':'bg-purple-100 text-purple-700', 'Completed':'bg-green-100 text-green-700' }[v.status] || 'bg-gray-100 text-gray-700';
11499:             var isSystem = (v.source === 'Auto' || ['Picking','Loading','Return','Unloading'].indexOf(v.type) !== -1);
11500:             var actions = '<button onclick="RW_Warehouse._viewVoucherDetails(\'' + v.voucher_code + '\')" class="text-blue-600 mx-1"><i class="fa-solid fa-eye"></i></button>';
11501:             if (v.status === 'Draft' && !isSystem) actions += '<button onclick="RW_Warehouse._sendVoucher(\'' + v.voucher_code + '\')" class="text-blue-600 mx-1"><i class="fa-solid fa-paper-plane"></i></button>';
11502:             if (v.status === 'Sent') actions += '<button onclick="RW_Warehouse._receiveVoucher(\'' + v.voucher_code + '\')" class="text-green-600 mx-1"><i class="fa-solid fa-check-circle"></i></button>';
11503:             var sourceIndicator = isSystem ? ' <i class="fa-solid fa-robot text-gray-400 text-xs" title="تلقائي"></i>' : '';
11504:             return '<tr class="hover:bg-gray-50"><td class="p-3 font-bold text-indigo-700">' + (v.voucher_code||'') + sourceIndicator + '</td><td class="p-3">' + (v.type||'') + '</td><td class="p-3">' + (v.voucher_date||'') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs ' + statusBadge + '">' + (v.status||'') + '</span></td><td class="p-3">' + (v.reference||'-') + '</td><td class="p-3">' + (v.from_id||'-') + '</td><td class="p-3">' + (v.to_id||'-') + '</td><td class="p-3 text-center">' + actions + '</td></tr>';
11505:         });
11506:     }
11507: 
11508: async function _viewVoucherDetails(voucherCode) {
11509:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11510:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11511: 
11512:     showLoader('جاري التحميل...');
11513: 
11514:     var voucherRes = await supabase.from('stock_vouchers')
11515:         .select('id,voucher_code')
11516:         .eq('company_id', companyId)
11517:         .eq('voucher_code', voucherCode)
11518:         .maybeSingle();
11519: 
11520:     if (voucherRes.error || !voucherRes.data) {
11521:         hideLoader();
11522:         showToast('الإذن غير موجود في الشركة الحالية', 'error');
11523:         return;
11524:     }
11525: 
11526:     var detRes = await supabase.from('stock_voucher_details')
11527:         .select('*')
11528:         .eq('voucher_id', voucherRes.data.id)
11529:         .order('item_code');
11530: 
11531:     hideLoader();
11532: 
11533:     var details = detRes.data || [];
11534:     if (!details.length) {
11535:         showToast('لا توجد تفاصيل', 'info');
11536:         return;
11537:     }
11538: 
11539:     var h = '<table class="w-full border text-sm"><thead class="bg-gray-100"><tr>' +
11540:         '<th class="p-2">الكود</th>' +
11541:         '<th class="p-2">الصنف</th>' +
11542:         '<th class="p-2 text-center">الكمية</th>' +
11543:         '<th class="p-2 text-center">المستلمة</th>' +
11544:         '</tr></thead><tbody>';
11545: 
11546:     details.forEach(function(d) {
11547:         h += '<tr>' +
11548:             '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
11549:             '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
11550:             '<td class="p-2 border text-center">' + (d.qty || 0) + '</td>' +
11551:             '<td class="p-2 border text-center">' + (d.received_qty || 0) + '</td>' +
11552:             '</tr>';
11553:     });
11554: 
11555:     h += '</tbody></table>';
11556: 
11557:     Swal.fire({
11558:         title: 'تفاصيل الإذن: ' + esc(voucherRes.data.voucher_code),
11559:         html: h,
11560:         width: '600px',
11561:         showCloseButton: true,
11562:         showConfirmButton: false
11563:     });
11564: }
11565: 
11566:     async function _sendVoucher(voucherCode) {
11567:         var confirm = await Swal.fire({ title: 'تأكيد الإرسال', text: 'سيتم إرسال الإذن ' + voucherCode + ' وخصم المخزون من المصدر. متابعة؟', icon: 'warning', showCancelButton: true, confirmButtonColor: '#2563eb', confirmButtonText: 'نعم، أرسل', cancelButtonText: 'إلغاء' });
11568:         if (!confirm.isConfirmed) return;
11569:         showLoader('جاري إرسال الإذن...');
11570:         var ses = await supabase.auth.getSession(), token = ses.data.session ? ses.data.session.access_token : null;
11571:         try {
11572:             var res = await fetch(RW_SUPABASE_URL + '/functions/v1/send-stock-voucher', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token }, body: JSON.stringify({ voucher_code: voucherCode }) });
11573:             var json = await res.json(); hideLoader();
11574:             if (json.success) { showToast('تم إرسال الإذن بنجاح', 'success'); loadVouchers(); }
11575:             else showToast(json.error || json.msg || 'فشل الإرسال', 'error');
11576:         } catch(e) { hideLoader(); showToast('فشل الاتصال بـ Edge Function', 'error'); }
11577:     }
11578: 
11579: async function _receiveVoucher(voucherCode) {
11580:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11581:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11582:     showLoader('جاري تحميل تفاصيل الإذن...');
11583:     var voucherRes = await supabase.from('stock_vouchers').select('id,status,voucher_code,to_id').eq('company_id', companyId).eq('voucher_code', voucherCode).maybeSingle();
11584:     if (voucherRes.error || !voucherRes.data) { hideLoader(); showToast('الإذن غير موجود في الشركة الحالية', 'error'); return; }
11585:     if (voucherRes.data.status !== 'Sent') { hideLoader(); showToast('الإذن غير جاهز للاستلام: ' + (voucherRes.data.status || ''), 'warning'); return; }
11586:     var detRes = await supabase.from('stock_voucher_details').select('*').eq('voucher_id', voucherRes.data.id).order('item_code');
11587:     var details = detRes.data || [];
11588:     hideLoader();
11589:     if (!details.length) { showToast('لا توجد تفاصيل لهذا الإذن', 'info'); return; }
11590:     var html = '<div class="text-right"><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2 border">الصنف</th><th class="p-2 border text-center">المرسل</th><th class="p-2 border text-center">المستلم سابقًا</th><th class="p-2 border text-center">المتبقي</th><th class="p-2 border text-center">استلام الآن</th></tr></thead><tbody>';
11591:     for (var i = 0; i < details.length; i++) {
11592:         var d = details[i];
11593:         var totalQty = Number(d.qty || 0);
11594:         var receivedBefore = Number(d.received_qty || 0);
11595:         var remaining = Math.max(0, totalQty - receivedBefore);
11596:         html += '<tr><td class="p-2 border font-semibold">' + esc(d.item_name || '') + ' (' + esc(d.item_code || '') + ')</td><td class="p-2 border text-center font-bold">' + totalQty + '</td><td class="p-2 border text-center">' + receivedBefore + '</td><td class="p-2 border text-center font-bold text-blue-700">' + remaining + '</td><td class="p-2 border text-center"><input type="number" id="vrec_qty_' + i + '" value="' + remaining + '" class="w-24 p-1 border rounded text-center" min="0" max="' + remaining + '" step="0.01"></td></tr>';
11597:     }
11598:     html += '</tbody></table></div>';
11599:     var result = await Swal.fire({
11600:         title: 'استلام الإذن: ' + esc(voucherCode),
11601:         html: html,
11602:         width: '850px',
11603:         showCancelButton: true,
11604:         confirmButtonText: 'تأكيد الاستلام',
11605:         confirmButtonColor: '#10b981',
11606:         cancelButtonText: 'إلغاء',
11607:         preConfirm: function() {
11608:             var items = [];
11609:             var hasQty = false;
11610:             for (var j = 0; j < details.length; j++) {
11611:                 var maxRemaining = Math.max(0, Number(details[j].qty || 0) - Number(details[j].received_qty || 0));
11612:                 var qty = parseFloat((document.getElementById('vrec_qty_' + j) || {}).value) || 0;
11613:                 if (qty < 0 || qty > maxRemaining) {
11614:                     Swal.showValidationMessage('كمية الاستلام تتجاوز المتبقي للصنف: ' + (details[j].item_code || ''));
11615:                     return false;
11616:                 }
11617:                 if (qty > 0) hasQty = true;
11618:                 items.push({ itemCode: details[j].item_code || '', itemName: details[j].item_name || '', unit: details[j].unit || 'حبة', receivedQty: qty });
11619:             }
11620:             if (!hasQty) { Swal.showValidationMessage('أدخل كمية واحدة على الأقل للاستلام'); return false; }
11621:             return items;
11622:         }
11623:     });
11624:     if (!result.isConfirmed) return;
11625:     var positiveItems = (result.value || []).filter(function(x) { return Number(x.receivedQty || 0) > 0; }).sort(function(a,b) { return String(a.itemCode).localeCompare(String(b.itemCode)); });
11626:     var operationId = 'UI-RECEIVE:' + companyId + ':' + voucherRes.data.id + ':' + positiveItems.map(function(x) { return String(x.itemCode) + ':' + Number(x.receivedQty); }).join('|');
11627:     showLoader('جاري الاستلام...');
11628:     var ses = await supabase.auth.getSession();
11629:     var token = ses.data.session ? ses.data.session.access_token : null;
11630:     if (!token) { hideLoader(); showToast('انتهت الجلسة', 'error'); return; }
11631:     try {
11632:         var res = await fetch(RW_SUPABASE_URL + '/functions/v1/receive-stock-voucher', {
11633:             method: 'POST',
11634:             headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Idempotency-Key': operationId },
11635:             body: JSON.stringify({ voucher_code: voucherCode, receivedItems: positiveItems, operation_id: operationId })
11636:         });
11637:         var json = await res.json();
11638:         hideLoader();
11639:         if (json.success) { showToast(json.msg || (json.duplicate ? 'تم تأكيد العملية السابقة' : 'تم الاستلام'), 'success'); loadVouchers(); }
11640:         else showToast(json.error || json.msg || 'فشل الاستلام', 'error');
11641:     } catch (e) { hideLoader(); showToast('فشل الاتصال بـ Edge Function', 'error'); }
11642: }
11643: 
11644: async function _openNewVoucherModal() {
11645:     var typeOptions =
11646:         '<option value="Transfer">تحويل داخلي</option>' +
11647:         '<option value="DirectSale">صرف سيارة بيع مباشر</option>' +
11648:         '<option value="DirectReturn">استلام مرتجع سيارة</option>' +
11649:         '<option value="SupplierReturn">مرتجع لمورد</option>';
11650: 
11651:     var html =
11652:         '<div class="text-right space-y-3">' +
11653:             '<div>' +
11654:                 '<label class="text-xs font-bold">نوع الإذن</label>' +
11655:                 '<select id="newVoucherType" class="swal2-input w-full">' +
11656:                     typeOptions +
11657:                 '</select>' +
11658:             '</div>' +
11659:         '</div>';
11660: 
11661:     var result = await Swal.fire({
11662:         title: 'إنشاء إذن مخزني جديد',
11663:         html: html,
11664:         showCancelButton: true,
11665:         confirmButtonText: 'متابعة',
11666:         cancelButtonText: 'إلغاء',
11667:         preConfirm: function() {
11668:             var type = document.getElementById('newVoucherType').value;
11669:             if (!type) {
11670:                 Swal.showValidationMessage('اختر نوع الإذن');
11671:                 return false;
11672:             }
11673:             return { type: type };
11674:         }
11675:     });
11676: 
11677:     if (!result.isConfirmed) return;
11678: 
11679:     loadVoucherForm(result.value.type);
11680: }
11681: 
11682:     // ==================== PICKING ====================
11683:     async function loadPicking() {
11684:         var c = byId('rw-page-container'); if (!c) return;
11685:         safeText(byId('rw-header-title'), 'التحضير (Picking)');
11686:         safeHTML(c, `<div class="p-4">
11687:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11688:                 <input type="text" id="pk-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyPicking()">
11689:                 <select id="pk-f-st" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyPicking()"><option value="">كل الحالات</option><option value="Open">Open</option>
11690: <option value="Confirmed">Confirmed</option></select>
11691:                 <button onclick="RW_Warehouse._applyPicking()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11692:             </div></div>
11693:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="pk-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11694:         </div>`);
11695:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11696: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11697: var res = await supabase.from('runsheets')
11698:     .select('*')
11699:     .eq('company_id', companyId)
11700:     .in('status', ['Open', 'Confirmed']);
11701:         window._pickingData = res.data || [];
11702:         _applyPicking();
11703:     }
11704:     function _applyPicking() {
11705:         var d = window._pickingData || [];
11706:         var id = (byId('pk-f-id')?.value||'').toLowerCase(), st = byId('pk-f-st')?.value;
11707:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11708:         if (st) d = d.filter(function(r) { return r.status === st; });
11709:         var tb = byId('pk-table'); if (!tb) return;
11710:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات محضّرة</td></tr>'); return; }
11711:         RW_Table.paginate('pk-table', d, 1, 50, function(r) {
11712:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showPickingDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-purple-100 text-purple-700">Picked</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11713:         });
11714:     }
11715:     async function _showPickingDetails(code) {
11716:         showLoader('جاري التحميل...');
11717:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11718: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11719: var rsRes = await supabase.from('runsheets')
11720:     .select('id')
11721:     .eq('company_id', companyId)
11722:     .eq('runsheet_code', code)
11723:     .maybeSingle();
11724:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11725:         hideLoader();
11726:         var items = itemsRes.data || [];
11727:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11728:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المطلوبة</th><th class="p-2 text-center">الكمية المحضرة</th></tr></thead><tbody>';
11729:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_ordered||0) + '</td><td class="p-2 text-center font-bold text-purple-600">' + (it.qty_picked||0) + '</td></tr>'; });
11730:         h += '</tbody></table></div>';
11731:         Swal.fire({ title: 'تفاصيل التحضير: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11732:     }
11733: 
11734:     // ==================== LOADING ====================
11735:     async function loadLoading() {
11736:         var c = byId('rw-page-container'); if (!c) return;
11737:         safeText(byId('rw-header-title'), 'التحميل (Loading)');
11738:         safeHTML(c, `<div class="p-4">
11739:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11740:                 <input type="text" id="ld-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyLoading()">
11741:                 <select id="ld-f-st" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyLoading()"><option value="">كل الحالات</option><option>Loaded</option></select>
11742:                 <button onclick="RW_Warehouse._applyLoading()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11743:             </div></div>
11744:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="ld-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11745:         </div>`);
11746:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11747: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11748: var res = await supabase.from('runsheets')
11749:     .select('*')
11750:     .eq('company_id', companyId)
11751:     .in('status', ['Loaded']);
11752:         window._loadingData = res.data || [];
11753:         _applyLoading();
11754:     }
11755:     function _applyLoading() {
11756:         var d = window._loadingData || [];
11757:         var id = (byId('ld-f-id')?.value||'').toLowerCase(), st = byId('ld-f-st')?.value;
11758:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11759:         if (st) d = d.filter(function(r) { return r.status === st; });
11760:         var tb = byId('ld-table'); if (!tb) return;
11761:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات محمّلة</td></tr>'); return; }
11762:         RW_Table.paginate('ld-table', d, 1, 50, function(r) {
11763:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showLoadingDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-orange-100 text-orange-700">Loaded</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11764:         });
11765:     }
11766:     async function _showLoadingDetails(code) {
11767:         showLoader('جاري التحميل...');
11768: 
11769:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11770:         if (!companyId) {
11771:             hideLoader();
11772:             showToast('سياق الشركة غير محدد', 'error');
11773:             return;
11774:         }
11775: 
11776:         try {
11777:             var rsRes = await supabase.from('runsheets')
11778:                 .select('id')
11779:                 .eq('company_id', companyId)
11780:                 .eq('runsheet_code', code)
11781:                 .maybeSingle();
11782: 
11783:             if (rsRes.error) throw rsRes.error;
11784:             if (!rsRes.data) {
11785:                 hideLoader();
11786:                 showToast('الرانشيت غير موجود في الشركة الحالية', 'error');
11787:                 return;
11788:             }
11789: 
11790:             var itemsRes = await supabase.from('run_sheet_details')
11791:                 .select('*')
11792:                 .eq('runsheet_id', rsRes.data.id);
11793: 
11794:             if (itemsRes.error) throw itemsRes.error;
11795: 
11796:             hideLoader();
11797: 
11798:             var items = itemsRes.data || [];
11799:             if (!items.length) {
11800:                 showToast('لا توجد أصناف', 'info');
11801:                 return;
11802:             }
11803: 
11804:             var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المحضّرة</th><th class="p-2 text-center">الكمية المحمّلة</th></tr></thead><tbody>';
11805:             items.forEach(it => {
11806:                 h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_picked||0) + '</td><td class="p-2 text-center font-bold text-orange-600">' + (it.qty_loaded||0) + '</td></tr>';
11807:             });
11808:             h += '</tbody></table></div>';
11809: 
11810:             Swal.fire({
11811:                 title: 'تفاصيل التحميل: ' + code,
11812:                 html: h,
11813:                 width: '700px',
11814:                 showCloseButton: true,
11815:                 showConfirmButton: false
11816:             });
11817:         } catch (e) {
11818:             hideLoader();
11819:             showToast('فشل تحميل تفاصيل التحميل: ' + (e.message || ''), 'error');
11820:         }
11821:     }
11822: 
11823:     // ==================== DELIVERY ====================
11824:     async function loadDelivery() {
11825:         var c = byId('rw-page-container'); if (!c) return;
11826:         safeText(byId('rw-header-title'), 'التوصيل (Delivery)');
11827:         safeHTML(c, `<div class="p-4">
11828:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11829:                 <input type="text" id="dv-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyDelivery()">
11830:                 <button onclick="RW_Warehouse._applyDelivery()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11831:             </div></div>
11832:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="dv-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11833:         </div>`);
11834:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11835: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11836: var res = await supabase.from('runsheets')
11837:     .select('*')
11838:     .eq('company_id', companyId)
11839:     .in('status', ['Delivered']);
11840:         window._deliveryData = res.data || [];
11841:         _applyDelivery();
11842:     }
11843:     function _applyDelivery() {
11844:         var d = window._deliveryData || [];
11845:         var id = (byId('dv-f-id')?.value||'').toLowerCase();
11846:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11847:         var tb = byId('dv-table'); if (!tb) return;
11848:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات موصّلة</td></tr>'); return; }
11849:         RW_Table.paginate('dv-table', d, 1, 50, function(r) {
11850:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showDeliveryDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-green-100 text-green-700">Delivered</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11851:         });
11852:     }
11853:     async function _showDeliveryDetails(code) {
11854:         showLoader('جاري التحميل...');
11855:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11856: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11857:         var rsRes = await supabase.from('runsheets')
11858:     .select('id')
11859:     .eq('company_id', companyId)
11860:     .eq('runsheet_code', code)
11861:     .maybeSingle();
11862:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11863:         hideLoader();
11864:         var items = itemsRes.data || [];
11865:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11866:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المحمّلة</th><th class="p-2 text-center">الكمية المسلّمة</th></tr></thead><tbody>';
11867:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_loaded||0) + '</td><td class="p-2 text-center font-bold text-green-600">' + (it.qty_delivered||0) + '</td></tr>'; });
11868:         h += '</tbody></table></div>';
11869:         Swal.fire({ title: 'تفاصيل التوصيل: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11870:     }
11871: 
11872:     // ==================== RETURN ====================
11873:     async function loadReturn() {
11874:         var c = byId('rw-page-container'); if (!c) return;
11875:         safeText(byId('rw-header-title'), 'المرتجعات (Return)');
11876:         safeHTML(c, `<div class="p-4">
11877:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11878:                 <input type="text" id="rt-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReturn()">
11879:                 <button onclick="RW_Warehouse._applyReturn()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11880:             </div></div>
11881:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="rt-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11882:         </div>`);
11883:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11884: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11885: var res = await supabase.from('runsheets')
11886:     .select('*')
11887:     .eq('company_id', companyId)
11888:     .in('status', ['Returned']);
11889:         window._returnData = res.data || [];
11890:         _applyReturn();
11891:     }
11892:     function _applyReturn() {
11893:         var d = window._returnData || [];
11894:         var id = (byId('rt-f-id')?.value||'').toLowerCase();
11895:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11896:         var tb = byId('rt-table'); if (!tb) return;
11897:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات مرتجعة</td></tr>'); return; }
11898:         RW_Table.paginate('rt-table', d, 1, 50, function(r) {
11899:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showReturnDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-rose-100 text-rose-700">Returned</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11900:         });
11901:     }
11902:     async function _showReturnDetails(code) {
11903:         showLoader('جاري التحميل...');
11904:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11905: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11906: var rsRes = await supabase.from('runsheets')
11907:     .select('id')
11908:     .eq('company_id', companyId)
11909:     .eq('runsheet_code', code)
11910:     .maybeSingle();
11911:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11912:         hideLoader();
11913:         var items = itemsRes.data || [];
11914:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11915:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المسلّمة</th><th class="p-2 text-center">الكمية المرتجعة</th></tr></thead><tbody>';
11916:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_delivered||0) + '</td><td class="p-2 text-center font-bold text-rose-600">' + (it.qty_returned||0) + '</td></tr>'; });
11917:         h += '</tbody></table></div>';
11918:         Swal.fire({ title: 'تفاصيل المرتجعات: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11919:     }
11920: 
11921:     // ==================== UNLOADING ====================
11922:     async function loadUnloading() {
11923:         var c = byId('rw-page-container');
11924:         if (!c) return;
11925: 
11926:         safeText(byId('rw-header-title'), 'التفريغ (Unloading)');
11927:         safeHTML(c, '<div class="p-4">' +
11928:             '<div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">' +
11929:                 '<div class="grid grid-cols-2 md:grid-cols-6 gap-2">' +
11930:                     '<input type="text" id="ul-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyUnloading()">' +
11931:                     '<button onclick="RW_Warehouse._applyUnloading()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>' +
11932:                 '</div>' +
11933:             '</div>' +
11934:             '<div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh">' +
11935:                 '<table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr>' +
11936:                     '<th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th>' +
11937:                 '</tr></thead><tbody id="ul-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table>' +
11938:             '</div>' +
11939:         '</div>');
11940: 
11941:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11942:         if (!companyId) {
11943:             showToast('سياق الشركة غير محدد', 'error');
11944:             return;
11945:         }
11946: 
11947:         var res = await supabase.from('runsheets')
11948:             .select('id,runsheet_code,run_date,driver_id,vehicle_id,status')
11949:             .eq('company_id', companyId)
11950:             .eq('status', 'Loaded')
11951:             .order('run_date', { ascending: false });
11952: 
11953:         if (res.error) {
11954:             showToast(res.error.message, 'error');
11955:             return;
11956:         }
11957: 
11958:         window._unloadingData = res.data || [];
11959:         _applyUnloading();
11960:     }
11961: 
11962:     function _applyUnloading() {
11963:         var d = window._unloadingData || [];
11964:         var id = (byId('ul-f-id')?.value || '').trim().toLowerCase();
11965:         if (id) {
11966:             d = d.filter(function(r) {
11967:                 return String(r.runsheet_code || '').toLowerCase().indexOf(id) !== -1;
11968:             });
11969:         }
11970: 
11971:         var tb = byId('ul-table');
11972:         if (!tb) return;
11973: 
11974:         if (!d.length) {
11975:             safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات جاهزة للتفريغ</td></tr>');
11976:             return;
11977:         }
11978: 
11979:         RW_Table.paginate('ul-table', d, 1, 50, function(r) {
11980:             var code = String(r.runsheet_code || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
11981:             return "<tr class=\"border-b hover:bg-gray-50 cursor-pointer\" onclick=\"RW_Warehouse._showUnloadingDetails('" + code + "')\">" +
11982:                 '<td class="p-3 font-bold">' + esc(r.runsheet_code || '') + '</td>' +
11983:                 '<td class="p-3">' + esc(r.run_date || '') + '</td>' +
11984:                 '<td class="p-3">' + esc(r.driver_id || '---') + '</td>' +
11985:                 '<td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-orange-100 text-orange-700">Loaded</span></td>' +
11986:                 "<td class=\"p-3 text-center\"><button class=\"text-blue-600\" onclick=\"event.stopPropagation(); RW_Warehouse._showUnloadingDetails('" + code + "')\"><i class=\"fa-solid fa-eye\"></i></button></td>" +
11987:             '</tr>';
11988:         });
11989:     }
11990: 
11991:     async function _showUnloadingDetails(code) {
11992:         if (!code) {
11993:             showToast('رقم الرانشيت غير صالح', 'error');
11994:             return;
11995:         }
11996: 
11997:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11998:         if (!companyId) {
11999:             showToast('سياق الشركة غير محدد', 'error');
12000:             return;
12001:         }
12002: 
12003:         showLoader('جاري تحميل تفاصيل التفريغ...');
12004:         try {
12005:             var rsRes = await supabase.from('runsheets')
12006:                 .select('id,runsheet_code,run_date,driver_id,vehicle_id,status')
12007:                 .eq('company_id', companyId)
12008:                 .eq('runsheet_code', code)
12009:                 .maybeSingle();
12010: 
12011:             if (rsRes.error) throw rsRes.error;
12012:             if (!rsRes.data) throw new Error('الرانشيت غير موجود في الشركة الحالية');
12013:             if (rsRes.data.status !== 'Loaded') throw new Error('الرانشيت ليس في حالة Loaded؛ لا يمكن اعتباره جاهزًا للتفريغ');
12014: 
12015:             var detailsRes = await supabase.from('run_sheet_details')
12016:                 .select('item_code,item_name,unit,qty_ordered,qty_picked,qty_loaded,qty_delivered,qty_refused,qty_returned')
12017:                 .eq('runsheet_id', rsRes.data.id)
12018:                 .order('item_code');
12019: 
12020:             if (detailsRes.error) throw detailsRes.error;
12021: 
12022:             var details = detailsRes.data || [];
12023:             if (!details.length) {
12024:                 hideLoader();
12025:                 showToast('لا توجد تفاصيل أصناف لهذا الرانشيت', 'info');
12026:                 return;
12027:             }
12028: 
12029:             var loadedTotal = 0;
12030:             var remainingTotal = 0;
12031:             var html = '<div class="text-right" dir="rtl">';
12032:             html += '<div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">' +
12033:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">الرانشيت</div><div class="font-black">' + esc(rsRes.data.runsheet_code) + '</div></div>' +
12034:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">السائق</div><div class="font-bold">' + esc(rsRes.data.driver_id || '---') + '</div></div>' +
12035:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">السيارة</div><div class="font-bold">' + esc(rsRes.data.vehicle_id || '---') + '</div></div>' +
12036:             '</div>';
12037:             html += '<div class="mb-3 p-3 bg-orange-50 border border-orange-100 rounded-xl text-sm font-bold text-orange-800">هذه الشاشة للعرض والتأكد من الحمولة قبل التفريغ. تنفيذ التفريغ نفسه يتم عبر <code>unload-runsheet</code> ولا يتم هنا إجراء أي تعديل مخزني.</div>';
12038:             html += '<div class="overflow-auto max-h-[55vh]"><table class="w-full border text-sm"><thead class="bg-gray-100 sticky top-0"><tr>' +
12039:                 '<th class="p-2 border">الكود</th><th class="p-2 border">الصنف</th><th class="p-2 border text-center">الوحدة</th><th class="p-2 border text-center">محمّل</th><th class="p-2 border text-center">مسلّم</th><th class="p-2 border text-center">مرفوض</th><th class="p-2 border text-center">مرتجع</th><th class="p-2 border text-center">المتبقي</th>' +
12040:                 '</tr></thead><tbody>';
12041: 
12042:             for (var i = 0; i < details.length; i++) {
12043:                 var d = details[i];
12044:                 var loaded = Number(d.qty_loaded) || 0;
12045:                 var delivered = Number(d.qty_delivered) || 0;
12046:                 var refused = Number(d.qty_refused) || 0;
12047:                 var returned = Number(d.qty_returned) || 0;
12048:                 var remaining = Math.max(0, loaded - delivered - refused - returned);
12049:                 loadedTotal += loaded;
12050:                 remainingTotal += remaining;
12051: 
12052:                 html += '<tr class="border-b">' +
12053:                     '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
12054:                     '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
12055:                     '<td class="p-2 border text-center">' + esc(d.unit || 'حبة') + '</td>' +
12056:                     '<td class="p-2 border text-center font-bold text-orange-700">' + loaded + '</td>' +
12057:                     '<td class="p-2 border text-center">' + delivered + '</td>' +
12058:                     '<td class="p-2 border text-center">' + refused + '</td>' +
12059:                     '<td class="p-2 border text-center">' + returned + '</td>' +
12060:                     '<td class="p-2 border text-center font-black ' + (remaining > 0 ? 'text-red-600' : 'text-emerald-600') + '">' + remaining + '</td>' +
12061:                 '</tr>';
12062:             }
12063: 
12064:             html += '</tbody></table></div>';
12065:             html += '<div class="mt-4 grid grid-cols-2 gap-3">' +
12066:                 '<div class="bg-orange-50 rounded-xl p-3 text-center"><div class="text-xs text-slate-500">إجمالي المحمّل</div><div class="text-xl font-black text-orange-700">' + loadedTotal + '</div></div>' +
12067:                 '<div class="bg-slate-50 rounded-xl p-3 text-center"><div class="text-xs text-slate-500">المتبقي قبل التفريغ</div><div class="text-xl font-black">' + remainingTotal + '</div></div>' +
12068:             '</div></div>';
12069: 
12070:             hideLoader();
12071:             Swal.fire({
12072:                 title: 'تفاصيل التفريغ: ' + esc(code),
12073:                 html: html,
12074:                 width: '1100px',
12075:                 showCloseButton: true,
12076:                 showConfirmButton: false
12077:             });
12078:         } catch (e) {
12079:             hideLoader();
12080:             showToast(e.message || 'فشل تحميل تفاصيل التفريغ', 'error');
12081:         }
12082:     }
12083:     // ==================== COUNT (الجرد) & SETTLEMENT (إغلاق اليومية) ====================
12084:     async function loadVehicleCount() {
12085:         var c = byId('rw-page-container'); if (!c) return;
12086:         safeText(byId('rw-header-title'), 'جرد سيارة');
12087:         safeHTML(c, `<div class="p-4">
12088:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 grid grid-cols-1 md:grid-cols-3 gap-4">
12089:                 <div>
12090:                     <label class="text-xs font-bold block mb-1">المندوب</label>
12091:                     <input type="text" id="vc-driver-search" oninput="RW_Warehouse._searchDriver(this.value)" autocomplete="off" placeholder="ابحث باسم أو بريد المندوب..." class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 focus:border-blue-500 outline-none">
12092:                     <div id="vc-driver-results" class="absolute z-50 bg-white shadow-xl rounded-xl max-h-48 overflow-y-auto hidden border mt-1" style="width:calc(33%-2rem);"></div>
12093:                 </div>
12094:                 <div>
12095:                     <label class="text-xs font-bold block mb-1">الرانشيت (اختياري)</label>
12096:                     <select id="vc-runsheet-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold"><option value="">-- اختر --</option></select>
12097:                 </div>
12098:                 <div>
12099:                     <label class="text-xs font-bold block mb-1">ملاحظات</label>
12100:                     <input id="vc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات...">
12101:                 </div>
12102:             </div>
12103:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12104:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12105:                 <div class="relative">
12106:                     <input type="text" id="vc-item-search" oninput="RW_Warehouse._searchInvItem('vc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg">
12107:                     <button onclick="RW_Warehouse._startBarcodeScanner('vc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button>
12108:                 </div>
12109:                 <div id="vc-item-results" class="absolute z-50 left-0 right-0 mt-1 bg-white shadow-xl rounded-xl max-h-60 overflow-y-auto hidden border"></div>
12110:             </div>
12111:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;">
12112:                 <table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="vc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table>
12113:             </div>
12114:             <div class="mt-2">عدد الأصناف: <span id="vc-cart-count">0</span></div>
12115:             <div class="mt-4 flex justify-end gap-3">
12116:                 <button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('vc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button>
12117:                 <button onclick="RW_Warehouse._saveVehicleCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button>
12118:             </div>
12119:         </div>`);
12120:         
12121:         window._selectedDriver = null;
12122:         window._invCart = [];
12123:         _renderInvCart('vc');
12124:         
12125:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12126: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12127: var runsheetsRes = await supabase.from('runsheets')
12128:     .select('runsheet_code, driver_id')
12129:     .eq('company_id', companyId)
12130:     .in('status', ['Loaded', 'Delivering', 'Delivered', 'Returning']);
12131:         var sel = byId('vc-runsheet-select');
12132:         if (sel && runsheetsRes.data) {
12133:             for (var i = 0; i < runsheetsRes.data.length; i++) {
12134:                 var r = runsheetsRes.data[i];
12135:                 sel.innerHTML += '<option value="' + r.runsheet_code + '">' + r.runsheet_code + ' - ' + (r.driver_id || '') + '</option>';
12136:             }
12137:         }
12138:     }
12139: 
12140:     async function _searchDriver(query) {
12141:         var div = byId('vc-driver-results'); if (!div) return;
12142:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
12143:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12144: if (!companyId) { div.classList.add('hidden'); return; }
12145: var res = await supabase.from('users')
12146:     .select('email, name')
12147:     .eq('company_id', companyId)
12148:     .in('role', ['driver','سائق','مندوب'])
12149:     .ilike('name', '%' + query + '%');
12150:         var drivers = res.data || [];
12151:         var q = query.toLowerCase();
12152:         var filtered = drivers.filter(function(d) { return (d.name || '').toLowerCase().indexOf(q) !== -1 || (d.email || '').toLowerCase().indexOf(q) !== -1; });
12153:         if (filtered.length > 0) {
12154:             var html = '';
12155:             for (var i = 0; i < filtered.length; i++) {
12156:                 var d = filtered[i];
12157:                 html += '<div onclick="RW_Warehouse._selectDriver(\'' + d.email + '\', \'' + (d.name || '').replace(/'/g, "\\'") + '\')" class="p-3 hover:bg-blue-50 cursor-pointer border-b"><div class="font-bold">' + d.name + '</div><div class="text-xs text-slate-400">' + d.email + '</div></div>';
12158:             }
12159:             safeHTML(div, html); div.classList.remove('hidden');
12160:         } else { div.classList.add('hidden'); }
12161:     }
12162: 
12163:     function _selectDriver(email, name) {
12164:         window._selectedDriver = email;
12165:         byId('vc-driver-search').value = name + ' (' + email + ')';
12166:         byId('vc-driver-results').classList.add('hidden');
12167:     }
12168: 
12169:     async function _startBarcodeScanner(prefix) {
12170:         var input = byId(prefix + '-item-search');
12171:         if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || typeof window.BarcodeDetector === 'undefined') {
12172:             if (input) {
12173:                 input.focus();
12174:                 input.select();
12175:             }
12176:             showToast('مسح الباركود بالكاميرا غير مدعوم في هذا المتصفح. استخدم البحث أو قارئ الباركود المتصل.', 'warning');
12177:             return;
12178:         }
12179: 
12180:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12181:         if (!companyId) {
12182:             showToast('سياق الشركة غير محدد', 'error');
12183:             return;
12184:         }
12185: 
12186:         var stream = null;
12187:         var timer = null;
12188:         var stopped = false;
12189:         var videoId = 'rw-barcode-video-' + Date.now();
12190: 
12191:         try {
12192:             var formats = ['ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'qr_code'];
12193:             try {
12194:                 if (BarcodeDetector.getSupportedFormats) {
12195:                     var supported = await BarcodeDetector.getSupportedFormats();
12196:                     formats = formats.filter(function(f) { return supported.indexOf(f) !== -1; });
12197:                 }
12198:             } catch (_) {}
12199: 
12200:             var detector = formats.length ? new BarcodeDetector({ formats: formats }) : new BarcodeDetector();
12201: 
12202:             var result = await Swal.fire({
12203:                 title: 'مسح الباركود',
12204:                 html: '<div class="text-center"><div class="mb-3 text-sm text-slate-500">وجّه الكاميرا إلى باركود الصنف</div><div class="relative overflow-hidden rounded-2xl bg-black"><video id="' + videoId + '" autoplay muted playsinline style="width:100%;max-height:420px;object-fit:cover"></video><div class="absolute inset-6 border-2 border-emerald-400 rounded-xl pointer-events-none"></div></div></div>',
12205:                 width: '650px',
12206:                 showCancelButton: true,
12207:                 confirmButtonText: 'إغلاق',
12208:                 cancelButtonText: 'إلغاء',
12209:                 showConfirmButton: false,
12210:                 allowOutsideClick: false,
12211:                 didOpen: async function() {
12212:                     try {
12213:                         stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
12214:                         var video = document.getElementById(videoId);
12215:                         if (!video) throw new Error('تعذر تشغيل كاميرا المسح');
12216:                         video.srcObject = stream;
12217:                         await video.play();
12218: 
12219:                         var lastRaw = '';
12220:                         var lastToastAt = 0;
12221:                         var scan = async function() {
12222:                             if (stopped) return;
12223:                             try {
12224:                                 if (video.readyState >= 2) {
12225:                                     var codes = await detector.detect(video);
12226:                                     if (codes && codes.length) {
12227:                                         var raw = String(codes[0].rawValue || '').trim();
12228:                                         if (raw && raw !== lastRaw) {
12229:                                             lastRaw = raw;
12230:                                             var items = (RW_STATE.data && RW_STATE.data.items) || [];
12231:                                             var matched = null;
12232:                                             for (var i = 0; i < items.length; i++) {
12233:                                                 var item = items[i];
12234:                                                 if (String(item.barcode || '').trim() === raw || String(item.item_code || '').trim() === raw) {
12235:                                                     matched = item;
12236:                                                     break;
12237:                                                 }
12238:                                             }
12239: 
12240:                                             if (!matched) {
12241:                                                 var now = Date.now();
12242:                                                 if (now - lastToastAt > 1500) {
12243:                                                     showToast('لم يتم العثور على صنف لهذا الباركود: ' + raw, 'warning');
12244:                                                     lastToastAt = now;
12245:                                                 }
12246:                                             } else {
12247:                                                 _addToInvCart(prefix, matched.item_code);
12248:                                                 if (input) {
12249:                                                     input.value = '';
12250:                                                     input.focus();
12251:                                                 }
12252:                                                 Swal.close();
12253:                                                 return;
12254:                                             }
12255:                                         }
12256:                                     }
12257:                                 }
12258:                             } catch (e) {
12259:                                 console.warn('BarcodeDetector scan error', e);
12260:                             }
12261:                             timer = setTimeout(function() { lastRaw = ''; scan(); }, 350);
12262:                         };
12263:                         scan();
12264:                     } catch (e) {
12265:                         showToast('تعذر الوصول إلى الكاميرا: ' + (e.message || ''), 'error');
12266:                         if (input) {
12267:                             input.focus();
12268:                             input.select();
12269:                         }
12270:                         Swal.close();
12271:                     }
12272:                 },
12273:                 willClose: function() {
12274:                     stopped = true;
12275:                     if (timer) {
12276:                         clearTimeout(timer);
12277:                         timer = null;
12278:                     }
12279:                     if (stream) {
12280:                         var tracks = stream.getTracks ? stream.getTracks() : [];
12281:                         for (var i = 0; i < tracks.length; i++) tracks[i].stop();
12282:                         stream = null;
12283:                     }
12284:                 }
12285:             });
12286: 
12287:             return result;
12288:         } catch (e) {
12289:             stopped = true;
12290:             if (timer) clearTimeout(timer);
12291:             if (stream) {
12292:                 var tracks = stream.getTracks ? stream.getTracks() : [];
12293:                 for (var j = 0; j < tracks.length; j++) tracks[j].stop();
12294:             }
12295:             if (input) {
12296:                 input.focus();
12297:                 input.select();
12298:             }
12299:             showToast(e.message || 'فشل تشغيل قارئ الباركود', 'error');
12300:             return null;
12301:         }
12302:     }
12303: 
12304:     function _searchInvItem(prefix, query) {
12305:         var div = byId(prefix + '-item-results'); if (!div) return;
12306:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
12307:         var items = RW_STATE.data.items || [];
12308:         var q = query.toLowerCase();
12309:         var filtered = items.filter(function(i) { return (i.name || '').toLowerCase().indexOf(q) !== -1 || (i.item_code || '').toLowerCase().indexOf(q) !== -1 || (i.barcode || '').toLowerCase().indexOf(q) !== -1; });
12310:         if (filtered.length > 0) {
12311:             var html = '';
12312:             for (var idx = 0; idx < Math.min(filtered.length, 30); idx++) {
12313:                 var item = filtered[idx];
12314:                 html += '<div onclick="RW_Warehouse._addToInvCart(\'' + prefix + '\', \'' + item.item_code + '\')" class="p-3 hover:bg-blue-50 cursor-pointer border-b flex items-center"><div><div class="font-bold">' + item.name + '</div><div class="text-xs text-slate-400">كود: ' + item.item_code + ' | رصيد: ' + (item.qty || 0) + '</div></div></div>';
12315:             }
12316:             safeHTML(div, html); div.classList.remove('hidden');
12317:         } else { safeHTML(div, '<div class="p-3 text-center text-gray-400">لا توجد نتائج</div>'); div.classList.remove('hidden'); }
12318:     }
12319: 
12320:     function _addToInvCart(prefix, itemCode) {
12321:         var items = RW_STATE.data.items || [], item = null;
12322:         for (var i = 0; i < items.length; i++) { if (items[i].item_code === itemCode) { item = items[i]; break; } }
12323:         if (!item) return;
12324:         var existing = null;
12325:         for (var j = 0; j < window._invCart.length; j++) { if (window._invCart[j].code === itemCode) { existing = window._invCart[j]; break; } }
12326:         if (existing) { existing.qty = (parseInt(existing.qty) || 0) + 1; } else { window._invCart.push({ code: item.item_code, name: item.name, unit: item.unit || 'حبة', qty: 1 }); }
12327:         byId(prefix + '-item-search').value = '';
12328:         byId(prefix + '-item-results').classList.add('hidden');
12329:         _renderInvCart(prefix);
12330:     }
12331: 
12332:     function _renderInvCart(prefix) {
12333:         var tbody = byId(prefix + '-cart-table'), countSpan = byId(prefix + '-cart-count');
12334:         if (!tbody) return;
12335:         if (window._invCart.length === 0) { safeHTML(tbody, '<tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr>'); if (countSpan) countSpan.innerText = '0'; return; }
12336:         var html = '';
12337:         for (var i = 0; i < window._invCart.length; i++) {
12338:             var it = window._invCart[i];
12339:             html += '<tr class="border-b hover:bg-slate-50"><td class="p-2"><div class="font-bold">' + it.name + '</div><div class="text-xs">' + it.code + '</div></td><td class="p-2 text-center">' + it.unit + '</td><td class="p-2 text-center"><input type="number" value="' + it.qty + '" onchange="RW_Warehouse._updateInvCartQty(' + i + ', this.value, \'' + prefix + '\')" class="w-20 p-1 border rounded text-center" min="0"></td><td class="p-2 text-center"><button onclick="RW_Warehouse._removeInvCartItem(' + i + ', \'' + prefix + '\')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>';
12340:         }
12341:         safeHTML(tbody, html);
12342:         if (countSpan) countSpan.innerText = String(window._invCart.length);
12343:     }
12344: 
12345:     function _updateInvCartQty(idx, val, prefix) {
12346:         var q = parseInt(val);
12347:         if (isNaN(q) || q <= 0) { window._invCart.splice(idx, 1); } else { window._invCart[idx].qty = q; }
12348:         _renderInvCart(prefix);
12349:     }
12350: 
12351:     function _removeInvCartItem(idx, prefix) { window._invCart.splice(idx, 1); _renderInvCart(prefix); }
12352: 
12353: async function _saveVehicleCount() {
12354:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12355:     var selectedDriver = window._selectedDriver || '';
12356:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12357:     if (!selectedDriver) { showToast('يجب اختيار مندوب', 'warning'); return; }
12358: 
12359:     var reference = (byId('vc-runsheet-select') ? byId('vc-runsheet-select').value : '') || '';
12360:     var notes = (byId('vc-notes') ? byId('vc-notes').value : '') || '';
12361:     if (notes) reference = reference ? reference + ' | ' + notes : notes;
12362: 
12363:     var selectedRunsheet = (byId('vc-runsheet-select') ? byId('vc-runsheet-select').value : '') || '';
12364:     var vehicleId = null;
12365: 
12366:     var userRes = await supabase.from('users')
12367:         .select('id')
12368:         .eq('company_id', companyId)
12369:         .eq('email', selectedDriver)
12370:         .maybeSingle();
12371:     if (userRes.error) { showToast(userRes.error.message, 'error'); return; }
12372:     var driverId = userRes.data ? userRes.data.id : null;
12373: 
12374:     if (selectedRunsheet) {
12375:         var rsRes = await supabase.from('runsheets')
12376:             .select('vehicle_id')
12377:             .eq('company_id', companyId)
12378:             .eq('runsheet_code', selectedRunsheet)
12379:             .maybeSingle();
12380:         if (rsRes.error) { showToast(rsRes.error.message, 'error'); return; }
12381:         vehicleId = rsRes.data ? rsRes.data.vehicle_id : null;
12382:     }
12383: 
12384:     if (!vehicleId && driverId) {
12385:         var vehicleRes = await supabase.from('vehicles')
12386:             .select('id')
12387:             .eq('company_id', companyId)
12388:             .eq('driver_id', driverId)
12389:             .limit(1)
12390:             .maybeSingle();
12391:         if (vehicleRes.error) { showToast(vehicleRes.error.message, 'error'); return; }
12392:         vehicleId = vehicleRes.data ? vehicleRes.data.id : null;
12393:     }
12394: 
12395:     if (!vehicleId) { showToast('لا توجد مركبة مرتبطة بهذا المندوب', 'warning'); return; }
12396:     await _saveInvCount('vehicle', vehicleId, reference || 'جرد سيارة');
12397: }
12398: 
12399:     async function _saveInvCount(type, entityId, reference) {
12400:         if (!window._invCart || window._invCart.length === 0) {
12401:             showToast('أضف أصنافاً', 'warning');
12402:             return;
12403:         }
12404:         if (!entityId) {
12405:             showToast('الكيان المستهدف للجرد غير محدد', 'warning');
12406:             return;
12407:         }
12408: 
12409:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12410:         if (!companyId) {
12411:             showToast('سياق الشركة غير محدد', 'error');
12412:             return;
12413:         }
12414: 
12415:         var items = [];
12416:         for (var i = 0; i < window._invCart.length; i++) {
12417:             var q = parseInt(window._invCart[i].qty, 10) || 0;
12418:             if (q < 0) {
12419:                 showToast('كمية الجرد لا يمكن أن تكون سالبة', 'warning');
12420:                 return;
12421:             }
12422:             items.push({
12423:                 itemCode: window._invCart[i].code,
12424:                 itemName: window._invCart[i].name,
12425:                 unit: window._invCart[i].unit,
12426:                 qty: q,
12427:                 unitPrice: 0,
12428:                 notes: ''
12429:             });
12430:         }
12431: 
12432:         var prefix = type === 'vehicle' ? 'vc' : (type === 'branch' ? 'bc' : 'gc');
12433:         showLoader('جاري حفظ الجرد...');
12434:         try {
12435:             var ses = await supabase.auth.getSession();
12436:             var token = ses.data.session ? ses.data.session.access_token : null;
12437:             if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
12438: 
12439:             var res = await fetch(RW_SUPABASE_URL + '/functions/v1/save-inventory-count', {
12440:                 method: 'POST',
12441:                 headers: {
12442:                     'Content-Type': 'application/json',
12443:                     'Authorization': 'Bearer ' + token
12444:                 },
12445:                 body: JSON.stringify({
12446:                     type: type,
12447:                     entityId: entityId,
12448:                     reference: reference,
12449:                     items: items
12450:                 })
12451:             });
12452: 
12453:             var json = await res.json().catch(function() { return {}; });
12454:             if (!res.ok || !json || !json.success) {
12455:                 throw new Error((json && (json.msg || json.error)) || 'فشل حفظ الجرد');
12456:             }
12457: 
12458:             hideLoader();
12459:             window._invCart = [];
12460:             _renderInvCart(prefix);
12461:             showToast(json.msg || ('تم حفظ الجرد ' + (json.count_id || '')), 'success');
12462:         } catch (e) {
12463:             hideLoader();
12464:             showToast(e.message || 'فشل الاتصال', 'error');
12465:         }
12466:     }
12467: 
12468:     async function loadBranchCount() {
12469:         var c = byId('rw-page-container'); if (!c) return;
12470:         safeText(byId('rw-header-title'), 'جرد فرع');
12471:         var branches = RW_STATE.data.branches || [];
12472:         safeHTML(c, `<div class="p-4">
12473:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 grid grid-cols-1 md:grid-cols-3 gap-4">
12474:                 <div><label class="text-xs font-bold block mb-1">الفرع</label><select id="bc-branch-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold"><option value="">-- اختر --</option>${branches.map(b => '<option value="' + (b.id || b.branch_code || '') + '">' + (b.name || b.branch_name || '') + '</option>').join('')}</select></div>
12475:                 <div><label class="text-xs font-bold block mb-1">القسم / الرف</label><input id="bc-section" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="مثلاً: رف A-1"></div>
12476:                 <div><label class="text-xs font-bold block mb-1">ملاحظات</label><input id="bc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات..."></div>
12477:             </div>
12478:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12479:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12480: <div class="relative"><input type="text" id="bc-item-search" oninput="RW_Warehouse._searchInvItem('bc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg"><button onclick="RW_Warehouse._startBarcodeScanner('bc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button></div>
12481:             </div>
12482:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="bc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table></div>
12483:             <div class="mt-2">عدد الأصناف: <span id="bc-cart-count">0</span></div>
12484:             <div class="mt-4 flex justify-end gap-3"><button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('bc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button><button onclick="RW_Warehouse._saveBranchCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button></div>
12485:         </div>`);
12486:         window._invCart = []; _renderInvCart('bc');
12487:     }
12488: 
12489:     async function _saveBranchCount() {
12490:         var entityId = (byId('bc-branch-select') ? byId('bc-branch-select').value : '') || '';
12491:         if (!entityId) { showToast('يجب اختيار فرع', 'warning'); return; }
12492:         var section = (byId('bc-section') ? byId('bc-section').value : '') || '';
12493:         var notes = (byId('bc-notes') ? byId('bc-notes').value : '') || '';
12494:         var reference = section ? ('قسم: ' + section) : '';
12495:         if (notes) reference = reference ? reference + ' | ' + notes : notes;
12496:         await _saveInvCount('branch', entityId, reference || 'جرد فرع');
12497:     }
12498: 
12499:     async function loadGeneralCount() {
12500:         var c = byId('rw-page-container'); if (!c) return;
12501:         safeText(byId('rw-header-title'), 'جرد عام');
12502:         safeHTML(c, `<div class="p-4">
12503:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><input id="gc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات الجرد العام..."></div>
12504:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12505:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12506: <div class="relative"><input type="text" id="gc-item-search" oninput="RW_Warehouse._searchInvItem('gc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg"><button onclick="RW_Warehouse._startBarcodeScanner('gc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button></div>
12507:             </div>
12508:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="gc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table></div>
12509:             <div class="mt-2">عدد الأصناف: <span id="gc-cart-count">0</span></div>
12510:             <div class="mt-4 flex justify-end gap-3"><button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('gc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button><button onclick="RW_Warehouse._saveGeneralCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button></div>
12511:         </div>`);
12512:         window._invCart = []; _renderInvCart('gc');
12513:     }
12514: 
12515: async function _saveGeneralCount() {
12516:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12517:     var notes = (byId('gc-notes') ? byId('gc-notes').value : '') || '';
12518:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12519: 
12520:     var settingsRes = await supabase.from('app_settings')
12521:         .select('main_branch_id')
12522:         .eq('company_id', companyId)
12523:         .order('created_at', { ascending: true })
12524:         .limit(1)
12525:         .maybeSingle();
12526:     if (settingsRes.error) { showToast(settingsRes.error.message, 'error'); return; }
12527: 
12528:     var mainBranchId = settingsRes.data ? settingsRes.data.main_branch_id : null;
12529:     if (!mainBranchId) { showToast('الفرع الرئيسي غير محدد', 'error'); return; }
12530: 
12531:     await _saveInvCount('general', mainBranchId, 'جرد عام' + (notes ? ' | ' + notes : ''));
12532: }
12533: 
12534:     // ==================== SETTLEMENT (إغلاق اليومية) ====================
12535:     async function loadSettlement() {
12536:         var c = byId('rw-page-container'); if (!c) return;
12537:         safeText(byId('rw-header-title'), 'إغلاق اليومية');
12538:         safeHTML(c, `<div class="p-4">
12539:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">
12540:                 <label class="text-xs font-bold block mb-2">اختيار الرانشيت</label>
12541:                 <select id="settlement-rs-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold" onchange="RW_Warehouse._onSettlementRsChange()"><option value="">-- اختر رانشيتاً --</option></select>
12542:                 <div id="settlement-rs-info" class="mt-3 text-sm text-slate-500"></div>
12543:             </div>
12544:             <div id="settlement-details-container" class="hidden">
12545:                 <div class="bg-white rounded-xl shadow-sm overflow-auto mb-4" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white sticky top-0"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">محمّلة</th><th class="p-2 text-center">مسلّمة</th><th class="p-2 text-center">مرتجعة</th><th class="p-2 text-center">مجرودة</th><th class="p-2 text-center">العجز</th><th class="p-2 text-center">قيمة العجز</th></tr></thead><tbody id="settlement-items-body"><tr><td colspan="7" class="p-6 text-center">اختر رانشيتاً</td></tr></tbody></table></div>
12546:                 <div class="flex justify-end gap-2"><button onclick="RW_Warehouse._saveSettlement()" class="bg-emerald-600 text-white px-8 py-3 rounded-2xl font-black shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ التسوية وترحيل العجز</button></div>
12547:             </div>
12548:         </div>`);
12549:         
12550:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12551: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12552: var runsheetsRes = await supabase.from('runsheets')
12553:     .select('runsheet_code, driver_id')
12554:     .eq('company_id', companyId)
12555:     .in('status', ['Delivered', 'Returned']);
12556:         var sel = byId('settlement-rs-select');
12557:         if (sel && runsheetsRes.data) {
12558:             for (var i = 0; i < runsheetsRes.data.length; i++) {
12559:                 sel.innerHTML += '<option value="' + runsheetsRes.data[i].runsheet_code + '">' + runsheetsRes.data[i].runsheet_code + ' - ' + (runsheetsRes.data[i].driver_id || '') + '</option>';
12560:             }
12561:         }
12562:     }
12563: 
12564:     async function _onSettlementRsChange() {
12565:         var rsCode = byId('settlement-rs-select')?.value || '';
12566:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12567:         var detailsContainer = byId('settlement-details-container');
12568: 
12569:         if (!rsCode) {
12570:             if (detailsContainer) detailsContainer.classList.add('hidden');
12571:             window._settlementData = null;
12572:             return;
12573:         }
12574:         if (!companyId) {
12575:             showToast('سياق الشركة غير محدد', 'error');
12576:             return;
12577:         }
12578: 
12579:         showLoader('جاري تحميل بيانات التسوية...');
12580:         try {
12581:             var rsRes = await supabase.from('runsheets')
12582:                 .select('id,runsheet_code,status,driver_id,vehicle_id,run_date')
12583:                 .eq('company_id', companyId)
12584:                 .eq('runsheet_code', rsCode)
12585:                 .maybeSingle();
12586:             if (rsRes.error) throw rsRes.error;
12587:             if (!rsRes.data) throw new Error('الرانشيت غير موجود في الشركة الحالية');
12588:             if (['Delivered', 'Returned'].indexOf(rsRes.data.status) === -1) {
12589:                 throw new Error('التسوية متاحة فقط للرانشيتات التي وصلت إلى Delivered أو Returned');
12590:             }
12591: 
12592:             var detailsRes = await supabase.from('run_sheet_details')
12593:                 .select('item_code,item_name,unit,qty_loaded,qty_delivered,qty_returned,unit_price')
12594:                 .eq('runsheet_id', rsRes.data.id)
12595:                 .order('item_code');
12596:             if (detailsRes.error) throw detailsRes.error;
12597:             var details = detailsRes.data || [];
12598: 
12599:             var countedByItem = {};
12600:             if (rsRes.data.vehicle_id) {
12601:                 var countRes = await supabase.from('inventory_counts')
12602:                     .select('id')
12603:                     .eq('company_id', companyId)
12604:                     .eq('type', 'vehicle')
12605:                     .eq('entity_id', rsRes.data.vehicle_id)
12606:                     .order('created_at', { ascending: false })
12607:                     .limit(1)
12608:                     .maybeSingle();
12609:                 if (countRes.error) throw countRes.error;
12610:                 if (countRes.data) {
12611:                     var countDetailsRes = await supabase.from('inventory_count_details')
12612:                         .select('item_code,counted_qty')
12613:                         .eq('count_id', countRes.data.id);
12614:                     if (countDetailsRes.error) throw countDetailsRes.error;
12615:                     var countDetails = countDetailsRes.data || [];
12616:                     for (var ci = 0; ci < countDetails.length; ci++) {
12617:                         countedByItem[countDetails[ci].item_code] = Number(countDetails[ci].counted_qty) || 0;
12618:                     }
12619:                 }
12620:             }
12621: 
12622:             var items = [];
12623:             var totalShortage = 0;
12624:             var totalShortageValue = 0;
12625:             var html = '';
12626: 
12627:             for (var i = 0; i < details.length; i++) {
12628:                 var d = details[i];
12629:                 var loaded = Number(d.qty_loaded) || 0;
12630:                 var delivered = Number(d.qty_delivered) || 0;
12631:                 var returned = Number(d.qty_returned) || 0;
12632:                 var counted = Object.prototype.hasOwnProperty.call(countedByItem, d.item_code) ? countedByItem[d.item_code] : null;
12633:                 var shortage = Math.max(0, loaded - delivered - returned);
12634:                 var shortageValue = shortage * (Number(d.unit_price) || 0);
12635: 
12636:                 totalShortage += shortage;
12637:                 totalShortageValue += shortageValue;
12638:                 items.push({
12639:                     itemCode: d.item_code,
12640:                     itemName: d.item_name,
12641:                     unit: d.unit,
12642:                     loadedQty: loaded,
12643:                     deliveredQty: delivered,
12644:                     returnedQty: returned,
12645:                     countedQty: counted,
12646:                     shortage: shortage,
12647:                     unitPrice: Number(d.unit_price) || 0,
12648:                     shortageValue: shortageValue
12649:                 });
12650: 
12651:                 html += '<tr class="border-b">' +
12652:                     '<td class="p-2">' + esc(d.item_name || '') + '<div class="text-xs text-gray-400">' + esc(d.item_code || '') + '</div></td>' +
12653:                     '<td class="p-2 text-center">' + loaded + '</td>' +
12654:                     '<td class="p-2 text-center">' + delivered + '</td>' +
12655:                     '<td class="p-2 text-center">' + returned + '</td>' +
12656:                     '<td class="p-2 text-center font-bold">' + (counted == null ? '—' : counted) + '</td>' +
12657:                     '<td class="p-2 text-center font-black ' + (shortage > 0 ? 'text-red-600' : 'text-emerald-600') + '">' + shortage + '</td>' +
12658:                     '<td class="p-2 text-center">' + Math.abs(shortageValue).toLocaleString() + ' EGP</td>' +
12659:                 '</tr>';
12660:             }
12661: 
12662:             safeHTML(byId('settlement-items-body'), html || '<tr><td colspan="7" class="p-6 text-center">لا توجد بيانات</td></tr>');
12663:             safeHTML(byId('settlement-rs-info'),
12664:                 '<strong>المندوب:</strong> ' + esc(rsRes.data.driver_id || '---') +
12665:                 ' | <strong>السيارة:</strong> ' + esc(rsRes.data.vehicle_id || '---') +
12666:                 ' | <strong>التاريخ:</strong> ' + esc(rsRes.data.run_date || '---') +
12667:                 '<div class="mt-2 text-xs text-slate-500">ملاحظة: التسوية المحاسبية تعتمد على المحمّل − المسلّم − المرتجع كما يطبّقها محرك التسوية في Production. كمية الجرد المعروضة مرجعية للتحقق فقط ولا تُخصم من نتيجة العجز آليًا.</div>');
12668: 
12669:             if (detailsContainer) detailsContainer.classList.remove('hidden');
12670:             window._settlementData = {
12671:                 rs: rsRes.data,
12672:                 items: items,
12673:                 totalShortage: totalShortage,
12674:                 totalShortageValue: totalShortageValue
12675:             };
12676:             hideLoader();
12677:         } catch (e) {
12678:             hideLoader();
12679:             window._settlementData = null;
12680:             if (detailsContainer) detailsContainer.classList.add('hidden');
12681:             showToast('فشل تحميل بيانات التسوية: ' + (e.message || ''), 'error');
12682:         }
12683:     }
12684: 
12685:     function _saveSettlement() {
12686:         var data = window._settlementData;
12687:         if (!data) {
12688:             showToast('اختر رانشيتاً أولاً', 'warning');
12689:             return;
12690:         }
12691:         var rs = data.rs;
12692:         if (!rs || !rs.runsheet_code) {
12693:             showToast('بيانات الرانشيت غير مكتملة', 'error');
12694:             return;
12695:         }
12696: 
12697:         window._settlementPendingOps = window._settlementPendingOps || {};
12698:         var operationId = window._settlementPendingOps[rs.runsheet_code];
12699:         if (!operationId) {
12700:             operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('SETTLE-' + Date.now() + '-' + Math.random().toString(36).slice(2));
12701:             window._settlementPendingOps[rs.runsheet_code] = operationId;
12702:         }
12703: 
12704:         showLoader('جاري حفظ التسوية...');
12705:         supabase.auth.getSession().then(function(ses) {
12706:             var token = (ses && ses.data && ses.data.session) ? ses.data.session.access_token : null;
12707:             if (!token) throw new Error('انتهت الجلسة');
12708: 
12709:             return fetch(RW_SUPABASE_URL + '/functions/v1/save-daily-settlement', {
12710:                 method: 'POST',
12711:                 headers: {
12712:                     'Content-Type': 'application/json',
12713:                     'Authorization': 'Bearer ' + token,
12714:                     'Idempotency-Key': operationId
12715:                 },
12716:                 body: JSON.stringify({
12717:                     runsheet_code: rs.runsheet_code,
12718:                     notes: 'تسوية يومية للرانشيت ' + rs.runsheet_code,
12719:                     operation_id: operationId
12720:                 })
12721:             });
12722:         }).then(function(res) {
12723:             return res.json().catch(function() { return {}; }).then(function(json) {
12724:                 if (!res.ok || !json || !json.success) {
12725:                     throw new Error((json && (json.msg || json.error)) || 'فشل حفظ التسوية');
12726:                 }
12727:                 return json;
12728:             });
12729:         }).then(function(json) {
12730:             hideLoader();
12731:             delete window._settlementPendingOps[rs.runsheet_code];
12732:             showToast(json.duplicate ? 'تم استرجاع نتيجة التسوية السابقة' : ('تم حفظ التسوية: ' + (json.settlement_code || rs.runsheet_code)), 'success');
12733:             var container = byId('settlement-details-container');
12734:             if (container) container.classList.add('hidden');
12735:             var sel = byId('settlement-rs-select');
12736:             if (sel) sel.value = '';
12737:             window._settlementData = null;
12738:         }).catch(function(e) {
12739:             hideLoader();
12740:             showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس رقم العملية', 'error');
12741:         });
12742:     }
12743: function _openPickingModal(rsCode) {
12744:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12745:     showLoader('جاري تحميل بيانات التحضير...');
12746: 
12747:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12748:     if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12749: 
12750:     window._pickingPendingOps = window._pickingPendingOps || {};
12751: 
12752:     supabase.from('runsheets')
12753:         .select('id')
12754:         .eq('company_id', companyId)
12755:         .eq('runsheet_code', rsCode)
12756:         .maybeSingle()
12757:         .then(function(rsRes) {
12758:             if (rsRes.error) throw rsRes.error;
12759:             if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
12760:             var runsheetUuid = rsRes.data.id;
12761: 
12762:             return supabase.from('run_sheet_details')
12763:                 .select('*')
12764:                 .eq('runsheet_id', runsheetUuid)
12765:                 .order('item_code')
12766:                 .then(function(itemsRes) {
12767:                     if (itemsRes.error) throw itemsRes.error;
12768:                     var items = itemsRes.data || [];
12769:                     if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
12770: 
12771:                     showLoader('جاري بدء التحضير...');
12772:                     return supabase.auth.getSession().then(function(ses) {
12773:                         var token = ses.data.session ? ses.data.session.access_token : null;
12774:                         if (!token) throw new Error('انتهت الجلسة');
12775:                         return fetch(RW_SUPABASE_URL + '/functions/v1/start-picking', {
12776:                             method: 'POST',
12777:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
12778:                             body: JSON.stringify({ runsheet_code: rsCode })
12779:                         });
12780:                     }).then(function(res) { return res.json().then(function(json) { if (!res.ok || !json.success) throw new Error(json.msg || json.error || 'فشل بدء التحضير'); return json; }); }).then(function(startJson) {
12781:                         hideLoader();
12782: 
12783:                         var operationId = window._pickingPendingOps[rsCode];
12784:                         if (!operationId) {
12785:                             operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('PICK-' + Date.now() + '-' + Math.random().toString(36).slice(2));
12786:                             window._pickingPendingOps[rsCode] = operationId;
12787:                         }
12788: 
12789:                         var html = '<div class="text-right" dir="rtl"><div class="max-h-[420px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
12790:                             '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المطلوبة</th><th class="p-2 text-center">الكمية المحضرة</th></tr></thead><tbody>';
12791:                         for (var i = 0; i < items.length; i++) {
12792:                             var it = items[i];
12793:                             var ordered = Number(it.qty_ordered) || 0;
12794:                             var picked = Number(it.qty_picked) || 0;
12795:                             html += '<tr><td class="p-2 border"><p class="font-bold">' + esc(it.item_name || '') + '</p><p class="text-xs">' + esc(it.item_code || '') + '</p></td>' +
12796:                                 '<td class="p-2 border text-center">' + esc(it.unit || 'حبة') + '</td>' +
12797:                                 '<td class="p-2 border text-center font-bold">' + ordered + '</td>' +
12798:                                 '<td class="p-2 border text-center"><input type="number" id="picked_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="0.01" min="0" max="' + ordered + '" value="' + (picked || ordered) + '"></td></tr>';
12799:                         }
12800:                         html += '</tbody></table></div></div>';
12801: 
12802:                         Swal.fire({
12803:                             title: 'تحضير الرانشيت: ' + esc(rsCode),
12804:                             html: html,
12805:                             width: '850px',
12806:                             showCancelButton: true,
12807:                             confirmButtonText: 'إنهاء التحضير',
12808:                             cancelButtonText: 'إلغاء',
12809:                             preConfirm: function() {
12810:                                 var itemsData = [];
12811:                                 var hasQty = false;
12812:                                 for (var j = 0; j < items.length; j++) {
12813:                                     var orderedQty = Number(items[j].qty_ordered) || 0;
12814:                                     var qty = parseFloat((document.getElementById('picked_qty_' + j) || {}).value);
12815:                                     if (!Number.isFinite(qty)) qty = 0;
12816:                                     if (qty < 0 || qty > orderedQty) {
12817:                                         Swal.showValidationMessage('الكمية المحضرة يجب أن تكون بين 0 والكمية المطلوبة للصنف: ' + (items[j].item_code || ''));
12818:                                         return false;
12819:                                     }
12820:                                     if (qty > 0) hasQty = true;
12821:                                     itemsData.push({ itemCode: items[j].item_code, pickedQty: qty, notes: '' });
12822:                                 }
12823:                                 if (!hasQty) { Swal.showValidationMessage('يجب تحضير كمية واحدة على الأقل'); return false; }
12824:                                 return itemsData;
12825:                             }
12826:                         }).then(function(result) {
12827:                             if (!result.isConfirmed) {
12828:                                 delete window._pickingPendingOps[rsCode];
12829:                                 return;
12830:                             }
12831:                             showLoader('جاري إنهاء التحضير...');
12832:                             return supabase.auth.getSession().then(function(ses2) {
12833:                                 var token2 = ses2.data.session ? ses2.data.session.access_token : null;
12834:                                 if (!token2) throw new Error('انتهت الجلسة');
12835:                                 return fetch(RW_SUPABASE_URL + '/functions/v1/complete-picking', {
12836:                                     method: 'POST',
12837:                                     headers: {
12838:                                         'Content-Type': 'application/json',
12839:                                         Authorization: 'Bearer ' + token2,
12840:                                         'Idempotency-Key': operationId
12841:                                     },
12842:                                     body: JSON.stringify({ runsheet_code: rsCode, items: result.value, operation_id: operationId })
12843:                                 });
12844:                             }).then(function(res) {
12845:                                 return res.json().catch(function() { return {}; }).then(function(compJson) {
12846:                                     if (!res.ok || !compJson.success) throw new Error(compJson.msg || compJson.error || 'فشل إنهاء التحضير');
12847:                                     return compJson;
12848:                                 });
12849:                             }).then(function(compJson) {
12850:                                 hideLoader();
12851:                                 delete window._pickingPendingOps[rsCode];
12852:                                 showToast(compJson.duplicate ? 'تم استرجاع نتيجة التحضير السابقة' : 'تم إنهاء التحضير بنجاح', 'success');
12853:                                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
12854:                             }).catch(function(e) {
12855:                                 hideLoader();
12856:                                 showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس العملية', 'error');
12857:                             });
12858:                         });
12859:                     });
12860:                 });
12861:         })
12862:         .catch(function(e) {
12863:             hideLoader();
12864:             showToast(e.message || 'فشل تحميل بيانات التحضير', 'error');
12865:         });
12866: }
12867: function _openLoadingModal(rsCode) {
12868:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12869:     showLoader('جاري تحميل بيانات التحميل...');
12870:     
12871:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12872: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12873: supabase.from('runsheets')
12874:     .select('id')
12875:     .eq('company_id', companyId)
12876:     .eq('runsheet_code', rsCode)
12877:     .maybeSingle()
12878:     .then(function(rsRes) {
12879:         if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
12880:         var runsheetUuid = rsRes.data.id;
12881:         
12882:         supabase.from('run_sheet_details').select('*').eq('runsheet_id', runsheetUuid).then(function(itemsRes) {
12883:             var items = itemsRes.data || [];
12884:             if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
12885:             
12886:             showLoader('جاري بدء التحميل...');
12887:             supabase.auth.getSession().then(function(ses) {
12888:                 var t = ses.data.session ? ses.data.session.access_token : null;
12889:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-loading', {
12890:                     method: 'POST',
12891:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
12892:                     body: JSON.stringify({ runsheet_code: rsCode })
12893:                 });
12894:             }).then(function(res) { return res.json(); }).then(function(startJson) {
12895:                 hideLoader();
12896:                 if (!startJson.success) { showToast(startJson.msg || 'فشل بدء التحميل', 'error'); return; }
12897:                 
12898:                 var html = '<div class="text-right" dir="rtl"><div class="max-h-[400px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
12899:                     '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المحضّرة</th><th class="p-2 text-center">الكمية المحمّلة</th></tr></thead><tbody>';
12900:                 for (var i = 0; i < items.length; i++) {
12901:                     var it = items[i];
12902:                     var picked = it.qty_picked || 0;
12903:                     html += '<tr><td class="p-2 border"><p class="font-bold">' + (it.item_name || '') + '</p><p class="text-xs">' + (it.item_code || '') + '</p></td>' +
12904:                         '<td class="p-2 border text-center">' + (it.unit || 'حبة') + '</td>' +
12905:                         '<td class="p-2 border text-center font-bold">' + picked + '</td>' +
12906:                         '<td class="p-2 border text-center"><input type="number" id="loaded_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="1" min="0" max="' + picked + '" value="' + picked + '"></td></tr>';
12907:                 }
12908:                 html += '</tbody></table></div></div>';
12909:                 
12910:                 Swal.fire({
12911:                     title: 'تحميل الرانشيت: ' + rsCode,
12912:                     html: html,
12913:                     width: '800px',
12914:                     showCancelButton: true,
12915:                     confirmButtonText: 'إنهاء التحميل',
12916:                     cancelButtonText: 'إلغاء',
12917:                     preConfirm: function() {
12918:                         var itemsData = [];
12919:                         var allZero = true;
12920:                         for (var j = 0; j < items.length; j++) {
12921:                             var qty = parseFloat(document.getElementById('loaded_qty_' + j).value) || 0;
12922:                             if (qty > 0) allZero = false;
12923:                             itemsData.push({ itemCode: items[j].item_code, loadedQty: qty, notes: '' });
12924:                         }
12925:                         if (allZero) { Swal.showValidationMessage('يجب تحميل كمية واحدة على الأقل'); return false; }
12926:                         return itemsData;
12927:                     }
12928:                 }).then(function(result) {
12929:                     if (!result.isConfirmed) return;
12930:                     showLoader('جاري إنهاء التحميل...');
12931:                     supabase.auth.getSession().then(function(ses2) {
12932:                         var t2 = ses2.data.session ? ses2.data.session.access_token : null;
12933:                         return fetch(RW_SUPABASE_URL + '/functions/v1/complete-loading', {
12934:                             method: 'POST',
12935:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
12936:                             body: JSON.stringify({ runsheet_code: rsCode, items: result.value })
12937:                         });
12938:                     }).then(function(res) { return res.json(); }).then(function(compJson) {
12939:                         hideLoader();
12940:                         if (compJson.success) {
12941:                             showToast('تم إنهاء التحميل بنجاح', 'success');
12942:                             if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
12943:                         } else {
12944:                             showToast(compJson.msg || 'فشل إنهاء التحميل', 'error');
12945:                         }
12946:                     }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
12947:                 });
12948:             }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
12949:         }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
12950:     }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
12951: }function _openDeliveryModal(rsCode) {
12952:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12953:     showLoader('جاري تحميل بيانات التوصيل...');
12954: 
12955:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12956:     if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12957: 
12958:     supabase.from('runsheets')
12959:         .select('id,status')
12960:         .eq('company_id', companyId)
12961:         .eq('runsheet_code', rsCode)
12962:         .maybeSingle()
12963:         .then(function(rsRes) {
12964:             if (rsRes.error) throw rsRes.error;
12965:             var rs = rsRes.data;
12966:             if (!rs) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return null; }
12967: 
12968:             showLoader('جاري بدء التوصيل...');
12969:             return supabase.auth.getSession().then(function(ses) {
12970:                 var t = ses.data.session ? ses.data.session.access_token : null;
12971:                 if (!t) throw new Error('انتهت الجلسة');
12972:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-delivery', {
12973:                     method: 'POST',
12974:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
12975:                     body: JSON.stringify({ runsheet_code: rsCode })
12976:                 });
12977:             }).then(function(res) {
12978:                 return res.json();
12979:             }).then(function(startJson) {
12980:                 if (!startJson.success) { hideLoader(); showToast(startJson.msg || 'فشل بدء التوصيل', 'error'); return null; }
12981: 
12982:                 return supabase.from('orders')
12983:                     .select('id,order_code,customer_name')
12984:                     .eq('company_id', companyId)
12985:                     .eq('runsheet_id', rs.id)
12986:                     .order('created_at', { ascending: true })
12987:                     .then(function(ordersRes) {
12988:                         if (ordersRes.error) throw ordersRes.error;
12989:                         var orders = ordersRes.data || [];
12990:                         if (!orders.length) { hideLoader(); showToast('لا توجد أوردرات في الرانشيت', 'info'); return null; }
12991: 
12992:                         function deliverOrder(index) {
12993:                             if (index >= orders.length) {
12994:                                 showLoader('جاري إنهاء الرانشيت...');
12995:                                 return supabase.auth.getSession().then(function(ses2) {
12996:                                     var t2 = ses2.data.session ? ses2.data.session.access_token : null;
12997:                                     if (!t2) throw new Error('انتهت الجلسة');
12998:                                     return fetch(RW_SUPABASE_URL + '/functions/v1/complete-delivery', {
12999:                                         method: 'POST',
13000:                                         headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
13001:                                         body: JSON.stringify({ runsheet_code: rsCode })
13002:                                     });
13003:                                 }).then(function(res) {
13004:                                     return res.json();
13005:                                 }).then(function(finalJson) {
13006:                                     hideLoader();
13007:                                     if (finalJson.success) {
13008:                                         showToast('تم إنهاء التوصيل بالكامل', 'success');
13009:                                         if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13010:                                     } else {
13011:                                         showToast(finalJson.msg || 'فشل إنهاء الرانشيت', 'error');
13012:                                     }
13013:                                 });
13014:                             }
13015: 
13016:                             var order = orders[index];
13017:                             showLoader('جاري تحميل بيانات الأوردر ' + (order.order_code || '') + '...');
13018:                             return supabase.from('order_details')
13019:                                 .select('id,item_code,item_name,unit,qty,qty_loaded,qty_delivered,qty_refused,unit_price')
13020:                                 .eq('order_id', order.id)
13021:                                 .order('created_at', { ascending: true })
13022:                                 .then(function(detailsRes) {
13023:                                     if (detailsRes.error) throw detailsRes.error;
13024:                                     var details = detailsRes.data || [];
13025:                                     hideLoader();
13026:                                     if (!details.length) {
13027:                                         return deliverOrder(index + 1);
13028:                                     }
13029: 
13030:                                     var html = '<div class="text-right" dir="rtl"><div class="max-h-[420px] overflow-y-auto">';
13031:                                     html += '<div class="mb-3 p-3 bg-blue-50 rounded-lg"><div class="font-black text-blue-700">' + (order.order_code || '') + '</div><div class="text-sm text-gray-600">' + (order.customer_name || '') + '</div></div>';
13032:                                     html += '<table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">محمّل</th><th class="p-2 text-center">مسلّم سابقًا</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">تسليم الآن</th></tr></thead><tbody>';
13033: 
13034:                                     for (var i = 0; i < details.length; i++) {
13035:                                         var d = details[i];
13036:                                         var loaded = Number(d.qty_loaded || 0);
13037:                                         var delivered = Number(d.qty_delivered || 0);
13038:                                         var remaining = Math.max(0, loaded - delivered);
13039:                                         html += '<tr><td class="p-2 border"><div class="font-bold">' + (d.item_name || '') + '</div><div class="text-xs text-gray-400">' + (d.item_code || '') + '</div></td>'
13040:                                             + '<td class="p-2 border text-center">' + loaded + '</td>'
13041:                                             + '<td class="p-2 border text-center">' + delivered + '</td>'
13042:                                             + '<td class="p-2 border text-center font-bold text-blue-700">' + remaining + '</td>'
13043:                                             + '<td class="p-2 border text-center"><input type="number" id="dv_order_qty_' + i + '" value="' + remaining + '" min="0" max="' + remaining + '" step="0.01" class="w-24 p-1 border rounded text-center"></td></tr>';
13044:                                     }
13045:                                     html += '</tbody></table></div></div>';
13046: 
13047:                                     return Swal.fire({
13048:                                         title: 'توصيل الأوردر ' + (order.order_code || ''),
13049:                                         html: html,
13050:                                         width: '850px',
13051:                                         showCancelButton: true,
13052:                                         confirmButtonText: 'تأكيد تسليم الأوردر',
13053:                                         cancelButtonText: 'إلغاء',
13054:                                         preConfirm: function() {
13055:                                             var items = [];
13056:                                             var hasQty = false;
13057:                                             for (var j = 0; j < details.length; j++) {
13058:                                                 var maxRemaining = Math.max(0, Number(details[j].qty_loaded || 0) - Number(details[j].qty_delivered || 0));
13059:                                                 var q = parseFloat((document.getElementById('dv_order_qty_' + j) || {}).value) || 0;
13060:                                                 if (q < 0 || q > maxRemaining) {
13061:                                                     Swal.showValidationMessage('كمية التسليم تتجاوز المتبقي للصنف: ' + (details[j].item_code || ''));
13062:                                                     return false;
13063:                                                 }
13064:                                                 if (q > 0) hasQty = true;
13065:                                                 items.push({ itemCode: details[j].item_code, deliveredQty: q, reason: '' });
13066:                                             }
13067:                                             if (!hasQty) {
13068:                                                 Swal.showValidationMessage('أدخل كمية تسليم واحدة على الأقل');
13069:                                                 return false;
13070:                                             }
13071:                                             return items;
13072:                                         }
13073:                                     }).then(function(result) {
13074:                                         if (!result.isConfirmed) return;
13075:                                         showLoader('جاري حفظ تسليم ' + (order.order_code || '') + '...');
13076:                                         return supabase.auth.getSession().then(function(ses3) {
13077:                                             var t3 = ses3.data.session ? ses3.data.session.access_token : null;
13078:                                             if (!t3) throw new Error('انتهت الجلسة');
13079:                                             return fetch(RW_SUPABASE_URL + '/functions/v1/complete-order-delivery', {
13080:                                                 method: 'POST',
13081:                                                 headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t3 },
13082:                                                 body: JSON.stringify({ runsheet_code: rsCode, order_code: order.order_code, items: result.value })
13083:                                             });
13084:                                         }).then(function(res) {
13085:                                             return res.json();
13086:                                         }).then(function(orderJson) {
13087:                                             hideLoader();
13088:                                             if (!orderJson.success) {
13089:                                                 showToast(orderJson.msg || 'فشل تسليم الأوردر', 'error');
13090:                                                 return;
13091:                                             }
13092:                                             return deliverOrder(index + 1);
13093:                                         });
13094:                                     });
13095:                                 });
13096:                         }
13097: 
13098:                         return deliverOrder(0);
13099:                     });
13100:             });
13101:         })
13102:         .catch(function(e) {
13103:             hideLoader();
13104:             showToast(e.message || 'فشل تحميل بيانات التوصيل', 'error');
13105:         });
13106: }
13107: function _openReturnModal(rsCode) {
13108:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
13109:     showLoader('جاري تحميل بيانات المرتجعات...');
13110:     
13111:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
13112: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
13113: supabase.from('runsheets')
13114:     .select('id')
13115:     .eq('company_id', companyId)
13116:     .eq('runsheet_code', rsCode)
13117:     .maybeSingle()
13118:     .then(function(rsRes) {
13119:         if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
13120:         var runsheetUuid = rsRes.data.id;
13121:         
13122:         supabase.from('run_sheet_details').select('*').eq('runsheet_id', runsheetUuid).then(function(itemsRes) {
13123:             var items = itemsRes.data || [];
13124:             if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
13125:             
13126:             showLoader('جاري بدء المرتجعات...');
13127:             supabase.auth.getSession().then(function(ses) {
13128:                 var t = ses.data.session ? ses.data.session.access_token : null;
13129:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-return', {
13130:                     method: 'POST',
13131:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13132:                     body: JSON.stringify({ runsheet_code: rsCode })
13133:                 });
13134:             }).then(function(res) { return res.json(); }).then(function(startJson) {
13135:                 hideLoader();
13136:                 if (!startJson.success) { showToast(startJson.msg || 'فشل بدء المرتجعات', 'error'); return; }
13137:                 
13138:                 var html = '<div class="text-right" dir="rtl"><div class="max-h-[400px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
13139:                     '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المسلّمة</th><th class="p-2 text-center">الكمية المرتجعة</th></tr></thead><tbody>';
13140:                 for (var i = 0; i < items.length; i++) {
13141:                     var it = items[i];
13142:                     var delivered = it.qty_delivered || 0;
13143:                     html += '<tr><td class="p-2 border"><p class="font-bold">' + (it.item_name || '') + '</p><p class="text-xs">' + (it.item_code || '') + '</p></td>' +
13144:                         '<td class="p-2 border text-center">' + (it.unit || 'حبة') + '</td>' +
13145:                         '<td class="p-2 border text-center font-bold">' + delivered + '</td>' +
13146:                         '<td class="p-2 border text-center"><input type="number" id="returned_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="1" min="0" max="' + delivered + '" value="0"></td></tr>';
13147:                 }
13148:                 html += '</tbody></table></div></div>';
13149:                 
13150:                 Swal.fire({
13151:                     title: 'مرتجعات الرانشيت: ' + rsCode,
13152:                     html: html,
13153:                     width: '800px',
13154:                     showCancelButton: true,
13155:                     confirmButtonText: 'إنهاء المرتجعات',
13156:                     cancelButtonText: 'إلغاء',
13157:                     preConfirm: function() {
13158:                         var itemsData = [];
13159:                         var allZero = true;
13160:                         for (var j = 0; j < items.length; j++) {
13161:                             var qty = parseFloat(document.getElementById('returned_qty_' + j).value) || 0;
13162:                             if (qty > 0) allZero = false;
13163:                             itemsData.push({ itemCode: items[j].item_code, returnedQty: qty, reason: '' });
13164:                         }
13165:                         if (allZero) { Swal.showValidationMessage('يجب إدخال كمية مرتجعة واحدة على الأقل'); return false; }
13166:                         return itemsData;
13167:                     }
13168:                 }).then(function(result) {
13169:                     if (!result.isConfirmed) return;
13170:                     showLoader('جاري إنهاء المرتجعات...');
13171:                     supabase.auth.getSession().then(function(ses2) {
13172:                         var t2 = ses2.data.session ? ses2.data.session.access_token : null;
13173:                         return fetch(RW_SUPABASE_URL + '/functions/v1/complete-return', {
13174:                             method: 'POST',
13175:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
13176:                             body: JSON.stringify({ runsheet_code: rsCode, items: result.value })
13177:                         });
13178:                     }).then(function(res) { return res.json(); }).then(function(compJson) {
13179:                         hideLoader();
13180:                         if (compJson.success) {
13181:                             showToast('تم إنهاء المرتجعات بنجاح', 'success');
13182:                             if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13183:                         } else {
13184:                             showToast(compJson.msg || 'فشل إنهاء المرتجعات', 'error');
13185:                         }
13186:                     }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13187:                 });
13188:             }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13189:         }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
13190:     }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
13191: }
13192: function _confirmUnload(code) {
13193:     Swal.fire({ title: 'تأكيد التفريغ', text: 'إعادة جميع الكميات للمخزون؟', icon: 'warning', showCancelButton: true, confirmButtonText: 'نعم', cancelButtonText: 'لا' }).then(function(cf) {
13194:         if (!cf.isConfirmed) return;
13195:         showLoader('جاري التفريغ...');
13196:         supabase.auth.getSession().then(function(ses) {
13197:             var t = ses.data.session ? ses.data.session.access_token : null;
13198:             return fetch(RW_SUPABASE_URL + '/functions/v1/unload-runsheet', {
13199:                 method: 'POST',
13200:                 headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13201:                 body: JSON.stringify({ runsheet_code: code })
13202:             });
13203:         }).then(function(res) { return res.json(); }).then(function(json) {
13204:             hideLoader();
13205:             if (json.success) {
13206:                 showToast('تم التفريغ بنجاح', 'success');
13207:                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13208:             } else {
13209:                 showToast(json.msg || 'فشل التفريغ', 'error');
13210:             }
13211:         }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13212:     });
13213: }
13214: function _changeStatus(code, funcName) {
13215:     showLoader('جاري تحديث الحالة...');
13216:     supabase.auth.getSession().then(function(ses) {
13217:         var t = ses.data.session ? ses.data.session.access_token : null;
13218:         return fetch(SUPABASE_URL + '/functions/v1/' + funcName, {
13219:             method: 'POST',
13220:             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13221:             body: JSON.stringify({ runsheet_code: code })
13222:         });
13223:     }).then(function(res) { return res.json(); }).then(function(json) {
13224:         hideLoader();
13225:         if (json.success) {
13226:             showToast('تم بنجاح', 'success');
13227:         } else {
13228:             showToast(json.msg || 'فشل', 'error');
13229:         }
13230:     }).catch(function(e) {
13231:         hideLoader();
13232:         showToast('فشل الاتصال', 'error');
13233:     });
13234: }
13235:     async function loadInventoryControl() {
13236:         var c = byId('rw-page-container');
13237:         if (!c) return;
13238: 
13239:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) ||
13240:             (typeof _rwCompanyId === 'function' ? _rwCompanyId() : null);
13241:         if (!companyId) {
13242:             showToast('سياق الشركة غير محدد', 'error');
13243:             return;
13244:         }
13245: 
13246:         var state = {
13247:             tab: 'snapshot',
13248:             branchId: '',
13249:             query: '',
13250:             lowOnly: false,
13251:             movementType: '',
13252:             fromDate: '',
13253:             toDate: '',
13254:             snapshot: [],
13255:             movements: [],
13256:             replenishment: [],
13257:             counts: [],
13258:             requests: [],
13259:             branches: [],
13260:             busy: false
13261:         };
13262: 
13263:         function escIC(v) {
13264:             return String(v == null ? '' : v)
13265:                 .replace(/&/g, '&amp;')
13266:                 .replace(/</g, '&lt;')
13267:                 .replace(/>/g, '&gt;')
13268:                 .replace(/"/g, '&quot;')
13269:                 .replace(/'/g, '&#39;');
13270:         }
13271: 
13272:         function fmtIC(v) {
13273:             return Number(v || 0).toLocaleString('ar-EG');
13274:         }
13275: 
13276:         async function callIC(operation, payload) {
13277:             var res = await supabase.rpc('inventory_control', {
13278:                 p_operation: operation,
13279:                 p_payload: payload || {}
13280:             });
13281:             if (res.error) throw res.error;
13282:             var data = res.data;
13283:             if (data && data.success === false) {
13284:                 throw new Error(data.msg || 'فشل تنفيذ العملية');
13285:             }
13286:             return data || { success: true };
13287:         }
13288: 
13289:         function branchOptions(selected) {
13290:             var h = '<option value="">كل المخازن والفروع</option>';
13291:             for (var i = 0; i < state.branches.length; i++) {
13292:                 var b = state.branches[i];
13293:                 h += '<option value="' + escIC(b.id) + '"' +
13294:                     (String(selected || '') === String(b.id) ? ' selected' : '') + '>' +
13295:                     escIC(b.name || b.branch_code) + '</option>';
13296:             }
13297:             return h;
13298:         }
13299: 
13300:         function renderShell() {
13301:             safeText(byId('rw-header-title'), 'مركز التحكم في المخزون');
13302:             safeHTML(c,
13303:                 '<div class="p-4 space-y-4">' +
13304:                 '<div class="bg-white rounded-2xl shadow-sm border p-4">' +
13305:                     '<div class="flex flex-wrap items-center justify-between gap-3 mb-4">' +
13306:                         '<div>' +
13307:                             '<div class="text-xl font-black text-slate-800">مركز التحكم في المخزون</div>' +
13308:                             '<div class="text-sm text-slate-500 mt-1">لوحة رقابة مركزية فوق رصيد المخزون والحركة والاحتياجات والجرد وطلبات المخزون</div>' +
13309:                         '</div>' +
13310:                         '<div class="flex gap-2">' +
13311:                             '<button id="ic-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث البيانات</button>' +
13312:                             '<button id="ic-new-count" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">جلسة جرد جديدة</button>' +
13313:                         '</div>' +
13314:                     '</div>' +
13315:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13316:                         '<div class="rounded-2xl bg-blue-50 border border-blue-100 p-4"><div class="text-xs text-blue-700 font-bold">بنود المخزون المعروضة</div><div id="ic-kpi-lines" class="text-2xl font-black text-blue-900 mt-1">0</div></div>' +
13317:                         '<div class="rounded-2xl bg-amber-50 border border-amber-100 p-4"><div class="text-xs text-amber-700 font-bold">بنود منخفضة</div><div id="ic-kpi-low" class="text-2xl font-black text-amber-900 mt-1">0</div></div>' +
13318:                         '<div class="rounded-2xl bg-emerald-50 border border-emerald-100 p-4"><div class="text-xs text-emerald-700 font-bold">بنود تحتاج إعادة طلب</div><div id="ic-kpi-repl" class="text-2xl font-black text-emerald-900 mt-1">0</div></div>' +
13319:                         '<div class="rounded-2xl bg-purple-50 border border-purple-100 p-4"><div class="text-xs text-purple-700 font-bold">جلسات الجرد النشطة</div><div id="ic-kpi-counts" class="text-2xl font-black text-purple-900 mt-1">0</div></div>' +
13320:                     '</div>' +
13321:                 '</div>' +
13322:                 '<div class="bg-white rounded-2xl shadow-sm border p-3">' +
13323:                     '<div class="flex flex-wrap gap-2">' +
13324:                         '<button data-ic-tab="snapshot" class="ic-tab px-4 py-2 rounded-xl font-bold bg-blue-600 text-white">الرصيد</button>' +
13325:                         '<button data-ic-tab="movements" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الحركات</button>' +
13326:                         '<button data-ic-tab="replenishment" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">إعادة الطلب</button>' +
13327:                         '<button data-ic-tab="counts" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الجرد</button>' +
13328:                         '<button data-ic-tab="requests" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">طلبات المخزون</button>' +
13329:                     '</div>' +
13330:                 '</div>' +
13331:                 '<div id="ic-filters" class="bg-white rounded-2xl shadow-sm border p-4"></div>' +
13332:                 '<div id="ic-content" class="bg-white rounded-2xl shadow-sm border overflow-auto"></div>' +
13333:                 '</div>'
13334:             );
13335: 
13336:             byId('ic-refresh').onclick = refreshAll;
13337:             byId('ic-new-count').onclick = createCountSession;
13338: 
13339:             var tabs = c.querySelectorAll('.ic-tab');
13340:             for (var i = 0; i < tabs.length; i++) {
13341:                 tabs[i].onclick = function() {
13342:                     state.tab = this.getAttribute('data-ic-tab');
13343:                     renderTabButtons();
13344:                     renderFilters();
13345:                     refreshCurrentTab();
13346:                 };
13347:             }
13348:         }
13349: 
13350:         function renderTabButtons() {
13351:             var tabs = c.querySelectorAll('.ic-tab');
13352:             for (var i = 0; i < tabs.length; i++) {
13353:                 var active = tabs[i].getAttribute('data-ic-tab') === state.tab;
13354:                 tabs[i].className = 'ic-tab px-4 py-2 rounded-xl font-bold ' +
13355:                     (active ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-700');
13356:             }
13357:         }
13358: 
13359:         function renderFilters() {
13360:             var f = byId('ic-filters');
13361:             if (!f) return;
13362:             if (state.tab === 'snapshot') {
13363:                 safeHTML(f,
13364:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13365:                         '<select id="ic-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13366:                         '<input id="ic-query" class="p-2.5 border rounded-xl bg-slate-50" placeholder="بحث بالصنف أو الكود أو الفرع" value="' + escIC(state.query) + '">' +
13367:                         '<label class="flex items-center gap-2 p-2.5 border rounded-xl bg-slate-50"><input id="ic-low" type="checkbox" ' + (state.lowOnly ? 'checked' : '') + '> منخفض فقط</label>' +
13368:                         '<button id="ic-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تطبيق</button>' +
13369:                     '</div>'
13370:                 );
13371:                 byId('ic-apply').onclick = function() {
13372:                     state.branchId = byId('ic-branch').value || '';
13373:                     state.query = byId('ic-query').value || '';
13374:                     state.lowOnly = !!byId('ic-low').checked;
13375:                     refreshCurrentTab();
13376:                 };
13377:             } else if (state.tab === 'movements') {
13378:                 safeHTML(f,
13379:                     '<div class="grid grid-cols-1 md:grid-cols-5 gap-3">' +
13380:                         '<input id="ic-from" type="date" class="p-2.5 border rounded-xl bg-slate-50" value="' + escIC(state.fromDate) + '">' +
13381:                         '<input id="ic-to" type="date" class="p-2.5 border rounded-xl bg-slate-50" value="' + escIC(state.toDate) + '">' +
13382:                         '<select id="ic-mov-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13383:                         '<input id="ic-mov-query" class="p-2.5 border rounded-xl bg-slate-50" placeholder="صنف/مرجع" value="' + escIC(state.query) + '">' +
13384:                         '<button id="ic-mov-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تطبيق</button>' +
13385:                     '</div>'
13386:                 );
13387:                 byId('ic-mov-apply').onclick = function() {
13388:                     state.fromDate = byId('ic-from').value || '';
13389:                     state.toDate = byId('ic-to').value || '';
13390:                     state.branchId = byId('ic-mov-branch').value || '';
13391:                     state.query = byId('ic-mov-query').value || '';
13392:                     refreshCurrentTab();
13393:                 };
13394:             } else if (state.tab === 'replenishment') {
13395:                 safeHTML(f,
13396:                     '<div class="grid grid-cols-1 md:grid-cols-3 gap-3">' +
13397:                         '<select id="ic-repl-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13398:                         '<div class="p-2.5 rounded-xl bg-emerald-50 border border-emerald-100 font-bold text-emerald-800">التوصية مبنية على الرصيد المتاح ونقطة إعادة الطلب والحد الأقصى</div>' +
13399:                         '<button id="ic-repl-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تحديث التوصيات</button>' +
13400:                     '</div>'
13401:                 );
13402:                 byId('ic-repl-apply').onclick = function() {
13403:                     state.branchId = byId('ic-repl-branch').value || '';
13404:                     refreshCurrentTab();
13405:                 };
13406:             } else if (state.tab === 'counts') {
13407:                 safeHTML(f,
13408:                     '<div class="flex flex-wrap items-center justify-between gap-2">' +
13409:                         '<div class="text-sm text-slate-600">الجرد يبدأ من جلسة، ثم Populate/Count/Refresh/Finalize عبر محرك الجرد الحالي.</div>' +
13410:                         '<button id="ic-count-refresh" class="px-4 py-2 rounded-xl bg-slate-700 text-white font-bold">تحديث الجلسات</button>' +
13411:                     '</div>'
13412:                 );
13413:                 byId('ic-count-refresh').onclick = refreshCounts;
13414:             } else {
13415:                 safeHTML(f,
13416:                     '<div class="flex flex-wrap items-center justify-between gap-2">' +
13417:                         '<div class="text-sm text-slate-600">طلبات المخزون تستخدم دورة Pending → Approved → Converted/Rejected/Cancelled.</div>' +
13418:                         '<button id="ic-request-new" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">طلب نقل مخزني جديد</button>' +
13419:                     '</div>'
13420:                 );
13421:                 byId('ic-request-new').onclick = createStockRequest;
13422:             }
13423:         }
13424: 
13425:         function setBusy(on, text) {
13426:             state.busy = on;
13427:             if (on) showLoader(text || 'جاري تحميل مركز التحكم...');
13428:             else hideLoader();
13429:         }
13430: 
13431:         async function refreshSnapshot() {
13432:             var d = await callIC('SNAPSHOT', {
13433:                 branch_id: state.branchId || null,
13434:                 query: state.query || null,
13435:                 low_only: state.lowOnly,
13436:                 limit: 200,
13437:                 offset: 0
13438:             });
13439:             state.snapshot = d.rows || [];
13440:             safeText(byId('ic-kpi-lines'), fmtIC(d.count || state.snapshot.length));
13441:             var low = state.snapshot.filter(function(x) { return x.low_stock; }).length;
13442:             safeText(byId('ic-kpi-low'), fmtIC(low));
13443:             renderSnapshot();
13444:         }
13445: 
13446:         async function refreshMovements() {
13447:             var d = await callIC('MOVEMENTS', {
13448:                 from_date: state.fromDate || null,
13449:                 to_date: state.toDate || null,
13450:                 branch_id: state.branchId || null,
13451:                 item_id: null,
13452:                 movement_type: state.movementType || null,
13453:                 query: state.query || null,
13454:                 limit: 200,
13455:                 offset: 0
13456:             });
13457:             state.movements = d.rows || [];
13458:             renderMovements();
13459:         }
13460: 
13461:         async function refreshReplenishment() {
13462:             var d = await callIC('REPLENISHMENT', {
13463:                 branch_id: state.branchId || null,
13464:                 limit: 200,
13465:                 offset: 0
13466:             });
13467:             state.replenishment = d.rows || [];
13468:             safeText(byId('ic-kpi-repl'), fmtIC(state.replenishment.length));
13469:             renderReplenishment();
13470:         }
13471: 
13472:         async function refreshCounts() {
13473:             var res = await supabase.from('inventory_counts')
13474:                 .select('*')
13475:                 .eq('company_id', companyId)
13476:                 .order('created_at', { ascending: false });
13477:             if (res.error) throw res.error;
13478:             state.counts = res.data || [];
13479:             safeText(byId('ic-kpi-counts'), fmtIC(state.counts.filter(function(x) { return ['InProgress','Draft'].indexOf(x.status) !== -1; }).length));
13480:             renderCounts();
13481:         }
13482: 
13483:         async function refreshRequests() {
13484:             var res = await supabase.from('inventory_stock_requests')
13485:                 .select('*')
13486:                 .eq('company_id', companyId)
13487:                 .order('created_at', { ascending: false });
13488:             if (res.error) throw res.error;
13489:             state.requests = res.data || [];
13490:             renderRequests();
13491:         }
13492: 
13493:         function renderSnapshot() {
13494:             var tb = byId('ic-content');
13495:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13496:                 '<th class="p-3">الفرع</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">فعلي</th><th class="p-3">محجوز</th><th class="p-3">متاح</th><th class="p-3">ROP</th><th class="p-3">إعادة الطلب</th><th class="p-3">القيمة</th></tr></thead><tbody>';
13497:             if (!state.snapshot.length) h += '<tr><td colspan="9" class="p-8 text-center text-slate-500">لا توجد بيانات</td></tr>';
13498:             for (var i = 0; i < state.snapshot.length; i++) {
13499:                 var x = state.snapshot[i];
13500:                 h += '<tr class="border-b hover:bg-slate-50">' +
13501:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code) + '</td>' +
13502:                     '<td class="p-3 font-bold">' + escIC(x.item_code) + '</td>' +
13503:                     '<td class="p-3 font-semibold">' + escIC(x.item_name) + '</td>' +
13504:                     '<td class="p-3 text-center">' + fmtIC(x.physical_qty) + '</td>' +
13505:                     '<td class="p-3 text-center text-orange-700">' + fmtIC(x.allocated_qty) + '</td>' +
13506:                     '<td class="p-3 text-center font-black">' + fmtIC(x.available_qty) + '</td>' +
13507:                     '<td class="p-3 text-center">' + fmtIC(x.reorder_point) + '</td>' +
13508:                     '<td class="p-3 text-center font-bold ' + (x.low_stock ? 'text-red-600' : 'text-emerald-600') + '">' + fmtIC(x.suggested_replenishment_qty) + '</td>' +
13509:                     '<td class="p-3 text-center">' + fmtIC(x.stock_value_at_cost) + '</td>' +
13510:                 '</tr>';
13511:             }
13512:             h += '</tbody></table>';
13513:             safeHTML(tb, h);
13514:         }
13515: 
13516:         function renderMovements() {
13517:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13518:                 '<th class="p-3">التاريخ</th><th class="p-3">الحركة</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">الفرع</th><th class="p-3">الأثر</th><th class="p-3">المرجع</th><th class="p-3">المستخدم</th></tr></thead><tbody>';
13519:             if (!state.movements.length) h += '<tr><td colspan="8" class="p-8 text-center text-slate-500">لا توجد حركات</td></tr>';
13520:             for (var i = 0; i < state.movements.length; i++) {
13521:                 var x = state.movements[i];
13522:                 h += '<tr class="border-b hover:bg-slate-50">' +
13523:                     '<td class="p-3">' + escIC(x.movement_date || x.created_at) + '</td>' +
13524:                     '<td class="p-3 font-bold">' + escIC(x.movement_type) + '</td>' +
13525:                     '<td class="p-3">' + escIC(x.item_code) + '</td>' +
13526:                     '<td class="p-3">' + escIC(x.item_name) + '</td>' +
13527:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code || '') + '</td>' +
13528:                     '<td class="p-3 text-center font-black">' + fmtIC(x.effect_qty == null ? x.qty : x.effect_qty) + '</td>' +
13529:                     '<td class="p-3">' + escIC(x.reference || x.voucher_id || '') + '</td>' +
13530:                     '<td class="p-3">' + escIC(x.user_email || '') + '</td>' +
13531:                 '</tr>';
13532:             }
13533:             h += '</tbody></table>';
13534:             safeHTML(byId('ic-content'), h);
13535:         }
13536: 
13537:         function renderReplenishment() {
13538:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13539:                 '<th class="p-3">الفرع</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">المتاح</th><th class="p-3">ROP</th><th class="p-3">الموصى به</th><th class="p-3">التكلفة</th><th class="p-3">القيمة</th></tr></thead><tbody>';
13540:             if (!state.replenishment.length) h += '<tr><td colspan="8" class="p-8 text-center text-slate-500">لا توجد توصيات حاليًا</td></tr>';
13541:             for (var i = 0; i < state.replenishment.length; i++) {
13542:                 var x = state.replenishment[i];
13543:                 h += '<tr class="border-b hover:bg-slate-50">' +
13544:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code) + '</td>' +
13545:                     '<td class="p-3 font-bold">' + escIC(x.item_code) + '</td>' +
13546:                     '<td class="p-3 font-semibold">' + escIC(x.item_name) + '</td>' +
13547:                     '<td class="p-3 text-center">' + fmtIC(x.available_qty) + '</td>' +
13548:                     '<td class="p-3 text-center">' + fmtIC(x.reorder_point) + '</td>' +
13549:                     '<td class="p-3 text-center font-black text-emerald-700">' + fmtIC(x.recommended_order_qty) + '</td>' +
13550:                     '<td class="p-3 text-center">' + fmtIC(x.cost_price) + '</td>' +
13551:                     '<td class="p-3 text-center font-bold">' + fmtIC(x.recommended_order_value) + '</td>' +
13552:                 '</tr>';
13553:             }
13554:             h += '</tbody></table>';
13555:             safeHTML(byId('ic-content'), h);
13556:         }
13557: 
13558:         function renderCounts() {
13559:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white"><tr><th class="p-3">التاريخ</th><th class="p-3">النوع</th><th class="p-3">الحالة</th><th class="p-3">المرجع</th><th class="p-3">عملية</th><th class="p-3">إجراء</th></tr></thead><tbody>';
13560:             if (!state.counts.length) h += '<tr><td colspan="6" class="p-8 text-center text-slate-500">لا توجد جلسات جرد</td></tr>';
13561:             for (var i = 0; i < state.counts.length; i++) {
13562:                 var x = state.counts[i];
13563:                 var actionable = ['InProgress','Draft'].indexOf(x.status) !== -1;
13564:                 h += '<tr class="border-b hover:bg-slate-50">' +
13565:                     '<td class="p-3">' + escIC(x.count_date || x.created_at) + '</td>' +
13566:                     '<td class="p-3">' + escIC(x.type) + '</td>' +
13567:                     '<td class="p-3 font-bold">' + escIC(x.status) + '</td>' +
13568:                     '<td class="p-3">' + escIC(x.reference || '') + '</td>' +
13569:                     '<td class="p-3 font-mono text-xs">' + escIC(x.operation_id || '') + '</td>' +
13570:                     '<td class="p-3">' +
13571:                         (actionable ? '<button data-count-id="' + escIC(x.id) + '" data-count-action="cancel" class="ic-count-cancel px-3 py-1 rounded-lg bg-red-50 text-red-700 font-bold">إلغاء</button>' : '-') +
13572:                     '</td>' +
13573:                 '</tr>';
13574:             }
13575:             h += '</tbody></table>';
13576:             safeHTML(byId('ic-content'), h);
13577:             var btns = c.querySelectorAll('.ic-count-cancel');
13578:             for (var j = 0; j < btns.length; j++) btns[j].onclick = cancelCount;
13579:         }
13580: 
13581:         function renderRequests() {
13582:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white"><tr><th class="p-3">الطلب</th><th class="p-3">التاريخ</th><th class="p-3">المصدر</th><th class="p-3">الوجهة</th><th class="p-3">الحالة</th><th class="p-3">إجراء</th></tr></thead><tbody>';
13583:             if (!state.requests.length) h += '<tr><td colspan="6" class="p-8 text-center text-slate-500">لا توجد طلبات مخزون</td></tr>';
13584:             for (var i = 0; i < state.requests.length; i++) {
13585:                 var x = state.requests[i];
13586:                 var actions = '';
13587:                 if (x.status === 'Pending') {
13588:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="approve" class="ic-req-btn px-2 py-1 rounded-lg bg-emerald-50 text-emerald-700 font-bold ml-1">اعتماد</button>';
13589:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="reject" class="ic-req-btn px-2 py-1 rounded-lg bg-red-50 text-red-700 font-bold">رفض</button>';
13590:                 } else if (x.status === 'Approved') {
13591:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="convert" class="ic-req-btn px-2 py-1 rounded-lg bg-indigo-50 text-indigo-700 font-bold">تحويل لإذن</button>';
13592:                 }
13593:                 h += '<tr class="border-b hover:bg-slate-50">' +
13594:                     '<td class="p-3 font-black text-indigo-700">' + escIC(x.request_code) + '</td>' +
13595:                     '<td class="p-3">' + escIC(x.request_date) + '</td>' +
13596:                     '<td class="p-3 font-mono text-xs">' + escIC(x.source_branch_id || '') + '</td>' +
13597:                     '<td class="p-3 font-mono text-xs">' + escIC(x.target_branch_id || '') + '</td>' +
13598:                     '<td class="p-3 font-bold">' + escIC(x.status) + '</td>' +
13599:                     '<td class="p-3">' + actions + '</td>' +
13600:                 '</tr>';
13601:             }
13602:             h += '</tbody></table>';
13603:             safeHTML(byId('ic-content'), h);
13604:             var btns = c.querySelectorAll('.ic-req-btn');
13605:             for (var j = 0; j < btns.length; j++) btns[j].onclick = handleRequestAction;
13606:         }
13607: 
13608:         async function refreshCurrentTab() {
13609:             try {
13610:                 setBusy(true, 'جاري مزامنة مركز التحكم مع Production...');
13611:                 if (state.tab === 'snapshot') await refreshSnapshot();
13612:                 else if (state.tab === 'movements') await refreshMovements();
13613:                 else if (state.tab === 'replenishment') await refreshReplenishment();
13614:                 else if (state.tab === 'counts') await refreshCounts();
13615:                 else await refreshRequests();
13616:             } catch (e) {
13617:                 showToast(e.message || 'فشل تحديث مركز التحكم', 'error');
13618:             } finally {
13619:                 setBusy(false);
13620:             }
13621:         }
13622: 
13623:         async function refreshAll() {
13624:             await refreshCurrentTab();
13625:             if (state.tab !== 'replenishment') {
13626:                 try {
13627:                     var d = await callIC('REPLENISHMENT', { branch_id: state.branchId || null, limit: 200, offset: 0 });
13628:                     state.replenishment = d.rows || [];
13629:                     safeText(byId('ic-kpi-repl'), fmtIC(state.replenishment.length));
13630:                 } catch (e) {}
13631:             }
13632:             try { await refreshCounts(); } catch (e2) {}
13633:         }
13634: 
13635:         async function createCountSession() {
13636:             var options = '';
13637:             for (var i = 0; i < state.branches.length; i++) options += '<option value="' + escIC(state.branches[i].id) + '">' + escIC(state.branches[i].name || state.branches[i].branch_code) + '</option>';
13638:             var r = await Swal.fire({
13639:                 title: 'جلسة جرد جديدة',
13640:                 html: '<select id="ic-count-branch" class="swal2-input">' + options + '</select><input id="ic-count-ref" class="swal2-input" placeholder="مرجع الجرد"><textarea id="ic-count-notes" class="swal2-textarea" placeholder="ملاحظات"></textarea>',
13641:                 showCancelButton: true,
13642:                 confirmButtonText: 'إنشاء',
13643:                 cancelButtonText: 'إلغاء',
13644:                 preConfirm: function() {
13645:                     return {
13646:                         branch: byId('ic-count-branch').value,
13647:                         ref: byId('ic-count-ref').value || '',
13648:                         notes: byId('ic-count-notes').value || ''
13649:                     };
13650:                 }
13651:             });
13652:             if (!r.isConfirmed) return;
13653:             try {
13654:                 setBusy(true, 'جاري إنشاء جلسة الجرد...');
13655:                 var operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('IC-' + Date.now());
13656:                 var d = await callIC('COUNT', {
13657:                     operation: 'CREATE',
13658:                     operation_id: operationId,
13659:                     payload: { type: 'branch', entity_id: r.value.branch, reference: r.value.ref, notes: r.value.notes }
13660:                 });
13661:                 showToast(d.duplicate ? 'تم استرجاع جلسة الجرد السابقة' : 'تم إنشاء جلسة الجرد', 'success');
13662:                 state.tab = 'counts';
13663:                 renderTabButtons();
13664:                 renderFilters();
13665:                 await refreshCounts();
13666:             } catch (e) {
13667:                 showToast(e.message || 'فشل إنشاء جلسة الجرد', 'error');
13668:             } finally {
13669:                 setBusy(false);
13670:             }
13671:         }
13672: 
13673:         async function cancelCount() {
13674:             var id = this.getAttribute('data-count-id');
13675:             if (!id) return;
13676:             try {
13677:                 setBusy(true, 'جاري إلغاء جلسة الجرد...');
13678:                 await callIC('COUNT', { operation: 'CANCEL', payload: { request_id: id, count_id: id } });
13679:                 showToast('تم إلغاء جلسة الجرد', 'success');
13680:                 await refreshCounts();
13681:             } catch (e) {
13682:                 showToast(e.message || 'فشل إلغاء الجرد', 'error');
13683:             } finally {
13684:                 setBusy(false);
13685:             }
13686:         }
13687: 
13688:         async function handleRequestAction() {
13689:             var id = this.getAttribute('data-req-id');
13690:             var action = this.getAttribute('data-req-action');
13691:             if (!id || !action) return;
13692:             var op = action.toUpperCase();
13693:             var payload = { request_id: id };
13694:             if (action === 'reject') {
13695:                 var r = await Swal.fire({ title: 'رفض الطلب', input: 'textarea', inputLabel: 'سبب الرفض', showCancelButton: true, confirmButtonText: 'رفض', cancelButtonText: 'إلغاء' });
13696:                 if (!r.isConfirmed) return;
13697:                 payload.reason = r.value || '';
13698:             }
13699:             try {
13700:                 setBusy(true, 'جاري تحديث طلب المخزون...');
13701:                 var d = await callIC('REQUEST', { operation: op, operation_id: null, payload: payload });
13702:                 showToast(d.duplicate ? 'تم استرجاع العملية السابقة' : 'تم تنفيذ العملية', 'success');
13703:                 await refreshRequests();
13704:             } catch (e) {
13705:                 showToast(e.message || 'فشل تحديث طلب المخزون', 'error');
13706:             } finally {
13707:                 setBusy(false);
13708:             }
13709:         }
13710: 
13711:         async function createStockRequest() {
13712:             if (state.branches.length < 2) {
13713:                 showToast('يلزم وجود فرعي مصدر ووجهة مختلفين', 'warning');
13714:                 return;
13715:             }
13716:             var sourceOptions = '', targetOptions = '';
13717:             for (var i = 0; i < state.branches.length; i++) {
13718:                 var b = state.branches[i];
13719:                 sourceOptions += '<option value="' + escIC(b.id) + '">' + escIC(b.name || b.branch_code) + '</option>';
13720:                 targetOptions += '<option value="' + escIC(b.id) + '">' + escIC(b.name || b.branch_code) + '</option>';
13721:             }
13722:             var r = await Swal.fire({
13723:                 title: 'طلب نقل مخزني جديد',
13724:                 html: '<select id="ic-r-source" class="swal2-input">' + sourceOptions + '</select><select id="ic-r-target" class="swal2-input">' + targetOptions + '</select><textarea id="ic-r-items" class="swal2-textarea" placeholder="صنف في كل سطر: 1001|5"></textarea><textarea id="ic-r-notes" class="swal2-textarea" placeholder="ملاحظات"></textarea>',
13725:                 showCancelButton: true,
13726:                 confirmButtonText: 'إنشاء',
13727:                 cancelButtonText: 'إلغاء',
13728:                 preConfirm: function() {
13729:                     var lines = (byId('ic-r-items').value || '').split('\n');
13730:                     var items = [];
13731:                     for (var k = 0; k < lines.length; k++) {
13732:                         var line = lines[k].trim();
13733:                         if (!line) continue;
13734:                         var parts = line.split('|');
13735:                         if (!parts[0] || Number(parts[1]) <= 0) {
13736:                             Swal.showValidationMessage('صيغة الأصناف: 1001|5');
13737:                             return false;
13738:                         }
13739:                         items.push({ item_code: parts[0].trim(), qty: Number(parts[1]) });
13740:                     }
13741:                     if (!items.length) {
13742:                         Swal.showValidationMessage('أضف صنفًا واحدًا على الأقل');
13743:                         return false;
13744:                     }
13745:                     if (byId('ic-r-source').value === byId('ic-r-target').value) {
13746:                         Swal.showValidationMessage('المصدر والوجهة يجب أن يكونا مختلفين');
13747:                         return false;
13748:                     }
13749:                     return {
13750:                         source: byId('ic-r-source').value,
13751:                         target: byId('ic-r-target').value,
13752:                         items: items,
13753:                         notes: byId('ic-r-notes').value || ''
13754:                     };
13755:                 }
13756:             });
13757:             if (!r.isConfirmed) return;
13758:             try {
13759:                 setBusy(true, 'جاري إنشاء طلب المخزون...');
13760:                 var operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('SR-' + Date.now());
13761:                 var d = await callIC('REQUEST', {
13762:                     operation: 'CREATE',
13763:                     operation_id: operationId,
13764:                     payload: {
13765:                         source_branch_id: r.value.source,
13766:                         target_branch_id: r.value.target,
13767:                         items: r.value.items,
13768:                         notes: r.value.notes
13769:                     }
13770:                 });
13771:                 showToast(d.duplicate ? 'تم استرجاع الطلب السابق' : 'تم إنشاء طلب المخزون', 'success');
13772:                 state.tab = 'requests';
13773:                 renderTabButtons();
13774:                 renderFilters();
13775:                 await refreshRequests();
13776:             } catch (e) {
13777:                 showToast(e.message || 'فشل إنشاء طلب المخزون', 'error');
13778:             } finally {
13779:                 setBusy(false);
13780:             }
13781:         }
13782: 
13783:         var branchRes = await supabase.from('branches')
13784:             .select('id,branch_code,name')
13785:             .eq('company_id', companyId)
13786:             .eq('is_active', true)
13787:             .order('name');
13788:         if (branchRes.error) {
13789:             showToast(branchRes.error.message, 'error');
13790:             return;
13791:         }
13792:         state.branches = branchRes.data || [];
13793: 
13794:         renderShell();
13795:         renderTabButtons();
13796:         renderFilters();
13797:         await refreshAll();
13798: 
13799:         try {
13800:             if (window._rwInventoryControlChannel) {
13801:                 await supabase.removeChannel(window._rwInventoryControlChannel);
13802:             }
13803:             var channel = supabase.channel('rw-inventory-control-' + companyId);
13804:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
13805:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
13806:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
13807:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
13808:             window._rwInventoryControlChannel = channel.subscribe();
13809:         } catch (e) {}
13810:     }
13811:     return {
13812: 			loadInventoryControl: loadInventoryControl,
13813:             loadReceiving: loadReceiving,
13814:     _applyReceiving: _applyReceiving,
13815:     _showReceivingDetails: _showReceivingDetails,
13816:     loadVouchers: loadVouchers,
13817:     _applyVouchers: _applyVouchers,
13818:     _viewVoucherDetails: _viewVoucherDetails,
13819:     _sendVoucher: _sendVoucher,
13820:     _receiveVoucher: _receiveVoucher,
13821:     _openNewVoucherModal: _openNewVoucherModal,
13822:     loadVoucherForm: loadVoucherForm,
13823:     _searchVoucherItem: _searchVoucherItem,
13824:     _addVoucherItem: _addVoucherItem,
13825:     _renderVoucherCart: _renderVoucherCart,
13826:     _updateVoucherQty: _updateVoucherQty,
13827:     _updateVoucherPrice: _updateVoucherPrice,
13828:     _removeVoucherItem: _removeVoucherItem,
13829:     _clearVoucherCart: _clearVoucherCart,
13830:     _saveAndSendVoucher: _saveAndSendVoucher,
13831:     loadPicking: loadPicking,
13832:     _applyPicking: _applyPicking,
13833:     _showPickingDetails: _showPickingDetails,
13834:     loadLoading: loadLoading,
13835:     _applyLoading: _applyLoading,
13836:     _showLoadingDetails: _showLoadingDetails,
13837:     loadDelivery: loadDelivery,
13838:     _applyDelivery: _applyDelivery,
13839:     _showDeliveryDetails: _showDeliveryDetails,
13840:     loadReturn: loadReturn,
13841:     _applyReturn: _applyReturn,
13842:     _showReturnDetails: _showReturnDetails,
13843:     loadUnloading: loadUnloading,
13844:     _applyUnloading: _applyUnloading,
13845:     _showUnloadingDetails: _showUnloadingDetails,
13846:     loadVehicleCount: loadVehicleCount,
13847:     loadBranchCount: loadBranchCount,
13848:     loadGeneralCount: loadGeneralCount,
13849:     loadSettlement: loadSettlement,
13850:     _searchDriver: _searchDriver,
13851:     _selectDriver: _selectDriver,
13852:     _startBarcodeScanner: _startBarcodeScanner,
13853:     _searchInvItem: _searchInvItem,
13854:     _addToInvCart: _addToInvCart,
13855:     _renderInvCart: _renderInvCart,
13856:     _updateInvCartQty: _updateInvCartQty,
13857:     _removeInvCartItem: _removeInvCartItem,
13858:     _saveVehicleCount: _saveVehicleCount,
13859:     _saveBranchCount: _saveBranchCount,
13860:     _saveGeneralCount: _saveGeneralCount,
13861:     _saveInvCount: _saveInvCount,
13862:     _onSettlementRsChange: _onSettlementRsChange,
13863:     _saveSettlement: _saveSettlement,
13864:     _openPickingModal: _openPickingModal,
13865:     _openLoadingModal: _openLoadingModal,
13866:     _openDeliveryModal: _openDeliveryModal,
13867:     _openReturnModal: _openReturnModal,
13868:     _startPicking: _changeStatus,
13869:     _startLoading: _changeStatus,
13870:     _startDelivery: _changeStatus,
13871:     _startReturn: _changeStatus,
13872:     _confirmUnload: _confirmUnload,
13873:     _changeStatus: _changeStatus
13874:     };
13875: })();
