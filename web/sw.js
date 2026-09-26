/* ============================================================
 * DNSCrypt Smart Filter — Service Worker
 * Version: v1.1.0
 * Author: gasciljh
 * Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
 * ============================================================
 * Purpose:
 *   Provides offline support and caching for the WebUI and
 *   Dashboard as an installable PWA.
 *
 *   Responsibilities:
 *     • Pre-cache essential assets on install
 *     • Clean up old caches on activate
 *     • Serve HTML with network-first strategy
 *     • Serve other assets with stale-while-revalidate
 *     • Provide an offline fallback page when the server
 *       is unreachable
 *     • Notify clients when a new version is available
 *     • Handle SKIP_WAITING / CHECK_UPDATE / CLEAR_CACHES /
 *       GET_VERSION / GET_RUNTIME_INFO / PING messages
 *
 *   Caching strategy:
 *     • HTML (navigations) → Network-First with timeout (5 s),
 *       fallback to cache, then to /offline.html, then to an
 *       inline offline page.
 *     • Static assets (icons, manifest, sw.js) → Stale-While-
 *       Revalidate.
 *     • Bypassed paths (never cached):
 *         /api/*, /events, /auth/*, /healthz, /readyz,
 *         /sw.js, non-GET requests, requests with Authorization.
 *
 *   PRECACHE_ASSETS (11 files):
 *     • HTML + Manifest:
 *         / , /manifest.json , /offline.html
 *     • SVG Icons:
 *         /icon-192.svg , /icon-512.svg
 *     • PNG Icons:
 *         /icon-192.png , /icon-512.png , /apple-touch-icon.png
 *     • Favicons:
 *         /favicon-32x32.png , /favicon-16x16.png , /favicon.ico
 *
 *   Notes:
 *     • The Service Worker is bound to a single origin. WebUI
 *       (9090) and Dashboard (9091) are technically different
 *       origins → each will have its own SW cache. This is a
 *       documented limitation (see docs/ARCHITECTURE.md §6.4).
 *     • PWA shortcuts in manifest.json use hardcoded ports and
 *       cannot read runtime_info (evaluated before JS runs).
 *       See manifest.json x-note-port-limitation.
 *
 * ============================================================
 * v1.1.0 changes:
 *   • CACHE_VERSION bumped from v1.0.0 to v1.1.0. This forces
 *     all clients to fetch the new assets on next activation.
 *   • Removed the previous comment claiming CACHE_VERSION is
 *     "updated automatically by sync_versions.sh". No such
 *     script exists — the value is updated manually at each
 *     release (see "How to update CACHE_VERSION" below).
 *   • Reformatted section headers for consistency with the
 *     rest of the codebase (v1.1.0 style).
 *   • Documented the icon source pipeline in PRECACHE_ASSETS
 *     (mirrors manifest.json x-note-icon-source).
 *   • Documented the /offline.html dependency chain for the
 *     offline fallback (unified source principle).
 *
 * How to update CACHE_VERSION (manual, at each release):
 *   1. Bump the module version in VERSION, module.prop, and
 *      update.json (handled automatically by scripts/release.sh).
 *   2. Manually edit CACHE_VERSION in this file to match the
 *      new release tag (e.g. 'v1.1.0' → 'v1.2.0').
 *   3. Commit the change with the release.
 *
 *   There is no automation for this step. It is a deliberate
 *   manual decision: bumping CACHE_VERSION invalidates every
 *   client's cache, forcing a full re-download of the 11
 *   precached assets. Do NOT bump it for non-release changes
 *   (e.g. minor tweaks that don't ship a new version).
 *
 * ============================================================ */

'use strict';

// ============================================================
// [1] Configuration
// ============================================================
// CACHE_VERSION — see "How to update CACHE_VERSION" above.
// The value must match the current release tag (VERSION file).
// Example: if VERSION is "v1.2.0", this must be 'v1.2.0'.
// ============================================================
const CACHE_VERSION = 'v1.1.0';

const STATIC_CACHE  = `dnscrypt-static-${CACHE_VERSION}`;
const RUNTIME_CACHE = `dnscrypt-runtime-${CACHE_VERSION}`;

const DEBUG = false; // true for debugging only

