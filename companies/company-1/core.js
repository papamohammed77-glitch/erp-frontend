// ============================================================
// core.js – النواة المشتركة لنظام الروائع ERP (الإصدار 1.2)
// التزم بـ var و function فقط. لا تستخدم const أو let أو () =>
// هذا الملف يُحمّل مرة واحدة في كل تطبيق PWA
// ============================================================

var SUPABASE_URL = 'https://fiilmooggumokxanwiyx.supabase.co';
var SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpaWxtb29nZ3Vtb2t4YW53aXl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3MDkwOTIsImV4cCI6MjA5NDI4NTA5Mn0.LZScCxnCiRrTSCCBmTryszQpY1AwBgR2dkTBbC5kOc4';

// ✅ إنشاء عميل Supabase الموحد (إصلاح الخطأ القاتل)
var supabase = (typeof window.supabase !== 'undefined' && typeof window.supabase.createClient === 'function')
    ? window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY)
    : null;

if (!supabase) {
    console.error('❌ فشل إنشاء عميل Supabase. تأكد من تحميل مكتبة supabase أولاً.');
}

// ============================================================
// الوحدة ١: RW_Auth – المصادقة والجلسة والصلاحيات
// ============================================================
var RW_Auth = (function() {
    var currentUser = null;
    var currentProfile = null;
    var currentSession = null;
    var pubUserId = null;

    function normalizePermissions(value) {
        if (!Array.isArray(value)) return [];
        var out = [];
        for (var i = 0; i < value.length; i++) {
            var permission = String(value[i] == null ? '' : value[i]).trim();
            if (permission && out.indexOf(permission) === -1) out.push(permission);
        }
        return out;
    }

    function clearState() {
        currentUser = null;
        currentProfile = null;
        currentSession = null;
        pubUserId = null;
    }

    // Keep the shared session snapshot current when supabase-js refreshes the access token.
    // This callback must remain synchronous; do not call Supabase auth methods from it.
    if (supabase && supabase.auth && typeof supabase.auth.onAuthStateChange === 'function') {
        supabase.auth.onAuthStateChange(function(event, session) {
            if (session) {
                if (currentUser && session.user && currentUser.id !== session.user.id) {
                    currentProfile = null;
                    pubUserId = null;
                }
                currentSession = session;
                currentUser = session.user || null;
            } else if (event === 'SIGNED_OUT') {
                clearState();
            }
        });
    }
    function toClientUser(profile) {
        var p = profile || currentProfile || {};
        return {
            id: p.id || pubUserId || null,
            auth_id: p.auth_id || (currentUser ? currentUser.id : null),
            company_id: p.company_id || null,
            email: p.email || (currentUser ? currentUser.email : null),
            name: p.name || (currentUser ? currentUser.email : null),
            role: p.role || 'موظف',
            isOwner: p.isOwner === true || p.isOwner === 'true',
            permissions: normalizePermissions(p.permissions),
            activeWarehouseRole: p.active_warehouse_role || p.activeWarehouseRole || '',
            defaultBranchId: p.default_branch_id || null,
            allowedBranchIds: p.allowed_branch_ids || null,
            session: currentSession
        };
    }

    function hydrateProfile(callback) {
        if (!supabase || !currentUser || !currentUser.id) {
            if (callback) callback(null, 'جلسة غير صالحة');
            return;
        }

        supabase.rpc('get_my_effective_profile').then(function(result) {
            if (result.error) {
                if (callback) callback(null, 'تعذر تحميل ملف المستخدم وصلاحياته: ' + result.error.message);
                return;
            }

            var profile = result.data;
            if (!profile || !profile.id || !profile.company_id) {
                if (callback) callback(null, 'لا يوجد سجل مستخدم صالح مرتبط بحساب المصادقة');
                return;
            }

            if (profile.status && String(profile.status).toLowerCase() !== 'active') {
                if (callback) callback(null, 'حساب المستخدم غير نشط');
                return;
            }

            currentProfile = {
                id: profile.id,
                auth_id: profile.auth_id || currentUser.id,
                company_id: profile.company_id,
                email: profile.email || currentUser.email,
                name: profile.name || currentUser.email,
                role: profile.role || 'موظف',
                status: profile.status || 'Active',
                isOwner: profile.isOwner === true || profile.isOwner === 'true',
                permissions: normalizePermissions(profile.permissions),
                active_warehouse_role: profile.active_warehouse_role || '',
                default_branch_id: profile.default_branch_id || null,
                allowed_branch_ids: profile.allowed_branch_ids || null
            };
            pubUserId = profile.id;

            if (callback) callback(toClientUser(currentProfile), null);
        }).catch(function(error) {
            if (callback) callback(
                null,
                'فشل تحميل ملف المستخدم: ' +
                (error && error.message ? error.message : 'خطأ غير معروف')
            );
        });
    }

    function init(callback) {
        if (!supabase) {
            if (callback) callback(null, 'Supabase غير مهيأ');
            return;
        }

        supabase.auth.getSession().then(function(result) {
            if (!result.data || !result.data.session) {
                clearState();
                if (callback) callback(null, 'NO_SESSION');
                return;
            }

            currentSession = result.data.session;
            currentUser = result.data.session.user;
            hydrateProfile(callback);
        }).catch(function(error) {
            if (callback) callback(
                null,
                error && error.message ? error.message : 'فشل استعادة الجلسة'
            );
        });
    }

    function doLogin(email, pass, callback) {
        if (!email || !pass) {
            if (callback) callback(null, 'أدخل البريد الإلكتروني وكلمة المرور');
            return;
        }

        supabase.auth.signInWithPassword({ email: email, password: pass }).then(function(result) {
            if (result.error) {
                if (callback) callback(null, result.error.message);
                return;
            }

            currentSession = result.data.session;
            currentUser = result.data.session.user;

            hydrateProfile(function(user, error) {
                if (error || !user) {
                    supabase.auth.signOut({ scope: 'local' }).then(function() {
                        clearState();
                        if (callback) callback(null, error || 'تعذر تحميل صلاحيات المستخدم');
                    }).catch(function() {
                        clearState();
                        if (callback) callback(null, error || 'تعذر تحميل صلاحيات المستخدم');
                    });
                    return;
                }

                if (callback) callback(user, null);
            });
        }).catch(function(error) {
            if (callback) callback(
                null,
                error && error.message ? error.message : 'فشل تسجيل الدخول'
            );
        });
    }

    function doLogout(callback) {
        if (!supabase) {
            clearState();
            if (callback) callback(true);
            return;
        }

        supabase.auth.signOut({ scope: 'local' }).then(function() {
            clearState();
            if (callback) callback(true);
        }).catch(function(error) {
            console.error('فشل تسجيل الخروج:', error);
            clearState();
            if (callback) callback(false);
        });
    }

    function getUser() {
        if (currentProfile) return toClientUser(currentProfile);
        return {
            id: pubUserId,
            auth_id: currentUser ? currentUser.id : null,
            company_id: null,
            email: currentUser ? currentUser.email : null,
            name: currentUser ? (
                currentUser.user_metadata ? currentUser.user_metadata.name : currentUser.email
            ) : null,
            role: 'موظف',
            isOwner: false,
            permissions: [],
            activeWarehouseRole: '',
            session: currentSession
        };
    }

    function getToken() {
        return currentSession ? currentSession.access_token : null;
    }

    function checkPermission(permissionKey) {
        if (!currentProfile) return false;
        if (currentProfile.isOwner) return true;
        var permissions = normalizePermissions(currentProfile.permissions);
        if (permissions.indexOf('*') !== -1) return true;
        return permissions.indexOf(permissionKey) !== -1;
    }

    function hasWarehouseRole(roleName) {
        if (!currentProfile) return false;
        if (currentProfile.isOwner) return true;

        var activeRole = '';
        try {
            activeRole = window._rwActiveRole ||
                currentProfile.active_warehouse_role || '';
        } catch (error) {
            activeRole = currentProfile.active_warehouse_role || '';
        }
        return activeRole === roleName;
    }

    return {
        init: init,
        doLogin: doLogin,
        doLogout: doLogout,
        getUser: getUser,
        getToken: getToken,
        checkPermission: checkPermission,
        hasWarehouseRole: hasWarehouseRole
    };
})();

