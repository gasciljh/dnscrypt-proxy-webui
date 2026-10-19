/* ============================================================
 * DNSCrypt Smart Filter — Service Worker
 * Version: v1.5.0 (Global Edition)
 * Last updated: 2026-10-19
 * ============================================================
 * Provides offline support and caching for the WebUI and
 * Dashboard as an installable PWA.
 *
 * Responsibilities:
 *   • Pre-cache essential assets on install
 *   • Clean up old caches on activate
 *   • Serve HTML with network-first strategy
 *   • Serve other assets with stale-while-revalidate
 *   • Provide an offline fallback when the server is unreachable
 *   • Notify clients when a new version is available
 *   • Handle SKIP_WAITING / CHECK_UPDATE / CLEAR_CACHES /
 *     GET_VERSION / GET_RUNTIME_INFO / PING messages
 *
 * Caching strategy:
 *   • HTML (navigations) → Network-First with 5 s timeout.
 *     Fallback chain (5 levels):
 *       1. Fresh fetch (5 s timeout)
 *       2. Exact request from cache
 *       3. App shell ('/') from cache
 *       4. /offline.html from cache
 *       5. Inline offline page (last resort)
 *   • Static assets (icons, manifest) → Stale-While-Revalidate.
 *   • /sw.js → always bypassed (browser must see byte changes).
 *
 * Bypass rules (9 in shouldBypass()):
 *   (1) external origins        — includes GitHub URLs
 *   (2) /api and /api/*         — precise match
 *   (3) /events                 — SSE stream
 *   (4) /auth/*                 — always hit the server
 *   (5) /healthz OR /readyz     — shared rule
 *   (6) /sw.js                  — browser must see bytes
 *   (7) non-GET requests        — mutation methods
 *   (8) Authorization header    — session-scoped
 *   (9) /app-debug.apk          — long-lived HTTP cache
 *
 * PRECACHE_ASSETS (11 files):
 *   • HTML + Manifest: / , /manifest.json , /offline.html
 *   • SVG Icons:       /icon-192.svg , /icon-512.svg
 *   • PNG Icons:       /icon-192.png , /icon-512.png ,
 *                      /apple-touch-icon.png
 *   • Favicons:        /favicon-32x32.png ,
 *                      /favicon-16x16.png , /favicon.ico
 *
 * Note on /dashboard.html (SW-PRECACHE-01):
 *   /dashboard.html is deliberately NOT in PRECACHE_ASSETS.
 *   Reason: the WebUI (9090) and Dashboard (9091) are distinct
 *   origins. On the WebUI origin, /dashboard.html does not
 *   exist as a distinct file — the catch-all route in main.go
 *   serves index.html for any unknown path. Precaching it
 *   there would cache the wrong content under a misleading key.
 *   On the Dashboard origin, /dashboard.html duplicates `/`.
 *   Reference: docs/REFERENCE.md §7.7.6.
 *
 * Design notes:
 *   • The SW is bound to a single origin. WebUI (9090) and
 *     Dashboard (9091) are different origins → each has its
 *     own SW cache. Documented limitation; see
 *     docs/REFERENCE.md §7.7.1–§7.7.5.
 *   • PWA shortcuts in manifest.json use RELATIVE URLs. They
 *     resolve to the manifest's CURRENT origin at install
 *     time. See manifest.json x-note-shortcuts.
 *
 * v1.5.0 corrections:
 *   • SW-PRECACHE-01 — PRECACHE_ASSETS is 11 files (not 12).
 *   • SW-DEF-01 — clients.claim() is guarded with .catch() so
 *     a rejected claim no longer skips the client notification
 *     loop.
 *   • SW-DEF-02 — client.postMessage() is wrapped in try/catch
 *     so a single invalid client cannot abort the loop.
 * ============================================================ */

'use strict';

// ============================================================
// [1] Configuration
// ============================================================
// CACHE_VERSION — must match the current release tag (VERSION
// file). Bumping it invalidates every client's cache and
// forces a full re-download of the 11 precached assets.
//
// Manual step at each release: bump CACHE_VERSION.
// ============================================================
const CACHE_VERSION = 'v1.5.0';

const STATIC_CACHE  = `dnscrypt-static-${CACHE_VERSION}`;
const RUNTIME_CACHE = `dnscrypt-runtime-${CACHE_VERSION}`;

const DEBUG = false;

