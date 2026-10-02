# HTTP API Reference — DNSCrypt Smart Filter

Complete reference for the HTTP API used to control the module programmatically.

**Version**: v1.3.0
**Base URL (WebUI)**: `http://127.0.0.1:9090`
**Base URL (Dashboard)**: `http://127.0.0.1:9091`
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **Global edition — English default with Arabic toggle** — the
>     WebUI ships with English as the default language and an
>     in-page toggle to switch to Arabic. The `lang` field of
>     `manifest.json` defaults to `en` and `dir` to `ltr`; the
>     toggle switches them at runtime. Documentation remains
>     English-only. **No API break** — the language preference is
>     client-side only (`localStorage['dnscrypt-lang']`) and is
>     never transmitted to the server.
>   • `runtime_info.backups` now returns **seven** fields
>     (previously five):
>       `available`, `in_flight_txn`, `orphan_txn`,
>       `last_backup`, `last_backup_name`, `last_stable`,
>       `path`.
>     This aligns the JSON schema returned by `main.go` with
>     the one already produced by `status.sh --json` (see
>     §6.1.7 and §10.6).
>   • `get_profile` unchanged in shape; still returns
>     `memory_limit_mb`.
>   • Five destructive endpoints now trigger a **pre-critical
>     backup** before writing:
>       - `POST /api/update_profile`
>       - `POST /api/save_allowlist`
>       - `POST /api/save_denylist`
>       - `POST /api/save_custom_rules`
>       - `POST /api/append_denylist`
>     The backup is best-effort (never blocks the operation).
>     See §6.2.3, §6.2.4, and §6.2.5.
>   • No new endpoints, no removed endpoints, no changed
>     request formats, no changed auth requirements.
>   • All v1.0.0 and v1.1.0 clients continue to work without
>     modification. All changes are additive.
>
> **v1.2.0 — POST-AUDIT FIXES (this file, still v1.2.0)**:
>   A pre-release audit of this file identified the following
>   issues. All of them are addressed in-place; no version bump.
>
>   🔧 API-1 — §5.1 (404 vs 405 table) showed the response body
>     for "Unknown action" and "Disallowed method" as
>     `{"error": "..."}`. The actual `handleAPI` responses use
>     `{"status": "error", "message": "..."}` for every code
>     path except `/readyz`. The table now matches the code.
>     `/readyz` is the sole endpoint that returns `{"error": ...}`
>     and its row is left unchanged.
>
>   🔧 API-2 — §10.6 claimed "Both paths return the same 7
>     fields" when comparing `runtime_info.backups` (API) with
>     `status.sh --json` `.backups` (shell). That statement was
>     incomplete: the shell tool adds TWO diagnostic-only fields
>     (`status` and `last_backup_age_seconds`), so its object has
>     NINE fields. The section now distinguishes the two shapes
>     explicitly and explains what to do if they diverge.
>
>   🔧 API-3 — §6.2.7 (`POST /api/append_denylist`) documented
>     only the "Processed N rules" response. The v1.2.0 post-audit
>     fix in `main.go` (BUG-1 + BUG-5) made the handler return a
>     distinct `"No changes detected"` message when the on-disk
>     denylist already matches the request. Both branches are now
>     documented.
>
>   🔧 API-4 — §1.3 (Endpoint Map) and §6.1.7 listed only
>     `/api/runtime_info` (no trailing slash). The v1.2.0
>     post-audit fix in `main.go` (BUG-6) also registers
>     `/api/runtime_info/` with a trailing slash. Both variants
>     return the same JSON.
>
>   🔧 API-5 — §6.1.7 described the path-based form as the
>     "Alternative" to the query-string form, which was backwards.
>     Both forms are first-class; the doc now presents them as
>     equivalent entry points, listing both without implying a
>     preference.
>
>   🔧 API-6 — §8.4 JavaScript example used
>     `new EventSource('/events', { withCredentials: true })`,
>     but the note immediately below stated that the WebUI and
>     Dashboard removed `withCredentials` in v1.2.0. The example
>     now matches the shipped code (`new EventSource('/events')`)
>     and the note explains why the option is unnecessary for
>     same-origin requests.
>
>   🔧 API-7 — §6.2.13 documented the `ensure_running_service`
>     auth exemption as applying only to `127.0.0.1`. The
>     `isLocalRequest()` helper accepts three values:
>     `127.0.0.1`, `::1`, and `localhost`. The doc now lists all
>     three.
>
>   🔧 API-8 — §11 (Changelog → v1.2.0) listed only the API-level
>     additions (BAK-1, BAK-2). It did not mention the seven
>     post-audit fixes applied to `main.go` in the same release
>     window (BUG-1 .. BUG-6, N-1, N-4). The entry now lists them
>     as a distinct subsection so a reader can trace the full
>     v1.2.0 delta.

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

---

## 1. Overview

### 1.1 Basics

| Item | Value |
|---|---|
| **Protocol** | HTTP/1.1 |
| **Binding** | `127.0.0.1` only (not reachable from the network by default) |
| **Encoding** | UTF-8 |
| **Content-Type** | `application/json` (default) |
| **Auth** | Bearer / Cookie / Basic |
| **Timeout (client)** | 15 s (normal GET), 60 s (`toggle`/`restart`), 310 s (`update_profile`) |
| **Language** | The WebUI is bilingual (English default + Arabic toggle via `langToggle`). The API itself is **language-neutral** — it returns JSON without localized strings. |

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

`readConfPort()` validates the range `[1, 65535]`. Values outside the range fall back to the default (9090 / 9091).

