var CACHE_NAME = 'rw-store-v1';
var STATIC_ASSETS = ['/', '/index.html', '/manifest.json'];

self.addEventListener('install', function(event) {
    event.waitUntil(
        caches.open(CACHE_NAME).then(function(cache) {
            return cache.addAll(STATIC_ASSETS);
        }).then(function() { return self.skipWaiting(); })
    );
});

self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(keys) {
            var promises = [];
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] !== CACHE_NAME) { promises.push(caches.delete(keys[i])); }
            }
            return Promise.all(promises).then(function() { return self.clients.claim(); });
        })
    );
});

self.addEventListener('fetch', function(event) {
    if (event.request.url.indexOf('supabase.co') !== -1) { return; }
    event.respondWith(
        fetch(event.request).then(function(response) {
            var cloned = response.clone();
            caches.open(CACHE_NAME).then(function(cache) { cache.put(event.request, cloned); });
            return response;
        }).catch(function() {
            return caches.match(event.request).then(function(cached) {
                return cached || caches.match('/index.html');
            });
        })
    );
});
