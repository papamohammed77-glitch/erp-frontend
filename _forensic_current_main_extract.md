# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=23819
FILE_BYTES=1321015
SHA256=0c787d98387cc9cd6eddeeeca9694d996bc471be90f93e36b6254b0591f6b3e2
PATTERN var RW_Warehouse: [10950]
PATTERN loadInventoryControl: [13235, 14316, 22017]
PATTERN loadReceiving: [10954, 14317, 22043]
PATTERN loadVouchers: [11123, 11444, 11452, 11574, 11639, 14320, 22044]
PATTERN loadVoucherForm: [11104, 11679, 14326, 22045, 22046, 22047, 22048]
PATTERN loadPicking: [11683, 14335, 22034]
PATTERN loadLoading: [11735, 14338, 22035]
PATTERN loadDelivery: [11824, 14341, 22036]
PATTERN loadReturn: [11873, 14344, 22037]
PATTERN loadUnloading: [11922, 14347, 22042]
PATTERN loadVehicleCount: [12084, 14350, 22049]
PATTERN loadBranchCount: [12468, 14351, 22050]
PATTERN loadGeneralCount: [12499, 14352, 22051]
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
--- WINDOW 14286-14416 around 14316 ---
14286: 
14287:         var branchRes = await supabase.from('branches')
14288:             .select('id,branch_code,name')
14289:             .eq('company_id', companyId)
14290:             .eq('is_active', true)
14291:             .order('name');
14292:         if (branchRes.error) {
14293:             showToast(branchRes.error.message, 'error');
14294:             return;
14295:         }
14296:         state.branches = branchRes.data || [];
14297: 
14298:         renderShell();
14299:         renderTabButtons();
14300:         renderFilters();
14301:         await refreshAll();
14302: 
14303:         try {
14304:             if (window._rwInventoryControlChannel) {
14305:                 await supabase.removeChannel(window._rwInventoryControlChannel);
14306:             }
14307:             var channel = supabase.channel('rw-inventory-control-' + companyId);
14308:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
14309:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
14310:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
14311:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
14312:             window._rwInventoryControlChannel = channel.subscribe();
14313:         } catch (e) {}
14314:     }
14315:     return {
14316: 			loadInventoryControl: loadInventoryControl,
14317:             loadReceiving: loadReceiving,
14318:     _applyReceiving: _applyReceiving,
14319:     _showReceivingDetails: _showReceivingDetails,
14320:     loadVouchers: loadVouchers,
14321:     _applyVouchers: _applyVouchers,
14322:     _viewVoucherDetails: _viewVoucherDetails,
14323:     _sendVoucher: _sendVoucher,
14324:     _receiveVoucher: _receiveVoucher,
14325:     _openNewVoucherModal: _openNewVoucherModal,
14326:     loadVoucherForm: loadVoucherForm,
14327:     _searchVoucherItem: _searchVoucherItem,
14328:     _addVoucherItem: _addVoucherItem,
14329:     _renderVoucherCart: _renderVoucherCart,
14330:     _updateVoucherQty: _updateVoucherQty,
14331:     _updateVoucherPrice: _updateVoucherPrice,
14332:     _removeVoucherItem: _removeVoucherItem,
14333:     _clearVoucherCart: _clearVoucherCart,
14334:     _saveAndSendVoucher: _saveAndSendVoucher,
14335:     loadPicking: loadPicking,
14336:     _applyPicking: _applyPicking,
14337:     _showPickingDetails: _showPickingDetails,
14338:     loadLoading: loadLoading,
14339:     _applyLoading: _applyLoading,
14340:     _showLoadingDetails: _showLoadingDetails,
14341:     loadDelivery: loadDelivery,
14342:     _applyDelivery: _applyDelivery,
14343:     _showDeliveryDetails: _showDeliveryDetails,
14344:     loadReturn: loadReturn,
14345:     _applyReturn: _applyReturn,
14346:     _showReturnDetails: _showReturnDetails,
14347:     loadUnloading: loadUnloading,
14348:     _applyUnloading: _applyUnloading,
14349:     _showUnloadingDetails: _showUnloadingDetails,
14350:     loadVehicleCount: loadVehicleCount,
14351:     loadBranchCount: loadBranchCount,
14352:     loadGeneralCount: loadGeneralCount,
14353:     loadSettlement: loadSettlement,
14354:     _searchDriver: _searchDriver,
14355:     _selectDriver: _selectDriver,
14356:     _startBarcodeScanner: _startBarcodeScanner,
14357:     _searchInvItem: _searchInvItem,
14358:     _addToInvCart: _addToInvCart,
14359:     _renderInvCart: _renderInvCart,
14360:     _updateInvCartQty: _updateInvCartQty,
14361:     _removeInvCartItem: _removeInvCartItem,
14362:     _saveVehicleCount: _saveVehicleCount,
14363:     _saveBranchCount: _saveBranchCount,
14364:     _saveGeneralCount: _saveGeneralCount,
14365:     _saveInvCount: _saveInvCount,
14366:     _onSettlementRsChange: _onSettlementRsChange,
14367:     _saveSettlement: _saveSettlement,
14368:     _openPickingModal: _openPickingModal,
14369:     _openLoadingModal: _openLoadingModal,
14370:     _openDeliveryModal: _openDeliveryModal,
14371:     _openReturnModal: _openReturnModal,
14372:     _startPicking: _changeStatus,
14373:     _startLoading: _changeStatus,
14374:     _startDelivery: _changeStatus,
14375:     _startReturn: _changeStatus,
14376:     _confirmUnload: _confirmUnload,
14377:     _changeStatus: _changeStatus
14378:     };
14379: })();
14380: window.RW_Warehouse = RW_Warehouse;
14381: // ============================================================
14382: // RW_Finance – الحسابات والمالية (وحدة كاملة - Supabase مباشر)
14383: // ============================================================
14384: var RW_Finance = (function() {
14385:     function _showLoader(m) { try { if (typeof showLoader === 'function') showLoader(m || 'جاري التحميل...'); } catch(e) { console.error(e); } }
14386:     function _hideLoader() { try { if (typeof hideLoader === 'function') hideLoader(); } catch(e) { console.error(e); } }
14387:     function _showToast(m, t) { try { if (typeof showToast === 'function') showToast(m, t || 'success'); } catch(e) { alert(m); } }
14388:     function _fmtNum(n) { return parseFloat(n || 0).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
14389:     function _esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
14390: 
14391:     function _companyId() {
14392:         var id = null;
14393:         if (typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.app) {
14394:             id = RW_STATE.app.companyId || null;
14395:         }
14396:         if (!id && typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.user) {
14397:             id = RW_STATE.user.companyId || null;
14398:         }
14399:         if (!id) throw new Error('سياق الشركة غير محدد');
14400:         return id;
14401:     }
14402:     var _cache = { loaded: false, accountsTree: [], accountsFlat: [], treasury: [] };
14403: 
14404:     function _loadAllData(callback) {
14405:         if (_cache.loaded) { if (callback) callback(); return; }
14406:         var companyId;
14407:         try {
14408:             companyId = _companyId();
14409:         } catch (e) {
14410:             _showToast(e.message || 'سياق الشركة غير محدد', 'error');
14411:             if (callback) callback();
14412:             return;
14413:         }
14414: 
14415:         _showLoader('جاري تحميل البيانات المالية...');
14416:         Promise.all([
--- WINDOW 21987-22117 around 22017 ---
21987:             'receiving':'الاستلام',
21988:             'picking':'التحضير',
21989:             'loading':'التحميل',
21990:             'delivery':'التوصيل',
21991:             'return':'المرتجعات',
21992: 			'sales-returns':'إدارة مرتجعات المبيعات',
21993:             'unloading':'التفريغ',
21994:             'vouchers':'الأذونات المخزنية',
21995:             'transfer':'تحويل مخزني',
21996:             'direct-sale':'صرف سيارة بيع مباشر',
21997:             'direct-return':'استلام مرتجع سيارة',
21998:             'supplier-return':'مرتجع لمورد',
21999:             'vehicle-count':'جرد سيارة',
22000:             'branch-count':'جرد فرع',
22001:             'general-count':'جرد عام',
22002:             'finance':'الإدارة المالية',
22003:             'reports-dashboard':'لوحة القيادة',
22004:             'reports-detailed':'التقارير التفصيلية',
22005:             'reports-comprehensive':'التقارير الشاملة',
22006:             'audit-log':'سجل التدقيق',
22007:             'hr':'الموارد البشرية',
22008:             'crm':'إدارة علاقات العملاء'
22009:         };
22010:         safeText(byId('rw-header-title'), titles[view] || view);
22011: 
22012:         if (view === 'dashboard') { RW_Dashboard.render(); return; }
22013:         if (view === 'items') { RW_Items.render(); return; }
22014:         if (view === 'customers') { RW_Customers.render(); return; }
22015:         if (view === 'suppliers') { RW_Suppliers.render(); return; }
22016:         if (view === 'branches') { RW_Branches.render(); return; }
22017: 		if (view === 'inventory-control') { RW_Warehouse.loadInventoryControl(); return; }
22018:         if (view === 'settings') { RW_Settings.render(); return; }
22019:         if (view === 'hr') { RW_HR.render(); return; }
22020:         if (view === 'crm') { RW_CRM.render(); return; }
22021:         if (view === 'users') { RW_Users.render(); return; }
22022:         if (view === 'roles') { RW_Roles.render(); return; }
22023:         if (view === 'license') { RW_OwnerLicense.render(); return; }
22024:         if (view === 'telesales') { RW_TeleSales.render(); return; }
22025:         if (view === 'pos') { RW_POS.render(); return; }
22026:         if (view === 'orders') { RW_Orders.render(); return; }
22027: 		if (view === 'quotes') { RW_SalesQuotes.render(); return; }
22028: 		if (view === 'price-lists') { RW_PriceLists.render(); return; }
22029: 		if (view === 'promotions') { RW_Promotions.render(); return; }
22030:         if (view === 'runsheets') { RW_Runsheets.render(); return; }
22031:         if (view === 'online-store') { RW_OnlineStore.render(); return; }
22032:         if (view === 'purchases') { RW_Purchases.renderOrders(); return; }
22033:         if (view === 'purchase-pos') { RW_Purchases.renderPOS(); return; }
22034:         if (view === 'picking') { RW_Warehouse.loadPicking(); return; }
22035:         if (view === 'loading') { RW_Warehouse.loadLoading(); return; }
22036:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
22037:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
22038: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
22039: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
22040: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
22041: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
22042:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
22043:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
22044:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
22045:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
22046:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
22047:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
22048:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
22049:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
22050:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
22051:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
22052:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
22053:         if (view === 'finance') { RW_Finance.render(); return; }
22054:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
22055:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
22056:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
22057:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
22058: 
22059:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
22060:     }
22061: };
22062: window.RW_Views = RW_Views;
22063: // ============================================================
22064: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
22065: // ============================================================
22066: var RW_HR = (function() {
22067:     'use strict';
22068: 
22069:     var hrData = [];
22070: 
22071:     function _esc(s) {
22072:         return String(s == null ? '' : s)
22073:             .replace(/&/g, '&amp;')
22074:             .replace(/</g, '&lt;')
22075:             .replace(/>/g, '&gt;');
22076:     }
22077: 
22078:     function _escAttr(s) {
22079:         return _esc(s)
22080:             .replace(/\"/g, '&quot;')
22081:             .replace(/'/g, '&#39;');
22082:     }
22083: 
22084:     function _fmtNum(n) {
22085:         return Number(n || 0).toLocaleString('ar-EG');
22086:     }
22087: 
22088:     function _companyId() {
22089:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
22090:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
22091:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
22092:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
22093:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
22094:         }
22095:         return null;
22096:     }
22097: 
22098:     async function _loadEmployees() {
22099:         var res = await supabase.rpc('hr_list_employees');
22100:         if (res.error) throw res.error;
22101:         hrData = res.data || [];
22102:         return hrData;
22103:     }
22104: 
22105:     function _employeeCard(emp) {
22106:         var profileSalary = Number(emp.basic_salary || 0) +
22107:             Number(emp.housing_allowance || 0) +
22108:             Number(emp.transport_allowance || 0) +
22109:             Number(emp.other_allowance || 0) -
22110:             Number(emp.default_deduction || 0);
22111:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
22112:             '<div class="flex items-center gap-4 mb-4">' +
22113:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
22114:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
22115:             '</div>' +
22116:             '<div class="space-y-2 text-sm">' +
22117:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
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
--- RW_Warehouse_FULL 10950-14379 ---
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
13636:             var branchOptionsHtml = '';
13637:             for (var i = 0; i < state.branches.length; i++) {
13638:                 branchOptionsHtml += '<option value="' + escIC(state.branches[i].id) + '">' +
13639:                     escIC(state.branches[i].name || state.branches[i].branch_code) + '</option>';
13640:             }
13641: 
13642:             var r = await Swal.fire({
13643:                 title: 'جلسة جرد جديدة',
13644:                 width: 760,
13645:                 html:
13646:                     '<div class="text-right space-y-4">' +
13647:                         '<div class="rounded-2xl bg-indigo-50 border border-indigo-100 p-4">' +
13648:                             '<div class="font-black text-indigo-900">ابدأ جردًا فعليًا للفرع</div>' +
13649:                             '<div class="text-sm text-indigo-700 mt-1">سيتم إنشاء الجلسة ثم تحميل أصناف الفرع تلقائيًا وفتح شاشة العد والمراجعة.</div>' +
13650:                         '</div>' +
13651:                         '<div class="grid grid-cols-1 md:grid-cols-2 gap-3">' +
13652:                             '<div>' +
13653:                                 '<label class="block text-sm font-black text-slate-700 mb-2">الفرع</label>' +
13654:                                 '<select id="ic-count-branch" class="swal2-input !w-full !m-0">' + branchOptionsHtml + '</select>' +
13655:                             '</div>' +
13656:                             '<div>' +
13657:                                 '<label class="block text-sm font-black text-slate-700 mb-2">تاريخ الجرد</label>' +
13658:                                 '<input id="ic-count-date" type="date" class="swal2-input !w-full !m-0" value="' + new Date().toISOString().slice(0, 10) + '">' +
13659:                             '</div>' +
13660:                         '</div>' +
13661:                         '<div>' +
13662:                             '<label class="block text-sm font-black text-slate-700 mb-2">مرجع الجرد</label>' +
13663:                             '<input id="ic-count-ref" class="swal2-input !w-full !m-0" placeholder="مثال: جرد نهاية اليوم / جرد دوري / جرد مفاجئ">' +
13664:                         '</div>' +
13665:                         '<div>' +
13666:                             '<label class="block text-sm font-black text-slate-700 mb-2">ملاحظات</label>' +
13667:                             '<textarea id="ic-count-notes" class="swal2-textarea !w-full !m-0" placeholder="ملاحظات الجرد أو تعليمات فريق العد"></textarea>' +
13668:                         '</div>' +
13669:                     '</div>',
13670:                 showCancelButton: true,
13671:                 confirmButtonText: 'بدء الجرد',
13672:                 cancelButtonText: 'إلغاء',
13673:                 focusConfirm: false,
13674:                 preConfirm: function() {
13675:                     var branch = byId('ic-count-branch').value || '';
13676:                     var countDate = byId('ic-count-date').value || '';
13677:                     if (!branch) {
13678:                         Swal.showValidationMessage('اختر الفرع أولًا');
13679:                         return false;
13680:                     }
13681:                     if (!countDate) {
13682:                         Swal.showValidationMessage('حدد تاريخ الجرد');
13683:                         return false;
13684:                     }
13685:                     return {
13686:                         branch: branch,
13687:                         countDate: countDate,
13688:                         ref: byId('ic-count-ref').value || '',
13689:                         notes: byId('ic-count-notes').value || ''
13690:                     };
13691:                 }
13692:             });
13693: 
13694:             if (!r.isConfirmed) return;
13695: 
13696:             try {
13697:                 setBusy(true, 'جاري إنشاء جلسة الجرد وتجهيز أصناف الفرع...');
13698: 
13699:                 var operationId = (window.crypto && window.crypto.randomUUID) ?
13700:                     window.crypto.randomUUID() : ('IC-' + Date.now() + '-' + Math.floor(Math.random() * 100000));
13701: 
13702:                 var created = await callIC('COUNT', {
13703:                     operation: 'CREATE',
13704:                     operation_id: operationId,
13705:                     payload: {
13706:                         type: 'branch',
13707:                         entity_id: r.value.branch,
13708:                         count_date: r.value.countDate,
13709:                         reference: r.value.ref,
13710:                         notes: r.value.notes
13711:                     }
13712:                 });
13713: 
13714:                 var countId = created.count_id;
13715:                 if (!countId) throw new Error('لم يتم إرجاع رقم جلسة الجرد');
13716: 
13717:                 await callIC('COUNT', {
13718:                     operation: 'POPULATE',
13719:                     payload: { count_id: countId }
13720:                 });
13721: 
13722:                 state.tab = 'counts';
13723:                 renderTabButtons();
13724:                 renderFilters();
13725:                 await refreshCounts();
13726: 
13727:                 async function openCountEditor() {
13728:                     var loaded = await callIC('COUNT', {
13729:                         operation: 'GET',
13730:                         payload: { count_id: countId }
13731:                     });
13732: 
13733:                     var count = loaded.count || {};
13734:                     var details = loaded.details || [];
13735:                     var catalog = (RW_STATE && RW_STATE.data && Array.isArray(RW_STATE.data.items)) ? RW_STATE.data.items : [];
13736: 
13737:                     function barcodeOf(code) {
13738:                         for (var bi = 0; bi < catalog.length; bi++) {
13739:                             if (String(catalog[bi].item_code || '') === String(code || '')) {
13740:                                 return catalog[bi].barcode || '';
13741:                             }
13742:                         }
13743:                         return '';
13744:                     }
13745: 
13746:                     function renderCountTable(filter) {
13747:                         filter = String(filter || '').trim().toLowerCase();
13748:                         var rows = '';
13749:                         for (var di = 0; di < details.length; di++) {
13750:                             var d = details[di];
13751:                             var barcode = barcodeOf(d.item_code);
13752:                             var hay = [d.item_code, d.item_name, barcode].join(' ').toLowerCase();
13753:                             if (filter && hay.indexOf(filter) === -1) continue;
13754:                             rows +=
13755:                                 '<tr class="border-b hover:bg-slate-50" data-count-row="' + escIC(d.id) + '">' +
13756:                                     '<td class="p-2 font-black text-indigo-700">' + escIC(d.item_code) + '</td>' +
13757:                                     '<td class="p-2 font-semibold">' + escIC(d.item_name) + '</td>' +
13758:                                     '<td class="p-2 text-center">' + escIC(d.unit || '') + '</td>' +
13759:                                     '<td class="p-2 text-center font-bold text-slate-700">' + fmtIC(d.system_qty) + '</td>' +
13760:                                     '<td class="p-2 text-center"><input data-count-input="' + escIC(d.id) + '" type="number" min="0" step="0.001" value="' + (d.counted_qty == null ? '' : escIC(d.counted_qty)) + '" class="w-28 px-2 py-2 border rounded-lg text-center font-black"></td>' +
13761:                                     '<td class="p-2 text-center font-black" data-count-variance="' + escIC(d.id) + '">' + fmtIC(d.variance_qty) + '</td>' +
13762:                                     '<td class="p-2"><input data-count-note="' + escIC(d.id) + '" value="' + escIC(d.notes || '') + '" class="w-40 px-2 py-2 border rounded-lg text-sm" placeholder="ملاحظة"></td>' +
13763:                                 '</tr>';
13764:                         }
13765:                         if (!rows) rows = '<tr><td colspan="7" class="p-10 text-center text-slate-500">لا توجد أصناف مطابقة للبحث</td></tr>';
13766:                         return rows;
13767:                     }
13768: 
13769:                     var editor = await Swal.fire({
13770:                         title: 'جلسة الجرد — ' + escIC(count.reference || count.count_date || ''),
13771:                         width: 1220,
13772:                         showConfirmButton: false,
13773:                         showCancelButton: false,
13774:                         html:
13775:                             '<div id="ic-count-editor" class="text-right">' +
13776:                                 '<div class="grid grid-cols-2 md:grid-cols-5 gap-2 mb-4">' +
13777:                                     '<div class="rounded-xl bg-slate-50 border p-3"><div class="text-xs text-slate-500">الفرع</div><div class="font-black">' + escIC(count.branch_id || '') + '</div></div>' +
13778:                                     '<div class="rounded-xl bg-blue-50 border border-blue-100 p-3"><div class="text-xs text-blue-700">إجمالي البنود</div><div id="ic-ce-total" class="font-black text-blue-900">' + fmtIC(details.length) + '</div></div>' +
13779:                                     '<div class="rounded-xl bg-emerald-50 border border-emerald-100 p-3"><div class="text-xs text-emerald-700">تم العد</div><div id="ic-ce-counted" class="font-black text-emerald-900">0</div></div>' +
13780:                                     '<div class="rounded-xl bg-amber-50 border border-amber-100 p-3"><div class="text-xs text-amber-700">عجز/زيادة</div><div id="ic-ce-variance" class="font-black text-amber-900">0</div></div>' +
13781:                                     '<div class="rounded-xl bg-purple-50 border border-purple-100 p-3"><div class="text-xs text-purple-700">الحالة</div><div id="ic-ce-status" class="font-black text-purple-900">' + escIC(count.status || '') + '</div></div>' +
13782:                                 '</div>' +
13783:                                 '<div class="flex flex-wrap gap-2 mb-3">' +
13784:                                     '<input id="ic-ce-search" class="flex-1 min-w-[240px] px-3 py-2 border rounded-xl" placeholder="ابحث بالكود أو اسم الصنف أو الباركود">' +
13785:                                     '<button id="ic-ce-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث أرصدة النظام</button>' +
13786:                                     '<button id="ic-ce-save" class="px-4 py-2 rounded-xl bg-blue-600 text-white font-bold">حفظ العد</button>' +
13787:                                     '<button id="ic-ce-finalize" class="px-4 py-2 rounded-xl bg-emerald-600 text-white font-bold">إتمام وتسوية الجرد</button>' +
13788:                                     '<button id="ic-ce-cancel" class="px-4 py-2 rounded-xl bg-red-50 text-red-700 font-bold">إلغاء الجلسة</button>' +
13789:                                 '</div>' +
13790:                                 '<div class="overflow-auto border rounded-2xl max-h-[58vh]">' +
13791:                                     '<table class="w-full text-sm">' +
13792:                                         '<thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13793:                                             '<th class="p-2">الكود</th><th class="p-2">الصنف</th><th class="p-2">الوحدة</th><th class="p-2">رصيد النظام</th><th class="p-2">العد الفعلي</th><th class="p-2">الفرق</th><th class="p-2">ملاحظة</th>' +
13794:                                         '</tr></thead>' +
13795:                                         '<tbody id="ic-ce-body">' + renderCountTable('') + '</tbody>' +
13796:                                     '</table>' +
13797:                                 '</div>' +
13798:                             '</div>',
13799:                         didOpen: function() {
13800:                             function updateSummary() {
13801:                                 var counted = 0;
13802:                                 var variance = 0;
13803:                                 var inputs = document.querySelectorAll('[data-count-input]');
13804:                                 for (var si = 0; si < inputs.length; si++) {
13805:                                     if (inputs[si].value !== '') counted++;
13806:                                 }
13807:                                 for (var sj = 0; sj < details.length; sj++) {
13808:                                     variance += Number(details[sj].variance_qty || 0);
13809:                                 }
13810:                                 safeText(byId('ic-ce-counted'), fmtIC(counted));
13811:                                 safeText(byId('ic-ce-variance'), fmtIC(variance));
13812:                             }
13813: 
13814:                             byId('ic-ce-search').oninput = function() {
13815:                                 safeHTML(byId('ic-ce-body'), renderCountTable(this.value));
13816:                             };
13817: 
13818:                             byId('ic-ce-refresh').onclick = async function() {
13819:                                 try {
13820:                                     showLoader('جاري تحديث أرصدة النظام قبل استكمال الجرد...');
13821:                                     await callIC('COUNT', { operation: 'REFRESH', payload: { count_id: countId, mode: 'ALL' } });
13822:                                     var refreshed = await callIC('COUNT', { operation: 'GET', payload: { count_id: countId } });
13823:                                     count = refreshed.count || count;
13824:                                     details = refreshed.details || [];
13825:                                     safeHTML(byId('ic-ce-body'), renderCountTable(byId('ic-ce-search').value));
13826:                                     updateSummary();
13827:                                     hideLoader();
13828:                                     showToast('تم تحديث أرصدة النظام للجلسة', 'success');
13829:                                 } catch (e) {
13830:                                     hideLoader();
13831:                                     showToast(e.message || 'فشل تحديث أرصدة النظام', 'error');
13832:                                 }
13833:                             };
13834: 
13835:                             byId('ic-ce-save').onclick = async function() {
13836:                                 try {
13837:                                     showLoader('جاري حفظ كميات الجرد...');
13838:                                     var inputs = document.querySelectorAll('[data-count-input]');
13839:                                     for (var si = 0; si < inputs.length; si++) {
13840:                                         var dId = inputs[si].getAttribute('data-count-input');
13841:                                         var value = inputs[si].value;
13842:                                         if (value === '') continue;
13843:                                         var noteEl = document.querySelector('[data-count-note="' + dId + '"]');
13844:                                         var detail = null;
13845:                                         for (var di2 = 0; di2 < details.length; di2++) {
13846:                                             if (String(details[di2].id) === String(dId)) { detail = details[di2]; break; }
13847:                                         }
13848:                                         if (!detail) continue;
13849:                                         var countedQty = Number(value);
13850:                                         if (!Number.isFinite(countedQty) || countedQty < 0) throw new Error('كمية جرد غير صالحة للصنف ' + detail.item_code);
13851:                                         await callIC('COUNT', {
13852:                                             operation: 'UPSERT_LINE',
13853:                                             payload: {
13854:                                                 count_id: countId,
13855:                                                 branch_id: detail.branch_id,
13856:                                                 item_code: detail.item_code,
13857:                                                 counted_qty: countedQty,
13858:                                                 notes: noteEl ? (noteEl.value || '') : (detail.notes || '')
13859:                                             }
13860:                                         });
13861:                                     }
13862:                                     var reloaded = await callIC('COUNT', { operation: 'GET', payload: { count_id: countId } });
13863:                                     count = reloaded.count || count;
13864:                                     details = reloaded.details || [];
13865:                                     safeHTML(byId('ic-ce-body'), renderCountTable(byId('ic-ce-search').value));
13866:                                     updateSummary();
13867:                                     safeText(byId('ic-ce-status'), count.status || 'InProgress');
13868:                                     hideLoader();
13869:                                     showToast('تم حفظ كميات الجرد', 'success');
13870:                                 } catch (e) {
13871:                                     hideLoader();
13872:                                     showToast(e.message || 'فشل حفظ الجرد', 'error');
13873:                                 }
13874:                             };
13875: 
13876:                             byId('ic-ce-finalize').onclick = async function() {
13877:                                 var confirm = await Swal.fire({
13878:                                     title: 'إتمام وتسوية الجرد؟',
13879:                                     text: 'سيتم اعتماد الفروق وتنفيذ حركات التسوية الرسمية عبر محرك المخزون المركزي.',
13880:                                     icon: 'warning',
13881:                                     showCancelButton: true,
13882:                                     confirmButtonText: 'إتمام الجرد',
13883:                                     cancelButtonText: 'إلغاء'
13884:                                 });
13885:                                 if (!confirm.isConfirmed) return;
13886:                                 try {
13887:                                     showLoader('جاري إتمام الجرد وتنفيذ التسويات...');
13888:                                     await callIC('COUNT', { operation: 'FINALIZE', payload: { count_id: countId } });
13889:                                     hideLoader();
13890:                                     showToast('تم إتمام الجرد وتسوية الفروق بنجاح', 'success');
13891:                                     Swal.close();
13892:                                     await refreshCounts();
13893:                                     await refreshCurrentTab();
13894:                                 } catch (e) {
13895:                                     hideLoader();
13896:                                     showToast(e.message || 'فشل إتمام الجرد', 'error');
13897:                                 }
13898:                             };
13899: 
13900:                             byId('ic-ce-cancel').onclick = async function() {
13901:                                 var confirm = await Swal.fire({
13902:                                     title: 'إلغاء جلسة الجرد؟',
13903:                                     text: 'لن يتم تنفيذ أي تسوية مخزنية.',
13904:                                     showCancelButton: true,
13905:                                     confirmButtonText: 'إلغاء الجلسة',
13906:                                     cancelButtonText: 'متابعة'
13907:                                 });
13908:                                 if (!confirm.isConfirmed) return;
13909:                                 try {
13910:                                     await callIC('COUNT', { operation: 'CANCEL', payload: { count_id: countId } });
13911:                                     showToast('تم إلغاء جلسة الجرد', 'success');
13912:                                     Swal.close();
13913:                                     await refreshCounts();
13914:                                 } catch (e) {
13915:                                     showToast(e.message || 'فشل إلغاء الجلسة', 'error');
13916:                                 }
13917:                             };
13918: 
13919:                             updateSummary();
13920:                         }
13921:                     });
13922: 
13923:                     return editor;
13924:                 }
13925: 
13926:                 await openCountEditor();
13927:             } catch (e) {
13928:                 showToast(e.message || 'فشل بدء جلسة الجرد', 'error');
13929:             } finally {
13930:                 setBusy(false);
13931:             }
13932:         }
13933: 
13934:         async function cancelCount() {
13935:             var id = this.getAttribute('data-count-id');
13936:             if (!id) return;
13937:             try {
13938:                 setBusy(true, 'جاري إلغاء جلسة الجرد...');
13939:                 await callIC('COUNT', { operation: 'CANCEL', payload: { request_id: id, count_id: id } });
13940:                 showToast('تم إلغاء جلسة الجرد', 'success');
13941:                 await refreshCounts();
13942:             } catch (e) {
13943:                 showToast(e.message || 'فشل إلغاء الجرد', 'error');
13944:             } finally {
13945:                 setBusy(false);
13946:             }
13947:         }
13948: 
13949:         async function handleRequestAction() {
13950:             var id = this.getAttribute('data-req-id');
13951:             var action = this.getAttribute('data-req-action');
13952:             if (!id || !action) return;
13953:             var op = action.toUpperCase();
13954:             var payload = { request_id: id };
13955:             if (action === 'reject') {
13956:                 var r = await Swal.fire({ title: 'رفض الطلب', input: 'textarea', inputLabel: 'سبب الرفض', showCancelButton: true, confirmButtonText: 'رفض', cancelButtonText: 'إلغاء' });
13957:                 if (!r.isConfirmed) return;
13958:                 payload.reason = r.value || '';
13959:             }
13960:             try {
13961:                 setBusy(true, 'جاري تحديث طلب المخزون...');
13962:                 var d = await callIC('REQUEST', { operation: op, operation_id: null, payload: payload });
13963:                 showToast(d.duplicate ? 'تم استرجاع العملية السابقة' : 'تم تنفيذ العملية', 'success');
13964:                 await refreshRequests();
13965:             } catch (e) {
13966:                 showToast(e.message || 'فشل تحديث طلب المخزون', 'error');
13967:             } finally {
13968:                 setBusy(false);
13969:             }
13970:         }
13971: 
13972:         async function createStockRequest() {
13973:             if (state.branches.length < 2) {
13974:                 showToast('يلزم وجود فرعي مصدر ووجهة مختلفين لإنشاء طلب نقل', 'warning');
13975:                 return;
13976:             }
13977: 
13978:             var sourceOptions = '';
13979:             var targetOptions = '';
13980:             for (var i = 0; i < state.branches.length; i++) {
13981:                 var branch = state.branches[i];
13982:                 sourceOptions += '<option value="' + escIC(branch.id) + '">' + escIC(branch.name || branch.branch_code) + '</option>';
13983:                 targetOptions += '<option value="' + escIC(branch.id) + '">' + escIC(branch.name || branch.branch_code) + '</option>';
13984:             }
13985: 
13986:             var sourceRows = [];
13987:             var cart = [];
13988: 
13989:             function findSourceRow(code) {
13990:                 for (var ri = 0; ri < sourceRows.length; ri++) {
13991:                     if (String(sourceRows[ri].item_code || '') === String(code || '')) return sourceRows[ri];
13992:                 }
13993:                 return null;
13994:             }
13995: 
13996:             function cartIndex(code) {
13997:                 for (var ci = 0; ci < cart.length; ci++) {
13998:                     if (String(cart[ci].item_code || '') === String(code || '')) return ci;
13999:                 }
14000:                 return -1;
14001:             }
14002: 
14003:             function renderSearchResults(query) {
14004:                 query = String(query || '').trim().toLowerCase();
14005:                 var html = '';
14006:                 var shown = 0;
14007:                 for (var i2 = 0; i2 < sourceRows.length; i2++) {
14008:                     var x = sourceRows[i2];
14009:                     var hay = [x.item_code, x.item_name, x.barcode || ''].join(' ').toLowerCase();
14010:                     if (query && hay.indexOf(query) === -1) continue;
14011:                     if (cartIndex(x.item_code) !== -1) continue;
14012:                     html +=
14013:                         '<button type="button" data-ic-add-item="' + escIC(x.item_code) + '" class="w-full text-right p-3 rounded-xl border hover:bg-indigo-50 hover:border-indigo-200 mb-2 bg-white">' +
14014:                             '<div class="flex items-center justify-between gap-3">' +
14015:                                 '<div>' +
14016:                                     '<div class="font-black text-slate-800">' + escIC(x.item_name || x.item_code) + '</div>' +
14017:                                     '<div class="text-xs text-slate-500 mt-1">' + escIC(x.item_code) + (x.barcode ? ' • ' + escIC(x.barcode) : '') + '</div>' +
14018:                                 '</div>' +
14019:                                 '<div class="text-left">' +
14020:                                     '<div class="text-xs text-slate-500">المتاح</div>' +
14021:                                     '<div class="font-black ' + (Number(x.available_qty || 0) > 0 ? 'text-emerald-700' : 'text-red-600') + '">' + fmtIC(x.available_qty) + '</div>' +
14022:                                 '</div>' +
14023:                             '</div>' +
14024:                         '</button>';
14025:                     shown++;
14026:                     if (shown >= 25) break;
14027:                 }
14028:                 if (!html) html = '<div class="p-6 text-center text-slate-500">لا توجد أصناف مطابقة أو تم إضافتها بالفعل</div>';
14029:                 return html;
14030:             }
14031: 
14032:             function renderCart() {
14033:                 var html = '';
14034:                 var totalQty = 0;
14035:                 var totalValue = 0;
14036:                 for (var ci = 0; ci < cart.length; ci++) {
14037:                     var x = cart[ci];
14038:                     var before = Number(x.available_qty || 0);
14039:                     var after = before - Number(x.qty || 0);
14040:                     var qty = Number(x.qty || 0);
14041:                     totalQty += qty;
14042:                     totalValue += qty * Number(x.cost_price || 0);
14043:                     html +=
14044:                         '<tr class="border-b">' +
14045:                             '<td class="p-2 font-black text-indigo-700">' + escIC(x.item_code) + '</td>' +
14046:                             '<td class="p-2 font-semibold">' + escIC(x.item_name) + '</td>' +
14047:                             '<td class="p-2 text-center">' + escIC(x.unit || '') + '</td>' +
14048:                             '<td class="p-2 text-center font-bold text-slate-700">' + fmtIC(before) + '</td>' +
14049:                             '<td class="p-2 text-center"><input data-ic-req-qty="' + escIC(x.item_code) + '" type="number" min="0.001" step="0.001" value="' + escIC(qty) + '" class="w-24 px-2 py-2 border rounded-lg text-center font-black"></td>' +
14050:                             '<td class="p-2 text-center font-black ' + (after < 0 ? 'text-red-600' : 'text-emerald-700') + '">' + fmtIC(after) + '</td>' +
14051:                             '<td class="p-2 text-center">' + fmtIC(Number(x.cost_price || 0)) + '</td>' +
14052:                             '<td class="p-2 text-center font-black">' + fmtIC(qty * Number(x.cost_price || 0)) + '</td>' +
14053:                             '<td class="p-2"><button type="button" data-ic-remove-item="' + escIC(x.item_code) + '" class="px-3 py-1 rounded-lg bg-red-50 text-red-700 font-bold">حذف</button></td>' +
14054:                         '</tr>';
14055:                 }
14056:                 if (!html) html = '<tr><td colspan="10" class="p-10 text-center text-slate-500">لم تتم إضافة أصناف بعد</td></tr>';
14057:                 return { html: html, totalQty: totalQty, totalValue: totalValue };
14058:             }
14059: 
14060:             async function loadSourceSnapshot(branchId) {
14061:                 var d = await callIC('SNAPSHOT', {
14062:                     branch_id: branchId,
14063:                     query: null,
14064:                     low_only: false,
14065:                     limit: 500,
14066:                     offset: 0
14067:                 });
14068:                 sourceRows = d.rows || [];
14069:             }
14070: 
14071:             var modal = await Swal.fire({
14072:                 title: 'طلب نقل مخزني جديد',
14073:                 width: 1280,
14074:                 showConfirmButton: false,
14075:                 showCancelButton: false,
14076:                 html:
14077:                     '<div id="ic-request-editor" class="text-right">' +
14078:                         '<div class="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4">' +
14079:                             '<div>' +
14080:                                 '<label class="block text-sm font-black text-slate-700 mb-2">من المخزن</label>' +
14081:                                 '<select id="ic-r-source" class="!w-full !m-0 swal2-input">' + sourceOptions + '</select>' +
14082:                             '</div>' +
14083:                             '<div>' +
14084:                                 '<label class="block text-sm font-black text-slate-700 mb-2">إلى المخزن</label>' +
14085:                                 '<select id="ic-r-target" class="!w-full !m-0 swal2-input">' + targetOptions + '</select>' +
14086:                             '</div>' +
14087:                             '<div class="rounded-xl bg-blue-50 border border-blue-100 p-3"><div class="text-xs text-blue-700">عدد البنود</div><div id="ic-r-total-lines" class="text-xl font-black text-blue-900">0</div></div>' +
14088:                             '<div class="rounded-xl bg-emerald-50 border border-emerald-100 p-3"><div class="text-xs text-emerald-700">إجمالي الكمية</div><div id="ic-r-total-qty" class="text-xl font-black text-emerald-900">0</div></div>' +
14089:                         '</div>' +
14090:                         '<div class="grid grid-cols-1 lg:grid-cols-5 gap-4">' +
14091:                             '<div class="lg:col-span-2 rounded-2xl bg-slate-50 border p-3">' +
14092:                                 '<div class="font-black text-slate-800 mb-2">إضافة صنف</div>' +
14093:                                 '<input id="ic-r-search" class="w-full px-3 py-2 border rounded-xl bg-white" placeholder="ابحث بالكود أو الاسم أو الباركود">' +
14094:                                 '<div id="ic-r-results" class="mt-3 max-h-[48vh] overflow-auto"></div>' +
14095:                             '</div>' +
14096:                             '<div class="lg:col-span-3 rounded-2xl bg-white border">' +
14097:                                 '<div class="flex items-center justify-between p-3 border-b">' +
14098:                                     '<div class="font-black text-slate-800">بنود الطلب</div>' +
14099:                                     '<div class="text-xs text-slate-500">Available After = Available Before − Requested Qty</div>' +
14100:                                 '</div>' +
14101:                                 '<div class="overflow-auto max-h-[48vh]">' +
14102:                                     '<table class="w-full text-sm">' +
14103:                                         '<thead class="bg-slate-800 text-white sticky top-0"><tr>' +
14104:                                             '<th class="p-2">الكود</th><th class="p-2">الصنف</th><th class="p-2">الوحدة</th><th class="p-2">المتاح قبل</th><th class="p-2">الطلب</th><th class="p-2">المتاح بعد</th><th class="p-2">التكلفة</th><th class="p-2">الإجمالي</th><th class="p-2">إجراء</th>' +
14105:                                         '</tr></thead>' +
14106:                                         '<tbody id="ic-r-cart"></tbody>' +
14107:                                     '</table>' +
14108:                                 '</div>' +
14109:                             '</div>' +
14110:                         '</div>' +
14111:                         '<div class="mt-4">' +
14112:                             '<textarea id="ic-r-notes" class="w-full px-3 py-2 border rounded-xl" rows="3" placeholder="ملاحظات الطلب / سبب النقل"></textarea>' +
14113:                         '</div>' +
14114:                         '<div class="flex flex-wrap justify-end gap-2 mt-4">' +
14115:                             '<button id="ic-r-close" type="button" class="px-5 py-2 rounded-xl bg-slate-100 text-slate-700 font-bold">إغلاق</button>' +
14116:                             '<button id="ic-r-submit" type="button" class="px-5 py-2 rounded-xl bg-indigo-600 text-white font-black">إنشاء طلب النقل</button>' +
14117:                         '</div>' +
14118:                     '</div>',
14119:                 didOpen: async function() {
14120:                     function repaintCart() {
14121:                         var p = renderCart();
14122:                         safeHTML(byId('ic-r-cart'), p.html);
14123:                         safeText(byId('ic-r-total-lines'), fmtIC(cart.length));
14124:                         safeText(byId('ic-r-total-qty'), fmtIC(p.totalQty));
14125: 
14126:                         var qtyInputs = document.querySelectorAll('[data-ic-req-qty]');
14127:                         for (var qi = 0; qi < qtyInputs.length; qi++) {
14128:                             qtyInputs[qi].oninput = function() {
14129:                                 var code = this.getAttribute('data-ic-req-qty');
14130:                                 var idx = cartIndex(code);
14131:                                 if (idx === -1) return;
14132:                                 var value = Number(this.value);
14133:                                 cart[idx].qty = Number.isFinite(value) && value > 0 ? value : 0.001;
14134:                                 repaintCart();
14135:                             };
14136:                         }
14137: 
14138:                         var removeButtons = document.querySelectorAll('[data-ic-remove-item]');
14139:                         for (var rb = 0; rb < removeButtons.length; rb++) {
14140:                             removeButtons[rb].onclick = function() {
14141:                                 var code = this.getAttribute('data-ic-remove-item');
14142:                                 var idx = cartIndex(code);
14143:                                 if (idx !== -1) cart.splice(idx, 1);
14144:                                 repaintCart();
14145:                                 safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14146:                                 bindSearchButtons();
14147:                             };
14148:                         }
14149:                     }
14150: 
14151:                     function bindSearchButtons() {
14152:                         var addButtons = document.querySelectorAll('[data-ic-add-item]');
14153:                         for (var ab = 0; ab < addButtons.length; ab++) {
14154:                             addButtons[ab].onclick = function() {
14155:                                 var code = this.getAttribute('data-ic-add-item');
14156:                                 var row = findSourceRow(code);
14157:                                 if (!row) return;
14158:                                 if (cartIndex(code) !== -1) return;
14159:                                 cart.push({
14160:                                     item_code: row.item_code,
14161:                                     item_name: row.item_name,
14162:                                     unit: row.unit,
14163:                                     available_qty: Number(row.available_qty || 0),
14164:                                     qty: 1,
14165:                                     cost_price: Number(row.cost_price || row.avg_cost || 0)
14166:                                 });
14167:                                 repaintCart();
14168:                                 safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14169:                                 bindSearchButtons();
14170:                             };
14171:                         }
14172:                     }
14173: 
14174:                     byId('ic-r-source').onchange = async function() {
14175:                         var target = byId('ic-r-target').value || '';
14176:                         if (target === this.value) {
14177:                             for (var ti = 0; ti < state.branches.length; ti++) {
14178:                                 if (String(state.branches[ti].id) !== String(this.value)) {
14179:                                     target = state.branches[ti].id;
14180:                                     break;
14181:                                 }
14182:                             }
14183:                             byId('ic-r-target').value = target;
14184:                         }
14185:                         cart = [];
14186:                         try {
14187:                             showLoader('جاري تحميل رصيد الفرع المصدر...');
14188:                             await loadSourceSnapshot(this.value);
14189:                             safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14190:                             bindSearchButtons();
14191:                             repaintCart();
14192:                             hideLoader();
14193:                         } catch (e) {
14194:                             hideLoader();
14195:                             showToast(e.message || 'فشل تحميل رصيد الفرع', 'error');
14196:                         }
14197:                     };
14198: 
14199:                     byId('ic-r-target').onchange = function() {
14200:                         if (this.value === byId('ic-r-source').value) {
14201:                             showToast('المصدر والوجهة يجب أن يكونا مختلفين', 'warning');
14202:                             for (var ti2 = 0; ti2 < state.branches.length; ti2++) {
14203:                                 if (String(state.branches[ti2].id) !== String(byId('ic-r-source').value)) {
14204:                                     this.value = state.branches[ti2].id;
14205:                                     break;
14206:                                 }
14207:                             }
14208:                         }
14209:                     };
14210: 
14211:                     byId('ic-r-search').oninput = function() {
14212:                         safeHTML(byId('ic-r-results'), renderSearchResults(this.value));
14213:                         bindSearchButtons();
14214:                     };
14215: 
14216:                     byId('ic-r-close').onclick = function() { Swal.close(); };
14217: 
14218:                     byId('ic-r-submit').onclick = async function() {
14219:                         var source = byId('ic-r-source').value || '';
14220:                         var target = byId('ic-r-target').value || '';
14221:                         if (!source || !target || source === target) {
14222:                             showToast('اختر مصدرًا ووجهة مختلفين', 'warning');
14223:                             return;
14224:                         }
14225:                         if (!cart.length) {
14226:                             showToast('أضف صنفًا واحدًا على الأقل إلى الطلب', 'warning');
14227:                             return;
14228:                         }
14229:                         for (var vi = 0; vi < cart.length; vi++) {
14230:                             if (!Number.isFinite(Number(cart[vi].qty)) || Number(cart[vi].qty) <= 0) {
14231:                                 showToast('كمية غير صالحة للصنف ' + cart[vi].item_code, 'error');
14232:                                 return;
14233:                             }
14234:                         }
14235: 
14236:                         try {
14237:                             setBusy(true, 'جاري إنشاء طلب النقل وربطه بدورة المخزون...');
14238:                             var operationId = (window.crypto && window.crypto.randomUUID) ?
14239:                                 window.crypto.randomUUID() : ('SR-' + Date.now() + '-' + Math.floor(Math.random() * 100000));
14240: 
14241:                             var items = [];
14242:                             for (var ii = 0; ii < cart.length; ii++) {
14243:                                 items.push({
14244:                                     item_code: cart[ii].item_code,
14245:                                     qty: Number(cart[ii].qty)
14246:                                 });
14247:                             }
14248: 
14249:                             var d = await callIC('REQUEST', {
14250:                                 operation: 'CREATE',
14251:                                 operation_id: operationId,
14252:                                 payload: {
14253:                                     source_branch_id: source,
14254:                                     target_branch_id: target,
14255:                                     items: items,
14256:                                     notes: byId('ic-r-notes').value || ''
14257:                                 }
14258:                             });
14259: 
14260:                             Swal.close();
14261:                             showToast(d.duplicate ? 'تم استرجاع طلب النقل السابق' : 'تم إنشاء طلب النقل بنجاح', 'success');
14262:                             state.tab = 'requests';
14263:                             renderTabButtons();
14264:                             renderFilters();
14265:                             await refreshRequests();
14266:                         } catch (e) {
14267:                             showToast(e.message || 'فشل إنشاء طلب النقل', 'error');
14268:                         } finally {
14269:                             setBusy(false);
14270:                         }
14271:                     };
14272: 
14273:                     try {
14274:                         await loadSourceSnapshot(byId('ic-r-source').value);
14275:                         safeHTML(byId('ic-r-results'), renderSearchResults(''));
14276:                         bindSearchButtons();
14277:                         repaintCart();
14278:                     } catch (e2) {
14279:                         showToast(e2.message || 'فشل تحميل بيانات المخزون', 'error');
14280:                     }
14281:                 }
14282:             });
14283: 
14284:             return modal;
14285:         }
14286: 
14287:         var branchRes = await supabase.from('branches')
14288:             .select('id,branch_code,name')
14289:             .eq('company_id', companyId)
14290:             .eq('is_active', true)
14291:             .order('name');
14292:         if (branchRes.error) {
14293:             showToast(branchRes.error.message, 'error');
14294:             return;
14295:         }
14296:         state.branches = branchRes.data || [];
14297: 
14298:         renderShell();
14299:         renderTabButtons();
14300:         renderFilters();
14301:         await refreshAll();
14302: 
14303:         try {
14304:             if (window._rwInventoryControlChannel) {
14305:                 await supabase.removeChannel(window._rwInventoryControlChannel);
14306:             }
14307:             var channel = supabase.channel('rw-inventory-control-' + companyId);
14308:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
14309:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
14310:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
14311:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
14312:             window._rwInventoryControlChannel = channel.subscribe();
14313:         } catch (e) {}
14314:     }
14315:     return {
14316: 			loadInventoryControl: loadInventoryControl,
14317:             loadReceiving: loadReceiving,
14318:     _applyReceiving: _applyReceiving,
14319:     _showReceivingDetails: _showReceivingDetails,
14320:     loadVouchers: loadVouchers,
14321:     _applyVouchers: _applyVouchers,
14322:     _viewVoucherDetails: _viewVoucherDetails,
14323:     _sendVoucher: _sendVoucher,
14324:     _receiveVoucher: _receiveVoucher,
14325:     _openNewVoucherModal: _openNewVoucherModal,
14326:     loadVoucherForm: loadVoucherForm,
14327:     _searchVoucherItem: _searchVoucherItem,
14328:     _addVoucherItem: _addVoucherItem,
14329:     _renderVoucherCart: _renderVoucherCart,
14330:     _updateVoucherQty: _updateVoucherQty,
14331:     _updateVoucherPrice: _updateVoucherPrice,
14332:     _removeVoucherItem: _removeVoucherItem,
14333:     _clearVoucherCart: _clearVoucherCart,
14334:     _saveAndSendVoucher: _saveAndSendVoucher,
14335:     loadPicking: loadPicking,
14336:     _applyPicking: _applyPicking,
14337:     _showPickingDetails: _showPickingDetails,
14338:     loadLoading: loadLoading,
14339:     _applyLoading: _applyLoading,
14340:     _showLoadingDetails: _showLoadingDetails,
14341:     loadDelivery: loadDelivery,
14342:     _applyDelivery: _applyDelivery,
14343:     _showDeliveryDetails: _showDeliveryDetails,
14344:     loadReturn: loadReturn,
14345:     _applyReturn: _applyReturn,
14346:     _showReturnDetails: _showReturnDetails,
14347:     loadUnloading: loadUnloading,
14348:     _applyUnloading: _applyUnloading,
14349:     _showUnloadingDetails: _showUnloadingDetails,
14350:     loadVehicleCount: loadVehicleCount,
14351:     loadBranchCount: loadBranchCount,
14352:     loadGeneralCount: loadGeneralCount,
14353:     loadSettlement: loadSettlement,
14354:     _searchDriver: _searchDriver,
14355:     _selectDriver: _selectDriver,
14356:     _startBarcodeScanner: _startBarcodeScanner,
14357:     _searchInvItem: _searchInvItem,
14358:     _addToInvCart: _addToInvCart,
14359:     _renderInvCart: _renderInvCart,
14360:     _updateInvCartQty: _updateInvCartQty,
14361:     _removeInvCartItem: _removeInvCartItem,
14362:     _saveVehicleCount: _saveVehicleCount,
14363:     _saveBranchCount: _saveBranchCount,
14364:     _saveGeneralCount: _saveGeneralCount,
14365:     _saveInvCount: _saveInvCount,
14366:     _onSettlementRsChange: _onSettlementRsChange,
14367:     _saveSettlement: _saveSettlement,
14368:     _openPickingModal: _openPickingModal,
14369:     _openLoadingModal: _openLoadingModal,
14370:     _openDeliveryModal: _openDeliveryModal,
14371:     _openReturnModal: _openReturnModal,
14372:     _startPicking: _changeStatus,
14373:     _startLoading: _changeStatus,
14374:     _startDelivery: _changeStatus,
14375:     _startReturn: _changeStatus,
14376:     _confirmUnload: _confirmUnload,
14377:     _changeStatus: _changeStatus
14378:     };
14379: })();
