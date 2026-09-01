// sw.js – إصدار 2.2 FINAL
// RAWAEA ERP — Production Service Worker
//
// Contract:
// - Network Only: HTML/navigation, Supabase/API, runtime code (JS/MJS/TS)
// - Cache First: immutable/static presentation assets only
// - Network First + cache fallback: other GET resources
// - Scope-safe: this file is intended to be served from the deployment path
//   that owns /companies/ (normally /companies/sw.js).
// - No authentication or business-data caching.

var STATIC_CACHE = 'rw-static-v3';
var STATIC_EXTENSIONS = [
    '.css',
    '.woff',
    '.woff2',
    '.ttf',
    '.png',
    '.jpg',
    '.jpeg',
    '.svg',
    '.ico',
    '.webp'
];
var MAX_STATIC_ITEMS = 200;
var SW_BUILD = 'RAWAEA_SW_P137_FINAL';

// ==================== INSTALL ====================
self.addEventListener('install', function(event) {
    // Activate the new worker without waiting for old tabs to close.
    event.waitUntil(self.skipWaiting());
});

// ==================== ACTIVATE ====================
self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(keys) {
            return Promise.all(keys.map(function(key) {
                if (key !== STATIC_CACHE) {
                    return caches.delete(key);
                }
                return Promise.resolve(false);
            }));
        }).then(function() {
            return self.clients.claim();
        }).then(function() {
            return self.clients.matchAll({ type: 'window' });
        }).then(function(clientsList) {
            for (var i = 0; i < clientsList.length; i++) {
                clientsList[i].postMessage({
                    type: 'RW_SW_UPDATED',
                    build: SW_BUILD,
                    at: Date.now()
                });
            }
        })
    );
});

// ==================== CLASSIFIERS ====================
function isHTMLRequest(request) {
    if (request.mode === 'navigate') return true;
    var accept = request.headers.get('accept') || '';
    return accept.indexOf('text/html') !== -1;
}

function isAPIRequest(url) {
    // Supabase REST/Auth/Storage/realtime endpoints must never be cached here.
    if (url.hostname.indexOf('supabase.co') !== -1) return true;

    // Supabase Edge Functions / compatible function gateways.
    if (url.pathname.indexOf('/functions/v1/') !== -1) return true;

    return false;
}

function isRuntimeRequest(url) {
    var pathname = url.pathname.toLowerCase();
    return pathname.indexOf('.js') !== -1 ||
           pathname.indexOf('.mjs') !== -1 ||
           pathname.indexOf('.ts') !== -1;
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

        // Delete the oldest entry returned by Cache.keys().
        return cache.delete(keys[0]).then(function() {
            return cache;
        });
    });
}

function isCacheableStaticResponse(response) {
    return !!response && response.status === 200 && response.type !== 'opaque';
}

function putStatic(cache, request, response) {
    if (!isCacheableStaticResponse(response)) {
        return Promise.resolve();
    }

    return trimCache(cache).then(function() {
        return cache.put(request, response.clone());
    }).catch(function(error) {
        // Caching is an optimization. Never let quota/cache failures break runtime.
        console.warn('[SW] تعذر تخزين المورد:', request.url, error);
    });
}

// ==================== FETCH ====================
self.addEventListener('fetch', function(event) {
    var request = event.request;

    // The SW only handles safe GET requests.
    if (request.method !== 'GET') return;

    var url = new URL(request.url);

    // 1) API / Supabase: always network, never cache.
    if (isAPIRequest(url)) {
        event.respondWith(fetch(request));
        return;
    }

    // 2) HTML/navigation: always network, never cache.
    // This prevents stale application shells after deployment.
    if (isHTMLRequest(request)) {
        event.respondWith(fetch(request));
        return;
    }

    // 3) Runtime code: always network, never cache.
    // A stale JS bundle can freeze the application on an older release.
    if (isRuntimeRequest(url)) {
        event.respondWith(fetch(request));
        return;
    }

    // 4) Presentation/static assets: Cache First.
    if (isStaticAsset(url.pathname)) {
        event.respondWith(
            caches.open(STATIC_CACHE).then(function(cache) {
                return cache.match(request).then(function(cached) {
                    if (cached) return cached;

                    return fetch(request).then(function(networkResponse) {
                        putStatic(cache, request, networkResponse);
                        return networkResponse;
                    }).catch(function() {
                        return new Response('غير متصل', {
                            status: 503,
                            statusText: 'Service Unavailable'
                        });
                    });
                });
            })
        );
        return;
    }

    // 5) Other GET resources: Network First with cache fallback.
    // Nothing here is considered authoritative business data.
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
