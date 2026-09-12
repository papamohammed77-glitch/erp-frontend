// RAWAEA ERP — permanent Service Worker update coordinator
var _rwReloadTriggered = false;
window._rwHasActiveSession = false;

function RW_checkPendingReload() {
    if (window._rwPendingReload) window.location.reload();
}

if (location.pathname.indexOf('/vouchers.html') === -1 && 'serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js', {scope:'./'}).then(function(registration) {
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
        // The new worker is responsible for activation; reload automatically.
        window._rwPendingReload = false;
        window.location.reload();
    });

    navigator.serviceWorker.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'RW_SW_UPDATED') {
            console.log('[RW] Auto-update active:', event.data.build || 'unknown');
        }
    });
}