// ============================================================
// [2] PRECACHE_ASSETS — 11 files (SW-PRECACHE-01)
// ============================================================
// Icon source pipeline (mirrors manifest.json x-note-icon-source):
//   icon-192.svg  → icon-192.png
//   icon-512.svg  → icon-512.png, apple-touch-icon.png,
//                   favicon-32x32.png, favicon-16x16.png
//   favicon-16/32 → favicon.ico
//
// The SW does NOT regenerate PNGs — it only caches what the
// build pipeline (scripts/generate-icons.sh) produced. If you
// change an SVG source, regenerate the PNGs BEFORE bumping
// CACHE_VERSION.
//
// /offline.html is the UNIFIED SOURCE for the offline page.
// buildOfflineResponse() tries to fetch it from cache first;
// the inline string is a last-resort fallback.
//
// The companion APK (web/app-debug.apk) is deliberately NOT in
// this list — see shouldBypass() rule 9.
//
// /dashboard.html is deliberately NOT in this list — see the
// SW-PRECACHE-01 note in the header.
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

// HTML network-first timeout.
const HTML_TIMEOUT_MS = 5000;

// Last version notified to clients (prevents duplicate
// notifications when activate fires more than once in the same
// page lifecycle).
let lastActivatedVersion = null;

// ============================================================
// [3] Suppressed logging
// ============================================================
function debugLog(...args) {
    if (DEBUG) console.log('[SW ' + CACHE_VERSION + ']', ...args);
}

function debugWarn(...args) {
    if (DEBUG) console.warn('[SW ' + CACHE_VERSION + ']', ...args);
}

// ============================================================
// [4] Offline page
// ============================================================
// Strategy:
//   1. Try to fetch /offline.html from the cache.
//   2. Fall back to an inline string if that fails.
//
// The inline fallback is ENGLISH-ONLY by design: the SW cannot
// read localStorage['dnscrypt-lang'] — localStorage is not part
// of the Cache Storage API. The full /offline.html (bilingual)
// is the primary offline experience whenever the SW has
// successfully cached it.
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
// [5] install
// ============================================================
// Per-asset catch → install succeeds even if one asset fails
// to cache (temporary network issue). A partial precache is
// better than a failed install.
//
// self.skipWaiting() is NOT called here. The new worker stays
// in the "waiting" state until either all clients disconnect
// or the client sends SKIP_WAITING (user pressed [Reload] in
// the update banner).
self.addEventListener('install', (event) => {
    debugLog('Installing...');

    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then((cache) => {
                return Promise.all(
                    PRECACHE_ASSETS.map((url) => {
                        return cache.add(url).catch((err) => {
                            debugWarn('Pre-cache failed for', url, err);
                        });
                    })
                );
            })
            .then(() => {
                debugLog('Installed — waiting for activation');
            })
    );
});

// ============================================================
// [6] activate
// ============================================================
// • Deletes every cache whose name is neither STATIC_CACHE nor
//   RUNTIME_CACHE (i.e. caches from a previous CACHE_VERSION).
// • Takes control of clients via clients.claim().
// • Notifies each client once per version.
//
// SW-DEF-01: clients.claim() is guarded with .catch().
// SW-DEF-02: client.postMessage() is wrapped in try/catch.
self.addEventListener('activate', (event) => {
    debugLog('Activating...');

    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                const toDelete = cacheNames.filter((name) => {
                    return name !== STATIC_CACHE && name !== RUNTIME_CACHE;
                });

                if (toDelete.length > 0) {
                    debugLog('Deleting old caches:', toDelete);
                }

                return Promise.all(toDelete.map((name) => caches.delete(name)));
            })
            .then(() => {
                debugLog('Taking control of clients');
                return self.clients.claim().catch((err) => {
                    debugWarn('clients.claim() failed:', err);
                });
            })
            .then(() => {
                return self.clients.matchAll({ type: 'window' });
            })
            .then((clients) => {
                if (lastActivatedVersion === CACHE_VERSION) {
                    debugLog('Already notified clients for', CACHE_VERSION);
                    return;
                }
                lastActivatedVersion = CACHE_VERSION;

                clients.forEach((client) => {
                    try {
                        client.postMessage({
                            type: 'SW_ACTIVATED',
                            version: CACHE_VERSION
                        });
                    } catch (err) {
                        debugWarn('client.postMessage failed:', err);
                    }
                });
                debugLog('Notified', clients.length, 'client(s)');
            })
    );
});

