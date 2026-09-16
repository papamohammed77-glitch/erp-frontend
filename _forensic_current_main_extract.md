# FORENSIC CURRENT MOTHER EXTRACT

FILE_LINES=23980
FILE_BYTES=1335560
SHA256=97ac3ec9060805f738ea6e5457f69c0709efd338e8d514bfda58b18cdbc32c8e
PATTERN var RW_Warehouse: [10969]
PATTERN loadInventoryControl: [13254, 14335, 22178]
PATTERN loadReceiving: [10973, 14336, 22204]
PATTERN loadVouchers: [11142, 11463, 11471, 11593, 11658, 14339, 22205]
PATTERN loadVoucherForm: [11123, 11698, 14345, 22206, 22207, 22208, 22209]
PATTERN loadPicking: [11702, 14354, 22195]
PATTERN loadLoading: [11754, 14357, 22196]
PATTERN loadDelivery: [11843, 14360, 22197]
PATTERN loadReturn: [11892, 14363, 22198]
PATTERN loadUnloading: [11941, 14366, 22203]
PATTERN loadVehicleCount: [12103, 14369, 22210]
PATTERN loadBranchCount: [12487, 14370, 22211]
PATTERN loadGeneralCount: [12518, 14371, 22212]
PATTERN inventory-stock-snapshot: []
PATTERN inventory_stock_snapshot: []
PATTERN inventory_movement_report: []
PATTERN inventory_replenishment_report: []
PATTERN inventory_count_engine: []
PATTERN receive-purchase: [8991]
PATTERN complete-return: [13192]
PATTERN complete-order-delivery: [13098]
PATTERN Idempotency-Key: [8864, 8991, 9114, 11430, 11448, 11653, 12733, 12859]
PATTERN قيد التطوير: []
PATTERN جاري التطوير: []
PATTERN TODO: []
PATTERN FIXME: []
--- WINDOW 13224-13354 around 13254 ---
13224:             if (json.success) {
13225:                 showToast('تم التفريغ بنجاح', 'success');
13226:                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13227:             } else {
13228:                 showToast(json.msg || 'فشل التفريغ', 'error');
13229:             }
13230:         }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13231:     });
13232: }
13233: function _changeStatus(code, funcName) {
13234:     showLoader('جاري تحديث الحالة...');
13235:     supabase.auth.getSession().then(function(ses) {
13236:         var t = ses.data.session ? ses.data.session.access_token : null;
13237:         return fetch(SUPABASE_URL + '/functions/v1/' + funcName, {
13238:             method: 'POST',
13239:             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13240:             body: JSON.stringify({ runsheet_code: code })
13241:         });
13242:     }).then(function(res) { return res.json(); }).then(function(json) {
13243:         hideLoader();
13244:         if (json.success) {
13245:             showToast('تم بنجاح', 'success');
13246:         } else {
13247:             showToast(json.msg || 'فشل', 'error');
13248:         }
13249:     }).catch(function(e) {
13250:         hideLoader();
13251:         showToast('فشل الاتصال', 'error');
13252:     });
13253: }
13254:     async function loadInventoryControl() {
13255:         var c = byId('rw-page-container');
13256:         if (!c) return;
13257: 
13258:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) ||
13259:             (typeof _rwCompanyId === 'function' ? _rwCompanyId() : null);
13260:         if (!companyId) {
13261:             showToast('سياق الشركة غير محدد', 'error');
13262:             return;
13263:         }
13264: 
13265:         var state = {
13266:             tab: 'snapshot',
13267:             branchId: '',
13268:             query: '',
13269:             lowOnly: false,
13270:             movementType: '',
13271:             fromDate: '',
13272:             toDate: '',
13273:             snapshot: [],
13274:             movements: [],
13275:             replenishment: [],
13276:             counts: [],
13277:             requests: [],
13278:             branches: [],
13279:             busy: false
13280:         };
13281: 
13282:         function escIC(v) {
13283:             return String(v == null ? '' : v)
13284:                 .replace(/&/g, '&amp;')
13285:                 .replace(/</g, '&lt;')
13286:                 .replace(/>/g, '&gt;')
13287:                 .replace(/"/g, '&quot;')
13288:                 .replace(/'/g, '&#39;');
13289:         }
13290: 
13291:         function fmtIC(v) {
13292:             return Number(v || 0).toLocaleString('ar-EG');
13293:         }
13294: 
13295:         async function callIC(operation, payload) {
13296:             var res = await supabase.rpc('inventory_control', {
13297:                 p_operation: operation,
13298:                 p_payload: payload || {}
13299:             });
13300:             if (res.error) throw res.error;
13301:             var data = res.data;
13302:             if (data && data.success === false) {
13303:                 throw new Error(data.msg || 'فشل تنفيذ العملية');
13304:             }
13305:             return data || { success: true };
13306:         }
13307: 
13308:         function branchOptions(selected) {
13309:             var h = '<option value="">كل المخازن والفروع</option>';
13310:             for (var i = 0; i < state.branches.length; i++) {
13311:                 var b = state.branches[i];
13312:                 h += '<option value="' + escIC(b.id) + '"' +
13313:                     (String(selected || '') === String(b.id) ? ' selected' : '') + '>' +
13314:                     escIC(b.name || b.branch_code) + '</option>';
13315:             }
13316:             return h;
13317:         }
13318: 
13319:         function renderShell() {
13320:             safeText(byId('rw-header-title'), 'مركز التحكم في المخزون');
13321:             safeHTML(c,
13322:                 '<div class="p-4 space-y-4">' +
13323:                 '<div class="bg-white rounded-2xl shadow-sm border p-4">' +
13324:                     '<div class="flex flex-wrap items-center justify-between gap-3 mb-4">' +
13325:                         '<div>' +
13326:                             '<div class="text-xl font-black text-slate-800">مركز التحكم في المخزون</div>' +
13327:                             '<div class="text-sm text-slate-500 mt-1">لوحة رقابة مركزية فوق رصيد المخزون والحركة والاحتياجات والجرد وطلبات المخزون</div>' +
13328:                         '</div>' +
13329:                         '<div class="flex gap-2">' +
13330:                             '<button id="ic-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث البيانات</button>' +
13331:                             '<button id="ic-new-count" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">جلسة جرد جديدة</button>' +
13332:                         '</div>' +
13333:                     '</div>' +
13334:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13335:                         '<div class="rounded-2xl bg-blue-50 border border-blue-100 p-4"><div class="text-xs text-blue-700 font-bold">بنود المخزون المعروضة</div><div id="ic-kpi-lines" class="text-2xl font-black text-blue-900 mt-1">0</div></div>' +
13336:                         '<div class="rounded-2xl bg-amber-50 border border-amber-100 p-4"><div class="text-xs text-amber-700 font-bold">بنود منخفضة</div><div id="ic-kpi-low" class="text-2xl font-black text-amber-900 mt-1">0</div></div>' +
13337:                         '<div class="rounded-2xl bg-emerald-50 border border-emerald-100 p-4"><div class="text-xs text-emerald-700 font-bold">بنود تحتاج إعادة طلب</div><div id="ic-kpi-repl" class="text-2xl font-black text-emerald-900 mt-1">0</div></div>' +
13338:                         '<div class="rounded-2xl bg-purple-50 border border-purple-100 p-4"><div class="text-xs text-purple-700 font-bold">جلسات الجرد النشطة</div><div id="ic-kpi-counts" class="text-2xl font-black text-purple-900 mt-1">0</div></div>' +
13339:                     '</div>' +
13340:                 '</div>' +
13341:                 '<div class="bg-white rounded-2xl shadow-sm border p-3">' +
13342:                     '<div class="flex flex-wrap gap-2">' +
13343:                         '<button data-ic-tab="snapshot" class="ic-tab px-4 py-2 rounded-xl font-bold bg-blue-600 text-white">الرصيد</button>' +
13344:                         '<button data-ic-tab="movements" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الحركات</button>' +
13345:                         '<button data-ic-tab="replenishment" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">إعادة الطلب</button>' +
13346:                         '<button data-ic-tab="counts" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الجرد</button>' +
13347:                         '<button data-ic-tab="requests" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">طلبات المخزون</button>' +
13348:                     '</div>' +
13349:                 '</div>' +
13350:                 '<div id="ic-filters" class="bg-white rounded-2xl shadow-sm border p-4"></div>' +
13351:                 '<div id="ic-content" class="bg-white rounded-2xl shadow-sm border overflow-auto"></div>' +
13352:                 '</div>'
13353:             );
13354: 
--- WINDOW 14305-14435 around 14335 ---
14305: 
14306:         var branchRes = await supabase.from('branches')
14307:             .select('id,branch_code,name')
14308:             .eq('company_id', companyId)
14309:             .eq('is_active', true)
14310:             .order('name');
14311:         if (branchRes.error) {
14312:             showToast(branchRes.error.message, 'error');
14313:             return;
14314:         }
14315:         state.branches = branchRes.data || [];
14316: 
14317:         renderShell();
14318:         renderTabButtons();
14319:         renderFilters();
14320:         await refreshAll();
14321: 
14322:         try {
14323:             if (window._rwInventoryControlChannel) {
14324:                 await supabase.removeChannel(window._rwInventoryControlChannel);
14325:             }
14326:             var channel = supabase.channel('rw-inventory-control-' + companyId);
14327:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
14328:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
14329:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
14330:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
14331:             window._rwInventoryControlChannel = channel.subscribe();
14332:         } catch (e) {}
14333:     }
14334:     return {
14335: 			loadInventoryControl: loadInventoryControl,
14336:             loadReceiving: loadReceiving,
14337:     _applyReceiving: _applyReceiving,
14338:     _showReceivingDetails: _showReceivingDetails,
14339:     loadVouchers: loadVouchers,
14340:     _applyVouchers: _applyVouchers,
14341:     _viewVoucherDetails: _viewVoucherDetails,
14342:     _sendVoucher: _sendVoucher,
14343:     _receiveVoucher: _receiveVoucher,
14344:     _openNewVoucherModal: _openNewVoucherModal,
14345:     loadVoucherForm: loadVoucherForm,
14346:     _searchVoucherItem: _searchVoucherItem,
14347:     _addVoucherItem: _addVoucherItem,
14348:     _renderVoucherCart: _renderVoucherCart,
14349:     _updateVoucherQty: _updateVoucherQty,
14350:     _updateVoucherPrice: _updateVoucherPrice,
14351:     _removeVoucherItem: _removeVoucherItem,
14352:     _clearVoucherCart: _clearVoucherCart,
14353:     _saveAndSendVoucher: _saveAndSendVoucher,
14354:     loadPicking: loadPicking,
14355:     _applyPicking: _applyPicking,
14356:     _showPickingDetails: _showPickingDetails,
14357:     loadLoading: loadLoading,
14358:     _applyLoading: _applyLoading,
14359:     _showLoadingDetails: _showLoadingDetails,
14360:     loadDelivery: loadDelivery,
14361:     _applyDelivery: _applyDelivery,
14362:     _showDeliveryDetails: _showDeliveryDetails,
14363:     loadReturn: loadReturn,
14364:     _applyReturn: _applyReturn,
14365:     _showReturnDetails: _showReturnDetails,
14366:     loadUnloading: loadUnloading,
14367:     _applyUnloading: _applyUnloading,
14368:     _showUnloadingDetails: _showUnloadingDetails,
14369:     loadVehicleCount: loadVehicleCount,
14370:     loadBranchCount: loadBranchCount,
14371:     loadGeneralCount: loadGeneralCount,
14372:     loadSettlement: loadSettlement,
14373:     _searchDriver: _searchDriver,
14374:     _selectDriver: _selectDriver,
14375:     _startBarcodeScanner: _startBarcodeScanner,
14376:     _searchInvItem: _searchInvItem,
14377:     _addToInvCart: _addToInvCart,
14378:     _renderInvCart: _renderInvCart,
14379:     _updateInvCartQty: _updateInvCartQty,
14380:     _removeInvCartItem: _removeInvCartItem,
14381:     _saveVehicleCount: _saveVehicleCount,
14382:     _saveBranchCount: _saveBranchCount,
14383:     _saveGeneralCount: _saveGeneralCount,
14384:     _saveInvCount: _saveInvCount,
14385:     _onSettlementRsChange: _onSettlementRsChange,
14386:     _saveSettlement: _saveSettlement,
14387:     _openPickingModal: _openPickingModal,
14388:     _openLoadingModal: _openLoadingModal,
14389:     _openDeliveryModal: _openDeliveryModal,
14390:     _openReturnModal: _openReturnModal,
14391:     _startPicking: _changeStatus,
14392:     _startLoading: _changeStatus,
14393:     _startDelivery: _changeStatus,
14394:     _startReturn: _changeStatus,
14395:     _confirmUnload: _confirmUnload,
14396:     _changeStatus: _changeStatus
14397:     };
14398: })();
14399: window.RW_Warehouse = RW_Warehouse;
14400: // ============================================================
14401: // RW_Finance – الحسابات والمالية (وحدة كاملة - Supabase مباشر)
14402: // ============================================================
14403: var RW_Finance = (function() {
14404:     function _showLoader(m) { try { if (typeof showLoader === 'function') showLoader(m || 'جاري التحميل...'); } catch(e) { console.error(e); } }
14405:     function _hideLoader() { try { if (typeof hideLoader === 'function') hideLoader(); } catch(e) { console.error(e); } }
14406:     function _showToast(m, t) { try { if (typeof showToast === 'function') showToast(m, t || 'success'); } catch(e) { alert(m); } }
14407:     function _fmtNum(n) { return parseFloat(n || 0).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
14408:     function _esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
14409: 
14410:     function _companyId() {
14411:         var id = null;
14412:         if (typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.app) {
14413:             id = RW_STATE.app.companyId || null;
14414:         }
14415:         if (!id && typeof RW_STATE !== 'undefined' && RW_STATE && RW_STATE.user) {
14416:             id = RW_STATE.user.companyId || null;
14417:         }
14418:         if (!id) throw new Error('سياق الشركة غير محدد');
14419:         return id;
14420:     }
14421:     var _cache = { loaded: false, accountsTree: [], accountsFlat: [], treasury: [] };
14422: 
14423:     function _loadAllData(callback) {
14424:         if (_cache.loaded) { if (callback) callback(); return; }
14425:         var companyId;
14426:         try {
14427:             companyId = _companyId();
14428:         } catch (e) {
14429:             _showToast(e.message || 'سياق الشركة غير محدد', 'error');
14430:             if (callback) callback();
14431:             return;
14432:         }
14433: 
14434:         _showLoader('جاري تحميل البيانات المالية...');
14435:         Promise.all([
--- WINDOW 22148-22278 around 22178 ---
22148:             'receiving':'الاستلام',
22149:             'picking':'التحضير',
22150:             'loading':'التحميل',
22151:             'delivery':'التوصيل',
22152:             'return':'المرتجعات',
22153: 			'sales-returns':'إدارة مرتجعات المبيعات',
22154:             'unloading':'التفريغ',
22155:             'vouchers':'الأذونات المخزنية',
22156:             'transfer':'تحويل مخزني',
22157:             'direct-sale':'صرف سيارة بيع مباشر',
22158:             'direct-return':'استلام مرتجع سيارة',
22159:             'supplier-return':'مرتجع لمورد',
22160:             'vehicle-count':'جرد سيارة',
22161:             'branch-count':'جرد فرع',
22162:             'general-count':'جرد عام',
22163:             'finance':'الإدارة المالية',
22164:             'reports-dashboard':'لوحة القيادة',
22165:             'reports-detailed':'التقارير التفصيلية',
22166:             'reports-comprehensive':'التقارير الشاملة',
22167:             'audit-log':'سجل التدقيق',
22168:             'hr':'الموارد البشرية',
22169:             'crm':'إدارة علاقات العملاء'
22170:         };
22171:         safeText(byId('rw-header-title'), titles[view] || view);
22172: 
22173:         if (view === 'dashboard') { RW_Dashboard.render(); return; }
22174:         if (view === 'items') { RW_Items.render(); return; }
22175:         if (view === 'customers') { RW_Customers.render(); return; }
22176:         if (view === 'suppliers') { RW_Suppliers.render(); return; }
22177:         if (view === 'branches') { RW_Branches.render(); return; }
22178: 		if (view === 'inventory-control') { RW_Warehouse.loadInventoryControl(); return; }
22179:         if (view === 'settings') { RW_Settings.render(); return; }
22180:         if (view === 'hr') { RW_HR.render(); return; }
22181:         if (view === 'crm') { RW_CRM.render(); return; }
22182:         if (view === 'users') { RW_Users.render(); return; }
22183:         if (view === 'roles') { RW_Roles.render(); return; }
22184:         if (view === 'license') { RW_OwnerLicense.render(); return; }
22185:         if (view === 'telesales') { RW_TeleSales.render(); return; }
22186:         if (view === 'pos') { RW_POS.render(); return; }
22187:         if (view === 'orders') { RW_Orders.render(); return; }
22188: 		if (view === 'quotes') { RW_SalesQuotes.render(); return; }
22189: 		if (view === 'price-lists') { RW_PriceLists.render(); return; }
22190: 		if (view === 'promotions') { RW_Promotions.render(); return; }
22191:         if (view === 'runsheets') { RW_Runsheets.render(); return; }
22192:         if (view === 'online-store') { RW_OnlineStore.render(); return; }
22193:         if (view === 'purchases') { RW_Purchases.renderOrders(); return; }
22194:         if (view === 'purchase-pos') { RW_Purchases.renderPOS(); return; }
22195:         if (view === 'picking') { RW_Warehouse.loadPicking(); return; }
22196:         if (view === 'loading') { RW_Warehouse.loadLoading(); return; }
22197:         if (view === 'delivery') { RW_Warehouse.loadDelivery(); return; }
22198:         if (view === 'return') { RW_Warehouse.loadReturn(); return; }
22199: 		if (view === 'sales-returns') { RW_SalesReturnsManagement.render(); return; }
22200: 		if (view === 'loyalty') { RW_LoyaltyMain.render(); return; }
22201: 		if (view === 'sales-decision-center') { RW_SalesDecisionCenter.render(); return; }
22202: 		if (view === 'sales-targets') { RW_SalesTargetsMain.render(); return; }
22203:         if (view === 'unloading') { RW_Warehouse.loadUnloading(); return; }
22204:         if (view === 'receiving') { RW_Warehouse.loadReceiving(); return; }
22205:         if (view === 'vouchers') { RW_Warehouse.loadVouchers(); return; }
22206:         if (view === 'transfer') { RW_Warehouse.loadVoucherForm('Transfer'); return; }
22207:         if (view === 'direct-sale') { RW_Warehouse.loadVoucherForm('DirectSale'); return; }
22208:         if (view === 'direct-return') { RW_Warehouse.loadVoucherForm('DirectReturn'); return; }
22209:         if (view === 'supplier-return') { RW_Warehouse.loadVoucherForm('SupplierReturn'); return; }
22210:         if (view === 'vehicle-count') { RW_Warehouse.loadVehicleCount(); return; }
22211:         if (view === 'branch-count') { RW_Warehouse.loadBranchCount(); return; }
22212:         if (view === 'general-count') { RW_Warehouse.loadGeneralCount(); return; }
22213:         if (view === 'settlement') { RW_Warehouse.loadSettlement(); return; }
22214:         if (view === 'finance') { RW_Finance.render(); return; }
22215:         if (view === 'reports-dashboard') { RW_Reports.renderDashboard(); return; }
22216:         if (view === 'reports-detailed') { RW_Reports.renderDetailedReports(); return; }
22217:         if (view === 'reports-comprehensive') { RW_Reports_Comprehensive.render(); return; }
22218:         if (view === 'audit-log') { RW_Audit_renderTab(); return; }
22219: 
22220:         safeHTML(c, '<div class="rw-card" style="text-align:center;padding:60px 20px"><div style="font-size:64px;margin-bottom:20px">⚠️</div><h2>' + (titles[view] || view) + '</h2><p style="color:#6b7280">التبويب غير معروف</p></div>');
22221:     }
22222: };
22223: window.RW_Views = RW_Views;
22224: // ============================================================
22225: // RW_HR – الموارد البشرية (HR) - الوحدة المتقدمة
22226: // ============================================================
22227: var RW_HR = (function() {
22228:     'use strict';
22229: 
22230:     var hrData = [];
22231: 
22232:     function _esc(s) {
22233:         return String(s == null ? '' : s)
22234:             .replace(/&/g, '&amp;')
22235:             .replace(/</g, '&lt;')
22236:             .replace(/>/g, '&gt;');
22237:     }
22238: 
22239:     function _escAttr(s) {
22240:         return _esc(s)
22241:             .replace(/\"/g, '&quot;')
22242:             .replace(/'/g, '&#39;');
22243:     }
22244: 
22245:     function _fmtNum(n) {
22246:         return Number(n || 0).toLocaleString('ar-EG');
22247:     }
22248: 
22249:     function _companyId() {
22250:         if (typeof _rwCompanyId === 'function') return _rwCompanyId();
22251:         if (typeof RW_STATE !== 'undefined' && RW_STATE) {
22252:             if (RW_STATE.app && RW_STATE.app.companyId) return RW_STATE.app.companyId;
22253:             if (RW_STATE.app && RW_STATE.app.company && RW_STATE.app.company.id) return RW_STATE.app.company.id;
22254:             if (RW_STATE.user && RW_STATE.user.companyId) return RW_STATE.user.companyId;
22255:         }
22256:         return null;
22257:     }
22258: 
22259:     async function _loadEmployees() {
22260:         var res = await supabase.rpc('hr_list_employees');
22261:         if (res.error) throw res.error;
22262:         hrData = res.data || [];
22263:         return hrData;
22264:     }
22265: 
22266:     function _employeeCard(emp) {
22267:         var profileSalary = Number(emp.basic_salary || 0) +
22268:             Number(emp.housing_allowance || 0) +
22269:             Number(emp.transport_allowance || 0) +
22270:             Number(emp.other_allowance || 0) -
22271:             Number(emp.default_deduction || 0);
22272:         return '<div class="bg-white rounded-2xl shadow-sm border p-5 hover:shadow-md transition cursor-pointer" data-hr-employee-id="' + _escAttr(emp.id) + '">' +
22273:             '<div class="flex items-center gap-4 mb-4">' +
22274:                 '<div class="w-14 h-14 rounded-2xl bg-indigo-500 flex items-center justify-center text-white text-xl font-black">' + _esc((emp.name || '?').charAt(0)) + '</div>' +
22275:                 '<div class="min-w-0"><h3 class="font-black text-base text-gray-800 truncate">' + _esc(emp.name) + '</h3><p class="text-xs text-gray-500 truncate">' + _esc(emp.job_title || emp.role || 'موظف') + '</p></div>' +
22276:             '</div>' +
22277:             '<div class="space-y-2 text-sm">' +
22278:                 '<div class="flex justify-between"><span class="text-gray-500">البريد</span><span class="font-bold text-gray-700">' + _esc(emp.email) + '</span></div>' +
--- WINDOW 8961-9091 around 8991 ---
8961:       var poRes = await supabase.from('purchase_orders').select('*').eq('company_id', companyId).eq('po_code', poCode).maybeSingle();
8962:       if (poRes.error || !poRes.data) throw new Error('أمر الشراء غير موجود');
8963:       var dRes = await supabase.from('purchase_order_details').select('*').eq('po_id', poRes.data.id).order('created_at', { ascending: true });
8964:       if (dRes.error) throw dRes.error;
8965:       var rows = dRes.data || [], h = '<div class="text-right"><div class="grid grid-cols-2 gap-3 mb-4"><div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-gray-500">المورد</div><div class="font-bold">' + esc(poRes.data.supplier_name) + '</div></div><div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-gray-500">الحالة</div><div class="font-bold">' + esc(poRes.data.status) + '</div></div></div><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">المطلوب</th><th class="p-2 text-center">المستلم</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">السعر</th></tr></thead><tbody>';
8966:       for (var i = 0; i < rows.length; i++) { var r = rows[i], ordered = Number(r.qty_ordered) || 0, received = Number(r.qty_received) || 0; h += '<tr class="border-b"><td class="p-2 font-semibold">' + esc(r.item_name || r.item_code) + '</td><td class="p-2 text-center">' + ordered + '</td><td class="p-2 text-center">' + received + '</td><td class="p-2 text-center font-bold">' + Math.max(0, ordered - received) + '</td><td class="p-2 text-center">' + (Number(r.unit_price) || 0).toLocaleString() + '</td></tr>'; }
8967:       h += '</tbody></table><div class="mt-4 font-black text-lg">الإجمالي: ' + (Number(poRes.data.total_amount) || 0).toLocaleString() + ' EGP</div></div>';
8968:       hideLoader(); Swal.fire({ title: 'تفاصيل ' + esc(poCode), html: h, width: '820px', showConfirmButton: false, showCloseButton: true });
8969:     } catch (e) { hideLoader(); showToast(e.message || 'فشل تحميل التفاصيل', 'error'); }
8970:   }
8971: 
8972:   async function openReceive(poCode) {
8973:     showLoader('جاري جلب تفاصيل الاستلام...');
8974:     try {
8975:       var companyId = companyIdOrFail();
8976:       var poRes = await supabase.from('purchase_orders').select('*').eq('company_id', companyId).eq('po_code', poCode).maybeSingle();
8977:       if (poRes.error || !poRes.data) throw new Error('أمر الشراء غير موجود');
8978:       var itemsRes = await supabase.from('purchase_order_details').select('*').eq('po_id', poRes.data.id).order('created_at', { ascending: true });
8979:       if (itemsRes.error) throw itemsRes.error;
8980:       hideLoader();
8981:       var items = itemsRes.data || [], html = '<div class="text-right"><div class="mb-3 text-sm text-gray-500">يمكن استلام الكمية المتبقية فقط. إعادة المحاولة تستخدم نفس هوية العملية إذا بقيت النافذة مفتوحة.</div><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">المطلوب</th><th class="p-2 text-center">المستلم</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">الاستلام الآن</th><th class="p-2">سبب/ملاحظة</th></tr></thead><tbody>';
8982:       for (var i = 0; i < items.length; i++) { var it = items[i], ordered = Number(it.qty_ordered) || 0, received = Number(it.qty_received) || 0, remaining = Math.max(0, ordered - received); html += '<tr class="border-b"><td class="p-2 font-semibold">' + esc(it.item_name || it.item_code) + '<div class="text-xs text-gray-400">' + esc(it.item_code) + '</div></td><td class="p-2 text-center">' + ordered + '</td><td class="p-2 text-center">' + received + '</td><td class="p-2 text-center font-bold">' + remaining + '</td><td class="p-2 text-center"><input type="number" id="rec-qty-' + i + '" value="' + remaining + '" max="' + remaining + '" min="0" step="0.01" class="w-24 p-1 border rounded text-center"></td><td class="p-2"><input type="text" id="rec-note-' + i + '" class="w-36 p-1 border rounded" placeholder="اختياري"></td></tr>'; }
8983:       html += '</tbody></table></div>';
8984:       Swal.fire({ title: 'استلام بضاعة: ' + esc(poCode), html: html, width: '1000px', showCancelButton: true, confirmButtonText: 'اعتماد الاستلام', confirmButtonColor: '#10b981', cancelButtonText: 'إلغاء', preConfirm: function() { var received = [], hasQty = false; for (var i = 0; i < items.length; i++) { var q = Number(document.getElementById('rec-qty-' + i).value) || 0, remaining = Math.max(0, (Number(items[i].qty_ordered) || 0) - (Number(items[i].qty_received) || 0)); if (q < 0 || q > remaining) { Swal.showValidationMessage('الكمية غير صالحة للصنف: ' + (items[i].item_code || '')); return false; } if (q > 0) { hasQty = true; received.push({ itemCode: items[i].item_code, itemName: items[i].item_name, unit: items[i].unit, receivedQty: q, reason: (document.getElementById('rec-note-' + i).value || '').trim() }); } } if (!hasQty) { Swal.showValidationMessage('أدخل كمية استلام واحدة على الأقل'); return false; } return received; } }).then(async function(r) {
8985:         if (!r.isConfirmed || !r.value || !r.value.length) return;
8986:         showLoader('جاري حفظ الاستلام...');
8987:         try {
8988:           var ses = await supabase.auth.getSession(), token = ses && ses.data && ses.data.session ? ses.data.session.access_token : null;
8989:           if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
8990:           var receiveOperationId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now()) + '-' + Math.random();
8991:           var res = await fetch(SUPABASE_URL + '/functions/v1/receive-purchase', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Idempotency-Key': receiveOperationId }, body: JSON.stringify({ po_code: poCode, itemsReceived: r.value, operation_id: receiveOperationId }) });
8992:           var json = await res.json();
8993:           if (!res.ok || !json || !json.success) throw new Error((json && json.msg) || 'فشل الاستلام');
8994:           hideLoader(); showToast(json.duplicate ? 'تم استرجاع نتيجة الاستلام السابق' : 'تم الاستلام بنجاح', 'success'); await renderOrders();
8995:         } catch (e) { hideLoader(); showToast(e.message || 'فشل الاتصال', 'error'); }
8996:       });
8997:     } catch (e) { hideLoader(); showToast(e.message || 'فشل تحميل الاستلام', 'error'); }
8998:   }
8999: 
9000:   async function renderPOS() {
9001:     var c = byId('rw-page-container'); if (!c) return;
9002:     safeText(byId('rw-header-title'), 'نقطة شراء');
9003:     if (!RW_STATE.data.items || !RW_STATE.data.items.length) { showLoader('جاري تحميل الأصناف...'); try { await RW_Data.loadItems(); } finally { hideLoader(); } }
9004:     if (!RW_STATE.data.suppliers || !RW_STATE.data.suppliers.length) {
9005:       var companyId = companyIdOrFail(), sRes = await supabase.from('suppliers').select('*').eq('company_id', companyId).eq('is_active', true).order('name', { ascending: true });
9006:       if (sRes.error) { showToast('تعذر تحميل الموردين', 'error'); RW_STATE.data.suppliers = []; } else RW_STATE.data.suppliers = sRes.data || [];
9007:     }
9008:     safeHTML(c, '<div class="grid grid-cols-1 lg:grid-cols-4 gap-6 p-4"><div class="lg:col-span-1 space-y-4"><div class="bg-white p-4 rounded-xl shadow-sm"><label class="text-sm font-bold">اختيار المورد</label><select id="po-supplier" class="w-full p-2.5 bg-gray-50 border rounded-lg"></select></div><div class="bg-white p-4 rounded-xl shadow-sm"><label class="text-sm font-bold">البحث عن صنف بالاسم أو الكود أو الباركود</label><input type="text" id="po-search" oninput="RW_Purchases._searchItem(this.value)" placeholder="ابحث..." class="w-full p-2.5 bg-gray-50 border rounded-lg"><div id="po-dropdown" class="absolute z-50 bg-white shadow-xl rounded-xl max-h-72 overflow-y-auto hidden border"></div></div></div><div class="lg:col-span-3 bg-white rounded-xl shadow-md overflow-hidden flex flex-col min-h-[520px]"><div class="bg-emerald-700 text-white p-4 flex justify-between"><h2 class="font-bold text-lg">أمر شراء جديد</h2><span id="po-count">0</span></div><div class="flex-1 overflow-y-auto p-4"><table class="w-full text-right"><thead><tr class="text-xs text-gray-500"><th class="p-2">الصنف</th><th class="p-2 text-center">سعر الشراء</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">الإجمالي</th><th></th></tr></thead><tbody id="po-cart-body"><tr><td colspan="5" class="p-8 text-center">لا توجد أصناف</td></tr></tbody></table></div><div class="p-4 bg-gray-50 border-t flex justify-between"><div><span class="text-gray-500">الإجمالي:</span><span id="po-total" class="text-3xl font-bold">0</span></div><div class="flex gap-2"><button onclick="RW_Purchases._clearCart()" class="px-4 py-2 bg-red-500 text-white rounded-lg">مسح</button><button onclick="RW_Purchases._savePO()" class="px-6 py-2 bg-emerald-600 text-white rounded-lg">حفظ أمر الشراء</button></div></div></div></div>');
9009:     loadSuppliers(); renderPOCart();
9010:   }
9011: 
9012:   function loadSuppliers() {
9013:     var sel = byId('po-supplier'); if (!sel) return;
9014:     var suppliers = RW_STATE.data.suppliers || [], h = '<option value="">-- اختر مورداً --</option>';
9015:     for (var i = 0; i < suppliers.length; i++) h += '<option value="' + esc(suppliers[i].id) + '">' + esc(suppliers[i].name || suppliers[i].supplier_code || '') + '</option>';
9016:     safeHTML(sel, h);
9017:   }
9018: 
9019:   function searchItem(q) {
9020:     var dd = byId('po-dropdown'); if (!dd) return; var query = (q || '').trim().toLowerCase(); if (!query) { dd.classList.add('hidden'); return; }
9021:     var items = RW_STATE.data.items || [], f = items.filter(function(i) { return (((i.name || '') + ' ' + (i.item_code || '') + ' ' + (i.barcode || '')).toLowerCase().indexOf(query) !== -1); }).slice(0, 25);
9022:     if (!f.length) { safeHTML(dd, '<div class="p-3 text-center text-gray-500">لا توجد نتائج</div>'); dd.classList.remove('hidden'); return; }
9023:     var h = '';
9024:     for (var i = 0; i < f.length; i++) { var item = f[i]; h += '<div onclick="RW_Purchases._addToCart(\'' + escJs(item.item_code) + '\')" class="p-3 hover:bg-emerald-50 cursor-pointer flex justify-between border-b"><div><div class="font-bold">' + esc(item.name || item.item_code) + '</div><div class="text-xs text-gray-400">' + esc(item.item_code) + (item.barcode ? ' | ' + esc(item.barcode) : '') + '</div></div><div class="text-emerald-600 font-bold">' + (Number(item.cost_price) || 0).toLocaleString() + ' EGP</div></div>'; }
9025:     safeHTML(dd, h); dd.classList.remove('hidden');
9026:   }
9027: 
9028:   function addToCart(code) {
9029:     var items = RW_STATE.data.items || [], item = null;
9030:     for (var i = 0; i < items.length; i++) if (items[i].item_code === code) { item = items[i]; break; }
9031:     if (!item) return;
9032:     for (var j = 0; j < cart.length; j++) if (cart[j].code === code) { cart[j].qty++; renderPOCart(); return; }
9033:     cart.push({ code: item.item_code, name: item.name, price: Number(item.cost_price) || 0, unit: item.unit || 'حبة', qty: 1 });
9034:     if (byId('po-search')) byId('po-search').value = '';
9035:     if (byId('po-dropdown')) byId('po-dropdown').classList.add('hidden');
9036:     renderPOCart();
9037:   }
9038: 
9039:   function updateQty(idx, v) { var q = Number(v); if (!Number.isFinite(q) || q <= 0) cart.splice(idx, 1); else cart[idx].qty = q; renderPOCart(); }
9040:   function updatePrice(idx, v) { var price = Number(v); if (!Number.isFinite(price) || price < 0) return; cart[idx].price = price; renderPOCart(); }
9041:   function removeItem(idx) { cart.splice(idx, 1); renderPOCart(); }
9042:   function clearCart() { cart = []; renderPOCart(); }
9043: 
9044:   function renderPOCart() {
9045:     var tb = byId('po-cart-body'), totalEl = byId('po-total'), countEl = byId('po-count'); if (!tb) return;
9046:     if (!cart.length) { safeHTML(tb, '<tr><td colspan="5" class="p-8 text-center">لا توجد أصناف</td></tr>'); safeText(totalEl, '0'); safeText(countEl, '0'); return; }
9047:     var total = 0, h = '';
9048:     for (var i = 0; i < cart.length; i++) { var it = cart[i], line = (Number(it.price) || 0) * (Number(it.qty) || 0); total += line; h += '<tr class="border-b"><td class="p-2 font-bold">' + esc(it.name) + '<div class="text-xs text-gray-400">' + esc(it.code) + '</div></td><td class="p-2 text-center"><input type="number" min="0" step="0.01" value="' + (Number(it.price) || 0) + '" onchange="RW_Purchases._updatePrice(' + i + ',this.value)" class="w-24 p-1 border rounded text-center"></td><td class="p-2 text-center"><input type="number" min="0.01" step="0.01" value="' + (Number(it.qty) || 0) + '" onchange="RW_Purchases._updateQty(' + i + ',this.value)" class="w-20 p-1 border rounded text-center"></td><td class="p-2 text-center font-bold">' + line.toLocaleString() + '</td><td class="p-2 text-center"><button onclick="RW_Purchases._removeItem(' + i + ')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>'; }
9049:     safeHTML(tb, h); safeText(totalEl, total.toLocaleString()); safeText(countEl, String(cart.length));
9050:   }
9051: 
9052:   async function savePO() {
9053:     var supplierId = byId('po-supplier') ? byId('po-supplier').value : '';
9054:     if (!supplierId) { showToast('اختر مورداً', 'warning'); return; }
9055:     if (!cart.length) { showToast('أضف أصنافاً', 'warning'); return; }
9056:     var supplier = null, suppliers = RW_STATE.data.suppliers || [];
9057:     for (var i = 0; i < suppliers.length; i++) if (suppliers[i].id === supplierId) { supplier = suppliers[i]; break; }
9058:     if (!supplier) { showToast('المورد غير موجود', 'error'); return; }
9059:     showLoader('جاري الحفظ...');
9060:     try {
9061:       var ses = await supabase.auth.getSession(), token = ses && ses.data && ses.data.session ? ses.data.session.access_token : null;
9062:       if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
9063:       var res = await fetch(SUPABASE_URL + '/functions/v1/save-purchase-order', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token }, body: JSON.stringify({ orderHeader: { supplierId: supplier.id, supplierName: supplier.name || supplier.supplier_code || '' }, itemsList: cart }) });
9064:       var json = await res.json();
9065:       if (!res.ok || !json || !json.success) throw new Error((json && json.msg) || 'فشل حفظ أمر الشراء');
9066:       hideLoader(); showToast('تم الحفظ: ' + (json.poID || ''), 'success'); cart = []; renderPOCart();
9067:     } catch (e) { hideLoader(); showToast(e.message || 'فشل الاتصال', 'error'); }
9068:   }
9069: 
9070:   return { renderOrders: renderOrders, renderPOS: renderPOS, _filterOrders: filterOrders, _openPO: openPO, _openReceive: openReceive, _searchItem: searchItem, _addToCart: addToCart, _updateQty: updateQty, _updatePrice: updatePrice, _removeItem: removeItem, _clearCart: clearCart, _savePO: savePO };
9071: })();
9072: window.RW_Purchases = RW_Purchases;
9073: 	
9074: var RW_PurchaseGold = (function () {
9075:   'use strict';
9076: 
9077:   var active = 'dashboard';
9078: 
9079:   function esc(v) {
9080:     return String(v == null ? '' : v)
9081:       .replace(/&/g,'&amp;')
9082:       .replace(/</g,'&lt;')
9083:       .replace(/>/g,'&gt;')
9084:       .replace(/"/g,'&quot;')
9085:       .replace(/'/g,'&#39;');
9086:   }
9087: 
9088:   function companyId() {
9089:     var id = _rwCompanyId();
9090:     if (!id) throw new Error('سياق الشركة غير محدد');
9091:     return id;
--- RW_Warehouse_FULL 10969-14398 ---
10969: var RW_Warehouse = (function() {
10970:     function esc(s) { return String(s||'').replace(/[&<>]/g, function(m) { return m==='&'?'&amp;':m==='<'?'&lt;':'&gt;'; }); }
10971: 
10972:     // ==================== RECEIVING (سجل الاستلام) ====================
10973:     async function loadReceiving() {
10974:         var c = byId('rw-page-container');
10975:         if (!c) return;
10976: 
10977:         safeText(byId('rw-header-title'), 'الاستلام (Receiving)');
10978:         safeHTML(c, '<div class="p-4">' +
10979:             '<div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">' +
10980:                 '<input type="text" id="rec-filter-id" placeholder="رقم العملية..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10981:                 '<input type="text" id="rec-filter-po" placeholder="رقم أمر الشراء..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10982:                 '<input type="text" id="rec-filter-resp" placeholder="المسؤول..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReceiving()">' +
10983:                 '<input type="date" id="rec-filter-date-from" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyReceiving()">' +
10984:                 '<input type="date" id="rec-filter-date-to" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyReceiving()">' +
10985:                 '<button onclick="RW_Warehouse._applyReceiving()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>' +
10986:             '</div></div>' +
10987:             '<div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr>' +
10988:                 '<th class="p-3">رقم العملية</th><th class="p-3">التاريخ</th><th class="p-3">أمر الشراء</th><th class="p-3">المسؤول</th><th class="p-3">الأصناف</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th>' +
10989:             '</tr></thead><tbody id="rec-table"><tr><td colspan="7" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>' +
10990:         '</div>');
10991: 
10992:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
10993:         if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
10994: 
10995:         var res = await supabase.from('receiving')
10996:             .select('*')
10997:             .eq('company_id', companyId)
10998:             .order('date', { ascending: false });
10999:         if (res.error) { showToast(res.error.message, 'error'); return; }
11000: 
11001:         var rows = res.data || [];
11002:         var opIds = rows.map(function(r) { return r.operation_id; }).filter(Boolean);
11003:         var counts = {};
11004:         if (opIds.length) {
11005:             var detailsRes = await supabase.from('receiving_details')
11006:                 .select('operation_id')
11007:                 .in('operation_id', opIds);
11008:             if (detailsRes.error) { showToast(detailsRes.error.message, 'error'); return; }
11009:             var details = detailsRes.data || [];
11010:             for (var i = 0; i < details.length; i++) {
11011:                 counts[details[i].operation_id] = (counts[details[i].operation_id] || 0) + 1;
11012:             }
11013:         }
11014: 
11015:         window._receivingData = rows.map(function(r) {
11016:             var x = Object.assign({}, r);
11017:             x.itemsCount = counts[r.operation_id] || 0;
11018:             return x;
11019:         });
11020:         _applyReceiving();
11021:     }
11022: 
11023:     function _applyReceiving() {
11024:         var d = window._receivingData || [];
11025:         var id = (byId('rec-filter-id')?.value || '').trim().toLowerCase();
11026:         var po = (byId('rec-filter-po')?.value || '').trim().toLowerCase();
11027:         var resp = (byId('rec-filter-resp')?.value || '').trim().toLowerCase();
11028:         var fd = byId('rec-filter-date-from')?.value;
11029:         var td = byId('rec-filter-date-to')?.value;
11030: 
11031:         if (id) d = d.filter(function(r) { return String(r.operation_id || '').toLowerCase().indexOf(id) !== -1; });
11032:         if (po) d = d.filter(function(r) { return String(r.po_number || '').toLowerCase().indexOf(po) !== -1; });
11033:         if (resp) d = d.filter(function(r) { return String(r.responsible || '').toLowerCase().indexOf(resp) !== -1; });
11034:         if (fd) d = d.filter(function(r) { return r.date >= fd; });
11035:         if (td) d = d.filter(function(r) { return r.date <= td; });
11036: 
11037:         var tb = byId('rec-table');
11038:         if (!tb) return;
11039:         if (!d.length) { safeHTML(tb, '<tr><td colspan="7" class="text-center py-8">لا توجد عمليات استلام</td></tr>'); return; }
11040: 
11041:         var h = '';
11042:         d.forEach(function(op) {
11043:             var opId = String(op.operation_id || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
11044:             h += "<tr class=\"border-b hover:bg-gray-50 cursor-pointer\" onclick=\"RW_Warehouse._showReceivingDetails('" + opId + "')\">" +
11045:                 '<td class="p-3 font-bold text-blue-600">' + esc(op.operation_id || '') + '</td>' +
11046:                 '<td class="p-3">' + esc(op.date || '') + '</td>' +
11047:                 '<td class="p-3">' + esc(op.po_number || '---') + '</td>' +
11048:                 '<td class="p-3">' + esc(op.responsible || '---') + '</td>' +
11049:                 '<td class="p-3 text-center">' + Number(op.itemsCount || 0) + '</td>' +
11050:                 '<td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-green-100 text-green-700">' + esc(op.status || 'مكتمل') + '</span></td>' +
11051:                 "<td class=\"p-3 text-center\"><button class=\"text-blue-600\" onclick=\"event.stopPropagation(); RW_Warehouse._showReceivingDetails('" + opId + "')\"><i class=\"fa-solid fa-eye\"></i></button></td>" +
11052:             '</tr>';
11053:         });
11054:         safeHTML(tb, h);
11055:     }
11056: 
11057: async function _showReceivingDetails(opId) {
11058:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11059:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11060:     showLoader('جاري التحميل...');
11061:     var opRes = await supabase.from('receiving')
11062:         .select('operation_id')
11063:         .eq('company_id', companyId)
11064:         .eq('operation_id', opId)
11065:         .maybeSingle();
11066: 
11067:     if (opRes.error || !opRes.data) {
11068:         hideLoader();
11069:         showToast('عملية الاستلام غير موجودة في الشركة الحالية', 'error');
11070:         return;
11071:     }
11072: 
11073:     var detRes = await supabase.from('receiving_details')
11074:         .select('*')
11075:         .eq('operation_id', opRes.data.operation_id);
11076: 
11077:     hideLoader();
11078: 
11079:     var details = detRes.data || [];
11080:     if (!details.length) {
11081:         showToast('لا توجد تفاصيل', 'info');
11082:         return;
11083:     }
11084: 
11085:     var h = '<div class="text-right"><table class="w-full border text-sm"><thead class="bg-gray-100"><tr>' +
11086:         '<th class="p-2">الكود</th>' +
11087:         '<th class="p-2">الصنف</th>' +
11088:         '<th class="p-2 text-center">الوحدة</th>' +
11089:         '<th class="p-2 text-center">المطلوب</th>' +
11090:         '<th class="p-2 text-center">الفعلي</th>' +
11091:         '<th class="p-2 text-center">الفرق</th>' +
11092:         '<th class="p-2">السبب</th>' +
11093:         '</tr></thead><tbody>';
11094: 
11095:     details.forEach(function(d) {
11096:         h += '<tr>' +
11097:             '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
11098:             '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
11099:             '<td class="p-2 border text-center">' + esc(d.unit || '') + '</td>' +
11100:             '<td class="p-2 border text-center">' + (d.qty_expected || 0) + '</td>' +
11101:             '<td class="p-2 border text-center font-bold">' + (d.qty_received || 0) + '</td>' +
11102:             '<td class="p-2 border text-center">' + (d.difference || 0) + '</td>' +
11103:             '<td class="p-2 border">' + esc(d.reason || '') + '</td>' +
11104:             '</tr>';
11105:     });
11106: 
11107:     h += '</tbody></table></div>';
11108: 
11109:     Swal.fire({
11110:         title: 'تفاصيل الاستلام: ' + esc(opRes.data.operation_id),
11111:         html: h,
11112:         width: '800px',
11113:         showCloseButton: true,
11114:         showConfirmButton: false
11115:     });
11116: }
11117: 
11118:     // ==================== VOUCHER FORM – نماذج الأذونات الأربعة ====================
11119:     var voucherCart = [];
11120:     var currentVoucherType = '';
11121:     var currentVoucherConfig = {};
11122: 
11123:     function loadVoucherForm(type) {
11124:         voucherCart = [];
11125:         currentVoucherType = type;
11126:         var configs = {            'Transfer':      { title: 'تحويل مخزني', entityLabel: 'الفرع المحول إليه', showPrice: false, fromType: 'Branch', fromId: null, toType: 'Branch', toId: null, endpoint: 'save-voucher' },
11127:             'DirectSale':    { title: 'صرف سيارة بيع مباشر', entityLabel: 'المندوب / السيارة', showPrice: true, fromType: 'Branch', fromId: null, toType: 'Vehicle', toId: null, endpoint: 'save-voucher' },
11128:             'DirectReturn':  { title: 'استلام مرتجع سيارة', entityLabel: 'المندوب / السيارة', showPrice: true, fromType: 'Vehicle', fromId: null, toType: 'Branch', toId: null, endpoint: 'save-voucher' },
11129:             'SupplierReturn':{ title: 'مرتجع لمورد', entityLabel: 'المورد', showPrice: true, fromType: 'Branch', fromId: null, toType: 'Supplier', toId: null, endpoint: 'save-voucher' }
11130:         };
11131:         var cfg = configs[type];
11132:         if (!cfg) { showToast('نوع غير معروف', 'error'); return; }
11133:         currentVoucherConfig = cfg;
11134: 
11135:         var c = byId('rw-page-container');
11136:         if (!c) return;
11137:         safeText(byId('rw-header-title'), cfg.title);
11138:         safeHTML(c, `<div class="p-4">
11139:             <div class="bg-white rounded-2xl shadow-sm border p-4">
11140:                 <div class="flex justify-between items-center mb-4">
11141:                     <h2 class="text-xl font-bold"><i class="fa-solid fa-file-signature ml-2 text-indigo-600"></i>${cfg.title}</h2>
11142:                     <button onclick="RW_Warehouse.loadVouchers()" class="text-gray-500 hover:text-gray-700"><i class="fa-solid fa-xmark text-xl"></i></button>
11143:                 </div>
11144:                 <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
11145:     <div>
11146:         <label class="block text-sm font-bold mb-1">${cfg.entityLabel}</label>
11147:         <select id="voucherEntitySelect" class="border rounded-lg p-2 w-full"><option value="">-- اختر --</option></select>
11148:     </div>
11149:     <div>
11150:         <label class="block text-sm font-bold mb-1">مرجع الإذن</label>
11151:         <input id="voucherReference" class="border rounded-lg p-2 w-full" placeholder="مرجع الإذن...">
11152:     </div>
11153:     <div>
11154:         <label class="block text-sm font-bold mb-1">ملاحظات</label>
11155:         <textarea id="voucherNotesLarge" rows="2" class="border rounded-lg p-2 w-full" placeholder="ملاحظات..."></textarea>
11156:     </div>
11157: </div> 
11158: <label class="block text-sm font-bold mb-1">بحث عن صنف</label>
11159:                     <div class="relative">
11160:                         <input type="text" id="voucherItemSearch" oninput="RW_Warehouse._searchVoucherItem(this.value)" autocomplete="off" placeholder="ابحث بالاسم أو الباركود..." class="border rounded-lg p-2 w-full">
11161:                         <div id="voucherSearchResults" class="absolute z-50 left-0 right-0 mt-1 bg-white shadow-xl rounded-xl max-h-60 overflow-y-auto hidden border"></div>
11162:                     </div>
11163:                 </div>
11164:                 <div class="mb-4 overflow-y-auto" style="max-height:300px;" id="voucherItemsTable">
11165:                     <div class="text-center py-8 text-gray-400">أضف أصنافاً</div>
11166:                 </div>
11167:                 <div class="p-3 bg-gray-50 rounded-lg flex justify-between items-center mb-4">
11168:                     <span class="font-bold">عدد الأصناف: <span id="voucherTotalItems">0</span></span>
11169:                 </div>
11170:                 <div class="flex justify-end gap-3">
11171:                     <button onclick="RW_Warehouse._clearVoucherCart()" class="px-4 py-2 bg-gray-500 text-white rounded-lg font-bold">مسح الكل</button>
11172:                     <button onclick="RW_Warehouse._saveAndSendVoucher()" class="px-6 py-2 bg-indigo-600 text-white rounded-lg font-bold">حفظ وإرسال (Sent)</button>
11173:                 </div>
11174:             </div>
11175:         </div>`);
11176: 
11177:         _loadVoucherEntityOptions(type);
11178:         _renderVoucherCart();
11179:     }
11180: 
11181: async function _loadVoucherEntityOptions(type) {
11182:     var select = byId('voucherEntitySelect');
11183:     if (!select) return;
11184: 
11185:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11186:     if (!companyId) {
11187:         showToast('سياق الشركة غير محدد', 'error');
11188:         return;
11189:     }
11190: 
11191:     if (type === 'Transfer') {
11192:         var branchRes = await supabase.from('branches')
11193:             .select('id, branch_code, name')
11194:             .eq('company_id', companyId)
11195:             .eq('is_active', true)
11196:             .order('name');
11197:         if (branchRes.error) { showToast(branchRes.error.message, 'error'); return; }
11198: 
11199:         var branchHtml = '<option value="">-- اختر فرعاً --</option>';
11200:         var branches = branchRes.data || [];
11201:         for (var i = 0; i < branches.length; i++) {
11202:             branchHtml += '<option value="' + branches[i].id + '">' +
11203:                 (branches[i].name || branches[i].branch_code || '') +
11204:                 '</option>';
11205:         }
11206:         safeHTML(select, branchHtml);
11207:         return;
11208:     }
11209: 
11210: 	if (type === 'SupplierReturn') {
11211:         var supplierRes = await supabase.from('suppliers')
11212:             .select('id, supplier_code, name')
11213:             .eq('company_id', companyId)
11214:             .eq('is_active', true)
11215:             .order('name');
11216:         if (supplierRes.error) { showToast(supplierRes.error.message, 'error'); return; }
11217: 
11218:         var supplierHtml = '<option value="">-- اختر مورداً --</option>';
11219:         var suppliers = supplierRes.data || [];
11220:         for (var s = 0; s < suppliers.length; s++) {
11221:             supplierHtml += '<option value="' + suppliers[s].id + '">' + (suppliers[s].name || suppliers[s].supplier_code || '') + '</option>';
11222:         }
11223:         safeHTML(select, supplierHtml);
11224:         return;
11225:     }
11226: 
11227:     var driverRoles = type === 'DirectSale'
11228:         ? ['مندوب بيع مباشر']
11229:         : ['driver', 'سائق', 'مندوب', 'مندوب بيع مباشر'];
11230: 
11231:     var usersRes = await supabase.from('users')
11232:         .select('id, email, name, role')
11233:         .eq('company_id', companyId)
11234:         .in('role', driverRoles)
11235:         .eq('status', 'Active');
11236:     if (usersRes.error) { showToast(usersRes.error.message, 'error'); return; }
11237: 
11238:     var drivers = usersRes.data || [];
11239:     var driverIds = drivers.map(function(d) { return d.id; });
11240:     if (!driverIds.length) {
11241:         safeHTML(select, '<option value="">-- لا توجد سيارات متاحة --</option>');
11242:         return;
11243:     }
11244: 
11245:     var vehicleRes = await supabase.from('vehicles')
11246:         .select('id, vehicle_code, license_plate, driver_id')
11247:         .eq('company_id', companyId)
11248:         .eq('status', 'Active')
11249:         .in('driver_id', driverIds)
11250:         .order('vehicle_code');
11251:     if (vehicleRes.error) { showToast(vehicleRes.error.message, 'error'); return; }
11252: 
11253:     var driverMap = {};
11254:     for (var d = 0; d < drivers.length; d++) driverMap[drivers[d].id] = drivers[d];
11255: 
11256:     var vehicleHtml = '<option value="">-- اختر سيارة --</option>';
11257:     var vehicles = vehicleRes.data || [];
11258:     for (var v = 0; v < vehicles.length; v++) {
11259:         var vehicle = vehicles[v];
11260:         var driver = driverMap[vehicle.driver_id] || {};
11261:         var label = (driver.name || driver.email || '') + ' — ' + (vehicle.vehicle_code || vehicle.license_plate || vehicle.id);
11262:         vehicleHtml += '<option value="' + vehicle.id + '">' + label + '</option>';
11263:     }
11264:     safeHTML(select, vehicleHtml);
11265: }
11266: 
11267:     function _searchVoucherItem(query) {
11268:         var div = byId('voucherSearchResults');
11269:         if (!div) return;
11270:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
11271:         var items = RW_STATE.data.items || [];
11272:         var q = query.toLowerCase();
11273:         var filtered = items.filter(function(i) { return (i.name || '').toLowerCase().indexOf(q) !== -1 || (i.item_code || '').toLowerCase().indexOf(q) !== -1; });
11274:         if (filtered.length > 0) {
11275:             var html = '';
11276:             for (var idx = 0; idx < Math.min(filtered.length, 20); idx++) {
11277:                 var item = filtered[idx];
11278:                 html += '<div onclick="RW_Warehouse._addVoucherItem(\'' + item.item_code + '\')" class="p-3 hover:bg-indigo-50 cursor-pointer flex justify-between border-b"><div><div class="font-bold">' + item.name + '</div><div class="text-xs text-gray-400">' + item.item_code + '</div></div><div class="font-bold text-indigo-600">' + (item.qty || 0) + ' ' + (item.unit || '') + '</div></div>';
11279:             }
11280:             safeHTML(div, html); div.classList.remove('hidden');
11281:         } else { div.classList.add('hidden'); }
11282:     }
11283: 
11284:     function _addVoucherItem(itemCode) {
11285:         var items = RW_STATE.data.items || [];
11286:         var item = null;
11287:         for (var i = 0; i < items.length; i++) { if (items[i].item_code === itemCode) { item = items[i]; break; } }
11288:         if (!item) return;
11289:         var existing = null;
11290:         for (var j = 0; j < voucherCart.length; j++) { if (voucherCart[j].code === itemCode) { existing = voucherCart[j]; break; } }
11291:         if (existing) { existing.qty++; } else {
11292:             voucherCart.push({ code: item.item_code, name: item.name, unit: item.unit || 'حبة', qty: 1, price: currentVoucherConfig.showPrice ? (Number(item.sales_price) || 0) : 0 });
11293:         }
11294:         byId('voucherItemSearch').value = '';
11295:         byId('voucherSearchResults').classList.add('hidden');
11296:         _renderVoucherCart();
11297:     }
11298: 
11299:     function _renderVoucherCart() {
11300:         var tbody = byId('voucherItemsTable');
11301:         var countSpan = byId('voucherTotalItems');
11302:         if (voucherCart.length === 0) { safeHTML(tbody, '<div class="text-center py-8 text-gray-400">أضف أصنافاً</div>'); if (countSpan) countSpan.innerText = '0'; return; }
11303:         var html = '<table class="w-full text-right border"><thead class="bg-gray-100 text-xs uppercase"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية</th>';
11304:         if (currentVoucherConfig.showPrice) html += '<th class="p-2 text-center">السعر</th>';
11305:         html += '<th class="p-2 text-center">حذف</th></tr></thead><tbody>';
11306:         for (var i = 0; i < voucherCart.length; i++) {
11307:             var item = voucherCart[i];
11308:             html += '<tr class="border-b"><td class="p-2"><div class="font-bold">' + item.name + '</div><div class="text-xs text-gray-400">' + item.code + '</div></td><td class="p-2 text-center"><input type="number" value="' + item.qty + '" onchange="RW_Warehouse._updateVoucherQty(' + i + ', this.value)" class="w-16 p-1 border rounded text-center" min="1"></td>';
11309:             if (currentVoucherConfig.showPrice) html += '<td class="p-2 text-center"><input type="number" value="' + item.price + '" onchange="RW_Warehouse._updateVoucherPrice(' + i + ', this.value)" class="w-20 p-1 border rounded text-center" step="0.01" min="0"></td>';
11310:             html += '<td class="p-2 text-center"><button onclick="RW_Warehouse._removeVoucherItem(' + i + ')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>';
11311:         }
11312:         html += '</tbody></table>';
11313:         safeHTML(tbody, html);
11314:         if (countSpan) countSpan.innerText = String(voucherCart.length);
11315:     }
11316: 
11317:     function _updateVoucherQty(idx, val) { var q = parseInt(val); if (q > 0) voucherCart[idx].qty = q; else voucherCart.splice(idx, 1); _renderVoucherCart(); }
11318:     function _updateVoucherPrice(idx, val) { voucherCart[idx].price = parseFloat(val) || 0; _renderVoucherCart(); }
11319:     function _removeVoucherItem(idx) { voucherCart.splice(idx, 1); _renderVoucherCart(); }
11320:     function _clearVoucherCart() { voucherCart = []; _renderVoucherCart(); }
11321: 
11322: async function _saveAndSendVoucher() {
11323:     if (voucherCart.length === 0) { showToast('أضف أصنافاً للإذن', 'warning'); return; }
11324: 
11325:     var entity = byId('voucherEntitySelect') ? byId('voucherEntitySelect').value : '';
11326:     if (!entity) { showToast('يرجى اختيار ' + currentVoucherConfig.entityLabel, 'warning'); return; }
11327: 
11328:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11329:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11330: 
11331:     var notes = byId('voucherNotesLarge') ? byId('voucherNotesLarge').value : '';
11332:     var reference = byId('voucherReference') ? byId('voucherReference').value.trim() : '';
11333:     if (!reference) { showToast('مرجع الإذن مطلوب', 'warning'); return; }
11334: 
11335:     var settingsRes = await supabase.from('app_settings')
11336:         .select('main_branch_id')
11337:         .eq('company_id', companyId)
11338:         .order('created_at', { ascending: true })
11339:         .limit(1)
11340:         .maybeSingle();
11341:     if (settingsRes.error) { showToast(settingsRes.error.message, 'error'); return; }
11342: 
11343:     var mainBranchId = settingsRes.data ? settingsRes.data.main_branch_id : null;
11344:     if (!mainBranchId) { showToast('الفرع الرئيسي غير محدد', 'error'); return; }
11345: 
11346:     var fromId = null;
11347:     var toId = null;
11348:     var repId = null;
11349: 
11350:     if (currentVoucherType === 'Transfer') {
11351:         fromId = mainBranchId;
11352:         toId = entity;
11353:     } else if (currentVoucherType === 'DirectSale') {
11354:         fromId = mainBranchId;
11355:         toId = entity;
11356: 
11357:         var directSaleVehicleRes = await supabase.from('vehicles')
11358:             .select('id, driver_id')
11359:             .eq('company_id', companyId)
11360:             .eq('id', entity)
11361:             .eq('status', 'Active')
11362:             .maybeSingle();
11363:         if (directSaleVehicleRes.error) { showToast(directSaleVehicleRes.error.message, 'error'); return; }
11364:         if (!directSaleVehicleRes.data || !directSaleVehicleRes.data.driver_id) {
11365:             showToast('المركبة المختارة لا ترتبط بمندوب بيع مباشر', 'error');
11366:             return;
11367:         }
11368:         repId = directSaleVehicleRes.data.driver_id;
11369:     } else if (currentVoucherType === 'DirectReturn') {
11370:         fromId = entity;
11371:         toId = mainBranchId;
11372:     } else if (currentVoucherType === 'SupplierReturn') {
11373:         fromId = mainBranchId;
11374:         toId = entity;
11375:     } else {
11376:         showToast('نوع الإذن غير مدعوم', 'error');
11377:         return;
11378:     }
11379: 
11380:     var items = [];
11381:     for (var i = 0; i < voucherCart.length; i++) {
11382:         items.push({
11383:             itemCode: voucherCart[i].code,
11384:             qty: voucherCart[i].qty,
11385:             unitPrice: voucherCart[i].price || 0,
11386:             notes: ''
11387:         });
11388:     }
11389: 
11390:     window._warehouseVoucherOperations = window._warehouseVoucherOperations || {};
11391:     var fingerprint = [
11392:         companyId,
11393:         currentVoucherType,
11394:         entity,
11395:         reference,
11396:         notes,
11397:         repId || '',
11398:         JSON.stringify(items)
11399:     ].join('|');
11400:     var operationId = window._warehouseVoucherOperations[fingerprint];
11401:     if (!operationId) {
11402:         operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('WHV-' + Date.now() + '-' + Math.random().toString(36).slice(2));
11403:         window._warehouseVoucherOperations[fingerprint] = operationId;
11404:     }
11405: 
11406:     showLoader('جاري حفظ وإرسال الإذن...');
11407:     var ses = await supabase.auth.getSession();
11408:     var token = ses.data.session ? ses.data.session.access_token : null;
11409:     if (!token) { hideLoader(); showToast('انتهت الجلسة', 'error'); return; }
11410: 
11411:     try {
11412:         var createBody = {
11413:             type: currentVoucherType,
11414:             reference: reference,
11415:             fromType: currentVoucherType === 'DirectReturn' ? 'Vehicle' : 'Branch',
11416:             fromId: fromId,
11417:             toType: currentVoucherType === 'DirectSale' || currentVoucherType === 'DirectReturn' ? (currentVoucherType === 'DirectSale' ? 'Vehicle' : 'Branch') : (currentVoucherType === 'SupplierReturn' ? 'Supplier' : 'Branch'),
11418:             toId: toId,
11419:             items: items,
11420:             notes: notes,
11421:             rep_id: repId,
11422:             operation_id: operationId
11423:         };
11424: 
11425:         var createRes = await fetch(RW_SUPABASE_URL + '/functions/v1/create-stock-voucher', {
11426:             method: 'POST',
11427:             headers: {
11428:                 'Content-Type': 'application/json',
11429:                 'Authorization': 'Bearer ' + token,
11430:                 'Idempotency-Key': operationId
11431:             },
11432:             body: JSON.stringify(createBody)
11433:         });
11434: 
11435:         var createJson = await createRes.json().catch(function() { return {}; });
11436:         if (!createRes.ok || !createJson.success) {
11437:             throw new Error(createJson.msg || createJson.error || 'فشل حفظ الإذن');
11438:         }
11439: 
11440:         var voucherCode = createJson.voucherId || createJson.voucher_code;
11441:         if (!voucherCode) throw new Error('لم يُرجع إنشاء الإذن رقمًا صالحًا');
11442: 
11443:         var sendRes = await fetch(RW_SUPABASE_URL + '/functions/v1/send-stock-voucher', {
11444:             method: 'POST',
11445:             headers: {
11446:                 'Content-Type': 'application/json',
11447:                 'Authorization': 'Bearer ' + token,
11448:                 'Idempotency-Key': operationId
11449:             },
11450:             body: JSON.stringify({ voucher_code: voucherCode })
11451:         });
11452: 
11453:         var sendJson = await sendRes.json().catch(function() { return {}; });
11454:         if (!sendRes.ok || !sendJson.success) {
11455:             throw new Error(sendJson.msg || sendJson.error || 'فشل الإرسال');
11456:         }
11457: 
11458:         hideLoader();
11459:         delete window._warehouseVoucherOperations[fingerprint];
11460:         showToast(sendJson.duplicate ? 'تم استرجاع نتيجة الإذن السابقة' : ('تم إنشاء وإرسال الإذن ' + voucherCode), 'success');
11461:         voucherCart = [];
11462:         _renderVoucherCart();
11463:         if (typeof loadVouchers === 'function') await loadVouchers();
11464:     } catch (e) {
11465:         hideLoader();
11466:         showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس العملية', 'error');
11467:     }
11468: }
11469: 
11470:     // ==================== VOUCHERS LIST – عرض الأذونات مع فصل ====================
11471:     async function loadVouchers() {
11472:         var c = byId('rw-page-container'); if (!c) return;
11473:         safeText(byId('rw-header-title'), 'الأذونات المخزنية');
11474:         safeHTML(c, `<div class="p-4">
11475:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">
11476:                 <div class="flex flex-wrap items-center gap-2 mb-3">
11477:                     <select id="v-filter-type" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm"><option value="">كل الأنواع</option><option value="Transfer">تحويل</option><option value="DirectSale">صرف مباشر</option><option value="DirectReturn">مرتجع مباشر</option><option value="SupplierReturn">مرتجع لمورد</option><option value="Picking">تحضير</option><option value="Loading">تحميل</option><option value="Return">مرتجع</option><option value="Unloading">تفريغ</option><option value="Adjustment">جرد</option></select>
11478:                     <select id="v-filter-status" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm"><option value="">كل الحالات</option><option value="Draft">مسودة</option><option value="Sent">مُرسل</option><option value="Received">مُستلم</option><option value="Completed">مكتمل</option></select>
11479:                     <input type="date" id="v-filter-from" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm">
11480:                     <input type="date" id="v-filter-to" onchange="RW_Warehouse._applyVouchers()" class="p-2 bg-white border rounded-lg text-sm">
11481:                     <input type="text" id="v-search" oninput="RW_Warehouse._applyVouchers()" placeholder="بحث برقم الإذن..." class="p-2 bg-white border rounded-lg text-sm w-40">
11482:                     <button onclick="RW_Warehouse._openNewVoucherModal()" class="bg-indigo-600 text-white px-4 py-2 rounded-xl font-bold text-sm"><i class="fa-solid fa-plus ml-1"></i> إذن جديد</button>
11483:                     <label class="flex items-center gap-2 ml-3 text-sm"><input type="checkbox" id="v-show-all" onchange="RW_Warehouse._applyVouchers()"> <span class="font-bold">إظهار الكل (يشمل التلقائية)</span></label>
11484:                 </div>
11485:             </div>
11486:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh" id="vouchers-table-container">
11487:                 <table class="w-full"><thead class="bg-gray-800 text-white sticky top-0"><tr><th class="p-3">رقم الإذن</th><th class="p-3">النوع</th><th class="p-3">التاريخ</th><th class="p-3">الحالة</th><th class="p-3">المرجع</th><th class="p-3">من</th><th class="p-3">إلى</th><th class="p-3 text-center">إجراءات</th></tr></thead><tbody id="vouchers-tbody"><tr><td colspan="8" class="text-center py-8">جاري التحميل...</td></tr></tbody></table>
11488:             </div>
11489:         </div>`);
11490:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11491: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11492: var res = await supabase.from('stock_vouchers').select('*').eq('company_id', companyId).order('voucher_date', { ascending: false });
11493:         window._vouchersData = res.data || [];
11494:         _applyVouchers();
11495:     }
11496: 
11497:     function _applyVouchers() {
11498:         var d = window._vouchersData || [];
11499:         var type = byId('v-filter-type') ? byId('v-filter-type').value : '';
11500:         var status = byId('v-filter-status') ? byId('v-filter-status').value : '';
11501:         var from = byId('v-filter-from') ? byId('v-filter-from').value : '';
11502:         var to = byId('v-filter-to') ? byId('v-filter-to').value : '';
11503:         var search = (byId('v-search') ? byId('v-search').value : '').toLowerCase();
11504:         var showAll = byId('v-show-all') ? byId('v-show-all').checked : false;
11505:         
11506:         if (!showAll) {
11507:             d = d.filter(function(v) { return v.source === 'Manual' || (v.source !== 'Manual' && v.type === 'Adjustment'); });
11508:         }
11509:         if (type) d = d.filter(function(v) { return v.type === type; });
11510:         if (status) d = d.filter(function(v) { return v.status === status; });
11511:         if (from) d = d.filter(function(v) { return v.voucher_date >= from; });
11512:         if (to) d = d.filter(function(v) { return v.voucher_date <= to; });
11513:         if (search) d = d.filter(function(v) { return (v.voucher_code||'').toLowerCase().indexOf(search) !== -1; });
11514:         var tb = byId('vouchers-tbody'); if (!tb) return;
11515:         if (!d.length) { safeHTML(tb, '<tr><td colspan="8" class="text-center py-8">لا توجد أذونات</td></tr>'); return; }
11516:         RW_Table.paginate('vouchers-tbody', d, 1, 50, function(v) {
11517:             var statusBadge = { 'Draft':'bg-gray-100 text-gray-600', 'Sent':'bg-blue-100 text-blue-700', 'Received':'bg-purple-100 text-purple-700', 'Completed':'bg-green-100 text-green-700' }[v.status] || 'bg-gray-100 text-gray-700';
11518:             var isSystem = (v.source === 'Auto' || ['Picking','Loading','Return','Unloading'].indexOf(v.type) !== -1);
11519:             var actions = '<button onclick="RW_Warehouse._viewVoucherDetails(\'' + v.voucher_code + '\')" class="text-blue-600 mx-1"><i class="fa-solid fa-eye"></i></button>';
11520:             if (v.status === 'Draft' && !isSystem) actions += '<button onclick="RW_Warehouse._sendVoucher(\'' + v.voucher_code + '\')" class="text-blue-600 mx-1"><i class="fa-solid fa-paper-plane"></i></button>';
11521:             if (v.status === 'Sent') actions += '<button onclick="RW_Warehouse._receiveVoucher(\'' + v.voucher_code + '\')" class="text-green-600 mx-1"><i class="fa-solid fa-check-circle"></i></button>';
11522:             var sourceIndicator = isSystem ? ' <i class="fa-solid fa-robot text-gray-400 text-xs" title="تلقائي"></i>' : '';
11523:             return '<tr class="hover:bg-gray-50"><td class="p-3 font-bold text-indigo-700">' + (v.voucher_code||'') + sourceIndicator + '</td><td class="p-3">' + (v.type||'') + '</td><td class="p-3">' + (v.voucher_date||'') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs ' + statusBadge + '">' + (v.status||'') + '</span></td><td class="p-3">' + (v.reference||'-') + '</td><td class="p-3">' + (v.from_id||'-') + '</td><td class="p-3">' + (v.to_id||'-') + '</td><td class="p-3 text-center">' + actions + '</td></tr>';
11524:         });
11525:     }
11526: 
11527: async function _viewVoucherDetails(voucherCode) {
11528:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11529:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11530: 
11531:     showLoader('جاري التحميل...');
11532: 
11533:     var voucherRes = await supabase.from('stock_vouchers')
11534:         .select('id,voucher_code')
11535:         .eq('company_id', companyId)
11536:         .eq('voucher_code', voucherCode)
11537:         .maybeSingle();
11538: 
11539:     if (voucherRes.error || !voucherRes.data) {
11540:         hideLoader();
11541:         showToast('الإذن غير موجود في الشركة الحالية', 'error');
11542:         return;
11543:     }
11544: 
11545:     var detRes = await supabase.from('stock_voucher_details')
11546:         .select('*')
11547:         .eq('voucher_id', voucherRes.data.id)
11548:         .order('item_code');
11549: 
11550:     hideLoader();
11551: 
11552:     var details = detRes.data || [];
11553:     if (!details.length) {
11554:         showToast('لا توجد تفاصيل', 'info');
11555:         return;
11556:     }
11557: 
11558:     var h = '<table class="w-full border text-sm"><thead class="bg-gray-100"><tr>' +
11559:         '<th class="p-2">الكود</th>' +
11560:         '<th class="p-2">الصنف</th>' +
11561:         '<th class="p-2 text-center">الكمية</th>' +
11562:         '<th class="p-2 text-center">المستلمة</th>' +
11563:         '</tr></thead><tbody>';
11564: 
11565:     details.forEach(function(d) {
11566:         h += '<tr>' +
11567:             '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
11568:             '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
11569:             '<td class="p-2 border text-center">' + (d.qty || 0) + '</td>' +
11570:             '<td class="p-2 border text-center">' + (d.received_qty || 0) + '</td>' +
11571:             '</tr>';
11572:     });
11573: 
11574:     h += '</tbody></table>';
11575: 
11576:     Swal.fire({
11577:         title: 'تفاصيل الإذن: ' + esc(voucherRes.data.voucher_code),
11578:         html: h,
11579:         width: '600px',
11580:         showCloseButton: true,
11581:         showConfirmButton: false
11582:     });
11583: }
11584: 
11585:     async function _sendVoucher(voucherCode) {
11586:         var confirm = await Swal.fire({ title: 'تأكيد الإرسال', text: 'سيتم إرسال الإذن ' + voucherCode + ' وخصم المخزون من المصدر. متابعة؟', icon: 'warning', showCancelButton: true, confirmButtonColor: '#2563eb', confirmButtonText: 'نعم، أرسل', cancelButtonText: 'إلغاء' });
11587:         if (!confirm.isConfirmed) return;
11588:         showLoader('جاري إرسال الإذن...');
11589:         var ses = await supabase.auth.getSession(), token = ses.data.session ? ses.data.session.access_token : null;
11590:         try {
11591:             var res = await fetch(RW_SUPABASE_URL + '/functions/v1/send-stock-voucher', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token }, body: JSON.stringify({ voucher_code: voucherCode }) });
11592:             var json = await res.json(); hideLoader();
11593:             if (json.success) { showToast('تم إرسال الإذن بنجاح', 'success'); loadVouchers(); }
11594:             else showToast(json.error || json.msg || 'فشل الإرسال', 'error');
11595:         } catch(e) { hideLoader(); showToast('فشل الاتصال بـ Edge Function', 'error'); }
11596:     }
11597: 
11598: async function _receiveVoucher(voucherCode) {
11599:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11600:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11601:     showLoader('جاري تحميل تفاصيل الإذن...');
11602:     var voucherRes = await supabase.from('stock_vouchers').select('id,status,voucher_code,to_id').eq('company_id', companyId).eq('voucher_code', voucherCode).maybeSingle();
11603:     if (voucherRes.error || !voucherRes.data) { hideLoader(); showToast('الإذن غير موجود في الشركة الحالية', 'error'); return; }
11604:     if (voucherRes.data.status !== 'Sent') { hideLoader(); showToast('الإذن غير جاهز للاستلام: ' + (voucherRes.data.status || ''), 'warning'); return; }
11605:     var detRes = await supabase.from('stock_voucher_details').select('*').eq('voucher_id', voucherRes.data.id).order('item_code');
11606:     var details = detRes.data || [];
11607:     hideLoader();
11608:     if (!details.length) { showToast('لا توجد تفاصيل لهذا الإذن', 'info'); return; }
11609:     var html = '<div class="text-right"><table class="w-full border text-sm"><thead class="bg-gray-100"><tr><th class="p-2 border">الصنف</th><th class="p-2 border text-center">المرسل</th><th class="p-2 border text-center">المستلم سابقًا</th><th class="p-2 border text-center">المتبقي</th><th class="p-2 border text-center">استلام الآن</th></tr></thead><tbody>';
11610:     for (var i = 0; i < details.length; i++) {
11611:         var d = details[i];
11612:         var totalQty = Number(d.qty || 0);
11613:         var receivedBefore = Number(d.received_qty || 0);
11614:         var remaining = Math.max(0, totalQty - receivedBefore);
11615:         html += '<tr><td class="p-2 border font-semibold">' + esc(d.item_name || '') + ' (' + esc(d.item_code || '') + ')</td><td class="p-2 border text-center font-bold">' + totalQty + '</td><td class="p-2 border text-center">' + receivedBefore + '</td><td class="p-2 border text-center font-bold text-blue-700">' + remaining + '</td><td class="p-2 border text-center"><input type="number" id="vrec_qty_' + i + '" value="' + remaining + '" class="w-24 p-1 border rounded text-center" min="0" max="' + remaining + '" step="0.01"></td></tr>';
11616:     }
11617:     html += '</tbody></table></div>';
11618:     var result = await Swal.fire({
11619:         title: 'استلام الإذن: ' + esc(voucherCode),
11620:         html: html,
11621:         width: '850px',
11622:         showCancelButton: true,
11623:         confirmButtonText: 'تأكيد الاستلام',
11624:         confirmButtonColor: '#10b981',
11625:         cancelButtonText: 'إلغاء',
11626:         preConfirm: function() {
11627:             var items = [];
11628:             var hasQty = false;
11629:             for (var j = 0; j < details.length; j++) {
11630:                 var maxRemaining = Math.max(0, Number(details[j].qty || 0) - Number(details[j].received_qty || 0));
11631:                 var qty = parseFloat((document.getElementById('vrec_qty_' + j) || {}).value) || 0;
11632:                 if (qty < 0 || qty > maxRemaining) {
11633:                     Swal.showValidationMessage('كمية الاستلام تتجاوز المتبقي للصنف: ' + (details[j].item_code || ''));
11634:                     return false;
11635:                 }
11636:                 if (qty > 0) hasQty = true;
11637:                 items.push({ itemCode: details[j].item_code || '', itemName: details[j].item_name || '', unit: details[j].unit || 'حبة', receivedQty: qty });
11638:             }
11639:             if (!hasQty) { Swal.showValidationMessage('أدخل كمية واحدة على الأقل للاستلام'); return false; }
11640:             return items;
11641:         }
11642:     });
11643:     if (!result.isConfirmed) return;
11644:     var positiveItems = (result.value || []).filter(function(x) { return Number(x.receivedQty || 0) > 0; }).sort(function(a,b) { return String(a.itemCode).localeCompare(String(b.itemCode)); });
11645:     var operationId = 'UI-RECEIVE:' + companyId + ':' + voucherRes.data.id + ':' + positiveItems.map(function(x) { return String(x.itemCode) + ':' + Number(x.receivedQty); }).join('|');
11646:     showLoader('جاري الاستلام...');
11647:     var ses = await supabase.auth.getSession();
11648:     var token = ses.data.session ? ses.data.session.access_token : null;
11649:     if (!token) { hideLoader(); showToast('انتهت الجلسة', 'error'); return; }
11650:     try {
11651:         var res = await fetch(RW_SUPABASE_URL + '/functions/v1/receive-stock-voucher', {
11652:             method: 'POST',
11653:             headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Idempotency-Key': operationId },
11654:             body: JSON.stringify({ voucher_code: voucherCode, receivedItems: positiveItems, operation_id: operationId })
11655:         });
11656:         var json = await res.json();
11657:         hideLoader();
11658:         if (json.success) { showToast(json.msg || (json.duplicate ? 'تم تأكيد العملية السابقة' : 'تم الاستلام'), 'success'); loadVouchers(); }
11659:         else showToast(json.error || json.msg || 'فشل الاستلام', 'error');
11660:     } catch (e) { hideLoader(); showToast('فشل الاتصال بـ Edge Function', 'error'); }
11661: }
11662: 
11663: async function _openNewVoucherModal() {
11664:     var typeOptions =
11665:         '<option value="Transfer">تحويل داخلي</option>' +
11666:         '<option value="DirectSale">صرف سيارة بيع مباشر</option>' +
11667:         '<option value="DirectReturn">استلام مرتجع سيارة</option>' +
11668:         '<option value="SupplierReturn">مرتجع لمورد</option>';
11669: 
11670:     var html =
11671:         '<div class="text-right space-y-3">' +
11672:             '<div>' +
11673:                 '<label class="text-xs font-bold">نوع الإذن</label>' +
11674:                 '<select id="newVoucherType" class="swal2-input w-full">' +
11675:                     typeOptions +
11676:                 '</select>' +
11677:             '</div>' +
11678:         '</div>';
11679: 
11680:     var result = await Swal.fire({
11681:         title: 'إنشاء إذن مخزني جديد',
11682:         html: html,
11683:         showCancelButton: true,
11684:         confirmButtonText: 'متابعة',
11685:         cancelButtonText: 'إلغاء',
11686:         preConfirm: function() {
11687:             var type = document.getElementById('newVoucherType').value;
11688:             if (!type) {
11689:                 Swal.showValidationMessage('اختر نوع الإذن');
11690:                 return false;
11691:             }
11692:             return { type: type };
11693:         }
11694:     });
11695: 
11696:     if (!result.isConfirmed) return;
11697: 
11698:     loadVoucherForm(result.value.type);
11699: }
11700: 
11701:     // ==================== PICKING ====================
11702:     async function loadPicking() {
11703:         var c = byId('rw-page-container'); if (!c) return;
11704:         safeText(byId('rw-header-title'), 'التحضير (Picking)');
11705:         safeHTML(c, `<div class="p-4">
11706:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11707:                 <input type="text" id="pk-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyPicking()">
11708:                 <select id="pk-f-st" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyPicking()"><option value="">كل الحالات</option><option value="Open">Open</option>
11709: <option value="Confirmed">Confirmed</option></select>
11710:                 <button onclick="RW_Warehouse._applyPicking()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11711:             </div></div>
11712:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="pk-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11713:         </div>`);
11714:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11715: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11716: var res = await supabase.from('runsheets')
11717:     .select('*')
11718:     .eq('company_id', companyId)
11719:     .in('status', ['Open', 'Confirmed']);
11720:         window._pickingData = res.data || [];
11721:         _applyPicking();
11722:     }
11723:     function _applyPicking() {
11724:         var d = window._pickingData || [];
11725:         var id = (byId('pk-f-id')?.value||'').toLowerCase(), st = byId('pk-f-st')?.value;
11726:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11727:         if (st) d = d.filter(function(r) { return r.status === st; });
11728:         var tb = byId('pk-table'); if (!tb) return;
11729:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات محضّرة</td></tr>'); return; }
11730:         RW_Table.paginate('pk-table', d, 1, 50, function(r) {
11731:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showPickingDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-purple-100 text-purple-700">Picked</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11732:         });
11733:     }
11734:     async function _showPickingDetails(code) {
11735:         showLoader('جاري التحميل...');
11736:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11737: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11738: var rsRes = await supabase.from('runsheets')
11739:     .select('id')
11740:     .eq('company_id', companyId)
11741:     .eq('runsheet_code', code)
11742:     .maybeSingle();
11743:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11744:         hideLoader();
11745:         var items = itemsRes.data || [];
11746:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11747:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المطلوبة</th><th class="p-2 text-center">الكمية المحضرة</th></tr></thead><tbody>';
11748:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_ordered||0) + '</td><td class="p-2 text-center font-bold text-purple-600">' + (it.qty_picked||0) + '</td></tr>'; });
11749:         h += '</tbody></table></div>';
11750:         Swal.fire({ title: 'تفاصيل التحضير: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11751:     }
11752: 
11753:     // ==================== LOADING ====================
11754:     async function loadLoading() {
11755:         var c = byId('rw-page-container'); if (!c) return;
11756:         safeText(byId('rw-header-title'), 'التحميل (Loading)');
11757:         safeHTML(c, `<div class="p-4">
11758:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11759:                 <input type="text" id="ld-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyLoading()">
11760:                 <select id="ld-f-st" class="p-2 bg-slate-50 rounded text-sm" onchange="RW_Warehouse._applyLoading()"><option value="">كل الحالات</option><option>Loaded</option></select>
11761:                 <button onclick="RW_Warehouse._applyLoading()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11762:             </div></div>
11763:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="ld-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11764:         </div>`);
11765:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11766: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11767: var res = await supabase.from('runsheets')
11768:     .select('*')
11769:     .eq('company_id', companyId)
11770:     .in('status', ['Loaded']);
11771:         window._loadingData = res.data || [];
11772:         _applyLoading();
11773:     }
11774:     function _applyLoading() {
11775:         var d = window._loadingData || [];
11776:         var id = (byId('ld-f-id')?.value||'').toLowerCase(), st = byId('ld-f-st')?.value;
11777:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11778:         if (st) d = d.filter(function(r) { return r.status === st; });
11779:         var tb = byId('ld-table'); if (!tb) return;
11780:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات محمّلة</td></tr>'); return; }
11781:         RW_Table.paginate('ld-table', d, 1, 50, function(r) {
11782:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showLoadingDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-orange-100 text-orange-700">Loaded</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11783:         });
11784:     }
11785:     async function _showLoadingDetails(code) {
11786:         showLoader('جاري التحميل...');
11787: 
11788:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11789:         if (!companyId) {
11790:             hideLoader();
11791:             showToast('سياق الشركة غير محدد', 'error');
11792:             return;
11793:         }
11794: 
11795:         try {
11796:             var rsRes = await supabase.from('runsheets')
11797:                 .select('id')
11798:                 .eq('company_id', companyId)
11799:                 .eq('runsheet_code', code)
11800:                 .maybeSingle();
11801: 
11802:             if (rsRes.error) throw rsRes.error;
11803:             if (!rsRes.data) {
11804:                 hideLoader();
11805:                 showToast('الرانشيت غير موجود في الشركة الحالية', 'error');
11806:                 return;
11807:             }
11808: 
11809:             var itemsRes = await supabase.from('run_sheet_details')
11810:                 .select('*')
11811:                 .eq('runsheet_id', rsRes.data.id);
11812: 
11813:             if (itemsRes.error) throw itemsRes.error;
11814: 
11815:             hideLoader();
11816: 
11817:             var items = itemsRes.data || [];
11818:             if (!items.length) {
11819:                 showToast('لا توجد أصناف', 'info');
11820:                 return;
11821:             }
11822: 
11823:             var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المحضّرة</th><th class="p-2 text-center">الكمية المحمّلة</th></tr></thead><tbody>';
11824:             items.forEach(it => {
11825:                 h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_picked||0) + '</td><td class="p-2 text-center font-bold text-orange-600">' + (it.qty_loaded||0) + '</td></tr>';
11826:             });
11827:             h += '</tbody></table></div>';
11828: 
11829:             Swal.fire({
11830:                 title: 'تفاصيل التحميل: ' + code,
11831:                 html: h,
11832:                 width: '700px',
11833:                 showCloseButton: true,
11834:                 showConfirmButton: false
11835:             });
11836:         } catch (e) {
11837:             hideLoader();
11838:             showToast('فشل تحميل تفاصيل التحميل: ' + (e.message || ''), 'error');
11839:         }
11840:     }
11841: 
11842:     // ==================== DELIVERY ====================
11843:     async function loadDelivery() {
11844:         var c = byId('rw-page-container'); if (!c) return;
11845:         safeText(byId('rw-header-title'), 'التوصيل (Delivery)');
11846:         safeHTML(c, `<div class="p-4">
11847:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11848:                 <input type="text" id="dv-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyDelivery()">
11849:                 <button onclick="RW_Warehouse._applyDelivery()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11850:             </div></div>
11851:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="dv-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11852:         </div>`);
11853:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11854: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11855: var res = await supabase.from('runsheets')
11856:     .select('*')
11857:     .eq('company_id', companyId)
11858:     .in('status', ['Delivered']);
11859:         window._deliveryData = res.data || [];
11860:         _applyDelivery();
11861:     }
11862:     function _applyDelivery() {
11863:         var d = window._deliveryData || [];
11864:         var id = (byId('dv-f-id')?.value||'').toLowerCase();
11865:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11866:         var tb = byId('dv-table'); if (!tb) return;
11867:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات موصّلة</td></tr>'); return; }
11868:         RW_Table.paginate('dv-table', d, 1, 50, function(r) {
11869:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showDeliveryDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-green-100 text-green-700">Delivered</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11870:         });
11871:     }
11872:     async function _showDeliveryDetails(code) {
11873:         showLoader('جاري التحميل...');
11874:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11875: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11876:         var rsRes = await supabase.from('runsheets')
11877:     .select('id')
11878:     .eq('company_id', companyId)
11879:     .eq('runsheet_code', code)
11880:     .maybeSingle();
11881:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11882:         hideLoader();
11883:         var items = itemsRes.data || [];
11884:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11885:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المحمّلة</th><th class="p-2 text-center">الكمية المسلّمة</th></tr></thead><tbody>';
11886:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_loaded||0) + '</td><td class="p-2 text-center font-bold text-green-600">' + (it.qty_delivered||0) + '</td></tr>'; });
11887:         h += '</tbody></table></div>';
11888:         Swal.fire({ title: 'تفاصيل التوصيل: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11889:     }
11890: 
11891:     // ==================== RETURN ====================
11892:     async function loadReturn() {
11893:         var c = byId('rw-page-container'); if (!c) return;
11894:         safeText(byId('rw-header-title'), 'المرتجعات (Return)');
11895:         safeHTML(c, `<div class="p-4">
11896:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><div class="grid grid-cols-2 md:grid-cols-6 gap-2">
11897:                 <input type="text" id="rt-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyReturn()">
11898:                 <button onclick="RW_Warehouse._applyReturn()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>
11899:             </div></div>
11900:             <div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh"><table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr><th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th></tr></thead><tbody id="rt-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table></div>
11901:         </div>`);
11902:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11903: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
11904: var res = await supabase.from('runsheets')
11905:     .select('*')
11906:     .eq('company_id', companyId)
11907:     .in('status', ['Returned']);
11908:         window._returnData = res.data || [];
11909:         _applyReturn();
11910:     }
11911:     function _applyReturn() {
11912:         var d = window._returnData || [];
11913:         var id = (byId('rt-f-id')?.value||'').toLowerCase();
11914:         if (id) d = d.filter(function(r) { return (r.runsheet_code||'').toLowerCase().indexOf(id) !== -1; });
11915:         var tb = byId('rt-table'); if (!tb) return;
11916:         if (!d.length) { safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات مرتجعة</td></tr>'); return; }
11917:         RW_Table.paginate('rt-table', d, 1, 50, function(r) {
11918:             return '<tr class="border-b hover:bg-gray-50 cursor-pointer" onclick="RW_Warehouse._showReturnDetails(\'' + r.runsheet_code + '\')"><td class="p-3 font-bold">' + (r.runsheet_code||'') + '</td><td class="p-3">' + (r.run_date||'') + '</td><td class="p-3">' + (r.driver_id||'---') + '</td><td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-rose-100 text-rose-700">Returned</span></td><td class="p-3 text-center"><button class="text-blue-600"><i class="fa-solid fa-eye"></i></button></td></tr>';
11919:         });
11920:     }
11921:     async function _showReturnDetails(code) {
11922:         showLoader('جاري التحميل...');
11923:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11924: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
11925: var rsRes = await supabase.from('runsheets')
11926:     .select('id')
11927:     .eq('company_id', companyId)
11928:     .eq('runsheet_code', code)
11929:     .maybeSingle();
11930:         var itemsRes = await supabase.from('run_sheet_details').select('*').eq('runsheet_id', rsRes.data?.id);
11931:         hideLoader();
11932:         var items = itemsRes.data || [];
11933:         if (!items.length) { showToast('لا توجد أصناف', 'info'); return; }
11934:         var h = '<div class="text-right"><table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الكمية المسلّمة</th><th class="p-2 text-center">الكمية المرتجعة</th></tr></thead><tbody>';
11935:         items.forEach(it => { h += '<tr><td class="p-2 font-bold">' + (it.item_name||'') + '</td><td class="p-2 text-center">' + (it.qty_delivered||0) + '</td><td class="p-2 text-center font-bold text-rose-600">' + (it.qty_returned||0) + '</td></tr>'; });
11936:         h += '</tbody></table></div>';
11937:         Swal.fire({ title: 'تفاصيل المرتجعات: ' + code, html: h, width: '700px', showCloseButton: true, showConfirmButton: false });
11938:     }
11939: 
11940:     // ==================== UNLOADING ====================
11941:     async function loadUnloading() {
11942:         var c = byId('rw-page-container');
11943:         if (!c) return;
11944: 
11945:         safeText(byId('rw-header-title'), 'التفريغ (Unloading)');
11946:         safeHTML(c, '<div class="p-4">' +
11947:             '<div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">' +
11948:                 '<div class="grid grid-cols-2 md:grid-cols-6 gap-2">' +
11949:                     '<input type="text" id="ul-f-id" placeholder="رقم الرانشيت..." class="p-2 bg-slate-50 rounded text-sm" oninput="RW_Warehouse._applyUnloading()">' +
11950:                     '<button onclick="RW_Warehouse._applyUnloading()" class="bg-gray-600 text-white px-3 rounded text-sm">تطبيق</button>' +
11951:                 '</div>' +
11952:             '</div>' +
11953:             '<div class="bg-white rounded-2xl shadow-sm border overflow-auto" style="max-height:65vh">' +
11954:                 '<table class="w-full"><thead class="bg-gray-50 sticky top-0"><tr>' +
11955:                     '<th class="p-3">الرانشيت</th><th class="p-3">التاريخ</th><th class="p-3">السائق</th><th class="p-3">الحالة</th><th class="p-3 text-center">عرض</th>' +
11956:                 '</tr></thead><tbody id="ul-table"><tr><td colspan="5" class="text-center py-8">جاري التحميل...</td></tr></tbody></table>' +
11957:             '</div>' +
11958:         '</div>');
11959: 
11960:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
11961:         if (!companyId) {
11962:             showToast('سياق الشركة غير محدد', 'error');
11963:             return;
11964:         }
11965: 
11966:         var res = await supabase.from('runsheets')
11967:             .select('id,runsheet_code,run_date,driver_id,vehicle_id,status')
11968:             .eq('company_id', companyId)
11969:             .eq('status', 'Loaded')
11970:             .order('run_date', { ascending: false });
11971: 
11972:         if (res.error) {
11973:             showToast(res.error.message, 'error');
11974:             return;
11975:         }
11976: 
11977:         window._unloadingData = res.data || [];
11978:         _applyUnloading();
11979:     }
11980: 
11981:     function _applyUnloading() {
11982:         var d = window._unloadingData || [];
11983:         var id = (byId('ul-f-id')?.value || '').trim().toLowerCase();
11984:         if (id) {
11985:             d = d.filter(function(r) {
11986:                 return String(r.runsheet_code || '').toLowerCase().indexOf(id) !== -1;
11987:             });
11988:         }
11989: 
11990:         var tb = byId('ul-table');
11991:         if (!tb) return;
11992: 
11993:         if (!d.length) {
11994:             safeHTML(tb, '<tr><td colspan="5" class="text-center py-8">لا توجد رانشيتات جاهزة للتفريغ</td></tr>');
11995:             return;
11996:         }
11997: 
11998:         RW_Table.paginate('ul-table', d, 1, 50, function(r) {
11999:             var code = String(r.runsheet_code || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
12000:             return "<tr class=\"border-b hover:bg-gray-50 cursor-pointer\" onclick=\"RW_Warehouse._showUnloadingDetails('" + code + "')\">" +
12001:                 '<td class="p-3 font-bold">' + esc(r.runsheet_code || '') + '</td>' +
12002:                 '<td class="p-3">' + esc(r.run_date || '') + '</td>' +
12003:                 '<td class="p-3">' + esc(r.driver_id || '---') + '</td>' +
12004:                 '<td class="p-3"><span class="px-2 py-1 rounded-full text-xs bg-orange-100 text-orange-700">Loaded</span></td>' +
12005:                 "<td class=\"p-3 text-center\"><button class=\"text-blue-600\" onclick=\"event.stopPropagation(); RW_Warehouse._showUnloadingDetails('" + code + "')\"><i class=\"fa-solid fa-eye\"></i></button></td>" +
12006:             '</tr>';
12007:         });
12008:     }
12009: 
12010:     async function _showUnloadingDetails(code) {
12011:         if (!code) {
12012:             showToast('رقم الرانشيت غير صالح', 'error');
12013:             return;
12014:         }
12015: 
12016:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12017:         if (!companyId) {
12018:             showToast('سياق الشركة غير محدد', 'error');
12019:             return;
12020:         }
12021: 
12022:         showLoader('جاري تحميل تفاصيل التفريغ...');
12023:         try {
12024:             var rsRes = await supabase.from('runsheets')
12025:                 .select('id,runsheet_code,run_date,driver_id,vehicle_id,status')
12026:                 .eq('company_id', companyId)
12027:                 .eq('runsheet_code', code)
12028:                 .maybeSingle();
12029: 
12030:             if (rsRes.error) throw rsRes.error;
12031:             if (!rsRes.data) throw new Error('الرانشيت غير موجود في الشركة الحالية');
12032:             if (rsRes.data.status !== 'Loaded') throw new Error('الرانشيت ليس في حالة Loaded؛ لا يمكن اعتباره جاهزًا للتفريغ');
12033: 
12034:             var detailsRes = await supabase.from('run_sheet_details')
12035:                 .select('item_code,item_name,unit,qty_ordered,qty_picked,qty_loaded,qty_delivered,qty_refused,qty_returned')
12036:                 .eq('runsheet_id', rsRes.data.id)
12037:                 .order('item_code');
12038: 
12039:             if (detailsRes.error) throw detailsRes.error;
12040: 
12041:             var details = detailsRes.data || [];
12042:             if (!details.length) {
12043:                 hideLoader();
12044:                 showToast('لا توجد تفاصيل أصناف لهذا الرانشيت', 'info');
12045:                 return;
12046:             }
12047: 
12048:             var loadedTotal = 0;
12049:             var remainingTotal = 0;
12050:             var html = '<div class="text-right" dir="rtl">';
12051:             html += '<div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">' +
12052:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">الرانشيت</div><div class="font-black">' + esc(rsRes.data.runsheet_code) + '</div></div>' +
12053:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">السائق</div><div class="font-bold">' + esc(rsRes.data.driver_id || '---') + '</div></div>' +
12054:                 '<div class="bg-slate-50 rounded-xl p-3"><div class="text-xs text-slate-500">السيارة</div><div class="font-bold">' + esc(rsRes.data.vehicle_id || '---') + '</div></div>' +
12055:             '</div>';
12056:             html += '<div class="mb-3 p-3 bg-orange-50 border border-orange-100 rounded-xl text-sm font-bold text-orange-800">هذه الشاشة للعرض والتأكد من الحمولة قبل التفريغ. تنفيذ التفريغ نفسه يتم عبر <code>unload-runsheet</code> ولا يتم هنا إجراء أي تعديل مخزني.</div>';
12057:             html += '<div class="overflow-auto max-h-[55vh]"><table class="w-full border text-sm"><thead class="bg-gray-100 sticky top-0"><tr>' +
12058:                 '<th class="p-2 border">الكود</th><th class="p-2 border">الصنف</th><th class="p-2 border text-center">الوحدة</th><th class="p-2 border text-center">محمّل</th><th class="p-2 border text-center">مسلّم</th><th class="p-2 border text-center">مرفوض</th><th class="p-2 border text-center">مرتجع</th><th class="p-2 border text-center">المتبقي</th>' +
12059:                 '</tr></thead><tbody>';
12060: 
12061:             for (var i = 0; i < details.length; i++) {
12062:                 var d = details[i];
12063:                 var loaded = Number(d.qty_loaded) || 0;
12064:                 var delivered = Number(d.qty_delivered) || 0;
12065:                 var refused = Number(d.qty_refused) || 0;
12066:                 var returned = Number(d.qty_returned) || 0;
12067:                 var remaining = Math.max(0, loaded - delivered - refused - returned);
12068:                 loadedTotal += loaded;
12069:                 remainingTotal += remaining;
12070: 
12071:                 html += '<tr class="border-b">' +
12072:                     '<td class="p-2 border">' + esc(d.item_code || '') + '</td>' +
12073:                     '<td class="p-2 border font-semibold">' + esc(d.item_name || '') + '</td>' +
12074:                     '<td class="p-2 border text-center">' + esc(d.unit || 'حبة') + '</td>' +
12075:                     '<td class="p-2 border text-center font-bold text-orange-700">' + loaded + '</td>' +
12076:                     '<td class="p-2 border text-center">' + delivered + '</td>' +
12077:                     '<td class="p-2 border text-center">' + refused + '</td>' +
12078:                     '<td class="p-2 border text-center">' + returned + '</td>' +
12079:                     '<td class="p-2 border text-center font-black ' + (remaining > 0 ? 'text-red-600' : 'text-emerald-600') + '">' + remaining + '</td>' +
12080:                 '</tr>';
12081:             }
12082: 
12083:             html += '</tbody></table></div>';
12084:             html += '<div class="mt-4 grid grid-cols-2 gap-3">' +
12085:                 '<div class="bg-orange-50 rounded-xl p-3 text-center"><div class="text-xs text-slate-500">إجمالي المحمّل</div><div class="text-xl font-black text-orange-700">' + loadedTotal + '</div></div>' +
12086:                 '<div class="bg-slate-50 rounded-xl p-3 text-center"><div class="text-xs text-slate-500">المتبقي قبل التفريغ</div><div class="text-xl font-black">' + remainingTotal + '</div></div>' +
12087:             '</div></div>';
12088: 
12089:             hideLoader();
12090:             Swal.fire({
12091:                 title: 'تفاصيل التفريغ: ' + esc(code),
12092:                 html: html,
12093:                 width: '1100px',
12094:                 showCloseButton: true,
12095:                 showConfirmButton: false
12096:             });
12097:         } catch (e) {
12098:             hideLoader();
12099:             showToast(e.message || 'فشل تحميل تفاصيل التفريغ', 'error');
12100:         }
12101:     }
12102:     // ==================== COUNT (الجرد) & SETTLEMENT (إغلاق اليومية) ====================
12103:     async function loadVehicleCount() {
12104:         var c = byId('rw-page-container'); if (!c) return;
12105:         safeText(byId('rw-header-title'), 'جرد سيارة');
12106:         safeHTML(c, `<div class="p-4">
12107:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 grid grid-cols-1 md:grid-cols-3 gap-4">
12108:                 <div>
12109:                     <label class="text-xs font-bold block mb-1">المندوب</label>
12110:                     <input type="text" id="vc-driver-search" oninput="RW_Warehouse._searchDriver(this.value)" autocomplete="off" placeholder="ابحث باسم أو بريد المندوب..." class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 focus:border-blue-500 outline-none">
12111:                     <div id="vc-driver-results" class="absolute z-50 bg-white shadow-xl rounded-xl max-h-48 overflow-y-auto hidden border mt-1" style="width:calc(33%-2rem);"></div>
12112:                 </div>
12113:                 <div>
12114:                     <label class="text-xs font-bold block mb-1">الرانشيت (اختياري)</label>
12115:                     <select id="vc-runsheet-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold"><option value="">-- اختر --</option></select>
12116:                 </div>
12117:                 <div>
12118:                     <label class="text-xs font-bold block mb-1">ملاحظات</label>
12119:                     <input id="vc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات...">
12120:                 </div>
12121:             </div>
12122:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12123:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12124:                 <div class="relative">
12125:                     <input type="text" id="vc-item-search" oninput="RW_Warehouse._searchInvItem('vc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg">
12126:                     <button onclick="RW_Warehouse._startBarcodeScanner('vc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button>
12127:                 </div>
12128:                 <div id="vc-item-results" class="absolute z-50 left-0 right-0 mt-1 bg-white shadow-xl rounded-xl max-h-60 overflow-y-auto hidden border"></div>
12129:             </div>
12130:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;">
12131:                 <table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="vc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table>
12132:             </div>
12133:             <div class="mt-2">عدد الأصناف: <span id="vc-cart-count">0</span></div>
12134:             <div class="mt-4 flex justify-end gap-3">
12135:                 <button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('vc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button>
12136:                 <button onclick="RW_Warehouse._saveVehicleCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button>
12137:             </div>
12138:         </div>`);
12139:         
12140:         window._selectedDriver = null;
12141:         window._invCart = [];
12142:         _renderInvCart('vc');
12143:         
12144:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12145: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12146: var runsheetsRes = await supabase.from('runsheets')
12147:     .select('runsheet_code, driver_id')
12148:     .eq('company_id', companyId)
12149:     .in('status', ['Loaded', 'Delivering', 'Delivered', 'Returning']);
12150:         var sel = byId('vc-runsheet-select');
12151:         if (sel && runsheetsRes.data) {
12152:             for (var i = 0; i < runsheetsRes.data.length; i++) {
12153:                 var r = runsheetsRes.data[i];
12154:                 sel.innerHTML += '<option value="' + r.runsheet_code + '">' + r.runsheet_code + ' - ' + (r.driver_id || '') + '</option>';
12155:             }
12156:         }
12157:     }
12158: 
12159:     async function _searchDriver(query) {
12160:         var div = byId('vc-driver-results'); if (!div) return;
12161:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
12162:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12163: if (!companyId) { div.classList.add('hidden'); return; }
12164: var res = await supabase.from('users')
12165:     .select('email, name')
12166:     .eq('company_id', companyId)
12167:     .in('role', ['driver','سائق','مندوب'])
12168:     .ilike('name', '%' + query + '%');
12169:         var drivers = res.data || [];
12170:         var q = query.toLowerCase();
12171:         var filtered = drivers.filter(function(d) { return (d.name || '').toLowerCase().indexOf(q) !== -1 || (d.email || '').toLowerCase().indexOf(q) !== -1; });
12172:         if (filtered.length > 0) {
12173:             var html = '';
12174:             for (var i = 0; i < filtered.length; i++) {
12175:                 var d = filtered[i];
12176:                 html += '<div onclick="RW_Warehouse._selectDriver(\'' + d.email + '\', \'' + (d.name || '').replace(/'/g, "\\'") + '\')" class="p-3 hover:bg-blue-50 cursor-pointer border-b"><div class="font-bold">' + d.name + '</div><div class="text-xs text-slate-400">' + d.email + '</div></div>';
12177:             }
12178:             safeHTML(div, html); div.classList.remove('hidden');
12179:         } else { div.classList.add('hidden'); }
12180:     }
12181: 
12182:     function _selectDriver(email, name) {
12183:         window._selectedDriver = email;
12184:         byId('vc-driver-search').value = name + ' (' + email + ')';
12185:         byId('vc-driver-results').classList.add('hidden');
12186:     }
12187: 
12188:     async function _startBarcodeScanner(prefix) {
12189:         var input = byId(prefix + '-item-search');
12190:         if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || typeof window.BarcodeDetector === 'undefined') {
12191:             if (input) {
12192:                 input.focus();
12193:                 input.select();
12194:             }
12195:             showToast('مسح الباركود بالكاميرا غير مدعوم في هذا المتصفح. استخدم البحث أو قارئ الباركود المتصل.', 'warning');
12196:             return;
12197:         }
12198: 
12199:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12200:         if (!companyId) {
12201:             showToast('سياق الشركة غير محدد', 'error');
12202:             return;
12203:         }
12204: 
12205:         var stream = null;
12206:         var timer = null;
12207:         var stopped = false;
12208:         var videoId = 'rw-barcode-video-' + Date.now();
12209: 
12210:         try {
12211:             var formats = ['ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'qr_code'];
12212:             try {
12213:                 if (BarcodeDetector.getSupportedFormats) {
12214:                     var supported = await BarcodeDetector.getSupportedFormats();
12215:                     formats = formats.filter(function(f) { return supported.indexOf(f) !== -1; });
12216:                 }
12217:             } catch (_) {}
12218: 
12219:             var detector = formats.length ? new BarcodeDetector({ formats: formats }) : new BarcodeDetector();
12220: 
12221:             var result = await Swal.fire({
12222:                 title: 'مسح الباركود',
12223:                 html: '<div class="text-center"><div class="mb-3 text-sm text-slate-500">وجّه الكاميرا إلى باركود الصنف</div><div class="relative overflow-hidden rounded-2xl bg-black"><video id="' + videoId + '" autoplay muted playsinline style="width:100%;max-height:420px;object-fit:cover"></video><div class="absolute inset-6 border-2 border-emerald-400 rounded-xl pointer-events-none"></div></div></div>',
12224:                 width: '650px',
12225:                 showCancelButton: true,
12226:                 confirmButtonText: 'إغلاق',
12227:                 cancelButtonText: 'إلغاء',
12228:                 showConfirmButton: false,
12229:                 allowOutsideClick: false,
12230:                 didOpen: async function() {
12231:                     try {
12232:                         stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
12233:                         var video = document.getElementById(videoId);
12234:                         if (!video) throw new Error('تعذر تشغيل كاميرا المسح');
12235:                         video.srcObject = stream;
12236:                         await video.play();
12237: 
12238:                         var lastRaw = '';
12239:                         var lastToastAt = 0;
12240:                         var scan = async function() {
12241:                             if (stopped) return;
12242:                             try {
12243:                                 if (video.readyState >= 2) {
12244:                                     var codes = await detector.detect(video);
12245:                                     if (codes && codes.length) {
12246:                                         var raw = String(codes[0].rawValue || '').trim();
12247:                                         if (raw && raw !== lastRaw) {
12248:                                             lastRaw = raw;
12249:                                             var items = (RW_STATE.data && RW_STATE.data.items) || [];
12250:                                             var matched = null;
12251:                                             for (var i = 0; i < items.length; i++) {
12252:                                                 var item = items[i];
12253:                                                 if (String(item.barcode || '').trim() === raw || String(item.item_code || '').trim() === raw) {
12254:                                                     matched = item;
12255:                                                     break;
12256:                                                 }
12257:                                             }
12258: 
12259:                                             if (!matched) {
12260:                                                 var now = Date.now();
12261:                                                 if (now - lastToastAt > 1500) {
12262:                                                     showToast('لم يتم العثور على صنف لهذا الباركود: ' + raw, 'warning');
12263:                                                     lastToastAt = now;
12264:                                                 }
12265:                                             } else {
12266:                                                 _addToInvCart(prefix, matched.item_code);
12267:                                                 if (input) {
12268:                                                     input.value = '';
12269:                                                     input.focus();
12270:                                                 }
12271:                                                 Swal.close();
12272:                                                 return;
12273:                                             }
12274:                                         }
12275:                                     }
12276:                                 }
12277:                             } catch (e) {
12278:                                 console.warn('BarcodeDetector scan error', e);
12279:                             }
12280:                             timer = setTimeout(function() { lastRaw = ''; scan(); }, 350);
12281:                         };
12282:                         scan();
12283:                     } catch (e) {
12284:                         showToast('تعذر الوصول إلى الكاميرا: ' + (e.message || ''), 'error');
12285:                         if (input) {
12286:                             input.focus();
12287:                             input.select();
12288:                         }
12289:                         Swal.close();
12290:                     }
12291:                 },
12292:                 willClose: function() {
12293:                     stopped = true;
12294:                     if (timer) {
12295:                         clearTimeout(timer);
12296:                         timer = null;
12297:                     }
12298:                     if (stream) {
12299:                         var tracks = stream.getTracks ? stream.getTracks() : [];
12300:                         for (var i = 0; i < tracks.length; i++) tracks[i].stop();
12301:                         stream = null;
12302:                     }
12303:                 }
12304:             });
12305: 
12306:             return result;
12307:         } catch (e) {
12308:             stopped = true;
12309:             if (timer) clearTimeout(timer);
12310:             if (stream) {
12311:                 var tracks = stream.getTracks ? stream.getTracks() : [];
12312:                 for (var j = 0; j < tracks.length; j++) tracks[j].stop();
12313:             }
12314:             if (input) {
12315:                 input.focus();
12316:                 input.select();
12317:             }
12318:             showToast(e.message || 'فشل تشغيل قارئ الباركود', 'error');
12319:             return null;
12320:         }
12321:     }
12322: 
12323:     function _searchInvItem(prefix, query) {
12324:         var div = byId(prefix + '-item-results'); if (!div) return;
12325:         if (!query || query.trim().length < 1) { div.classList.add('hidden'); return; }
12326:         var items = RW_STATE.data.items || [];
12327:         var q = query.toLowerCase();
12328:         var filtered = items.filter(function(i) { return (i.name || '').toLowerCase().indexOf(q) !== -1 || (i.item_code || '').toLowerCase().indexOf(q) !== -1 || (i.barcode || '').toLowerCase().indexOf(q) !== -1; });
12329:         if (filtered.length > 0) {
12330:             var html = '';
12331:             for (var idx = 0; idx < Math.min(filtered.length, 30); idx++) {
12332:                 var item = filtered[idx];
12333:                 html += '<div onclick="RW_Warehouse._addToInvCart(\'' + prefix + '\', \'' + item.item_code + '\')" class="p-3 hover:bg-blue-50 cursor-pointer border-b flex items-center"><div><div class="font-bold">' + item.name + '</div><div class="text-xs text-slate-400">كود: ' + item.item_code + ' | رصيد: ' + (item.qty || 0) + '</div></div></div>';
12334:             }
12335:             safeHTML(div, html); div.classList.remove('hidden');
12336:         } else { safeHTML(div, '<div class="p-3 text-center text-gray-400">لا توجد نتائج</div>'); div.classList.remove('hidden'); }
12337:     }
12338: 
12339:     function _addToInvCart(prefix, itemCode) {
12340:         var items = RW_STATE.data.items || [], item = null;
12341:         for (var i = 0; i < items.length; i++) { if (items[i].item_code === itemCode) { item = items[i]; break; } }
12342:         if (!item) return;
12343:         var existing = null;
12344:         for (var j = 0; j < window._invCart.length; j++) { if (window._invCart[j].code === itemCode) { existing = window._invCart[j]; break; } }
12345:         if (existing) { existing.qty = (parseInt(existing.qty) || 0) + 1; } else { window._invCart.push({ code: item.item_code, name: item.name, unit: item.unit || 'حبة', qty: 1 }); }
12346:         byId(prefix + '-item-search').value = '';
12347:         byId(prefix + '-item-results').classList.add('hidden');
12348:         _renderInvCart(prefix);
12349:     }
12350: 
12351:     function _renderInvCart(prefix) {
12352:         var tbody = byId(prefix + '-cart-table'), countSpan = byId(prefix + '-cart-count');
12353:         if (!tbody) return;
12354:         if (window._invCart.length === 0) { safeHTML(tbody, '<tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr>'); if (countSpan) countSpan.innerText = '0'; return; }
12355:         var html = '';
12356:         for (var i = 0; i < window._invCart.length; i++) {
12357:             var it = window._invCart[i];
12358:             html += '<tr class="border-b hover:bg-slate-50"><td class="p-2"><div class="font-bold">' + it.name + '</div><div class="text-xs">' + it.code + '</div></td><td class="p-2 text-center">' + it.unit + '</td><td class="p-2 text-center"><input type="number" value="' + it.qty + '" onchange="RW_Warehouse._updateInvCartQty(' + i + ', this.value, \'' + prefix + '\')" class="w-20 p-1 border rounded text-center" min="0"></td><td class="p-2 text-center"><button onclick="RW_Warehouse._removeInvCartItem(' + i + ', \'' + prefix + '\')" class="text-red-500"><i class="fa-solid fa-trash"></i></button></td></tr>';
12359:         }
12360:         safeHTML(tbody, html);
12361:         if (countSpan) countSpan.innerText = String(window._invCart.length);
12362:     }
12363: 
12364:     function _updateInvCartQty(idx, val, prefix) {
12365:         var q = parseInt(val);
12366:         if (isNaN(q) || q <= 0) { window._invCart.splice(idx, 1); } else { window._invCart[idx].qty = q; }
12367:         _renderInvCart(prefix);
12368:     }
12369: 
12370:     function _removeInvCartItem(idx, prefix) { window._invCart.splice(idx, 1); _renderInvCart(prefix); }
12371: 
12372: async function _saveVehicleCount() {
12373:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12374:     var selectedDriver = window._selectedDriver || '';
12375:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12376:     if (!selectedDriver) { showToast('يجب اختيار مندوب', 'warning'); return; }
12377: 
12378:     var reference = (byId('vc-runsheet-select') ? byId('vc-runsheet-select').value : '') || '';
12379:     var notes = (byId('vc-notes') ? byId('vc-notes').value : '') || '';
12380:     if (notes) reference = reference ? reference + ' | ' + notes : notes;
12381: 
12382:     var selectedRunsheet = (byId('vc-runsheet-select') ? byId('vc-runsheet-select').value : '') || '';
12383:     var vehicleId = null;
12384: 
12385:     var userRes = await supabase.from('users')
12386:         .select('id')
12387:         .eq('company_id', companyId)
12388:         .eq('email', selectedDriver)
12389:         .maybeSingle();
12390:     if (userRes.error) { showToast(userRes.error.message, 'error'); return; }
12391:     var driverId = userRes.data ? userRes.data.id : null;
12392: 
12393:     if (selectedRunsheet) {
12394:         var rsRes = await supabase.from('runsheets')
12395:             .select('vehicle_id')
12396:             .eq('company_id', companyId)
12397:             .eq('runsheet_code', selectedRunsheet)
12398:             .maybeSingle();
12399:         if (rsRes.error) { showToast(rsRes.error.message, 'error'); return; }
12400:         vehicleId = rsRes.data ? rsRes.data.vehicle_id : null;
12401:     }
12402: 
12403:     if (!vehicleId && driverId) {
12404:         var vehicleRes = await supabase.from('vehicles')
12405:             .select('id')
12406:             .eq('company_id', companyId)
12407:             .eq('driver_id', driverId)
12408:             .limit(1)
12409:             .maybeSingle();
12410:         if (vehicleRes.error) { showToast(vehicleRes.error.message, 'error'); return; }
12411:         vehicleId = vehicleRes.data ? vehicleRes.data.id : null;
12412:     }
12413: 
12414:     if (!vehicleId) { showToast('لا توجد مركبة مرتبطة بهذا المندوب', 'warning'); return; }
12415:     await _saveInvCount('vehicle', vehicleId, reference || 'جرد سيارة');
12416: }
12417: 
12418:     async function _saveInvCount(type, entityId, reference) {
12419:         if (!window._invCart || window._invCart.length === 0) {
12420:             showToast('أضف أصنافاً', 'warning');
12421:             return;
12422:         }
12423:         if (!entityId) {
12424:             showToast('الكيان المستهدف للجرد غير محدد', 'warning');
12425:             return;
12426:         }
12427: 
12428:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12429:         if (!companyId) {
12430:             showToast('سياق الشركة غير محدد', 'error');
12431:             return;
12432:         }
12433: 
12434:         var items = [];
12435:         for (var i = 0; i < window._invCart.length; i++) {
12436:             var q = parseInt(window._invCart[i].qty, 10) || 0;
12437:             if (q < 0) {
12438:                 showToast('كمية الجرد لا يمكن أن تكون سالبة', 'warning');
12439:                 return;
12440:             }
12441:             items.push({
12442:                 itemCode: window._invCart[i].code,
12443:                 itemName: window._invCart[i].name,
12444:                 unit: window._invCart[i].unit,
12445:                 qty: q,
12446:                 unitPrice: 0,
12447:                 notes: ''
12448:             });
12449:         }
12450: 
12451:         var prefix = type === 'vehicle' ? 'vc' : (type === 'branch' ? 'bc' : 'gc');
12452:         showLoader('جاري حفظ الجرد...');
12453:         try {
12454:             var ses = await supabase.auth.getSession();
12455:             var token = ses.data.session ? ses.data.session.access_token : null;
12456:             if (!token) throw new Error('انتهت الجلسة. يرجى إعادة تسجيل الدخول.');
12457: 
12458:             var res = await fetch(RW_SUPABASE_URL + '/functions/v1/save-inventory-count', {
12459:                 method: 'POST',
12460:                 headers: {
12461:                     'Content-Type': 'application/json',
12462:                     'Authorization': 'Bearer ' + token
12463:                 },
12464:                 body: JSON.stringify({
12465:                     type: type,
12466:                     entityId: entityId,
12467:                     reference: reference,
12468:                     items: items
12469:                 })
12470:             });
12471: 
12472:             var json = await res.json().catch(function() { return {}; });
12473:             if (!res.ok || !json || !json.success) {
12474:                 throw new Error((json && (json.msg || json.error)) || 'فشل حفظ الجرد');
12475:             }
12476: 
12477:             hideLoader();
12478:             window._invCart = [];
12479:             _renderInvCart(prefix);
12480:             showToast(json.msg || ('تم حفظ الجرد ' + (json.count_id || '')), 'success');
12481:         } catch (e) {
12482:             hideLoader();
12483:             showToast(e.message || 'فشل الاتصال', 'error');
12484:         }
12485:     }
12486: 
12487:     async function loadBranchCount() {
12488:         var c = byId('rw-page-container'); if (!c) return;
12489:         safeText(byId('rw-header-title'), 'جرد فرع');
12490:         var branches = RW_STATE.data.branches || [];
12491:         safeHTML(c, `<div class="p-4">
12492:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 grid grid-cols-1 md:grid-cols-3 gap-4">
12493:                 <div><label class="text-xs font-bold block mb-1">الفرع</label><select id="bc-branch-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold"><option value="">-- اختر --</option>${branches.map(b => '<option value="' + (b.id || b.branch_code || '') + '">' + (b.name || b.branch_name || '') + '</option>').join('')}</select></div>
12494:                 <div><label class="text-xs font-bold block mb-1">القسم / الرف</label><input id="bc-section" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="مثلاً: رف A-1"></div>
12495:                 <div><label class="text-xs font-bold block mb-1">ملاحظات</label><input id="bc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات..."></div>
12496:             </div>
12497:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12498:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12499: <div class="relative"><input type="text" id="bc-item-search" oninput="RW_Warehouse._searchInvItem('bc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg"><button onclick="RW_Warehouse._startBarcodeScanner('bc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button></div>
12500:             </div>
12501:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="bc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table></div>
12502:             <div class="mt-2">عدد الأصناف: <span id="bc-cart-count">0</span></div>
12503:             <div class="mt-4 flex justify-end gap-3"><button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('bc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button><button onclick="RW_Warehouse._saveBranchCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button></div>
12504:         </div>`);
12505:         window._invCart = []; _renderInvCart('bc');
12506:     }
12507: 
12508:     async function _saveBranchCount() {
12509:         var entityId = (byId('bc-branch-select') ? byId('bc-branch-select').value : '') || '';
12510:         if (!entityId) { showToast('يجب اختيار فرع', 'warning'); return; }
12511:         var section = (byId('bc-section') ? byId('bc-section').value : '') || '';
12512:         var notes = (byId('bc-notes') ? byId('bc-notes').value : '') || '';
12513:         var reference = section ? ('قسم: ' + section) : '';
12514:         if (notes) reference = reference ? reference + ' | ' + notes : notes;
12515:         await _saveInvCount('branch', entityId, reference || 'جرد فرع');
12516:     }
12517: 
12518:     async function loadGeneralCount() {
12519:         var c = byId('rw-page-container'); if (!c) return;
12520:         safeText(byId('rw-header-title'), 'جرد عام');
12521:         safeHTML(c, `<div class="p-4">
12522:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4"><input id="gc-notes" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200" placeholder="ملاحظات الجرد العام..."></div>
12523:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4 relative">
12524:                 <label class="text-xs font-bold block mb-2">البحث عن صنف</label>
12525: <div class="relative"><input type="text" id="gc-item-search" oninput="RW_Warehouse._searchInvItem('gc', this.value)" autocomplete="off" placeholder="امسح الباركود أو ابحث..." class="w-full p-4 bg-slate-50 rounded-xl border-2 focus:border-emerald-500 outline-none font-bold text-lg"><button onclick="RW_Warehouse._startBarcodeScanner('gc')" class="absolute left-2 top-2 bg-emerald-600 text-white p-3 rounded-xl"><i class="fa-solid fa-camera"></i></button></div>
12526:             </div>
12527:             <div class="bg-white rounded-xl shadow-sm overflow-auto" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية</th><th class="p-2 text-center">حذف</th></tr></thead><tbody id="gc-cart-table"><tr><td colspan="4" class="p-6 text-center">أضف أصنافاً</td></tr></tbody></table></div>
12528:             <div class="mt-2">عدد الأصناف: <span id="gc-cart-count">0</span></div>
12529:             <div class="mt-4 flex justify-end gap-3"><button onclick="window._invCart=[]; RW_Warehouse._renderInvCart('gc')" class="bg-gray-500 text-white px-4 py-2 rounded-xl font-bold text-sm">مسح الكل</button><button onclick="RW_Warehouse._saveGeneralCount()" class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-black text-lg shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ الجرد</button></div>
12530:         </div>`);
12531:         window._invCart = []; _renderInvCart('gc');
12532:     }
12533: 
12534: async function _saveGeneralCount() {
12535:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12536:     var notes = (byId('gc-notes') ? byId('gc-notes').value : '') || '';
12537:     if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12538: 
12539:     var settingsRes = await supabase.from('app_settings')
12540:         .select('main_branch_id')
12541:         .eq('company_id', companyId)
12542:         .order('created_at', { ascending: true })
12543:         .limit(1)
12544:         .maybeSingle();
12545:     if (settingsRes.error) { showToast(settingsRes.error.message, 'error'); return; }
12546: 
12547:     var mainBranchId = settingsRes.data ? settingsRes.data.main_branch_id : null;
12548:     if (!mainBranchId) { showToast('الفرع الرئيسي غير محدد', 'error'); return; }
12549: 
12550:     await _saveInvCount('general', mainBranchId, 'جرد عام' + (notes ? ' | ' + notes : ''));
12551: }
12552: 
12553:     // ==================== SETTLEMENT (إغلاق اليومية) ====================
12554:     async function loadSettlement() {
12555:         var c = byId('rw-page-container'); if (!c) return;
12556:         safeText(byId('rw-header-title'), 'إغلاق اليومية');
12557:         safeHTML(c, `<div class="p-4">
12558:             <div class="bg-white rounded-2xl shadow-sm border p-4 mb-4">
12559:                 <label class="text-xs font-bold block mb-2">اختيار الرانشيت</label>
12560:                 <select id="settlement-rs-select" class="w-full p-3 bg-slate-50 rounded-xl border-2 border-slate-200 font-bold" onchange="RW_Warehouse._onSettlementRsChange()"><option value="">-- اختر رانشيتاً --</option></select>
12561:                 <div id="settlement-rs-info" class="mt-3 text-sm text-slate-500"></div>
12562:             </div>
12563:             <div id="settlement-details-container" class="hidden">
12564:                 <div class="bg-white rounded-xl shadow-sm overflow-auto mb-4" style="max-height:50vh;"><table class="w-full"><thead class="bg-slate-800 text-white sticky top-0"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">محمّلة</th><th class="p-2 text-center">مسلّمة</th><th class="p-2 text-center">مرتجعة</th><th class="p-2 text-center">مجرودة</th><th class="p-2 text-center">العجز</th><th class="p-2 text-center">قيمة العجز</th></tr></thead><tbody id="settlement-items-body"><tr><td colspan="7" class="p-6 text-center">اختر رانشيتاً</td></tr></tbody></table></div>
12565:                 <div class="flex justify-end gap-2"><button onclick="RW_Warehouse._saveSettlement()" class="bg-emerald-600 text-white px-8 py-3 rounded-2xl font-black shadow-lg"><i class="fa-solid fa-check ml-2"></i> حفظ التسوية وترحيل العجز</button></div>
12566:             </div>
12567:         </div>`);
12568:         
12569:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12570: if (!companyId) { showToast('سياق الشركة غير محدد', 'error'); return; }
12571: var runsheetsRes = await supabase.from('runsheets')
12572:     .select('runsheet_code, driver_id')
12573:     .eq('company_id', companyId)
12574:     .in('status', ['Delivered', 'Returned']);
12575:         var sel = byId('settlement-rs-select');
12576:         if (sel && runsheetsRes.data) {
12577:             for (var i = 0; i < runsheetsRes.data.length; i++) {
12578:                 sel.innerHTML += '<option value="' + runsheetsRes.data[i].runsheet_code + '">' + runsheetsRes.data[i].runsheet_code + ' - ' + (runsheetsRes.data[i].driver_id || '') + '</option>';
12579:             }
12580:         }
12581:     }
12582: 
12583:     async function _onSettlementRsChange() {
12584:         var rsCode = byId('settlement-rs-select')?.value || '';
12585:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12586:         var detailsContainer = byId('settlement-details-container');
12587: 
12588:         if (!rsCode) {
12589:             if (detailsContainer) detailsContainer.classList.add('hidden');
12590:             window._settlementData = null;
12591:             return;
12592:         }
12593:         if (!companyId) {
12594:             showToast('سياق الشركة غير محدد', 'error');
12595:             return;
12596:         }
12597: 
12598:         showLoader('جاري تحميل بيانات التسوية...');
12599:         try {
12600:             var rsRes = await supabase.from('runsheets')
12601:                 .select('id,runsheet_code,status,driver_id,vehicle_id,run_date')
12602:                 .eq('company_id', companyId)
12603:                 .eq('runsheet_code', rsCode)
12604:                 .maybeSingle();
12605:             if (rsRes.error) throw rsRes.error;
12606:             if (!rsRes.data) throw new Error('الرانشيت غير موجود في الشركة الحالية');
12607:             if (['Delivered', 'Returned'].indexOf(rsRes.data.status) === -1) {
12608:                 throw new Error('التسوية متاحة فقط للرانشيتات التي وصلت إلى Delivered أو Returned');
12609:             }
12610: 
12611:             var detailsRes = await supabase.from('run_sheet_details')
12612:                 .select('item_code,item_name,unit,qty_loaded,qty_delivered,qty_returned,unit_price')
12613:                 .eq('runsheet_id', rsRes.data.id)
12614:                 .order('item_code');
12615:             if (detailsRes.error) throw detailsRes.error;
12616:             var details = detailsRes.data || [];
12617: 
12618:             var countedByItem = {};
12619:             if (rsRes.data.vehicle_id) {
12620:                 var countRes = await supabase.from('inventory_counts')
12621:                     .select('id')
12622:                     .eq('company_id', companyId)
12623:                     .eq('type', 'vehicle')
12624:                     .eq('entity_id', rsRes.data.vehicle_id)
12625:                     .order('created_at', { ascending: false })
12626:                     .limit(1)
12627:                     .maybeSingle();
12628:                 if (countRes.error) throw countRes.error;
12629:                 if (countRes.data) {
12630:                     var countDetailsRes = await supabase.from('inventory_count_details')
12631:                         .select('item_code,counted_qty')
12632:                         .eq('count_id', countRes.data.id);
12633:                     if (countDetailsRes.error) throw countDetailsRes.error;
12634:                     var countDetails = countDetailsRes.data || [];
12635:                     for (var ci = 0; ci < countDetails.length; ci++) {
12636:                         countedByItem[countDetails[ci].item_code] = Number(countDetails[ci].counted_qty) || 0;
12637:                     }
12638:                 }
12639:             }
12640: 
12641:             var items = [];
12642:             var totalShortage = 0;
12643:             var totalShortageValue = 0;
12644:             var html = '';
12645: 
12646:             for (var i = 0; i < details.length; i++) {
12647:                 var d = details[i];
12648:                 var loaded = Number(d.qty_loaded) || 0;
12649:                 var delivered = Number(d.qty_delivered) || 0;
12650:                 var returned = Number(d.qty_returned) || 0;
12651:                 var counted = Object.prototype.hasOwnProperty.call(countedByItem, d.item_code) ? countedByItem[d.item_code] : null;
12652:                 var shortage = Math.max(0, loaded - delivered - returned);
12653:                 var shortageValue = shortage * (Number(d.unit_price) || 0);
12654: 
12655:                 totalShortage += shortage;
12656:                 totalShortageValue += shortageValue;
12657:                 items.push({
12658:                     itemCode: d.item_code,
12659:                     itemName: d.item_name,
12660:                     unit: d.unit,
12661:                     loadedQty: loaded,
12662:                     deliveredQty: delivered,
12663:                     returnedQty: returned,
12664:                     countedQty: counted,
12665:                     shortage: shortage,
12666:                     unitPrice: Number(d.unit_price) || 0,
12667:                     shortageValue: shortageValue
12668:                 });
12669: 
12670:                 html += '<tr class="border-b">' +
12671:                     '<td class="p-2">' + esc(d.item_name || '') + '<div class="text-xs text-gray-400">' + esc(d.item_code || '') + '</div></td>' +
12672:                     '<td class="p-2 text-center">' + loaded + '</td>' +
12673:                     '<td class="p-2 text-center">' + delivered + '</td>' +
12674:                     '<td class="p-2 text-center">' + returned + '</td>' +
12675:                     '<td class="p-2 text-center font-bold">' + (counted == null ? '—' : counted) + '</td>' +
12676:                     '<td class="p-2 text-center font-black ' + (shortage > 0 ? 'text-red-600' : 'text-emerald-600') + '">' + shortage + '</td>' +
12677:                     '<td class="p-2 text-center">' + Math.abs(shortageValue).toLocaleString() + ' EGP</td>' +
12678:                 '</tr>';
12679:             }
12680: 
12681:             safeHTML(byId('settlement-items-body'), html || '<tr><td colspan="7" class="p-6 text-center">لا توجد بيانات</td></tr>');
12682:             safeHTML(byId('settlement-rs-info'),
12683:                 '<strong>المندوب:</strong> ' + esc(rsRes.data.driver_id || '---') +
12684:                 ' | <strong>السيارة:</strong> ' + esc(rsRes.data.vehicle_id || '---') +
12685:                 ' | <strong>التاريخ:</strong> ' + esc(rsRes.data.run_date || '---') +
12686:                 '<div class="mt-2 text-xs text-slate-500">ملاحظة: التسوية المحاسبية تعتمد على المحمّل − المسلّم − المرتجع كما يطبّقها محرك التسوية في Production. كمية الجرد المعروضة مرجعية للتحقق فقط ولا تُخصم من نتيجة العجز آليًا.</div>');
12687: 
12688:             if (detailsContainer) detailsContainer.classList.remove('hidden');
12689:             window._settlementData = {
12690:                 rs: rsRes.data,
12691:                 items: items,
12692:                 totalShortage: totalShortage,
12693:                 totalShortageValue: totalShortageValue
12694:             };
12695:             hideLoader();
12696:         } catch (e) {
12697:             hideLoader();
12698:             window._settlementData = null;
12699:             if (detailsContainer) detailsContainer.classList.add('hidden');
12700:             showToast('فشل تحميل بيانات التسوية: ' + (e.message || ''), 'error');
12701:         }
12702:     }
12703: 
12704:     function _saveSettlement() {
12705:         var data = window._settlementData;
12706:         if (!data) {
12707:             showToast('اختر رانشيتاً أولاً', 'warning');
12708:             return;
12709:         }
12710:         var rs = data.rs;
12711:         if (!rs || !rs.runsheet_code) {
12712:             showToast('بيانات الرانشيت غير مكتملة', 'error');
12713:             return;
12714:         }
12715: 
12716:         window._settlementPendingOps = window._settlementPendingOps || {};
12717:         var operationId = window._settlementPendingOps[rs.runsheet_code];
12718:         if (!operationId) {
12719:             operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('SETTLE-' + Date.now() + '-' + Math.random().toString(36).slice(2));
12720:             window._settlementPendingOps[rs.runsheet_code] = operationId;
12721:         }
12722: 
12723:         showLoader('جاري حفظ التسوية...');
12724:         supabase.auth.getSession().then(function(ses) {
12725:             var token = (ses && ses.data && ses.data.session) ? ses.data.session.access_token : null;
12726:             if (!token) throw new Error('انتهت الجلسة');
12727: 
12728:             return fetch(RW_SUPABASE_URL + '/functions/v1/save-daily-settlement', {
12729:                 method: 'POST',
12730:                 headers: {
12731:                     'Content-Type': 'application/json',
12732:                     'Authorization': 'Bearer ' + token,
12733:                     'Idempotency-Key': operationId
12734:                 },
12735:                 body: JSON.stringify({
12736:                     runsheet_code: rs.runsheet_code,
12737:                     notes: 'تسوية يومية للرانشيت ' + rs.runsheet_code,
12738:                     operation_id: operationId
12739:                 })
12740:             });
12741:         }).then(function(res) {
12742:             return res.json().catch(function() { return {}; }).then(function(json) {
12743:                 if (!res.ok || !json || !json.success) {
12744:                     throw new Error((json && (json.msg || json.error)) || 'فشل حفظ التسوية');
12745:                 }
12746:                 return json;
12747:             });
12748:         }).then(function(json) {
12749:             hideLoader();
12750:             delete window._settlementPendingOps[rs.runsheet_code];
12751:             showToast(json.duplicate ? 'تم استرجاع نتيجة التسوية السابقة' : ('تم حفظ التسوية: ' + (json.settlement_code || rs.runsheet_code)), 'success');
12752:             var container = byId('settlement-details-container');
12753:             if (container) container.classList.add('hidden');
12754:             var sel = byId('settlement-rs-select');
12755:             if (sel) sel.value = '';
12756:             window._settlementData = null;
12757:         }).catch(function(e) {
12758:             hideLoader();
12759:             showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس رقم العملية', 'error');
12760:         });
12761:     }
12762: function _openPickingModal(rsCode) {
12763:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12764:     showLoader('جاري تحميل بيانات التحضير...');
12765: 
12766:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12767:     if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12768: 
12769:     window._pickingPendingOps = window._pickingPendingOps || {};
12770: 
12771:     supabase.from('runsheets')
12772:         .select('id')
12773:         .eq('company_id', companyId)
12774:         .eq('runsheet_code', rsCode)
12775:         .maybeSingle()
12776:         .then(function(rsRes) {
12777:             if (rsRes.error) throw rsRes.error;
12778:             if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
12779:             var runsheetUuid = rsRes.data.id;
12780: 
12781:             return supabase.from('run_sheet_details')
12782:                 .select('*')
12783:                 .eq('runsheet_id', runsheetUuid)
12784:                 .order('item_code')
12785:                 .then(function(itemsRes) {
12786:                     if (itemsRes.error) throw itemsRes.error;
12787:                     var items = itemsRes.data || [];
12788:                     if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
12789: 
12790:                     showLoader('جاري بدء التحضير...');
12791:                     return supabase.auth.getSession().then(function(ses) {
12792:                         var token = ses.data.session ? ses.data.session.access_token : null;
12793:                         if (!token) throw new Error('انتهت الجلسة');
12794:                         return fetch(RW_SUPABASE_URL + '/functions/v1/start-picking', {
12795:                             method: 'POST',
12796:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
12797:                             body: JSON.stringify({ runsheet_code: rsCode })
12798:                         });
12799:                     }).then(function(res) { return res.json().then(function(json) { if (!res.ok || !json.success) throw new Error(json.msg || json.error || 'فشل بدء التحضير'); return json; }); }).then(function(startJson) {
12800:                         hideLoader();
12801: 
12802:                         var operationId = window._pickingPendingOps[rsCode];
12803:                         if (!operationId) {
12804:                             operationId = (window.crypto && window.crypto.randomUUID) ? window.crypto.randomUUID() : ('PICK-' + Date.now() + '-' + Math.random().toString(36).slice(2));
12805:                             window._pickingPendingOps[rsCode] = operationId;
12806:                         }
12807: 
12808:                         var html = '<div class="text-right" dir="rtl"><div class="max-h-[420px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
12809:                             '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المطلوبة</th><th class="p-2 text-center">الكمية المحضرة</th></tr></thead><tbody>';
12810:                         for (var i = 0; i < items.length; i++) {
12811:                             var it = items[i];
12812:                             var ordered = Number(it.qty_ordered) || 0;
12813:                             var picked = Number(it.qty_picked) || 0;
12814:                             html += '<tr><td class="p-2 border"><p class="font-bold">' + esc(it.item_name || '') + '</p><p class="text-xs">' + esc(it.item_code || '') + '</p></td>' +
12815:                                 '<td class="p-2 border text-center">' + esc(it.unit || 'حبة') + '</td>' +
12816:                                 '<td class="p-2 border text-center font-bold">' + ordered + '</td>' +
12817:                                 '<td class="p-2 border text-center"><input type="number" id="picked_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="0.01" min="0" max="' + ordered + '" value="' + (picked || ordered) + '"></td></tr>';
12818:                         }
12819:                         html += '</tbody></table></div></div>';
12820: 
12821:                         Swal.fire({
12822:                             title: 'تحضير الرانشيت: ' + esc(rsCode),
12823:                             html: html,
12824:                             width: '850px',
12825:                             showCancelButton: true,
12826:                             confirmButtonText: 'إنهاء التحضير',
12827:                             cancelButtonText: 'إلغاء',
12828:                             preConfirm: function() {
12829:                                 var itemsData = [];
12830:                                 var hasQty = false;
12831:                                 for (var j = 0; j < items.length; j++) {
12832:                                     var orderedQty = Number(items[j].qty_ordered) || 0;
12833:                                     var qty = parseFloat((document.getElementById('picked_qty_' + j) || {}).value);
12834:                                     if (!Number.isFinite(qty)) qty = 0;
12835:                                     if (qty < 0 || qty > orderedQty) {
12836:                                         Swal.showValidationMessage('الكمية المحضرة يجب أن تكون بين 0 والكمية المطلوبة للصنف: ' + (items[j].item_code || ''));
12837:                                         return false;
12838:                                     }
12839:                                     if (qty > 0) hasQty = true;
12840:                                     itemsData.push({ itemCode: items[j].item_code, pickedQty: qty, notes: '' });
12841:                                 }
12842:                                 if (!hasQty) { Swal.showValidationMessage('يجب تحضير كمية واحدة على الأقل'); return false; }
12843:                                 return itemsData;
12844:                             }
12845:                         }).then(function(result) {
12846:                             if (!result.isConfirmed) {
12847:                                 delete window._pickingPendingOps[rsCode];
12848:                                 return;
12849:                             }
12850:                             showLoader('جاري إنهاء التحضير...');
12851:                             return supabase.auth.getSession().then(function(ses2) {
12852:                                 var token2 = ses2.data.session ? ses2.data.session.access_token : null;
12853:                                 if (!token2) throw new Error('انتهت الجلسة');
12854:                                 return fetch(RW_SUPABASE_URL + '/functions/v1/complete-picking', {
12855:                                     method: 'POST',
12856:                                     headers: {
12857:                                         'Content-Type': 'application/json',
12858:                                         Authorization: 'Bearer ' + token2,
12859:                                         'Idempotency-Key': operationId
12860:                                     },
12861:                                     body: JSON.stringify({ runsheet_code: rsCode, items: result.value, operation_id: operationId })
12862:                                 });
12863:                             }).then(function(res) {
12864:                                 return res.json().catch(function() { return {}; }).then(function(compJson) {
12865:                                     if (!res.ok || !compJson.success) throw new Error(compJson.msg || compJson.error || 'فشل إنهاء التحضير');
12866:                                     return compJson;
12867:                                 });
12868:                             }).then(function(compJson) {
12869:                                 hideLoader();
12870:                                 delete window._pickingPendingOps[rsCode];
12871:                                 showToast(compJson.duplicate ? 'تم استرجاع نتيجة التحضير السابقة' : 'تم إنهاء التحضير بنجاح', 'success');
12872:                                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
12873:                             }).catch(function(e) {
12874:                                 hideLoader();
12875:                                 showToast(e.message || 'فشل الاتصال؛ يمكن إعادة المحاولة بنفس العملية', 'error');
12876:                             });
12877:                         });
12878:                     });
12879:                 });
12880:         })
12881:         .catch(function(e) {
12882:             hideLoader();
12883:             showToast(e.message || 'فشل تحميل بيانات التحضير', 'error');
12884:         });
12885: }
12886: function _openLoadingModal(rsCode) {
12887:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12888:     showLoader('جاري تحميل بيانات التحميل...');
12889:     
12890:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12891: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12892: supabase.from('runsheets')
12893:     .select('id')
12894:     .eq('company_id', companyId)
12895:     .eq('runsheet_code', rsCode)
12896:     .maybeSingle()
12897:     .then(function(rsRes) {
12898:         if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
12899:         var runsheetUuid = rsRes.data.id;
12900:         
12901:         supabase.from('run_sheet_details').select('*').eq('runsheet_id', runsheetUuid).then(function(itemsRes) {
12902:             var items = itemsRes.data || [];
12903:             if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
12904:             
12905:             showLoader('جاري بدء التحميل...');
12906:             supabase.auth.getSession().then(function(ses) {
12907:                 var t = ses.data.session ? ses.data.session.access_token : null;
12908:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-loading', {
12909:                     method: 'POST',
12910:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
12911:                     body: JSON.stringify({ runsheet_code: rsCode })
12912:                 });
12913:             }).then(function(res) { return res.json(); }).then(function(startJson) {
12914:                 hideLoader();
12915:                 if (!startJson.success) { showToast(startJson.msg || 'فشل بدء التحميل', 'error'); return; }
12916:                 
12917:                 var html = '<div class="text-right" dir="rtl"><div class="max-h-[400px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
12918:                     '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المحضّرة</th><th class="p-2 text-center">الكمية المحمّلة</th></tr></thead><tbody>';
12919:                 for (var i = 0; i < items.length; i++) {
12920:                     var it = items[i];
12921:                     var picked = it.qty_picked || 0;
12922:                     html += '<tr><td class="p-2 border"><p class="font-bold">' + (it.item_name || '') + '</p><p class="text-xs">' + (it.item_code || '') + '</p></td>' +
12923:                         '<td class="p-2 border text-center">' + (it.unit || 'حبة') + '</td>' +
12924:                         '<td class="p-2 border text-center font-bold">' + picked + '</td>' +
12925:                         '<td class="p-2 border text-center"><input type="number" id="loaded_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="1" min="0" max="' + picked + '" value="' + picked + '"></td></tr>';
12926:                 }
12927:                 html += '</tbody></table></div></div>';
12928:                 
12929:                 Swal.fire({
12930:                     title: 'تحميل الرانشيت: ' + rsCode,
12931:                     html: html,
12932:                     width: '800px',
12933:                     showCancelButton: true,
12934:                     confirmButtonText: 'إنهاء التحميل',
12935:                     cancelButtonText: 'إلغاء',
12936:                     preConfirm: function() {
12937:                         var itemsData = [];
12938:                         var allZero = true;
12939:                         for (var j = 0; j < items.length; j++) {
12940:                             var qty = parseFloat(document.getElementById('loaded_qty_' + j).value) || 0;
12941:                             if (qty > 0) allZero = false;
12942:                             itemsData.push({ itemCode: items[j].item_code, loadedQty: qty, notes: '' });
12943:                         }
12944:                         if (allZero) { Swal.showValidationMessage('يجب تحميل كمية واحدة على الأقل'); return false; }
12945:                         return itemsData;
12946:                     }
12947:                 }).then(function(result) {
12948:                     if (!result.isConfirmed) return;
12949:                     showLoader('جاري إنهاء التحميل...');
12950:                     supabase.auth.getSession().then(function(ses2) {
12951:                         var t2 = ses2.data.session ? ses2.data.session.access_token : null;
12952:                         return fetch(RW_SUPABASE_URL + '/functions/v1/complete-loading', {
12953:                             method: 'POST',
12954:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
12955:                             body: JSON.stringify({ runsheet_code: rsCode, items: result.value })
12956:                         });
12957:                     }).then(function(res) { return res.json(); }).then(function(compJson) {
12958:                         hideLoader();
12959:                         if (compJson.success) {
12960:                             showToast('تم إنهاء التحميل بنجاح', 'success');
12961:                             if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
12962:                         } else {
12963:                             showToast(compJson.msg || 'فشل إنهاء التحميل', 'error');
12964:                         }
12965:                     }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
12966:                 });
12967:             }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
12968:         }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
12969:     }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
12970: }function _openDeliveryModal(rsCode) {
12971:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
12972:     showLoader('جاري تحميل بيانات التوصيل...');
12973: 
12974:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
12975:     if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
12976: 
12977:     supabase.from('runsheets')
12978:         .select('id,status')
12979:         .eq('company_id', companyId)
12980:         .eq('runsheet_code', rsCode)
12981:         .maybeSingle()
12982:         .then(function(rsRes) {
12983:             if (rsRes.error) throw rsRes.error;
12984:             var rs = rsRes.data;
12985:             if (!rs) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return null; }
12986: 
12987:             showLoader('جاري بدء التوصيل...');
12988:             return supabase.auth.getSession().then(function(ses) {
12989:                 var t = ses.data.session ? ses.data.session.access_token : null;
12990:                 if (!t) throw new Error('انتهت الجلسة');
12991:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-delivery', {
12992:                     method: 'POST',
12993:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
12994:                     body: JSON.stringify({ runsheet_code: rsCode })
12995:                 });
12996:             }).then(function(res) {
12997:                 return res.json();
12998:             }).then(function(startJson) {
12999:                 if (!startJson.success) { hideLoader(); showToast(startJson.msg || 'فشل بدء التوصيل', 'error'); return null; }
13000: 
13001:                 return supabase.from('orders')
13002:                     .select('id,order_code,customer_name')
13003:                     .eq('company_id', companyId)
13004:                     .eq('runsheet_id', rs.id)
13005:                     .order('created_at', { ascending: true })
13006:                     .then(function(ordersRes) {
13007:                         if (ordersRes.error) throw ordersRes.error;
13008:                         var orders = ordersRes.data || [];
13009:                         if (!orders.length) { hideLoader(); showToast('لا توجد أوردرات في الرانشيت', 'info'); return null; }
13010: 
13011:                         function deliverOrder(index) {
13012:                             if (index >= orders.length) {
13013:                                 showLoader('جاري إنهاء الرانشيت...');
13014:                                 return supabase.auth.getSession().then(function(ses2) {
13015:                                     var t2 = ses2.data.session ? ses2.data.session.access_token : null;
13016:                                     if (!t2) throw new Error('انتهت الجلسة');
13017:                                     return fetch(RW_SUPABASE_URL + '/functions/v1/complete-delivery', {
13018:                                         method: 'POST',
13019:                                         headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
13020:                                         body: JSON.stringify({ runsheet_code: rsCode })
13021:                                     });
13022:                                 }).then(function(res) {
13023:                                     return res.json();
13024:                                 }).then(function(finalJson) {
13025:                                     hideLoader();
13026:                                     if (finalJson.success) {
13027:                                         showToast('تم إنهاء التوصيل بالكامل', 'success');
13028:                                         if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13029:                                     } else {
13030:                                         showToast(finalJson.msg || 'فشل إنهاء الرانشيت', 'error');
13031:                                     }
13032:                                 });
13033:                             }
13034: 
13035:                             var order = orders[index];
13036:                             showLoader('جاري تحميل بيانات الأوردر ' + (order.order_code || '') + '...');
13037:                             return supabase.from('order_details')
13038:                                 .select('id,item_code,item_name,unit,qty,qty_loaded,qty_delivered,qty_refused,unit_price')
13039:                                 .eq('order_id', order.id)
13040:                                 .order('created_at', { ascending: true })
13041:                                 .then(function(detailsRes) {
13042:                                     if (detailsRes.error) throw detailsRes.error;
13043:                                     var details = detailsRes.data || [];
13044:                                     hideLoader();
13045:                                     if (!details.length) {
13046:                                         return deliverOrder(index + 1);
13047:                                     }
13048: 
13049:                                     var html = '<div class="text-right" dir="rtl"><div class="max-h-[420px] overflow-y-auto">';
13050:                                     html += '<div class="mb-3 p-3 bg-blue-50 rounded-lg"><div class="font-black text-blue-700">' + (order.order_code || '') + '</div><div class="text-sm text-gray-600">' + (order.customer_name || '') + '</div></div>';
13051:                                     html += '<table class="w-full border"><thead class="bg-slate-100"><tr><th class="p-2">الصنف</th><th class="p-2 text-center">محمّل</th><th class="p-2 text-center">مسلّم سابقًا</th><th class="p-2 text-center">المتبقي</th><th class="p-2 text-center">تسليم الآن</th></tr></thead><tbody>';
13052: 
13053:                                     for (var i = 0; i < details.length; i++) {
13054:                                         var d = details[i];
13055:                                         var loaded = Number(d.qty_loaded || 0);
13056:                                         var delivered = Number(d.qty_delivered || 0);
13057:                                         var remaining = Math.max(0, loaded - delivered);
13058:                                         html += '<tr><td class="p-2 border"><div class="font-bold">' + (d.item_name || '') + '</div><div class="text-xs text-gray-400">' + (d.item_code || '') + '</div></td>'
13059:                                             + '<td class="p-2 border text-center">' + loaded + '</td>'
13060:                                             + '<td class="p-2 border text-center">' + delivered + '</td>'
13061:                                             + '<td class="p-2 border text-center font-bold text-blue-700">' + remaining + '</td>'
13062:                                             + '<td class="p-2 border text-center"><input type="number" id="dv_order_qty_' + i + '" value="' + remaining + '" min="0" max="' + remaining + '" step="0.01" class="w-24 p-1 border rounded text-center"></td></tr>';
13063:                                     }
13064:                                     html += '</tbody></table></div></div>';
13065: 
13066:                                     return Swal.fire({
13067:                                         title: 'توصيل الأوردر ' + (order.order_code || ''),
13068:                                         html: html,
13069:                                         width: '850px',
13070:                                         showCancelButton: true,
13071:                                         confirmButtonText: 'تأكيد تسليم الأوردر',
13072:                                         cancelButtonText: 'إلغاء',
13073:                                         preConfirm: function() {
13074:                                             var items = [];
13075:                                             var hasQty = false;
13076:                                             for (var j = 0; j < details.length; j++) {
13077:                                                 var maxRemaining = Math.max(0, Number(details[j].qty_loaded || 0) - Number(details[j].qty_delivered || 0));
13078:                                                 var q = parseFloat((document.getElementById('dv_order_qty_' + j) || {}).value) || 0;
13079:                                                 if (q < 0 || q > maxRemaining) {
13080:                                                     Swal.showValidationMessage('كمية التسليم تتجاوز المتبقي للصنف: ' + (details[j].item_code || ''));
13081:                                                     return false;
13082:                                                 }
13083:                                                 if (q > 0) hasQty = true;
13084:                                                 items.push({ itemCode: details[j].item_code, deliveredQty: q, reason: '' });
13085:                                             }
13086:                                             if (!hasQty) {
13087:                                                 Swal.showValidationMessage('أدخل كمية تسليم واحدة على الأقل');
13088:                                                 return false;
13089:                                             }
13090:                                             return items;
13091:                                         }
13092:                                     }).then(function(result) {
13093:                                         if (!result.isConfirmed) return;
13094:                                         showLoader('جاري حفظ تسليم ' + (order.order_code || '') + '...');
13095:                                         return supabase.auth.getSession().then(function(ses3) {
13096:                                             var t3 = ses3.data.session ? ses3.data.session.access_token : null;
13097:                                             if (!t3) throw new Error('انتهت الجلسة');
13098:                                             return fetch(RW_SUPABASE_URL + '/functions/v1/complete-order-delivery', {
13099:                                                 method: 'POST',
13100:                                                 headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t3 },
13101:                                                 body: JSON.stringify({ runsheet_code: rsCode, order_code: order.order_code, items: result.value })
13102:                                             });
13103:                                         }).then(function(res) {
13104:                                             return res.json();
13105:                                         }).then(function(orderJson) {
13106:                                             hideLoader();
13107:                                             if (!orderJson.success) {
13108:                                                 showToast(orderJson.msg || 'فشل تسليم الأوردر', 'error');
13109:                                                 return;
13110:                                             }
13111:                                             return deliverOrder(index + 1);
13112:                                         });
13113:                                     });
13114:                                 });
13115:                         }
13116: 
13117:                         return deliverOrder(0);
13118:                     });
13119:             });
13120:         })
13121:         .catch(function(e) {
13122:             hideLoader();
13123:             showToast(e.message || 'فشل تحميل بيانات التوصيل', 'error');
13124:         });
13125: }
13126: function _openReturnModal(rsCode) {
13127:     if (!rsCode) { showToast('رقم الرانشيت غير صالح', 'error'); return; }
13128:     showLoader('جاري تحميل بيانات المرتجعات...');
13129:     
13130:     var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) || null;
13131: if (!companyId) { hideLoader(); showToast('سياق الشركة غير محدد', 'error'); return; }
13132: supabase.from('runsheets')
13133:     .select('id')
13134:     .eq('company_id', companyId)
13135:     .eq('runsheet_code', rsCode)
13136:     .maybeSingle()
13137:     .then(function(rsRes) {
13138:         if (!rsRes.data) { hideLoader(); showToast('الرانشيت غير موجود', 'error'); return; }
13139:         var runsheetUuid = rsRes.data.id;
13140:         
13141:         supabase.from('run_sheet_details').select('*').eq('runsheet_id', runsheetUuid).then(function(itemsRes) {
13142:             var items = itemsRes.data || [];
13143:             if (items.length === 0) { hideLoader(); showToast('لا توجد أصناف في هذا الرانشيت', 'info'); return; }
13144:             
13145:             showLoader('جاري بدء المرتجعات...');
13146:             supabase.auth.getSession().then(function(ses) {
13147:                 var t = ses.data.session ? ses.data.session.access_token : null;
13148:                 return fetch(RW_SUPABASE_URL + '/functions/v1/start-return', {
13149:                     method: 'POST',
13150:                     headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13151:                     body: JSON.stringify({ runsheet_code: rsCode })
13152:                 });
13153:             }).then(function(res) { return res.json(); }).then(function(startJson) {
13154:                 hideLoader();
13155:                 if (!startJson.success) { showToast(startJson.msg || 'فشل بدء المرتجعات', 'error'); return; }
13156:                 
13157:                 var html = '<div class="text-right" dir="rtl"><div class="max-h-[400px] overflow-y-auto"><table class="w-full border"><thead class="bg-slate-100"><tr>' +
13158:                     '<th class="p-2">الصنف</th><th class="p-2 text-center">الوحدة</th><th class="p-2 text-center">الكمية المسلّمة</th><th class="p-2 text-center">الكمية المرتجعة</th></tr></thead><tbody>';
13159:                 for (var i = 0; i < items.length; i++) {
13160:                     var it = items[i];
13161:                     var delivered = it.qty_delivered || 0;
13162:                     html += '<tr><td class="p-2 border"><p class="font-bold">' + (it.item_name || '') + '</p><p class="text-xs">' + (it.item_code || '') + '</p></td>' +
13163:                         '<td class="p-2 border text-center">' + (it.unit || 'حبة') + '</td>' +
13164:                         '<td class="p-2 border text-center font-bold">' + delivered + '</td>' +
13165:                         '<td class="p-2 border text-center"><input type="number" id="returned_qty_' + i + '" class="w-24 p-2 border rounded text-center" step="1" min="0" max="' + delivered + '" value="0"></td></tr>';
13166:                 }
13167:                 html += '</tbody></table></div></div>';
13168:                 
13169:                 Swal.fire({
13170:                     title: 'مرتجعات الرانشيت: ' + rsCode,
13171:                     html: html,
13172:                     width: '800px',
13173:                     showCancelButton: true,
13174:                     confirmButtonText: 'إنهاء المرتجعات',
13175:                     cancelButtonText: 'إلغاء',
13176:                     preConfirm: function() {
13177:                         var itemsData = [];
13178:                         var allZero = true;
13179:                         for (var j = 0; j < items.length; j++) {
13180:                             var qty = parseFloat(document.getElementById('returned_qty_' + j).value) || 0;
13181:                             if (qty > 0) allZero = false;
13182:                             itemsData.push({ itemCode: items[j].item_code, returnedQty: qty, reason: '' });
13183:                         }
13184:                         if (allZero) { Swal.showValidationMessage('يجب إدخال كمية مرتجعة واحدة على الأقل'); return false; }
13185:                         return itemsData;
13186:                     }
13187:                 }).then(function(result) {
13188:                     if (!result.isConfirmed) return;
13189:                     showLoader('جاري إنهاء المرتجعات...');
13190:                     supabase.auth.getSession().then(function(ses2) {
13191:                         var t2 = ses2.data.session ? ses2.data.session.access_token : null;
13192:                         return fetch(RW_SUPABASE_URL + '/functions/v1/complete-return', {
13193:                             method: 'POST',
13194:                             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t2 },
13195:                             body: JSON.stringify({ runsheet_code: rsCode, items: result.value })
13196:                         });
13197:                     }).then(function(res) { return res.json(); }).then(function(compJson) {
13198:                         hideLoader();
13199:                         if (compJson.success) {
13200:                             showToast('تم إنهاء المرتجعات بنجاح', 'success');
13201:                             if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13202:                         } else {
13203:                             showToast(compJson.msg || 'فشل إنهاء المرتجعات', 'error');
13204:                         }
13205:                     }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13206:                 });
13207:             }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13208:         }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
13209:     }).catch(function(e) { hideLoader(); showToast('فشل تحميل بيانات الرانشيت', 'error'); });
13210: }
13211: function _confirmUnload(code) {
13212:     Swal.fire({ title: 'تأكيد التفريغ', text: 'إعادة جميع الكميات للمخزون؟', icon: 'warning', showCancelButton: true, confirmButtonText: 'نعم', cancelButtonText: 'لا' }).then(function(cf) {
13213:         if (!cf.isConfirmed) return;
13214:         showLoader('جاري التفريغ...');
13215:         supabase.auth.getSession().then(function(ses) {
13216:             var t = ses.data.session ? ses.data.session.access_token : null;
13217:             return fetch(RW_SUPABASE_URL + '/functions/v1/unload-runsheet', {
13218:                 method: 'POST',
13219:                 headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13220:                 body: JSON.stringify({ runsheet_code: code })
13221:             });
13222:         }).then(function(res) { return res.json(); }).then(function(json) {
13223:             hideLoader();
13224:             if (json.success) {
13225:                 showToast('تم التفريغ بنجاح', 'success');
13226:                 if (typeof RW_Runsheets !== 'undefined' && RW_Runsheets._apply) RW_Runsheets._apply();
13227:             } else {
13228:                 showToast(json.msg || 'فشل التفريغ', 'error');
13229:             }
13230:         }).catch(function(e) { hideLoader(); showToast('فشل الاتصال', 'error'); });
13231:     });
13232: }
13233: function _changeStatus(code, funcName) {
13234:     showLoader('جاري تحديث الحالة...');
13235:     supabase.auth.getSession().then(function(ses) {
13236:         var t = ses.data.session ? ses.data.session.access_token : null;
13237:         return fetch(SUPABASE_URL + '/functions/v1/' + funcName, {
13238:             method: 'POST',
13239:             headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
13240:             body: JSON.stringify({ runsheet_code: code })
13241:         });
13242:     }).then(function(res) { return res.json(); }).then(function(json) {
13243:         hideLoader();
13244:         if (json.success) {
13245:             showToast('تم بنجاح', 'success');
13246:         } else {
13247:             showToast(json.msg || 'فشل', 'error');
13248:         }
13249:     }).catch(function(e) {
13250:         hideLoader();
13251:         showToast('فشل الاتصال', 'error');
13252:     });
13253: }
13254:     async function loadInventoryControl() {
13255:         var c = byId('rw-page-container');
13256:         if (!c) return;
13257: 
13258:         var companyId = (RW_STATE && RW_STATE.app && RW_STATE.app.companyId) ||
13259:             (typeof _rwCompanyId === 'function' ? _rwCompanyId() : null);
13260:         if (!companyId) {
13261:             showToast('سياق الشركة غير محدد', 'error');
13262:             return;
13263:         }
13264: 
13265:         var state = {
13266:             tab: 'snapshot',
13267:             branchId: '',
13268:             query: '',
13269:             lowOnly: false,
13270:             movementType: '',
13271:             fromDate: '',
13272:             toDate: '',
13273:             snapshot: [],
13274:             movements: [],
13275:             replenishment: [],
13276:             counts: [],
13277:             requests: [],
13278:             branches: [],
13279:             busy: false
13280:         };
13281: 
13282:         function escIC(v) {
13283:             return String(v == null ? '' : v)
13284:                 .replace(/&/g, '&amp;')
13285:                 .replace(/</g, '&lt;')
13286:                 .replace(/>/g, '&gt;')
13287:                 .replace(/"/g, '&quot;')
13288:                 .replace(/'/g, '&#39;');
13289:         }
13290: 
13291:         function fmtIC(v) {
13292:             return Number(v || 0).toLocaleString('ar-EG');
13293:         }
13294: 
13295:         async function callIC(operation, payload) {
13296:             var res = await supabase.rpc('inventory_control', {
13297:                 p_operation: operation,
13298:                 p_payload: payload || {}
13299:             });
13300:             if (res.error) throw res.error;
13301:             var data = res.data;
13302:             if (data && data.success === false) {
13303:                 throw new Error(data.msg || 'فشل تنفيذ العملية');
13304:             }
13305:             return data || { success: true };
13306:         }
13307: 
13308:         function branchOptions(selected) {
13309:             var h = '<option value="">كل المخازن والفروع</option>';
13310:             for (var i = 0; i < state.branches.length; i++) {
13311:                 var b = state.branches[i];
13312:                 h += '<option value="' + escIC(b.id) + '"' +
13313:                     (String(selected || '') === String(b.id) ? ' selected' : '') + '>' +
13314:                     escIC(b.name || b.branch_code) + '</option>';
13315:             }
13316:             return h;
13317:         }
13318: 
13319:         function renderShell() {
13320:             safeText(byId('rw-header-title'), 'مركز التحكم في المخزون');
13321:             safeHTML(c,
13322:                 '<div class="p-4 space-y-4">' +
13323:                 '<div class="bg-white rounded-2xl shadow-sm border p-4">' +
13324:                     '<div class="flex flex-wrap items-center justify-between gap-3 mb-4">' +
13325:                         '<div>' +
13326:                             '<div class="text-xl font-black text-slate-800">مركز التحكم في المخزون</div>' +
13327:                             '<div class="text-sm text-slate-500 mt-1">لوحة رقابة مركزية فوق رصيد المخزون والحركة والاحتياجات والجرد وطلبات المخزون</div>' +
13328:                         '</div>' +
13329:                         '<div class="flex gap-2">' +
13330:                             '<button id="ic-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث البيانات</button>' +
13331:                             '<button id="ic-new-count" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">جلسة جرد جديدة</button>' +
13332:                         '</div>' +
13333:                     '</div>' +
13334:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13335:                         '<div class="rounded-2xl bg-blue-50 border border-blue-100 p-4"><div class="text-xs text-blue-700 font-bold">بنود المخزون المعروضة</div><div id="ic-kpi-lines" class="text-2xl font-black text-blue-900 mt-1">0</div></div>' +
13336:                         '<div class="rounded-2xl bg-amber-50 border border-amber-100 p-4"><div class="text-xs text-amber-700 font-bold">بنود منخفضة</div><div id="ic-kpi-low" class="text-2xl font-black text-amber-900 mt-1">0</div></div>' +
13337:                         '<div class="rounded-2xl bg-emerald-50 border border-emerald-100 p-4"><div class="text-xs text-emerald-700 font-bold">بنود تحتاج إعادة طلب</div><div id="ic-kpi-repl" class="text-2xl font-black text-emerald-900 mt-1">0</div></div>' +
13338:                         '<div class="rounded-2xl bg-purple-50 border border-purple-100 p-4"><div class="text-xs text-purple-700 font-bold">جلسات الجرد النشطة</div><div id="ic-kpi-counts" class="text-2xl font-black text-purple-900 mt-1">0</div></div>' +
13339:                     '</div>' +
13340:                 '</div>' +
13341:                 '<div class="bg-white rounded-2xl shadow-sm border p-3">' +
13342:                     '<div class="flex flex-wrap gap-2">' +
13343:                         '<button data-ic-tab="snapshot" class="ic-tab px-4 py-2 rounded-xl font-bold bg-blue-600 text-white">الرصيد</button>' +
13344:                         '<button data-ic-tab="movements" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الحركات</button>' +
13345:                         '<button data-ic-tab="replenishment" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">إعادة الطلب</button>' +
13346:                         '<button data-ic-tab="counts" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">الجرد</button>' +
13347:                         '<button data-ic-tab="requests" class="ic-tab px-4 py-2 rounded-xl font-bold bg-slate-100 text-slate-700">طلبات المخزون</button>' +
13348:                     '</div>' +
13349:                 '</div>' +
13350:                 '<div id="ic-filters" class="bg-white rounded-2xl shadow-sm border p-4"></div>' +
13351:                 '<div id="ic-content" class="bg-white rounded-2xl shadow-sm border overflow-auto"></div>' +
13352:                 '</div>'
13353:             );
13354: 
13355:             byId('ic-refresh').onclick = refreshAll;
13356:             byId('ic-new-count').onclick = createCountSession;
13357: 
13358:             var tabs = c.querySelectorAll('.ic-tab');
13359:             for (var i = 0; i < tabs.length; i++) {
13360:                 tabs[i].onclick = function() {
13361:                     state.tab = this.getAttribute('data-ic-tab');
13362:                     renderTabButtons();
13363:                     renderFilters();
13364:                     refreshCurrentTab();
13365:                 };
13366:             }
13367:         }
13368: 
13369:         function renderTabButtons() {
13370:             var tabs = c.querySelectorAll('.ic-tab');
13371:             for (var i = 0; i < tabs.length; i++) {
13372:                 var active = tabs[i].getAttribute('data-ic-tab') === state.tab;
13373:                 tabs[i].className = 'ic-tab px-4 py-2 rounded-xl font-bold ' +
13374:                     (active ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-700');
13375:             }
13376:         }
13377: 
13378:         function renderFilters() {
13379:             var f = byId('ic-filters');
13380:             if (!f) return;
13381:             if (state.tab === 'snapshot') {
13382:                 safeHTML(f,
13383:                     '<div class="grid grid-cols-1 md:grid-cols-4 gap-3">' +
13384:                         '<select id="ic-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13385:                         '<input id="ic-query" class="p-2.5 border rounded-xl bg-slate-50" placeholder="بحث بالصنف أو الكود أو الفرع" value="' + escIC(state.query) + '">' +
13386:                         '<label class="flex items-center gap-2 p-2.5 border rounded-xl bg-slate-50"><input id="ic-low" type="checkbox" ' + (state.lowOnly ? 'checked' : '') + '> منخفض فقط</label>' +
13387:                         '<button id="ic-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تطبيق</button>' +
13388:                     '</div>'
13389:                 );
13390:                 byId('ic-apply').onclick = function() {
13391:                     state.branchId = byId('ic-branch').value || '';
13392:                     state.query = byId('ic-query').value || '';
13393:                     state.lowOnly = !!byId('ic-low').checked;
13394:                     refreshCurrentTab();
13395:                 };
13396:             } else if (state.tab === 'movements') {
13397:                 safeHTML(f,
13398:                     '<div class="grid grid-cols-1 md:grid-cols-5 gap-3">' +
13399:                         '<input id="ic-from" type="date" class="p-2.5 border rounded-xl bg-slate-50" value="' + escIC(state.fromDate) + '">' +
13400:                         '<input id="ic-to" type="date" class="p-2.5 border rounded-xl bg-slate-50" value="' + escIC(state.toDate) + '">' +
13401:                         '<select id="ic-mov-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13402:                         '<input id="ic-mov-query" class="p-2.5 border rounded-xl bg-slate-50" placeholder="صنف/مرجع" value="' + escIC(state.query) + '">' +
13403:                         '<button id="ic-mov-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تطبيق</button>' +
13404:                     '</div>'
13405:                 );
13406:                 byId('ic-mov-apply').onclick = function() {
13407:                     state.fromDate = byId('ic-from').value || '';
13408:                     state.toDate = byId('ic-to').value || '';
13409:                     state.branchId = byId('ic-mov-branch').value || '';
13410:                     state.query = byId('ic-mov-query').value || '';
13411:                     refreshCurrentTab();
13412:                 };
13413:             } else if (state.tab === 'replenishment') {
13414:                 safeHTML(f,
13415:                     '<div class="grid grid-cols-1 md:grid-cols-3 gap-3">' +
13416:                         '<select id="ic-repl-branch" class="p-2.5 border rounded-xl bg-slate-50">' + branchOptions(state.branchId) + '</select>' +
13417:                         '<div class="p-2.5 rounded-xl bg-emerald-50 border border-emerald-100 font-bold text-emerald-800">التوصية مبنية على الرصيد المتاح ونقطة إعادة الطلب والحد الأقصى</div>' +
13418:                         '<button id="ic-repl-apply" class="p-2.5 rounded-xl bg-slate-700 text-white font-bold">تحديث التوصيات</button>' +
13419:                     '</div>'
13420:                 );
13421:                 byId('ic-repl-apply').onclick = function() {
13422:                     state.branchId = byId('ic-repl-branch').value || '';
13423:                     refreshCurrentTab();
13424:                 };
13425:             } else if (state.tab === 'counts') {
13426:                 safeHTML(f,
13427:                     '<div class="flex flex-wrap items-center justify-between gap-2">' +
13428:                         '<div class="text-sm text-slate-600">الجرد يبدأ من جلسة، ثم Populate/Count/Refresh/Finalize عبر محرك الجرد الحالي.</div>' +
13429:                         '<button id="ic-count-refresh" class="px-4 py-2 rounded-xl bg-slate-700 text-white font-bold">تحديث الجلسات</button>' +
13430:                     '</div>'
13431:                 );
13432:                 byId('ic-count-refresh').onclick = refreshCounts;
13433:             } else {
13434:                 safeHTML(f,
13435:                     '<div class="flex flex-wrap items-center justify-between gap-2">' +
13436:                         '<div class="text-sm text-slate-600">طلبات المخزون تستخدم دورة Pending → Approved → Converted/Rejected/Cancelled.</div>' +
13437:                         '<button id="ic-request-new" class="px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold">طلب نقل مخزني جديد</button>' +
13438:                     '</div>'
13439:                 );
13440:                 byId('ic-request-new').onclick = createStockRequest;
13441:             }
13442:         }
13443: 
13444:         function setBusy(on, text) {
13445:             state.busy = on;
13446:             if (on) showLoader(text || 'جاري تحميل مركز التحكم...');
13447:             else hideLoader();
13448:         }
13449: 
13450:         async function refreshSnapshot() {
13451:             var d = await callIC('SNAPSHOT', {
13452:                 branch_id: state.branchId || null,
13453:                 query: state.query || null,
13454:                 low_only: state.lowOnly,
13455:                 limit: 200,
13456:                 offset: 0
13457:             });
13458:             state.snapshot = d.rows || [];
13459:             safeText(byId('ic-kpi-lines'), fmtIC(d.count || state.snapshot.length));
13460:             var low = state.snapshot.filter(function(x) { return x.low_stock; }).length;
13461:             safeText(byId('ic-kpi-low'), fmtIC(low));
13462:             renderSnapshot();
13463:         }
13464: 
13465:         async function refreshMovements() {
13466:             var d = await callIC('MOVEMENTS', {
13467:                 from_date: state.fromDate || null,
13468:                 to_date: state.toDate || null,
13469:                 branch_id: state.branchId || null,
13470:                 item_id: null,
13471:                 movement_type: state.movementType || null,
13472:                 query: state.query || null,
13473:                 limit: 200,
13474:                 offset: 0
13475:             });
13476:             state.movements = d.rows || [];
13477:             renderMovements();
13478:         }
13479: 
13480:         async function refreshReplenishment() {
13481:             var d = await callIC('REPLENISHMENT', {
13482:                 branch_id: state.branchId || null,
13483:                 limit: 200,
13484:                 offset: 0
13485:             });
13486:             state.replenishment = d.rows || [];
13487:             safeText(byId('ic-kpi-repl'), fmtIC(state.replenishment.length));
13488:             renderReplenishment();
13489:         }
13490: 
13491:         async function refreshCounts() {
13492:             var res = await supabase.from('inventory_counts')
13493:                 .select('*')
13494:                 .eq('company_id', companyId)
13495:                 .order('created_at', { ascending: false });
13496:             if (res.error) throw res.error;
13497:             state.counts = res.data || [];
13498:             safeText(byId('ic-kpi-counts'), fmtIC(state.counts.filter(function(x) { return ['InProgress','Draft'].indexOf(x.status) !== -1; }).length));
13499:             renderCounts();
13500:         }
13501: 
13502:         async function refreshRequests() {
13503:             var res = await supabase.from('inventory_stock_requests')
13504:                 .select('*')
13505:                 .eq('company_id', companyId)
13506:                 .order('created_at', { ascending: false });
13507:             if (res.error) throw res.error;
13508:             state.requests = res.data || [];
13509:             renderRequests();
13510:         }
13511: 
13512:         function renderSnapshot() {
13513:             var tb = byId('ic-content');
13514:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13515:                 '<th class="p-3">الفرع</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">فعلي</th><th class="p-3">محجوز</th><th class="p-3">متاح</th><th class="p-3">ROP</th><th class="p-3">إعادة الطلب</th><th class="p-3">القيمة</th></tr></thead><tbody>';
13516:             if (!state.snapshot.length) h += '<tr><td colspan="9" class="p-8 text-center text-slate-500">لا توجد بيانات</td></tr>';
13517:             for (var i = 0; i < state.snapshot.length; i++) {
13518:                 var x = state.snapshot[i];
13519:                 h += '<tr class="border-b hover:bg-slate-50">' +
13520:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code) + '</td>' +
13521:                     '<td class="p-3 font-bold">' + escIC(x.item_code) + '</td>' +
13522:                     '<td class="p-3 font-semibold">' + escIC(x.item_name) + '</td>' +
13523:                     '<td class="p-3 text-center">' + fmtIC(x.physical_qty) + '</td>' +
13524:                     '<td class="p-3 text-center text-orange-700">' + fmtIC(x.allocated_qty) + '</td>' +
13525:                     '<td class="p-3 text-center font-black">' + fmtIC(x.available_qty) + '</td>' +
13526:                     '<td class="p-3 text-center">' + fmtIC(x.reorder_point) + '</td>' +
13527:                     '<td class="p-3 text-center font-bold ' + (x.low_stock ? 'text-red-600' : 'text-emerald-600') + '">' + fmtIC(x.suggested_replenishment_qty) + '</td>' +
13528:                     '<td class="p-3 text-center">' + fmtIC(x.stock_value_at_cost) + '</td>' +
13529:                 '</tr>';
13530:             }
13531:             h += '</tbody></table>';
13532:             safeHTML(tb, h);
13533:         }
13534: 
13535:         function renderMovements() {
13536:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13537:                 '<th class="p-3">التاريخ</th><th class="p-3">الحركة</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">الفرع</th><th class="p-3">الأثر</th><th class="p-3">المرجع</th><th class="p-3">المستخدم</th></tr></thead><tbody>';
13538:             if (!state.movements.length) h += '<tr><td colspan="8" class="p-8 text-center text-slate-500">لا توجد حركات</td></tr>';
13539:             for (var i = 0; i < state.movements.length; i++) {
13540:                 var x = state.movements[i];
13541:                 h += '<tr class="border-b hover:bg-slate-50">' +
13542:                     '<td class="p-3">' + escIC(x.movement_date || x.created_at) + '</td>' +
13543:                     '<td class="p-3 font-bold">' + escIC(x.movement_type) + '</td>' +
13544:                     '<td class="p-3">' + escIC(x.item_code) + '</td>' +
13545:                     '<td class="p-3">' + escIC(x.item_name) + '</td>' +
13546:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code || '') + '</td>' +
13547:                     '<td class="p-3 text-center font-black">' + fmtIC(x.effect_qty == null ? x.qty : x.effect_qty) + '</td>' +
13548:                     '<td class="p-3">' + escIC(x.reference || x.voucher_id || '') + '</td>' +
13549:                     '<td class="p-3">' + escIC(x.user_email || '') + '</td>' +
13550:                 '</tr>';
13551:             }
13552:             h += '</tbody></table>';
13553:             safeHTML(byId('ic-content'), h);
13554:         }
13555: 
13556:         function renderReplenishment() {
13557:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13558:                 '<th class="p-3">الفرع</th><th class="p-3">الكود</th><th class="p-3">الصنف</th><th class="p-3">المتاح</th><th class="p-3">ROP</th><th class="p-3">الموصى به</th><th class="p-3">التكلفة</th><th class="p-3">القيمة</th></tr></thead><tbody>';
13559:             if (!state.replenishment.length) h += '<tr><td colspan="8" class="p-8 text-center text-slate-500">لا توجد توصيات حاليًا</td></tr>';
13560:             for (var i = 0; i < state.replenishment.length; i++) {
13561:                 var x = state.replenishment[i];
13562:                 h += '<tr class="border-b hover:bg-slate-50">' +
13563:                     '<td class="p-3">' + escIC(x.branch_name || x.branch_code) + '</td>' +
13564:                     '<td class="p-3 font-bold">' + escIC(x.item_code) + '</td>' +
13565:                     '<td class="p-3 font-semibold">' + escIC(x.item_name) + '</td>' +
13566:                     '<td class="p-3 text-center">' + fmtIC(x.available_qty) + '</td>' +
13567:                     '<td class="p-3 text-center">' + fmtIC(x.reorder_point) + '</td>' +
13568:                     '<td class="p-3 text-center font-black text-emerald-700">' + fmtIC(x.recommended_order_qty) + '</td>' +
13569:                     '<td class="p-3 text-center">' + fmtIC(x.cost_price) + '</td>' +
13570:                     '<td class="p-3 text-center font-bold">' + fmtIC(x.recommended_order_value) + '</td>' +
13571:                 '</tr>';
13572:             }
13573:             h += '</tbody></table>';
13574:             safeHTML(byId('ic-content'), h);
13575:         }
13576: 
13577:         function renderCounts() {
13578:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white"><tr><th class="p-3">التاريخ</th><th class="p-3">النوع</th><th class="p-3">الحالة</th><th class="p-3">المرجع</th><th class="p-3">عملية</th><th class="p-3">إجراء</th></tr></thead><tbody>';
13579:             if (!state.counts.length) h += '<tr><td colspan="6" class="p-8 text-center text-slate-500">لا توجد جلسات جرد</td></tr>';
13580:             for (var i = 0; i < state.counts.length; i++) {
13581:                 var x = state.counts[i];
13582:                 var actionable = ['InProgress','Draft'].indexOf(x.status) !== -1;
13583:                 h += '<tr class="border-b hover:bg-slate-50">' +
13584:                     '<td class="p-3">' + escIC(x.count_date || x.created_at) + '</td>' +
13585:                     '<td class="p-3">' + escIC(x.type) + '</td>' +
13586:                     '<td class="p-3 font-bold">' + escIC(x.status) + '</td>' +
13587:                     '<td class="p-3">' + escIC(x.reference || '') + '</td>' +
13588:                     '<td class="p-3 font-mono text-xs">' + escIC(x.operation_id || '') + '</td>' +
13589:                     '<td class="p-3">' +
13590:                         (actionable ? '<button data-count-id="' + escIC(x.id) + '" data-count-action="cancel" class="ic-count-cancel px-3 py-1 rounded-lg bg-red-50 text-red-700 font-bold">إلغاء</button>' : '-') +
13591:                     '</td>' +
13592:                 '</tr>';
13593:             }
13594:             h += '</tbody></table>';
13595:             safeHTML(byId('ic-content'), h);
13596:             var btns = c.querySelectorAll('.ic-count-cancel');
13597:             for (var j = 0; j < btns.length; j++) btns[j].onclick = cancelCount;
13598:         }
13599: 
13600:         function renderRequests() {
13601:             var h = '<table class="w-full text-sm"><thead class="bg-slate-800 text-white"><tr><th class="p-3">الطلب</th><th class="p-3">التاريخ</th><th class="p-3">المصدر</th><th class="p-3">الوجهة</th><th class="p-3">الحالة</th><th class="p-3">إجراء</th></tr></thead><tbody>';
13602:             if (!state.requests.length) h += '<tr><td colspan="6" class="p-8 text-center text-slate-500">لا توجد طلبات مخزون</td></tr>';
13603:             for (var i = 0; i < state.requests.length; i++) {
13604:                 var x = state.requests[i];
13605:                 var actions = '';
13606:                 if (x.status === 'Pending') {
13607:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="approve" class="ic-req-btn px-2 py-1 rounded-lg bg-emerald-50 text-emerald-700 font-bold ml-1">اعتماد</button>';
13608:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="reject" class="ic-req-btn px-2 py-1 rounded-lg bg-red-50 text-red-700 font-bold">رفض</button>';
13609:                 } else if (x.status === 'Approved') {
13610:                     actions += '<button data-req-id="' + escIC(x.id) + '" data-req-action="convert" class="ic-req-btn px-2 py-1 rounded-lg bg-indigo-50 text-indigo-700 font-bold">تحويل لإذن</button>';
13611:                 }
13612:                 h += '<tr class="border-b hover:bg-slate-50">' +
13613:                     '<td class="p-3 font-black text-indigo-700">' + escIC(x.request_code) + '</td>' +
13614:                     '<td class="p-3">' + escIC(x.request_date) + '</td>' +
13615:                     '<td class="p-3 font-mono text-xs">' + escIC(x.source_branch_id || '') + '</td>' +
13616:                     '<td class="p-3 font-mono text-xs">' + escIC(x.target_branch_id || '') + '</td>' +
13617:                     '<td class="p-3 font-bold">' + escIC(x.status) + '</td>' +
13618:                     '<td class="p-3">' + actions + '</td>' +
13619:                 '</tr>';
13620:             }
13621:             h += '</tbody></table>';
13622:             safeHTML(byId('ic-content'), h);
13623:             var btns = c.querySelectorAll('.ic-req-btn');
13624:             for (var j = 0; j < btns.length; j++) btns[j].onclick = handleRequestAction;
13625:         }
13626: 
13627:         async function refreshCurrentTab() {
13628:             try {
13629:                 setBusy(true, 'جاري مزامنة مركز التحكم مع Production...');
13630:                 if (state.tab === 'snapshot') await refreshSnapshot();
13631:                 else if (state.tab === 'movements') await refreshMovements();
13632:                 else if (state.tab === 'replenishment') await refreshReplenishment();
13633:                 else if (state.tab === 'counts') await refreshCounts();
13634:                 else await refreshRequests();
13635:             } catch (e) {
13636:                 showToast(e.message || 'فشل تحديث مركز التحكم', 'error');
13637:             } finally {
13638:                 setBusy(false);
13639:             }
13640:         }
13641: 
13642:         async function refreshAll() {
13643:             await refreshCurrentTab();
13644:             if (state.tab !== 'replenishment') {
13645:                 try {
13646:                     var d = await callIC('REPLENISHMENT', { branch_id: state.branchId || null, limit: 200, offset: 0 });
13647:                     state.replenishment = d.rows || [];
13648:                     safeText(byId('ic-kpi-repl'), fmtIC(state.replenishment.length));
13649:                 } catch (e) {}
13650:             }
13651:             try { await refreshCounts(); } catch (e2) {}
13652:         }
13653: 
13654:         async function createCountSession() {
13655:             var branchOptionsHtml = '';
13656:             for (var i = 0; i < state.branches.length; i++) {
13657:                 branchOptionsHtml += '<option value="' + escIC(state.branches[i].id) + '">' +
13658:                     escIC(state.branches[i].name || state.branches[i].branch_code) + '</option>';
13659:             }
13660: 
13661:             var r = await Swal.fire({
13662:                 title: 'جلسة جرد جديدة',
13663:                 width: 760,
13664:                 html:
13665:                     '<div class="text-right space-y-4">' +
13666:                         '<div class="rounded-2xl bg-indigo-50 border border-indigo-100 p-4">' +
13667:                             '<div class="font-black text-indigo-900">ابدأ جردًا فعليًا للفرع</div>' +
13668:                             '<div class="text-sm text-indigo-700 mt-1">سيتم إنشاء الجلسة ثم تحميل أصناف الفرع تلقائيًا وفتح شاشة العد والمراجعة.</div>' +
13669:                         '</div>' +
13670:                         '<div class="grid grid-cols-1 md:grid-cols-2 gap-3">' +
13671:                             '<div>' +
13672:                                 '<label class="block text-sm font-black text-slate-700 mb-2">الفرع</label>' +
13673:                                 '<select id="ic-count-branch" class="swal2-input !w-full !m-0">' + branchOptionsHtml + '</select>' +
13674:                             '</div>' +
13675:                             '<div>' +
13676:                                 '<label class="block text-sm font-black text-slate-700 mb-2">تاريخ الجرد</label>' +
13677:                                 '<input id="ic-count-date" type="date" class="swal2-input !w-full !m-0" value="' + new Date().toISOString().slice(0, 10) + '">' +
13678:                             '</div>' +
13679:                         '</div>' +
13680:                         '<div>' +
13681:                             '<label class="block text-sm font-black text-slate-700 mb-2">مرجع الجرد</label>' +
13682:                             '<input id="ic-count-ref" class="swal2-input !w-full !m-0" placeholder="مثال: جرد نهاية اليوم / جرد دوري / جرد مفاجئ">' +
13683:                         '</div>' +
13684:                         '<div>' +
13685:                             '<label class="block text-sm font-black text-slate-700 mb-2">ملاحظات</label>' +
13686:                             '<textarea id="ic-count-notes" class="swal2-textarea !w-full !m-0" placeholder="ملاحظات الجرد أو تعليمات فريق العد"></textarea>' +
13687:                         '</div>' +
13688:                     '</div>',
13689:                 showCancelButton: true,
13690:                 confirmButtonText: 'بدء الجرد',
13691:                 cancelButtonText: 'إلغاء',
13692:                 focusConfirm: false,
13693:                 preConfirm: function() {
13694:                     var branch = byId('ic-count-branch').value || '';
13695:                     var countDate = byId('ic-count-date').value || '';
13696:                     if (!branch) {
13697:                         Swal.showValidationMessage('اختر الفرع أولًا');
13698:                         return false;
13699:                     }
13700:                     if (!countDate) {
13701:                         Swal.showValidationMessage('حدد تاريخ الجرد');
13702:                         return false;
13703:                     }
13704:                     return {
13705:                         branch: branch,
13706:                         countDate: countDate,
13707:                         ref: byId('ic-count-ref').value || '',
13708:                         notes: byId('ic-count-notes').value || ''
13709:                     };
13710:                 }
13711:             });
13712: 
13713:             if (!r.isConfirmed) return;
13714: 
13715:             try {
13716:                 setBusy(true, 'جاري إنشاء جلسة الجرد وتجهيز أصناف الفرع...');
13717: 
13718:                 var operationId = (window.crypto && window.crypto.randomUUID) ?
13719:                     window.crypto.randomUUID() : ('IC-' + Date.now() + '-' + Math.floor(Math.random() * 100000));
13720: 
13721:                 var created = await callIC('COUNT', {
13722:                     operation: 'CREATE',
13723:                     operation_id: operationId,
13724:                     payload: {
13725:                         type: 'branch',
13726:                         entity_id: r.value.branch,
13727:                         count_date: r.value.countDate,
13728:                         reference: r.value.ref,
13729:                         notes: r.value.notes
13730:                     }
13731:                 });
13732: 
13733:                 var countId = created.count_id;
13734:                 if (!countId) throw new Error('لم يتم إرجاع رقم جلسة الجرد');
13735: 
13736:                 await callIC('COUNT', {
13737:                     operation: 'POPULATE',
13738:                     payload: { count_id: countId }
13739:                 });
13740: 
13741:                 state.tab = 'counts';
13742:                 renderTabButtons();
13743:                 renderFilters();
13744:                 await refreshCounts();
13745: 
13746:                 async function openCountEditor() {
13747:                     var loaded = await callIC('COUNT', {
13748:                         operation: 'GET',
13749:                         payload: { count_id: countId }
13750:                     });
13751: 
13752:                     var count = loaded.count || {};
13753:                     var details = loaded.details || [];
13754:                     var catalog = (RW_STATE && RW_STATE.data && Array.isArray(RW_STATE.data.items)) ? RW_STATE.data.items : [];
13755: 
13756:                     function barcodeOf(code) {
13757:                         for (var bi = 0; bi < catalog.length; bi++) {
13758:                             if (String(catalog[bi].item_code || '') === String(code || '')) {
13759:                                 return catalog[bi].barcode || '';
13760:                             }
13761:                         }
13762:                         return '';
13763:                     }
13764: 
13765:                     function renderCountTable(filter) {
13766:                         filter = String(filter || '').trim().toLowerCase();
13767:                         var rows = '';
13768:                         for (var di = 0; di < details.length; di++) {
13769:                             var d = details[di];
13770:                             var barcode = barcodeOf(d.item_code);
13771:                             var hay = [d.item_code, d.item_name, barcode].join(' ').toLowerCase();
13772:                             if (filter && hay.indexOf(filter) === -1) continue;
13773:                             rows +=
13774:                                 '<tr class="border-b hover:bg-slate-50" data-count-row="' + escIC(d.id) + '">' +
13775:                                     '<td class="p-2 font-black text-indigo-700">' + escIC(d.item_code) + '</td>' +
13776:                                     '<td class="p-2 font-semibold">' + escIC(d.item_name) + '</td>' +
13777:                                     '<td class="p-2 text-center">' + escIC(d.unit || '') + '</td>' +
13778:                                     '<td class="p-2 text-center font-bold text-slate-700">' + fmtIC(d.system_qty) + '</td>' +
13779:                                     '<td class="p-2 text-center"><input data-count-input="' + escIC(d.id) + '" type="number" min="0" step="0.001" value="' + (d.counted_qty == null ? '' : escIC(d.counted_qty)) + '" class="w-28 px-2 py-2 border rounded-lg text-center font-black"></td>' +
13780:                                     '<td class="p-2 text-center font-black" data-count-variance="' + escIC(d.id) + '">' + fmtIC(d.variance_qty) + '</td>' +
13781:                                     '<td class="p-2"><input data-count-note="' + escIC(d.id) + '" value="' + escIC(d.notes || '') + '" class="w-40 px-2 py-2 border rounded-lg text-sm" placeholder="ملاحظة"></td>' +
13782:                                 '</tr>';
13783:                         }
13784:                         if (!rows) rows = '<tr><td colspan="7" class="p-10 text-center text-slate-500">لا توجد أصناف مطابقة للبحث</td></tr>';
13785:                         return rows;
13786:                     }
13787: 
13788:                     var editor = await Swal.fire({
13789:                         title: 'جلسة الجرد — ' + escIC(count.reference || count.count_date || ''),
13790:                         width: 1220,
13791:                         showConfirmButton: false,
13792:                         showCancelButton: false,
13793:                         html:
13794:                             '<div id="ic-count-editor" class="text-right">' +
13795:                                 '<div class="grid grid-cols-2 md:grid-cols-5 gap-2 mb-4">' +
13796:                                     '<div class="rounded-xl bg-slate-50 border p-3"><div class="text-xs text-slate-500">الفرع</div><div class="font-black">' + escIC(count.branch_id || '') + '</div></div>' +
13797:                                     '<div class="rounded-xl bg-blue-50 border border-blue-100 p-3"><div class="text-xs text-blue-700">إجمالي البنود</div><div id="ic-ce-total" class="font-black text-blue-900">' + fmtIC(details.length) + '</div></div>' +
13798:                                     '<div class="rounded-xl bg-emerald-50 border border-emerald-100 p-3"><div class="text-xs text-emerald-700">تم العد</div><div id="ic-ce-counted" class="font-black text-emerald-900">0</div></div>' +
13799:                                     '<div class="rounded-xl bg-amber-50 border border-amber-100 p-3"><div class="text-xs text-amber-700">عجز/زيادة</div><div id="ic-ce-variance" class="font-black text-amber-900">0</div></div>' +
13800:                                     '<div class="rounded-xl bg-purple-50 border border-purple-100 p-3"><div class="text-xs text-purple-700">الحالة</div><div id="ic-ce-status" class="font-black text-purple-900">' + escIC(count.status || '') + '</div></div>' +
13801:                                 '</div>' +
13802:                                 '<div class="flex flex-wrap gap-2 mb-3">' +
13803:                                     '<input id="ic-ce-search" class="flex-1 min-w-[240px] px-3 py-2 border rounded-xl" placeholder="ابحث بالكود أو اسم الصنف أو الباركود">' +
13804:                                     '<button id="ic-ce-refresh" class="px-4 py-2 rounded-xl bg-slate-800 text-white font-bold">تحديث أرصدة النظام</button>' +
13805:                                     '<button id="ic-ce-save" class="px-4 py-2 rounded-xl bg-blue-600 text-white font-bold">حفظ العد</button>' +
13806:                                     '<button id="ic-ce-finalize" class="px-4 py-2 rounded-xl bg-emerald-600 text-white font-bold">إتمام وتسوية الجرد</button>' +
13807:                                     '<button id="ic-ce-cancel" class="px-4 py-2 rounded-xl bg-red-50 text-red-700 font-bold">إلغاء الجلسة</button>' +
13808:                                 '</div>' +
13809:                                 '<div class="overflow-auto border rounded-2xl max-h-[58vh]">' +
13810:                                     '<table class="w-full text-sm">' +
13811:                                         '<thead class="bg-slate-800 text-white sticky top-0"><tr>' +
13812:                                             '<th class="p-2">الكود</th><th class="p-2">الصنف</th><th class="p-2">الوحدة</th><th class="p-2">رصيد النظام</th><th class="p-2">العد الفعلي</th><th class="p-2">الفرق</th><th class="p-2">ملاحظة</th>' +
13813:                                         '</tr></thead>' +
13814:                                         '<tbody id="ic-ce-body">' + renderCountTable('') + '</tbody>' +
13815:                                     '</table>' +
13816:                                 '</div>' +
13817:                             '</div>',
13818:                         didOpen: function() {
13819:                             function updateSummary() {
13820:                                 var counted = 0;
13821:                                 var variance = 0;
13822:                                 var inputs = document.querySelectorAll('[data-count-input]');
13823:                                 for (var si = 0; si < inputs.length; si++) {
13824:                                     if (inputs[si].value !== '') counted++;
13825:                                 }
13826:                                 for (var sj = 0; sj < details.length; sj++) {
13827:                                     variance += Number(details[sj].variance_qty || 0);
13828:                                 }
13829:                                 safeText(byId('ic-ce-counted'), fmtIC(counted));
13830:                                 safeText(byId('ic-ce-variance'), fmtIC(variance));
13831:                             }
13832: 
13833:                             byId('ic-ce-search').oninput = function() {
13834:                                 safeHTML(byId('ic-ce-body'), renderCountTable(this.value));
13835:                             };
13836: 
13837:                             byId('ic-ce-refresh').onclick = async function() {
13838:                                 try {
13839:                                     showLoader('جاري تحديث أرصدة النظام قبل استكمال الجرد...');
13840:                                     await callIC('COUNT', { operation: 'REFRESH', payload: { count_id: countId, mode: 'ALL' } });
13841:                                     var refreshed = await callIC('COUNT', { operation: 'GET', payload: { count_id: countId } });
13842:                                     count = refreshed.count || count;
13843:                                     details = refreshed.details || [];
13844:                                     safeHTML(byId('ic-ce-body'), renderCountTable(byId('ic-ce-search').value));
13845:                                     updateSummary();
13846:                                     hideLoader();
13847:                                     showToast('تم تحديث أرصدة النظام للجلسة', 'success');
13848:                                 } catch (e) {
13849:                                     hideLoader();
13850:                                     showToast(e.message || 'فشل تحديث أرصدة النظام', 'error');
13851:                                 }
13852:                             };
13853: 
13854:                             byId('ic-ce-save').onclick = async function() {
13855:                                 try {
13856:                                     showLoader('جاري حفظ كميات الجرد...');
13857:                                     var inputs = document.querySelectorAll('[data-count-input]');
13858:                                     for (var si = 0; si < inputs.length; si++) {
13859:                                         var dId = inputs[si].getAttribute('data-count-input');
13860:                                         var value = inputs[si].value;
13861:                                         if (value === '') continue;
13862:                                         var noteEl = document.querySelector('[data-count-note="' + dId + '"]');
13863:                                         var detail = null;
13864:                                         for (var di2 = 0; di2 < details.length; di2++) {
13865:                                             if (String(details[di2].id) === String(dId)) { detail = details[di2]; break; }
13866:                                         }
13867:                                         if (!detail) continue;
13868:                                         var countedQty = Number(value);
13869:                                         if (!Number.isFinite(countedQty) || countedQty < 0) throw new Error('كمية جرد غير صالحة للصنف ' + detail.item_code);
13870:                                         await callIC('COUNT', {
13871:                                             operation: 'UPSERT_LINE',
13872:                                             payload: {
13873:                                                 count_id: countId,
13874:                                                 branch_id: detail.branch_id,
13875:                                                 item_code: detail.item_code,
13876:                                                 counted_qty: countedQty,
13877:                                                 notes: noteEl ? (noteEl.value || '') : (detail.notes || '')
13878:                                             }
13879:                                         });
13880:                                     }
13881:                                     var reloaded = await callIC('COUNT', { operation: 'GET', payload: { count_id: countId } });
13882:                                     count = reloaded.count || count;
13883:                                     details = reloaded.details || [];
13884:                                     safeHTML(byId('ic-ce-body'), renderCountTable(byId('ic-ce-search').value));
13885:                                     updateSummary();
13886:                                     safeText(byId('ic-ce-status'), count.status || 'InProgress');
13887:                                     hideLoader();
13888:                                     showToast('تم حفظ كميات الجرد', 'success');
13889:                                 } catch (e) {
13890:                                     hideLoader();
13891:                                     showToast(e.message || 'فشل حفظ الجرد', 'error');
13892:                                 }
13893:                             };
13894: 
13895:                             byId('ic-ce-finalize').onclick = async function() {
13896:                                 var confirm = await Swal.fire({
13897:                                     title: 'إتمام وتسوية الجرد؟',
13898:                                     text: 'سيتم اعتماد الفروق وتنفيذ حركات التسوية الرسمية عبر محرك المخزون المركزي.',
13899:                                     icon: 'warning',
13900:                                     showCancelButton: true,
13901:                                     confirmButtonText: 'إتمام الجرد',
13902:                                     cancelButtonText: 'إلغاء'
13903:                                 });
13904:                                 if (!confirm.isConfirmed) return;
13905:                                 try {
13906:                                     showLoader('جاري إتمام الجرد وتنفيذ التسويات...');
13907:                                     await callIC('COUNT', { operation: 'FINALIZE', payload: { count_id: countId } });
13908:                                     hideLoader();
13909:                                     showToast('تم إتمام الجرد وتسوية الفروق بنجاح', 'success');
13910:                                     Swal.close();
13911:                                     await refreshCounts();
13912:                                     await refreshCurrentTab();
13913:                                 } catch (e) {
13914:                                     hideLoader();
13915:                                     showToast(e.message || 'فشل إتمام الجرد', 'error');
13916:                                 }
13917:                             };
13918: 
13919:                             byId('ic-ce-cancel').onclick = async function() {
13920:                                 var confirm = await Swal.fire({
13921:                                     title: 'إلغاء جلسة الجرد؟',
13922:                                     text: 'لن يتم تنفيذ أي تسوية مخزنية.',
13923:                                     showCancelButton: true,
13924:                                     confirmButtonText: 'إلغاء الجلسة',
13925:                                     cancelButtonText: 'متابعة'
13926:                                 });
13927:                                 if (!confirm.isConfirmed) return;
13928:                                 try {
13929:                                     await callIC('COUNT', { operation: 'CANCEL', payload: { count_id: countId } });
13930:                                     showToast('تم إلغاء جلسة الجرد', 'success');
13931:                                     Swal.close();
13932:                                     await refreshCounts();
13933:                                 } catch (e) {
13934:                                     showToast(e.message || 'فشل إلغاء الجلسة', 'error');
13935:                                 }
13936:                             };
13937: 
13938:                             updateSummary();
13939:                         }
13940:                     });
13941: 
13942:                     return editor;
13943:                 }
13944: 
13945:                 await openCountEditor();
13946:             } catch (e) {
13947:                 showToast(e.message || 'فشل بدء جلسة الجرد', 'error');
13948:             } finally {
13949:                 setBusy(false);
13950:             }
13951:         }
13952: 
13953:         async function cancelCount() {
13954:             var id = this.getAttribute('data-count-id');
13955:             if (!id) return;
13956:             try {
13957:                 setBusy(true, 'جاري إلغاء جلسة الجرد...');
13958:                 await callIC('COUNT', { operation: 'CANCEL', payload: { request_id: id, count_id: id } });
13959:                 showToast('تم إلغاء جلسة الجرد', 'success');
13960:                 await refreshCounts();
13961:             } catch (e) {
13962:                 showToast(e.message || 'فشل إلغاء الجرد', 'error');
13963:             } finally {
13964:                 setBusy(false);
13965:             }
13966:         }
13967: 
13968:         async function handleRequestAction() {
13969:             var id = this.getAttribute('data-req-id');
13970:             var action = this.getAttribute('data-req-action');
13971:             if (!id || !action) return;
13972:             var op = action.toUpperCase();
13973:             var payload = { request_id: id };
13974:             if (action === 'reject') {
13975:                 var r = await Swal.fire({ title: 'رفض الطلب', input: 'textarea', inputLabel: 'سبب الرفض', showCancelButton: true, confirmButtonText: 'رفض', cancelButtonText: 'إلغاء' });
13976:                 if (!r.isConfirmed) return;
13977:                 payload.reason = r.value || '';
13978:             }
13979:             try {
13980:                 setBusy(true, 'جاري تحديث طلب المخزون...');
13981:                 var d = await callIC('REQUEST', { operation: op, operation_id: null, payload: payload });
13982:                 showToast(d.duplicate ? 'تم استرجاع العملية السابقة' : 'تم تنفيذ العملية', 'success');
13983:                 await refreshRequests();
13984:             } catch (e) {
13985:                 showToast(e.message || 'فشل تحديث طلب المخزون', 'error');
13986:             } finally {
13987:                 setBusy(false);
13988:             }
13989:         }
13990: 
13991:         async function createStockRequest() {
13992:             if (state.branches.length < 2) {
13993:                 showToast('يلزم وجود فرعي مصدر ووجهة مختلفين لإنشاء طلب نقل', 'warning');
13994:                 return;
13995:             }
13996: 
13997:             var sourceOptions = '';
13998:             var targetOptions = '';
13999:             for (var i = 0; i < state.branches.length; i++) {
14000:                 var branch = state.branches[i];
14001:                 sourceOptions += '<option value="' + escIC(branch.id) + '">' + escIC(branch.name || branch.branch_code) + '</option>';
14002:                 targetOptions += '<option value="' + escIC(branch.id) + '">' + escIC(branch.name || branch.branch_code) + '</option>';
14003:             }
14004: 
14005:             var sourceRows = [];
14006:             var cart = [];
14007: 
14008:             function findSourceRow(code) {
14009:                 for (var ri = 0; ri < sourceRows.length; ri++) {
14010:                     if (String(sourceRows[ri].item_code || '') === String(code || '')) return sourceRows[ri];
14011:                 }
14012:                 return null;
14013:             }
14014: 
14015:             function cartIndex(code) {
14016:                 for (var ci = 0; ci < cart.length; ci++) {
14017:                     if (String(cart[ci].item_code || '') === String(code || '')) return ci;
14018:                 }
14019:                 return -1;
14020:             }
14021: 
14022:             function renderSearchResults(query) {
14023:                 query = String(query || '').trim().toLowerCase();
14024:                 var html = '';
14025:                 var shown = 0;
14026:                 for (var i2 = 0; i2 < sourceRows.length; i2++) {
14027:                     var x = sourceRows[i2];
14028:                     var hay = [x.item_code, x.item_name, x.barcode || ''].join(' ').toLowerCase();
14029:                     if (query && hay.indexOf(query) === -1) continue;
14030:                     if (cartIndex(x.item_code) !== -1) continue;
14031:                     html +=
14032:                         '<button type="button" data-ic-add-item="' + escIC(x.item_code) + '" class="w-full text-right p-3 rounded-xl border hover:bg-indigo-50 hover:border-indigo-200 mb-2 bg-white">' +
14033:                             '<div class="flex items-center justify-between gap-3">' +
14034:                                 '<div>' +
14035:                                     '<div class="font-black text-slate-800">' + escIC(x.item_name || x.item_code) + '</div>' +
14036:                                     '<div class="text-xs text-slate-500 mt-1">' + escIC(x.item_code) + (x.barcode ? ' • ' + escIC(x.barcode) : '') + '</div>' +
14037:                                 '</div>' +
14038:                                 '<div class="text-left">' +
14039:                                     '<div class="text-xs text-slate-500">المتاح</div>' +
14040:                                     '<div class="font-black ' + (Number(x.available_qty || 0) > 0 ? 'text-emerald-700' : 'text-red-600') + '">' + fmtIC(x.available_qty) + '</div>' +
14041:                                 '</div>' +
14042:                             '</div>' +
14043:                         '</button>';
14044:                     shown++;
14045:                     if (shown >= 25) break;
14046:                 }
14047:                 if (!html) html = '<div class="p-6 text-center text-slate-500">لا توجد أصناف مطابقة أو تم إضافتها بالفعل</div>';
14048:                 return html;
14049:             }
14050: 
14051:             function renderCart() {
14052:                 var html = '';
14053:                 var totalQty = 0;
14054:                 var totalValue = 0;
14055:                 for (var ci = 0; ci < cart.length; ci++) {
14056:                     var x = cart[ci];
14057:                     var before = Number(x.available_qty || 0);
14058:                     var after = before - Number(x.qty || 0);
14059:                     var qty = Number(x.qty || 0);
14060:                     totalQty += qty;
14061:                     totalValue += qty * Number(x.cost_price || 0);
14062:                     html +=
14063:                         '<tr class="border-b">' +
14064:                             '<td class="p-2 font-black text-indigo-700">' + escIC(x.item_code) + '</td>' +
14065:                             '<td class="p-2 font-semibold">' + escIC(x.item_name) + '</td>' +
14066:                             '<td class="p-2 text-center">' + escIC(x.unit || '') + '</td>' +
14067:                             '<td class="p-2 text-center font-bold text-slate-700">' + fmtIC(before) + '</td>' +
14068:                             '<td class="p-2 text-center"><input data-ic-req-qty="' + escIC(x.item_code) + '" type="number" min="0.001" step="0.001" value="' + escIC(qty) + '" class="w-24 px-2 py-2 border rounded-lg text-center font-black"></td>' +
14069:                             '<td class="p-2 text-center font-black ' + (after < 0 ? 'text-red-600' : 'text-emerald-700') + '">' + fmtIC(after) + '</td>' +
14070:                             '<td class="p-2 text-center">' + fmtIC(Number(x.cost_price || 0)) + '</td>' +
14071:                             '<td class="p-2 text-center font-black">' + fmtIC(qty * Number(x.cost_price || 0)) + '</td>' +
14072:                             '<td class="p-2"><button type="button" data-ic-remove-item="' + escIC(x.item_code) + '" class="px-3 py-1 rounded-lg bg-red-50 text-red-700 font-bold">حذف</button></td>' +
14073:                         '</tr>';
14074:                 }
14075:                 if (!html) html = '<tr><td colspan="10" class="p-10 text-center text-slate-500">لم تتم إضافة أصناف بعد</td></tr>';
14076:                 return { html: html, totalQty: totalQty, totalValue: totalValue };
14077:             }
14078: 
14079:             async function loadSourceSnapshot(branchId) {
14080:                 var d = await callIC('SNAPSHOT', {
14081:                     branch_id: branchId,
14082:                     query: null,
14083:                     low_only: false,
14084:                     limit: 500,
14085:                     offset: 0
14086:                 });
14087:                 sourceRows = d.rows || [];
14088:             }
14089: 
14090:             var modal = await Swal.fire({
14091:                 title: 'طلب نقل مخزني جديد',
14092:                 width: 1280,
14093:                 showConfirmButton: false,
14094:                 showCancelButton: false,
14095:                 html:
14096:                     '<div id="ic-request-editor" class="text-right">' +
14097:                         '<div class="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4">' +
14098:                             '<div>' +
14099:                                 '<label class="block text-sm font-black text-slate-700 mb-2">من المخزن</label>' +
14100:                                 '<select id="ic-r-source" class="!w-full !m-0 swal2-input">' + sourceOptions + '</select>' +
14101:                             '</div>' +
14102:                             '<div>' +
14103:                                 '<label class="block text-sm font-black text-slate-700 mb-2">إلى المخزن</label>' +
14104:                                 '<select id="ic-r-target" class="!w-full !m-0 swal2-input">' + targetOptions + '</select>' +
14105:                             '</div>' +
14106:                             '<div class="rounded-xl bg-blue-50 border border-blue-100 p-3"><div class="text-xs text-blue-700">عدد البنود</div><div id="ic-r-total-lines" class="text-xl font-black text-blue-900">0</div></div>' +
14107:                             '<div class="rounded-xl bg-emerald-50 border border-emerald-100 p-3"><div class="text-xs text-emerald-700">إجمالي الكمية</div><div id="ic-r-total-qty" class="text-xl font-black text-emerald-900">0</div></div>' +
14108:                         '</div>' +
14109:                         '<div class="grid grid-cols-1 lg:grid-cols-5 gap-4">' +
14110:                             '<div class="lg:col-span-2 rounded-2xl bg-slate-50 border p-3">' +
14111:                                 '<div class="font-black text-slate-800 mb-2">إضافة صنف</div>' +
14112:                                 '<input id="ic-r-search" class="w-full px-3 py-2 border rounded-xl bg-white" placeholder="ابحث بالكود أو الاسم أو الباركود">' +
14113:                                 '<div id="ic-r-results" class="mt-3 max-h-[48vh] overflow-auto"></div>' +
14114:                             '</div>' +
14115:                             '<div class="lg:col-span-3 rounded-2xl bg-white border">' +
14116:                                 '<div class="flex items-center justify-between p-3 border-b">' +
14117:                                     '<div class="font-black text-slate-800">بنود الطلب</div>' +
14118:                                     '<div class="text-xs text-slate-500">Available After = Available Before − Requested Qty</div>' +
14119:                                 '</div>' +
14120:                                 '<div class="overflow-auto max-h-[48vh]">' +
14121:                                     '<table class="w-full text-sm">' +
14122:                                         '<thead class="bg-slate-800 text-white sticky top-0"><tr>' +
14123:                                             '<th class="p-2">الكود</th><th class="p-2">الصنف</th><th class="p-2">الوحدة</th><th class="p-2">المتاح قبل</th><th class="p-2">الطلب</th><th class="p-2">المتاح بعد</th><th class="p-2">التكلفة</th><th class="p-2">الإجمالي</th><th class="p-2">إجراء</th>' +
14124:                                         '</tr></thead>' +
14125:                                         '<tbody id="ic-r-cart"></tbody>' +
14126:                                     '</table>' +
14127:                                 '</div>' +
14128:                             '</div>' +
14129:                         '</div>' +
14130:                         '<div class="mt-4">' +
14131:                             '<textarea id="ic-r-notes" class="w-full px-3 py-2 border rounded-xl" rows="3" placeholder="ملاحظات الطلب / سبب النقل"></textarea>' +
14132:                         '</div>' +
14133:                         '<div class="flex flex-wrap justify-end gap-2 mt-4">' +
14134:                             '<button id="ic-r-close" type="button" class="px-5 py-2 rounded-xl bg-slate-100 text-slate-700 font-bold">إغلاق</button>' +
14135:                             '<button id="ic-r-submit" type="button" class="px-5 py-2 rounded-xl bg-indigo-600 text-white font-black">إنشاء طلب النقل</button>' +
14136:                         '</div>' +
14137:                     '</div>',
14138:                 didOpen: async function() {
14139:                     function repaintCart() {
14140:                         var p = renderCart();
14141:                         safeHTML(byId('ic-r-cart'), p.html);
14142:                         safeText(byId('ic-r-total-lines'), fmtIC(cart.length));
14143:                         safeText(byId('ic-r-total-qty'), fmtIC(p.totalQty));
14144: 
14145:                         var qtyInputs = document.querySelectorAll('[data-ic-req-qty]');
14146:                         for (var qi = 0; qi < qtyInputs.length; qi++) {
14147:                             qtyInputs[qi].oninput = function() {
14148:                                 var code = this.getAttribute('data-ic-req-qty');
14149:                                 var idx = cartIndex(code);
14150:                                 if (idx === -1) return;
14151:                                 var value = Number(this.value);
14152:                                 cart[idx].qty = Number.isFinite(value) && value > 0 ? value : 0.001;
14153:                                 repaintCart();
14154:                             };
14155:                         }
14156: 
14157:                         var removeButtons = document.querySelectorAll('[data-ic-remove-item]');
14158:                         for (var rb = 0; rb < removeButtons.length; rb++) {
14159:                             removeButtons[rb].onclick = function() {
14160:                                 var code = this.getAttribute('data-ic-remove-item');
14161:                                 var idx = cartIndex(code);
14162:                                 if (idx !== -1) cart.splice(idx, 1);
14163:                                 repaintCart();
14164:                                 safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14165:                                 bindSearchButtons();
14166:                             };
14167:                         }
14168:                     }
14169: 
14170:                     function bindSearchButtons() {
14171:                         var addButtons = document.querySelectorAll('[data-ic-add-item]');
14172:                         for (var ab = 0; ab < addButtons.length; ab++) {
14173:                             addButtons[ab].onclick = function() {
14174:                                 var code = this.getAttribute('data-ic-add-item');
14175:                                 var row = findSourceRow(code);
14176:                                 if (!row) return;
14177:                                 if (cartIndex(code) !== -1) return;
14178:                                 cart.push({
14179:                                     item_code: row.item_code,
14180:                                     item_name: row.item_name,
14181:                                     unit: row.unit,
14182:                                     available_qty: Number(row.available_qty || 0),
14183:                                     qty: 1,
14184:                                     cost_price: Number(row.cost_price || row.avg_cost || 0)
14185:                                 });
14186:                                 repaintCart();
14187:                                 safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14188:                                 bindSearchButtons();
14189:                             };
14190:                         }
14191:                     }
14192: 
14193:                     byId('ic-r-source').onchange = async function() {
14194:                         var target = byId('ic-r-target').value || '';
14195:                         if (target === this.value) {
14196:                             for (var ti = 0; ti < state.branches.length; ti++) {
14197:                                 if (String(state.branches[ti].id) !== String(this.value)) {
14198:                                     target = state.branches[ti].id;
14199:                                     break;
14200:                                 }
14201:                             }
14202:                             byId('ic-r-target').value = target;
14203:                         }
14204:                         cart = [];
14205:                         try {
14206:                             showLoader('جاري تحميل رصيد الفرع المصدر...');
14207:                             await loadSourceSnapshot(this.value);
14208:                             safeHTML(byId('ic-r-results'), renderSearchResults(byId('ic-r-search').value));
14209:                             bindSearchButtons();
14210:                             repaintCart();
14211:                             hideLoader();
14212:                         } catch (e) {
14213:                             hideLoader();
14214:                             showToast(e.message || 'فشل تحميل رصيد الفرع', 'error');
14215:                         }
14216:                     };
14217: 
14218:                     byId('ic-r-target').onchange = function() {
14219:                         if (this.value === byId('ic-r-source').value) {
14220:                             showToast('المصدر والوجهة يجب أن يكونا مختلفين', 'warning');
14221:                             for (var ti2 = 0; ti2 < state.branches.length; ti2++) {
14222:                                 if (String(state.branches[ti2].id) !== String(byId('ic-r-source').value)) {
14223:                                     this.value = state.branches[ti2].id;
14224:                                     break;
14225:                                 }
14226:                             }
14227:                         }
14228:                     };
14229: 
14230:                     byId('ic-r-search').oninput = function() {
14231:                         safeHTML(byId('ic-r-results'), renderSearchResults(this.value));
14232:                         bindSearchButtons();
14233:                     };
14234: 
14235:                     byId('ic-r-close').onclick = function() { Swal.close(); };
14236: 
14237:                     byId('ic-r-submit').onclick = async function() {
14238:                         var source = byId('ic-r-source').value || '';
14239:                         var target = byId('ic-r-target').value || '';
14240:                         if (!source || !target || source === target) {
14241:                             showToast('اختر مصدرًا ووجهة مختلفين', 'warning');
14242:                             return;
14243:                         }
14244:                         if (!cart.length) {
14245:                             showToast('أضف صنفًا واحدًا على الأقل إلى الطلب', 'warning');
14246:                             return;
14247:                         }
14248:                         for (var vi = 0; vi < cart.length; vi++) {
14249:                             if (!Number.isFinite(Number(cart[vi].qty)) || Number(cart[vi].qty) <= 0) {
14250:                                 showToast('كمية غير صالحة للصنف ' + cart[vi].item_code, 'error');
14251:                                 return;
14252:                             }
14253:                         }
14254: 
14255:                         try {
14256:                             setBusy(true, 'جاري إنشاء طلب النقل وربطه بدورة المخزون...');
14257:                             var operationId = (window.crypto && window.crypto.randomUUID) ?
14258:                                 window.crypto.randomUUID() : ('SR-' + Date.now() + '-' + Math.floor(Math.random() * 100000));
14259: 
14260:                             var items = [];
14261:                             for (var ii = 0; ii < cart.length; ii++) {
14262:                                 items.push({
14263:                                     item_code: cart[ii].item_code,
14264:                                     qty: Number(cart[ii].qty)
14265:                                 });
14266:                             }
14267: 
14268:                             var d = await callIC('REQUEST', {
14269:                                 operation: 'CREATE',
14270:                                 operation_id: operationId,
14271:                                 payload: {
14272:                                     source_branch_id: source,
14273:                                     target_branch_id: target,
14274:                                     items: items,
14275:                                     notes: byId('ic-r-notes').value || ''
14276:                                 }
14277:                             });
14278: 
14279:                             Swal.close();
14280:                             showToast(d.duplicate ? 'تم استرجاع طلب النقل السابق' : 'تم إنشاء طلب النقل بنجاح', 'success');
14281:                             state.tab = 'requests';
14282:                             renderTabButtons();
14283:                             renderFilters();
14284:                             await refreshRequests();
14285:                         } catch (e) {
14286:                             showToast(e.message || 'فشل إنشاء طلب النقل', 'error');
14287:                         } finally {
14288:                             setBusy(false);
14289:                         }
14290:                     };
14291: 
14292:                     try {
14293:                         await loadSourceSnapshot(byId('ic-r-source').value);
14294:                         safeHTML(byId('ic-r-results'), renderSearchResults(''));
14295:                         bindSearchButtons();
14296:                         repaintCart();
14297:                     } catch (e2) {
14298:                         showToast(e2.message || 'فشل تحميل بيانات المخزون', 'error');
14299:                     }
14300:                 }
14301:             });
14302: 
14303:             return modal;
14304:         }
14305: 
14306:         var branchRes = await supabase.from('branches')
14307:             .select('id,branch_code,name')
14308:             .eq('company_id', companyId)
14309:             .eq('is_active', true)
14310:             .order('name');
14311:         if (branchRes.error) {
14312:             showToast(branchRes.error.message, 'error');
14313:             return;
14314:         }
14315:         state.branches = branchRes.data || [];
14316: 
14317:         renderShell();
14318:         renderTabButtons();
14319:         renderFilters();
14320:         await refreshAll();
14321: 
14322:         try {
14323:             if (window._rwInventoryControlChannel) {
14324:                 await supabase.removeChannel(window._rwInventoryControlChannel);
14325:             }
14326:             var channel = supabase.channel('rw-inventory-control-' + companyId);
14327:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'stock_branches' }, function() { refreshCurrentTab(); });
14328:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_log' }, function() { if (state.tab === 'movements') refreshCurrentTab(); else refreshSnapshot(); });
14329:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_counts' }, function() { if (state.tab === 'counts') refreshCounts(); });
14330:             channel.on('postgres_changes', { event: '*', schema: 'public', table: 'inventory_stock_requests' }, function() { if (state.tab === 'requests') refreshRequests(); });
14331:             window._rwInventoryControlChannel = channel.subscribe();
14332:         } catch (e) {}
14333:     }
14334:     return {
14335: 			loadInventoryControl: loadInventoryControl,
14336:             loadReceiving: loadReceiving,
14337:     _applyReceiving: _applyReceiving,
14338:     _showReceivingDetails: _showReceivingDetails,
14339:     loadVouchers: loadVouchers,
14340:     _applyVouchers: _applyVouchers,
14341:     _viewVoucherDetails: _viewVoucherDetails,
14342:     _sendVoucher: _sendVoucher,
14343:     _receiveVoucher: _receiveVoucher,
14344:     _openNewVoucherModal: _openNewVoucherModal,
14345:     loadVoucherForm: loadVoucherForm,
14346:     _searchVoucherItem: _searchVoucherItem,
14347:     _addVoucherItem: _addVoucherItem,
14348:     _renderVoucherCart: _renderVoucherCart,
14349:     _updateVoucherQty: _updateVoucherQty,
14350:     _updateVoucherPrice: _updateVoucherPrice,
14351:     _removeVoucherItem: _removeVoucherItem,
14352:     _clearVoucherCart: _clearVoucherCart,
14353:     _saveAndSendVoucher: _saveAndSendVoucher,
14354:     loadPicking: loadPicking,
14355:     _applyPicking: _applyPicking,
14356:     _showPickingDetails: _showPickingDetails,
14357:     loadLoading: loadLoading,
14358:     _applyLoading: _applyLoading,
14359:     _showLoadingDetails: _showLoadingDetails,
14360:     loadDelivery: loadDelivery,
14361:     _applyDelivery: _applyDelivery,
14362:     _showDeliveryDetails: _showDeliveryDetails,
14363:     loadReturn: loadReturn,
14364:     _applyReturn: _applyReturn,
14365:     _showReturnDetails: _showReturnDetails,
14366:     loadUnloading: loadUnloading,
14367:     _applyUnloading: _applyUnloading,
14368:     _showUnloadingDetails: _showUnloadingDetails,
14369:     loadVehicleCount: loadVehicleCount,
14370:     loadBranchCount: loadBranchCount,
14371:     loadGeneralCount: loadGeneralCount,
14372:     loadSettlement: loadSettlement,
14373:     _searchDriver: _searchDriver,
14374:     _selectDriver: _selectDriver,
14375:     _startBarcodeScanner: _startBarcodeScanner,
14376:     _searchInvItem: _searchInvItem,
14377:     _addToInvCart: _addToInvCart,
14378:     _renderInvCart: _renderInvCart,
14379:     _updateInvCartQty: _updateInvCartQty,
14380:     _removeInvCartItem: _removeInvCartItem,
14381:     _saveVehicleCount: _saveVehicleCount,
14382:     _saveBranchCount: _saveBranchCount,
14383:     _saveGeneralCount: _saveGeneralCount,
14384:     _saveInvCount: _saveInvCount,
14385:     _onSettlementRsChange: _onSettlementRsChange,
14386:     _saveSettlement: _saveSettlement,
14387:     _openPickingModal: _openPickingModal,
14388:     _openLoadingModal: _openLoadingModal,
14389:     _openDeliveryModal: _openDeliveryModal,
14390:     _openReturnModal: _openReturnModal,
14391:     _startPicking: _changeStatus,
14392:     _startLoading: _changeStatus,
14393:     _startDelivery: _changeStatus,
14394:     _startReturn: _changeStatus,
14395:     _confirmUnload: _confirmUnload,
14396:     _changeStatus: _changeStatus
14397:     };
14398: })();
