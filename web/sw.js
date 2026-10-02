/* ============================================================
 * DNSCrypt Smart Filter — Service Worker
 * Version: v1.3.0 (Global Edition)
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
 *         /api (and /api/*), /events, /auth/*, /healthz, /readyz,
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
 *       documented limitation (see docs/ARCHITECTURE.md §6.6).
 *     • PWA shortcuts in manifest.json use RELATIVE URLs
 *       (/?source=shortcut_webui and /?source=shortcut_dashboard,
 *       MAN-2 fix in v1.2.0). They cannot read runtime_info
 *       because they are evaluated by the browser BEFORE any JS
 *       runs. The actual origin they resolve to is the manifest's
 *       CURRENT origin at install time. See manifest.json
 *       x-note-shortcuts for the full rationale.
 *
 * ============================================================
 * Language policy (v1.2.0 — Global edition):
 * ============================================================
 *   The WebUI ships with English as the DEFAULT language and
 *   an in-page toggle (langToggle) that switches to Arabic.
 *   This is the "global edition" policy: a single canonical
 *   default (English) plus first-class access for Arabic-
 *   speaking users without requiring a fork.
 *
 *   The Service Worker is LANGUAGE-NEUTRAL by design:
 *
 *     1. It caches the HTML ONCE. Both translations.en and
 *        translations.ar objects live inline in the same
 *        HTML file. There is no per-language cache entry.
 *
 *     2. The langToggle operates purely on the DOM after the
 *        page is loaded. It does not trigger any additional
 *        network requests and does not require the SW to
 *        re-fetch anything.
 *
 *     3. The user's language preference is stored CLIENT-SIDE
 *        ONLY in localStorage['dnscrypt-lang']. It never
 *        reaches the server and never appears in a request
 *        that the SW might handle.
 *
 *     4. The SW does NOT read, write, or cache
 *        localStorage['dnscrypt-lang'] (localStorage is
 *        not part of the Cache Storage API).
 *
 *   Consequence: this file is identical whether the user is
 *   browsing in English or Arabic. No language-specific logic
 *   exists here — and none should be added.
 *
 * ============================================================
 * v1.1.0 changes (kept):
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
 * v1.2.0 changes:
 *   • CACHE_VERSION bumped from 'v1.1.0' to 'v1.2.0'. This
 *     forces all clients to re-fetch the precached assets on
 *     next activation, picking up the v1.2.0 bilingual WebUI
 *     (English default + Arabic toggle) and the fixed
 *     update-banner logic.
 *
 *   • No logic changes to the caching strategy. The v1.2.0
 *     release touched only:
 *       - The client-side WebUI (index.html, dashboard.html):
 *         retained bilingual support (translations.ar, the
 *         langToggle button, and the [dir="rtl"] CSS rules),
 *         added backup state display in the System Info panel,
 *         and fixed the update-banner loop.
 *       - The shell installers (customize.sh, functions.sh,
 *         service.sh, status.sh, uninstall.sh): added the 10
 *         data-preservation layers.
 *       - main.go: added the auto-backup triggers and the
 *         startup transaction cleanup, plus the 7-field
 *         `runtime_info.backups` object (BAK-1).
 *       - Documentation.
 *     None of those changes require any modification to the
 *     Service Worker's caching or messaging logic.
 *
 *   • 📌 Important clarification about the update-banner loop:
 *       The loop was NOT caused by this file. It was caused by
 *       a client-side bug in index.html and dashboard.html:
 *         - The [Reload] button sent SKIP_WAITING to
 *           navigator.serviceWorker.controller (the OLD worker),
 *           which ignored it.
 *         - The new worker stayed in "waiting", so the banner
 *           reappeared on every reload → infinite loop.
 *       The fix (in index.html and dashboard.html v1.2.0):
 *         - Send SKIP_WAITING to swRegistration.waiting (the
 *           NEW worker).
 *         - Reload on the 'controllerchange' event.
 *         - Guard double-clicks with a `pendingReload` flag.
 *       sw.js was already correct: it handles the SKIP_WAITING
 *       message properly (calls self.skipWaiting()). No change
 *       was needed here — this note is for traceability.
 *
 *   • Added an explicit statement of the SW's independence from
 *     the v1.2.0 data-preservation layers: the SW only caches
 *     WebUI assets (HTML, CSS, JS, icons, manifest). It never
 *     touches /sdcard/dnscrypt-webui-backup/ or any file
 *     outside its own cache storage. The 10 layers live in
 *     shell scripts and main.go, which are outside the SW's
 *     scope.
 *
 *   • Added the "Language policy (Global edition)" section
 *     above, making explicit that the SW is language-neutral
 *     and why. Corrected the earlier wording that implied the
 *     v1.2.0 WebUI was "English-only" — it is not; it retains
 *     the bilingual interface from v1.0.0 and v1.1.0.
 *
 * ============================================================
 * v1.2.0 — POST-AUDIT FIXES (this file, still v1.2.0)
 * ============================================================
 * A pre-release audit of this file identified the following
 * issues. All of them are addressed in-place; no version bump.
 *
 *   🔧 SW-1 — The SKIP_WAITING message handler called
 *     `self.skipWaiting()` without wrapping the returned
 *     Promise in `event.waitUntil()`. In practice the browser
 *     usually keeps the SW alive long enough for skipWaiting()
 *     to resolve, but the spec does not guarantee it: without
 *     waitUntil, the SW may be terminated between the handler
 *     returning and the promise resolving, leaving the client
 *     in a state where 'controllerchange' never fires. The
 *     handler now uses `event.waitUntil(self.skipWaiting())`,
 *     which is the canonical pattern.
 *
 *   🔧 SW-2 — `shouldBypass()` used
 *       url.pathname.startsWith('/api')
 *     which also matches hypothetical paths like `/apidoc` or
 *     `/api_v2`. No such routes exist today, so this was not a
 *     live bug — but tightening the check to match exactly
 *     `/api` or `/api/<something>` avoids surprising future
 *     contributors who might add a static asset whose path
 *     happens to begin with `/api`. The change is:
 *       if (url.pathname === '/api' ||
 *           url.pathname.startsWith('/api/')) return true;
 *
 *   🔧 SW-3 — The inline fallback page inside
 *     `buildOfflineResponse()` is English-only (it hard-codes
 *     `lang="en" dir="ltr"` and English text). This is
 *     unavoidable: the SW cannot read
 *     localStorage['dnscrypt-lang'], and adding an Arabic
 *     variant would double the size of this file for an edge
 *     case that only triggers when `/offline.html` failed to
 *     cache during install. The comment above
 *     `buildOfflineResponse()` now documents this limitation
 *     explicitly, so that a future reader does not mistake it
 *     for an oversight. The full `/offline.html` — which IS
 *     bilingual — remains the primary offline experience; the
 *     inline page is a last-resort fallback.
 *
 *   🔧 SW-4 — The header referenced
 *       docs/ARCHITECTURE.md §6.4
 *     for the dual-origin limitation. The correct section is
 *     §6.6 (see docs/ARCHITECTURE.md, "Dual-origin PWA
 *     limitation"). The stale reference appeared in two places:
 *       • The "Notes:" bullet at the top of this header
 *         (originally: "see docs/ARCHITECTURE.md §6.4").
 *       • §[1] PRECACHE_ASSETS, the "PWA dual-origin note"
 *         (same stale §6.4 reference).
 *     Both have been corrected to §6.6. There is no §6.4 in
 *     ARCHITECTURE.md — the v1.0.0 numbering shifted during
 *     editing and the header was never re-synced.
 *
 * ============================================================
 * The SW and the 5 preserved files (v1.2.0)
 * ============================================================
 *   The v1.2.0 release preserves 5 user config files across
 *   upgrades, renames, reinstalls, and uninstalls:
 *
 *     • webui.conf
 *     • dnscrypt-proxy.toml
 *     • selected_profile.txt
 *     • allowlist.txt
 *     • denylist.txt
 *
 *   The Service Worker NEVER touches these files. Reasons:
 *
 *     1. The SW runs in a browser sandbox. It has NO access to
 *        /data/adb/modules/ or /sdcard/.
 *
 *     2. The preserved files are managed by shell scripts
 *        (customize.sh, functions.sh, service.sh) and by
 *        main.go — all of which run as root in the Android OS,
 *        completely outside the browser's reach.
 *
 *     3. The WebUI reads these files exclusively through the
 *        main.go HTTP API (e.g. GET /api?action=get_custom_rules
 *        for allowlist.txt + denylist.txt). All API endpoints
 *        are in the bypass list and are NEVER cached.
 *
 *   Consequence for offline behavior:
 *     When the WebUI server is down, the SW cannot read the
 *     preserved files. The offline page (offline.html) therefore
 *     shows generic guidance rather than the user's actual
 *     settings. It does state that the settings are safe on
 *     /sdcard/, which is true.
 *
 * ============================================================
 * The SW and runtime_info.backups (v1.2.0 — 7 fields)
 * ============================================================
 *   main.go's /api?action=runtime_info now returns a `backups`
 *   object with SEVEN fields (BAK-1):
 *
 *     "backups": {
 *       "available":        5,
 *       "in_flight_txn":    0,
 *       "orphan_txn":       0,
 *       "last_backup":      "2026-09-26 10:30:00",
 *       "last_backup_name": "20260926-103000-v1.2.0",
 *       "last_stable":      "20260926-103000-v1.2.0",
 *       "path":             "/sdcard/dnscrypt-webui-backup"
 *     }
 *
 *   The WebUI and Dashboard display these fields in their
 *   System Info panels. The SW serves those JSON responses
 *   transparently, but does NOT cache them (all /api/* paths
 *   are bypassed — see shouldBypass()).
 *
 *   ⚠️ Note: status.sh --json produces a DIFFERENT object with
 *      NINE fields (the same seven plus `status` and
 *      `last_backup_age_seconds`). The SW never sees that
 *      object — it is generated on the device by the shell
 *      tool, not by the HTTP API.
 *
 *   Result: the user always sees the CURRENT backup state, not
 *   a stale cached one.
 *
 * ============================================================
 * How to update CACHE_VERSION (manual, at each release):
 * ============================================================
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
// Example: if VERSION is "v1.3.0", this must be 'v1.3.0'.
//
// For v1.2.0, this is 'v1.2.0' (matches VERSION and module.prop).
// ============================================================
const CACHE_VERSION = 'v1.3.0';

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
//   The dual-origin limitation is documented in full at
//   docs/ARCHITECTURE.md §6.6 (SW-4 fix: the header previously
//   cited §6.4, which does not exist).
//
// ⚠️ We do NOT cache sw.js — the browser always fetches it from
// the network. This guarantees that a new SW version is picked up
// on every page load (browsers do a byte-comparison).
//
// v1.2.0 note: the asset list is UNCHANGED from v1.1.0. The
// v1.2.0 data-preservation layers live in shell scripts and
// main.go — they have no bearing on what the SW precaches.
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
// clean. To enable locally for troubleshooting, change the value
// below to `true`.
//
// ⚠️ Remember to set it back to `false` before committing — the
// flag is intentionally `false` in the released SW.
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
// ⚠️ SW-3 note on the inline fallback's language:
//   The inline fallback is ENGLISH-ONLY by design. It hard-codes
//   lang="en" dir="ltr" and English text. This is unavoidable:
//     • The SW cannot read localStorage['dnscrypt-lang'] —
//       localStorage is not part of the Cache Storage API and
//       is not accessible from a Service Worker context.
//     • Duplicating the full offline.html (which contains both
//       translations.en and translations.ar inline) would double
//       the size of this file for an edge case that only triggers
//       when /offline.html failed to cache during install (a
//       very rare scenario, since the install handler attempts
//       to precache it every time).
//     • The full /offline.html — which IS bilingual, with the
//       same langToggle + [dir="rtl"] rules as the other pages
//       — remains the PRIMARY offline experience whenever the
//       SW has successfully cached it.
//   The inline page is therefore a last-resort fallback, not a
//   substitute for offline.html. If a future version needs the
//   fallback to be bilingual, the change must happen here, and
//   it will increase the SW file size accordingly.
//
// Dependency: /offline.html MUST be in PRECACHE_ASSETS (see [2])
// for step 1 to ever succeed.
//
// v1.2.0 note: the inline fallback mentions the persistent backup
// directory (/sdcard/dnscrypt-webui-backup/), matching the
// offline.html page. This tells the user their data is safe even
// in the fallback case.
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
        '<title>Offline — DNSCrypt v' + CACHE_VERSION + '</title>' +
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
// [5] install: cache essential assets
// ============================================================
// Uses Promise.allSettled-style semantics via per-asset catch:
// if one asset fails to cache (e.g. temporary network issue), the
// install still succeeds. This is deliberate — a partial precache
// is better than a failed install.
//
// Note: we do NOT call self.skipWaiting() here. The new worker
// stays in the "waiting" state until either:
//   • All clients disconnect (natural activation), OR
//   • The client sends a SKIP_WAITING message (user pressed
//     [Reload] in the update banner).
//
// This preserves the user-controlled update flow.
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
//
// ⚠️ SKIP_WAITING: as of v1.2.0, the client sends this message
// directly to the new worker (swRegistration.waiting), NOT to
// navigator.serviceWorker.controller (which is the OLD worker).
// The handler below is correct — it calls self.skipWaiting().
// The v1.1.0 banner loop was entirely a client-side bug.
//
// SW-1 fix: the SKIP_WAITING case now wraps self.skipWaiting()
// in event.waitUntil(). Without it, the spec does not guarantee
// the SW stays alive until the promise resolves — and if the
// browser terminates the SW mid-resolution, the 'controllerchange'
// event may never fire on the client, leaving [Reload] stuck.
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
            // SW-1 fix: waitUntil ensures the SW is not
            // terminated before skipWaiting() resolves.
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
// [8] Determine which requests should bypass the cache
// ============================================================
// Returns true if the request must NOT be handled by the SW.
// The browser then handles it as a normal network request.
//
// Rationale for each bypass:
//   • External origins    — never interfere with third parties
//   • /api and /api/*     — must always be fresh (state changes)
//   • /events             — SSE stream, cannot be cached
//   • /auth/*             — must always hit the server
//   • /healthz, /readyz   — liveness probes need fresh responses
//   • /sw.js              — the browser must see byte changes
//   • Non-GET             — mutation methods must not be cached
//   • Authorization hdr   — bearer/token requests are session-scoped
//
// v1.2.0 note: /api?action=runtime_info (used to display the new
// `backups` field — 7 fields — in the WebUI/Dashboard System Info
// panels) is covered by the `/api` rule → always fresh. The SW
// does NOT cache it, so the user always sees the current backup
// state. The shell-side status.sh --json object (9 fields) never
// reaches the SW — it is generated on the device.
//
// SW-2 fix: the previous check was
//   url.pathname.startsWith('/api')
// which also matches hypothetical paths like '/apidoc'. The
// check below matches exactly '/api' or '/api/<anything>', which
// is what the server actually exposes.
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

    // 2) API paths — no caching (SW-2 fix: precise match)
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) return true;

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
// [13] Data preservation — explicit non-scope (v1.2.0)
// ============================================================
// The v1.2.0 release added 10 data-preservation layers to the
// module. This Service Worker is NOT involved in any of them.
//
// Explicit non-scope of sw.js:
//   • It NEVER touches /sdcard/dnscrypt-webui-backup/.
//   • It NEVER reads or writes user config files:
//       - webui.conf
//       - dnscrypt-proxy.toml
//       - selected_profile.txt
//       - allowlist.txt
//       - denylist.txt
//   • It NEVER reads or writes the backup manifest.
//   • It NEVER reads or writes the upgrade history log.
//   • It NEVER reads or writes .last_stable or .pending_notification.
//   • It NEVER touches txn-* or orphan-txn-* directories.
//   • Its scope is limited to:
//       - caches (IndexedDB-backed), and
//       - network interception for the WebUI pages.
//
// Where the 10 layers actually live:
//   • Layer 1-8  → proxy/customize.sh (install time)
//   • Layer 9    → proxy/service.sh + proxy/functions.sh (boot) +
//                  proxy/main.go (pre-critical backup)
//   • Layer 10   → proxy/status.sh (--diagnose) +
//                  proxy/main.go (runtime_info.backups)
//
// If a future version ever needs the SW to cooperate with the
// backup system, it MUST do so through the /api endpoints
// (which are already excluded from SW caching — see shouldBypass).
// Direct filesystem access is out of scope by design.
//
// Why the SW cannot read /sdcard/:
//   The SW runs in the browser's sandbox. It has no OS-level
//   file access. The preserved files are managed by root-owned
//   shell scripts and by main.go, all outside the browser.
// ============================================================

// ============================================================
// [14] Language policy — explicit non-scope (v1.2.0)
// ============================================================
// The WebUI ships with English as the default language and an
// in-page toggle (langToggle) that switches to Arabic. This is
// a purely client-side concern.
//
// Explicit non-scope of sw.js:
//   • It NEVER reads or writes localStorage['dnscrypt-lang'].
//     (localStorage is not part of the Cache Storage API.)
//   • It NEVER sends the user's language preference to the server.
//   • It NEVER requests language-specific assets — the HTML is
//     cached ONCE and contains both translations.en and
//     translations.ar inline.
//   • It NEVER triggers a re-fetch when the user toggles the
//     language, because the toggle operates on the DOM only.
//
// Consequence:
//   The SW is language-neutral. The same cache entry serves
//   both English and Arabic users. No language-specific logic
//   exists in this file, and none should be added.
//
// See the "Language policy (Global edition)" section at the top
// of this file for the full rationale.
// ============================================================

// ============================================================
// [15] Startup message
// ============================================================
debugLog('Service Worker loaded (version: ' + CACHE_VERSION + ')');
debugLog('Precache assets: ' + PRECACHE_ASSETS.length + ' file(s)');
debugLog('Scope: ' + self.registration.scope);
debugLog('Data preservation: NOT handled by SW (see [13])');
debugLog('Language policy: language-neutral (see [14])');