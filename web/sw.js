/* ============================================================
 * DNSCrypt Smart Filter — Service Worker
 * Version: v1.6.0 (Global Edition)
 * Last updated: 2026-11-13
 * ============================================================
 * Provides offline support and caching for the WebUI and
 * Dashboard as an installable PWA.
 *
 * Caching strategy:
 *   • HTML → Network-First with 5s timeout.
 *   • Static assets → Stale-While-Revalidate (30s timeout).
 *   • /sw.js → always bypassed.
 * ============================================================ */

'use strict';

// ============================================================
// [1] Configuration
// ============================================================
// CACHE_VERSION invalidates every client's cache on release.
// MUST be bumped whenever assets change.
// ============================================================
const CACHE_VERSION = 'v1.6.0-r1794570446';

const STATIC_CACHE  = `dnscrypt-static-${CACHE_VERSION}`;
const RUNTIME_CACHE = `dnscrypt-runtime-${CACHE_VERSION}`;

const DEBUG = false;

// ============================================================
// [2] PRECACHE_ASSETS
// ============================================================
const PRECACHE_ASSETS = [
    // --- HTML + Manifest (3) ---
    '/',
    '/manifest.json',
    '/offline.html',

    // --- SVG Icons (2) ---
    '/icon-192.svg',
    '/icon-512.svg',

    // --- PNG Icons (3) ---
    '/icon-192.png',
    '/icon-512.png',
    '/apple-touch-icon.png',

    // --- Favicons (3) ---
    '/favicon-32x32.png',
    '/favicon-16x16.png',
    '/favicon.ico'
];

const HTML_TIMEOUT_MS = 5000;
const SWR_NETWORK_TIMEOUT_MS = 30000;

let lastActivatedVersion = null;
let lastPrecacheFailures = [];

// ============================================================
// [3] Logging
// ============================================================
function debugLog(...args) {
    if (DEBUG) console.log('[SW ' + CACHE_VERSION + ']', ...args);
}

function debugWarn(...args) {
    if (DEBUG) console.warn('[SW ' + CACHE_VERSION + ']', ...args);
}

// ============================================================
// [4] Client notification helper
// ============================================================
async function notifyClients(payload) {
    try {
        const clients = await self.clients.matchAll({ type: 'window' });
        clients.forEach((client) => {
            try {
                client.postMessage(payload);
            } catch (err) {
                debugWarn('client.postMessage failed:', err);
            }
        });
        return clients.length;
    } catch (err) {
        debugWarn('matchAll failed:', err);
        return 0;
    }
}

