var CACHE_NAME = 'rawaea-erp-v1';

// جميع تطبيقات الشركة
var urlsToCache = [
  '/',
  '/index.html',
  '/sales/telesales.html',
  '/sales/order-taker.html',
  '/sales/pos.html',
  '/sales/van-sales.html',
  '/sales/supervisor.html',
  '/sales/manager.html',
  '/warehouse/manager.html',
  '/warehouse/supervisor.html',
  '/warehouse/receiver.html',
  '/warehouse/picker.html',
  '/warehouse/loader.html',
  '/warehouse/returns.html',
  '/warehouse/unloader.html',
  '/warehouse/counter.html',
  '/warehouse/vouchers.html',
  '/delivery/driver.html',
  '/delivery/supervisor.html',
  '/purchasing/buyer.html',
  '/purchasing/supervisor.html',
  '/office/accountant.html',
  '/office/hr.html',
  '/office/finance-manager.html',
  '/office/general-manager.html',
  '/office/owner.html',
  '/store/index.html',
  '/store/track.html'
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll(urlsToCache);
    })
  );
});

self.addEventListener('fetch', function(event) {
  event.respondWith(
    caches.match(event.request).then(function(response) {
      if (response) return response;
      return fetch(event.request).then(function(response) {
        if (!response || response.status !== 200 || response.type !== 'basic') return response;
        var responseToCache = response.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put(event.request, responseToCache);
        });
        return response;
      });
    })
  );
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});