// ============================================================
// [2] PRECACHE_ASSETS — 11 files
// ============================================================
// Full list:
//   • HTML/Manifest: 3 files (/, /manifest.json, /offline.html)
//   • SVG Icons:     2 files (icon-192.svg, icon-512.svg)
//   • PNG Icons:     3 files (icon-192.png, icon-512.png, apple-touch-icon.png)
//   • Favicons:      3 files (favicon-32x32.png, favicon-16x16.png, favicon.ico)
//
// ⚠️ Icon source pipeline (mirrors manifest.json x-note-icon-source):
//   The SVG sources are cached here as-is. The generated PNG/ICO
//   files (see /scripts/generate-icons.sh) are ALSO cached, so
//   browsers that prefer PNG get the cached version. Do NOT
//   assume a single source — the pipeline is:
//
//     icon-192.svg     → icon-192.png        (192×192)
//     icon-512.svg     → icon-512.png        (512×512)
//     icon-512.svg     → apple-touch-icon.png (180×180)
//     icon-512.svg     → favicon-32x32.png   (32×32)
//     icon-512.svg     → favicon-16x16.png   (16×16)
//     favicon-16/32    → favicon.ico         (multi-size)
//
//   The Service Worker does NOT regenerate PNGs — it only caches
//   what was already produced by the build pipeline. If you
//   change an SVG source, regenerate the PNGs first (see
//   scripts/generate-icons.sh --force) BEFORE bumping
//   CACHE_VERSION. Otherwise clients would cache stale PNGs.
//
// ⚠️ /offline.html is the UNIFIED SOURCE for the offline page:
//   buildOfflineResponse() (see [4] below) tries to fetch it
//   from the cache first, and only falls back to an inline
//   string if the cache lookup fails. This is why /offline.html
//   MUST be in PRECACHE_ASSETS — without it, the first offline
//   visit after install would show the minimal inline page
//   instead of the full offline.html experience.
//
// ⚠️ PWA dual-origin note:
//   This list is cached in the origin of the current page.
//   • If index.html is opened from 9090 → Cache holds the assets.
//   • If dashboard.html is opened from 9091 → Separate cache.
//   • /manifest.json is shared (same content, different scope).
//
// ⚠️ We do NOT cache sw.js — the browser always fetches it from
// the network. This guarantees that a new SW version is picked up
// on every page load (browsers do a byte-comparison).
// ============================================================
const PRECACHE_ASSETS = [
    // --- HTML + Manifest ---
    '/',
    '/manifest.json',
    '/offline.html',   // ← unified source for offline fallback

    // --- SVG Icons (modern browsers) ---
    '/icon-192.svg',   // source for /icon-192.png
    '/icon-512.svg',   // source for 4 PNGs (see [2] header)

    // --- PNG Icons (generated from SVG) ---
    '/icon-192.png',   // ← from icon-192.svg
    '/icon-512.png',   // ← from icon-512.svg
    '/apple-touch-icon.png',  // ← from icon-512.svg

    // --- Favicons (generated from icon-512.svg + favicon-16/32) ---
    '/favicon-32x32.png',  // ← from icon-512.svg
    '/favicon-16x16.png',  // ← from icon-512.svg
    '/favicon.ico'         // ← multi-size (16 + 32)
];

// HTML network-first timeout
const HTML_TIMEOUT_MS = 5000;

// Last version notified to clients (prevents duplicate notifications
// when activate fires more than once in the same page lifecycle).
let lastActivatedVersion = null;