`MONITORING_UI_PORT` is declared as a Go constant in `main.go`
and reused in every place that needs the reserved port
including `metricsProxyHandler` (v1.1.0 — see §6.1.14).

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
│    GET  /apple-touch-icon.png    iOS icon                    │
│    GET  /favicon-32x32.png       Modern favicon              │
│    GET  /favicon-16x16.png       Legacy favicon              │
│    GET  /favicon.ico             IE + bookmarks              │
│    GET  /offline.html            Offline fallback            │
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
│    GET  /api/runtime_info/       (same; BUG-6 fix)           │
│    GET  /api?action=runtime_info (same; query-string form)   │
│                                  → both include backups      │
│                                    (v1.2.0 — 7 fields)       │
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
│    POST /api/ensure_running_service  Ensure DNS running      │
└─────────────────────────────────────────────────────┘
```

### 1.4 What was New in v1.1.0

| Section | Change | Reference |
|---|---|---|
| **§2.1** | Memory limits per profile (new table) | MEM-1 |
| **§6.1.7** | `runtime_info` returns `profile_key` + `memory_limit_mb` | MEM-1 |
| **§6.1.14** | `metricsProxyHandler` uses `MONITORING_UI_PORT` constant | MEM-3 |
| **§11** | Changelog entry for v1.1.0 | — |

Architectural note: the API structure is unchanged — v1.1.0 is
additive. All v1.0.0 clients continue to work without changes.

---

### 1.5 What is New in v1.2.0

| Section | Change | Reference |
|---|---|---|
| **§1.1** | Language is now bilingual (EN default + AR toggle). The API stays language-neutral. | — |
| **§6.1.7** | `runtime_info.backups` returns **7 fields** (was 5) | BAK-1 |
| **§6.2.3** | `update_profile` creates a pre-critical backup | BAK-2 |
| **§6.2.4** | `save_allowlist` creates a pre-critical backup | BAK-2 |
| **§6.2.5** | `save_denylist` creates a pre-critical backup | BAK-2 |
| **§6.2.6** | `save_custom_rules` creates a pre-critical backup | BAK-2 |
| **§6.2.7** | `append_denylist` creates a pre-critical backup | BAK-2 |
| **§10.6** | New backup diagnostic examples | BAK-3 |
| **§10.7** | New recovery-mode examples | BAK-4 |
| **§11** | Changelog entry for v1.2.0 | — |

**Compatibility**: All v1.0.0 and v1.1.0 clients continue to
work without modification. All v1.2.0 changes are additive:

- The `backups` object gained **two** fields
  (`in_flight_txn`, `orphan_txn`).
- Five POST endpoints now trigger a best-effort backup before
  writing. This is transparent to clients: the request/response
  format is unchanged, and a failed backup never fails the
  request.
- The `lang`/`dir` fields of `manifest.json` default to `en`/`ltr`
  and are updated at runtime by the in-page toggle. This affects
  only the PWA shell, not the API.
- The API itself is **language-neutral**: it never sends nor
  accepts a language identifier. The `langToggle` is a purely
  client-side concern.

**Architectural note**: v1.2.0 is a **data-preservation
release**. It does not change the API contract — it only
enriches the observability surface and hardens the write path.

### 1.6 What was New in v1.0.0

| Section | Change | Reference |
|---|---|---|
| **§1.2** | `readConfPort` range check [1, 65535] | Fix NEW-3 |
| **§2.3** | Login POST-only (rejects GET/HEAD/PUT/DELETE) | Fix NEW-1 |
| **§2.5** | Logout POST-only | Fix NEW-1 |
| **§3.3** | Basic Auth rate limiting (previously unlimited) | Fix #8 |
| **§3.5** | Auth cache (60 s TTL) — reduces file I/O | Fix NEW-6 |
| **§4.5** | 404 for unknown action | Fix #12 |
| **§5.1** | 404 vs 405 — adds Login POST-only | Fix NEW-1 |
| **§6.1.7** | `runtime_info` returns `webui_port` + `dashboard_port` | PORT-2 |
| **§6.1.14** | `/api/metrics` JSON schema (instead of Prometheus text) | Fix #1 |
| **§7** | Exact path matching (`hasEndpoint`) | Fix #12 |

---

## 2. Authentication

### 2.1 Memory Limits per Profile (v1.1.0)

The Go runtime soft memory limit is set dynamically by `main.go`
based on the active blocklist profile. This affects the memory
reported by `runtime_info.memory_limit_mb` (§6.1.7).

| Profile | `memory_limit_mb` | `profile_key` | Typical device |
|---|---:|:---:|---|
| Light | 80 | `light` | 1 GB RAM |
| Normal | 100 | `normal` | 2 GB RAM |
| PRO | 120 | `pro` | 3 GB RAM (default) |
| PRO++ | 160 | `proplus` | 4 GB RAM |
| Ultimate | 220 | `ultimate` | 6 GB+ RAM |

**Semantics**:
- `debug.SetMemoryLimit` is a **soft** limit — the Go runtime
  runs GC more aggressively as usage approaches it, but it does
  **not** kill the process (no OOM).
- The limit is recomputed at startup (`main()`) and on every
  profile change (`POST /api/update_profile`).
- The value is **read-only** from the API — you cannot change it
  via an endpoint. Change the profile instead.

**Example**:

```bash
# Current limit for the active profile
curl -s -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.memory_limit_mb'
# → 120  (if profile is "pro")
```

### 2.2 Schemes

| Scheme | Header/Cookie | Priority | Rate Limited |
|---|---|:---:|:---:|
| Bearer | `Authorization: Bearer <token>` | 1 | No |
| Cookie | `Cookie: dnscrypt_session=<token>` | 2 | No |
| Basic | `Authorization: Basic <base64>` | 3 | Yes |

Basic Auth is rate-limited (5 attempts / 15 min) since v1.0.0 — previously unlimited.

### 2.3 Credentials Source

Credentials are read exclusively from the `[monitoring_ui]` section of `dnscrypt-proxy.toml`.

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
- `customize.sh` → `[18]` verification with section tracking.

Section header with comment is supported:

```toml
[monitoring_ui] # monitoring section
  username = 'admin'
```

The pattern is now extracted between `[` and `]` (first occurrence).

Auth cache (Fix NEW-6):

- `getMonitoringAuth()` caches credentials for **60 seconds**.
- Changing credentials in TOML takes effect within ≤ 60 seconds.
- For immediate effect: restart the WebUI.

### 2.4 Login — POST-only (Fix NEW-1)

`/api/auth/login` accepts **POST only**.

- GET/HEAD/PUT/DELETE → **405 Method Not Allowed**.
- Reason: prevents a CSRF vector and prevents credentials from leaking into the URL.

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
> `::1`, or `localhost`). The example above assumes the default
> `127.0.0.1` bind. On a LAN bind the attribute is omitted so
> that browsers accept the cookie over plain HTTP. See §2.5.

There is no `token` field in the response. Authentication relies solely on the HttpOnly cookie.

> **v1.1.0 note**: the `profile` object in the response now also
> contains `memory_limit_mb` (added in v1.1.0). Clients that
> ignore unknown fields are unaffected.

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

Supported methods:

| Method | Before | After v1.0.0 |
|--------|:---:|:---:|
| POST | ✅ | ✅ |
| GET | ⚠️ accepted (CSRF) | ❌ 405 + `Allow: POST` |
| HEAD | ⚠️ accepted | ❌ 405 + `Allow: POST` |
| PUT | ⚠️ accepted | ❌ 405 + `Allow: POST` |
| DELETE | ⚠️ accepted | ❌ 405 + `Allow: POST` |

Test the rejection:

```bash
# ✅ POST (works)
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"..."}' \
    -c /tmp/cookies.txt