// ============================================================
// [5] Offline page
// ============================================================
async function buildOfflineResponse() {
    try {
        const cached = await caches.match('/offline.html');
        if (cached) {
            debugLog('Using cached /offline.html');
            return cached;
        }
    } catch (e) {
        debugWarn('Failed to fetch offline.html from cache:', e);
    }

    debugLog('Using inline offline page (fallback)');
    return new Response(
        '<!DOCTYPE html>' +
        '<html lang="en" dir="ltr">' +
        '<head>' +
        '<meta charset="utf-8">' +
        '<meta name="viewport" content="width=device-width,initial-scale=1">' +
        '<title>Offline — DNSCrypt ' + CACHE_VERSION + '</title>' +
        '<style>' +
        '*{margin:0;padding:0;box-sizing:border-box}' +
        'body{font-family:-apple-system,system-ui,sans-serif;background:#0d1117;color:#e6edf3;' +
        'display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center}' +
        '.box{max-width:420px;background:rgba(22,27,34,0.92);border:1px solid rgba(255,255,255,0.06);' +
        'border-radius:20px;padding:40px 24px;box-shadow:0 30px 80px rgba(0,0,0,0.7)}' +
        '.icon{font-size:64px;margin-bottom:20px;display:block;opacity:0.9}' +
        'h1{color:#f85149;font-size:24px;margin-bottom:12px;font-weight:700}' +
        'p{color:#8b949e;font-size:14px;line-height:1.6;margin-bottom:16px}' +
        'code{background:rgba(88,166,255,0.1);color:#58a6ff;padding:2px 8px;border-radius:6px;' +
        'font-family:monospace;font-size:13px;direction:ltr;display:inline-block}' +
        '.safe{background:rgba(63,185,80,0.06);border:1px solid rgba(63,185,80,0.25);' +
        'border-radius:10px;padding:12px;margin:16px 0;font-size:12.5px;color:#8b949e;text-align:start}' +
        '.safe strong{color:#3fb950;display:block;margin-bottom:6px}' +
        '.hint{font-size:11px;color:#8b949e;margin-top:16px;padding-top:16px;border-top:1px solid rgba(255,255,255,0.06)}' +
        'button{background:linear-gradient(135deg,#1f6feb,#58a6ff);color:white;border:none;padding:12px 24px;' +
        'border-radius:12px;font-weight:700;font-size:14px;cursor:pointer;font-family:inherit;transition:0.2s}' +
        'button:hover{transform:translateY(-2px);box-shadow:0 10px 20px rgba(31,111,235,0.4)}' +
        '</style></head>' +
        '<body><div class="box">' +
        '<span class="icon">📡</span>' +
        '<h1>Offline</h1>' +
        '<p>Cannot reach the local server.<br>' +
        'Make sure <code>dnscrypt-webui</code> is running on its ' +
        'configured port (default 9090).</p>' +
        '<div class="safe"><strong>💾 Your data is safe</strong>' +
        'Your settings are preserved on ' +
        '<code>/sdcard/dnscrypt-webui-backup/</code> and will be ' +
        'restored automatically if you reinstall the module.</div>' +
        '<button type="button" onclick="location.reload()">🔄 Retry</button>' +
        '<div class="hint">Service Worker ' + CACHE_VERSION + '</div>' +
        '</div></body></html>',
        {
            status: 503,
            statusText: 'Service Unavailable',
            headers: { 'Content-Type': 'text/html; charset=utf-8' }
        }
    );
}

// ============================================================
// [6] install
// ============================================================
self.addEventListener('install', (event) => {
    debugLog('Installing...');

    event.waitUntil(
        (async () => {
            const failures = [];

            try {
                const cache = await caches.open(STATIC_CACHE);

                await Promise.all(
                    PRECACHE_ASSETS.map((url) => {
                        return cache.add(url).catch((err) => {
                            failures.push({
                                url: url,
                                err: (err && err.message) ? err.message : String(err)
                            });
                            debugWarn('Pre-cache failed for', url, err);
                        });
                    })
                );
            } catch (err) {
                failures.push({
                    url: '__install__',
                    err: (err && err.message) ? err.message : String(err)
                });
                debugWarn('Install wrapper failed:', err);
            }

            lastPrecacheFailures = failures.slice();

            if (failures.length > 0) {
                const notified = await notifyClients({
                    type: 'SW_PRECACHE_PARTIAL',
                    version: CACHE_VERSION,
                    failedCount: failures.length,
                    failures: failures.slice(0, 20)
                });
                debugWarn(
                    'Precache incomplete: ' + failures.length +
                    ' failure(s); notified ' + notified + ' client(s)'
                );
            }

            debugLog(
                'Installed — waiting for activation (' +
                (PRECACHE_ASSETS.length - failures.length) +
                '/' + PRECACHE_ASSETS.length + ' cached)'
            );
        })()
    );
});

