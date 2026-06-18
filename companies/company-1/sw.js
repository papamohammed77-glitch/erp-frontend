var CACHE_NAME = 'rawaea-erp-v1';
var ASSETS_TO_CACHE = [
  '/companies/company-1/',
  '/companies/company-1/index.html',
  '/companies/company-1/manifest.json'
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(key) { return key !== CACHE_NAME; })
            .map(function(key) { return caches.delete(key); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(event) {
  if (event.request.method !== 'GET') return;
  
  if (event.request.url.indexOf('supabase.co') !== -1 ||
      event.request.url.indexOf('cdn.jsdelivr.net') !== -1 ||
      event.request.url.indexOf('cdnjs.cloudflare.com') !== -1 ||
      event.request.url.indexOf('cdn.tailwindcss.com') !== -1 ||
      event.request.url.indexOf('fonts.googleapis.com') !== -1) {
    return;
  }
  
  event.respondWith(
    caches.match(event.request).then(function(cached) {
      return cached || fetch(event.request).then(function(response) {
        if (response && response.status === 200) {
          var clone = response.clone();
          caches.open(CACHE_NAME).then(function(cache) {
            cache.put(event.request, clone);
          });
        }
        return response;
      }).catch(function() {
        return cached || new Response('غير متصل', { status: 503 });
      });
    })
  );
});