# ❌ GET (rejected)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → HTTP/1.1 405 Method Not Allowed
# → Allow: POST
```

### 2.5 Cookie Properties

| Property | Value | Note |
|---|---|---|
| Name | `dnscrypt_session` | — |
| Path | `/` | — |
| MaxAge | 86400 (24 h) | — |
| HttpOnly | `true` | JavaScript cannot read it |
| Secure | conditional | `true` only on loopback binds (`127.0.0.1`, `::1`, `localhost`) |
| SameSite | `Lax` | PWA-friendly |

Secure details:

- `true` if `BIND_ADDR` = `127.0.0.1` / `::1` / `localhost`.
- `false` otherwise (LAN access).

SameSite details:

- `Lax` (instead of `Strict` in older versions).
- Supports PWA shortcuts.
- Protects against CSRF (cross-site POST forbidden).

### 2.6 Logout — POST-only (Fix NEW-1)

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

### 2.7 Authentication Flow Diagram

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

---

## 3. Rate Limiting

### 3.1 Limits (v1.2.0)

| Endpoint | Limit | Window | Enforcement |
|---|---|---|---|
| POST `/api/auth/login` | 5 attempts | 15 min | `handleLogin` |
| Basic Auth (any endpoint) | 5 attempts | 15 min | `checkAuth` |
| GET `/api/*` (with Cookie/Bearer) | unlimited | — | — |
| POST `/api/*` (with Cookie/Bearer) | unlimited | — | — |

### 3.2 Behavior

- 5 failed attempts → 15-minute lockout.
- Lockout per IP.
- Client IP extraction supports IPv4 and IPv6 via `net.SplitHostPort`.
- Failed Basic Auth attempts are recorded in `loginAttempts`.
- `X-Forwarded-For` is not used (localhost-only).

### 3.3 Basic Auth Rate Limiting (Fix #8)

Before:

```go
// checkAuth
user, pass, ok := r.BasicAuth()
if ok {
    // Does not record failed attempts
    if userMatch && passMatch { return true }
}
// ← unlimited Basic Auth requests allowed
```

After:

```go
func checkAuth(r *http.Request) bool {
    // ...
    user, pass, ok := r.BasicAuth()
    if ok {
        ip := getClientIP(r)

        // rate limiting
        if isLockedOut(ip) {
            return false
        }

        userMatch := subtle.ConstantTimeCompare(...)
        passMatch := subtle.ConstantTimeCompare(...)
        if userMatch && passMatch {
            recordLoginAttempt(ip, true)
            return true
        }

        // failed attempt → record + check rate limit
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

Before:

```go
ip := strings.Split(r.RemoteAddr, ":")[0]
// IPv4 "127.0.0.1:12345" → "127.0.0.1" ✅
// IPv6 "[::1]:12345"     → "["           ❌
```

After:

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

### 3.5 Auth Cache (60 s) — Fix NEW-6

`getMonitoringAuth()` caches credentials for **60 seconds**.

Reason:

- Before: every HTTP request read the entire `dnscrypt-proxy.toml` (~5–10 ms per request).
- After: cache hit → ~0.05 ms per request.

Impact:

| Metric | Before | After |
|---|:---:|:---:|
| 100 req/s | ~1 MB/s I/O | ~0 MB/s (cache) |
| Response time | ~5–10 ms | ~0.05 ms |
| Battery consumption | High | Low |

Constraints:

- Changing credentials in TOML takes effect within ≤ 60 seconds.
- For immediate effect: restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```

**Response (429):**

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "status": "error",
  "message": "Too many attempts. Try again later."
}
```

---

## 4. Response Format

### 4.1 Success

```json
{
  "status": "ok",
  "data": { }
}
```

### 4.2 Error

```json
{
  "status": "error",
  "message": "Error description",
  "details": "Additional details (optional)"
}
```

> **Exception — `/readyz`**: `/readyz` is the only endpoint that
> does NOT use the `{status, message}` shape. On a non-localhost
> request it returns `{"error": "readyz is localhost-only"}` with
> HTTP 403. See §9.2.

### 4.3 Conflict

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```
*HTTP status: 409 Conflict.*

### 4.4 Processing (async)

```json
{
  "status": "processing",
  "message": "Update in progress..."
}
```

### 4.5 Not Found (Fix #12)

```json
{
  "status": "error",
  "message": "unknown action: \"foo\""
}
```
*HTTP status: 404 Not Found.*

Before: unknown action → `200 OK` with `{"status": "unknown"}`.
After: `404 Not Found` with a clear message.

**Example:**

```bash
curl -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=definitely_unknown"
# HTTP/1.1 404 Not Found
# {
#   "status": "error",
#   "message": "unknown action: \"definitely_unknown\""
# }
```

---

## 5. Error Codes

| HTTP Code | Meaning | Example |
|---|---|---|
| 200 | ok / success | — |
| 200 | processing | `update_profile` |
| 400 | error — bad input | missing param |
| 401 | error — unauthorized | session expired |
| 403 | error — forbidden | path traversal / `/readyz` from LAN |
| 404 | error — path/action not found | `?action=foo` |
| 405 | error — method not allowed | GET on POST endpoint / Login GET |
| 409 | conflict — hash mismatch | concurrent edit |
| 413 | error — file too large | POST > 5 MB |
| 429 | error — too many requests | rate limit (login + Basic Auth) |
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

> **API-1 fix**: the first two rows previously showed `{"error": "..."}`
> bodies, which did not match the actual `handleAPI` responses.
> `handleAPI` uses the `{status, message}` shape for every code
> path (see §4.2). Only `/readyz` uses `{"error": ...}`, because
> it is served by `handleReadyz` — a separate handler — and not
> by `handleAPI`.

### 5.2 Not Found vs 405 Table

```text
┌────────────────────────────┬─────┬───────────┐
│  Scenario                       │ Code │  Fix        │
├────────────────────────────┼─────┼───────────┤
│  ?action=foo (unknown)          │ 404  │ Fix #12     │
│  POST /api/save_allowlist_evil  │ 404  │ Fix #12     │
│  GET /api/auth/login            │ 405  │ Fix NEW-1   │
│  GET /api?action=toggle         │ 405  │ Fix #13     │
│  /readyz from LAN               │ 403  │ Fix NEW-4   │
└────────────────────────────┴─────┴───────────┘
```

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

- `STATUS_FILE` = "user intent".
- `status endpoint` = "actual state".
- They may differ temporarily on crash (before the Watchdog restarts).

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

> **v1.1.0**: `memory_limit_mb` is a new field that mirrors the
> active profile's soft memory limit (§2.1). It is additive —
> clients that only need `key` / `name` / `entries` are unaffected.

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
*Used to verify hash before saving.*

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

**Equivalent entry points (API-5 fix)**:

| Form | Handler | Notes |
|---|---|---|
| `GET /api/runtime_info` | `handleRuntimeInfo` | Path-based (canonical) |
| `GET /api/runtime_info/` | `handleRuntimeInfo` | Path-based with trailing slash (BUG-6 fix) |
| `GET /api?action=runtime_info` | `handleAPI` | Query-string form |

All three return the **same JSON body** — they invoke
`buildRuntimeInfo()`. Choose whichever form fits the client
convention; none is deprecated.

**Response (v1.2.0):**

```json
{
  "version": "v1.2.0",
  "commit": "a1b2c3d",
  "build_time": "1726987200",
  "build_time_human": "2026-09-26T10:00:00Z",
  "project_url": "https://github.com/gasciljh/dnscrypt-proxy-webui",
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
    "last_backup": "2026-09-26 15:00:00",
    "last_backup_name": "20260926-150000-manual",
    "last_stable": "20260926-095826-v1.2.0",
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
| **Dynamic ports** (PORT-2) | `webui_port`, `dashboard_port` | v1.0.0 |
| **Memory profile** (MEM-1) | `profile_key`, `memory_limit_mb` | v1.1.0 |
| **Backups** (BAK-1) | `available`, `in_flight_txn`, `orphan_txn`, `last_backup`, `last_backup_name`, `last_stable`, `path` | **v1.2.0** |

**`profile_key`** — one of: `light`, `normal`, `pro`, `proplus`, `ultimate`.

**`memory_limit_mb`** — the Go runtime soft limit for the active profile. See §2.1 for the mapping.

**`backups` object — full schema (v1.2.0):**

| Field | Type | Description |
|---|---|---|
| `available` | int | Number of snapshots (excludes `current/`, `txn-*`, `orphan-txn-*`) |
| `in_flight_txn` | int | Number of `txn-*` directories (install in progress or interrupted) |
| `orphan_txn` | int | Number of `orphan-txn-*` directories (preserved interrupted installs) |
| `last_backup` | string \| null | Modification time of the newest snapshot, formatted as `YYYY-MM-DD HH:MM:SS` |
| `last_backup_name` | string \| null | Directory name of the newest snapshot (e.g. `20260926-150000-manual`) |
| `last_stable` | string \| null | Content of the `.last_stable` pointer file, or null if not set |
| `path` | string | Absolute path of the persistent backup directory (`/sdcard/dnscrypt-webui-backup`) |

**Why these fields exist**:
- **Observability** — a user reporting a GC or performance issue can paste the JSON output.
- **Verification** — the WebUI/Dashboard System Info panel displays them.
- **Shell equivalent** — `functions.sh:get_profile_memory_hint()` for memory, `status.sh --json` for backups.
- **Consistency** — the JSON schema now matches `status.sh --json` on the seven shared fields (see §10.6; the shell tool adds two more).

**Benefits**:

- HTML/JS can update links dynamically.
- Supports LAN access (`window.location.hostname`).
- Supports IPv6 loopback (`[::1]`).
- Clients can detect a corrupted backup layer (e.g. `orphan_txn > 0`).

**`status_file`** = "user intent". Values: ON / OFF. Written only by `startService` / `stopService`. To check the actual state, use `GET /api?action=status`.

#### 6.1.8 `GET /api?action=logs`

Last 300 lines from the log.

**Response:**

```json
{
  "logs": "[2026-09-26T10:30:00Z] 🚀 Starting DNSCrypt WebUI...\n[...]"
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
*File types: active, archive, emergency, sensitive.*

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

Before v1.0.0: returned Prometheus text with `Content-Type: application/json` → `JSON.parse()` failed → Dashboard showed "Cannot fetch data" permanently.

After v1.0.0: `parsePrometheus()` → `buildDashboardJSON()` → `Content-Type: application/json`.

**v1.1.0 change (MEM-3)**: The upstream URL used by
`metricsProxyHandler` is now built from the `MONITORING_UI_PORT`
Go constant instead of the hardcoded string `"8080"`. Behavior
is unchanged:

```go
// Before v1.1.0:
"http://127.0.0.1:8080/api/metrics"

// After v1.1.0:
"http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

The observable API contract is identical. The change only
removes one hardcoded reference to the reserved port.

**Flow:**

```text
Dashboard (9091)
  → GET /api/metrics (main.go)
    → metricsProxyHandler
      → GET http://127.0.0.1:<MONITORING_UI_PORT>/api/metrics  ← v1.1.0
        → monitoring_ui (dnscrypt-proxy)
          → returns JSON or Prometheus text
      → JSON response passed through OR parsePrometheus() + buildDashboardJSON()
  ← JSON response
```

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
  "generated_at": "2026-09-26T10:30:00Z",
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

**Field details:**

| Field | Type | Description |
|-------|:----:|-------------|
| `generated_at` | string | RFC3339 timestamp |
| `total_queries` | float64 | Total queries |
| `blocked_queries` | float64 | Blocked queries |
| `queries_per_second` | float64 | QPS (currently 0 — placeholder) |
| `uptime_seconds` | float64 | Uptime (currently 0 — placeholder) |
| `avg_response_time` | float64 | Average response time (currently 0 — placeholder) |
| `cache_stats.enabled` | bool | `true` if cache is active |
| `cache_stats.cache_hit_ratio` | float64 | 0.0–1.0 (hit ratio) |
| `cache_stats.cache_hits` | float64 | Cache hits |
| `cache_stats.cache_misses` | float64 | Cache misses |
| `cache_stats.configured_size` | float64 | Configured size |
| `query_types` | array | Empty array (filled later) |
| `resolver_health` | array | Empty array (filled later) |
| `top_domains` | array | Empty array (filled later) |
| `sources` | array | Empty array (filled later) |
| `recent_queries` | array | Empty array (filled later) |

**Response (401 Unauthorized):**

```json
{
  "error": "Unauthorized Access"
}
```

> **Exception**: `metricsProxyHandler` — like `handleReadyz` — uses
> the `{"error": ...}` shape rather than the `{status, message}`
> shape that `handleAPI` uses. See §4.2.

**Response (500 Internal Server Error):**

```json
{
  "error": "Monitoring authentication not configured"
}
```

**Response (502 Bad Gateway):**

```json
{
  "error": "Upstream returned HTTP 500"
}
```

**Response (503 Service Unavailable):**

```json
{
  "error": "DNSCrypt-Proxy is stopped or unreachable"
}
```

**Supported Prometheus metric names (fallback mode):**

| Prometheus name | JSON field |
|---|---|
| `dnscrypt_proxy_query_total` | `total_queries` |
| `dnscrypt_query_total` | (fallback) |
| `dnscrypt_proxy_queries_total` | (fallback) |
| `dnscrypt_proxy_blocked_query_total` | `blocked_queries` |
| `dnscrypt_blocked_query_total` | (fallback) |
| `dnscrypt_proxy_cache_hits_total` | `cache_hits` |
| `dnscrypt_proxy_cache_hit_total` | (fallback) |
| `dnscrypt_cache_hits_total` | (fallback) |
| `dnscrypt_proxy_cache_misses_total` | `cache_misses` |
| `dnscrypt_proxy_cache_miss_total` | (fallback) |
| `dnscrypt_cache_misses_total` | (fallback) |

If a Prometheus label has multiple values (e.g. `cache_hits_total{type="positive"}`), `parsePrometheus` sums them all under the same name.

**Verify:**

```bash
# Query main.go directly
curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'

# Check Content-Type
curl -sI http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: Content-Type: application/json; charset=utf-8
```

### 6.2 POST Endpoints

#### 6.2.1 `POST /api/auth/login`

*(see §2.4)*

#### 6.2.2 `POST /api/auth/logout`

*(see §2.6)*

#### 6.2.3 `POST /api/update_profile`

Update the blocklist from a profile.

**Pre-critical backup (v1.2.0):** Before writing, the handler
calls `createAutoBackup("pre-profile-change")`, which snapshots
the 5 user config files to the persistent backup directory
(`/sdcard/dnscrypt-webui-backup/`). This is **best-effort**: a
failed backup logs a warning but does not block the update.

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

RACE-1: if `updateProfile` is running and `allowlist` is saved at the same time, `rebuildMu` serializes the rebuilds — may appear slower but is safe.

**v1.1.0 (MEM-1)**: After a successful rebuild, the handler
applies the new profile's memory limit via `applyMemoryLimit()`.
The new limit is reflected in subsequent `runtime_info` calls
(§6.1.7).

**v1.2.0 (BAK-2)**: A pre-critical backup is created before the
profile change. The backup appears as a new snapshot directory
under `/sdcard/dnscrypt-webui-backup/`. It is visible via
`runtime_info.backups.last_backup_name`.

#### 6.2.4 `POST /api/save_allowlist`

**Pre-critical backup (v1.2.0):** Calls
`createAutoBackup("pre-allowlist-save")` before writing
(best-effort).

**Request:**

```http
POST /api/save_allowlist HTTP/1.1
Content-Type: application/x-www-form-urlencoded

allowlist=googleadservices.com%0As.youtube.com&expected_hash=abc123...
```
**Params:**

- `allowlist` (required) — content (URL-encoded).
- `expected_hash` (optional) — hash from `get_custom_rules`.

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

> When the submitted content is byte-identical to what is
> already on disk, the handler short-circuits: no file write,
> no blocklist rebuild, no service reload. `changed: false`
> is returned and the hashes are the current on-disk values.

**Response (409 conflict):**

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```

#### 6.2.5 `POST /api/save_denylist`

Same as `save_allowlist` but uses the `denylist` param.

**Pre-critical backup (v1.2.0):** Calls
`createAutoBackup("pre-denylist-save")` before writing
(best-effort).

#### 6.2.6 `POST /api/save_custom_rules`

Save both atomically.

**Pre-critical backup (v1.2.0):** Calls
`createAutoBackup("pre-custom-rules-save")` before writing
(best-effort).

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

**Pre-critical backup (v1.2.0):** The pre-critical backup is
performed **once** by the delegated `saveDenylist` path (the
v1.2.0 post-audit fix BUG-1 removed a duplicate call in the
original `appendDenylist` implementation). The backup is
best-effort.

**Response — rules applied (changed):**

```json
{
  "status": "ok",
  "changed": true,
  "message": "Processed 250000 rules",
  "hash": "xyz789...",
  "allow_hash": "abc123...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Response — no change (API-3 fix):**

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

> The `"Processed N rules"` message reports the **total blocklist
> entry count** (not the size of the deny list). The
> `"No changes detected"` branch triggers when the on-disk
> denylist is byte-identical to what the handler reads back —
> in that case the atomic-save path short-circuits and no
> rebuild is performed.

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
*Restrictions:*
- Cannot clear the active log (`dnscrypt_main.log`).
- Cannot clear sensitive files.

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

**Request:**

```http
POST /api/remove_module HTTP/1.1
Content-Type: application/x-www-form-urlencoded

path=/data/adb/modules/dnscrypt-old
```

**Response:**

```json
{
  "status": "ok",
  "message": "Old module removed successfully"
}
```
*Security:*
- Path must be under `/data/adb/modules/`.
- Must contain `.module.fingerprint` with `dnscrypt-proxy-webui`.
- Cannot remove the current module.

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

**Notes:**
- May take 1–60 s (depending on service state).
- Recommended HTTP timeout: 60 s.
- When stopping: `STATUS_FILE` = "OFF" (user intent).
- When starting: `STATUS_FILE` = "ON" (user intent).

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
*Notes:*
- Internal flow: `stopService()` → `startService()`.
- May take 2–60 s.
- Recommended HTTP timeout: 60 s.

#### 6.2.13 `POST /api/ensure_running_service`

Called by the Watchdog. Checks `STATUS_FILE` then restarts if needed.

**Request:**

```http
POST /api/ensure_running_service HTTP/1.1
Cookie: dnscrypt_session=<token>
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

This endpoint relies on `STATUS_FILE` as "user intent":
- `STATUS_FILE` = "ON" → DNS engine crashed; Watchdog restarts it.
- `STATUS_FILE` = "OFF" → user stopped the service; Watchdog does nothing.

**Authentication exemption (API-7 fix)**: `checkAuth()`
short-circuits to `true` when **both** of the following hold:

1. The request originated from a **loopback** address — one of
   `127.0.0.1`, `::1`, or `localhost` (as determined by
   `isLocalRequest()`).
2. The request is a **POST** to
   `/api/ensure_running_service` (matched via `hasEndpoint`).

Requests from a LAN IP (even with valid credentials) go through
normal auth. Any method other than POST, or any other endpoint,
goes through normal auth. The exemption exists because the
Watchdog runs on the same host and cannot easily carry a
session cookie.

---

## 7. Path Matching

### 7.1 `hasEndpoint()` Function

Before:

```go
if strings.Contains(r.URL.Path, "update_profile") {
    // ← also matches: /api/update_profile_evil
    // ← also matches: /prefix/api/update_profile
    // ← dangerous: loose match
}
```

After:

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

### 7.3 Examples

Correct:

```http
POST /api/save_allowlist HTTP/1.1
→ hasEndpoint(path, "save_allowlist") = true ✅
```

Incorrect (not handled):

```http
POST /api/save_allowlist_evil HTTP/1.1
→ hasEndpoint(path, "save_allowlist") = false ❌
→ returns 404 Not Found
```

### 7.4 Endpoints Using `hasEndpoint`

All POST endpoints use `hasEndpoint`:
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

### 7.5 Supported Path Variants

For each endpoint, these two paths are equivalent:

```text
✅ /api/save_allowlist        ← canonical
✅ /api/save_allowlist/       ← trailing slash
```

### 7.6 Rejected Path Variants

```text
❌ /api/save_allowlist_extra  ← suffix
❌ /prefix/api/save_allowlist ← prefix
❌ /api/save_allowlist/child  ← subpath
❌ /api/SAVE_ALLOWLIST        ← case-sensitive
```

### 7.7 Test Coverage

```bash
# Quick check on the source
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ present"

# Runtime check
curl -i "http://127.0.0.1:9090/api?action=nonexistent"
# → 404 Not Found

curl -i -X POST "http://127.0.0.1:9090/api/save_allowlist_evil" \
  -b /tmp/cookies.txt
# → 404 Not Found (not treated as save_allowlist)
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

**Behavior:**
- Connection stays open.
- Keepalive every 15 s (`: keepalive\n\n`).
- Write Deadline: 30 s per flush.
- Slow clients are disconnected after 30 s.

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
// API-6 fix: `withCredentials` is not passed — it is unnecessary
// for same-origin requests. The /events endpoint is same-origin
// with both the WebUI (9090) and the Dashboard (9091), so the
// browser sends cookies automatically.
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

> **Note (v1.2.0)**: `withCredentials: true` is optional for
> same-origin requests — cookies are sent automatically. The
> WebUI and Dashboard dropped this option in v1.2.0 as part of a
> cleanup. It remains supported by the browser for clients that
> connect from a different origin (rare, and usually blocked by
> CORS anyway).

### 8.5 SSE Write Deadline

Problem in the old design:

```go
// http.Server.WriteTimeout = 0 (infinite)
// If the client is slow (TCP buffer full), Fprint blocks forever
fmt.Fprint(w, msg)   // ← may hang the goroutine
```

Solution:

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

### 9.2 `GET /readyz` — localhost-only (Fix NEW-4)

Readiness check. Verifies dependencies.

Requests from outside localhost → **403 Forbidden**.

**Response (200) — from localhost:**

```json
{
  "config": "ok",
  "blocklist": "ok",
  "run_dir": "ok",
  "dns_engine": "ok",
  "version": "v1.2.0",
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
  "version": "v1.2.0",
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

> **Exception**: `/readyz` is one of the few endpoints that
> returns `{"error": ...}` instead of `{"status": "error",
> "message": ...}`. This is because it is served by the dedicated
> `handleReadyz` handler, not by `handleAPI`. See §4.2.

*Checks:*
- `config` — `dnscrypt-proxy.toml` exists.
- `blocklist` — `blocklist.txt` readable.
- `run_dir` — `proxy/run/` writable.
- `dns_engine` — dnscrypt-proxy running on 5354.

**Difference between `/healthz` and `/readyz`:**

| Endpoint | Access | Info Exposed | Use Case |
|----------|:---:|---|---|
| `/healthz` | public | `ok` only | Load balancer liveness |
| `/readyz` | localhost-only | system details | Debugging + startup |

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
# ✅ correct — POST
curl -b /tmp/cookies.txt \
  -X POST http://127.0.0.1:9090/api/toggle_service

# ❌ wrong — GET (CSRF protection)
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api?action=toggle
# → 405 Method Not Allowed + Allow: POST
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

**SSE:**

```bash
curl -b /tmp/cookies.txt -N http://127.0.0.1:9090/events
```

**Download log:**

```bash
curl -b /tmp/cookies.txt \
  -o dnscrypt_main.log \
  "http://127.0.0.1:9090/api/download_log?file=dnscrypt_main.log"
```

**Metrics (Dashboard):**

```bash
# Now returns JSON instead of Prometheus text
curl -b /tmp/cookies.txt http://127.0.0.1:9091/api/metrics | jq

# Expected: JSON with total_queries, blocked_queries, cache_stats, ...
```

**Basic Auth rate limiting:**

```bash
# 5 failed attempts → 15-minute lockout
for i in 1 2 3 4 5 6; do
  curl -u "wronguser:wrongpass" http://127.0.0.1:9090/api?action=status
  echo ""
done
# Each response is HTTP 401. After the 5th failure the IP is
# locked; the 6th request still returns 401 (no 429 — 429 is
# only emitted by handleLogin for the /api/auth/login endpoint).
```

**Login GET rejected:**

```bash
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# HTTP/1.1 405 Method Not Allowed
# Allow: POST
```

**Unknown action:**

```bash
curl -i "http://127.0.0.1:9090/api?action=foo"
# HTTP/1.1 404 Not Found
```

**v1.1.0 — Runtime info with profile + memory:**

```bash
# Full runtime_info
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq

# Only the two v1.1.0 fields
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}
```

**v1.2.0 — Runtime info with backup state (all three path forms):**

```bash
# Path form
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api/runtime_info | jq '.backups'

# Path form with trailing slash (BUG-6 fix — same JSON)
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api/runtime_info/ | jq '.backups'

# Query-string form (same JSON)
curl -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups'
```

### 10.2 Python

```python
import requests

BASE = "http://127.0.0.1:9090"
DASHBOARD = "http://127.0.0.1:9091"

# Login
r = requests.post(f"{BASE}/api/auth/login", json={
    "username": "admin_abc12345",
    "password": "SecurePass123",
})
r.raise_for_status()

# Session with cookies
s = requests.Session()
s.post(f"{BASE}/api/auth/login", json={
    "username": "admin_abc12345",
    "password": "SecurePass123",
})

# Status
status = s.get(f"{BASE}/api?action=status").json()
print(f"Service: {status['status']}")

# Toggle (POST)
new_status = s.post(f"{BASE}/api/toggle_service").json()
print(f"New status: {new_status['status']}")

# Save allowlist
resp = s.post(f"{BASE}/api/save_allowlist", data={
    "allowlist": "googleadservices.com\ns.youtube.com",
    "expected_hash": "",
})
print(resp.json())

# Metrics
metrics = s.get(f"{DASHBOARD}/api/metrics").json()
print(f"Total queries: {metrics['total_queries']}")
print(f"Blocked: {metrics['blocked_queries']}")
print(f"Cache hit ratio: {metrics['cache_stats']['cache_hit_ratio']:.2%}")

# Runtime info (PORT-2 + MEM-1 + BAK-1)
info = s.get(f"{BASE}/api?action=runtime_info").json()
print(f"WebUI port: {info['webui_port']}")
print(f"Dashboard port: {info['dashboard_port']}")
print(f"Profile: {info['profile_key']}")
print(f"Memory limit: {info['memory_limit_mb']} MB")

# v1.2.0 — Backup state
bk = info["backups"]
print(f"Backups available: {bk['available']}")
print(f"Latest backup: {bk['last_backup_name']}")
print(f"Last stable: {bk['last_stable']}")
print(f"In-flight txn: {bk['in_flight_txn']}")
print(f"Orphan txn: {bk['orphan_txn']}")
print(f"Backup path: {bk['path']}")
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
)

const base = "http://127.0.0.1:9090"
const dashboard = "http://127.0.0.1:9091"

func main() {
    jar, _ := cookiejar.New(nil)
    client := &http.Client{Jar: jar}

    // Login
    creds := map[string]string{
        "username": "admin_abc12345",
        "password": "SecurePass123",
    }
    body, _ := json.Marshal(creds)

    resp, err := client.Post(base+"/api/auth/login", "application/json",
        bytes.NewReader(body))
    if err != nil {
        panic(err)
    }
    defer resp.Body.Close()

    // Status
    resp2, _ := client.Get(base + "/api?action=status")
    defer resp2.Body.Close()
    b2, _ := io.ReadAll(resp2.Body)
    fmt.Println(string(b2))

    // Toggle (POST)
    resp3, _ := client.Post(base+"/api/toggle_service",
        "application/x-www-form-urlencoded", nil)
    defer resp3.Body.Close()
    b3, _ := io.ReadAll(resp3.Body)
    fmt.Println(string(b3))

    // Metrics
    resp4, _ := client.Get(dashboard + "/api/metrics")
    defer resp4.Body.Close()
    var metrics map[string]interface{}
    json.NewDecoder(resp4.Body).Decode(&metrics)
    fmt.Printf("Total queries: %v\n", metrics["total_queries"])

    // Runtime info (PORT-2 + MEM-1 + BAK-1)
    resp5, _ := client.Get(base + "/api?action=runtime_info")
    defer resp5.Body.Close()
    var info map[string]interface{}
    json.NewDecoder(resp5.Body).Decode(&info)
    fmt.Printf("WebUI port: %v\n", info["webui_port"])
    fmt.Printf("Dashboard port: %v\n", info["dashboard_port"])
    fmt.Printf("Profile: %v\n", info["profile_key"])
    fmt.Printf("Memory limit: %v MB\n", info["memory_limit_mb"])

    // v1.2.0 — Backup state
    if bk, ok := info["backups"].(map[string]interface{}); ok {
        fmt.Printf("Backups available: %v\n", bk["available"])
        fmt.Printf("Latest backup: %v\n", bk["last_backup_name"])
        fmt.Printf("In-flight txn: %v\n", bk["in_flight_txn"])
        fmt.Printf("Orphan txn: %v\n", bk["orphan_txn"])
    }
}
```

### 10.4 JavaScript (fetch)

```javascript
const BASE = 'http://127.0.0.1:9090';
const DASHBOARD = 'http://127.0.0.1:9091';

async function login(username, password) {
  const resp = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  return resp.json();
}

async function getStatus() {
  const resp = await fetch(`${BASE}/api?action=status`, {
    credentials: 'same-origin',
  });
  return resp.json();
}

// Toggle — POST
async function toggleService() {
  const resp = await fetch(`${BASE}/api/toggle_service`, {
    method: 'POST',
    credentials: 'same-origin',
  });
  return resp.json();
}

// Restart — POST
async function restartService() {
  const resp = await fetch(`${BASE}/api/restart_service`, {
    method: 'POST',
    credentials: 'same-origin',
  });
  return resp.json();
}

// Metrics
async function getMetrics() {
  const resp = await fetch(`${DASHBOARD}/api/metrics`, {
    credentials: 'same-origin',
  });
  return resp.json();
}

// Runtime info (PORT-2 + MEM-1 + BAK-1)
async function getRuntimeInfo() {
  const resp = await fetch(`${BASE}/api?action=runtime_info`, {
    credentials: 'same-origin',
  });
  return resp.json();
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

**Toggle GET:**

```bash
curl -i -b /tmp/cookies.txt "http://127.0.0.1:9090/api?action=toggle"
# HTTP/1.1 405 Method Not Allowed
# Allow: POST
# {"status": "error", "message": "...", "hint": "Use POST /api/toggle_service"}
```

**/readyz from LAN:**