// ============================================================
// [7] message handler
// ============================================================
// Supported messages from clients:
//   • SKIP_WAITING     — activate this SW immediately
//   • PING             — liveness check
//   • GET_VERSION      — return CACHE_VERSION
//   • GET_RUNTIME_INFO — return cache names + asset list + scope
//   • CLEAR_CACHES     — delete all caches
//   • CHECK_UPDATE     — ask the browser to check for a new SW
self.addEventListener('message', (event) => {
    if (!event.data) return;

    const type = event.data.type;
    const reply = (payload) => {
        if (event.source && event.source.postMessage) {
            event.source.postMessage(payload);
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
                        if (self.registration.waiting) {
                            reply({
                                type: 'UPDATE_AVAILABLE',
                                version: CACHE_VERSION,
                                waiting: true
                            });
                        } else {
                            reply({
                                type: 'UPDATE_AVAILABLE',
                                version: CACHE_VERSION,
                                waiting: false
                            });
                        }
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
// [8] Bypass list
// ============================================================
// Returns true if the request must NOT be handled by the SW.
// The browser then handles it as a normal network request.
//
// 9 rules total:
//   1. External origins    — never interfere with third parties.
//                             Covers the v1.5.0 GitHub URLs.
//   2. /api and /api/*     — always fresh (state changes).
//                             Covers all 4 companion-install
//                             endpoints (v1.5.0):
//                             POST /api/install_companion_app,
//                             POST /api/uninstall_companion_app,
//                             GET  /api?action=install_token,
//                             GET  /api?action=companion_app_state.
//   3. /events             — SSE stream, cannot be cached.
//   4. /auth/*             — must always hit the server.
//   5. /healthz, /readyz   — liveness probes need fresh responses.
//   6. /sw.js              — the browser must see byte changes.
//   7. Non-GET             — mutation methods must not be cached.
//   8. Authorization hdr   — bearer/token requests are
//                             session-scoped.
//   9. /app-debug.apk      — served with immutable Cache-Control
//                             by main.go; the browser's HTTP cache
//                             is the correct storage layer.
//
// The /api check matches exactly '/api' or '/api/<anything>'
// instead of any path starting with '/api'.
function shouldBypass(request) {
    let url;
    try {
        url = new URL(request.url);
    } catch (e) {
        return true;
    }

    // 1) External origins — includes the v1.5.0 GitHub URLs.
    if (url.origin !== self.location.origin) return true;

    // 2) API paths — no caching. Covers all v1.5.0 companion
    //    endpoints (install, uninstall, install_token,
    //    companion_app_state).
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) return true;

    // 3) SSE
    if (url.pathname === '/events') return true;

    // 4) Authentication
    if (url.pathname.startsWith('/auth/')) return true;

    // 5) Health endpoints
    if (url.pathname === '/healthz' || url.pathname === '/readyz') return true;

    // 6) The Service Worker itself — never cached.
    if (url.pathname === '/sw.js') return true;

    // 7) Non-GET requests
    if (request.method !== 'GET') return true;

    // 8) Requests with Authorization header (Bearer) — not cached.
    if (request.headers.has('Authorization')) return true;

    // 9) Companion APK — served with Cache-Control: public,
    //    max-age=3600, immutable by main.go; the browser HTTP
    //    cache is the right place for a ~3 MB download.
    if (url.pathname === '/app-debug.apk') return true;

    return false;
}

// ============================================================
// [9] Navigation request detection
// ============================================================
function isNavigationRequest(request) {
    if (request.mode === 'navigate') return true;
    const accept = request.headers.get('accept') || '';
    return accept.includes('text/html');
}

// ============================================================
// [10] Network-First for HTML
// ============================================================
// Flow (5 levels):
//   1. Start a fetch with a 5-second AbortController timeout.
//   2. On success (HTTP 200, type basic):
//        • Cache the response in RUNTIME_CACHE (for offline).
//        • Return the fresh response to the client.
//   3. On timeout (AbortError) or network failure:
//        a. Try the exact request from cache.
//        b. Else try '/' from cache (app shell).
//        c. Else return the offline response (503).
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
                        .catch(() => {});
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
// [11] Stale-While-Revalidate for assets
// ============================================================
// Flow:
//   1. Look up the request in cache.
//   2. Start a network fetch in parallel.
//   3. Return the cached response immediately if present.
//   4. If not cached, wait for the network response.
//   5. On network success, update RUNTIME_CACHE for next time.
//
// The companion APK (/app-debug.apk) is in the bypass list
// (rule 9) — never reaches this function.
function staleWhileRevalidate(request) {
    return caches.match(request).then((cached) => {
        const fetchPromise = fetch(request)
            .then((response) => {
                if (response && response.status === 200 &&
                    (response.type === 'basic' || response.type === 'cors')) {
                    const copy = response.clone();
                    caches.open(RUNTIME_CACHE)
                        .then((cache) => cache.put(request, copy))
                        .catch(() => {});
                }
                return response;
            })
            .catch(() => {
                if (cached) return cached;
                throw new Error('Network failed and no cache');
            });

        return cached || fetchPromise;
    });
}

// ============================================================
// [12] fetch: main entry point
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
// [13] Startup message
// ============================================================
debugLog('Service Worker loaded (version: ' + CACHE_VERSION + ')');
debugLog('Precache assets: ' + PRECACHE_ASSETS.length + ' file(s)');
debugLog('Scope: ' + self.registration.scope);