// sw.js – إصدار 3.3 AUTO-UPDATE FINAL
// RAWAEA ERP — Production Service Worker
// Contract:
// - HTML/navigation/API/runtime code are network-backed and never cached.
// - The shared update coordinator is injected into controlled HTML.
// - Static presentation assets use a versioned cache.
// - Every new SW build activates immediately and reloads in-scope windows.
// - Manifest is network-backed so PWA metadata cannot remain stale.
// - No authentication or business-data caching.
// - Known RW_HR payroll shell syntax drift is repaired before HTML parse.

var SW_BUILD = 'RAWAEA_SW_P154_HR_SHELL_HARDENING_20260917';
var STATIC_CACHE = 'rw-static-' + SW_BUILD;
var STATIC_EXTENSIONS = ['.css', '.woff', '.woff2', '.ttf', '.png', '.jpg', '.jpeg', '.svg', '.ico', '.webp'];
var MAX_STATIC_ITEMS = 200;

self.addEventListener('install', function(event) {
    event.waitUntil(self.skipWaiting());
});

function isInScopeClient(client) {
    if (!client || !client.url) return false;
    return client.url.indexOf(self.registration.scope) === 0;
}

function activateAndReloadClients() {
    return Promise.resolve()
        .then(function() { return self.clients.claim(); })
        .then(function() { return self.clients.matchAll({ type: 'window', includeUncontrolled: true }); })
        .then(function(clientsList) {
            var tasks = [];
            for (var i = 0; i < clientsList.length; i++) {
                var client = clientsList[i];
                if (!isInScopeClient(client)) continue;
                if (typeof client.navigate === 'function') {
                    tasks.push(client.navigate(client.url).catch(function(error) {
                        console.warn('[SW] Auto-reload failed:', error);
                    }));
                }
            }
            return Promise.all(tasks);
        });
}

self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(keys) {
            return Promise.all(keys.map(function(key) {
                if (key !== STATIC_CACHE) return caches.delete(key);
                return Promise.resolve(false);
            }));
        }).then(activateAndReloadClients)
    );
});

function isHTMLRequest(request) {
    if (request.mode === 'navigate') return true;
    var accept = request.headers.get('accept') || '';
    return accept.indexOf('text/html') !== -1;
}

function isAPIRequest(url) {
    if (url.hostname.indexOf('supabase.co') !== -1) return true;
    return url.pathname.indexOf('/functions/v1/') !== -1;
}

function isRuntimeRequest(url) {
    var pathname = url.pathname.toLowerCase();
    return pathname.indexOf('.js') !== -1 || pathname.indexOf('.mjs') !== -1 || pathname.indexOf('.ts') !== -1;
}

function isNeverCacheRequest(url) {
    var pathname = url.pathname.toLowerCase();
    return pathname.endsWith('/manifest.json') || pathname.endsWith('/sw.js');
}

function isStaticAsset(pathname) {
    var lowerPath = pathname.toLowerCase();
    for (var i = 0; i < STATIC_EXTENSIONS.length; i++) {
        if (lowerPath.indexOf(STATIC_EXTENSIONS[i]) !== -1) return true;
    }
    return false;
}

function trimCache(cache) {
    return cache.keys().then(function(keys) {
        if (keys.length < MAX_STATIC_ITEMS) return cache;
        return cache.delete(keys[0]).then(function() { return cache; });
    });
}

function putStatic(cache, request, response) {
    if (!response || response.status !== 200 || response.type === 'opaque') return Promise.resolve();
    return trimCache(cache).then(function() {
        return cache.put(request, response.clone());
    }).catch(function(error) {
        console.warn('[SW] static cache write skipped:', error);
    });
}

function patchKnownHRShell(html) {
    var broken = "esc(x.status||'-')]))));";
    var canonical = "esc(x.status||'-')])));";
    var count = html.split(broken).length - 1;
    if (count === 1) {
        console.warn('[SW] Repaired stale RW_HR payroll syntax before HTML parse');
        return html.replace(broken, canonical);
    }
    if (count > 1) {
        console.error('[SW] Refused ambiguous RW_HR payroll repair; multiple stale tokens found:', count);
    }
    return html;
}

function injectUpdateCoordinator(response) {
    if (!response || response.status !== 200) return response;
    var contentType = response.headers.get('content-type') || '';
    if (contentType.indexOf('text/html') === -1) return response;

    return response.text().then(function(html) {
        var before = html;
        html = patchKnownHRShell(html);

        if (html.indexOf('RAWAEA_UPDATE_COORDINATOR') === -1) {
            var scopeUrl = new URL(self.registration.scope);
            var coordinatorUrl = new URL('register-sw.js', scopeUrl).pathname;
            var script = '<script id="RAWAEA_UPDATE_COORDINATOR" src="' + coordinatorUrl + '"></script>';
            var marker = html.indexOf('</head>');
            if (marker >= 0) {
                html = html.slice(0, marker) + script + html.slice(marker);
            } else {
                html = script + html;
            }
        }

        if (html === before) return response;
        return new Response(html, {
            status: response.status,
            statusText: response.statusText,
            headers: new Headers(response.headers)
        });
    }).catch(function(error) {
        console.warn('[SW] coordinator/HR shell transform skipped:', error);
        return response;
    });
}

self.addEventListener('fetch', function(event) {
    var request = event.request;
    if (request.method !== 'GET') return;

    var url = new URL(request.url);

    if (isNeverCacheRequest(url) || isAPIRequest(url) || isRuntimeRequest(url)) {
        event.respondWith(fetch(request));
        return;
    }

    if (isHTMLRequest(request)) {
        event.respondWith(fetch(request).then(injectUpdateCoordinator));
        return;
    }

    if (isStaticAsset(url.pathname)) {
        event.respondWith(
            caches.open(STATIC_CACHE).then(function(cache) {
                return cache.match(request).then(function(cached) {
                    if (cached) return cached;
                    return fetch(request).then(function(networkResponse) {
                        return putStatic(cache, request, networkResponse).then(function() {
                            return networkResponse;
                        });
                    });
                });
            })
        );
        return;
    }

    event.respondWith(fetch(request));
});