```bash
# From another device on the LAN
curl -i "http://192.168.1.5:9091/readyz"
# HTTP/1.1 403 Forbidden
# {"error": "readyz is localhost-only"}
```

### 10.6 Backup Diagnostics (v1.2.0)

**Read the full backup state via the API:**

```bash
# Full runtime_info (includes the backups object)
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups'
```

Expected shape:

```json
{
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-26 15:00:00",
  "last_backup_name": "20260926-150000-manual",
  "last_stable": "20260926-095826-v1.2.0",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**Only the essential fields:**

```bash
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" \
  | jq '{available: .backups.available, latest: .backups.last_backup_name, last_stable: .backups.last_stable}'
```

**Detect a degraded backup layer:**

```bash
# Any non-zero txn count means the installer needs attention.
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" \
  | jq 'select(.backups.in_flight_txn > 0 or .backups.orphan_txn > 0)'
```

**Compare with `status.sh --json` (API-2 fix):**

The `backups` object has **different shapes** depending on the
source. Both describe the same reality; they differ only in the
amount of diagnostic detail they expose:

| Source | Field count | Extra fields |
|---|---:|---|
| `runtime_info` (HTTP API) | **7** | — |
| `status.sh --json` (shell) | **9** | `status`, `last_backup_age_seconds` |

The two shell-only fields are:
- **`status`** — `"ok"` \| `"empty"` \| `"missing"`. A coarse
  classification of the backup layer's health.
- **`last_backup_age_seconds`** — integer number of seconds since
  the newest snapshot. Provided so that shell scripts do not have
  to compute the delta themselves (there is no `date -r` in some
  Android shells).

Run both and compare the seven shared fields:

```bash
# API (7 fields)
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups | keys'

