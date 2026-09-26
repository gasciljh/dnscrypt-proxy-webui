# HTTP API Reference — DNSCrypt Smart Filter

Complete reference for the HTTP API used to control the module programmatically.

**Version**: v1.1.0
**Base URL (WebUI)**: `http://127.0.0.1:9090`
**Base URL (Dashboard)**: `http://127.0.0.1:9091`
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • `runtime_info` now returns two additional fields:
>     `profile_key` (string) and `memory_limit_mb` (int). See §6.1.7
>     for the full schema.
>   • `metricsProxyHandler` now builds the upstream monitoring_ui
>     URL using the `MONITORING_UI_PORT` constant instead of the
>     hardcoded string `"8080"`. The observable behavior is
>     unchanged. See §6.1.14.
>   • Added §2.1 — Memory limits per profile (v1.1.0).
>   • No breaking changes. All v1.0.0 clients continue to work.
>     The two new fields are additive.

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
│    GET  /api?action=runtime_info Build info + ports + memory │
│    GET  /api/runtime_info        Build info (path)           │
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

### 1.4 What is New in v1.1.0

| Section | Change | Reference |
|---|---|---|
| **§2.1** | Memory limits per profile (new table) | MEM-1 |
| **§6.1.7** | `runtime_info` returns `profile_key` + `memory_limit_mb` | MEM-1 |
| **§6.1.14** | `metricsProxyHandler` uses `MONITORING_UI_PORT` constant | MEM-3 |
| **§11** | Changelog entry for v1.1.0 | — |

Architectural note: the API structure is unchanged — v1.1.0 is
additive. All v1.0.0 clients continue to work without changes.

---

### 1.5 What was New in v1.0.0

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
| Secure | conditional | `true` only on localhost |
| SameSite | `Lax` | PWA-friendly |

Secure details:

- `true` if `BIND_ADDR` = 127.0.0.1 / ::1 / localhost.
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

### 3.1 Limits (v1.1.0)

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
| **Unknown action** (`?action=foo`) | **404** | `{"error": "unknown action: \"foo\""}` |
| **Disallowed method** (GET on POST endpoint) | **405** | `{"error": "This endpoint requires POST"}` + `Allow: POST` |
| **Login GET** | **405** | `{"error": "Login requires POST (CSRF protection)"}` + `Allow: POST` |
| **`/readyz` from LAN** | **403** | `{"error": "readyz is localhost-only"}` |

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

#### 6.1.7 `GET /api/runtime_info` — includes ports + profile + memory

Alternative: `GET /api?action=runtime_info` (path-based).

**Response (v1.1.0):**

```json
{
  "version": "v1.1.0",
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
  "memory_limit_mb": 120
}
```

Field groups:

| Group | Fields | Version |
|---|---|---|
| **Build info** | `version`, `commit`, `build_time`, `build_time_human`, `project_url` | v1.0.0 |
| **Runtime paths** | `run_dir`, `status_file`, `pid_file`, `progress_file`, `log_file` | v1.0.0 |
| **Network** | `bind_addr` | v1.0.0 |
| **Dynamic ports** (PORT-2) | `webui_port`, `dashboard_port` | v1.0.0 |
| **Memory profile** (MEM-1) | `profile_key`, `memory_limit_mb` | **v1.1.0** |

**`profile_key`** — one of: `light`, `normal`, `pro`, `proplus`, `ultimate`.

**`memory_limit_mb`** — the Go runtime soft limit for the active profile. See §2.1 for the mapping.

**Why these fields exist**:
- **Observability**: a user reporting a GC or performance issue can paste the JSON output.
- **Verification**: the WebUI/Dashboard System Info panel displays them.
- **Shell equivalent**: `functions.sh:get_profile_memory_hint()`.

Benefits:

- HTML/JS can update links dynamically.
- Supports LAN access (`window.location.hostname`).
- Supports IPv6 loopback (`[::1]`).

`status_file` = "user intent". Values: ON / OFF. Written only by `startService` / `stopService`. To check the actual state, use `GET /api?action=status`.

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

#### 6.2.4 `POST /api/save_allowlist`

**Request:**

```http
POST /api/save_allowlist HTTP/1.1
Content-Type: application/x-www-form-urlencoded

allowlist=googleadservices.com%0As.youtube.com&expected_hash=abc123...
```
**Params:**

- `allowlist` (required) — content (URL-encoded).
- `expected_hash` (optional) — hash from `get_custom_rules`.

**Response (200):**

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

**Response (409 conflict):**

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```

#### 6.2.5 `POST /api/save_denylist`

Same as `save_allowlist` but uses the `denylist` param.

#### 6.2.6 `POST /api/save_custom_rules`

Save both atomically.

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
  "message": "Rules saved successfully"
}
```

#### 6.2.7 `POST /api/append_denylist`

**Response:**

```json
{
  "status": "ok",
  "message": "Processed 250000 rules"
}
```

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

*Security: endpoint is exempt from auth if the request comes from `127.0.0.1` (`isLocalRequest`).*

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
const sse = new EventSource('/events', { withCredentials: true });

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
  "version": "v1.1.0",
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
  "version": "v1.1.0",
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
# After 5: 401
# After 6: 401 (locked out)
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

# Only the two new fields
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}
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

# Runtime info (PORT-2 + MEM-1)
info = s.get(f"{BASE}/api?action=runtime_info").json()
print(f"WebUI port: {info['webui_port']}")
print(f"Dashboard port: {info['dashboard_port']}")
print(f"Profile: {info['profile_key']}")
print(f"Memory limit: {info['memory_limit_mb']} MB")
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

    // Runtime info (PORT-2 + MEM-1)
    resp5, _ := client.Get(base + "/api?action=runtime_info")
    defer resp5.Body.Close()
    var info map[string]interface{}
    json.NewDecoder(resp5.Body).Decode(&info)
    fmt.Printf("WebUI port: %v\n", info["webui_port"])
    fmt.Printf("Dashboard port: %v\n", info["dashboard_port"])
    fmt.Printf("Profile: %v\n", info["profile_key"])
    fmt.Printf("Memory limit: %v MB\n", info["memory_limit_mb"])
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

// Runtime info — PORT-2 + MEM-1
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

---

## 11. Changelog

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

**Last Audit Correction**: #33 (v1.0.0)
**Next expected**: #34 (v1.2.x)

---

**Last updated**: 2026-09-26
**Version**: v1.1.0
**Author**: gasciljh