// ============================================================
// [7] activate
// ============================================================
self.addEventListener('activate', (event) => {
    debugLog('Activating...');

    event.waitUntil(
        (async () => {
            try {
                const cacheNames = await caches.keys();
                const toDelete = cacheNames.filter((name) => {
                    return name !== STATIC_CACHE && name !== RUNTIME_CACHE;
                });

                if (toDelete.length > 0) {
                    debugLog('Deleting old caches:', toDelete);
                }

                await Promise.all(toDelete.map((name) => caches.delete(name)));
            } catch (err) {
                debugWarn('Cache cleanup failed:', err);
            }

            try {
                await self.clients.claim();
                debugLog('Took control of clients');
            } catch (err) {
                debugWarn('clients.claim() failed:', err);
            }

            if (lastActivatedVersion === CACHE_VERSION) {
                debugLog('Already notified clients for', CACHE_VERSION);
                return;
            }
            lastActivatedVersion = CACHE_VERSION;

            const count = await notifyClients({
                type: 'SW_ACTIVATED',
                version: CACHE_VERSION
            });
            debugLog('Notified', count, 'client(s)');
        })()
    );
});

// ============================================================
// [8] unhandledrejection
// ============================================================
self.addEventListener('unhandledrejection', (event) => {
    const reason = event.reason;
    const message =
        (reason && reason.message) ? reason.message :
        (reason && reason.stack)   ? String(reason.stack).split('\n')[0] :
        String(reason);

    debugWarn('Unhandled rejection:', message);

    notifyClients({
        type: 'SW_ERROR',
        version: CACHE_VERSION,
        message: message
    }).catch(() => { });

    event.preventDefault();
});

// ============================================================
// [9] message handler
// ============================================================
self.addEventListener('message', (event) => {
    if (!event.data) return;

    const type = event.data.type;
    const reply = (payload) => {
        if (event.source && event.source.postMessage) {
            try {
                event.source.postMessage(payload);
            } catch (err) {
                debugWarn('reply postMessage failed:', err);
            }
        }
    };

    switch (type) {
        case 'SKIP_WAITING':
            debugLog('SKIP_WAITING received');
            event.waitUntil(self.skipWaiting());
            break;

        case 'PING':
            reply({
                type: 'PONG',
                version: CACHE_VERSION,
                timestamp: Date.now()
            });
            break;

        case 'GET_VERSION':
            reply({
                type: 'VERSION',
                version: CACHE_VERSION
            });
            break;

        case 'GET_RUNTIME_INFO':
            reply({
                type: 'RUNTIME_INFO',
                version: CACHE_VERSION,
                staticCache: STATIC_CACHE,
                runtimeCache: RUNTIME_CACHE,
                precacheAssets: PRECACHE_ASSETS,
                precacheCount: PRECACHE_ASSETS.length,
                scope: self.registration.scope,
                timestamp: Date.now()
            });
            break;

        case 'GET_PRECACHE_STATUS':
            reply({
                type: 'PRECACHE_STATUS',
                version: CACHE_VERSION,
                failedCount: lastPrecacheFailures.length,
                failures: lastPrecacheFailures.slice(0, 20)
            });
            break;

        case 'CLEAR_CACHES':
            debugLog('CLEAR_CACHES received');
            event.waitUntil(
                caches.keys()
                    .then((names) => Promise.all(names.map((n) => caches.delete(n))))
                    .then(() => {
                        reply({ type: 'CACHES_CLEARED', success: true });
                    })
                    .catch(() => {
                        reply({ type: 'CACHES_CLEARED', success: false });
                    })
            );
            break;

        case 'CHECK_UPDATE':
            debugLog('CHECK_UPDATE received');
            event.waitUntil(
                self.registration.update()
                    .then(() => {
                        const waiting = !!self.registration.waiting;
                        reply({
                            type: 'UPDATE_AVAILABLE',
                            version: CACHE_VERSION,
                            waiting: waiting
                        });
                    })
                    .catch(() => {
                        reply({
                            type: 'UPDATE_AVAILABLE',
                            version: CACHE_VERSION,
                            error: true
                        });
                    })
            );
            break;

        default:
            debugWarn('Unknown message type:', type);
    }
});