// ============================================================
// الوحدة ٢: RW_DB – غلاف Dexie.js للتخزين المحلي
// ============================================================
var RW_DB = (function() {
    var dbInstances = {};

function getDB(appName) {
    if (dbInstances[appName]) {
        return dbInstances[appName];
    }
    if (typeof Dexie === 'undefined') {
        console.error('❌ Dexie.js غير محمّل');
        return null;
    }
    var db = new Dexie('RW_' + appName);
    var schema = {
        customers: 'customer_code, name, area, phone, visit_day',
        items: 'item_code, id, name, sales_price, unit, max_qty, barcode, category, image_url',
        stock: '[item_id+branch_id], branch_id, item_id, qty, allocated_qty',
        branches: 'branch_code, name',
        meta: 'key',
        orders: '++id, status, created_at',
        pending_updates: '++id, type, status'
    };
    if (appName === 'VanSales') {
        schema.myCustomers = 'customer_code, name, area, phone, totalDebt, lastOrderDate, orderCount';
        schema.customerPatterns = '++id, customer_code, item_code, frequency, avgQty, item_name';
    }
    if (appName === 'VanSales') {
    db.version(2).stores(schema);

    var originalItemsGet = db.items.get.bind(db.items);

    db.items.get = function(key) {
        return originalItemsGet(key).then(function(item) {
            if (item || key == null) return item;
            return db.items.where('id').equals(String(key)).first();
        });
    };
} else {
    db.version(1).stores(schema);
}
    dbInstances[appName] = db;
    return db;
}

    function syncDown(appName, callback) {
        var db = getDB(appName);
        if (!db) {
            if (callback) callback(false, 'Dexie غير مهيأ');
            return;
        }
        Promise.all([
            supabase.from('customers').select('*').then(function(r) { return db.customers.clear().then(function() { return db.customers.bulkPut(r.data || []); }); }),
            supabase.from('items').select('*').then(function(r) { return db.items.clear().then(function() { return db.items.bulkPut(r.data || []); }); }),
            supabase.from('stock_branches').select('*').then(function(r) { return db.stock.clear().then(function() { return db.stock.bulkPut(r.data || []); }); }),
            supabase.from('branches').select('*').then(function(r) { return db.branches.clear().then(function() { return db.branches.bulkPut(r.data || []); }); })
        ]).then(function() {
            if (callback) callback(true, null);
        }).catch(function(e) {
            console.error('❌ فشل syncDown:', e);
            if (callback) callback(false, e.message);
        });
    }

    function syncUp(appName, callback) {
        var db = getDB(appName);
        if (!db) {
            if (callback) callback(false, 'Dexie غير مهيأ');
            return;
        }
        db.pending_updates.where('status').equals('pending').toArray().then(function(pendingOps) {
            if (!pendingOps || pendingOps.length === 0) {
                if (callback) callback(true, null, 0);
                return;
            }
            var totalOps = pendingOps.length;
            var completedOps = 0;
            var hasError = false;
            var lastError = null;

            for (var i = 0; i < pendingOps.length; i++) {
                var op = pendingOps[i];
                (function(operation) {
                    var token = RW_Auth.getToken();
                    if (!token) {
                        hasError = true;
                        lastError = 'انتهت الجلسة';
                        completedOps++;
                        checkDone();
                        return;
                    }
                    var bodyData = operation.data || operation.body || {};
                    fetch(SUPABASE_URL + '/functions/v1/' + operation.type, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer ' + token
                        },
                        body: JSON.stringify(bodyData)
                    }).then(function(res) {
                        if (!res.ok) {
                            return res.json().then(function(err) {
                                throw new Error(err.msg || err.error || 'خطأ في الخادم');
                            });
                        }
                        return res.json();
                    }).then(function(json) {
                        if (json.success) {
                            db.pending_updates.delete(operation.id).then(function() {
                                completedOps++;
                                checkDone();
                            }).catch(function() {
                                completedOps++;
                                checkDone();
                            });
                        } else {
                            hasError = true;
                            lastError = json.msg || 'فشل المزامنة';
                            completedOps++;
                            checkDone();
                        }
                    }).catch(function(e) {
                        hasError = true;
                        lastError = e.message || 'فشل الاتصال';
                        completedOps++;
                        checkDone();
                    });
                })(op);
            }

            function checkDone() {
                if (completedOps >= totalOps) {
                    if (callback) callback(!hasError, hasError ? lastError : null, totalOps);
                }
            }
        }).catch(function(e) {
            if (callback) callback(false, e.message);
        });
    }

    function getItems(appName, callback) {
        var db = getDB(appName);
        if (!db) {
            if (callback) callback([], 'Dexie غير مهيأ');
            return;
        }
        db.items.toArray().then(function(items) {
            if (callback) callback(items, null);
        }).catch(function(e) {
            if (callback) callback([], e.message);
        });
    }

    function getCustomers(appName, callback) {
        var db = getDB(appName);
        if (!db) {
            if (callback) callback([], 'Dexie غير مهيأ');
            return;
        }
        db.customers.toArray().then(function(customers) {
            if (callback) callback(customers, null);
        }).catch(function(e) {
            if (callback) callback([], e.message);
        });
    }

    function getBranches(appName, callback) {
        var db = getDB(appName);
        if (!db) {
            if (callback) callback([], 'Dexie غير مهيأ');
            return;
        }
        db.branches.toArray().then(function(branches) {
            if (callback) callback(branches, null);
        }).catch(function(e) {
            if (callback) callback([], e.message);
        });
    }

    return {
        getDB: getDB,
        syncDown: syncDown,
        syncUp: syncUp,
        getItems: getItems,
        getCustomers: getCustomers,
        getBranches: getBranches
    };
})();

