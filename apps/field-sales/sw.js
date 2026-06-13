importScripts('https://storage.googleapis.com/workbox-cdn/releases/7.0.0/workbox-sw.js');

if (workbox) {
  workbox.setConfig({ debug: false });

  workbox.routing.registerRoute(
    function(args) { return args.request.destination === 'style' || args.request.destination === 'script' || args.request.destination === 'font' || args.request.destination === 'image'; },
    new workbox.strategies.CacheFirst({ cacheName: 'rw-static', plugins: [new workbox.expiration.ExpirationPlugin({ maxEntries: 100, maxAgeSeconds: 2592000 })] })
  );

  workbox.routing.registerRoute(
    function(args) { return args.url.hostname.indexOf('supabase.co') !== -1 && args.url.pathname.indexOf('/rest/') !== -1; },
    new workbox.strategies.NetworkFirst({ cacheName: 'rw-api', networkTimeoutSeconds: 5 })
  );

  var bgSyncPlugin = new workbox.backgroundSync.BackgroundSyncPlugin('rw-orders-queue', { maxRetentionTime: 1440 });
  workbox.routing.registerRoute(
    function(args) { return args.url.pathname.indexOf('/functions/v1/save-sales-invoice') !== -1; },
    new workbox.strategies.NetworkOnly({ plugins: [bgSyncPlugin] }),
    'POST'
  );
}

self.addEventListener('install', function(event) { self.skipWaiting(); });
self.addEventListener('activate', function(event) { event.waitUntil(self.clients.claim()); });