// ============================================================
// [10] Bypass list
// ============================================================
function shouldBypass(request) {
    let url;
    try {
        url = new URL(request.url);
    } catch (e) {
        return true;
    }

    // 1) External origins
    if (url.origin !== self.location.origin) return true;

    // 2) API paths — no caching.
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) return true;

    // 3) SSE
    if (url.pathname === '/events') return true;

    // 4) Authentication
    if (url.pathname.startsWith('/auth/')) return true;

    // 5) Health endpoints
    if (url.pathname === '/healthz' || url.pathname === '/readyz') return true;

    // 6) The Service Worker itself
    if (url.pathname === '/sw.js') return true;

    // 7) Non-GET requests
    if (request.method !== 'GET') return true;

    // 8) Requests with Authorization header
    if (request.headers.has('Authorization')) return true;

    // 9) Companion APK
    if (url.pathname === '/app-debug.apk') return true;

    return false;
}

// ============================================================
// [11] Navigation request detection
// ============================================================
function isNavigationRequest(request) {
    if (request.mode === 'navigate') return true;
    const accept = request.headers.get('accept') || '';
    return accept.includes('text/html');
}

// ============================================================
// [12] Network-First for HTML
// ============================================================
function networkFirstHtml(request) {
    return new Promise((resolve) => {
        let settled = false;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => {
            if (!settled) {
                debugLog('HTML timeout, aborting fetch');
                controller.abort();
            }
        }, HTML_TIMEOUT_MS);

        const fallbackToCache = () => {
            if (settled) return;
            settled = true;
            clearTimeout(timeoutId);

            caches.match(request)
                .then((cached) => {
                    if (cached) {
                        resolve(cached);
                        return;
                    }
                    return caches.match('/').then((shell) => {
                        if (shell) {
                            resolve(shell);
                        } else {
                            return buildOfflineResponse().then(resolve);
                        }
                    });
                })
                .catch(() => {
                    buildOfflineResponse().then(resolve);
                });
        };

        fetch(request, { signal: controller.signal })
            .then((response) => {
                if (settled) return;
                settled = true;
                clearTimeout(timeoutId);

                if (response && response.status === 200 && response.type === 'basic') {
                    const copy = response.clone();
                    caches.open(RUNTIME_CACHE)
                        .then((cache) => cache.put(request, copy))
                        .catch(() => { });
                }
                resolve(response);
            })
            .catch((err) => {
                if (err && err.name === 'AbortError') {
                    debugLog('Fetch aborted (timeout)');
                }
                fallbackToCache();
            });
    });
}

// ============================================================
// [13] Stale-While-Revalidate for assets
// ============================================================
function staleWhileRevalidate(request) {
    return caches.match(request).then((cached) => {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => {
            debugLog('SWR timeout, aborting background fetch');
            controller.abort();
        }, SWR_NETWORK_TIMEOUT_MS);

        const fetchPromise = fetch(request, { signal: controller.signal })
            .then((response) => {
                clearTimeout(timeoutId);
                if (response && response.status === 200 &&
                    (response.type === 'basic' || response.type === 'cors')) {
                    const copy = response.clone();
                    caches.open(RUNTIME_CACHE)
                        .then((cache) => cache.put(request, copy))
                        .catch(() => { });
                }
                return response;
            })
            .catch(() => {
                clearTimeout(timeoutId);
                if (cached) return cached;
                return new Response('Resource unavailable offline', {
                    status: 503,
                    statusText: 'Service Unavailable',
                    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
                });
            });

        if (cached) {
            return cached;
        }

        return fetchPromise;
    });
}

// ============================================================
// [14] fetch: main entry point
// ============================================================
self.addEventListener('fetch', (event) => {
    const { request } = event;

    if (shouldBypass(request)) {
        return;
    }

    if (isNavigationRequest(request)) {
        event.respondWith(networkFirstHtml(request));
        return;
    }

    event.respondWith(staleWhileRevalidate(request));
});

// ============================================================
// [15] Startup message
// ============================================================
debugLog('Service Worker loaded (version: ' + CACHE_VERSION + ')');
debugLog('Precache assets: ' + PRECACHE_ASSETS.length + ' file(s)');
debugLog('Scope: ' + self.registration.scope);