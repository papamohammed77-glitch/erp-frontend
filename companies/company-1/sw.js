// RAWAEA ERP — Production Service Worker
// P150 AUTO-UPDATE FINAL
var SW_BUILD = 'RAWAEA_SW_P150_AUTO_UPDATE';
var STATIC_CACHE = 'rw-static-' + SW_BUILD;
var STATIC_EXTENSIONS = ['.css','.woff','.woff2','.ttf','.png','.jpg','.jpeg','.svg','.ico','.webp'];
var MAX_STATIC_ITEMS = 200;

self.addEventListener('install', function(event) { event.waitUntil(self.skipWaiting()); });

function isInScopeClient(client) {
    return !!(client && client.url && client.url.indexOf(self.registration.scope) === 0);
}

function activateAndReloadClients() {
    return self.clients.claim()
        .then(function() { return self.clients.matchAll({type:'window', includeUncontrolled:true}); })
        .then(function(clientsList) {
            return Promise.all(clientsList.filter(isInScopeClient).map(function(client) {
                return typeof client.navigate === 'function'
                    ? client.navigate(client.url).catch(function(error){ console.warn('[SW] auto-reload failed', error); })
                    : Promise.resolve();
            }));
        });
}

self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(keys) {
            return Promise.all(keys.map(function(key) { return key === STATIC_CACHE ? null : caches.delete(key); }));
        }).then(activateAndReloadClients)
        .then(function() { return self.clients.matchAll({type:'window'}); })
        .then(function(clientsList) {
            clientsList.filter(isInScopeClient).forEach(function(client) {
                client.postMessage({type:'RW_SW_UPDATED', build:SW_BUILD, at:Date.now()});
            });
        })
    );
});

function isHTMLRequest(request) {
    if (request.mode === 'navigate') return true;
    return (request.headers.get('accept') || '').indexOf('text/html') !== -1;
}
function isAPIRequest(url) {
    return url.hostname.indexOf('supabase.co') !== -1 || url.pathname.indexOf('/functions/v1/') !== -1;
}
function isRuntimeRequest(url) {
    var p=url.pathname.toLowerCase();
    return p.indexOf('.js')!==-1 || p.indexOf('.mjs')!==-1 || p.indexOf('.ts')!==-1;
}
function isStaticAsset(pathname) {
    var p=pathname.toLowerCase();
    for(var i=0;i<STATIC_EXTENSIONS.length;i++) if(p.indexOf(STATIC_EXTENSIONS[i])!==-1) return true;
    return false;
}
function trimCache(cache) {
    return cache.keys().then(function(keys){
        if(keys.length<MAX_STATIC_ITEMS) return cache;
        return cache.delete(keys[0]).then(function(){return cache;});
    });
}
function putStatic(cache, request, response) {
    if(!response || response.status!==200 || response.type==='opaque') return Promise.resolve();
    return trimCache(cache).then(function(){return cache.put(request,response.clone());}).catch(function(error){console.warn('[SW] cache write skipped',error);});
}

self.addEventListener('fetch', function(event) {
    var request=event.request;
    if(request.method!=='GET') return;
    var url=new URL(request.url);
    if(isAPIRequest(url) || isHTMLRequest(request) || isRuntimeRequest(url)) {
        event.respondWith(fetch(request));
        return;
    }
    if(isStaticAsset(url.pathname)) {
        event.respondWith(caches.open(STATIC_CACHE).then(function(cache){
            return cache.match(request).then(function(cached){
                if(cached) return cached;
                return fetch(request).then(function(response){return putStatic(cache,request,response).then(function(){return response;});});
            });
        }));
        return;
    }
    event.respondWith(fetch(request).then(function(response){
        return caches.open(STATIC_CACHE).then(function(cache){return putStatic(cache,request,response).then(function(){return response;});});
    }).catch(function(){return caches.match(request);}));
});