# Shell (9 fields)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups | keys'
```

Both paths return the same seven shared fields. If the seven
shared fields ever diverge, the `main.go` and `status.sh`
versions are out of sync — restart the WebUI (or reinstall the
module) to pick up the matching versions.

**Trigger a manual backup (on the device):**

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Run the full diagnostic report (on the device):**

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

The `--diagnose` report is human-readable and includes:
- System + module info.
- The 5 user data files with size + mtime.
- The backup listing (sorted by name).
- In-flight + orphan transaction listings.
- Recovery mode state.
- Health checks with a final ✅ / ⚠️ / ❌.

### 10.7 Recovery Mode (v1.2.0)

Recovery mode restores the last known-good configuration from
the persistent backup directory. It is intended for scenarios
where the module cannot boot normally or user data was
corrupted.

**Trigger recovery (on the device):**

```bash
# Option A — module-specific trigger
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# Option B — external trigger (survives module folder loss)
su -c "touch /data/adb/dnscrypt-recovery"
su -c "reboot"
```

On the next boot, `customize.sh` runs before normal installation
and restores the last known-good snapshot. Then it continues
with the normal install flow.

**Recovery source priority** (enforced by `customize.sh §[8a]`):

1. `$PERSISTENT_BACKUP/.last_stable` → the pointer file.
2. `$PERSISTENT_BACKUP/current/` → the live snapshot.
3. `$FOUND_SOURCE` → the in-place data (fallback).

**Verify the recovery succeeded:**

```bash
# After the reboot, check the runtime info
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups.last_stable'
```

**Inspect the recovery log:**

```bash
su -c "grep 'RECOVERY MODE' /data/local/tmp/dnscrypt_install.log"
```

**Full documentation:**
- [`docs/EMERGENCY.md`](EMERGENCY.md) — step-by-step recovery procedures.
- [`docs/BACKUP.md`](BACKUP.md) — backup system reference.
- [`docs/UPGRADE.md`](UPGRADE.md) §3.1 — the v1.1.0 → v1.2.0 upgrade path.

### 10.8 Language Preference (v1.2.0)

**The API is language-neutral.** The WebUI's bilingual toggle
(English default + Arabic) is a **client-side concern only**:

- The preference is stored in `localStorage['dnscrypt-lang']`
  (values: `"en"` or `"ar"`).
- No API endpoint accepts or returns a language identifier.
- No server-side state is involved.
- The Service Worker cache (`web/sw.js`) is language-neutral:
  it caches the HTML once, and the toggle operates on the DOM.

**Verify the client state (from the browser console):**

```javascript
// Read the current preference
localStorage.getItem('dnscrypt-lang')  // → "en" (default) or "ar"

