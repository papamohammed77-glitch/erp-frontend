// sw.js – إصدار 3.1 AUTO-UPDATE FINAL
// RAWAEA ERP — Production Service Worker
// Contract:
// - HTML/navigation/API/runtime code are network-backed and never cached.
// - The shared update coordinator is injected into controlled HTML.
// - Static presentation assets use a versioned cache.
// - Every new SW build activates immediately and reloads in-scope windows.
// - No authentication or business-data caching.

var SW_BUILD = 'RAWAEA_SW_P151_AUTO_UPDATE_COORDINATOR';
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

function injectUpdateCoordinator(response) {
    if (!response || response.status !== 200) return response;
    var contentType = response.headers.get('content-type') || '';
    if (contentType.indexOf('text/html') === -1) return response;

    return response.text().then(function(html) {
        if (html.indexOf('RAWAEA_UPDATE_COORDINATOR') !== -1) return response;

        var scopeUrl = new URL(self.registration.scope);
        var coordinatorUrl = new URL('register-sw.js', scopeUrl).pathname;
        var script = '<script id="RAWAEA_UPDATE_COORDINATOR" src="' + coordinatorUrl + '"></script>';
        var marker = html.indexOf('</head>');
        if (marker >= 0) {
            html = html.slice(0, marker) + script + html.slice(marker);
        } else {
            html = script + html;
        }

        return new Response(html, {
            status: response.status,
            statusText: response.statusText,
            headers: new Headers(response.headers)
        });
    }).catch(function(error) {
        console.warn('[SW] coordinator injection skipped:', error);
        return response;
    });
}

self.addEventListener('fetch', function(event) {
    var request = event.request;
    if (request.method !== 'GET') return;

    var url = new URL(request.url);

    if (isAPIRequest(url) || isRuntimeRequest(url)) {
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

    event.respondWith(
        fetch(request).then(function(networkResponse) {
            return caches.open(STATIC_CACHE).then(function(cache) {
                return putStatic(cache, request, networkResponse).then(function() {
                    return networkResponse;
                });
            });
        }).catch(function() {
            return caches.match(request);
        })
    );
});
