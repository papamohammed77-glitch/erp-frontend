/* CountFlow Core — independent runtime for CountFlow apps only. */
(function (global) {
  'use strict';

  var SUPABASE_URL = 'https://hfzznsiprnwkpayskzhu.supabase.co';
  var PUBLISHABLE_KEY = 'sb_publishable_xd6h0YBpVA1VmNH6A1LCXg_9DhF2ifh';
  var VERSION = 'countflow-core-1.0.0';

  function createClient(options) {
    if (!global.supabase || typeof global.supabase.createClient !== 'function') {
      throw new Error('COUNTFLOW_SUPABASE_LIBRARY_UNAVAILABLE');
    }
    return global.supabase.createClient(SUPABASE_URL, PUBLISHABLE_KEY, options || {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
  }

  function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(null);
    if (location.protocol !== 'https:' && location.hostname !== 'localhost') return Promise.resolve(null);
    return navigator.serviceWorker.register('./countflow-sw.js', { scope: './' })
      .then(function (registration) {
        registration.update().catch(function (error) {
          console.warn('[CountFlow SW] update check failed:', error);
        });
        return registration;
      })
      .catch(function (error) {
        console.warn('[CountFlow SW] registration failed:', error);
        return null;
      });
  }

  function watchPostgresChanges(client, config) {
    config = config || {};
    if (!client || typeof client.channel !== 'function' || !Array.isArray(config.filters) ||
        typeof config.onInvalidate !== 'function') return null;

    var stopped = false;
    var timer = null;
    var reconcileTimer = null;
    var debounceMs = Math.max(100, Number(config.debounceMs) || 350);
    var reconcileMs = Math.max(15000, Number(config.reconcileMs) || 30000);

    function invalidate(reason) {
      if (stopped) return;
      clearTimeout(timer);
      timer = setTimeout(function () {
        if (stopped) return;
        Promise.resolve(config.onInvalidate({ source: reason || 'postgres_changes' }))
          .catch(function (error) { console.warn('[CountFlow Realtime] refresh failed:', error); });
      }, debounceMs);
    }

    var channelName = config.channelName || ('countflow-core-' + Date.now());
    var channel = client.channel(channelName);
    config.filters.forEach(function (filter) {
      if (!filter || !filter.table) return;
      channel.on('postgres_changes', {
        event: filter.event || '*',
        schema: 'public',
        table: filter.table,
        filter: filter.filter
      }, function () { invalidate('postgres_changes'); });
    });

    channel.subscribe(function (status, error) {
      if (typeof config.onStatus === 'function') {
        try { config.onStatus(status, error || null); } catch (e) { console.warn(e); }
      }
      if (status === 'SUBSCRIBED') invalidate('subscribed');
    });

    reconcileTimer = setInterval(function () {
      if (!stopped && !document.hidden) invalidate('periodic');
    }, reconcileMs);

    var visibilityHandler = function () {
      if (!document.hidden) invalidate('visibility');
    };
    document.addEventListener('visibilitychange', visibilityHandler);

    return {
      channel: channel,
      stop: function () {
        if (stopped) return;
        stopped = true;
        clearTimeout(timer);
        clearInterval(reconcileTimer);
        document.removeEventListener('visibilitychange', visibilityHandler);
        client.removeChannel(channel).catch(function (error) {
          console.warn('[CountFlow Realtime] channel cleanup failed:', error);
        });
      }
    };
  }

  function bindConnectivity(callback) {
    if (typeof callback !== 'function') return function () {};
    var update = function () {
      callback({ online: navigator.onLine, source: 'browser-network-state' });
    };
    global.addEventListener('online', update);
    global.addEventListener('offline', update);
    update();
    return function () {
      global.removeEventListener('online', update);
      global.removeEventListener('offline', update);
    };
  }

  global.CF_Core = Object.freeze({
    version: VERSION,
    SUPABASE_URL: SUPABASE_URL,
    PUBLISHABLE_KEY: PUBLISHABLE_KEY,
    createClient: createClient,
    registerServiceWorker: registerServiceWorker,
    watchPostgresChanges: watchPostgresChanges,
    bindConnectivity: bindConnectivity
  });

  registerServiceWorker();
})(window);