// Read the current document state
document.documentElement.lang  // → "en" or "ar"
document.documentElement.dir   // → "ltr" or "rtl"
```

**Impact on API clients**: **None.** A script that calls the API
does not need to know or set the language. The JSON payloads are
identical regardless of the WebUI language.

---

## 11. Changelog

### v1.2.0 (2026-09-29)

**Data-preservation release — no breaking changes. All changes are additive.**

Added (API surface):

- **§6.1.7** — `runtime_info.backups` now returns **seven**
  fields: `available`, `in_flight_txn`, `orphan_txn`,
  `last_backup`, `last_backup_name`, `last_stable`, `path`
  (BAK-1).
- **§6.2.3, §6.2.4, §6.2.5, §6.2.6, §6.2.7** — five destructive
  endpoints now trigger a pre-critical backup before writing
  (BAK-2). The backup is best-effort and never blocks the
  operation.
- **§10.6** — new examples for backup diagnostics.
- **§10.7** — new examples for recovery mode.
- **§10.8** — new section documenting that the API is
  language-neutral (the WebUI toggle is client-side only).

**v1.2.0 post-audit fixes (main.go — API-8 fix):**

The v1.2.0 post-audit pass applied seven corrections to
`proxy/main.go`. They do not change the API contract, but they
fix behaviors that clients could observe:

| ID | Scope | Observable effect |
|---|---|---|
| **BUG-1** | `appendDenylist` — the pre-critical backup is performed **once**, via `saveDenylist` | One snapshot per call instead of two |
| **BUG-2** | `createAutoBackup` — stderr is no longer discarded | Failed backups are now visible in `dnscrypt_main.log` |
| **BUG-3** | `buildBackupInfo` — snapshots are sorted by directory **name**, not `mtime` | `last_backup_name` now matches `status.sh --json` and the rotation policy |
| **BUG-4** | `readLogFile` — a failed `Seek` is handled explicitly | `?action=read_log` no longer silently returns the wrong slice |
| **BUG-5** | `appendDenylist` — the response message distinguishes "rules applied" from "no changes" | See §6.2.7 |
| **BUG-6** | `main()` registers `/api/runtime_info/` (trailing slash) | See §1.3 and §6.1.7 |
| **N-1** | `USER_AGENT` derived from `BuildVersion` | Custom `-ldflags` no longer leave a stale UA |
| **N-4** | `getEntriesCount` caches `lastSize` even when count is `0` | Fewer full scans on the "no blocklist yet" state |

Changed (documentation only — no API surface change):

- **§1.1** — the language field is now bilingual (EN default +
  AR toggle). All "English-only" references were replaced with
  "English default with Arabic toggle".
- **§1.5** — new section describing the v1.2.0 changes.
- **§1.6** — the previous "What is New in v1.0.0" section
  (renumbered from §1.5).
- **§11** — this entry.
- **§12** — References now include `docs/BACKUP.md`,
  `docs/EMERGENCY.md`, and `docs/UPGRADE.md`.

Deprecated:

- None.

Removed:

- None.

Fixed:

- No API-level fixes at the contract level. All v1.2.0 fixes to
  `main.go` (listed above) are internal — the request/response
  shapes are unchanged.

Client compatibility:

- **v1.0.0 clients**: unaffected. All new fields are additive.
- **v1.1.0 clients**: unaffected. The `backups` object gained
  two fields; clients that read only the original five fields
  continue to work.
- **v1.2.0 clients**: can rely on all seven `backups` fields
  being present.
- **Order of fields**: not guaranteed. Use a JSON parser, not
  string indexing.

### v1.1.0 (2026-09-26)

**Polish release — no breaking changes. All changes are additive.**

Added:

- **§2.1** — Memory limits per profile table (MEM-1).
- **§6.1.7** — `runtime_info` returns `profile_key` and
  `memory_limit_mb`.
- **§6.1.2** — `get_profile` returns `memory_limit_mb`.
- **§6.1.14** — note that `metricsProxyHandler` uses the
  `MONITORING_UI_PORT` constant (MEM-3).

Changed (internal only — same API surface):

- `metricsProxyHandler` builds the upstream URL from the Go
  constant `MONITORING_UI_PORT` instead of the hardcoded
  string `"8080"`.
- `updateProfile` calls `applyMemoryLimit()` after a
  successful profile change (affects the value returned by
  `runtime_info.memory_limit_mb`).
- `main()` calls `applyMemoryLimit()` once at startup instead
  of using a hardcoded `debug.SetMemoryLimit(80 MB)`.

Deprecated:

- None.

Removed:

- None.

Fixed:

- No API-level fixes. (The MEM-1 / MEM-2 / MEM-3 changes close
  edge cases; they are not audit corrections. See
  docs/SECURITY.md §17.)

Client compatibility:

- **v1.0.0 clients**: unaffected. All new fields are additive.
- **v1.1.0 clients**: can rely on `profile_key` and
  `memory_limit_mb` being present.
- **Order of fields**: not guaranteed. Use a JSON parser, not
  string indexing.

### v1.0.0 (2026-09-24)

Security / correctness:

- Fixed: **Login POST-only** — `/api/auth/login` and `/api/auth/logout` reject non-POST (405 + Allow: POST) — Fix NEW-1.
- Fixed: **`/readyz` localhost-only** — rejects LAN (403) — Fix NEW-4.
- Fixed: **`shellQuote()`** — shell injection protection in `MODDIR` — Fix NEW-5.
- Fixed: **`readConfPort` range check** — [1, 65535] — Fix NEW-3.
- Fixed: **`hasEndpoint()`** — exact path matching instead of `strings.Contains` — Fix #12 + NEW-2.
- Fixed: **404 for unknown action** — instead of 200 + "unknown" — Fix #12.
- Fixed: **Basic Auth rate limiting** — 5 attempts / 15 minutes — Fix #8.
- Fixed: `metricsProxyHandler` — Prometheus → JSON — Fix #1.
- Fixed: `getSystemShell()` — fallback for Linux — Fix #2.
- Fixed: `getMonitoringAuth` — section header with comment — Fix #10.
- Fixed: `isPortOpenCached` — per-port cache — Fix #11.

State & architecture:

- Added: **`rebuildMu` mutex** — serializes `rebuildBlocklist` — RACE-1.
- Added: **`runtime_info` ports** — `webui_port` + `dashboard_port` — PORT-2.
- Added: **Auth cache (60 s)** — reduces file I/O — Fix NEW-6.
- Fixed: **Preserve settings on upgrade** — backup/restore — Fix #3.
- Fixed: `.gitignore` — `proxy/run/*` instead of `proxy/run/` — Fix #4.
- Fixed: `recordLoginAttempt` — no idle allocation.

Documentation:

- Updated: §1.2 — Port range check (NEW-3).
- Updated: §1.4 — What's New.
- Updated: §2.3 — Login POST-only (NEW-1).
- Updated: §2.5 — Logout POST-only.
- Updated: §3.3 — Basic Auth rate limiting.
- Updated: §3.5 — Auth cache.
- Updated: §4.5 — 404 errors.
- Updated: §5.1 — 404 vs 405 table.
- Updated: §6.1.7 — runtime_info ports (PORT-2).
- Updated: §6.1.14 — /api/metrics JSON schema.
- Added: §7.5–7.7 — Path variants + verification.
- Updated: §9.2 — /readyz localhost-only.
- Updated: §10.5 — Error cases.
- Updated: §12 — References.

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

### 12.2 Project Documentation

| Document | Purpose |
|---|---|
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Full architecture |
| [docs/SECURITY.md](SECURITY.md) | Audit Corrections Registry |
| [docs/DEVELOPMENT.md](DEVELOPMENT.md) | Developer guide |
| [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting |
| [docs/CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [docs/COMPATIBILITY.md](COMPATIBILITY.md) | Compatibility matrix |
| [docs/DNS_BINARIES.md](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [docs/GLOSSARY.md](GLOSSARY.md) | Glossary |
| [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) | Contributors recognition |
| [docs/ROADMAP.md](ROADMAP.md) | Roadmap |
| [docs/INSTALL.md](INSTALL.md) | Installation guide |
| [docs/UPGRADE.md](UPGRADE.md) | Upgrade guide |
| [docs/FAQ.md](FAQ.md) | FAQ |
| [docs/BACKUP.md](BACKUP.md) | Backup system reference (v1.2.0) |
| [docs/EMERGENCY.md](EMERGENCY.md) | Emergency recovery guide (v1.2.0) |
| [CHANGELOG.md](../CHANGELOG.md) | Version history |

### 12.3 v1.0.0 References

| Fix | Number | Reference |
|---|:---:|---|
| Dashboard JSON | #1 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Shell fallback | #2 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Preserve settings | #3 | [SECURITY.md](SECURITY.md) |
| `.gitignore` negation | #4 | [SECURITY.md](SECURITY.md) |
| Login POST-only | NEW-1 | [SECURITY.md](SECURITY.md) |
| `hasEndpoint` | #12 + NEW-2 | [SECURITY.md](SECURITY.md) |
| `readConfPort` range | NEW-3 | [SECURITY.md](SECURITY.md) |
| `/readyz` localhost | NEW-4 | [SECURITY.md](SECURITY.md) |
| `shellQuote` | NEW-5 | [SECURITY.md](SECURITY.md) |
| Auth cache | NEW-6 | [SECURITY.md](SECURITY.md) |
| Basic Auth rate limit | #8 | [SECURITY.md](SECURITY.md) |
| Section header comment | #10 | [SECURITY.md](SECURITY.md) |
| Per-port cache | #11 | [SECURITY.md](SECURITY.md) |
| `rebuildMu` (RACE-1) | — | [SECURITY.md](SECURITY.md) |
| `runtime_info` (PORT-2) | — | [SECURITY.md](SECURITY.md) |

### 12.4 v1.1.0 References

| Change | ID | Reference |
|---|:---:|---|
| Dynamic memory limit | MEM-1 | [SECURITY.md](SECURITY.md) §5.30.1, §14.22 |
| Extended shellQuote | MEM-2 | [SECURITY.md](SECURITY.md) §5.30.2 |
| MONITORING_UI_PORT in metrics handler | MEM-3 | [SECURITY.md](SECURITY.md) §5.30.3, §14.24 |

> **Note**: MEM-1 / MEM-2 / MEM-3 are **not** audit corrections.
> They are runtime improvements documented in SECURITY.md §17.1.
> The Audit Corrections Registry remains at #33 (last entry from
> v1.0.0). The next audit correction will be #34.

### 12.5 v1.2.0 References

| Change | ID | Reference |
|---|:---:|---|
| `runtime_info.backups` full schema (7 fields) | BAK-1 | [BACKUP.md](BACKUP.md) §8.1, [ARCHITECTURE.md](ARCHITECTURE.md) §16.7 |
| Pre-critical backup on destructive endpoints | BAK-2 | [BACKUP.md](BACKUP.md) §4.3, [ARCHITECTURE.md](ARCHITECTURE.md) §4.10 |
| Backup diagnostic examples | BAK-3 | [BACKUP.md](BACKUP.md) §8.1–§8.3, [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §7.8–§7.10 |
| Recovery mode examples | BAK-4 | [EMERGENCY.md](EMERGENCY.md) §9, [UPGRADE.md](UPGRADE.md) §3.1 |
| Post-audit fixes to `main.go` (BUG-1 .. BUG-6, N-1, N-4) | — | [ARCHITECTURE.md](ARCHITECTURE.md) §4.10.5 |

> **Note**: BAK-1 / BAK-2 / BAK-3 / BAK-4 are **not** audit
> corrections. They are data-preservation additions documented
> in [SECURITY.md](SECURITY.md) §5.31. The Audit Corrections
> Registry remains at #33.

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (v1.3.x)

---

**Last updated**: 2026-10-02
**Version**: v1.3.0
**Author**: gasciljh