// ============================================================
// الوحدة ٣: RW_API – استدعاء Edge Functions بـ fetch اليدوي
// ============================================================
var RW_API = (function() {
    function call(functionName, body, callback) {
        var token = RW_Auth.getToken();
        if (!token) {
            if (callback) callback({ success: false, msg: 'انتهت الجلسة. يرجى إعادة تسجيل الدخول.' }, null);
            return;
        }
        fetch(SUPABASE_URL + '/functions/v1/' + functionName, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + token
            },
            body: JSON.stringify(body || {})
        }).then(function(res) {
            if (!res.ok) {
                return res.json().then(function(err) {
                    throw new Error(err.msg || err.error || 'خطأ في الخادم');
                });
            }
            return res.json();
        }).then(function(json) {
            if (callback) callback(json, null);
        }).catch(function(e) {
            console.error('❌ فشل استدعاء ' + functionName + ':', e.message);
            if (callback) callback({ success: false, msg: e.message || 'فشل الاتصال بـ Edge Function' }, e.message);
        });
    }

    function callWithRetry(functionName, body, retries, callback) {
        var maxRetries = retries || 2;
        var attempt = 0;

        function tryCall() {
            call(functionName, body, function(json, err) {
                if (err && attempt < maxRetries) {
                    attempt++;
                    console.warn('⚠️ محاولة ' + attempt + ' فشلت لـ ' + functionName + '، إعادة المحاولة...');
                    setTimeout(tryCall, 1000);
                } else {
                    if (callback) callback(json, err);
                }
            });
        }

        tryCall();
    }

    return {
        call: call,
        callWithRetry: callWithRetry
    };
})();

// ============================================================
// الوحدة ٤: RW_UI – دوال واجهة المستخدم المشتركة
// ============================================================
var RW_UI = (function() {
    function toast(message, type) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                toast: true,
                position: 'top',
                icon: type || 'info',
                title: message,
                showConfirmButton: false,
                timer: 2000,
                customClass: { popup: '!rounded-2xl !shadow-xl' }
            });
        } else {
            try { alert(message); } catch(e) {}
        }
    }

    function showLoader(message) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: message || 'جاري التحميل...',
                allowOutsideClick: false,
                didOpen: function() { Swal.showLoading(); }
            });
        }
    }

    function hideLoader() {
        if (typeof Swal !== 'undefined') {
            Swal.close();
        }
    }

    function showError(message, callback) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: 'خطأ',
                text: message || 'حدث خطأ غير معروف',
                icon: 'error',
                confirmButtonText: 'حسناً',
                customClass: { popup: '!rounded-3xl' }
            }).then(function() {
                if (callback) callback();
            });
        } else {
            try { alert(message); } catch(e) {}
            if (callback) callback();
        }
    }

    function showConfirm(message, confirmCallback, cancelCallback) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: 'تأكيد',
                text: message,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: 'نعم',
                cancelButtonText: 'إلغاء',
                customClass: {
                    popup: '!rounded-3xl',
                    confirmButton: '!rounded-xl !bg-blue-600 !px-8',
                    cancelButton: '!rounded-xl !px-8'
                }
            }).then(function(result) {
                if (result.isConfirmed && confirmCallback) confirmCallback();
                else if (!result.isConfirmed && cancelCallback) cancelCallback();
            });
        } else {
            if (confirm('تأكيد: ' + message)) {
                if (confirmCallback) confirmCallback();
            } else {
                if (cancelCallback) cancelCallback();
            }
        }
    }

    function formatCurrency(amount, currency) {
        var num = Number(amount || 0);
        var symbol = 'ر.س';
        if (currency === 'SAR') symbol = 'ر.س';
        else if (currency === 'EGP') symbol = 'ج.م';
        else if (currency === 'AED') symbol = 'د.إ';
        else if (currency === 'KWD') symbol = 'د.ك';
        else if (currency === 'QAR') symbol = 'ر.ق';
        else if (currency === 'BHD') symbol = 'د.ب';
        else if (currency === 'OMR') symbol = 'ر.ع';
        else if (currency === 'USD') symbol = '$';
        return num.toLocaleString('ar-EG', { minimumFractionDigits: 2 }) + ' ' + symbol;
    }

    function formatNumber(num) {
        return Number(num || 0).toLocaleString('ar-EG', { minimumFractionDigits: 2 });
    }

    function safeHTML(element, html) {
        if (element) {
            try { element.innerHTML = html; } catch(e) { console.error('safeHTML error:', e); }
        }
    }

    function safeText(element, text) {
        if (element) {
            try { element.textContent = text; } catch(e) { console.error('safeText error:', e); }
        }
    }

    function byId(id) {
        return document.getElementById(id);
    }

    function showSkeleton(containerId, count, type) {
        var container = byId(containerId);
        if (!container) return;
        var html = '';
        var height = 'h-32';
        var width = 'w-full';
        if (type === 'card') {
            height = 'h-14';
            width = 'w-full';
        } else if (type === 'grid') {
            height = 'h-32';
            width = 'w-full';
        }
        for (var i = 0; i < (count || 3); i++) {
            html += '<div class="skeleton ' + height + ' ' + width + ' mb-3"></div>';
        }
        safeHTML(container, html);
    }

    function showEmptyState(containerId, message, emoji) {
        var container = byId(containerId);
        if (!container) return;
        var msg = message || 'لا توجد بيانات';
        var emj = emoji || '☕';
        safeHTML(container, '<div class="text-center py-12"><div class="text-6xl mb-4">' + emj + '</div><p class="text-slate-400 font-bold">' + msg + '</p></div>');
    }

    function updateConnectionStatus(dotId, labelId) {
        var dot = byId(dotId);
        var label = byId(labelId);
        if (navigator.onLine) {
            if (dot) { dot.className = 'w-2.5 h-2.5 rounded-full bg-emerald-400'; }
            if (label) { label.innerText = 'متصل'; }
        } else {
            if (dot) { dot.className = 'w-2.5 h-2.5 rounded-full bg-red-500'; }
            if (label) { label.innerText = 'غير متصل'; }
        }
    }

    return {
        toast: toast,
        showLoader: showLoader,
        hideLoader: hideLoader,
        showError: showError,
        showConfirm: showConfirm,
        formatCurrency: formatCurrency,
        formatNumber: formatNumber,
        safeHTML: safeHTML,
        safeText: safeText,
        byId: byId,
        showSkeleton: showSkeleton,
        showEmptyState: showEmptyState,
        updateConnectionStatus: updateConnectionStatus
    };
})();