// ============================================================
// [3] Suppressed logging
// ============================================================
// Logging is gated by the DEBUG flag to keep production consoles
// clean. Enable locally for troubleshooting.
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
//   1. Try to fetch /offline.html from the cache (unified source).
//   2. Fall back to an inline string if that fails.
//
// This prevents duplication between sw.js and offline.html.
//
// The inline fallback is intentionally minimal — it exists only
// for the edge case where the Service Worker has been registered
// but /offline.html was never successfully cached (e.g. first
// install offline). It is not a replacement for the full
// offline.html page.
//
// Dependency: /offline.html MUST be in PRECACHE_ASSETS (see [2])
// for step 1 to ever succeed.
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
        '<title>Offline — DNSCrypt</title>' +
        '<style>' +
        '*{margin:0;padding:0;box-sizing:border-box}' +
        'body{font-family:-apple-system,system-ui,sans-serif;background:#0d1117;color:#e6edf3;' +
        'display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center}' +
        '.box{max-width:400px;background:rgba(22,27,34,0.92);border:1px solid rgba(255,255,255,0.06);' +
        'border-radius:20px;padding:40px 24px;box-shadow:0 30px 80px rgba(0,0,0,0.7)}' +
        '.icon{font-size:64px;margin-bottom:20px;display:block;opacity:0.9}' +
        'h1{color:#f85149;font-size:24px;margin-bottom:12px;font-weight:700}' +
        'p{color:#8b949e;font-size:14px;line-height:1.6;margin-bottom:24px}' +
        'code{background:rgba(88,166,255,0.1);color:#58a6ff;padding:2px 8px;border-radius:6px;' +
        'font-family:monospace;font-size:13px;direction:ltr;display:inline-block}' +
        '.hint{font-size:12px;color:#8b949e;margin-top:16px;padding-top:16px;border-top:1px solid rgba(255,255,255,0.06)}' +
        'button{background:linear-gradient(135deg,#1f6feb,#58a6ff);color:white;border:none;padding:12px 24px;' +
        'border-radius:12px;font-weight:700;font-size:14px;cursor:pointer;font-family:inherit;transition:0.2s}' +
        'button:hover{transform:translateY(-2px);box-shadow:0 10px 20px rgba(31,111,235,0.4)}' +
        '</style></head>' +
        '<body><div class="box">' +
        '<span class="icon">📡</span>' +
        '<h1>Offline</h1>' +
        '<p>Cannot reach the local server.<br>' +
        'Make sure <code>dnscrypt-webui</code> is running on port 9090.</p>' +
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
// [5] install: cache essential assets
// ============================================================
// Uses Promise.allSettled-style semantics via per-asset catch:
// if one asset fails to cache (e.g. temporary network issue), the
// install still succeeds. This is deliberate — a partial precache
// is better than a failed install.
// ============================================================
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
// [6] activate: cleanup old caches
// ============================================================
// • Deletes every cache whose name is neither STATIC_CACHE nor
//   RUNTIME_CACHE (i.e. caches from a previous CACHE_VERSION).
// • Takes control of clients via clients.claim().
// • Notifies each client once per version.
// ============================================================
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
                return self.clients.claim();
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
                    client.postMessage({
                        type: 'SW_ACTIVATED',
                        version: CACHE_VERSION
                    });
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
//
// The reply is always posted via event.source.postMessage() so
// the requesting client can react.
// ============================================================
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
            self.skipWaiting();
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
// [8] Determine which requests should bypass the cache
// ============================================================
// Returns true if the request must NOT be handled by the SW.
// The browser then handles it as a normal network request.
//
// Rationale for each bypass:
//   • External origins    — never interfere with third parties
//   • /api/*              — must always be fresh (state changes)
//   • /events             — SSE stream, cannot be cached
//   • /auth/*             — must always hit the server
//   • /healthz, /readyz   — liveness probes need fresh responses
//   • /sw.js              — the browser must see byte changes
//   • Non-GET             — mutation methods must not be cached
//   • Authorization hdr   — bearer/token requests are session-scoped
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

    // 2) API paths — no caching
    if (url.pathname.startsWith('/api')) return true;

    // 3) SSE
    if (url.pathname === '/events') return true;

    // 4) Authentication
    if (url.pathname.startsWith('/auth/')) return true;

    // 5) Health endpoints
    if (url.pathname === '/healthz' || url.pathname === '/readyz') return true;

    // 6) The Service Worker itself — never cached
    if (url.pathname === '/sw.js') return true;

    // 7) Non-GET requests
    if (request.method !== 'GET') return true;

    // 8) Requests with Authorization header (Bearer) — not cached
    if (request.headers.has('Authorization')) return true;

    return false;
}

// ============================================================
// [9] Is this a navigation request for HTML?
// ============================================================
// Two ways to detect:
//   • request.mode === 'navigate'  (modern browsers)
//   • Accept header contains 'text/html'  (fallback for older)
// ============================================================
function isNavigationRequest(request) {
    if (request.mode === 'navigate') return true;
    const accept = request.headers.get('accept') || '';
    return accept.includes('text/html');
}

// ============================================================
// [10] Network-First for HTML with AbortController
// ============================================================
// Flow:
//   1. Start a fetch with a 5-second AbortController timeout.
//   2. On success (HTTP 200, type basic):
//        • Cache the response in RUNTIME_CACHE (for offline fallback).
//        • Return the fresh response to the client.
//   3. On timeout (AbortError) or network failure:
//        • Try the exact request from cache.
//        • Else try '/' from cache (app shell).
//        • Else return the offline response (503).
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
                    // Try '/' (app shell)
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
// ============================================================
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
// Routing decision:
//   1. Bypass list → let the browser handle it (no respondWith).
//   2. Navigation → network-first (HTML fresh, offline fallback).
//   3. Everything else → stale-while-revalidate.
// ============================================================
self.addEventListener('fetch', (event) => {
    const { request } = event;

    // 1) Bypass cache
    if (shouldBypass(request)) {
        return;
    }

    // 2) HTML → Network-First
    if (isNavigationRequest(request)) {
        event.respondWith(networkFirstHtml(request));
        return;
    }

    // 3) Other assets → SWR
    event.respondWith(staleWhileRevalidate(request));
});

// ============================================================
// [13] Startup message
// ============================================================
debugLog('Service Worker loaded (version: ' + CACHE_VERSION + ')');
debugLog('Precache assets: ' + PRECACHE_ASSETS.length + ' file(s)');
debugLog('Scope: ' + self.registration.scope);