// sw.js – الروائع ERP
// الإصدار 2.0 – Network First مع إشعار فوري بالتحديث
var CACHE_NAME = 'rawaea-erp-v2';

self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(key) { return key !== CACHE_NAME; })
            .map(function(key) { return caches.delete(key); })
      );
    }).then(function() {
      self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function(event) {
  if (event.request.method !== 'GET') return;

  // لا يُخبَّأ Supabase أو CDNs
  if (event.request.url.indexOf('supabase.co') !== -1 ||
      event.request.url.indexOf('cdn.jsdelivr.net') !== -1 ||
      event.request.url.indexOf('cdnjs.cloudflare.com') !== -1 ||
      event.request.url.indexOf('cdn.tailwindcss.com') !== -1 ||
      event.request.url.indexOf('fonts.googleapis.com') !== -1) {
    return;
  }

  event.respondWith(
    fetch(event.request).then(function(networkResponse) {
      // ✅ الشبكة أولاً – نُحدِّث الكاش بالنسخة الجديدة
      if (networkResponse && networkResponse.status === 200) {
        var clone = networkResponse.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put(event.request, clone);
        });
      }
      return networkResponse;
    }).catch(function() {
      // ⚠️ فقط عند فشل الشبكة، نستخدم الكاش
      return caches.match(event.request).then(function(cached) {
        return cached || new Response('غير متصل', { status: 503 });
      });
    })
  );
});