// ============================================================
// الوحدة ٥: RW_ImageCache – كاش صور المنتجات
// ============================================================
var RW_ImageCache = (function() {
    var cache = {};

    function loadAll(callback) {
        supabase.from('items').select('item_code, image_url').then(function(res) {
            var items = res.data || [];
            for (var i = 0; i < items.length; i++) {
                if (items[i].item_code && items[i].image_url) {
                    cache[items[i].item_code] = items[i].image_url;
                }
            }
            if (callback) callback();
        }).catch(function(e) {
            console.error('❌ فشل تحميل كاش الصور:', e);
            if (callback) callback();
        });
    }

    function getImageUrl(itemCode) {
        return cache[itemCode] || '';
    }

    function getImageHTML(itemCode, widthClass, heightClass) {
        var url = cache[itemCode] || '';
        var w = widthClass || 'w-14';
        var h = heightClass || 'h-14';
        if (url) {
            return '<img src="' + url + '" class="' + w + ' ' + h + ' rounded-2xl object-cover border-2 border-white shadow-sm" onerror="this.style.display=\'none\'">';
        }
        return '<div class="' + w + ' ' + h + ' bg-gradient-to-br from-slate-100 to-slate-200 rounded-2xl flex items-center justify-center text-slate-400"><i class="fa-solid fa-box"></i></div>';
    }

    function clearCache() {
        cache = {};
    }

    return {
        loadAll: loadAll,
        getImageUrl: getImageUrl,
        getImageHTML: getImageHTML,
        clearCache: clearCache
    };
})();

// ============================================================
// الوحدة ٦: RW_SW – تسجيل Service Worker وكشف التحديثات (محدثة)
// ============================================================
var RW_SW = (function() {
    
    // 💡 اللمسة العبقرية: الاستماع الصامت لرسالة الـ Service Worker الجديد
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'RW_SW_UPDATED') {
                console.log('[RW_SW] تم رصد إصدار جديد، جاري التحديث التلقائي...');
                
                // عرض إشعار أنيق يختفي بسرعة ثم يُحدث الصفحة
                if (typeof Swal !== 'undefined') {
                    Swal.fire({
                        toast: true,
                        position: 'top',
                        icon: 'success',
                        title: 'تم تحديث النظام لآخر إصدار 🚀',
                        showConfirmButton: false,
                        timer: 1500,
                        customClass: { popup: '!rounded-2xl !shadow-xl' }
                    }).then(function() {
                        window.location.reload(true);
                    });
                } else {
                    window.location.reload(true);
                }
            }
        });
    }

    function register(swPath, callback) {
        if (!('serviceWorker' in navigator)) {
            if (callback) callback(false, 'المتصفح لا يدعم Service Worker');
            return;
        }
        var path = swPath || '../sw.js';
        navigator.serviceWorker.register(path).then(function(reg) {
            // تم تخفيف الكود هنا لأن الاعتماد أصبح على حدث 'message' في الأعلى
            // والذي يعتبر أسرع وأدق مع استراتيجية self.skipWaiting
            if (callback) callback(true, null);
        }).catch(function(err) {
            console.error('❌ فشل تسجيل Service Worker:', err);
            if (callback) callback(false, err.message);
        });
    }

    return {
        register: register
    };
})();
// ============================================================
// دوال مساعدة عامة (متوافقة مع جميع التطبيقات)
// ============================================================
function fmtNum(n) {
    return Number(n || 0).toLocaleString('ar-EG', { minimumFractionDigits: 2 });
}

function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

console.log('✅ core.js – النواة المشتركة للروائع ERP – تم التحميل بنجاح');

