# HTTP API Reference — DNSCrypt Smart Filter

Complete reference for the HTTP API used to control the module programmatically.

**Version**: v1.5.0
**Base URL (WebUI)**: `http://127.0.0.1:9090`
**Base URL (Dashboard)**: `http://127.0.0.1:9091`
**Last updated**: 2026-10-15
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.5.0 changes**:
>   • Version bumped from v1.4.0 to v1.5.0.
>   • **Companion app one-tap install** — four new endpoints:
>       - `POST /api/install_companion_app` — root install via
>         `proxy/install_app.sh` (5-level `pm install` cascade).
>         CSRF token required, per-IP rate limit (5 failed
>         attempts / 15 min).
>       - `POST /api/uninstall_companion_app` — reserved for
>         future UI.
>       - `GET /api?action=install_token` — one-shot CSRF token
>         (60-second TTL) for the install flow. **Localhost-only**.
>       - `GET /api?action=companion_app_state` — cached install
>         state (30-second TTL).
>   • **Install-method modal (IDX-24)** — the WebUI confirm modal
>     offers **three actions across two categories** (local root
>     install + open GitHub page + direct APK download).
>   • **Install timeout raised** — the WebUI's
>     `getTimeoutForUrl()` returns 120 s for
>     `install_companion_app`. The server-side `INSTALL_TIMEOUT`
>     in `main.go` §[3b] is 90 s. `HTTP_WRITE_TIMEOUT` is 150 s.
>   • **Retry policy** — the WebUI disables retries for
>     `install_companion_app` (`retries = 0`).
>   • **Compatibility**: All v1.4.0 clients continue to work
>     without modification. All v1.5.0 changes are additive.
>   • **Post-release patches**: the `install_token` endpoint is
>     now gated to localhost (see §1.1). `HTTP_WRITE_TIMEOUT` was
>     raised from 60 s to 150 s to prevent client resets on slow
>     installs.

> **v1.4.0 changes** (historical):
>   • Version bumped from v1.3.0 to v1.4.0.
>   • **New static route**: `GET /app-debug.apk`.
>   • **`POST /api/remove_module` hardened** against CodeQL
>     `go/path-injection`.
>   • **Companion Android app integration**.

> **v1.3.0 changes** (historical):
>   • **PWA install button** (WebUI).
>   • **Live status LED** on the Today counter.
>   • **`service.sh` DNS auto-start fix**.
>   • **`runtime_info.backups` snapshot detection is now
>     manifest-based (SNAP-MANIFEST)**.

