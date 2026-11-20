/* CountFlow Service Worker — shell/static assets only; never cache business data. */
'use strict';
var CF_SW_BUILD = 'countflow-sw-20261120-2';
var CF_SHELL_CACHE = 'cf-shell-' + CF_SW_BUILD;
var CF_STATIC_CACHE = 'cf-static-' + CF_SW_BUILD;
var CF_SHELL = [
  './',
  './index.html',
  './countflow-admin.html',
  './countflow.html',
  './Countflow-supervisor.html',
  './countflow-core.js',
  './manifest.webmanifest',
  './countflow-icon.svg'
];
var CF_CDN = [
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdn.jsdelivr.net/npm/papaparse@5.4.1/papaparse.min.js',
  'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js'
];

self.addEventListener('install', function (event) {
  event.waitUntil((async function () {
    var shell = await caches.open(CF_SHELL_CACHE);
    await Promise.all(CF_SHELL.map(function (path) {
      return shell.add(path).catch(function (error) {
        console.warn('[CountFlow SW] shell precache skipped:', path, error);
      });
    }));
    var assets = await caches.open(CF_STATIC_CACHE);
    await Promise.all(CF_CDN.map(async function (url) {
      try {
        var response = await fetch(new Request(url, { mode: 'cors', cache: 'reload' }));
        if (response && (response.ok || response.type === 'opaque')) {
          await assets.put(url, response.clone());
        }
      } catch (error) {
        console.warn('[CountFlow SW] CDN precache skipped:', url, error);
      }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    var keys = await caches.keys();
    await Promise.all(keys.map(function (key) {
      if ((key.indexOf('cf-shell-') === 0 && key !== CF_SHELL_CACHE) ||
          (key.indexOf('cf-static-') === 0 && key !== CF_STATIC_CACHE)) {
        return caches.delete(key);
      }
      return Promise.resolve(false);
    }));
    await self.clients.claim();
  })());
});

function isSupabaseRequest(url) {
  return url.hostname === 'hfzznsiprnwkpayskzhu.supabase.co' ||
    url.pathname.indexOf('/functions/v1/') !== -1;
}
function isAllowedCdn(url) {
  return CF_CDN.indexOf(url.href) !== -1;
}
function isStaticPath(path) {
  return /\.(?:js|mjs|css|svg|png|jpg|jpeg|webp|ico|woff2?|webmanifest)$/i.test(path);
}
function cacheResponse(cache, request, response) {
  if (response && (response.ok || response.type === 'opaque')) {
    return cache.put(request, response.clone()).catch(function (error) {
      console.warn('[CountFlow SW] cache write skipped:', error);
    });
  }
  return Promise.resolve();
}

self.addEventListener('fetch', function (event) {
  var request = event.request;
  if (request.method !== 'GET') return;
  var url = new URL(request.url);

  /* Auth, REST, Storage and Edge Functions are network-only. */
  if (isSupabaseRequest(url) || url.hostname.endsWith('.supabase.co')) {
    event.respondWith(fetch(request).catch(function () {
      return new Response(JSON.stringify({
        code: 'COUNTFLOW_NETWORK_UNAVAILABLE',
        message: 'الخدمة غير متاحة دون اتصال. احتفظنا بعمليات العد المحلية حتى عودة الاتصال.'
      }), {
        status: 503,
        headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }
      });
    }));
    return;
  }

  if (isAllowedCdn(url)) {
    event.respondWith((async function () {
      var cache = await caches.open(CF_STATIC_CACHE);
      var cached = await cache.match(request);
      if (!cached) { var shellCache = await caches.open(CF_SHELL_CACHE); cached = await shellCache.match(request); }
      if (cached) return cached;
      try {
        var response = await fetch(request);
        await cacheResponse(cache, request, response);
        return response;
      } catch (error) {
        return new Response('CountFlow dependency unavailable offline', { status: 503 });
      }
    })());
    return;
  }

  if (url.origin !== self.location.origin) {
    event.respondWith(fetch(request));
    return;
  }

  if (request.mode === 'navigate' || (request.headers.get('accept') || '').indexOf('text/html') !== -1) {
    event.respondWith((async function () {
      var shell = await caches.open(CF_SHELL_CACHE);
      try {
        var response = await fetch(request);
        if (response && response.ok) await cacheResponse(shell, request, response);
        return response;
      } catch (error) {
        var cached = await shell.match(request, { ignoreSearch: true });
        if (cached) return cached;
        var fallback = await shell.match('./index.html');
        if (fallback) return fallback;
        return new Response('CountFlow is not available offline yet. Open it once while connected.', { status: 503 });
      }
    })());
    return;
  }

  if (isStaticPath(url.pathname)) {
    event.respondWith((async function () {
      var cache = await caches.open(CF_STATIC_CACHE);
      var cached = await cache.match(request);
      if (cached) return cached;
      try {
        var response = await fetch(request);
        await cacheResponse(cache, request, response);
        return response;
      } catch (error) {
        return new Response('Static asset unavailable offline', { status: 503 });
      }
    })());
    return;
  }

  event.respondWith(fetch(request));
});