// ============================================================
// الوحدة ٧: RW_Realtime – محرك أحداث موحد للتطبيقات التشغيلية
// مصدره العقد المعتمد في Current/PWA/core.js؛ نطاق الشركة يتحقق من RW_Auth.
// ============================================================
// الوحدة ٧: RW_Realtime – محرك أحداث موحد للتطبيقات التشغيلية
// لا يقرأ الحدث كحقيقة أعمال؛ كل مستهلك يعيد الجلب عبر RLS.
// ============================================================
var RW_Realtime = (function() {
    var active = {};
    var serial = 0;
    var authListener = null;

    function safePart(value) {
        return String(value || '').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 48);
    }

    function notifyStatus(state, status, error) {
        state.status = status;
        if (typeof state.onStatus === 'function') {
            try { state.onStatus({ appId: state.appId, status: status, error: error || null }); }
            catch (e) { console.error('[RW_Realtime] onStatus failed:', e); }
        }
    }

    function reconcile(state, reason) {
        if (state.stopped || typeof state.onReconcile !== 'function') return;
        try {
            Promise.resolve(state.onReconcile({ source: reason || 'reconcile', appId: state.appId }))
                .catch(function(e) { console.error('[RW_Realtime] reconciliation failed:', e); });
        } catch (e) {
            console.error('[RW_Realtime] reconciliation failed:', e);
        }
    }

    function queueEvent(state, table, eventName, payload) {
        if (state.stopped) return;
        if (typeof document !== 'undefined' && document.hidden) {
            state.needsReconcile = true;
            return;
        }
        if (state.pending[table]) clearTimeout(state.pending[table]);
        state.pending[table] = setTimeout(function() {
            delete state.pending[table];
            if (state.stopped || typeof state.onEvent !== 'function') return;
            try {
                state.onEvent({
                    table: table,
                    event: eventName,
                    commitTimestamp: payload && payload.commit_timestamp ? payload.commit_timestamp : null,
                    source: 'realtime',
                    appId: state.appId
                });
            } catch (e) {
                console.error('[RW_Realtime] event consumer failed:', table, e);
            }
        }, state.debounceMs);
    }

    function normalizeTables(tables) {
        var result = [];
        var seen = {};
        (tables || []).forEach(function(entry) {
            var spec = typeof entry === 'string' ? { name: entry } : entry;
            if (!spec || !/^[a-z][a-z0-9_]*$/.test(spec.name || '') || seen[spec.name]) return;
            seen[spec.name] = true;
            var events = Array.isArray(spec.events) && spec.events.length
                ? spec.events.filter(function(eventName) {
                    return ['INSERT', 'UPDATE'].indexOf(eventName) !== -1;
                })
                : ['INSERT', 'UPDATE'];
            if (!events.length) events = ['INSERT', 'UPDATE'];
            result.push({
                name: spec.name,
                companyColumn: spec.companyColumn !== false,
                events: events
            });
        });
        return result;
    }

    function start(config) {
        config = config || {};
        if (!supabase || typeof supabase.channel !== 'function') return false;
        if (!config.appId || !config.companyId || typeof config.onEvent !== 'function') return false;
        // Tenant scope must come from the verified public profile, never caller metadata.
        var verifiedUser = (typeof RW_Auth !== 'undefined' && RW_Auth && typeof RW_Auth.getUser === 'function')
            ? RW_Auth.getUser() : null;
        if (!verifiedUser || !verifiedUser.company_id ||
            String(verifiedUser.company_id) !== String(config.companyId)) return false;

        var tables = normalizeTables(config.tables);
        if (!tables.length) return false;

        var key = safePart(config.appId) + ':' + safePart(config.companyId);
        if (active[key]) stop(key);

        var state = {
            key: key,
            appId: String(config.appId),
            companyId: String(config.companyId),
            tables: tables,
            onEvent: config.onEvent,
            onStatus: config.onStatus,
            onReconcile: config.onReconcile,
            debounceMs: Math.max(100, Number(config.debounceMs) || 350),
            reconcileMs: Math.max(15000, Number(config.reconcileMs) || 60000),
            pending: {},
            channel: null,
            status: 'CONNECTING',
            wasSubscribed: false,
            needsReconcile: false,
            stopped: false
        };

        if (!authListener && supabase.auth && typeof supabase.auth.onAuthStateChange === 'function') {
            authListener = supabase.auth.onAuthStateChange(function(event, session) {
                if (session && session.access_token && supabase.realtime &&
                    typeof supabase.realtime.setAuth === 'function') {
                    supabase.realtime.setAuth(session.access_token);
                }
                if (event === 'SIGNED_OUT') stopAll();
            });
        }

        var channelName = 'rw-core-' + safePart(state.appId) + '-' +
            safePart(state.companyId) + '-' + (++serial);
        var channel = supabase.channel(channelName);

        tables.forEach(function(spec) {
            spec.events.forEach(function(eventName) {
                var filter = {
                    event: eventName,
                    schema: 'public',
                    table: spec.name
                };
                if (spec.companyColumn) {
                    filter.filter = 'company_id=eq.' + state.companyId;
                }
                channel.on('postgres_changes', filter, function(payload) {
                    queueEvent(state, spec.name, eventName, payload);
                });
            });
        });

        state.channel = channel;
        active[key] = state;
        channel.subscribe(function(status, error) {
            if (state.stopped) return;
            notifyStatus(state, status, error);
            if (status === 'SUBSCRIBED') {
                // Reconcile once after the initial channel is live to close the fetch/subscribe race.
                reconcile(state, state.wasSubscribed || state.needsReconcile ? 'reconnected' : 'initial');
                state.wasSubscribed = true;
                state.needsReconcile = false;
            }
        });

        if (typeof state.onReconcile === 'function') {
            state.reconcileTimer = setInterval(function() {
                if (!state.stopped && !(typeof document !== 'undefined' && document.hidden)) {
                    reconcile(state, 'periodic');
                } else {
                    state.needsReconcile = true;
                }
            }, state.reconcileMs);
        }

        if (typeof document !== 'undefined' && !state.visibilityHandler) {
            state.visibilityHandler = function() {
                if (!document.hidden && state.needsReconcile) {
                    state.needsReconcile = false;
                    reconcile(state, 'visibility');
                }
            };
            document.addEventListener('visibilitychange', state.visibilityHandler);
        }

        return key;
    }

    function stop(key) {
        var state = active[key];
        if (!state) return false;
        state.stopped = true;
        Object.keys(state.pending).forEach(function(table) {
            clearTimeout(state.pending[table]);
        });
        if (state.reconcileTimer) clearInterval(state.reconcileTimer);
        if (state.visibilityHandler && typeof document !== 'undefined') {
            document.removeEventListener('visibilitychange', state.visibilityHandler);
        }
        delete active[key];
        try {
            if (state.channel && supabase && typeof supabase.removeChannel === 'function') {
                supabase.removeChannel(state.channel);
            }
        } catch (e) {
            console.warn('[RW_Realtime] channel cleanup failed:', e);
        }
        return true;
    }

    function stopAll() {
        Object.keys(active).forEach(function(key) { stop(key); });
    }

    function getStatus(key) {
        return active[key] ? active[key].status : 'STOPPED';
    }

    return {
        start: start,
        stop: stop,
        stopAll: stopAll,
        getStatus: getStatus
    };
})();