> **v1.2.0 changes** (historical):
>   • **Global edition — English default with Arabic toggle**.
>   • `runtime_info.backups` now returns **seven** fields.
>   • **`POST /api/ensure_running_service` now requires the
>     `X-Watchdog-Token` header**.
>   • Five destructive endpoints now trigger a **pre-critical
>     backup** before writing.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication](#2-authentication)
3. [Rate Limiting](#3-rate-limiting)
4. [Response Format](#4-response-format)
5. [Error Codes](#5-error-codes)
6. [Endpoints](#6-endpoints)
7. [Path Matching](#7-path-matching)
8. [SSE Events](#8-sse-events)
9. [Health Checks](#9-health-checks)
10. [Examples](#10-examples)
11. [Changelog](#11-changelog)
12. [References](#12-references)
13. [Documentation Corrections to This File](#13-documentation-corrections-to-this-file)

---

## 1. Overview

### 1.1 Basics

| Item | Value |
|---|---|
| **Protocol** | HTTP/1.1 |
| **Binding** | `127.0.0.1` only (not reachable from the network by default) |
| **Encoding** | UTF-8 |
| **Content-Type** | `application/json` (default for responses) |
| **Auth** | Bearer / Cookie / Basic / Watchdog token / Install token |
| **Language** | The WebUI is bilingual (English default + Arabic toggle). The API itself is **language-neutral** — it returns JSON without localized strings, except for the AR/EN message pair on install errors (§6.2.14). |

**Timeout table**:

| Scope | Endpoint | Value | Source |
|---|---|---|---|
| **HTTP client** | normal GET | 15 s | `web/index.html` `getTimeoutForUrl()` |
| **HTTP client** | `toggle_service` / `restart_service` | 60 s | `web/index.html` |
| **HTTP client** | `install_companion_app` | 120 s | `web/index.html` |
| **HTTP client** | `update_profile` | 310 s | `web/index.html` |
| **HTTP server** | every request (write phase) | 150 s | `main.go` `HTTP_WRITE_TIMEOUT` |
| **Handler** | `install_companion_app` | 90 s | `main.go` §[3b] `INSTALL_TIMEOUT` |
| **Cascade** | inside `install_app.sh` | 75 s | `install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS` |

**Timeout hierarchy**: cascade (75 s) < handler (90 s) < WriteTimeout
(150 s) < client (up to 310 s for `update_profile`). The cascade
deadline is deliberately shorter than the handler timeout, so the
`EXIT / INT / TERM` trap inside `install_app.sh` always fires
before `main.go`'s `exec.CommandContext` kills the script. See
`docs/SECURITY.md` §5.36.4 for the trap semantics.

**Localhost gate**: `main.go` applies the `isLocalRequest()` gate
to **all three install surfaces**:

- `POST /api/install_companion_app`
- `POST /api/uninstall_companion_app`
- `GET  /api?action=install_token`

A non-loopback request to any of the three returns HTTP 403 with
a JSON body. See §6.1.16, §6.2.14, and §6.2.15.

**Service Worker bypass**: all four new companion-install
endpoints live under `/api/*`, which is already handled by the
Service Worker's bypass rule 2. The two GitHub URLs are external
origins, handled by bypass rule 1. The `/app-debug.apk` fallback
path is handled by bypass rule 9. **No Service Worker change was
required for v1.5.0.**

### 1.2 Port Constraints

| Port | Purpose | Note |
|:----:|---|---|
| **9090** | WebUI (default) | Configurable via `webui.conf` |
| **9091** | Dashboard (default) | Configurable via `webui.conf` |
| **8080** | `monitoring_ui` (internal) | **Reserved — do not use** |
| **5354** | DNS engine (internal) | Reserved — do not use |

`main.go` refuses to start if:

- `PORT` = `DASHBOARD_PORT`
- `PORT` = `8080`
- `DASHBOARD_PORT` = `8080`

`readConfPort()` validates the range `[1, 65535]`. Values outside
the range fall back to the default (9090 / 9091).

`MONITORING_UI_PORT` is declared as a Go constant in `main.go`
and reused in every place that needs the reserved port including
`metricsProxyHandler`.

**Port cache**: `getWebUIPort()` and `getDashboardPort()` now
route through a 30-second TTL cache. The values returned by
`/api?action=runtime_info` are still the authoritative current
values; the cache only avoids redundant `webui.conf` reads within
a 30 s window. Editing `webui.conf` and reloading the WebUI may
show the old port for up to 30 s. A `main.go` restart always
re-reads the file.

### 1.3 Endpoint Map

```text
┌─────────────────────────────────────────────────────┐
│  Public (no auth)                                            │
│    GET  /healthz                 Liveness check              │
│    GET  /readyz                  Readiness (localhost)       │
│    GET  /sw.js                   Service Worker              │
│    GET  /manifest.json           PWA manifest                │
│    GET  /icon-192.svg            PWA icon (SVG)              │
│    GET  /icon-512.svg            PWA icon (maskable)         │
│    GET  /icon-192.png            PWA icon (PNG)              │
│    GET  /icon-512.png            PWA icon (PNG maskable)     │
│    GET  /apple-touch-icon.png    Launcher icon fallback      │
│    GET  /favicon-32x32.png       Modern favicon              │
│    GET  /favicon-16x16.png       Legacy favicon              │
│    GET  /favicon.ico             IE + bookmarks              │
│    GET  /offline.html            Offline fallback            │
│    GET  /app-debug.apk           Companion Android app       │
│                                  (optional)                  │
│    GET  /                        index.html                  │
│                                                              │
│  Auth required (GET)                                         │
│    GET  /api?action=status       Service status              │
│    GET  /api?action=get_profile  Current profile             │
│    GET  /api?action=get_custom_rules  Rules                  │
│    GET  /api?action=get_rules_state   Hash state             │
│    GET  /api?action=stats        Blocked count               │
│    GET  /api?action=resources    RAM usage                   │
│    GET  /api?action=logs         Recent logs                 │
│    GET  /api?action=list_logs    Log files list              │
│    GET  /api?action=read_log     Read log file               │
│    GET  /api?action=get_progress Progress                    │
│    GET  /api?action=check_old_modules  Old modules           │
│    GET  /api/runtime_info        Build + ports + memory      │
│    GET  /api/runtime_info/       (same; trailing slash)      │
│    GET  /api?action=runtime_info (same; query-string form)   │
│                                  → all include backups       │
│    GET  /api?action=install_token     ← v1.5.0 (localhost)   │
│                                  One-shot CSRF token (60 s)  │
│    GET  /api?action=companion_app_state  ← v1.5.0            │
│                                  Install state (30 s cache)  │
│    GET  /api/download_log        Download log file           │
│    GET  /api/metrics             Metrics (Dashboard)         │
│    GET  /events                  SSE stream                  │
│                                                              │
│  Auth required (POST)                                        │
│    POST /api/auth/login          Login (POST-only)           │
│    POST /api/auth/logout         Logout (POST-only)          │
│    POST /api/update_profile      Update blocklist            │
│    POST /api/save_allowlist      Save allowlist              │
│    POST /api/save_denylist       Save denylist               │
│    POST /api/save_custom_rules   Save both                   │
│    POST /api/append_denylist     Append to denylist          │
│    POST /api/clear_log_file      Clear one log               │
│    POST /api/clear_logs          Clear main log              │
│    POST /api/remove_module       Remove old module           │
│    POST /api/toggle_service      Toggle on/off               │
│    POST /api/restart_service     Restart DNS                 │
│    POST /api/install_companion_app    ← v1.5.0 (localhost)   │
│                                  Root install (CSRF token)   │
│    POST /api/uninstall_companion_app  ← v1.5.0 (localhost)   │
│                                  Uninstall (reserved for UI) │
│                                                              │
│  Watchdog token OR user auth (POST)                          │
│    POST /api/ensure_running_service  Ensure DNS running      │
│      • localhost + POST + valid X-Watchdog-Token → allowed   │
│      • otherwise → normal user auth (Bearer/Cookie/Basic)    │
│      • see §2.8 and §6.2.13                                  │
└─────────────────────────────────────────────────────┘
```

### 1.4 What was New in v1.5.0

| Section | Change | Reference |
|---|---|---|
| **§1.3** | 4 new endpoints | Companion install |
| **§3.1** | `install_companion_app` added to the rate limit table | Rate limiting |
| **§5.2** | Install-specific error codes added | Error codes |
| **§6.1.16** | `GET /api?action=install_token` documented | CSRF token |
| **§6.1.17** | `GET /api?action=companion_app_state` documented | Install state |
| **§6.2.14** | `POST /api/install_companion_app` documented | Root install |
| **§6.2.15** | `POST /api/uninstall_companion_app` documented | Reserved for UI |
| **§10.11** | Watchdog install examples added | — |
| **§11** | Changelog entry for v1.5.0 | — |
| **§12.8** | v1.5.0 References added | — |
| **§13** | Documentation corrections consolidated | This file |

**Architectural note**: v1.5.0 is additive. The API structure is
unchanged; the only new auth requirement is the one-shot CSRF
token on `install_companion_app`, which is a per-request token
unrelated to the session-based schemes in §2.2.

### 1.5 What was New in v1.5.0+ (Post-release)

| Section | Change |
|---|---|
| **§1.1** | Timeout table expanded to include `HTTP_WRITE_TIMEOUT` (150 s) |
| **§1.1** | Localhost gate documented on all three install surfaces |
| **§6.1.16** | `install_token` endpoint documented as localhost-only |
| **§6.2.14** | Response shapes corrected to match `main.go` |
| **§11** | Changelog entry for the post-release patch set |
| **§13** | All corrections consolidated |

### 1.6 What was New in v1.4.0 (historical)

| Section | Change | Reference |
|---|---|---|
| **§1.3** | New static route: `GET /app-debug.apk` | Companion APK |
| **§6.1.15** | New subsection documenting the companion APK route | Companion APK |
| **§6.2.10** | `remove_module` documented with CodeQL path-injection hardening | CodeQL fix |
| **§11** | Changelog entry for v1.4.0 | — |

### 1.7 What was New in v1.3.0 (historical)

| Section | Change |
|---|---|
| **§6.2.13** | `ensure_running_service` is now called directly by `service.sh` at boot |
| **§6.1.7** | Snapshot detection is now manifest-based (SNAP-MANIFEST) |
| **§11** | Changelog entry for v1.3.0 |

### 1.8 What was New in v1.2.0 (historical)

| Section | Change |
|---|---|
| **§1.1** | Language is now bilingual |
| **§2.8** | Watchdog token (`X-Watchdog-Token`) |
| **§6.1.7** | `runtime_info.backups` returns **7 fields** |
| **§6.2.3–§6.2.7** | Destructive endpoints create a pre-critical backup |
| **§6.2.13** | `ensure_running_service` requires `X-Watchdog-Token` |
| **§10.6–§10.7** | New backup / recovery examples |

---

## 2. Authentication

### 2.1 Schemes

| Scheme | Header/Cookie | Priority | Rate Limited |
|---|---|:---:|:---:|
| Bearer | `Authorization: Bearer <token>` | 1 | No |
| Cookie | `Cookie: dnscrypt_session=<token>` | 2 | No |
| Basic | `Authorization: Basic <base64>` | 3 | Yes |
| Watchdog token | `X-Watchdog-Token: <64-hex>` | 0 (before all above, endpoint-scoped) | No |

**Watchdog token priority**: as of v1.2.0, `checkAuth()` checks
for the `X-Watchdog-Token` header **before** any of the user
schemes — but **only** for `POST /api/ensure_running_service`
from a loopback address. See §2.8 for the full design.

**Install token** is **not** an alternative to the schemes above.
It is an additional, per-request credential required **in
addition to** a valid session for a single endpoint. See §2.7.

### 2.2 Credentials Source

Credentials are read exclusively from the `[monitoring_ui]`
section of `dnscrypt-proxy.toml`.

```toml
[monitoring_ui]
  enabled = true
  listen_address = '127.0.0.1:8080'
  username = 'admin_xxxxxxxx'
  password = 'xxxxxxxxxxxxxxxxxxxxxxxx'
```

Section-restricted parsing:

- `main.go` → `getMonitoringAuth` tracks sections.
- `functions.sh` → `read_toml_credentials` tracks sections.
- `watchdog.sh` → reads inline with section tracking.
- `customize.sh` → §[18] verification with section tracking.

Section header with comment is supported:

```toml
[monitoring_ui] # monitoring section
  username = 'admin'
```

The pattern is extracted between `[` and `]` (first occurrence).

Auth cache:

- `getMonitoringAuth()` caches credentials for **60 seconds**.
- Changing credentials in TOML takes effect within ≤ 60 seconds.
- For immediate effect: restart the WebUI.

**Missing `[monitoring_ui]` section**: if the file is missing,
unreadable, or has no non-empty `username` and `password` in the
`[monitoring_ui]` section, `getMonitoringAuth()` returns
`("", "")`. In that state, `checkAuth()` treats **every request
as authorized**. This is intentional for the default localhost
setup, but it means a **missing configuration is not a
fail-closed condition**. If `BIND_ADDR` is anything other than
`127.0.0.1` / `::1`, `main.go` refuses to start without
credentials — see `docs/SECURITY.md` §5.1.

### 2.3 Login — POST-only

`/api/auth/login` accepts **POST only**.

- GET/HEAD/PUT/DELETE → **405 Method Not Allowed**.
- Reason: prevents a CSRF vector and prevents credentials from
  leaking into the URL.

**Request:**

```http
POST /api/auth/login HTTP/1.1
Host: 127.0.0.1:9090
Content-Type: application/json
Content-Length: 56

{
  "username": "admin_abc12345",
  "password": "SecurePassword12345678"
}
```

**Alternative (form-urlencoded):**

```http
POST /api/auth/login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

username=admin_abc12345&password=SecurePassword12345678
```

**Response (200 OK):**

```http
HTTP/1.1 200 OK
Content-Type: application/json
Set-Cookie: dnscrypt_session=<token>; Path=/; Max-Age=86400; HttpOnly; Secure; SameSite=Lax

{
  "status": "ok",
  "message": "Login successful",
  "profile": {
    "key": "pro",
    "name": "HaGeZi PRO",
    "entries": 250000,
    "is_empty": false,
    "last_update": "2026-09-26 10:30:00",
    "memory_limit_mb": 120
  }
}
```

> **Note on `Secure`**: the `Secure` attribute is set only when
> the server runs on a loopback address (`BIND_ADDR` = `127.0.0.1`,
> `::1`, or `localhost`). On a LAN bind the attribute is omitted
> so that browsers accept the cookie over plain HTTP. See §2.4.

There is no `token` field in the response. Authentication relies
solely on the HttpOnly cookie.

**Response (405 — Method Not Allowed):**

```http
HTTP/1.1 405 Method Not Allowed
Allow: POST
Content-Type: application/json

{
  "status": "error",
  "message": "Login requires POST (CSRF protection)"
}
```

**Response (401 Unauthorized):**

```json
{
  "status": "error",
  "message": "Invalid credentials"
}
```

**Response (429 Too Many Requests):**

```json
{
  "status": "error",
  "message": "Too many attempts. Try again later."
}
```

### 2.4 Cookie Properties

| Property | Value | Note |
|---|---|---|
| Name | `dnscrypt_session` | — |
| Path | `/` | — |
| MaxAge | 86400 (24 h) | — |
| HttpOnly | `true` | JavaScript cannot read it |
| Secure | conditional | `true` only on loopback binds |
| SameSite | `Lax` | PWA-friendly |

Secure details:

- `true` if `BIND_ADDR` = `127.0.0.1` / `::1` / `localhost`.
- `false` otherwise (LAN access).

SameSite details:

- `Lax` (instead of `Strict`).
- Supports PWA shortcuts.
- Protects against CSRF (cross-site POST forbidden).

### 2.5 Logout — POST-only

`/api/auth/logout` accepts **POST only**.

**Request:**

```http
POST /api/auth/logout HTTP/1.1
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response:**

```http
HTTP/1.1 200 OK
Set-Cookie: dnscrypt_session=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax

{"status": "ok"}
```

**Response (405 — Method Not Allowed):**

```json
{
  "status": "error",
  "message": "Logout requires POST (CSRF protection)"
}
```

### 2.6 Authentication Flow Diagram

```text
┌────────────────────────────────────────────────┐
│  User                                                  │
│  POST /api/auth/login                                  │
│  {"username":"admin","password":"..."}                 │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌───────────────────────────────────────────────────┐
│  main.go — handleAPI                                       │
│  if hasEndpoint(path, "auth/login") {                      │
│      if r.Method != POST → 405 + Allow: POST              │
│      handleLogin(w, r)                                     │
│  }                                                         │
└────────────────────┬──────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────┐
│  handleLogin()                                              │
│  1. ip := getClientIP(r)  ← IPv6-safe                      │
│  2. if isLockedOut(ip) → 429                               │
│  3. read credentials from JSON body                         │
│  4. subtle.ConstantTimeCompare                              │
│  5. if fail → recordLoginAttempt(ip, false)                │
│  6. if success → createSession + Set-Cookie                │
│  7. response: {status, message, profile}                    │
│     (no token — cookie-only)                                │
└────────────────────────────────────────────────────┘
```

For the Watchdog token path — which runs **before** any of the
above when the request is a localhost POST to
`ensure_running_service` — see §2.8. For the install token path
— which runs **after** normal auth on `install_companion_app` —
see §2.7.

### 2.7 Install Token (v1.5.0)

The install token is a **one-shot CSRF token** consumed by
`POST /api/install_companion_app`. It is **not** a session
scheme; it is a per-request nonce that prevents cross-site
request forgery on the install endpoint.

```text
┌──────────────────────────────────────────────────────────────┐
│  Token lifecycle (v1.5.0)                                    │
│                                                              │
│  1. Client sends GET /api?action=install_token               │
│     • checkAuth() must succeed (session cookie or bearer)    │
│     • isLocalRequest() must succeed                          │
│     • generateInstallToken():                                │
│         – 32 bytes from crypto/rand                          │
│         – hex-encode → 64 chars                              │
│         – store in installTokens[token] = {expiry}           │
│         – expiry = now + INSTALL_TOKEN_TTL (60 s)            │
│     • response: { "token": "abc...", "ttl": 60 }             │
│                                                              │
│  2. Client sends POST /api/install_companion_app             │
│     body: token=<token>                                      │
│     • checkAuth() must succeed                               │
│     • isLocalRequest() must succeed                          │
│     • isInstallLockedOut(ip) must be false                   │
│     • validateAndConsumeInstallToken(token):                 │
│         – look up in installTokens                           │
│         – if not found OR expired → 401                      │
│         – if found → delete from map (one-shot) → allow      │
│     • recordInstallAttempt(ip, success)                      │
│     • callInstallScript() runs install_app.sh                │
│                                                              │
│  3. Expired tokens are garbage-collected lazily              │
└──────────────────────────────────────────────────────────────┘
```

**Characteristics**:

| Aspect | Value |
|---|---|
| TTL | 60 seconds (`INSTALL_TOKEN_TTL`) |
| Format | 64 hex chars (32 bytes) |
| Reusable? | ❌ One-shot — deleted from the map on first use |
| Consumed by | `POST /api/install_companion_app` only |
| Rate-limited? | Yes — the install endpoint, per-IP (5 failed attempts / 15 min). See §3.1 |
| Session-related? | No — orthogonal to the cookie/bearer schemes in §2.1 |
| Localhost-only? | Yes — `isLocalRequest()` gate on the token endpoint itself |

**Why a separate token (not just the session cookie)?** The
install endpoint performs a root operation with side effects that
outlive the session (the app remains installed after logout). A
one-shot token forces the WebUI to explicitly opt-in per install
attempt, and it makes CSRF exploitation practically impossible.

**Why 60 seconds?** The token is generated when the user clicks
"Install App" and consumed when the user confirms the modal.
60 seconds is generous enough for a slow decision and short
enough that a leaked token is unlikely to still be valid.

**Client-side handling of a 401 (IDX-401-DISTINCT)**: the WebUI's
`xhrRequest()` suppresses the generic "Session Expired" modal for
install-family URLs. The 401 is still surfaced to the caller, and
the install flow renders a token-specific message
(`t('installTokenError')`). For every other endpoint, a 401
continues to trigger the session-expired path.

### 2.8 Watchdog Token (v1.2.0)

The watchdog (`watchdog.sh`) needs to call
`POST /api/ensure_running_service` to recover a crashed DNS
engine. In v1.1.0, this endpoint was protected only by an
implicit "localhost bypass" — exploitable via CSRF.

v1.2.0 replaces the bypass with a **token**:

- **Localhost-scoped**: `isLocalRequest(r)` is still required.
- **POST-only**: only `POST /api/ensure_running_service`.
- **Constant-time**: `subtle.ConstantTimeCompare`.
- **Not rate-limited**: token requests bypass the login limiter.
- **Persistent**: the token file survives restarts.
- **Fail-closed**: if the token file is missing and no token is
  sent, the request falls back to normal user auth.

**Migration guidance for API clients**:

- If your client previously relied on the v1.1.0 localhost
  bypass, it must now read `$RUN_DIR/.watchdog_token` and send
  the `X-Watchdog-Token` header.
- If your client uses a **Cookie/Bearer/Basic** session, **no
  change is required**.

---

## 3. Rate Limiting

### 3.1 Limits (v1.5.0)

| Endpoint | Limit | Window | Enforcement |
|---|---|---|---|
| POST `/api/auth/login` | 5 failed attempts | 15 min | `handleLogin` |
| Basic Auth (any endpoint) | 5 failed attempts | 15 min | `checkAuth` |
| POST `/api/install_companion_app` | 5 **failed** attempts | 15 min | `isInstallLockedOut` |
| Watchdog token (`ensure_running_service`, localhost) | unlimited | — | `verifyWatchdogToken` — deliberately not rate-limited |
| GET `/api?action=install_token` | unlimited | — | Not rate-limited; the endpoint is localhost-only and side-effect-free |
| GET `/api/*` (with Cookie/Bearer) | unlimited | — | — |
| POST `/api/*` (with Cookie/Bearer) | unlimited | — | — |

**v1.5.0 note**: the install rate limit is **per-IP** and shares
the same 5-attempts/15-minutes parameters as the login limit,
but uses a **separate** state map (`installAttempts` vs
`loginAttempts`). A failed login does not affect the install
counter and vice versa.

**Rate limit scope**: the counter counts **failed install
attempts** only. A successful install resets the counter for that
IP. This matches the same semantics as the login rate limiter.

### 3.2 Behavior

- 5 failed attempts → 15-minute lockout.
- Lockout per IP.
- Client IP extraction supports IPv4 and IPv6 via
  `net.SplitHostPort`.
- Failed Basic Auth attempts are recorded in `loginAttempts`.
- `X-Forwarded-For` is not used (localhost-only).

### 3.3 Basic Auth Rate Limiting

**Before**:

```go
// checkAuth
user, pass, ok := r.BasicAuth()
if ok {
    // Does not record failed attempts
    if userMatch && passMatch { return true }
}
// ← unlimited Basic Auth requests allowed
```

**After**:

```go
func checkAuth(r *http.Request) bool {
    // ...
    user, pass, ok := r.BasicAuth()
    if ok {
        ip := getClientIP(r)

        if isLockedOut(ip) {
            return false
        }

        userMatch := subtle.ConstantTimeCompare(...)
        passMatch := subtle.ConstantTimeCompare(...)
        if userMatch && passMatch {
            recordLoginAttempt(ip, true)
            return true
        }

        recordLoginAttempt(ip, false)
    }
    return false
}
```

Impact:

- No brute force over LAN.
- Same `loginAttempts` mechanism (5/15 min).
- Successful Basic Auth resets the counter.

### 3.4 Client IP Extraction

**Before**:

```go
ip := strings.Split(r.RemoteAddr, ":")[0]
// IPv4 "127.0.0.1:12345" → "127.0.0.1" ✅
// IPv6 "[::1]:12345"     → "["           ❌
```

**After**:

```go
func getClientIP(r *http.Request) string {
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return strings.Trim(r.RemoteAddr, "[]")
    }
    return host
}
// IPv4 "127.0.0.1:12345" → "127.0.0.1" ✅
// IPv6 "[::1]:12345"     → "::1"       ✅
```

### 3.5 Auth Cache (60 s)

`getMonitoringAuth()` caches credentials for **60 seconds**.

Reason:

- Before: every HTTP request read the entire `dnscrypt-proxy.toml`.
- After: cache hit → ~0.05 ms per request.

Constraints:

- Changing credentials in TOML takes effect within ≤ 60 seconds.
- For immediate effect: restart the WebUI.
- The cache no longer stores **empty results**. If the
  credentials file is unreadable, the next request re-reads it
  instead of caching "no auth required" for 60 s.

**Response (429):**

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "status": "error",
  "message": "Too many attempts. Try again later."
}
```

**v1.5.0 — install rate limit response:**

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "status": "error",
  "action": "install",
  "message": "Too many install attempts. Try again in 15 minutes.",
  "reason": "rate_limited"
}
```

---

## 4. Response Format

### 4.1 Success

The API uses **four** successful response shapes, depending on
the endpoint. There is no single canonical wrapper.

**Shape A — status-tagged** (most POST endpoints):

```json
{
  "status": "ok",
  ...endpoint-specific fields...
}
```

Example — `POST /api/save_allowlist`:

```json
{
  "status": "ok",
  "changed": true,
  "hash": "def456...",
  "allow_hash": "def456...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Shape B — status field carrying a value** (short status
endpoints):

```json
{ "status": "ON" }
{ "status": "OFF" }
```

Example — `GET /api?action=status` returns `{"status": "ON"}`
when the DNS engine is running.

**Shape C — flat object, no status field** (read-only GETs):

```json
{ ...endpoint-specific fields... }
```

Examples:

- `GET /api?action=install_token` → `{"token": "...", "ttl": 60}`
- `GET /api?action=get_custom_rules` → `{"allowlist": "...", "denylist": "..."}`
- `GET /api?action=runtime_info` → a flat object with `version`, `commit`, `backups`, etc.

**Shape D — install result** (v1.5.0, two-part):

```json
{
  "status": "ok" | "error",
  "action": "install" | "uninstall",
  ...endpoint-specific fields...
}
```

See §4.6 for the full install-result shape and the 200-vs-4xx
rationale.

**Which shape does which endpoint use?** See §6 for the exact
shape of each endpoint. As a rule of thumb:

- POST endpoints that change state → **Shape A**.
- Short read-only status endpoints → **Shape B**.
- Read-only data endpoints → **Shape C**.
- Companion install endpoints (v1.5.0) → **Shape D**.

### 4.2 Error

```json
{
  "status": "error",
  "message": "Error description",
  "reason": "machine_readable_reason (optional)",
  "details": "Additional details (optional)"
}
```

> **Exceptions — `/readyz` and `/api/metrics`**: the standard
> `{status, message}` shape is used by every endpoint except
> **two**:
>
>   • **`/readyz`** — on a non-localhost request returns
>     `{"error": "readyz is localhost-only"}` with HTTP 403.
>   • **`/api/metrics`** — `metricsProxyHandler` uses
>     `{"error": "..."}` for its own error responses
>     (401 / 500 / 502 / 503).
>
> The pre-v1.5.0 revision of this section said "/readyz is the
> **only** endpoint that does NOT use the `{status, message}`
> shape", then contradicted itself one sentence later by listing
> `/api/metrics`. Both are now stated as **explicit** exceptions
> in the same paragraph, and the "only" qualifier has been
> removed.

### 4.3 Conflict

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```
*HTTP status: 409 Conflict.*

> **v1.5.0+ note**: `POST /api/append_denylist` used to produce a
> spurious `409 conflict` when `denylist.txt` had been modified
> externally (e.g. by `customize.sh` during an upgrade) without a
> corresponding update to the in-memory `currentRules` snapshot.
> The fix aligns the hash source used by `appendDenylist` with the
> one used by `saveDenylist`, so the conflict only appears on a
> genuine concurrent-edit scenario.

### 4.4 Processing (async)

```json
{
  "status": "processing",
  "message": "Update in progress..."
}
```

### 4.5 Not Found

```json
{
  "status": "error",
  "message": "unknown action: \"foo\""
}
```
*HTTP status: 404 Not Found.*

**Example:**

```bash
curl -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=definitely_unknown"
# HTTP/1.1 404 Not Found
# {
#   "status": "error",
#   "message": "unknown action: \"definitely_unknown\""
# }
```

### 4.6 Install Result (v1.5.0)

The `install_companion_app` endpoint uses a **two-part response
shape**: `{status, action, ...}`. The `status` field follows the
standard convention (`ok` or `error`), and the `action` field
indicates what the endpoint attempted.

**Success** (HTTP 200):

```json
{
  "status": "ok",
  "action": "install",
  "strategy": 1,
  "package": "com.gasciljh.dnsproxy.debug",
  "version_name": "1.0.0",
  "expected_version": "1.0.0",
  "apk_size": 3284803,
  "sha_verified": true,
  "message_ar": "تم تثبيت التطبيق بنجاح",
  "message_en": "Companion app installed successfully"
}
```

**Install failure** (HTTP 200 — see rationale below):

```json
{
  "status": "error",
  "action": "install",
  "message_ar": "...",
  "message_en": "All install strategies failed — try the manual download",
  "hint_ar": "...",
  "hint_en": "..."
}
```

**Auth/token/rate-limit failure** (HTTP 4xx):

```json
{
  "status": "error",
  "action": "install",
  "message": "...",
  "reason": "invalid_token" | "rate_limited" | "not_localhost" | "script_not_found" | "invalid_mode" | "no_json_output"
}
```

**Important**: a failed install returns **HTTP 200**, not 4xx.
The body carries `status: "error"` and the localized message.
This is deliberate — a failed install is a valid outcome of a
well-formed request, and the WebUI needs to read the AR/EN
message from the body. Only auth/rate-limit/token failures use
4xx. See §6.2.14 for the full matrix.

**Client-side rendering (IDX-429, IDX-401-DISTINCT)**: the WebUI
distinguishes the following HTTP-level failures from the generic
"install failed" case:

  • **HTTP 429** → `t('installRateLimited')`.
  • **HTTP 401** (install-family only) → `t('installTokenError')`.
  • **HTTP 403** → `t('installError')` with a "localhost only"
    hint.
  • **Other 4xx / 5xx** → `t('installError')`.

---

## 5. Error Codes

| HTTP Code | Meaning | Example |
|---|---|---|
| 200 | ok / success | — |
| 200 | processing | `update_profile` |
| 200 | install error | `install_companion_app` (status=error in body) |
| 400 | error — bad input | missing param |
| 401 | error — unauthorized | session expired / invalid watchdog token / **invalid install token** |
| 403 | error — forbidden | path traversal / `/readyz` from LAN / **install from non-localhost** |
| 404 | error — path/action not found | `?action=foo` |
| 405 | error — method not allowed | GET on POST endpoint / Login GET |
| 409 | conflict — hash mismatch | concurrent edit |
| 413 | error — file too large | POST > 5 MB |
| 415 | error — unsupported media type | POST with non-form Content-Type |
| 429 | error — too many requests | rate limit (login + Basic Auth + install) |
| 500 | error — internal error | panic recovery |
| 502 | error — upstream error | monitoring_ui error |
| 503 | — not ready | `/readyz` fail |

### 5.1 404 vs 405 — Difference

| Case | HTTP Code | Response |
|---|---|---|
| **Unknown action** (`?action=foo`) | **404** | `{"status": "error", "message": "unknown action: \"foo\""}` |
| **Disallowed method** (GET on POST endpoint) | **405** | `{"status": "error", "message": "This endpoint requires POST (CSRF-GET protection)", "hint": "Use POST /api/<name>_service"}` + `Allow: POST` |
| **Login GET** | **405** | `{"status": "error", "message": "Login requires POST (CSRF protection)"}` + `Allow: POST` |
| **`/readyz` from LAN** | **403** | `{"error": "readyz is localhost-only"}` |
| **Install from non-localhost** | **403** | `{"status": "error", "action": "install", "reason": "not_localhost", "message": "Forbidden: install is localhost-only"}` |
| **Invalid install token** | **401** | `{"status": "error", "action": "install", "reason": "invalid_token", "message": "Invalid or expired install token"}` |
| **Install rate limit** | **429** | `{"status": "error", "action": "install", "reason": "rate_limited", "message": "Too many install attempts. Try again in 15 minutes."}` |
| **`install_token` from non-localhost** | **403** | `{"status": "error", "action": "install_token", "reason": "not_localhost", "message": "Forbidden: install is localhost-only"}` |

### 5.2 Not Found vs 405 Table

```text
┌────────────────────────────────────┬─────┬───────────────────┐
│  Scenario                               │ Code │  Fix              │
├────────────────────────────────────┼─────┼───────────────────┤
│  ?action=foo (unknown)                  │ 404  │ Fix #12           │
│  POST /api/save_allowlist_evil          │ 404  │ Fix #12           │
│  GET /api/auth/login                    │ 405  │ Fix NEW-1         │
│  GET /api?action=toggle                 │ 405  │ Fix NEW-1         │
│  /readyz from LAN                       │ 403  │ Fix NEW-4         │
│  ensure_running_service (no token,      │ 401  │ BUG-B (v1.2.0)    │
│  no user auth)                          │      │                   │
│  install_companion_app (no token)       │ 401  │ APK-5 (v1.5.0)    │
│  install_companion_app (non-localhost)  │ 403  │ APK-5 (v1.5.0)    │
│  install_companion_app (5× failed)      │ 429  │ APK-11 (v1.5.0)   │
│  install_token (non-localhost)          │ 403  │ v1.5.0+           │
└────────────────────────────────────┴─────┴───────────────────┘
```

### 5.3 Install-Specific Error Messages (v1.5.0)

`install_app.sh` produces a structured JSON error response with
localized AR + EN messages. The WebUI displays the message
matching the user's language, plus an optional hint.

**Error kinds**:

| `reason` | `message_en` (excerpt) | Typical cause |
|---|---|---|
| `apk_not_found` | "Companion APK not found in the module" | Dev build without the APK |
| `apk_empty` | "Companion APK is empty" | Failed download / partial copy |
| `apk_too_small` | "Companion APK is suspiciously small" | Truncated file |
| `apk_not_zip` | "Companion APK is not a valid ZIP archive" | Corrupted file |
| `sha_mismatch` | "Integrity check failed" | Tampered/corrupted APK |
| `insufficient_storage` | "Insufficient storage" | Device storage full |
| `all_strategies_failed` | "All install strategies failed" | All 5 cascade levels failed |

Each error may also carry `hint_ar` / `hint_en` with actionable
advice. The WebUI renders both, and offers a **"⬇️ Download
manually"** fallback button that navigates to `/app-debug.apk`.

---

## 6. Endpoints

### 6.1 GET Endpoints

#### 6.1.1 `GET /api?action=status`

**Response:**

```json
{
  "status": "ON"
}
```
Values: `ON` — DNS engine running, `OFF` — stopped.

This endpoint is read-only. It does not write STATUS_FILE.

#### 6.1.2 `GET /api?action=get_profile`

**Response:**

```json
{
  "key": "pro",
  "name": "HaGeZi PRO",
  "entries": 250000,
  "is_empty": false,
  "last_update": "2026-09-26 10:30:00",
  "memory_limit_mb": 120
}
```

#### 6.1.3 `GET /api?action=get_custom_rules`

**Response:**

```json
{
  "allowlist": "googleadservices.com\ns.youtube.com\n",
  "denylist": "facebook.com\ntiktok.com\n"
}
```

#### 6.1.4 `GET /api?action=get_rules_state`

**Response:**

```json
{
  "allowlist_hash": "abc123...",
  "denylist_hash": "def456..."
}
```

> **v1.5.0+ note**: the hashes returned here are the
> authoritative source that `saveDenylist()` and
> `appendDenylist()` consult for their conflict checks. A client
> that mirrors these hashes and passes them back as
> `expected_hash` will not see spurious `409 conflict` responses
> when `denylist.txt` was modified externally.

#### 6.1.5 `GET /api?action=stats`

**Response:**

```json
{
  "blocked_today": "1523"
}
```

#### 6.1.6 `GET /api?action=resources`

**Response:**

```json
{
  "ram": "18 MB"
}
```

#### 6.1.7 `runtime_info` — ports + profile + memory + backups

**Equivalent entry points**:

| Form | Handler | Notes |
|---|---|---|
| `GET /api/runtime_info` | `handleRuntimeInfo` | Path-based (canonical) |
| `GET /api/runtime_info/` | `handleRuntimeInfo` | Path-based with trailing slash |
| `GET /api?action=runtime_info` | `handleAPI` | Query-string form |

All three return the **same JSON body** — they invoke
`buildRuntimeInfo()`. Choose whichever form fits the client
convention; none is deprecated.

**Response (v1.5.0):**

```json
{
  "version": "v1.5.0",
  "commit": "a1b2c3d",
  "build_time": "1726987200",
  "build_time_human": "2026-10-10T10:00:00Z",
  "project_url": "https://github.com/gasciljh/dnscrypt-proxy-webui",
  "app_version": "1.0.0",
  "run_dir": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run",
  "status_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status",
  "pid_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.pid",
  "progress_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/update_progress.txt",
  "log_file": "/data/local/tmp/dnscrypt_main.log",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "backups": {
    "available": 7,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-10-10 15:00:00",
    "last_backup_name": "20261010-150000-manual",
    "last_stable": "20261010-095826-v1.5.0",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

**Field groups:**

| Group | Fields | Version |
|---|---|---|
| **Build info** | `version`, `commit`, `build_time`, `build_time_human`, `project_url` | v1.0.0 |
| **Runtime paths** | `run_dir`, `status_file`, `pid_file`, `progress_file`, `log_file` | v1.0.0 |
| **Network** | `bind_addr` | v1.0.0 |
| **Dynamic ports** | `webui_port`, `dashboard_port` | v1.0.0 |
| **Memory profile** | `profile_key`, `memory_limit_mb` | v1.1.0 |
| **Companion app version** | `app_version` | v1.4.0 |
| **Backups** | 7 fields (see below) | v1.2.0 |

**`backups` object — full schema:**

| Field | Type | Description |
|---|---|---|
| `available` | int | Number of snapshots. **Detection rule (v1.3.0 — SNAP-MANIFEST):** a directory counts as a snapshot **iff** it contains a `.manifest.json` file. Excludes `current/`, `txn-*`, `orphan-txn-*`, and `apk/` by name. |
| `in_flight_txn` | int | Number of `txn-*` directories |
| `orphan_txn` | int | Number of `orphan-txn-*` directories |
| `last_backup` | string \| null | Modification time of the newest snapshot, formatted as `YYYY-MM-DD HH:MM:SS` |
| `last_backup_name` | string \| null | Directory name of the newest snapshot. **Sort key (v1.3.0 — SNAP-MTIME):** mtime, descending (with a name-based fallback when `DirEntry.Info()` fails). |
| `last_stable` | string \| null | Content of the `.last_stable` pointer file, or null if not set |
| `path` | string | Absolute path of the persistent backup directory |

> **v1.5.0+ note**: the `webui_port` and `dashboard_port` values
> are now served from a 30-second TTL cache. The response shape
> and field names are unchanged; the cache is transparent to the
> client. A manual edit of `webui.conf` followed by an immediate
> reload may show the old value for up to 30 seconds. A `main.go`
> restart always re-reads the file.

#### 6.1.8 `GET /api?action=logs`

Last 300 lines from the log.

**Response:**

```json
{
  "logs": "[2026-10-10T10:30:00Z] 🚀 Starting DNSCrypt WebUI...\n[...]"
}
```

#### 6.1.9 `GET /api?action=list_logs`

**Response:**

```json
{
  "status": "ok",
  "files": [
    {
      "name": "dnscrypt_main.log",
      "size": 45312,
      "mtime": 1726987200,
      "type": "active",
      "extension": ".log"
    },
    {
      "name": "dnscrypt_main.log.1726900000.old.gz",
      "size": 12456,
      "mtime": 1726900000,
      "type": "archive",
      "extension": ".gz"
    },
    {
      "name": "dnscrypt_credentials.txt",
      "size": 250,
      "mtime": 1726980000,
      "type": "sensitive",
      "extension": ".txt"
    }
  ],
  "count": 3
}
```

#### 6.1.10 `GET /api?action=read_log&file=<name>&confirm=1`

**Query params:**

- `file` (required) — file name.
- `confirm` — `1` for sensitive files.

**Response (200):**

```json
{
  "status": "ok",
  "name": "dnscrypt_main.log",
  "size": 45312,
  "content": "...",
  "truncated": false,
  "type": "active"
}
```

**Response (requires_confirm):**

```json
{
  "status": "requires_confirm",
  "message": "Sensitive file requires confirmation",
  "name": "dnscrypt_credentials.txt"
}
```

#### 6.1.11 `GET /api?action=get_progress`

**Response:**

```json
{
  "progress": "50|Downloading..."
}
```
*Format: percent|message.*

#### 6.1.12 `GET /api?action=check_old_modules`

**Response:**

```json
{
  "modules": [
    {
      "path": "/data/adb/modules/dnscrypt-old",
      "version": "v3.2.0",
      "disabled": true,
      "name": "dnscrypt-old",
      "id": "dnscrypt-proxy-webui"
    }
  ],
  "count": 1
}
```

#### 6.1.13 `GET /api/download_log?file=<name>&confirm=1`

**Response:** binary stream (`application/octet-stream`).

**Headers:**

```http
Content-Type: application/octet-stream
Content-Disposition: attachment; filename="dnscrypt_main.log"
Content-Length: 45312
Cache-Control: no-cache, no-store, must-revalidate
```

**Error responses** (plain text bodies, not JSON):

| Condition | HTTP status | Body |
|---|---|---|
| Not authenticated | 401 | `Unauthorized` |
| Path outside whitelist | 403 | `Forbidden` |
| Sensitive file without `confirm=1` | 403 | `Confirmation required` |
| File not found | 404 | (empty, from `http.NotFound`) |
| File size > 100 MB | 413 | `File too large` |

#### 6.1.14 `GET /api/metrics` — JSON (Dashboard)

Dashboard-only endpoint (port 9091).

**v1.1.0 change**: The upstream URL used by
`metricsProxyHandler` is built from the `MONITORING_UI_PORT`
Go constant instead of the hardcoded string `"8080"`.

**Request:**

```http
GET /api/metrics HTTP/1.1
Host: 127.0.0.1:9091
Cookie: dnscrypt_session=<token>
```

**Response (200 OK):**

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Cache-Control: no-cache, no-store, must-revalidate

{
  "generated_at": "2026-10-10T10:30:00Z",
  "total_queries": 15234,
  "blocked_queries": 1523,
  "queries_per_second": 0,
  "uptime_seconds": 0,
  "avg_response_time": 0,
  "cache_stats": {
    "enabled": true,
    "cache_hit_ratio": 0.8234,
    "cache_hits": 12500,
    "cache_misses": 2734,
    "configured_size": 0,
    "entries": 0,
    "capacity": 0,
    "min_ttl": 0,
    "max_ttl": 0
  },
  "query_types": [],
  "resolver_health": [],
  "top_domains": [],
  "sources": [],
  "recent_queries": []
}
```

**Response (401 / 500 / 502 / 503):**

```json
{
  "error": "Unauthorized Access"
}
```

> **Exception**: `metricsProxyHandler` — like `handleReadyz` —
> uses the `{"error": ...}` shape rather than `{status, message}`.
> See §4.2 for the two-exception note.

#### 6.1.15 `GET /app-debug.apk` — Companion Android App

Serves the optional companion Android app APK.

**Public route** — no authentication required.

**Request:**

```http
GET /app-debug.apk HTTP/1.1
Host: 127.0.0.1:9090
```

**Response (200 OK — APK present):**

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.android.package-archive
Cache-Control: public, max-age=3600, immutable
Content-Length: 3145728
```

**Response (404 Not Found — APK absent):**

```http
HTTP/1.1 404 Not Found
Content-Type: text/plain; charset=utf-8
X-Content-Type-Options: nosniff
Content-Length: 19

404 page not found
```

> **v1.5.0 note**: The WebUI install button no longer links to
> this route directly. It opens the **install-method modal**
> (IDX-24) whose primary action performs a root install via
> `POST /api/install_companion_app`. The `/app-debug.apk` route
> remains reachable as a **fallback** when the local install
> fails.

#### 6.1.16 `GET /api?action=install_token` (v1.5.0)

Generates a **one-shot CSRF token** for the companion app
install flow. The token is consumed by the next
`POST /api/install_companion_app` from the same IP.

**Auth**: session cookie (or Bearer/Basic). **Localhost-only**
(the `isLocalRequest` gate is applied to this GET endpoint — see
§1.1).

**Request:**

```http
GET /api?action=install_token HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
```

**Response (200 OK):**

```json
{
  "token": "abc123def456789...",
  "ttl": 60
}
```

**Response (401 Unauthorized — no session):**

```json
{
  "status": "error",
  "message": "Unauthorized"
}
```

**Response (403 Forbidden — non-localhost):**

```json
{
  "status": "error",
  "action": "install_token",
  "reason": "not_localhost",
  "message": "Forbidden: install is localhost-only"
}
```

**Field details**:

| Field | Type | Description |
|---|---|---|
| `token` | string | 64 hex chars (32 random bytes from `crypto/rand`). Single-use. |
| `ttl` | int | Token lifetime in seconds. Currently always `60`. |

**Characteristics**:

- **One-shot**: the token is removed from the server-side map
  on the first successful use.
- **Ephemeral**: the map is in memory only. A server restart
  invalidates all outstanding tokens.
- **Lazy GC**: expired tokens are removed from the map when
  the next `generateInstallToken()` call runs.
- **Not rate-limited**: generating a token is cheap and
  side-effect-free. The rate limit applies to the **install
  attempt** (§6.2.14).

**Verify:**

```bash
# Generate a token
curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=install_token" | jq

# Expected:
# {
#   "token": "abc123...",
#   "ttl": 60
# }
```

#### 6.1.17 `GET /api?action=companion_app_state` (v1.5.0)

Returns the current install state of the companion app.

**Auth**: session cookie (or Bearer/Basic).

**Cache**: the server caches the result for **30 seconds**
(`COMPANION_STATE_CACHE_TTL`). The cache is **invalidated** after
every install/uninstall attempt — success OR failure. A failed
install attempt can still have partially succeeded, so the cache
must not keep reporting `{installed: false}` when the package
manager may have registered the app a few seconds later.

**Request:**

```http
GET /api?action=companion_app_state HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
```

**Response (200 OK — installed):**

```json
{
  "status": "ok",
  "action": "status",
  "installed": true,
  "package": "com.gasciljh.dnsproxy.debug",
  "version_name": "1.0.0",
  "expected_version": "1.0.0"
}
```

**Response (200 OK — not installed):**

```json
{
  "status": "ok",
  "action": "status",
  "installed": false,
  "package": "com.gasciljh.dnsproxy.debug",
  "expected_version": "1.0.0"
}
```

> **Note**: when the package is not installed, `install_app.sh`
> returns the **default candidate** name
> (`com.gasciljh.dnsproxy.debug`) in the `package` field, and
> **omits** the `version_name` field entirely. This matches the
> behaviour of `_emit_json` inside `install_app.sh`.

**Response (200 OK — installed but different version):**

```json
{
  "status": "ok",
  "action": "status",
  "installed": true,
  "package": "com.gasciljh.dnsproxy.debug",
  "version_name": "0.9.5",
  "expected_version": "1.0.0"
}
```

**Response (401 Unauthorized):**

```json
{
  "status": "error",
  "message": "Unauthorized"
}
```

**Field details**:

| Field | Type | Description |
|---|---|---|
| `status` | string | Always `"ok"` on a successful probe. |
| `action` | string | Always `"status"`. |
| `installed` | bool | `true` if the package is installed. |
| `package` | string | The detected package name. When not installed, defaults to the first candidate. |
| `version_name` | string | Installed version. **Absent** when not installed. |
| `expected_version` | string | Version expected by this module (`proxy/app-apk.version`). |

**Package name candidates**: the server tries three candidates
in order: `com.gasciljh.dnsproxy.debug`,
`com.gasciljh.dnsproxy`, and `com.gasciljh.dnscrypt_proxy`
(legacy).

**WebUI usage**: the button label is set based on three cases:

| `installed` | `version_name == expected_version` | Button |
|---|:---:|---|
| `false` | — | 📲 "Install App" |
| `true` | `true` | ✅ "Installed" (disabled) |
| `true` | `false` | 🔄 "Update App" |

**Verify:**

```bash
curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=companion_app_state" | jq
```

---

### 6.2 POST Endpoints

**Content-Type requirement**: every POST endpoint that reads a
request body calls `requireFormContentType()`. Accepted values:

- `application/x-www-form-urlencoded`
- `multipart/form-data`
- **Empty** (accepted for compatibility with `wget --post-data=''`)

Any other Content-Type (e.g. `application/json`) returns **HTTP
415 Unsupported Media Type** with:

```json
{
  "status": "error",
  "message": "Content-Type must be application/x-www-form-urlencoded or multipart/form-data"
}
```

**Exception**: `POST /api/auth/login` accepts both
`application/json` and `application/x-www-form-urlencoded` (§2.3).

**Body size limit**: `MaxBytesReader` caps every POST body at
**5 MB** (`MAX_POST_BODY_SIZE`). Exceeding the limit returns HTTP
413 with a JSON body.

#### 6.2.1 `POST /api/auth/login`

See §2.3.

#### 6.2.2 `POST /api/auth/logout`

See §2.5.

#### 6.2.3 `POST /api/update_profile`

Update the blocklist from a profile.

**Pre-critical backup**: Before writing, the handler calls
`createAutoBackup("pre-profile-change")`, which snapshots the 5
user config files to the persistent backup directory.

**Request:**

```http
POST /api/update_profile HTTP/1.1
Content-Type: application/x-www-form-urlencoded

profile=pro
```
*Values: light, normal, pro, proplus, ultimate.*

**Response (200 — async):**

```json
{
  "status": "processing",
  "message": "Update in progress..."
}
```
*Timeout: 310 s for the HTTP request.*

#### 6.2.4 `POST /api/save_allowlist`

**Pre-critical backup**: Calls
`createAutoBackup("pre-allowlist-save")` before writing.

**Request:**

```http
POST /api/save_allowlist HTTP/1.1
Content-Type: application/x-www-form-urlencoded

allowlist=googleadservices.com%0As.youtube.com&expected_hash=abc123...
```

**Response (200 — changed):**

```json
{
  "status": "ok",
  "changed": true,
  "hash": "def456...",
  "allow_hash": "def456...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Response (200 — no change):**

```json
{
  "status": "ok",
  "changed": false,
  "hash": "def456...",
  "allow_hash": "def456...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Response (409 conflict):**

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```

#### 6.2.5 `POST /api/save_denylist`

Same as `save_allowlist` but uses the `denylist` param.

**Pre-critical backup**: Calls
`createAutoBackup("pre-denylist-save")` before writing.

#### 6.2.6 `POST /api/save_custom_rules`

Save both atomically.

**Pre-critical backup**: Calls
`createAutoBackup("pre-custom-rules-save")` before writing.

**Request:**

```http
POST /api/save_custom_rules HTTP/1.1
Content-Type: application/x-www-form-urlencoded

allowlist=googleadservices.com&denylist=facebook.com
```

**Response:**

```json
{
  "status": "ok",
  "changed": true,
  "hash": "def456...",
  "allow_hash": "def456...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

#### 6.2.7 `POST /api/append_denylist`

**Pre-critical backup**: The pre-critical backup is performed
**once** by the delegated `saveDenylist` path.

**Request:**

```http
POST /api/append_denylist HTTP/1.1
Content-Type: application/x-www-form-urlencoded

content=tracker.example.com%0Aads.example.com
```

**Response — rules applied (changed):**

```json
{
  "status": "ok",
  "changed": true,
  "message": "Appended and processed 250000 rules",
  "hash": "xyz789...",
  "allow_hash": "abc123...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Response — no change:**

```json
{
  "status": "ok",
  "changed": false,
  "message": "No changes detected",
  "hash": "xyz789...",
  "allow_hash": "abc123...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

> **v1.5.0+ note**: the internal hash check now uses
> `getRulesState().DenylistHash` — the same source that
> `saveDenylist()` consults — instead of a freshly-read
> `fileHash(DENYLIST_FILE)`. On the API surface this only changes
> the edge case of an externally modified `denylist.txt`
> (spurious `409` no longer occurs). Normal calls are unaffected.

#### 6.2.8 `POST /api/clear_log_file`

**Request:**

```http
POST /api/clear_log_file HTTP/1.1
Content-Type: application/x-www-form-urlencoded

file=dnscrypt_main.log.1726700000.old.gz
```

**Response:**

```json
{
  "status": "ok",
  "message": "File cleared successfully"
}
```

#### 6.2.9 `POST /api/clear_logs`

Clear the main log.

**Response:**

```json
{
  "status": "ok",
  "message": "Logs cleared successfully"
}
```

#### 6.2.10 `POST /api/remove_module`

> **v1.4.0 CodeQL hardening**: The handler now sanitizes the
> caller-provided path via `filepath.Base()` and rebuilds the
> final path from the trusted `MODULES_DIR` constant, using
> `securejoin.SecureJoin`. This closes two CodeQL
> `go/path-injection` alerts (#1 and #2).

**Request:**

```http
POST /api/remove_module HTTP/1.1
Content-Type: application/x-www-form-urlencoded

path=/data/adb/modules/dnscrypt-old
```

**Response (200 OK):**

```json
{
  "status": "ok",
  "message": "Old module removed successfully"
}
```

**Response (400 — invalid path):**

```json
{
  "status": "error",
  "message": "Invalid module name"
}
```

#### 6.2.11 `POST /api/toggle_service`

POST only (previously GET — changed for CSRF protection).

**Request:**

```http
POST /api/toggle_service HTTP/1.1
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200):**

```json
{
  "status": "ON"
}
```

**Response (busy):**

```json
{
  "status": "error",
  "message": "Service is busy"
}
```

**Response to GET (error):**

```http
HTTP/1.1 405 Method Not Allowed
Allow: POST
Content-Type: application/json

{
  "status": "error",
  "message": "This endpoint requires POST (CSRF-GET protection)",
  "hint": "Use POST /api/toggle_service"
}
```

#### 6.2.12 `POST /api/restart_service`

**Request:**

```http
POST /api/restart_service HTTP/1.1
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200):**

```json
{
  "status": "ON"
}
```

#### 6.2.13 `POST /api/ensure_running_service`

Called by the Watchdog **and** (since v1.3.0) by `service.sh` at
boot to ensure the DNS engine starts even when the WebUI has not
yet loaded.

**Authentication (v1.2.0)**: this endpoint has **TWO** distinct
auth paths, in this order:

1. **Watchdog token** (preferred for the Watchdog):
   - `POST` method, **and**
   - request from a **loopback** address, **and**
   - `X-Watchdog-Token` header that matches the token at
     `$RUN_DIR/.watchdog_token` (constant-time comparison).

2. **Normal user auth** (same as every other POST endpoint).

**Request (with watchdog token):**

```http
POST /api/ensure_running_service HTTP/1.1
Host: 127.0.0.1:9090
X-Watchdog-Token: 3f8e...  (64 hex chars)
Content-Length: 0
```

**Response (skipped — user intent OFF):**

```json
{
  "status": "OFF",
  "action": "skipped",
  "message": "User stopped the service"
}
```

**Response (started):**

```json
{
  "status": "ON",
  "action": "started"
}
```

**Response (already running):**

```json
{
  "status": "ON",
  "action": "none",
  "message": "Already running"
}
```

**Response (401 — no token, no user auth):**

```json
{
  "status": "error",
  "message": "Unauthorized"
}
```

**v1.3.0 note**: `service.sh` at boot performs the same POST call
after waiting (bounded) for the WebUI to bind its port.

#### 6.2.14 `POST /api/install_companion_app` (v1.5.0)

Performs a **root-level install** of the companion Android app.
The server runs `proxy/install_app.sh`, which tries a 5-level
`pm install` cascade.

**Auth**: session cookie (or Bearer/Basic) **AND** a valid
one-shot CSRF token from §6.1.16. **Localhost only.**

**Rate limit**: 5 **failed** attempts / 15 min per IP. A
successful install resets the counter.

**Retry policy**: the WebUI disables retries for this endpoint
(`retries = 0` in `xhrPost`). Rationale: the first request
consumes the CSRF token, so a retry would produce "Invalid or
expired install token" even when the first install is still in
progress.

**Timeouts**:
- Client-side (WebUI `getTimeoutForUrl`): **120 s**.
- Server-side (`main.go` §[3b] `INSTALL_TIMEOUT`): **90 s**.
- Cascade-side (`install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS`):
  **75 s**.
- HTTP WriteTimeout (server, applies to every response):
  **150 s**.

The 75 s deadline is deliberately shorter than the 90 s
`INSTALL_TIMEOUT`, so the `EXIT / INT / TERM` trap in
`install_app.sh` always fires before `main.go`'s context deadline
kills the script. See `docs/SECURITY.md` §5.36.4 for the trap
semantics.

**Request:**

```http
POST /api/install_companion_app HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
Content-Type: application/x-www-form-urlencoded
Content-Length: 71

token=abc123def456789abc123def456789abc123def456789abc123def4567890
```

**Body params**:

| Param | Required | Description |
|---|---|---|
| `token` | ✅ | The one-shot CSRF token from §6.1.16. 64 hex chars. |

**Response (200 OK — install succeeded):**

```json
{
  "status": "ok",
  "action": "install",
  "strategy": 1,
  "package": "com.gasciljh.dnsproxy.debug",
  "version_name": "1.0.0",
  "expected_version": "1.0.0",
  "apk_size": 3284803,
  "sha_verified": true,
  "message_ar": "تم تثبيت التطبيق بنجاح",
  "message_en": "Companion app installed successfully"
}
```

**Response (200 OK — install failed):**

```json
{
  "status": "error",
  "action": "install",
  "message_ar": "فشلت جميع استراتيجيات التثبيت — جرّب التنزيل اليدوي",
  "message_en": "All install strategies failed — try the manual download",
  "hint_ar": "تأكد من أن الجهاز غير محمي بواسطة Play Protect.",
  "hint_en": "Check that the device is not protected by Play Protect."
}
```

> **Note**: a failed install returns **HTTP 200**. The `status`
> field carries the failure. Only auth/rate-limit/token failures
> use 4xx.

**Response (401 — invalid or expired token):**

```json
{
  "status": "error",
  "action": "install",
  "reason": "invalid_token",
  "message": "Invalid or expired install token"
}
```

**Response (401 — no session):**

```json
{
  "status": "error",
  "message": "Unauthorized"
}
```

**Response (403 — non-localhost):**

```json
{
  "status": "error",
  "action": "install",
  "reason": "not_localhost",
  "message": "Forbidden: install is localhost-only"
}
```

**Response (429 — rate limited):**

```json
{
  "status": "error",
  "action": "install",
  "reason": "rate_limited",
  "message": "Too many install attempts. Try again in 15 minutes."
}
```

**Response field details**:

| Field | Type | Description |
|---|---|---|
| `status` | string | `"ok"` or `"error"` |
| `action` | string | Always `"install"` |
| `reason` | string | Present on 4xx responses only. One of: `invalid_token`, `rate_limited`, `not_localhost`, `script_not_found`, `invalid_mode`, `no_json_output`. |
| `strategy` | int (1-5) | Which cascade level succeeded. Present only on `status: "ok"`. |
| `package` | string | Detected package name. Present only on success. |
| `version_name` | string | Installed version. Present only on success. |
| `expected_version` | string | Version expected by this module (`proxy/app-apk.version`). |
| `apk_size` | int | APK size in bytes. |
| `sha_verified` | bool | `true` if `web/app-debug.apk.sha256` was present and matched. |
| `message_ar` | string | Arabic error/success message. |
| `message_en` | string | English error/success message. |
| `hint_ar` | string | Optional Arabic hint. Present only on some errors. |
| `hint_en` | string | Optional English hint. Present only on some errors. |

**The 5-level cascade** (first success wins):

| Level | Command | Notes |
|:-:|---|---|
| **1** | `pm install -r --user 0 <apk>` | Direct install as the current user. |
| **2** | `pm install -r --user 0 -i com.android.shell <apk>` | Install attributed to the shell app. |
| **3** | Session-based (`install-create` + `install-write` + `install-commit`) | The same API Google Play uses. |
| **4** | `magisk su -c "pm install -r <apk>"` | Explicit Magisk root. |
| **5** | `cmd package install -r <apk>` | Modern PackageManager shell entrypoint (Android 8.0+). |

After each level, the script polls `pm list packages` for up to
15 seconds to confirm the install succeeded (the exit code of
`pm install` alone is not reliable across ROMs).

**SELinux staging**: the APK is first copied to
`/data/local/tmp/dnscrypt-companion.apk` (context
`shell_data_file`, readable by `system_server`). **SELinux is
never disabled** — the script does not call `setenforce 0`. The
staged copy is removed on exit by the trap.

**Trap semantics**: the signal handling in `install_app.sh` uses
**three separate handlers** (`EXIT` / `INT` / `TERM`) with a
`_CLEANED_UP` re-entry guard inside a named `_cleanup_app()`
function. The `INT` handler calls `exit 130`; the `TERM` handler
calls `exit 143`. The staged APK is removed on every catchable
exit path. This does not affect the HTTP contract — `main.go`
sends SIGKILL after `INSTALL_TIMEOUT`, which is uncatchable, so
the primary invocation path is unchanged.

**Play Protect**: the package verifier is temporarily disabled
during the cascade, and restored on exit via the three-way trap.
The cascade is bounded by the 75 s deadline so the trap always
fires inside `main.go`'s 90 s `INSTALL_TIMEOUT`. The trap restores
the exact captured value (`$_VERIFIER_ORIG`), not a hardcoded `1`.

**SHA256 verification**: if `web/app-debug.apk.sha256` is present,
the APK's SHA256 is verified before any install strategy is
attempted. If the `.sha256` file is absent, the script degrades
to advisory mode.

**Client-side handling — IDX-429 + IDX-401-DISTINCT**: the WebUI
distinguishes:

  • **429** → `t('installRateLimited')`.
  • **401** → `t('installTokenError')` (session-expired modal
    suppressed for install-family URLs).
  • **403** → `t('installError')` with a "localhost only" hint.
  • **other 4xx / 5xx** → `t('installError')`.

**Verify:**

```bash
# 1. Get a token
TOKEN=$(curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')

# 2. Install
curl -s -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/install_companion_app \
  -d "token=$TOKEN" | jq

# Expected (success):
# {
#   "status": "ok",
#   "action": "install",
#   "strategy": 1,
#   "package": "com.gasciljh.dnsproxy.debug",
#   "version_name": "1.0.0",
#   "message_ar": "...",
#   "message_en": "..."
# }
```

#### 6.2.15 `POST /api/uninstall_companion_app` (v1.5.0)

Removes the companion app package.

**Status**: reserved for future UI. The v1.5.0 install-method
modal (IDX-24) does **not** expose an uninstall button.

**Auth**: session cookie (or Bearer/Basic). **Localhost only.**

**Request:**

```http
POST /api/uninstall_companion_app HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200 OK — uninstall succeeded):**

```json
{
  "status": "ok",
  "action": "uninstall",
  "package": "com.gasciljh.dnsproxy.debug",
  "message_ar": "تمت إزالة التطبيق بنجاح",
  "message_en": "Companion app uninstalled successfully"
}
```

**Response (200 OK — uninstall failed):**

```json
{
  "status": "error",
  "action": "uninstall",
  "message_ar": "فشلت إزالة التطبيق",
  "message_en": "Uninstall failed"
}
```

**Response (403 — non-localhost):**

```json
{
  "status": "error",
  "action": "uninstall",
  "reason": "not_localhost",
  "message": "Forbidden: install is localhost-only"
}
```

**Implementation**: runs `pm uninstall <pkg>` for the first
candidate that is currently installed. On success, the
`companionStateCache` is invalidated.

**Verify:**

```bash
curl -s -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/uninstall_companion_app | jq
```

---

## 7. Path Matching

### 7.1 `hasEndpoint()` Function

**Before**:

```go
if strings.Contains(r.URL.Path, "update_profile") {
    // ← also matches: /api/update_profile_evil
    // ← dangerous: loose match
}
```

**After**:

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

### 7.2 Comparison

| Path | `strings.Contains` (old) | `hasEndpoint` (new) |
|--------|:---:|:---:|
| `/api/update_profile` | ✅ | ✅ |
| `/api/update_profile/` | ✅ | ✅ |
| `/api/update_profile_evil` | ✅ (**bug**) | ❌ |
| `/prefix/api/update_profile` | ✅ (**bug**) | ❌ |
| `/api/update_profile/child` | ✅ (**bug**) | ❌ |
| `/api/save_allowlist_extra` | ❌ | ❌ |

### 7.3 Endpoints Using `hasEndpoint`

All POST endpoints use `hasEndpoint`, including the v1.5.0
install endpoints:

- `auth/login`, `auth/logout`
- `update_profile`
- `save_allowlist`
- `save_denylist`
- `save_custom_rules`
- `append_denylist`
- `remove_module`
- `clear_log_file`
- `clear_logs`
- `toggle_service`
- `restart_service`
- `ensure_running_service`
- `install_companion_app`
- `uninstall_companion_app`

### 7.4 Supported Path Variants

For each endpoint, these two paths are equivalent:

```text
✅ /api/save_allowlist        ← canonical
✅ /api/save_allowlist/       ← trailing slash
✅ /api/install_companion_app
✅ /api/install_companion_app/
```

### 7.5 Rejected Path Variants

```text
❌ /api/save_allowlist_extra  ← suffix
❌ /prefix/api/save_allowlist ← prefix
❌ /api/save_allowlist/child  ← subpath
❌ /api/SAVE_ALLOWLIST        ← case-sensitive
```

### 7.6 Test Coverage

```bash
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ present"

curl -i "http://127.0.0.1:9090/api?action=nonexistent"
# → 404 Not Found

curl -i -X POST "http://127.0.0.1:9090/api/save_allowlist_evil" \
  -b /tmp/cookies.txt
# → 404 Not Found (not treated as save_allowlist)

curl -i -X POST "http://127.0.0.1:9090/api/install_companion_app/" \
  -b /tmp/cookies.txt
# → 401 (trailing slash accepted, but no token)
```

---

## 8. SSE Events

### 8.1 Connection

**Endpoint**: `GET /events`

**Headers:**

```http
Accept: text/event-stream
```

**Response headers:**

```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
X-Accel-Buffering: no
```

### 8.2 Event Types

| Event | Data | Frequency |
|---|---|---|
| status | `ON` / `OFF` | on change |
| stats | `{"blocked_today":"1523"}` | every 5 min |
| resources | `{"ram":"18 MB"}` | every 10 s |
| progress | `50\|Downloading...` | during update |

### 8.3 Example Stream

```text
event: status
data: ON

event: stats
data: {"blocked_today":"1523"}

event: resources
data: {"ram":"18 MB"}

: keepalive

event: progress
data: 10|Downloading... (1.2 MB)

event: progress
data: 50|Downloading... (12.5 MB)

event: progress
data: 100|✅ Protection applied successfully (250000 entries)

: keepalive
```

### 8.4 JavaScript Client

```javascript
const sse = new EventSource('/events');

sse.addEventListener('status', (e) => {
  console.log('Status:', e.data);
});

sse.addEventListener('progress', (e) => {
  const [percent, msg] = e.data.split('|');
  console.log(`${percent}% - ${msg}`);
});

sse.onerror = () => {
  // reconnect with backoff
};
```

### 8.5 SSE Write Deadline

```go
rc := http.NewResponseController(w)
_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))  // 30 s
fmt.Fprint(w, msg)
if err := flusher.Flush(); err != nil {
    return  // ← releases the goroutine
}
```

---

## 9. Health Checks

### 9.1 `GET /healthz`

Liveness check. Always returns `ok` if the server is running.

**Response (200):**

```http
Content-Type: text/plain; charset=utf-8
Cache-Control: no-store

ok
```

**Public** — does not require auth.

### 9.2 `GET /readyz` — localhost-only

Readiness check. Verifies dependencies.

Requests from outside localhost → **403 Forbidden**.

**Response (200) — from localhost:**

```json
{
  "config": "ok",
  "blocklist": "ok",
  "run_dir": "ok",
  "dns_engine": "ok",
  "version": "v1.5.0",
  "status": "ready"
}
```

**Response (503) — from localhost with an issue:**

```json
{
  "config": "missing",
  "blocklist": "ok",
  "run_dir": "ok",
  "dns_engine": "not_running",
  "version": "v1.5.0",
  "status": "unhealthy"
}
```

**Response (403) — from LAN:**

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "readyz is localhost-only"
}
```

### 9.3 Docker / Kubernetes

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:9090/healthz"]
  interval: 30s
  timeout: 5s
  retries: 3

readinessProbe:
  httpGet:
    path: /readyz
    port: 9090
  initialDelaySeconds: 5
  periodSeconds: 10
```

---

## 10. Examples

### 10.1 cURL

**Login:**

```bash
curl -X POST http://127.0.0.1:9090/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin_abc12345","password":"SecurePass123"}' \
  -c /tmp/cookies.txt
```

**Status:**

```bash
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api?action=status
```

**Toggle (POST):**

```bash
curl -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/toggle_service
```

**Restart:**

```bash
curl -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/restart_service
```

**Save allowlist:**

```bash
curl -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/save_allowlist \
  -d "allowlist=googleadservices.com" \
  -d "expected_hash=abc123..."
```

**Ensure running (with watchdog token):**

```bash
TOKEN=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token")
curl -X POST http://127.0.0.1:9090/api/ensure_running_service \
  -H "X-Watchdog-Token: $TOKEN"
```

**SSE:**

```bash
curl -b /tmp/cookies.txt -N http://127.0.0.1:9090/events
```

**Metrics:**

```bash
curl -b /tmp/cookies.txt http://127.0.0.1:9091/api/metrics | jq
```

**Companion APK route:**

```bash
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
# Expected when present:
#   HTTP/1.1 200 OK
#   Content-Type: application/vnd.android.package-archive
#   Cache-Control: public, max-age=3600, immutable
```

**v1.5.0 — Full companion install flow (two requests):**

```bash
# 1. Generate the one-shot CSRF token
TOKEN=$(curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')

# 2. Install
curl -s -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/install_companion_app \
  -d "token=$TOKEN" | jq

# 3. Verify state
curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=companion_app_state" | jq
```

**v1.5.0 — Uninstall (reserved for future UI):**

```bash
curl -s -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/uninstall_companion_app | jq
```

**v1.5.0+ — Detecting HTTP 429 (install rate limit):**

```bash
for i in 1 2 3 4 5 6; do
  TOKEN=$(curl -s -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -b /tmp/cookies.txt \
    -X POST "http://127.0.0.1:9090/api/install_companion_app" \
    -d "token=$TOKEN")
  echo "attempt $i → HTTP $CODE"
done
# Expected: 200 for the first 5, 429 for the 6th.
```

### 10.2 Python

```python
import requests

BASE = "http://127.0.0.1:9090"
DASHBOARD = "http://127.0.0.1:9091"

s = requests.Session()
s.post(f"{BASE}/api/auth/login", json={
    "username": "admin_abc12345",
    "password": "SecurePass123",
})

# Status
status = s.get(f"{BASE}/api?action=status").json()
print(f"Service: {status['status']}")

# Save allowlist
resp = s.post(f"{BASE}/api/save_allowlist", data={
    "allowlist": "googleadservices.com\ns.youtube.com",
    "expected_hash": "",
})
print(resp.json())

# Metrics
metrics = s.get(f"{DASHBOARD}/api/metrics").json()
print(f"Total queries: {metrics['total_queries']}")

# Runtime info
info = s.get(f"{BASE}/api?action=runtime_info").json()
print(f"Profile: {info['profile_key']}")
print(f"Memory limit: {info['memory_limit_mb']} MB")

# v1.5.0 — Companion install flow
token_resp = s.get(f"{BASE}/api?action=install_token").json()
token = token_resp["token"]
print(f"Token TTL: {token_resp['ttl']} s")

install_resp = s.post(f"{BASE}/api/install_companion_app", data={
    "token": token,
})

# Distinguish the three failure modes (IDX-429 + IDX-401-DISTINCT).
if install_resp.status_code == 429:
    print("🚫 Rate limited — retry in 15 minutes.")
elif install_resp.status_code == 401:
    print("❌ CSRF token expired or invalid (session is fine).")
elif install_resp.status_code == 403:
    print("❌ Non-localhost request.")
else:
    result = install_resp.json()
    if result["status"] == "ok":
        print(f"✅ Installed: {result['package']} v{result['version_name']}")
        print(f"   Strategy: {result['strategy']} (1=safest, 5=last resort)")
    else:
        print(f"❌ {result.get('message_en', 'Unknown error')}")
        if result.get("hint_en"):
            print(f"   Hint: {result['hint_en']}")

# Companion state
state = s.get(f"{BASE}/api?action=companion_app_state").json()
print(f"Installed: {state['installed']}")
print(f"Version: {state.get('version_name', 'n/a')} (expected: {state['expected_version']})")
```

### 10.3 Go

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "net/http/cookiejar"
    "net/url"
)

const base = "http://127.0.0.1:9090"

func main() {
    jar, _ := cookiejar.New(nil)
    client := &http.Client{Jar: jar}

    // Login
    creds := map[string]string{
        "username": "admin_abc12345",
        "password": "SecurePass123",
    }
    body, _ := json.Marshal(creds)
    client.Post(base+"/api/auth/login", "application/json",
        bytes.NewReader(body))

    // v1.5.0 — Companion install flow

    // 1. Get token
    respTok, _ := client.Get(base + "/api?action=install_token")
    defer respTok.Body.Close()
    var tok map[string]interface{}
    json.NewDecoder(respTok.Body).Decode(&tok)
    fmt.Printf("Token TTL: %v s\n", tok["ttl"])

    // 2. Install
    token := tok["token"].(string)
    respInst, _ := client.PostForm(base+"/api/install_companion_app",
        url.Values{"token": {token}})
    defer respInst.Body.Close()

    switch respInst.StatusCode {
    case http.StatusTooManyRequests:
        fmt.Println("🚫 Rate limited — retry in 15 minutes.")
    case http.StatusUnauthorized:
        fmt.Println("❌ CSRF token expired or invalid (session is fine).")
    case http.StatusForbidden:
        fmt.Println("❌ Non-localhost request.")
    default:
        instBody, _ := io.ReadAll(respInst.Body)
        fmt.Printf("Install: HTTP %d\n%s\n", respInst.StatusCode, instBody)
    }

    // 3. State
    respState, _ := client.Get(base + "/api?action=companion_app_state")
    defer respState.Body.Close()
    stateBody, _ := io.ReadAll(respState.Body)
    fmt.Printf("State: %s\n", stateBody)
}
```

### 10.4 JavaScript (fetch)

```javascript
const BASE = 'http://127.0.0.1:9090';

async function installCompanionApp() {
  const tokResp = await fetch(`${BASE}/api?action=install_token`, {
    credentials: 'same-origin',
  });
  if (!tokResp.ok) {
    console.error('Failed to get token:', tokResp.status);
    return;
  }
  const { token } = await tokResp.json();

  const installResp = await fetch(`${BASE}/api/install_companion_app`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `token=${encodeURIComponent(token)}`,
  });

  if (installResp.status === 429) {
    console.error('🚫 Too many install attempts. Try again later.');
    return;
  }
  if (installResp.status === 401) {
    console.error('❌ CSRF token expired. Please retry the install.');
    return;
  }
  if (installResp.status === 403) {
    console.error('❌ Install is localhost-only.');
    return;
  }

  const result = await installResp.json();
  if (result.status === 'ok') {
    console.log(`✅ Installed via strategy ${result.strategy}`);
    console.log(`   Package: ${result.package}`);
  } else {
    console.error(`❌ ${result.message_en}`);
  }
  return result;
}
```

### 10.5 Error Cases

**Unknown action:**

```bash
curl -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=definitely_unknown"
# HTTP/1.1 404 Not Found
# {"status": "error", "message": "unknown action: \"definitely_unknown\""}
```

**Login GET:**

```bash
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# HTTP/1.1 405 Method Not Allowed
# Allow: POST
```

**ensure_running_service without any auth:**

```bash
curl -i -X POST http://127.0.0.1:9090/api/ensure_running_service
# HTTP/1.1 401 Unauthorized
# {"status": "error", "message": "Unauthorized"}
```

**v1.5.0 — install without token:**

```bash
curl -i -X POST http://127.0.0.1:9090/api/install_companion_app \
  -b /tmp/cookies.txt
# HTTP/1.1 401 Unauthorized
# {"status": "error", "action": "install", "reason": "invalid_token", "message": "Invalid or expired install token"}
```

**v1.5.0+ — install_token from a non-localhost address** (only
if `BIND_ADDR=0.0.0.0` on the server):

```bash
curl -i "http://192.168.1.5:9090/api?action=install_token" \
  -b /tmp/cookies.txt
# HTTP/1.1 403 Forbidden
# {"status": "error", "action": "install_token", "reason": "not_localhost", "message": "Forbidden: install is localhost-only"}
```

### 10.6 Backup Diagnostics

**Read the full backup state via the API:**

```bash
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups'
```

**Compare with `status.sh --json`:**

| Source | Field count | Extra fields |
|---|---:|---|
| `runtime_info` (HTTP API) | **7** | — |
| `status.sh --json` (shell) | **9** | `status`, `last_backup_age_seconds` |

```bash
# API (7 fields)
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups | keys'

# Shell (9 fields)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups | keys'
```

### 10.7 Recovery Mode

**Trigger recovery:**

```bash
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"
```

**Verify the recovery succeeded:**

```bash
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups.last_stable'
```

### 10.8 Language Preference

The API is language-neutral. The bilingual toggle is a
**client-side concern only**.

```javascript
localStorage.getItem('dnscrypt-lang')  // → "en" (default) or "ar"
```

### 10.9 Companion APK Route

**Check availability:**

```bash
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
```

**Download the APK:**

```bash
curl -o DNS-Proxy.apk http://127.0.0.1:9090/app-debug.apk
```

### 10.10 Watchdog Token

**Read the token file:**

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
```

**Call the endpoint:**

```bash
TOKEN=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token")
curl -i -X POST http://127.0.0.1:9090/api/ensure_running_service \
  -H "X-Watchdog-Token: $TOKEN"
```

### 10.11 Companion Install — Complete Workflow (v1.5.0)

```bash
#!/system/bin/sh
# v1.5.0 — companion install from a shell script.

BASE="http://127.0.0.1:9090"
COOKIE_JAR="/tmp/dnscrypt_cookies.txt"

# 0. Login (if not already logged in)
curl -s -c "$COOKIE_JAR" -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"pass"}' > /dev/null

# 1. Check if already installed
STATE=$(curl -s -b "$COOKIE_JAR" "$BASE/api?action=companion_app_state")
INSTALLED=$(echo "$STATE" | jq -r '.installed')
if [ "$INSTALLED" = "true" ]; then
    echo "Already installed:"
    echo "$STATE" | jq
    exit 0
fi

# 2. Get a CSRF token
TOKEN=$(curl -s -b "$COOKIE_JAR" "$BASE/api?action=install_token" | jq -r '.token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "❌ Failed to get install token"
    exit 1
fi

# 3. Install — capture both the status code and the body
RESP=$(curl -s -b "$COOKIE_JAR" -w "\n%{http_code}" \
  -X POST "$BASE/api/install_companion_app" \
  -d "token=$TOKEN")

HTTP_CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | sed '$d')

case "$HTTP_CODE" in
    200)
        STATUS=$(echo "$BODY" | jq -r '.status')
        if [ "$STATUS" = "ok" ]; then
            STRATEGY=$(echo "$BODY" | jq -r '.strategy')
            PACKAGE=$(echo "$BODY" | jq -r '.package')
            VERSION=$(echo "$BODY" | jq -r '.version_name')
            echo "✅ Installed: $PACKAGE v$VERSION (strategy $STRATEGY)"
        else
            echo "❌ Install failed:"
            echo "$BODY" | jq -r '.message_en'
            if echo "$BODY" | jq -e '.hint_en' > /dev/null 2>&1; then
                echo "   Hint: $(echo "$BODY" | jq -r '.hint_en')"
            fi
            exit 1
        fi
        ;;
    429)
        echo "🚫 Too many install attempts. Try again in 15 minutes."
        exit 1
        ;;
    401)
        echo "❌ CSRF token expired. Please retry the install."
        exit 1
        ;;
    403)
        echo "❌ Install is localhost-only."
        exit 1
        ;;
    *)
        echo "❌ Unexpected HTTP $HTTP_CODE"
        echo "$BODY" | jq
        exit 1
        ;;
esac

# 4. Verify
curl -s -b "$COOKIE_JAR" "$BASE/api?action=companion_app_state" | jq
```

**Fallback to manual download when install fails:**

```bash
# If the root install fails, the APK is still available at:
#   http://127.0.0.1:9090/app-debug.apk
curl -o /sdcard/Download/DNS-Proxy.apk \
  "http://127.0.0.1:9090/app-debug.apk"
```

---

## 11. Changelog

### v1.5.0 (2026-10-13)

**Feature release — companion app one-tap install.**

**Added (API surface)**:

- **`POST /api/install_companion_app`** (§6.2.14).
- **`POST /api/uninstall_companion_app`** (§6.2.15).
- **`GET /api?action=install_token`** (§6.1.16).
- **`GET /api?action=companion_app_state`** (§6.1.17).
- **`install_companion_app` rate limit** — 5 failed attempts /
  15 min per IP.
- **Install-specific error messages** — AR + EN, with optional
  hints. See §5.3.

**Changed (API surface)**:

- **§1.3 Endpoint Map** — includes the four new endpoints.
- **§3.1 Rate Limiting table** — includes `install_companion_app`.
- **§5.2 Error-code table** — includes install-specific codes.
- **§6.1.15** — updated to note that `/app-debug.apk` remains as
  a fallback path.

**Compatibility**:

- All v1.4.0 clients continue to work without modification.
- All v1.5.0 changes are additive at the API level.
- The new endpoints are handled by the existing `/api/*`
  Service Worker bypass rule — no SW change required.

**Documentation corrections**: see §13 for the consolidated
table.

**Audit Corrections**: **None** — the registry in
`docs/SECURITY.md` §17 remains at **#33**.

### v1.5.0+ (2026-10-15) — Post-release patches

**Documentation-accuracy and client-side rendering pass.**

**No new audit corrections.** The registry remains at **#33**.

**Server-side changes**:

- `GET /api?action=install_token` is now **localhost-only**. The
  `isLocalRequest()` gate covers all three install surfaces.
- `HTTP_WRITE_TIMEOUT` raised from **60 s → 150 s** so the client
  never sees a connection reset while a slow install is still
  running.

**Client-side changes (WebUI)**:

- **IDX-429** — the WebUI renders `t('installRateLimited')` for
  HTTP 429 from `install_companion_app`.
- **IDX-401-DISTINCT** — the WebUI suppresses the generic
  "Session Expired" modal for install-family 401s.

**Documentation corrections**: see §13.

**Registry status**: unchanged at **#33**.

### v1.4.0 (2026-10-06) — historical

**Integration release — companion Android app + CodeQL cleanup.**

**Added**:

- **`GET /app-debug.apk`**.
- **`proxy/app-apk.version`**.

**Changed**:

- **`POST /api/remove_module`** — CodeQL `go/path-injection`
  hardening.
- **`web/index.html`** — the install button was a plain
  `<a download href="/app-debug.apk">` link.
- **iOS PWA logic removed**.

**Audit Corrections**: **None**.

### v1.3.0 (2026-10-02) — historical

**Feature release — PWA install button + live status LED +
DNS auto-start + server-side snapshot refinements.**

**Added**:

- **PWA install button** (`web/index.html`).
- **Live status LED** on the Today counter.

**Changed**:

- **`service.sh`** — boot path calls
  `POST /api/ensure_running_service` directly.
- **`main.go:buildBackupInfo()`** — SNAP-MANIFEST + SNAP-MTIME.
- **`functions.sh:rotate_backups()`** — ROT-* semantics.

**Audit Corrections**: **None**.

### v1.2.0 (2026-09-29) — historical

**Data-preservation release.**

**Added (API surface)**:

- **§2.8** — Watchdog token (`X-Watchdog-Token` header).
- **§6.1.7** — `runtime_info.backups` now returns **seven**
  fields.
- **§6.2.3–§6.2.7** — five destructive endpoints now trigger a
  pre-critical backup.
- **§10.6, §10.7, §10.8, §10.10** — new examples.

**Changed (API surface)**:

- **§6.2.13** — `POST /api/ensure_running_service` now requires
  the `X-Watchdog-Token` header (or a normal user session).

**v1.2.0 post-audit fixes (`main.go`)**:

| ID | Scope |
|---|---|
| BUG-A | `appendDenylist` — pre-critical backup performed once |
| BUG-B | `ensure_running_service` — watchdog token replaces localhost bypass |
| BUG-C | Auth cache — empty results are no longer cached |
| BUG-D | `createAutoBackup` — calls `rotate_backups 21` after success |
| BUG-E | `createAutoBackup` — unique target dir |
| BUG-F | `clear_logs` — reports `os.Truncate` errors |
| BUG-G | `getStatusUncached` — sets `"OFF"` on panic |
| BUG-H | `last_update` cache — TTL-based (5 s) |
| BUG-I | `runtime_info.profile_key` — reads `selected_profile.txt` |
| BUG-J | `isPidAlive` — exact command names only |
| BUG-K | `runShellWithTimeout` — logs `(timeout)` marker |
| BUG-L | Watchdog token file — atomic writes |

### v1.1.0 (2026-09-26) — historical

**Polish release.**

**Added**:

- **§6.1.7** — `runtime_info` returns `profile_key` and
  `memory_limit_mb`.
- **§6.1.2** — `get_profile` returns `memory_limit_mb`.
- **§6.1.14** — `metricsProxyHandler` uses the
  `MONITORING_UI_PORT` constant.

### v1.0.0 (2026-09-24) — historical

**First stable release.**

Security / correctness:

- Fixed: **Login POST-only**.
- Fixed: **`/readyz` localhost-only**.
- Fixed: **`shellQuote()`** — shell injection protection.
- Fixed: **`readConfPort` range check** — [1, 65535].
- Fixed: **`hasEndpoint()`** — exact path matching.
- Fixed: **404 for unknown action**.
- Fixed: **Basic Auth rate limiting**.
- Fixed: `metricsProxyHandler` — Prometheus → JSON.
- Fixed: `getSystemShell()`.
- Fixed: `getMonitoringAuth` — section header with comment.
- Fixed: `isPortOpenCached` — per-port cache.

State & architecture:

- Added: **`rebuildMu` mutex** — RACE-1.
- Added: **`runtime_info` ports** — PORT-2.
- Added: **Auth cache (60 s)**.
- Fixed: **Preserve settings on upgrade**.
- Fixed: `recordLoginAttempt` — no idle allocation.

---

## 12. References

### 12.1 Specifications and Tools

- RFC 7231 — HTTP/1.1 Semantics
- RFC 7231 §6.5.5 — 405 Method Not Allowed
- RFC 7231 §6.5.4 — 404 Not Found
- RFC 6265bis — Cookies
- W3C — Server-Sent Events
- MDN EventSource — https://developer.mozilla.org/en-US/docs/Web/API/EventSource
- Prometheus Text Format — https://prometheus.io/docs/instrumenting/exposition_formats/
- Go runtime/debug — SetMemoryLimit — https://pkg.go.dev/runtime/debug#SetMemoryLimit
- Android PackageManager documentation — https://developer.android.com/reference/android/content/pm/PackageManager
- POSIX — Signals and trap — https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_28

### 12.2 Project Documentation

| Document | Purpose |
|---|---|
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture |
| [docs/SECURITY.md](SECURITY.md) | Audit Corrections Registry + §5.36 companion install security + §18 documentation corrections |
| [docs/DEVELOPMENT.md](DEVELOPMENT.md) | Developer guide |
| [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [docs/CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [docs/COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [docs/DNS_BINARIES.md](DNS_BINARIES.md) | DNS binaries |
| [docs/GLOSSARY.md](GLOSSARY.md) | Glossary |
| [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) | Contributors recognition |
| [docs/ROADMAP.md](ROADMAP.md) | Roadmap |
| [docs/INSTALL.md](INSTALL.md) | Installation guide |
| [docs/UPGRADE.md](UPGRADE.md) | Upgrade guide |
| [docs/FAQ.md](FAQ.md) | FAQ |
| [docs/BACKUP.md](BACKUP.md) | Backup system reference |
| [docs/EMERGENCY.md](EMERGENCY.md) | Emergency recovery guide |
| [CHANGELOG.md](../CHANGELOG.md) | Version history |

### 12.3 Companion App Repository

The companion Android app is maintained in a separate
repository:

| Link | Purpose |
|---|---|
| [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) | Source repository |
| [Releases](https://github.com/gasciljh/dnscrypt-proxy-app/releases) | Signed APK downloads |
| [Issues](https://github.com/gasciljh/dnscrypt-proxy-app/issues) | Bug reports |

The APK is fetched by `scripts/fetch_app_apk.sh` at release time
from the version pinned in `proxy/app-apk.version` (Single
Source of Truth).

The install cascade in `proxy/install_app.sh` serves the APK to
PackageManager. The APK's SHA256 is verified against
`web/app-debug.apk.sha256` when the file is present.

### 12.4 v1.0.0 References

| Fix | Number |
|---|:---:|
| Dashboard JSON | #1 |
| Shell fallback | #2 |
| Preserve settings | #3 |
| `.gitignore` negation | #4 |
| Login POST-only | NEW-1 |
| `hasEndpoint` | #12 + NEW-2 |
| `readConfPort` range | NEW-3 |
| `/readyz` localhost | NEW-4 |
| `shellQuote` | NEW-5 |
| Auth cache | NEW-6 |
| Basic Auth rate limit | #8 |
| Section header comment | #10 |
| Per-port cache | #11 |
| `rebuildMu` (RACE-1) | — |
| `runtime_info` (PORT-2) | — |

### 12.5 v1.1.0 References

| Change | ID | Reference |
|---|:---:|---|
| Dynamic memory limit | MEM-1 | [SECURITY.md](SECURITY.md) §5.30.1 |
| Extended shellQuote | MEM-2 | [SECURITY.md](SECURITY.md) §5.30.2 |
| MONITORING_UI_PORT in metrics handler | MEM-3 | [SECURITY.md](SECURITY.md) §5.30.3 |

### 12.6 v1.2.0 References

| Change | ID | Reference |
|---|:---:|---|
| `runtime_info.backups` full schema (7 fields) | BAK-1 | [BACKUP.md](BACKUP.md) §8.1, [ARCHITECTURE.md](ARCHITECTURE.md) §4.10 |
| Pre-critical backup on destructive endpoints | BAK-2 | [BACKUP.md](BACKUP.md) §4.3, [ARCHITECTURE.md](ARCHITECTURE.md) §4.10 |
| Backup diagnostic examples | BAK-3 | [BACKUP.md](BACKUP.md) §8.1–§8.3 |
| Recovery mode examples | BAK-4 | [EMERGENCY.md](EMERGENCY.md) §9 |
| Watchdog token (`X-Watchdog-Token`) | WD-TOKEN | §2.8 above, [ARCHITECTURE.md](ARCHITECTURE.md) §4.5.1 |
| Post-audit fixes to `main.go` (BUG-A .. BUG-L) | — | [ARCHITECTURE.md](ARCHITECTURE.md) §4.6.3 |

### 12.7 v1.3.0 / v1.4.0 References

| Change | ID | Reference |
|---|:---:|---|
| PWA install button (WebUI) | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.4 |
| Live status LED (WebUI) | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.1 |
| DNS auto-start fix (`service.sh`) | — | [CHANGELOG.md](../CHANGELOG.md) §[v1.3.0] |
| Snapshot detection — manifest-based (SNAP-MANIFEST) | SNAP-MANIFEST | [ARCHITECTURE.md](ARCHITECTURE.md) §4.13.1 |
| `last_backup_name` sort order — mtime (SNAP-MTIME) | SNAP-MTIME | [ARCHITECTURE.md](ARCHITECTURE.md) §4.13.1 |
| Rotation — manifest-based detection (ROT-MANIFEST) | ROT-MANIFEST | [ARCHITECTURE.md](ARCHITECTURE.md) §4.13.2 |
| Rotation — mtime sort (ROT-MTIME) | ROT-MTIME | [ARCHITECTURE.md](ARCHITECTURE.md) §4.13.2 |
| Rotation — protected targets (ROT-PROTECT) | ROT-PROTECT | [ARCHITECTURE.md](ARCHITECTURE.md) §4.13.2 |
| Companion Android app integration | — | [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0] |
| CodeQL `go/path-injection` fix in `removeModule` | — | [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0], §6.2.10 above |
| `/app-debug.apk` route (optional) | — | §6.1.15 above |

### 12.8 v1.5.0 References

| Change | ID | Reference |
|---|:---:|---|
| Companion app install (root cascade) | — | §6.2.14 above, [ARCHITECTURE.md](ARCHITECTURE.md) §3.11, §5.8 |
| Install-method modal (IDX-24) | IDX-24 | [ARCHITECTURE.md](ARCHITECTURE.md) §3.11, §6.4 |
| Companion button state survives language toggles | IDX-23 | [ARCHITECTURE.md](ARCHITECTURE.md) §6.9 |
| Status card updates instantly on language toggle | IDX-23b | [ARCHITECTURE.md](ARCHITECTURE.md) §6.10 |
| Dashboard section-nav fix | IDX-25 | [ARCHITECTURE.md](ARCHITECTURE.md) §6.11 |
| Dashboard centered hint | IDX-25a | [ARCHITECTURE.md](ARCHITECTURE.md) §6.12 |
| Install token (one-shot CSRF) | APK-5 | §6.1.16 above |
| Companion state endpoint + 30 s cache | APK-6 | §6.1.17 above |
| 5-level `pm install` cascade | APK-5 | §6.2.14 above, [ARCHITECTURE.md](ARCHITECTURE.md) §5.8.5 |
| SELinux staging | APK-11 | §6.2.14 above, [ARCHITECTURE.md](ARCHITECTURE.md) §5.8.3 |
| Play Protect temporary disable | APK-11 | §6.2.14 above, [ARCHITECTURE.md](ARCHITECTURE.md) §5.8.4 |
| Per-IP install rate limit | APK-11 | §3.1 above |
| Package name candidates | APK-12 | §6.1.17 above, [ARCHITECTURE.md](ARCHITECTURE.md) §5.8.7 |
| Companion install security | — | [SECURITY.md](SECURITY.md) §5.36 |
| Companion install API | — | §6.2.14 above |

### 12.9 v1.5.0+ References

| Change | ID | Reference |
|---|:---:|---|
| Timeout table expanded (client / server / cascade) | — | §1.1 above |
| `install_token` endpoint now localhost-only | — | §1.1, §6.1.16 above |
| `HTTP_WRITE_TIMEOUT` raised to 150 s | — | §1.1 above |
| Install rate-limit message (client-side) | IDX-429 | §3.1, §6.2.14 above |
| Install-family 401 distinctness (client-side) | IDX-401-DISTINCT | §2.7, §4.6, §6.2.14 above |
| `logWithLevel` three-layer split | — | [ARCHITECTURE.md](ARCHITECTURE.md) §4.6.8, §11.55 |
| Port cache for `getWebUIPort` / `getDashboardPort` | — | §1.2, §6.1.7 above |
| `isLocalRequest` dead-branch removal | — | [ARCHITECTURE.md](ARCHITECTURE.md) §4.6.8 |
| `appendDenylist` hash source alignment | — | §4.3, §6.1.4, §6.2.7 above |
| Dashboard `isRefreshing` reset on 401 | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.10 |
| Dashboard session-expired modal retry | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.10 |
| Dashboard hint dual-timer | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.12 |
| Dashboard hint `scrollend` scheduling | — | [ARCHITECTURE.md](ARCHITECTURE.md) §6.12 |
| Maskable safe-circle fit | — | `web/icon-512.svg` header |
| Three-way signal trap split | — | §6.2.14 above; [SECURITY.md](SECURITY.md) §5.36.3 |

---

## 13. Documentation Corrections to This File

This section consolidates every documentation-accuracy
correction applied to this file. **None of these advances the
Audit Corrections Registry** — the registry in
`docs/SECURITY.md` §17 remains at **#33**.

### 13.1 Pre-release sweep (v1.5.0)

| ID | Section | Correction |
|:-:|---|---|
| — | §1.4 | "What was New in v1.5.0" table added |
| — | §2.7 | Install token moved to a distinct, non-session section |
| — | §3.1 | `install_companion_app` added to the rate limit table |
| — | §5.2 | Install-specific error codes added |
| — | §6.1.16 | `install_token` documented |
| — | §6.1.17 | `companion_app_state` documented |
| — | §6.2.14 | `install_companion_app` documented |
| — | §6.2.15 | `uninstall_companion_app` documented |
| — | §10.11 | Watchdog install examples added |

### 13.2 Post-release sweep (v1.5.0+)

| ID | Section | Correction |
|:-:|---|---|
| — | §1.1 | Timeout table expanded to include `HTTP_WRITE_TIMEOUT` |
| — | §1.1 | Localhost gate documented on all three install surfaces |
| — | §2.1 + §2.2 | Internal reference `§2.9` → `§2.7` (Install Token section) |
| — | §4.1 | "three" response shapes → **"four"** |
| — | §4.2 | "only exception" → **"two exceptions"** (`/readyz` + `/api/metrics`) |
| — | §4.6 | Install failure response split: 200 for install failure, 4xx for auth/rate-limit/token |
| — | §5.1 | Install-specific response shapes corrected to match `main.go`: added `reason` field to 401/429/403; removed `action` from generic 401; corrected the 429 message text |
| — | §5.1 | Added the 415 Unsupported Media Type row |
| — | §6.1.16 | Added 403 response for non-localhost |
| — | §6.1.17 | Not-installed response corrected: `package` returns the default candidate; `version_name` is absent |
| — | §6.2.14 | Response shapes corrected to match `main.go` |
| — | §6.2.15 | Response shapes corrected to match `main.go` |
| — | §13 | New section — this consolidated correction index |

### 13.3 BusyBox compatibility

The `docs/SECURITY.md` §14.34 audit commands contain BusyBox
portability corrections. `docs/API.md` does not cite any
BusyBox-incompatible shell commands; no equivalent corrections
are required here.

### 13.4 Identifier cross-references

The following corrections are documented in sibling files. They
affect facts referenced from this document but are not
themselves corrections to `docs/API.md`.

| Identifier | File | Description |
|---|---|---|
| CHG-DOC-01 | `CHANGELOG.md` | `watchdog.sh` line count corrected 1,356 → 1,326 |
| ARCH-DOC-04..06 | `docs/ARCHITECTURE.md` | File counts corrected (97 tracked / +7 / 18 in proxy) |
| HARD-SEC-XREF-01 | `docs/SECURITY.md` | Cross-reference block for the v1.5.0++ cycle |
| README-DOC-02 | `README.md` | Per-directory count correction |
| MAIN-XREF-01 | `proxy/main.go` | Documentation-only cross-reference block |
| SW-DOC-02 | `web/sw.js` | Endpoint re-attribution (4 endpoints = v1.5.0, not v1.4.0) |

### 13.5 Deprecated identifiers

The following identifiers appeared in earlier revisions of this
file and are **no longer referenced**:

- **API-V15-01..18** — consolidated into §13.2.
- **API-DATE** — the date bump is now documented in the header.
- **API-XREF-01** — consolidated into §13.4.
- **API-1..8** (v1.2.0 post-audit) — the corrections themselves
  are still in effect; only the identifiers were removed from the
  inline text and are now summarized here.

---

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (in a future release)

**Last updated**: 2026-10-15
**Version**: v1.5.0
**Author**: gasciljh
