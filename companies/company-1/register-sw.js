// RAWAEA ERP — permanent Service Worker update coordinator
var _rwReloadTriggered = false;
window._rwHasActiveSession = false;

function RW_checkPendingReload() {
    if (window._rwPendingReload) window.location.reload();
}

function RW_getCanonicalSWRegistration() {
    var currentScript = document.currentScript;
    var coordinatorUrl;

    if (currentScript && currentScript.src) {
        coordinatorUrl = new URL(currentScript.src, window.location.href);
    } else {
        coordinatorUrl = new URL('/companies/company-1/register-sw.js', window.location.origin);
    }

    return {
        swUrl: new URL('sw.js', coordinatorUrl).pathname,
        scope: new URL('./', coordinatorUrl).pathname
    };
}

if (location.pathname.indexOf('/vouchers.html') === -1 && 'serviceWorker' in navigator) {
    var rwSW = RW_getCanonicalSWRegistration();

    navigator.serviceWorker.register(rwSW.swUrl, {scope:rwSW.scope}).then(function(registration) {
        var update = function() {
            registration.update().catch(function(err) { console.warn('[RW] SW update check failed:', err); });
        };
        update();
        setInterval(update, 60000);
        document.addEventListener('visibilitychange', function() {
            if (document.visibilityState === 'visible') update();
        });
        window.addEventListener('online', update);
    }).catch(function(err) {
        console.error('[RW] Service Worker registration failed:', err);
    });

    navigator.serviceWorker.addEventListener('controllerchange', function() {
        if (_rwReloadTriggered) return;
        _rwReloadTriggered = true;
        // sw.js performs the authoritative in-scope client navigation on activation.
        window._rwPendingReload = false;
    });

    navigator.serviceWorker.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'RW_SW_UPDATED') {
            console.log('[RW] Auto-update active:', event.data.build || 'unknown');
        }
    });
}