/* RW_EmployeeCustody — direct self-only RLS reads and ownership-checked RPCs. */
var RW_EmployeeCustody=(function(){
 var state={root:null,channel:null,snapshot:null,serial:0};
 function esc(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
 function money(v,c){return Number(v||0).toLocaleString('ar-EG',{minimumFractionDigits:2,maximumFractionDigits:2})+' '+esc(c||'EGP');}
 function user(){var u=RW_Auth&&RW_Auth.getUser?RW_Auth.getUser():null;if(!u||!u.id||!u.company_id)throw Error('تعذر التحقق من هوية الموظف ونطاق الشركة');return u;}
 function rows(r){if(!r||r.error)throw Error(r&&r.error?r.error.message:'فشل تحميل بيانات العهدة');return r.data||[];}
 function notice(m,t){if(RW_UI&&RW_UI.toast)RW_UI.toast(m,t||'info');else Swal.fire({toast:true,position:'top',icon:t||'info',title:m,timer:2500,showConfirmButton:false});}
 function fail(x){var m=x&&x.message?x.message:String(x||'خطأ غير معروف');if(RW_UI&&RW_UI.showError)RW_UI.showError(m);else Swal.fire({icon:'error',title:'تعذر تنفيذ العملية',text:m});}
 function opId(){return window.crypto&&crypto.randomUUID?crypto.randomUUID():'custody-'+Date.now()+'-'+Math.random().toString(36).slice(2,12);}
 function load(){
  var u=user();
  return Promise.all([
   supabase.from('buyer_custodies').select('*').eq('company_id',u.company_id).eq('employee_id',u.id).order('issued_date',{ascending:false}).limit(100),
   supabase.from('buyer_custody_advances').select('*').eq('company_id',u.company_id).eq('employee_id',u.id).order('advance_date',{ascending:false}).limit(300),
   supabase.from('buyer_custody_expenses').select('*').eq('company_id',u.company_id).eq('employee_id',u.id).order('expense_date',{ascending:false}).limit(300)
  ]).then(function(r){
   var c=rows(r[0]),a=rows(r[1]),e=rows(r[2]),ids=c.map(function(x){return x.id;}).filter(Boolean);
   if(!ids.length)return {user:u,custodies:c,advances:a,expenses:e,settlements:[]};
   return Promise.all([
    supabase.from('buyer_custody_settlements').select('*').eq('company_id',u.company_id).in('custody_id',ids).limit(200),
    supabase.from('buyer_custody_payments').select('*').eq('company_id',u.company_id).in('custody_id',ids).limit(300)
   ]).then(function(x){return {user:u,custodies:c,advances:a,expenses:e,settlements:rows(x[0]),payments:rows(x[1])};});
  }).then(function(x){state.snapshot=x;return x;});
 }
 function status(s){return ({Issued:'صادرة',UnderReview:'قيد المراجعة',Settled:'تمت التسوية',Closed:'مغلقة',Submitted:'مرسلة للمالية',Approved:'معتمدة',Rejected:'مرفوضة'})[s]||s||'—';}
 function draw(s){
  var c=s.custodies||[],a=s.advances||[],e=s.expenses||[];
  var open=c.filter(function(x){return x.status!=='Settled'&&x.status!=='Closed';}).length;
  var rec=a.filter(function(x){return !!x.acknowledged_at;}).reduce(function(n,x){return n+Number(x.amount||0);},0);
  var wait=a.filter(function(x){return !x.acknowledged_at;}).reduce(function(n,x){return n+Number(x.amount||0);},0);
  var pend=e.filter(function(x){return x.status==='Submitted';}).reduce(function(n,x){return n+Number(x.amount||0);},0);
  var html='<div class="p-4 space-y-4"><div class="flex justify-between items-center gap-2"><div><h2 class="text-xl font-black">عهدتي النقدية</h2><p class="text-xs text-slate-500 mt-1">منفصلة عن رصيد السيارة وحيازة البضاعة</p></div><button data-ec-refresh class="px-3 py-2 rounded-xl bg-sky-50 text-sky-700 text-xs font-bold">تحديث</button></div>'+
   '<div class="grid grid-cols-2 gap-2"><div class="card"><small>العهد المفتوحة</small><b class="block text-xl mt-1">'+open+'</b></div><div class="card"><small>نقدية مؤكدة الاستلام</small><b class="block text-sm mt-2">'+money(rec,c[0]&&c[0].currency)+'</b></div><div class="card"><small>زيادات تنتظر تأكيدك</small><b class="block text-sm mt-2">'+money(wait,c[0]&&c[0].currency)+'</b></div><div class="card"><small>مصروفات قيد المراجعة</small><b class="block text-sm mt-2">'+money(pend,c[0]&&c[0].currency)+'</b></div></div>'+
   '<div class="rounded-xl border border-sky-100 bg-sky-50 text-sky-900 p-3 text-xs leading-6">إقرار استلام النقدية هو الذي يثبت الصرف الفعلي من الخزينة. تقديم الإيصال لا يرحّل مصروفًا؛ الاعتماد من المالية هو الذي ينشئ قيد المصروف.</div>';
  if(!c.length)html+='<div class="card text-center py-10"><i class="fa-solid fa-wallet text-4xl text-slate-300"></i><p class="font-black mt-3">لا توجد عهد نقدية مسجلة باسمك</p><p class="text-xs text-slate-500 mt-2">ستظهر هنا العهد التي تصدرها المالية باسم حسابك.</p></div>';
  c.forEach(function(x){
   var aa=a.filter(function(z){return z.custody_id===x.id;}),ee=e.filter(function(z){return z.custody_id===x.id;}),ss=(s.settlements||[]).filter(function(z){return z.custody_id===x.id;});
   var confirmed=aa.filter(function(z){return !!z.acknowledged_at;}).reduce(function(n,z){return n+Number(z.amount||0);},0);
   var pending=ee.filter(function(z){return z.status==='Submitted';}).reduce(function(n,z){return n+Number(z.amount||0);},0);
   var approved=ee.filter(function(z){return z.status==='Approved';}).reduce(function(n,z){return n+Number(z.amount||0);},0);
   html+='<section class="card space-y-3"><div class="flex justify-between gap-2"><div><b>'+esc(x.custody_code)+'</b><p class="text-xs text-slate-500 mt-1">'+esc(x.purpose)+'</p><p class="text-xs text-slate-400 mt-1">'+esc(x.issued_date||'')+'</p></div><span class="text-[11px] rounded-lg px-2 py-1 bg-slate-100 font-bold">'+esc(x.acknowledged_at?status(x.status):'بانتظار إقرارك')+'</span></div>'+
    '<div class="grid grid-cols-2 gap-2 text-xs"><div class="bg-slate-50 p-3 rounded-xl"><small>إجمالي العهدة</small><b class="block mt-1">'+money(x.issued_amount,x.currency)+'</b></div><div class="bg-slate-50 p-3 rounded-xl"><small>نقدية مؤكدة</small><b class="block mt-1">'+money(confirmed,x.currency)+'</b></div><div class="bg-amber-50 p-3 rounded-xl"><small>قيد المراجعة</small><b class="block mt-1">'+money(pending,x.currency)+'</b></div><div class="bg-emerald-50 p-3 rounded-xl"><small>مصروفات معتمدة</small><b class="block mt-1">'+money(approved,x.currency)+'</b></div></div>';
   if(!x.acknowledged_at&&x.status==='Issued')html+='<div class="rounded-xl border border-amber-200 bg-amber-50 p-3"><p class="text-xs mb-2">أكد فقط بعد استلام النقدية فعليًا من المالية.</p><button data-ec-ack-custody="'+esc(x.id)+'" class="w-full rounded-xl bg-emerald-600 text-white py-3 text-sm font-black">تأكيد استلام العهدة</button></div>';
   if(aa.length){html+='<div><h4 class="font-black text-sm mb-2">التسليمات والزيادات</h4><div class="space-y-2">';aa.forEach(function(z){html+='<div class="flex justify-between items-center gap-2 border rounded-xl p-3"><div><b class="text-xs">'+(z.advance_type==='Initial'?'العهدة الأصلية':'زيادة عهدة')+'</b><p class="text-xs text-slate-500 mt-1">'+esc(z.advance_date||'')+' · '+money(z.amount,z.currency)+'</p><p class="text-[11px] text-slate-400">'+esc(z.reference||'')+'</p></div>'+(z.acknowledged_at?'<span class="text-xs text-emerald-700 font-bold">تم التأكيد</span>':'<button data-ec-ack-advance="'+esc(z.id)+'" class="px-3 py-2 rounded-lg bg-emerald-50 text-emerald-700 text-xs font-bold">تأكيد الاستلام</button>')+'</div>';});html+='</div></div>';}
   if(ee.length){html+='<div><h4 class="font-black text-sm mb-2">مصروفاتي ومستنداتي</h4><div class="space-y-2">';ee.forEach(function(z){var cat=({TRANSPORTATION:'انتقالات',FUEL:'وقود',TOLLS_PARKING:'طرق ومواقف',OTHER:'أخرى'})[z.expense_category]||(z.expense_type==='PURCHASE_INVOICE'?'فاتورة شراء مرتبطة':'مصروف');html+='<div class="border rounded-xl p-3"><div class="flex justify-between gap-2"><b class="text-xs">'+esc(cat)+'</b><b class="text-xs">'+money(z.amount,z.currency)+'</b></div><p class="text-xs text-slate-600 mt-1">'+esc(z.description)+'</p><div class="flex justify-between items-center gap-2 mt-2"><span class="text-[11px] text-slate-500">'+esc(status(z.status))+'</span>'+(z.document_path?'<button data-ec-open-document="'+esc(z.document_path)+'" class="text-xs text-sky-700 font-bold">عرض الإيصال</button>':'')+'</div>'+(z.review_note?'<p class="text-xs text-rose-700 mt-2">'+esc(z.review_note)+'</p>':'')+'</div>';});html+='</div></div>';}
   if(ss.length){html+='<div><h4 class="font-black text-sm mb-2">التسوية المالية</h4>';ss.forEach(function(z){html+='<div class="border rounded-xl p-3 text-xs"><div class="flex justify-between"><span>مصروفات معتمدة</span><b>'+money(z.approved_expense_total,x.currency)+'</b></div><div class="flex justify-between mt-1"><span>النقد المرتجع</span><b>'+money(z.cash_returned,x.currency)+'</b></div><p class="text-slate-500 mt-1">'+esc(z.finance_reference||'')+'</p></div>';});html+='</div>';}
   if(x.acknowledged_at&&x.status!=='Settled'&&x.status!=='Closed')html+='<button data-ec-submit-expense="'+esc(x.id)+'" class="w-full rounded-xl bg-sky-600 text-white py-3 font-black text-sm">تقديم إيصال مصروف</button>';
   html+='</section>';
  });
  return html+'</div>';
 }
 function bind(root){root.onclick=function(ev){var b=ev.target&&ev.target.closest?ev.target.closest('button'):null;if(!b||!root.contains(b))return;if(b.hasAttribute('data-ec-refresh'))render(state.root);else if(b.hasAttribute('data-ec-ack-custody'))ack(b.getAttribute('data-ec-ack-custody'),false);else if(b.hasAttribute('data-ec-ack-advance'))ack(b.getAttribute('data-ec-ack-advance'),true);else if(b.hasAttribute('data-ec-submit-expense'))submit(b.getAttribute('data-ec-submit-expense'));else if(b.hasAttribute('data-ec-open-document'))openDoc(b.getAttribute('data-ec-open-document'));};}
 function render(rootId){
  state.root=rootId||state.root||'mainContent';var h=document.getElementById(state.root);if(!h)return Promise.resolve(false);var seq=++state.serial;
  h.innerHTML='<div class="p-8 text-center text-slate-500">جاري تحميل عهدتك النقدية...</div>';
  return load().then(function(x){if(seq!==state.serial)return false;var t=document.getElementById(state.root);if(!t)return false;t.innerHTML=draw(x);bind(t);realtime(x.user);return true;})
  .catch(function(x){if(seq!==state.serial)return false;var t=document.getElementById(state.root);if(t){t.innerHTML='<div class="p-8 text-center"><h3 class="font-black">تعذر تحميل عهدتك</h3><p class="text-sm text-slate-500 mt-2">'+esc(x.message||x)+'</p><button data-ec-refresh class="mt-4 px-5 py-3 rounded-xl bg-sky-600 text-white">إعادة المحاولة</button></div>';bind(t);}return false;});
 }
 function realtime(u){if(!u||!RW_Realtime||!RW_Realtime.start)return;var key='employee-custody:'+u.company_id;if(state.channel===key)return;if(state.channel)RW_Realtime.stop(state.channel);var started=RW_Realtime.start({appId:'employee-custody',companyId:u.company_id,tables:['buyer_custodies','buyer_custody_advances','buyer_custody_expenses','buyer_custody_payments','buyer_custody_settlements'],debounceMs:500,reconcileMs:30000,onEvent:function(){if(state.root)render(state.root);},onReconcile:function(){if(state.root)render(state.root);}});if(started)state.channel=key;}
 function ack(id,isAdvance){var u;try{u=user();}catch(x){fail(x);return;}Swal.fire({title:isAdvance?'تأكيد استلام زيادة العهدة':'تأكيد استلام العهدة',text:'أكد فقط إذا استلمت النقدية فعليًا.',icon:'question',showCancelButton:true,confirmButtonText:'نعم، استلمت',cancelButtonText:'إلغاء'}).then(function(r){if(!r.isConfirmed)return;Swal.fire({title:'جاري تسجيل الإقرار...',allowOutsideClick:false,didOpen:function(){Swal.showLoading();}});var rpc=isAdvance?'buyer_custody_acknowledge_advance_atomic':'buyer_custody_acknowledge_atomic',args=isAdvance?{p_company_id:u.company_id,p_advance_id:id}:{p_company_id:u.company_id,p_custody_id:id};supabase.rpc(rpc,args).then(function(x){Swal.close();if(x.error)throw x.error;notice('تم تسجيل إقرار الاستلام','success');render(state.root);}).catch(function(x){Swal.close();fail(x);});});}
 function submit(custodyId){
  var s=state.snapshot,c=s&&s.custodies.filter(function(x){return x.id===custodyId;})[0];if(!c||!c.acknowledged_at||['Issued','UnderReview'].indexOf(c.status)<0){fail('لا يمكن تقديم مصروف قبل تأكيد استلام عهدة مفتوحة');return;}
  var op=opId(),html='<div class="text-right space-y-3"><label class="block text-xs font-bold">فئة المصروف<select id="ec-cat" class="swal2-select w-full"><option value="TRANSPORTATION">انتقالات ومواصلات</option><option value="FUEL">وقود</option><option value="TOLLS_PARKING">رسوم طرق ومواقف</option><option value="OTHER">مصروف تشغيلي آخر</option></select></label><div class="grid grid-cols-2 gap-2"><label class="text-xs font-bold">المبلغ ('+esc(c.currency)+')<input id="ec-amt" type="number" min="0.01" step="0.01" class="swal2-input"></label><label class="text-xs font-bold">التاريخ<input id="ec-date" type="date" value="'+new Date().toISOString().slice(0,10)+'" class="swal2-input"></label></div><label class="block text-xs font-bold">البيان<input id="ec-desc" class="swal2-input"></label><label class="block text-xs font-bold">رقم الإيصال<input id="ec-ref" class="swal2-input"></label><label class="block text-xs font-bold">صورة الإيصال أو PDF<input id="ec-file" type="file" accept="application/pdf,image/jpeg,image/png,image/webp" class="swal2-file"></label><p class="text-[11px] text-slate-500">المرفق خاص، بحد أقصى 10 ميجابايت. الإرسال لا يعني الاعتماد.</p></div>';
  Swal.fire({title:'تقديم إيصال مصروف من العهدة',html:html,width:650,showCancelButton:true,confirmButtonText:'إرسال للمالية',cancelButtonText:'إلغاء',preConfirm:async function(){
   var u=user(),amt=Number(byId('ec-amt').value||0),desc=byId('ec-desc').value.trim(),date=byId('ec-date').value,ref=byId('ec-ref').value.trim(),cat=byId('ec-cat').value,f=byId('ec-file').files[0],allowed=['application/pdf','image/jpeg','image/png','image/webp'];
   if(!f||allowed.indexOf(String(f.type||'').toLowerCase())<0||f.size<=0||f.size>10485760){Swal.showValidationMessage('أرفق PDF أو JPG/PNG/WEBP لا يتجاوز 10 ميجابايت');return false;}
   if(amt<=0||!desc||!date){Swal.showValidationMessage('المبلغ والبيان والتاريخ مطلوبة');return false;}
   var check=await supabase.from('buyer_custody_expenses').select('id').eq('company_id',u.company_id).eq('operation_id',op).maybeSingle();
   if(check.error){Swal.showValidationMessage(check.error.message);return false;}if(check.data)return check.data;
   var name=f.name.replace(/[^a-zA-Z0-9._-]+/g,'_').slice(-90)||'receipt',path=u.company_id+'/'+u.id+'/buyer-custody/'+custodyId+'/'+op+'_'+name;
   var upload=await supabase.storage.from('employee-documents').upload(path,f,{upsert:false,contentType:f.type});if(upload.error){Swal.showValidationMessage(upload.error.message);return false;}
   var result=await supabase.rpc('buyer_custody_submit_other_expense_atomic',{p_company_id:u.company_id,p_custody_id:custodyId,p_expense_date:date,p_expense_category:cat,p_expense_reference:ref||null,p_description:desc,p_amount:amt,p_currency:c.currency,p_document_name:f.name,p_document_path:path,p_mime_type:f.type,p_operation_id:op});
   if(result.error){var verify=await supabase.from('buyer_custody_expenses').select('id').eq('company_id',u.company_id).eq('operation_id',op).maybeSingle();if(!verify.error&&!verify.data)await supabase.storage.from('employee-documents').remove([path]);if(!verify.error&&verify.data)return verify.data;Swal.showValidationMessage(result.error.message);return false;}
   return result.data;
  }}).then(function(r){if(r.isConfirmed){notice('تم إرسال الإيصال للمالية دون ترحيل مصروف','success');render(state.root);}});
 }
 function openDoc(path){var w=window.open('about:blank','_blank');supabase.storage.from('employee-documents').createSignedUrl(path,300).then(function(r){if(r.error)throw r.error;if(w)w.location=r.data.signedUrl;else notice('المتصفح منع فتح نافذة المستند','warning');}).catch(function(x){if(w)w.close();fail(x);});}
 function stop(){if(state.channel&&RW_Realtime&&RW_Realtime.stop)RW_Realtime.stop(state.channel);state.channel=null;state.root=null;state.snapshot=null;state.serial++;}
 return {render:render,refresh:function(){return state.root?render(state.root):Promise.resolve(false);},stop:stop};
})();

console.log('   RW_Auth | RW_DB | RW_API | RW_UI | RW_ImageCache | RW_SW | RW_Realtime | RW_EmployeeCustody');