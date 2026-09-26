# Architecture — DNSCrypt Smart Filter

Comprehensive architecture document explaining how the system works internally.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • Added §3.9 (Memory Limit Flow) documenting the dynamic
>     per-profile memory limit introduced by MEM-1.
>   • Added §4.9 (v1.1.0 Backend Additions) covering MEM-1,
>     MEM-2 (extended shellQuote), MEM-3 (MONITORING_UI_PORT
>     constant in metrics handler).
>   • Updated §1.2 (Architectural Principles) with three new
>     principles that emerged from the v1.1.0 changes.
>   • Updated §4.5 (Security Features) with v1.1.0 items.
>   • Updated §10 (Performance) with the actual memory limits
>     per profile and the GC overhead trade-off.
>   • Updated §11 (Trade-offs) with §11.21 (dynamic vs static
>     memory limit).
>   • Updated §16 (Metrics Abstraction) with the two new fields
>     exposed via runtime_info.
>   • Added MEM-1 / MEM-2 / MEM-3 to the Legend and the Official
>     Fix Numbers table at the bottom of the file.
>   • No structural changes — v1.1.0 is a polish release.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Main Components](#2-main-components)
3. [Data Flow](#3-data-flow)
4. [Backend Component (main.go)](#4-backend-component-maingo)
5. [Shell Scripts](#5-shell-scripts)
6. [Frontend](#6-frontend)
7. [State Management](#7-state-management)
8. [File Layout](#8-file-layout)
9. [Watchdog & Recovery](#9-watchdog--recovery)
10. [Performance](#10-performance)
11. [Trade-offs & Decisions](#11-trade-offs--decisions)
12. [Blocklist Filtering Strategy](#12-blocklist-filtering-strategy)
13. [Firewall Architecture — Custom Chains](#13-firewall-architecture--custom-chains)
14. [DNS Binaries Management](#14-dns-binaries-management)
15. [Platform Abstraction](#15-platform-abstraction)
16. [Metrics Abstraction](#16-metrics-abstraction)

---

## 1. Overview

### 1.1 Purpose

Turn an Android device into a **filtered, encrypted DNS server** without a VPN, via:

- Transparent redirection of DNS queries (port 53) → `127.0.0.1:5354`
- Full encryption (DNSCrypt / DoH)
- Ad / tracker blocking via updatable lists
- Web interface for control (EN / AR)

### 1.2 Architectural Principles

| Principle | Implementation |
|--------|---------|
| **Separation of Concerns** | Go for HTTP, Shell for OS, JS for UI |
| **Zero-Footprint** | Streaming I/O, bounded buffers, 1 MB log rotation |
| **Atomic Operations** | All writes via `.tmp` + `rename` |
| **Graceful Degradation** | Fallbacks everywhere |
| **Localhost-Only** | All servers on `127.0.0.1` (by default) |
| **Idempotent** | Running scripts twice changes nothing |
| **Bounded Concurrency** | SSE writes bounded by 30 s deadline |
| **Single Source of Truth** | `VERSION` + `module.prop` + `proxy/dnscrypt-proxy.version` |
| **Clean State** | `STATUS_FILE` = user intent |
| **Custom Chains** | iptables/ip6tables in dedicated chains |
| **DNS Version** | Single file determines dnscrypt-proxy version |
| **Delegation** | Responsibilities unified in centralized scripts |
| **Multi-Source Fallback** | 5 sources for DNS binaries |
| **SHA256 Verification** | Binary integrity check |
| **Platform-Agnostic Shell** | `getSystemShell()` works on Linux/macOS/Android |
| **Exact Endpoint Matching** | `hasEndpoint()` instead of `strings.Contains` |
| **Structured Metrics** | Prometheus → JSON in `metricsProxyHandler` |
| **Rate-Limited Auth** | Basic Auth protected by rate limiting |
| **Setting Preservation** | Backup/restore on upgrade |
| **Login POST-Only** | Closes CSRF vector on `/api/auth/login` |
| **Serialized Blocklist Rebuilds** | `rebuildMu` prevents race condition |
| **Dynamic Ports** | `runtime_info` returns actual ports |
| **Auth Cache** | 60 s TTL to reduce I/O |
| **v1.1.0 — Dynamic Memory Limit** | Per-profile soft limit via `memoryLimitForProfile()` |
| **v1.1.0 — Extended Shell Escaping** | `shellQuote()` covers `{`, `}`, `\n`, `\t` |
| **v1.1.0 — Port Constant Reuse** | `MONITORING_UI_PORT` used in every reference (no hardcoded "8080") |

### 1.3 Dependencies

| Component | Version | Purpose |
|---------|:-------:|-------|
| **Go** | 1.22 | Backend |
| **DNSCrypt-proxy** | 2.1.18 | DNS engine |
| **Magisk/KernelSU** | 20.4+ / 0.9+ | Module framework |
| **HaGeZi blocklists** | latest | Blocklists |
| **iptables/nftables** | — | DNS redirection |
| **DNS Binaries** | Level 4 | DNS binary management (5 fallback sources) |

DNSCrypt-proxy version is determined by `proxy/dnscrypt-proxy.version` — see [`DNS_BINARIES.md`](DNS_BINARIES.md).

---

## 2. Main Components

### 2.1 Overall Diagram

```text
┌─────────────────────────────────────────────────────┐
│                     Android Device (Rooted)                  │
│                                                              │
│  ┌─────────────────────────────────────────────┐    │
│  │              Magisk / KernelSU Module               │    │
│  │                                                     │    │
│  │  ┌────────────┐    ┌─────────────────────┐    │    │
│  │  │  WebUI       │    │  DNSCrypt-proxy         │    │    │
│  │  │  (Go binary) │◄──┤  (Go binary - upstream)  │   │    │
│  │  │  :9090       │    │  :5354                  │    │    │
│  │  │  :9091 Dash  │    │  :8080 monitoring_ui    │    │    │
│  │  │  (JSON conv) │    │  (Prometheus metrics)   │    │    │
│  │  │  + MEM-1     │    │                         │    │    │
│  │  └──────┬─────┘    └────────────┬────────┘    │    │
│  │          │                          │               │    │
│  │          │ HTTP/SSE                 │ DNS           │    │
│  │          │                          │               │    │
│  │  ┌──────▼─────────────────────▼──────────┐  │    │
│  │  │           Shell Scripts (BusyBox sh)          │  │    │
│  │  │  customize / service / action / status / ...  │  │    │
│  │  │  manage_firewall → Custom Chains             │  │    │
│  │  │  getSystemShell() fallback                    │  │    │
│  │  │  get_profile_memory_hint()  (v1.1.0)          │  │    │
│  │  └──────┬────────────────────┬────────────┘  │    │
│  │          │                        │                 │    │
│  │  ┌──────▼──────┐   ┌─────────▼───────────┐  │    │
│  │  │  Watchdog     │    │  iptables / nftables    │  │    │
│  │  │  (standalone) │    │  DNSCRYPT_OUT / _OUT6   │  │    │
│  │  │  reads STATUS │    │  (Custom Chains)        │  │    │
│  │  │  DNS backoff  │    │                         │  │    │
│  │  └─────────────┘    └─────────────────────┘  │    │
│  └─────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────┐    │
│  │           User Applications                         │    │
│  │  (Chrome, Games, Apps → :53 → 127.0.0.1:5354)      │    │
│  └─────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────┘
```

### 2.2 Components

| Component | Language | Responsibilities |
|---|---|---|
| **main.go** | Go | HTTP API, SSE, auth, blocklist management, Prometheus → JSON, dynamic memory limit |
| **dnscrypt-proxy** | Go (upstream) | The actual DNS engine |
| **Shell scripts** | sh | Install, launch, watchdog, firewall, memory hint |
| **index.html** | HTML+JS | Main interface |
| **dashboard.html** | HTML+JS | Monitoring dashboard |
| **sw.js** | JS | Service Worker (PWA) |

---

## 3. Data Flow

### 3.1 DNS Query (Normal Path)

```text
App → :53 (UDP/TCP)
│
▼
[iptables DNAT]  ← forces 127.0.0.1:5354
│  (via DNSCRYPT_OUT Custom Chain)
│
▼
dnscrypt-proxy :5354
│
├──► blocklist.txt (fast local check)
│      │
│      ├── blocked → reply 0.0.0.0
│      └── allowed ─┐
│                 │
▼                 ▼
[DNSCrypt/DoH] ← encryption
│
▼
Remote Resolver (Cloudflare, Quad9, ...)
│
▼
Reply → Cache → App
```

### 3.2 Blocklist Update

```text
User (WebUI) → POST /api/update_profile
│
▼
main.go
│
├──► writeProgress(5, "Connecting...")
├──► downloadWithProgress(URL, tempFile)
│      │
│      ├──► atomicWriteStream()
│      ├──► broadcastEvent("progress", "10|...")
│      └──► [SSE] → User (progress bar)
│
├──► validateBlocklist(tempFile)
│
├──► rebuildBlocklist()   ← protected by rebuildMu (RACE-1)
│      │
│      ├── rebuildMu.Lock()
│      ├── read allowlist.txt → Set
│      ├── read denylist.txt → []string
│      ├── stream blocklist.raw
│      ├── atomicWriteStream(blocklist.txt)
│      └── rebuildMu.Unlock()  (defer)
│
├──► atomicWriteFile(SELECTED_FILE, key)
├──► applyMemoryLimit(key)   ← v1.1.0: MEM-1
│
├──► stopService() / startService()
│
└──► writeProgress(100, "Protection applied")
```

### 3.3 Service Restart

```text
User → POST /api/toggle_service
│
▼
handleAPI  (hasEndpoint: exact matching)
│
├──► serviceMutex.TryLock()
│
├──► stopService()
│      ├── pkill -9 dnscrypt-proxy
│      ├── STATUS_FILE = "OFF"  ← legitimate write (user requested)
│      ├── manage_firewall 0 (Custom Chain cleanup)
│      └── ...
│
├──► startService()
│      ├── exec dnscrypt-proxy -config ...
│      ├── waitForProcessAndPort(45 s)
│      ├── settings delete global private_dns_mode
│      ├── manage_firewall 1 (Custom Chain create)
│      └── STATUS_FILE = "ON"   ← legitimate write
│
└──► broadcastEvent("status", "ON")
```

### 3.4 Dashboard Metrics

```text
┌────────────────────────────────────────────────┐
│  User Browser                                           │
│  GET http://127.0.0.1:9091/api/metrics                  │
└────────────────────┬───────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│  main.go :9091 (Dashboard Server)                        │
│  ┌────────────────────────────────────────────┐  │
│  │  metricsProxyHandler                               │  │
│  │  1. checkAuth(r)                                   │  │
│  │  2. getMonitoringAuth()  ← auth cache 60 s        │  │
│  │  3. HTTP GET http://127.0.0.1:<MONITORING_UI_PORT> │  │
│  │              /api/metrics                          │  │
│  │     (Basic Auth)                                   │  │
│  │     ← v1.1.0: uses the constant, not "8080"       │  │
│  └──────────────────┬─────────────────────────┘  │
└─────────────────────┼───────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────┐
│  dnscrypt-proxy :8080 (monitoring_ui)                   │
│  returns JSON (or Prometheus text fallback)             │
└─────────────────────┬──────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────┐
│  main.go — metricsProxyHandler (continues)              │
│  ┌───────────────────────────────────────────┐  │
│  │  4. body, _ := io.ReadAll(resp.Body)              │  │
│  │  5. if valid JSON → pass through                 │  │
│  │  6. else → parsePrometheus()                     │  │
│  │           + buildDashboardJSON()                  │  │
│  │  7. json.NewEncoder(w).Encode(...)                │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────┬──────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────┐
│  User Browser                                           │
│  JSON response with: generated_at, total_queries,       │
│  blocked_queries, cache_stats, ...                      │
└────────────────────────────────────────────────┘
```

**Fix #1 (v1.0.0)**:
- Before: `metricsProxyHandler` returned Prometheus text with `Content-Type: application/json` → `JSON.parse()` failed → Dashboard showed "Cannot fetch data".
- After: JSON detection + `parsePrometheus()` + `buildDashboardJSON()` as fallback.

### 3.5 DNS Binaries Fetch

```text
CI / Developer
│
▼
scripts/fetch_dns_binaries.sh
│
├──► read proxy/dnscrypt-proxy.version → "2.1.18"
│
├──► cache check
│      ├── ~/.cache/.../dnscrypt-proxy-arm64    ✅
│      ├── ~/.cache/.../dnscrypt-proxy-arm      ✅
│      ├── ~/.cache/.../dnscrypt-proxy-x86_64   ✅
│      └── ~/.cache/.../dnscrypt-proxy-i386     ❌
│
├──► for missing: 5 fallback sources
│      1. GitHub API       → real asset names
│      2. android_X-V.zip  → 2.1.18+ format
│      3. android-X-V.zip  → older format
│      4. android_X_V.zip  → underscore format
│      5. jsDelivr CDN     → mirror
│
├──► SHA256 verification
│
└──► save to cache + .manifest.json
```

### 3.6 Login Flow (v1.0.0 — Fix NEW-1)

```text
┌────────────────────────────────────────────────┐
│  User Browser                                           │
│  POST /api/auth/login                                   │
│  Content-Type: application/json                         │
│  Body: {"username": "admin", "password": "..."}         │
└────────────────────┬───────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────┐
│  main.go — handleAPI                                    │
│  ┌───────────────────────────────────────────┐  │
│  │  if hasEndpoint(r.URL.Path, "auth/login") {       │  │
│  │      if r.Method != http.MethodPost {             │  │
│  │          w.Header().Set("Allow", "POST")          │  │
│  │          w.WriteHeader(405)                       │  │
│  │          return                                   │  │
│  │      }                                            │  │
│  │      handleLogin(w, r)                            │  │
│  │  }                                                │  │
│  └───────────────────────────────────────────┘  │
└────────────────────┬───────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────┐
│  handleLogin()                                          │
│  ┌───────────────────────────────────────────┐  │
│  │  1. ip := getClientIP(r)  ← IPv6-safe            │  │
│  │  2. if isLockedOut(ip) → 429                     │  │
│  │  3. read credentials (POST body)                  │  │
│  │  4. subtle.ConstantTimeCompare                    │  │
│  │  5. if fail → recordLoginAttempt(ip, false)      │  │
│  │  6. if success → createSession + Set-Cookie      │  │
│  │     (no token in response — cookie-only)          │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

### 3.7 Rebuild Blocklist Concurrency (RACE-1)

```text
┌────────────────────────────────────────────────┐
│  Thread 1 (updateProfile — in goroutine)                │
│  ┌───────────────────────────────────────────┐  │
│  │  os.Rename(tempFile, RAW_BLOCKLIST_FILE)          │  │
│  │  rebuildBlocklist()                               │  │
│  │    ├── rebuildMu.Lock()                          │  │
│  │    ├── ... (I/O)                                 │  │
│  │    └── defer rebuildMu.Unlock()                  │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
                    ⚡ ⚡ ⚡
┌────────────────────────────────────────────────┐
│  Thread 2 (atomicSaveRulesInternal — HTTP handler)      │
│  ┌───────────────────────────────────────────┐  │
│  │  rulesStateMu.Lock()                              │  │
│  │  atomicWriteFile(ALLOWLIST_FILE, ...)             │  │
│  │  rebuildBlocklist()                               │  │
│  │    ├── rebuildMu.Lock()  ← waits for Thread 1    │  │
│  │    ├── ... (I/O)                                  │  │
│  │    └── defer rebuildMu.Unlock()                   │  │
│  │  currentRules = rulesStateSnapshot{...}           │  │
│  │  rulesStateMu.Unlock()                            │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

Result: `BLOCKLIST` is always consistent (no race conditions).

### 3.8 Dynamic Ports (PORT-2)

```text
┌─────────────────────────────────────────────────────┐
│  Startup (main.go)                                           │
│  ┌───────────────────────────────────────────────┐  │
│  │  serverPort = getWebUIPort()      ← from webui.conf  │   │
│  │  dashboardPort = getDashboardPort()← from webui.conf │   │
│  │  if serverPort == dashboardPort → FATAL              │   │
│  │  if serverPort == MONITORING_UI_PORT → FATAL         │   │
│  │  if dashboardPort == MONITORING_UI_PORT → FATAL      │   │
│  └───────────────────────────────────────────────┘  │
└──────────────────┬──────────────────────────────────┘
                       │
                       │ GET /api/runtime_info
                       ▼
┌──────────────────────────────────────────────────┐
│  buildRuntimeInfo()                                       │
│  ┌────────────────────────────────────────────┐  │
│  │  {                                                 │  │
│  │    "version": "...",                               │  │
│  │    "webui_port": "9090",                           │  │
│  │    "dashboard_port": "9091",                       │  │
│  │    "bind_addr": "127.0.0.1",                       │  │
│  │    "profile_key": "pro",       ← v1.1.0 (MEM-1)   │  │
│  │    "memory_limit_mb": 120,     ← v1.1.0 (MEM-1)   │  │
│  │    ...                                             │  │
│  │  }                                                 │  │
│  └────────────────────────────────────────────┘  │
└────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│  Frontend (index.html / dashboard.html)                  │
│  ┌────────────────────────────────────────────┐  │
│  │  if (data.webui_port) PORTS.webui = ...            │  │
│  │  if (data.dashboard_port) {                        │  │
│  │      PORTS.dashboard = ...                         │  │
│  │      updateDashboardLink()                         │  │
│  │  }                                                 │  │
│  │  // v1.1.0: also display profile + memory limit    │  │
│  │  riItem("riProfile", data.profile_key)             │  │
│  │  riItem("riMemoryLimit", data.memory_limit_mb)     │  │
│  └────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────┐
│  Links work with custom ports                           │
│  • Dashboard link in index.html                         │
│  • "Back to WebUI" link in dashboard.html               │
│  • LAN access (window.location.hostname)                │
│  • IPv6 support ([::1])                                 │
│  • System Info panel shows profile + memory limit       │
└────────────────────────────────────────────────┘
```

### 3.9 Memory Limit Flow (v1.1.0 — MEM-1)

```text
┌──────────────────────────────────────────────────┐
│  Startup (main.go)                                        │
│  ┌─────────────────────────────────────────────┐  │
│  │  initialProfile := readSelectedProfile()            │  │
│  │  applyMemoryLimit(initialProfile)                   │  │
│  │     ↓                                               │  │
│  │  limit := memoryLimitForProfile(profile)            │  │
│  │     light=80, normal=100, pro=120,                  │  │
│  │     proplus=160, ultimate=220 (MB)                  │  │
│  │     ↓                                               │  │
│  │  debug.SetMemoryLimit(limit)                        │  │
│  │  (Go runtime: SOFT limit → GC pressure, not OOM)   │  │
│  └─────────────────────────────────────────────┘  │
└───────────────────┬──────────────────────────────┘
                       │
                       │ user changes profile
                       ▼
┌──────────────────────────────────────────────────┐
│  POST /api/update_profile?profile=ultimate                │
│  ┌────────────────────────────────────────────┐  │
│  │  updateProfile("ultimate")                         │  │
│  │    ├── download + validate                        │  │
│  │    ├── rebuildBlocklist (with rebuildMu)          │  │
│  │    ├── atomicWriteFile(SELECTED_FILE, "ultimate") │  │
│  │    └── applyMemoryLimit("ultimate")   ← v1.1.0   │  │
│  │           ↓                                        │  │
│  │         debug.SetMemoryLimit(220 MB)               │  │
│  │         log: "memory limit adjusted: 120 → 220"   │  │
│  └────────────────────────────────────────────┘  │
└───────────────────┬──────────────────────────────┘
                       │
                       │ Shell scripts need the hint
                       ▼
┌─────────────────────────────────────────────────┐
│  functions.sh                                           │
│  ┌───────────────────────────────────────────┐  │
│  │  get_profile_memory_hint()                        │  │
│  │    → "120 MB (pro)"  /  "220 MB (ultimate)"      │  │
│  │                                                   │  │
│  │  Read-only. Does not call SetMemoryLimit.         │  │
│  │  Used by service.sh / action.sh / status.sh       │  │
│  │  for user-facing display (System Info, logs).     │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Key invariants**:

| Invariant | Where enforced |
|---|---|
| `debug.SetMemoryLimit` is called only from `main.go` | Go runtime |
| The limit is a **soft** limit (no OOM on breach) | Go runtime design |
| The limit is recomputed at startup + on every profile change | `main()` + `updateProfile()` |
| Shell scripts only **read** the hint, never set the limit | `get_profile_memory_hint()` |
| `runtime_info` exposes the effective limit for observability | `buildRuntimeInfo()` |

---

## 4. Backend Component (main.go)

### 4.1 Structure

| Section | Purpose |
|---|---|
| `[0] - [4]` | Version vars, paths, constants, types |
| `[5]` | Rules state (Atomic Rules State) + `rebuildMu` (RACE-1) |
| `[6] - [7]` | HTTP Client + Paths |
| `[8] - [13]` | Variables, Config, Logging, Atomic Writes |
| `[14]` | SSE (with Write Deadline) |
| `[15] - [17]` | Stats, Auth |
| `[18] - [19]` | Process/Port Checks + Service Lifecycle |
| `[20] - [23]` | Entries Count, Download, Domain Matching |
| `[24] - [27]` | Atomic Rules Save, Profile Management |
| `[28] - [29]` | Old Modules, Log Files |
| `[30] - [33]` | runtime_info, healthz/readyz, API, Login |
| `[34]` | serveStaticAssets (whitelist) |
| `[35]` | metricsProxyHandler |
| `[36]` | main() |

**Size**: ~3600 lines (v1.1.0).

### 4.2 API Endpoints

| Method | Path | Action | Auth | Timeout |
|---|---|---|---|---|
| GET | `/healthz` | Health check | No | 5 s |
| GET | `/readyz` | Readiness | Local-only | 5 s |
| GET | `/api?action=X` | Various actions | Yes | 15 s |
| POST | `/api/save_allowlist` | Save allowlist | Yes | 15 s |
| POST | `/api/save_denylist` | Save denylist | Yes | 15 s |
| POST | `/api/update_profile` | Update blocklist | Yes | 310 s |
| POST | `/api/toggle_service` | Toggle on/off | Yes | 60 s |
| POST | `/api/restart_service` | Restart | Yes | 60 s |
| POST | `/api/ensure_running_service` | Ensure DNS running | Partial | 60 s |
| POST | `/api/auth/login` | Login (POST-only) | No | 15 s |
| POST | `/api/auth/logout` | Logout (POST-only) | Yes | 15 s |
| GET | `/api/runtime_info` | Runtime info + ports + profile + memory | Yes | 15 s |
| GET | `/api/download_log` | Download log file | Yes | 15 s |
| GET | `/api/metrics` | Prometheus → JSON | Yes | 15 s |
| GET | `/events` | SSE stream | Yes | ∞ (30 s per flush) |

**v1.1.0 notes**:
- `runtime_info` returns two additional fields: `profile_key` and `memory_limit_mb`.
- `metricsProxyHandler` uses the `MONITORING_UI_PORT` constant, not the hardcoded string `"8080"`.

### 4.3 Concurrency Model

| Resource | Protection | Notes |
|---|---|---|
| `currentRules` | `sync.RWMutex` (`rulesStateMu`) | Atomic rules state |
| `rebuildMu` | `sync.Mutex` | Serializes rebuildBlocklist (RACE-1) |
| `sessions` | `sync.RWMutex` (`sessionsMu`) | Session map |
| `loginAttempts` | `sync.Mutex` | Rate limiting (login + Basic Auth) |
| `authCacheMu` | `sync.RWMutex` | Auth cache 60 s (NEW-6) |
| `serviceMutex` | `sync.Mutex` (`TryLock`) | Service lifecycle |
| `cachedStatus` | `sync.Mutex` | Status cache |
| `cachedCount` | `sync.Mutex` | Entries count cache |
| `sseClients` | `sync.Mutex` | SSE clients map |
| `downloadClient` | `sync.Mutex` | HTTP client cache |
| `runDirUsable` | `sync.Mutex` | Cache 30 s |
| `portCacheMap` | `sync.Mutex` | Per-port cache (Fix #11) |
| `systemShell` | `sync.Once` | Platform detection (Fix #2) |
| **`memLimitMu`** | **`sync.Mutex`** | **Memory limit state (v1.1.0 — MEM-1)** |

### 4.4 SSE Implementation

#### 4.4.1 Diagram

```text
┌──────────────────────────────────────────────────┐
│  broadcastEvent(event, data)                              │
│    ├── sseMutex.Lock()                                   │
│    ├── for each client channel:                          │
│    │   ├── select { case ch <- msg: default: }           │
│    │   └── (non-blocking)                                │
│    └── sseMutex.Unlock()                                 │
└──────────────────────────────────────────────────┘
│
│ (client channels)
▼
┌──────────────────────────────────────────────────┐
│  sseHandler(w, r)  [per-client goroutine]                 │
│    ├── rc := http.NewResponseController(w)               │
│    ├── ch := make(chan string, 100)  ← Buffered          │
│    ├── loop:                                             │
│    │   ├── select {                                      │
│    │   │   case msg := <-ch:                             │
│    │   │     rc.SetWriteDeadline(now + 30 s)  ← Deadline │
│    │   │     fmt.Fprint(w, msg)                          │
│    │   │     if err := flusher.Flush(); err != nil {     │
│    │   │       return  ← releases goroutine             │
│    │   │     }                                           │
│    │   │   case <-ticker.C:                              │
│    │   │     rc.SetWriteDeadline(now + 30 s)             │
│    │   │     fmt.Fprint(w, ": keepalive\n\n")            │
│    │   │     flusher.Flush()                             │
│    │   │   case <-r.Context().Done():                    │
│    │   │     return                                      │
│    │   │ }                                               │
│    │   └── }                                             │
│    └── }                                                 │
└──────────────────────────────────────────────────┘
```

#### 4.4.2 Why Write Deadline?

**Problem in the traditional design:**

```go
// http.Server.WriteTimeout = 0 (infinite) — to allow long SSE
fmt.Fprint(w, msg)      // ← may block if TCP buffer full
flusher.Flush()         // ← may block
```

If the client is slow (bad network, frozen browser, DoS attack):
- TCP buffer fills up
- `Fprint` / `Flush` block
- The goroutine hangs forever
- Each connection = 1 stuck goroutine + memory

**Result**: 10,000 connections = 10,000 goroutines = memory exhaustion = DoS.

**Solution**:

```go
rc := http.NewResponseController(w)
_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))  // 30 s
fmt.Fprint(w, msg)
if err := flusher.Flush(); err != nil {
    return  // ← releases the goroutine immediately
}
```

#### 4.4.3 Chosen Values

| Constant | Value | Reason |
|---|---|---|
| `SSE_WRITE_TIMEOUT` | 30 s | Enough for slow networks, short enough to prevent DoS |
| `SSE_KEEPALIVE_INTERVAL` | 15 s | Less than WriteTimeout to renew the deadline |
| `ch buffer` | 100 | Absorbs bursts without blocking the producer |

### 4.5 Security Features

- CSP + X-Frame-Options + nosniff + COOP + CORP
- Constant-time comparison (`subtle.ConstantTimeCompare`)
- `MaxBytesReader` (5 MB limit on POST)
- Session GC (every 30 min)
- Rate limiting (5 attempts / 15 min) — includes Basic Auth
- Atomic writes (`atomicWriteStream` + `fsync`)
- BIND_ADDR check (refuses 0.0.0.0 without credentials)
- Secure cookies (conditional — localhost only)
- SameSite=Lax (PWA-friendly CSRF protection)
- SSE Write Deadline (30 s — DoS protection)
- Exact endpoint matching (`hasEndpoint`)
- Login POST-only (CSRF protection)
- `/readyz` localhost-only (info leak prevention)
- `shellQuote()` (shell injection protection) — **extended in v1.1.0**
- `readConfPort` range check (1-65535)
- Auth cache 60 s (I/O reduction)
- `rebuildMu` mutex (RACE-1: BLOCKLIST consistency)
- **v1.1.0 — MEM-1**: Dynamic per-profile memory limit (prevents GC thrashing)
- **v1.1.0 — MEM-3**: `MONITORING_UI_PORT` constant in `metricsProxyHandler` (single source of truth)

### 4.6 Backend Fixes — §4.6.x

#### 4.6.1 Fix A — STATUS_FILE Semantics

**Before:**

```go
func getStatusUncached() string {
    _, found := isProcessRunning()
    if !found || !isPortOpenCached(5354) {
        atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)  // ⚠️
        return "OFF"
    }
    atomicWriteFile(STATUS_FILE, []byte("ON"), 0666)  // ⚠️
    return "ON"
}
```

**After:**

```go
func getStatusUncached() string {
    _, found := isProcessRunning()
    if !found || !isPortOpenCached(5354) {
        return "OFF"  // ← read-only!
    }
    return "ON"  // ← read-only
}
```

**Contract:**

```text
┌───────────────────────────────────────────┐
│  STATUS_FILE = "user intent"                     │
│                                                  │
│  ON  → user wants the service running           │
│  OFF → user stopped it manually                 │
│                                                  │
│  Writers:  startService() / stopService() only   │
│  Readers:  getStatus, Watchdog, status.sh        │
└───────────────────────────────────────────┘
```

#### 4.6.2 Fix B — Metrics Proxy Path

```go
// Before:
http://127.0.0.1:8080/api/metrics   // ← always 404
// After:
http://127.0.0.1:8080/api/metrics   // ← correct in dnscrypt-proxy 2.1.18
```

Note: the endpoint was later corrected to `/api/metrics` for JSON, and Prometheus text is used only as fallback. In v1.1.0, the URL is built from `MONITORING_UI_PORT`.

#### 4.6.3 Fix C — IPv6 Client IP

```go
func getClientIP(r *http.Request) string {
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return strings.Trim(r.RemoteAddr, "[]")
    }
    return host
}
```

#### 4.6.4 Fix D — Port Collision Guard

```go
const MONITORING_UI_PORT = "8080"

// in main():
if serverPort == MONITORING_UI_PORT { os.Exit(1) }
if dashboardPort == MONITORING_UI_PORT { os.Exit(1) }
```

#### 4.6.5 Fix E — Section-Restricted TOML

Read credentials from `[monitoring_ui]` only (section tracking).

### 4.7 Post-Release Fixes

#### 4.7.1 Fix G — Exact Key Matching

**Before:**

```go
if strings.HasPrefix(trimmed, "username") && strings.Contains(trimmed, "=") {
    // ⚠️ matches: username2, username_backup
}
```

**After:**

```go
eqIdx := strings.Index(trimmed, "=")
if eqIdx <= 0 { continue }
key := strings.TrimSpace(trimmed[:eqIdx])
switch key {
case "username": username = val
case "password": password = val
}
```

#### 4.7.2 Fix H — recordLoginAttempt

```go
// Before: create then delete
attempt := loginAttempts[ip]
if attempt == nil {
    attempt = &LoginAttempt{}  // ← create
    loginAttempts[ip] = attempt
}
if success {
    delete(loginAttempts, ip)  // ← immediate delete
    return
}

// After: check success first
if success {
    delete(loginAttempts, ip)
    return
}
attempt := loginAttempts[ip]
if attempt == nil { attempt = &LoginAttempt{}; loginAttempts[ip] = attempt }
```

#### 4.7.3 Fix I — isRunDirUsable (30 s cache)

```go
var (
    runDirUsableCached bool
    runDirUsableTime   time.Time
    runDirUsableMutex  sync.Mutex
)

func isRunDirUsable() bool {
    runDirUsableMutex.Lock()
    defer runDirUsableMutex.Unlock()

    if !runDirUsableTime.IsZero() && time.Since(runDirUsableTime) < RUN_DIR_USABLE_CACHE_TTL {
        return runDirUsableCached
    }

    // ... I/O ...
    runDirUsableCached = result
    runDirUsableTime = time.Now()
    return result
}
```

**Impact**: no file write/delete on every `/readyz`.

#### 4.7.4 Fix J — isPortOpen native Go

**Before**: `fork/exec` + `source functions.sh` every 3 s.
**After**: read `/proc/net/udp{,6}` directly (native Go).

#### 4.7.5 Fix K — Asset Serving

**Added 7 static files**:
- `icon-192.png`, `icon-512.png`
- `apple-touch-icon.png`
- `favicon-32x32.png`, `favicon-16x16.png`, `favicon.ico`
- `offline.html`

### 4.8 v1.0.0 Backend Fixes

#### 4.8.1 Fix M — Metrics JSON conversion (Fix #1)

**Problem**:

```go
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")  // ← lies
    resp, _ := dashboardProxyClient.Do(req)
    io.Copy(w, resp.Body)  // ← raw Prometheus text
}
```

**Solution**:

```go
// 1. parser
func parsePrometheus(text string) map[string]float64 {
    result := make(map[string]float64)
    for _, line := range strings.Split(text, "\n") {
        line = strings.TrimSpace(line)
        if line == "" || strings.HasPrefix(line, "#") {
            continue
        }
        fields := strings.Fields(line)
        if len(fields) < 2 {
            continue
        }
        name := fields[0]
        if idx := strings.IndexByte(name, '{'); idx > 0 {
            name = name[:idx]
        }
        val, err := strconv.ParseFloat(fields[1], 64)
        if err != nil {
            continue
        }
        result[name] += val
    }
    return result
}

// 2. converter
func buildDashboardJSON(prom map[string]float64) map[string]interface{} {
    totalQ := findMetric(prom,
        "dnscrypt_proxy_query_total",
        "dnscrypt_query_total",
        "dnscrypt_proxy_queries_total",
    )
    // ... cache_stats, etc.
}

// 3. handler
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
    // ...
    body, _ := io.ReadAll(resp.Body)

    // Try JSON first
    var upstream map[string]interface{}
    if err := json.Unmarshal(body, &upstream); err == nil {
        json.NewEncoder(w).Encode(upstream)
        return
    }

    // Fallback: Prometheus text
    prom := parsePrometheus(string(body))
    dashboardJSON := buildDashboardJSON(prom)
    json.NewEncoder(w).Encode(dashboardJSON)
}
```

#### 4.8.2 Fix N — getSystemShell fallback (Fix #2)

**Problem**:

```go
command := exec.CommandContext(ctx, "/system/bin/sh", "-c", cmd)
//                                  ^^^^^^^^^^^^^^^^
//                                  does not exist on Linux/macOS
```

**Solution**:

```go
var (
    systemShellOnce sync.Once
    systemShellPath string
)

func getSystemShell() string {
    systemShellOnce.Do(func() {
        candidates := []string{"/system/bin/sh", "/bin/sh", "/usr/bin/sh"}
        for _, c := range candidates {
            if _, err := os.Stat(c); err == nil {
                systemShellPath = c
                return
            }
        }
        systemShellPath = "sh"
    })
    return systemShellPath
}

func runShell(cmd string) error {
    command := exec.CommandContext(ctx, getSystemShell(), "-c", cmd)
    // ...
}
```

**Impact**: CI works on Ubuntu/macOS. Android unchanged.

#### 4.8.3 Fix O — Basic Auth Rate Limiting (Fix #8)

**Before**:

```go
func checkAuth(r *http.Request) bool {
    user, pass, ok := r.BasicAuth()
    if ok {
        userMatch := subtle.ConstantTimeCompare(...)
        passMatch := subtle.ConstantTimeCompare(...)
        if userMatch && passMatch {
            return true
        }
        // ← does not record failed attempts!
    }
    return false
}
```

**After**:

```go
func checkAuth(r *http.Request) bool {
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
        recordLoginAttempt(ip, false)  // ← records failure
    }
    return false
}
```

#### 4.8.4 Fix P — Section Header with Comment (Fix #10)

**Before**:

```go
if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
    // ⚠️ fails on [sec] # comment
}
```

**After**:

```go
if strings.HasPrefix(trimmed, "[") {
    if end := strings.Index(trimmed, "]"); end > 0 {
        section := strings.TrimSpace(trimmed[1:end])
        inSection = (section == "monitoring_ui")
        continue
    }
}
```

**Applied in 4 files**:
- `main.go` — `getMonitoringAuth`
- `functions.sh` — `read_toml_credentials`
- `watchdog.sh` — inline reading
- `customize.sh` — `[18]` verification

#### 4.8.5 Fix Q — Per-Port Cache (Fix #11)

**Before**:

```go
var (
    cachedPortStatus bool
    cachedPortTime   time.Time
    portCacheMutex   sync.Mutex
)

func isPortOpenCached(port int) bool {
    portCacheMutex.Lock()
    defer portCacheMutex.Unlock()
    if time.Since(cachedPortTime) < PORT_CACHE_TTL {
        return cachedPortStatus
    }
    cachedPortStatus = isPortOpen(port)  // ← depends on last port only
    cachedPortTime = time.Now()
    return cachedPortStatus
}
```

**After**:

```go
type portCacheEntry struct {
    open bool
    time time.Time
}

var (
    portCacheMu  sync.Mutex
    portCacheMap = make(map[int]portCacheEntry)
)

func isPortOpenCached(port int) bool {
    portCacheMu.Lock()
    defer portCacheMu.Unlock()

    if entry, ok := portCacheMap[port]; ok {
        if time.Since(entry.time) < PORT_CACHE_TTL {
            return entry.open
        }
    }

    open := isPortOpen(port)
    portCacheMap[port] = portCacheEntry{open: open, time: time.Now()}
    return open
}
```

#### 4.8.6 Fix R — Exact Endpoint Matching (Fix #12 + NEW-2)

**Before**:

```go
if strings.Contains(r.URL.Path, "update_profile") {
    // ⚠️ matches: /api/update_profile_evil
    // ⚠️ matches: /prefix/api/update_profile
}
```

**After**:

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}

if hasEndpoint(r.URL.Path, "update_profile") {
    // ✅ only /api/update_profile or /api/update_profile/
}
```

**Applied to**: 11 POST endpoints + `auth/login` + `auth/logout`.

#### 4.8.7 Fix S — Login POST-only (Fix NEW-1)

**Problem**:

```go
if strings.HasSuffix(r.URL.Path, "/auth/login") {
    handleLogin(w, r)  // ← no method check!
    return
}
```

**Solution**:

```go
if hasEndpoint(r.URL.Path, "auth/login") {
    if r.Method != http.MethodPost {
        w.Header().Set("Allow", "POST")
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    handleLogin(w, r)
    return
}
```

#### 4.8.8 Fix T — readConfPort Range Check (Fix NEW-3)

**Problem**: `PORT=0` → Go picks a random port. `PORT=99999` → silent failure.

**Solution**:

```go
func readConfPort(key, defaultPort string) string {
    defer func() { recover() }()
    val := readConfValue(key, defaultPort)
    n, err := strconv.Atoi(val)
    if err != nil || n < 1 || n > 65535 {
        return defaultPort  // fallback
    }
    return val
}
```

#### 4.8.9 Fix U — /readyz localhost-only (Fix NEW-4)

**Before**: `/readyz` exposed system details to anyone (including LAN).

**After**:

```go
func handleReadyz(w http.ResponseWriter, r *http.Request) {
    if !isLocalRequest(r) {
        w.WriteHeader(http.StatusForbidden)
        json.NewEncoder(w).Encode(map[string]string{
            "error": "readyz is localhost-only",
        })
        return
    }
    // ... checks ...
}
```

#### 4.8.10 Fix V — shellQuote injection protection (Fix NEW-5)

**Before**:

```go
cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", MODDIR, port)
//    ↑ MODDIR unquoted
```

**After**:

```go
func shellQuote(s string) string {
    for _, r := range s {
        if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
            r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
            r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
            r == '?' || r == '[' || r == ']' || r == '#' || r == '~' {
            return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
        }
    }
    return s
}

cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", shellQuote(MODDIR), port)
```

**Usages (3+)**: `isPortOpen`, `startService`, `stopService`, SIGTERM handler.

#### 4.8.11 Fix W — Auth cache 60 s (Fix NEW-6)

**Before**: `getMonitoringAuth` read `dnscrypt-proxy.toml` on **every HTTP request**.

**After**:

```go
const AUTH_CACHE_TTL = 60 * time.Second

var (
    authCacheMu   sync.RWMutex
    authCacheUser string
    authCachePass string
    authCacheTime time.Time
)

func getMonitoringAuth() (username, password string) {
    authCacheMu.RLock()
    if !authCacheTime.IsZero() && time.Since(authCacheTime) < AUTH_CACHE_TTL {
        u, p := authCacheUser, authCachePass
        authCacheMu.RUnlock()
        return u, p
    }
    authCacheMu.RUnlock()

    user, pass := readMonitoringAuthFromFile()

    authCacheMu.Lock()
    authCacheUser = user
    authCachePass = pass
    authCacheTime = time.Now()
    authCacheMu.Unlock()

    return user, pass
}

func invalidateAuthCache() {
    authCacheMu.Lock()
    authCacheUser = ""
    authCachePass = ""
    authCacheTime = time.Time{}
    authCacheMu.Unlock()
}
```

**Impact**: ~5–10 ms → ~0.05 ms per request.

#### 4.8.12 Fix X — rebuildMu mutex (RACE-1)

**Problem**: `updateProfile` (goroutine) + `atomicSaveRulesInternal` (HTTP handler) → race on BLOCKLIST.

**Solution**:

```go
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ... existing code ...
}
```

**Performance**: coarse-grained lock — no noticeable overhead (~200 ms rebuild for 100K entries).

#### 4.8.13 Fix Y — runtime_info ports (PORT-2)

**Before**: hardcoded HTML links (`127.0.0.1:9090` / `:9091`).

**After**:

```go
func buildRuntimeInfo() map[string]interface{} {
    info := map[string]interface{}{
        "version":     BuildVersion,
        // ... existing fields ...

        // PORT-2:
        "webui_port":     getWebUIPort(),
        "dashboard_port": getDashboardPort(),
    }
    return info
}
```

**Frontend** (`index.html` + `dashboard.html`):

```javascript
var PORTS = {
    webui:     '9090',
    dashboard: '9091'
};

function getDashboardUrl() {
    var hostname = window.location.hostname || '127.0.0.1';
    if (hostname.indexOf(':') !== -1 && hostname.charAt(0) !== '[') {
        hostname = '[' + hostname + ']';
    }
    var protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return protocol + '//' + hostname + ':' + PORTS.dashboard + '/';
}
```

#### 4.8.14 Fix Z — Preserve settings on upgrade (Fix #3)

**Problem**: `customize.sh` relied on `[ ! -f "$BIN_DIR/$f" ]` — fails because `unzip -o` extracts defaults first.

**Solution (backup → unzip → restore)**:

```bash
# [8b] Backup BEFORE extraction
BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
mkdir -p "$BACKUP_TMP"
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    [ -f "$_EXISTING_MODULE/proxy/$f" ] && cp -f "$_EXISTING_MODULE/proxy/$f" "$BACKUP_TMP/$f"
done

# [9] unzip -o ...

# [9c] Restore AFTER extraction
for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
    [ -f "$BACKUP_TMP/$f" ] && cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f"
done
rm -rf "$BACKUP_TMP"
```

### 4.9 v1.1.0 Backend Additions

v1.1.0 introduces three runtime improvements in `main.go`.
They are documented here (rather than as audit corrections)
because they close edge cases rather than fix known
exploitable vulnerabilities.

#### 4.9.1 MEM-1 — Dynamic Memory Limit per Profile

**Before**:

```go
// main() — top of function
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← hardcoded
```

**Problem**:
- On the `ultimate` profile, actual working set approaches or
  exceeds 200 MB during `rebuildBlocklist` and under concurrent
  load.
- With an 80 MB soft limit, the Go runtime runs GC continuously
  ("GC thrashing"). On low-RAM devices, this manifested as an
  application freeze.

**After**:

```go
const (
    MEMORY_LIMIT_LIGHT     = 80 * 1024 * 1024
    MEMORY_LIMIT_NORMAL    = 100 * 1024 * 1024
    MEMORY_LIMIT_PRO       = 120 * 1024 * 1024
    MEMORY_LIMIT_PROPLUS   = 160 * 1024 * 1024
    MEMORY_LIMIT_ULTIMATE  = 220 * 1024 * 1024
    MEMORY_LIMIT_DEFAULT   = 80 * 1024 * 1024
)

var (
    memLimitMu      sync.Mutex
    currentMemLimit int64 = MEMORY_LIMIT_DEFAULT
    currentProfile  string = "pro"
)

func readSelectedProfile() string {
    data, err := os.ReadFile(SELECTED_FILE)
    if err != nil {
        return "pro"
    }
    key := strings.TrimSpace(string(data))
    if _, ok := profiles[key]; !ok {
        return "pro"
    }
    return key
}

func memoryLimitForProfile(key string) int64 {
    switch strings.ToLower(strings.TrimSpace(key)) {
    case "light":    return MEMORY_LIMIT_LIGHT
    case "normal":   return MEMORY_LIMIT_NORMAL
    case "pro":      return MEMORY_LIMIT_PRO
    case "proplus":  return MEMORY_LIMIT_PROPLUS
    case "ultimate": return MEMORY_LIMIT_ULTIMATE
    default:         return MEMORY_LIMIT_DEFAULT
    }
}

func applyMemoryLimit(key string) {
    memLimitMu.Lock()
    defer memLimitMu.Unlock()

    limit := memoryLimitForProfile(key)
    if limit == currentMemLimit && key == currentProfile {
        return
    }

    old := debug.SetMemoryLimit(limit)
    currentMemLimit = limit
    currentProfile = key

    logWithLevel("info", fmt.Sprintf(
        "memory limit adjusted: %d MB → %d MB (profile=%s, previous runtime value=%d MB)",
        old/(1024*1024), limit/(1024*1024), key, old/(1024*1024)))
}
```

**Called from**:
- `main()` at startup (after `initPaths()`, before server startup).
- `updateProfile()` after `atomicWriteFile(SELECTED_FILE)`.

**Exposed via**:
- `runtime_info.memory_limit_mb` (integer MB).
- `runtime_info.profile_key` (string).
- Startup log line and shell-level `get_profile_memory_hint()`.

**Key properties**:

| Property | Value |
|---|---|
| Type | Soft limit (Go runtime) |
| Enforced by | `debug.SetMemoryLimit` |
| Re-applied on | Startup + every profile change |
| Shell access | Read-only hint (`get_profile_memory_hint`) |
| Observability | `runtime_info`, startup log, System Info panel |

#### 4.9.2 MEM-2 — Extended `shellQuote` Character Set

**Before (v1.0.0)**:
20 characters: `` ` ``, `"`, `'`, `$`, `` ` ``, `\`, `!`, `&`, `|`, `;`,
`(`, `)`, `<`, `>`, `*`, `?`, `[`, `]`, `#`, `~`.

**After (v1.1.0)**:
24 characters — adds `{`, `}`, `\n`, `\t`.

```go
func shellQuote(s string) string {
    for _, r := range s {
        if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
            r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
            r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
            r == '?' || r == '[' || r == ']' || r == '#' || r == '~' ||
            r == '{' || r == '}' || r == '\n' || r == '\t' {
            return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
        }
    }
    return s
}
```

**Rationale**:
- `{`, `}` — brace expansion in shells.
- `\n`, `\t` — word-splitting separators in embedded strings.
- Defense in depth; no known exploitable path existed.

#### 4.9.3 MEM-3 — `MONITORING_UI_PORT` in Metrics Handler

**Before**:

```go
req, err := http.NewRequestWithContext(r.Context(), "GET",
    "http://127.0.0.1:8080/api/metrics", nil)
//   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ hardcoded
```

**After**:

```go
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
req, err := http.NewRequestWithContext(r.Context(), "GET", monitoringURL, nil)
```

**Rationale**:
- Single source of truth for the reserved port.
- Reduces the list of files to audit if the reserved port ever changes.
- Matches the same pattern already used in `getWebUIPort()` and `getDashboardPort()`.

---

## 5. Shell Scripts

### 5.1 Roles

| Script | Role | Trigger |
|---|---|---|
| `customize.sh` | Install (+backup/restore) | Magisk install |
| `service.sh` | Start services | boot_completed |
| `post-fs-data.sh` | Emergency cleanup | early boot |
| `watchdog.sh` | Monitoring | standalone |
| `action.sh` | Open WebUI | Magisk Action |
| `status.sh` | Display status | manual |
| `uninstall.sh` | Cleanup | Magisk remove |
| `functions.sh` | Shared library | sourced |
| `build.sh` | Cross-compile | manual / CI |

### 5.2 Boot Sequence

```text
Boot → Kernel → Init (mount /data)
  │
  ▼
post-fs-data.sh  ← emergency cleanup if disabled
  │              ← Custom Chain cleanup
  │
  ▼
system_server starts
  │
  ▼
sys.boot_completed = 1
  │
  ▼
service.sh
  ├── wait for boot
  ├── wait for network
  ├── read webui.conf (with Port Guard)
  ├── log active profile + memory hint (v1.1.0)
  ├── start WebUI
  └── start Watchdog (standalone)
```

### 5.3 Watchdog Model

```text
watchdog.sh (real PID)
  │
  ├── write PID
  ├── trap TERM/INT/QUIT → cleanup
  ├── read credentials from [monitoring_ui] only
  │   (section header with comment — Fix #10)
  │
  └── loop:
        ├── sleep BACKOFF (30 s → 600 s exponential)
        ├── check disable
        ├── check WebUI → restart if needed
        └── check STATUS_FILE:
              - "ON"  → call POST /api/ensure_running_service
              - "OFF" → skip (respect user intent)
              (separate DNS_BACKOFF + reset on STATUS change)
```

**RACE-1 integration**:
- `rebuildMu` prevents overlapping rebuilds.
- Watchdog does not call `rebuildBlocklist` directly.
- Fixes are performed via `main.go` (`ensure_running_service`).

---

## 6. Frontend

### 6.1 Structure

| File | Purpose | Size |
|---|---|---|
| `index.html` | Main WebUI | ~135 KB |
| `dashboard.html` | Monitoring dashboard | ~78 KB |
| `manifest.json` | PWA manifest | ~2 KB |
| `sw.js` | Service Worker | ~20 KB |
| `offline.html` | Offline page | ~15 KB |
| `icon-192.svg` | Small icon | ~1.5 KB |
| `icon-512.svg` | Maskable icon | ~1.7 KB |
| `icon-192.png` | PWA icon | ~14 KB |
| `icon-512.png` | PWA icon | ~78 KB |
| `apple-touch-icon.png` | iOS | ~18 KB |
| `favicon-32x32.png` | favicon | ~1.4 KB |
| `favicon-16x16.png` | favicon | ~553 B |
| `favicon.ico` | favicon | ~4.7 KB |

### 6.2 State Machine (Edit Mode)

```text
      VIEW ──────[click on textarea]──────► EDIT
        ▲                                    │
        │                                    │
        │                              [Ctrl+S]
        │                                    │
        │                                    ▼
        │                              [saving...]
        │                                    │
        │                           ┌───────┴──────┐
        │                           │                │
        │                         [ok]            [error]
        │                           │                │
        │                           ▼               ▼
        └────────────────────── VIEW ◄──── ROLLBACK
```

### 6.3 PWA Features

- **Installable**: manifest + SW + icons (PNG + SVG fallback)
- **Offline**: standalone offline page (`offline.html`)
- **Update**: banner with CHECK_UPDATE
- **Shortcuts**: direct shortcut + Dashboard shortcut
- **Maskable icon**: PNG (for Android)
- **SameSite=Lax**: works from shortcuts easily
- **Favicons**: PNG + ICO for all browsers
- **iOS Support**: `apple-touch-icon.png`
- **Dynamic Ports**: links updated from `runtime_info`
- **LAN Support**: `window.location.hostname` instead of `127.0.0.1`
- **v1.1.0**: System Info panel shows `profile_key` + `memory_limit_mb`

### 6.4 Dual-Origin Limitation

```text
┌─────────────────────────────────────────────────┐
│  Architectural problem:                                  │
│                                                          │
│  • WebUI :9090  ← separate origin                       │
│  • Dashboard :9091 ← separate origin                    │
│                                                          │
│  Service Worker is limited to a single origin.           │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Practical impact:                                       │
│                                                          │
│  • PWA installed from 9090 → offline for WebUI only     │
│  • PWA installed from 9091 → offline for Dashboard only │
│  • Both = assets stored twice                            │
└─────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│  Future solution (v1.2.x):                                │
│                                                           │
│  Unify on a single port (Option A):                       │
│  • Dashboard served from the same 9090 at /dashboard      │
│  • Single origin → single SW → offline for both          │
│  • refactor main.go (mux routing)                         │
└──────────────────────────────────────────────────┘
```

---

## 7. State Management

### 7.1 Server-side State

| State | Storage | Persistence | Writer |
|---|---|---|---|
| `currentRules` | memory | rebuild from files | `atomicSaveRulesInternal` |
| `sessions` | memory | lost on restart | `createSession` / `destroySession` |
| `loginAttempts` | memory | lost on restart | `recordLoginAttempt` |
| `serverBindAddr` | memory | reassigned in main() | `main()` |
| `STATUS_FILE` | `run/dnscrypt.status` | ✓ | `startService` / `stopService` only |
| `PID_FILE` | `run/dnscrypt.pid` | ✓ | `startService` / `os.Remove` |
| `selected_profile` | `selected_profile.txt` | ✓ | `updateProfile` |
| DNS version | `proxy/dnscrypt-proxy.version` | ✓ | manual |
| `portCacheMap` | memory | lost on restart | `isPortOpenCached` |
| `systemShell` | memory (sync.Once) | lost on restart | `getSystemShell` |
| `authCache` | memory | lost on restart | `getMonitoringAuth` |
| `rebuildMu` | memory | lost on restart | `rebuildBlocklist` |
| **`currentMemLimit`** | **memory** | **recomputed at startup** | **`applyMemoryLimit` (v1.1.0)** |
| **`currentProfile`** | **memory** | **recomputed at startup** | **`applyMemoryLimit` (v1.1.0)** |

### 7.2 Client-side State

| State | Storage | Lifetime |
|---|---|---|
| Lang | localStorage | persistent |
| Drafts | localStorage | 1 hour |
| Session token | memory only (cookie-based) | tab lifetime |
| Show idle | localStorage | persistent |
| Server hashes | memory | page lifetime |
| `currentStatus` | memory | page lifetime |
| `PORTS` | memory | page lifetime (updated from runtime_info) |

### 7.3 Conflict Detection

```text
Client                          Server
  │                               │
  ├── save(content, hash_A) ────►│
  │                               │
  │                               ├── if hash_A ≠ current_hash:
  │                               │      return 409 conflict
  │◄──── 200 {hash: B} ────────┤
  │                               │
  ├── next save: hash_B          │
```

### 7.4 State Machine — STATUS_FILE

```text
┌───────────────────────────────────────────────────┐
│                                                            │
│  User Intent (STATUS_FILE)      Actual State (probe)       │
│  ─────────────────────       ────────────────────   │
│                                                            │
│  START                                ┌─── ON ────┐       │
│    │                                  │            │       │
│    ├─► startService() ──► [ON] ────►│            │       │
│    │                          ▲      │            │       │
│    │                     Watchdog     │            │       │
│    │                     restarts     │            │       │
│    │                     on crash     │            │       │
│    │                          │       │            │       │
│    │                     [ON]─┴──────│            │       │
│    │                          [crash] │            │       │
│    │                            [OFF]─┘            │       │
│    │                                               │       │
│    └─► stopService() ──► [OFF]                    │       │
│                                                    │       │
│  User stops ────────────────────► [OFF]───────┘       │
│                                                            │
└───────────────────────────────────────────────────┘
```

### 7.5 User Intent vs Actual State

```text
┌───────────────────────────────────────────────┐
│  STATUS_FILE (User Intent)                            │
│  ─────────────────────────                       │
│  • written only by startService() / stopService()     │
│  • NOT written by getStatusUncached (read-only)       │
│  • Watchdog depends on it                             │
└───────────────────────────────────────────────┘
                        ↕
┌────────────────────────────────────────────────┐
│  Actual State (probe)                                  │
│  ─────────────────────                             │
│  • isProcessRunning() + isPortOpenCached(5354)         │
│  • read from getStatusUncached()                       │
│  • used in getStatus()                                 │
└────────────────────────────────────────────────┘
```

**Difference**:
- **User Intent** may stay `ON` while **Actual State** = `OFF` (crash).
- Watchdog resolves the conflict by calling `ensure_running_service`.

---

## 8. File Layout

### 8.1 Runtime Layout

```text
/data/adb/modules/dnscrypt-proxy-webui/
├── module.prop                    # Magisk definition
├── service.sh                     # boot service
├── post-fs-data.sh                # early cleanup
├── action.sh                      # Magisk Action
├── status.sh                      # status display
├── uninstall.sh                   # cleanup
├── functions.sh                   # shared library
├── watchdog.sh                    # standalone process
├── customize.sh                   # installer
├── .module.fingerprint            # module fingerprint
├── disable                        # disable flag (optional)
│
├── web/                           # Frontend
│   ├── index.html
│   ├── dashboard.html
│   ├── manifest.json
│   ├── sw.js
│   ├── offline.html
│   ├── icon-192.svg
│   ├── icon-512.svg
│   ├── icon-192.png
│   ├── icon-512.png
│   ├── apple-touch-icon.png
│   ├── favicon-32x32.png
│   ├── favicon-16x16.png
│   └── favicon.ico
│
└── proxy/                         # Backend
    ├── dnscrypt-webui             # binary (Go)
    ├── dnscrypt-proxy             # binary (upstream)
    ├── dnscrypt-proxy.version     # (Single Source of Truth)
    ├── dnscrypt-proxy.toml        # config
    ├── webui.conf                 # config
    ├── blocklist.txt              # output
    ├── blocklist.raw              # source
    ├── allowlist.txt
    ├── denylist.txt
    ├── selected_profile.txt
    ├── blocked-ips.txt
    └── run/                       # runtime (0700)
        ├── dnscrypt.pid
        ├── webui.pid
        ├── watchdog.pid
        ├── dnscrypt.status        # ← user intent
        ├── update_progress.txt
        └── .bootstrap_cache
```

### 8.2 Repository Layout

```text
dnscrypt-proxy-webui/
├── VERSION                        # module version (v1.1.0)
├── module.prop
├── update.json
├── README.md
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── LICENSE
├── SECURITY.md
├── Makefile
│
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .pre-commit-config.yaml
├── .secrets.baseline
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── release.yml
│   │   └── codeql.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── release.md
│   └── SECURITY.md
│
├── .devcontainer/
│   ├── devcontainer.json
│   └── setup.sh
│
├── scripts/
│   ├── fetch_dns_binaries.sh
│   ├── generate-icons.sh
│   ├── package_module.sh
│   ├── release.sh
│   └── release-patch.sh
│
├── proxy/
│   ├── action.sh
│   ├── build.sh
│   ├── customize.sh
│   ├── dnscrypt-proxy.toml
│   ├── dnscrypt-proxy.version
│   ├── functions.sh
│   ├── go.mod
│   ├── main.go
│   ├── post-fs-data.sh
│   ├── service.sh
│   ├── status.sh
│   ├── uninstall.sh
│   ├── watchdog.sh
│   └── webui.conf
│
├── web/
│   ├── apple-touch-icon.png
│   ├── dashboard.html
│   ├── favicon.ico
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── icon-192.png
│   ├── icon-192.svg
│   ├── icon-512.png
│   ├── icon-512.svg
│   ├── index.html
│   ├── manifest.json
│   ├── offline.html
│   └── sw.js
│
└── docs/                          # 23 documentation files
    ├── API.md
    ├── ARCHITECTURE.md
    ├── BRANCHING.md
    ├── COMPATIBILITY.md
    ├── CONTRIBUTING.md
    ├── DEVELOPMENT.md
    ├── DNS_BINARIES.md
    ├── FAQ.md
    ├── GLOSSARY.md
    ├── HALL_OF_FAME.md
    ├── INSTALL.md
    ├── RELEASE_PROCESS.md
    ├── ROADMAP.md
    ├── SECURITY.md
    ├── TROUBLESHOOTING.md
    ├── UPGRADE.md
    └── adr/
        ├── README.md
        ├── 0001-two-branch-model.md
        ├── 0002-automated-releases.md
        ├── 0003-post-release-sync.md
        ├── 0004-unified-pr-template.md          (superseded)
        ├── 0005-release-specific-pr-template.md
        └── 0006-rename-hotfix-to-release-patch.md
```

### 8.3 Runtime Files (System)

```text
/data/local/tmp/
├── dnscrypt_main.log              # WebUI log
├── dnscrypt-query.log             # query log
├── dnscrypt-blocked.log           # blocked log
├── dnscrypt-allowed.log           # allowed log
├── dnscrypt-blocked-ips.log       # IP log
├── dnscrypt-proxy.log             # DNSCrypt log
├── dnscrypt_credentials.txt       # credentials
├── dnscrypt_install.log           # install log

~/.cache/dnscrypt-proxy-webui/
└── dns-binaries/
    ├── dnscrypt-proxy-arm64       # binary
    ├── dnscrypt-proxy-arm
    ├── dnscrypt-proxy-x86_64
    ├── dnscrypt-proxy-i386
    └── .manifest.json             # SHA256 metadata
```

---

## 9. Watchdog & Recovery

### 9.1 Responsibilities

| Service | Check | Action |
|---|---|---|
| WebUI | `is_port_open $PORT tcp` | restart if closed |
| DNS Engine | `is_port_open 5354 udp` | ensure_running API (POST) |

### 9.2 Backoff Strategy

```text
WebUI:
  Attempt 1: 30 s   ─► fail
  Attempt 2: 60 s   ─► fail
  Attempt 3: 120 s  ─► fail
  Attempt 4: 240 s  ─► fail
  Attempt 5: 480 s  ─► fail
  Attempt 6+: 600 s ─► max
              │
              └── on success → reset to 30 s

DNS:
  same logic, but independent from WebUI
  + reset on STATUS_FILE change (user intent change)
  + handle 429 (rate limit) → additional backoff
```

### 9.3 Recovery Scenarios

**Scenario 1: WebUI crashes**

```text
Watchdog → is_port_open(9090) → false
        → cleanup_webui
        → start_native_webui
        → wait 35 s
        → success → BACKOFF = 30
```

**Scenario 2: DNS Engine crashes (but user wants it ON)**

```text
Watchdog → is_port_open(5354 udp) → false
        → read STATUS_FILE:
            - "ON"  → call POST /api/ensure_running_service
            - "OFF" → skip (user intent = stopped)
```

**Scenario 3: After sudden crash**

```text
DNS Engine crashes suddenly (OOM killer, signal)
  │
  ├── STATUS_FILE stays "ON"
  │
  ▼
Watchdog reads "ON"
  │
  ▼
POST /api/ensure_running_service
  │
  ▼
main.go → startService() → DNSCRYPT_OUT recreated
  │
  ▼
DNS restored ✅
```

**Scenario 4: 429 rate limit**

```text
Watchdog → POST ensure_running
        → HTTP 429 (rate limited)
        → backoff ×2
        → retry on next iteration
```

### 9.4 State-integrity Guarantee

```text
┌─────────────────────────────────────────────────┐
│  Guarantee:                                              │
│  ─────────                                             │
│  • STATUS_FILE is never written from a read-only fn.     │
│  • Watchdog restarts after crash (reliably).             │
│  • Watchdog respects user stop.                          │
│  • Firewall state always matches STATUS_FILE.            │
│  • BLOCKLIST always consistent (after RACE-1).           │
│  • Memory limit always matches active profile (v1.1.0).  │
│                                                          │
│  Implementation:                                         │
│  ───────────────                                      │
│  • main.go: getStatusUncached read-only                  │
│  • main.go: rebuildBlocklist protected by rebuildMu      │
│  • main.go: applyMemoryLimit called on startup + change  │
│  • service.sh: STATUS_FILE = OFF only on disable         │
│  • watchdog.sh: read-only                                │
└─────────────────────────────────────────────────┘
```

---

## 10. Performance

### 10.1 Memory Profile

| State | Memory |
|---|---|
| Idle WebUI | ~15 MB |
| `rebuildBlocklist` (500K lines) | +2 MB peak |
| Download (50 MB) | +2 MB peak |
| SSE per connection | ~4 KB + 30 s max |

**v1.1.0 — Dynamic soft limit per profile**:

| Profile | Soft limit | Typical use case |
|---|---:|---|
| light | 80 MB | 1 GB RAM devices, minimal blocking |
| normal | 100 MB | 2 GB RAM devices |
| pro | 120 MB | 3 GB RAM devices (default) |
| proplus | 160 MB | 4 GB RAM devices |
| ultimate | 220 MB | 6 GB+ RAM devices, max blocking |

**Soft limit semantics**:
- `debug.SetMemoryLimit` is a **soft** limit.
- The Go runtime does not OOM when the limit is breached — it
  runs GC more aggressively instead.
- Setting the limit too low → GC overhead (CPU waste).
- Setting it too high → RAM waste.
- Hence the per-profile values.

### 10.2 CPU Profile

| Operation | Duration |
|---|---|
| `rebuildBlocklist` (100K) | ~200 ms |
| `rebuildBlocklist` (500K) | ~1 s |
| `validateBlocklist` | ~50 ms |
| Session GC | <1 ms |
| SSE broadcast | <1 ms |
| `manage_iptables` (Custom Chain) | ~50 ms |
| `getClientIP` (IPv6) | <1 µs |
| `isPortOpen` (native) | <100 µs |
| `parsePrometheus` (10 metrics) | ~50 µs |
| `buildDashboardJSON` | ~5 µs |
| `hasEndpoint` (exact match) | <100 ns |
| `getSystemShell` (cached) | <10 ns |
| `getMonitoringAuth` (cached) | ~50 ns |
| **`applyMemoryLimit` (v1.1.0)** | **~10 ns** (mutex + compare, no syscall in the common case) |
| `rebuildBlocklist` (with rebuildMu) | same values (no overhead) |

### 10.3 Disk I/O

| Operation | I/O |
|---|---|
| `atomicWriteFile` | tmp + fsync + rename |
| `atomicWriteStream` | 64 KB buffer |
| Log rotation | 1 MB threshold |
| Session GC | 30 min interval |
| `isRunDirUsable` | cache 30 s (no I/O) |
| `getMonitoringAuth` | cache 60 s (no I/O) |

### 10.4 Network

| Connection | Timeout |
|---|---|
| Download blocklist | 300 s |
| HTTP API request | 15 s |
| SSE WriteTimeout | 30 s per flush |
| SSE keepalive | 15 s |
| DNS query | 5 s |
| DNS binaries download | 30 s + retry |

### 10.5 Dashboard Metrics Pipeline

| Stage | Time |
|---|---|
| `GET /metrics` (monitoring_ui) | ~5–15 ms |
| `io.ReadAll(body)` | ~0.1 ms |
| `parsePrometheus` | ~50 µs |
| `buildDashboardJSON` | ~5 µs |
| `json.Encode` | ~20 µs |
| **Total** | **~5–15 ms** |

Note: time is dominated by the network call to monitoring_ui.

**With Auth Cache (NEW-6)**:
- Before: `getMonitoringAuth` took ~5–10 ms (file I/O).
- After: cache hit → ~0.05 ms.
- **Improvement**: ~100× faster.

---

## 11. Trade-offs & Decisions

### 11.1 Go vs Shell

| Aspect | Shell | Go | Decision |
|---|---|---|---|
| HTTP server | No | ✓ | **Go** |
| API endpoints | Hard | Easy | **Go** |
| SSE | Hard | Easy | **Go** |
| JSON | Hard | Easy | **Go** |
| File ops | Good | Better | **Go** |
| Process mgmt | ✓ | Possible | **Shell** |

### 11.2 Streaming vs Load-All

**Decision**: Streaming.
**Reason**: 500K lines × ~50 bytes = 25 MB. Load-all → 150 MB peak. Streaming → 2 MB.

### 11.3 Atomic vs Direct

**Decision**: Atomic (`tmp` + `fsync` + `rename`).
**Reason**: Crash mid-write → corrupt file. Atomic → either old or new version.

### 11.4 Watchdog: subshell vs standalone

**Decision**: standalone (`watchdog.sh` file).
**Reason**: `$$` in a subshell = parent PID (wrong). `$$` in a standalone file = real PID.

### 11.5 State: get-modify-set vs atomic

**Decision**: atomic (full lock).
**Reason**: `get → modify → set` allows lost updates. Atomic → no conflict.

### 11.6 SSE: WriteTimeout=0 vs SetWriteDeadline

**Decision**: `WriteTimeout=0` + `SetWriteDeadline(30 s)` per flush.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| WriteTimeout=0 without deadline | goroutine hangs forever (DoS) |
| WriteTimeout=30 s global | breaks SSE after 30 s (even active) |
| WriteTimeout=5 min | blocks goroutines for 5 min under DoS |
| **SetWriteDeadline per flush** | ✅ allows long connections + prevents DoS |

### 11.7 Custom Chains vs Direct OUTPUT

**Decision**: Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`).

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| DNAT + RETURN rules directly in OUTPUT | orphans when TOML changes |
| `-m comment` to identify rules | doesn't solve the problem |
| IPset | complex, not supported on all kernels |
| **Custom Chains** | ✅ mathematically guaranteed cleanup |

### 11.8 STATUS_FILE: state vs intent

**Decision**: `STATUS_FILE` = "user intent" only.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| STATUS_FILE = "process state" | loses user-intent meaning |
| Separate state file | adds complexity |
| **STATUS_FILE = "user intent" (simplified)** | ✅ single clear meaning |

### 11.9 Section-restricted TOML

**Decision**: read `[monitoring_ui]` only.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| linear scan for any username/password | fragile — any other section could be misread |
| Full TOML library | external dependency (against philosophy) |
| **manual section tracking** | ✅ lightweight, safe, no deps |

### 11.10 Single source of truth for DNS version

**Decision**: `proxy/dnscrypt-proxy.version` is the single source.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Version embedded in every script | drift in 5 files |
| Env var only | lost on CI/CD |
| JSON file | overkill (single line) |
| **plain `.version` file** | ✅ simple, readable by any tool |

### 11.11 Delegation vs Inline

**Decision**: centralized script (`fetch_dns_binaries.sh`) instead of 150+ lines inline.

### 11.12 Multi-source fallback

**Decision**: 5 sources for DNS binaries.

### 11.13 Platform-agnostic shell

**Decision**: `getSystemShell()` instead of hardcoded `/system/bin/sh`.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Hardcoded `/system/bin/sh` | fails on Linux/macOS |
| Hardcoded `/bin/sh` | fails on Android |
| `sh` via PATH lookup | may match unexpected shell |
| **candidates + sync.Once** | ✅ picks first existing + cached |

### 11.14 Prometheus → JSON vs Raw Proxy

**Decision**: convert inside `metricsProxyHandler`.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Raw proxy (as before) | Dashboard broken — `JSON.parse()` fails |
| Modify `monitoring_ui` to return JSON | impossible — dnscrypt-proxy upstream |
| Use another dnscrypt-proxy endpoint | does not exist |
| **parsePrometheus + buildDashboardJSON** | ✅ works inside main.go |

### 11.15 Exact endpoint matching

**Decision**: `hasEndpoint(path, name)` instead of `strings.Contains(path, name)`.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| `strings.Contains` | matches `/api/update_profile_evil` |
| `strings.HasPrefix(path, "/api/"+name)` | matches `/api/update_profile_evil` |
| Regex per endpoint | slow + complex |
| **`hasEndpoint` (string equality)** | ✅ faster, precise, readable |

### 11.16 Per-port cache

**Decision**: `map[int]portCacheEntry` instead of a single variable.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Single variable (as before) | wrong result when switching ports |
| Two variables (5354 + PORT) | doesn't scale to DASHBOARD_PORT |
| **map** | ✅ scales automatically, O(1) |
| LRU cache | overkill (≤3 ports) |

### 11.17 Preserve settings on upgrade

**Decision**: backup before `unzip -o` + restore after.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| migration after unzip (as before) | unzip extracts defaults first → migration fails |
| `unzip -n` (no overwrite) | doesn't update files |
| `unzip -o` with skip list | not supported in BusyBox unzip |
| **backup → unzip → restore** | ✅ guarantees preservation |

**Files preserved**:
- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

### 11.18 Login POST-only

**Decision**: `/api/auth/login` and `/api/auth/logout` POST only.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Accept GET and POST | CSRF vector via `<img src="...">` |
| SameSite=Strict | breaks PWA shortcuts |
| Separate CSRF token | adds complexity |
| **POST-only** | ✅ simple, effective, standard |

### 11.19 rebuildMu — Coarse-grained vs Fine-grained

**Decision**: single `sync.Mutex` covering `rebuildBlocklist` entirely.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| No lock (as before) | real race condition |
| Fine-grained (per file) | complex, error-prone, no real gain |
| RWMutex (multi-reader) | meaningless (rebuildBlocklist is write-only) |
| Semaphore | overkill (few callers) |
| **single Mutex (coarse-grained)** | ✅ simple, guaranteed, sufficient |

### 11.20 runtime_info ports — Coarse vs Granular

**Decision**: `buildRuntimeInfo()` returns `webui_port` + `dashboard_port` in the same response.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| Hardcoded 9090/9091 in HTML | broken with custom ports |
| JS reads webui.conf directly | impossible (server-side file) |
| Separate endpoint `/api/ports` | extra HTTP request |
| **include in runtime_info** | ✅ no extra request |
| Use `location.port` in JS | only works on same port |

### 11.21 Auth cache — Cache vs No Cache

**Decision**: cache 60 s in `getMonitoringAuth`.

**Rejected alternatives**:
| Alternative | Problem |
|---|---|
| No cache (as before) | ~5–10 ms I/O per request |
| Permanent cache | credentials change never applied |
| Cache with inotify | complex, unreliable on Android |
| **Cache 60 s** | ✅ good balance |

### 11.22 v1.1.0 — Dynamic vs Static Memory Limit

**Decision**: dynamic, per-profile soft limit
(`MEMORY_LIMIT_*` constants + `memoryLimitForProfile()`).

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep 80 MB hardcoded | `ultimate` profile triggers GC thrashing → looks like a freeze on low-RAM devices |
| Set 220 MB hardcoded for all | wastes memory on light/normal/pro profiles; no benefit on small devices |
| Env var only | not persisted; not visible to the WebUI; no compile-time check |
| Compute per request | unnecessary; profile changes are rare; extra mutex traffic |
| External config file | adds parsing complexity; no gain over the constant table |
| **Per-profile constants + re-apply on change** | ✅ simple, observable, no new deps |

**Chosen limits (MB)**:

| Profile | Limit | Reason |
|---|---:|---|
| light | 80 | 1 GB devices — bound cache and pipeline |
| normal | 100 | 2 GB devices |
| pro | 120 | 3 GB devices — good default |
| proplus | 160 | 4 GB devices |
| ultimate | 220 | 6 GB+ devices — heavy workload |

**Observability**:
- `runtime_info.memory_limit_mb` — effective limit.
- `runtime_info.profile_key` — active profile.
- Startup log line — computed limit.
- Shell hint — `get_profile_memory_hint()`.

### 11.23 v1.1.0 — Extended shellQuote vs Minimal Set

**Decision**: extend `shellQuote()` to also cover `{`, `}`, `\n`, `\t`.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep 20-char set (v1.0.0) | `{`/`}` could brace-expand; `\n`/`\t` could word-split |
| Use `printf %q` (bash) | not portable to `/system/bin/sh` |
| Base64-encode every path | breaks readability and debugging |
| Replace shell entirely with direct exec | major refactor, out of scope |
| **Extend the character set** | ✅ minimal, safe, no behavior change for clean paths |

### 11.24 v1.1.0 — Constant vs Hardcoded Reserved Port

**Decision**: use `MONITORING_UI_PORT` in `metricsProxyHandler`.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep hardcoded `"8080"` | one more place to update if the port ever changes |
| Config file for the port | overkill (single fixed value) |
| Env var | not persisted; breaks if unset |
| **Reuse the existing Go constant** | ✅ single source of truth already present |

---

## 12. Blocklist Filtering Strategy

### 12.1 Source

All filtering happens in `main.go` via `rebuildBlocklist()`.

### 12.2 Why Go and not Shell?

| Aspect | Shell (old) | Go (current) |
|---|---|---|
| Speed | O(n·m) — slow on 500K entries | O(n) — Set-based lookup |
| Memory | loads files in memory (150 MB peak) | streaming I/O (2 MB peak) |
| Atomicity | no — manual tmp_dir + mv | `atomicWriteStream` + `fsync` |
| Pollution | writes to `/data/local/tmp/*_norm.txt` | no intermediate files |
| Concurrency | unprotected | `rebuildMu` (RACE-1) |

### 12.3 Full Path

```text
User (WebUI)
    │
    ▼ POST /api/save_allowlist
handleAPI  (hasEndpoint)
    │
    ▼
atomicSaveRulesInternal
    │
    ├──► rulesStateMu.Lock()  ← full lock
    │
    ├──► atomicWriteFile(ALLOWLIST_FILE)
    │
    ├──► rebuildBlocklist()  ← actual filtering (Go)
    │       │
    │       ├── rebuildMu.Lock()  ← RACE-1
    │       ├── read allowlist.txt → map[string]struct{}
    │       ├── read denylist.txt → []string
    │       ├── stream blocklist.raw
    │       │       │
    │       │       ├── normalizeDomain(line)
    │       │       ├── isAllowedBySuffixes(norm, allowSet) → skip?
    │       │       └── write line to tmp
    │       │
    │       ├── atomicWriteStream(BLOCKLIST_FILE)  ← write + fsync + rename
    │       └── defer rebuildMu.Unlock()
    │
    ├──► currentRules = rulesStateSnapshot{...}  ← atomic update
    │
    └──► rulesStateMu.Unlock()
    │
    ▼
reloadServiceFn()  ← outside the lock
    │
    ▼
broadcastEvent("stats", ...)
```

### 12.4 Removed Shell Functions

```diff
- apply_custom_rules_only()   # 90 lines, dead code
- load_custom_rules()          # 30 lines, helper
```

Replaced by: `rebuildBlocklist()` in `main.go`.

### 12.5 Handling Large Lists

- `blocklist.raw`: 10–50 MB (downloaded from the internet)
- `blocklist.txt`: 10–50 MB (output)
- `allowlist.txt`: < 1 KB (rare)
- `denylist.txt`: < 10 KB (rare)

`rebuildBlocklist` uses `bufio.Scanner` with Buffer(64KB, 1MB).

### 12.6 Error Handling

| Error | Handling |
|---|---|
| allowlist.txt missing | treated as empty |
| denylist.txt missing | treated as empty |
| blocklist.raw missing | `rebuildBlocklist` returns error |
| atomicWriteStream fails | rollback + retry |
| reloadService fails | log warning, no rollback |
| hash conflict (409) | client retries after reload |
| concurrent conflict (RACE-1) | `rebuildMu` serializes |

### 12.7 Notes for Contributors

When adding a new filtering feature:
1. ✅ **Do** — add it in `main.go` (Go-native)
2. ❌ **Don't** — rewrite filtering logic in Shell
3. ✅ **Do** — use `atomicWriteStream` for writes
4. ✅ **Do** — keep `rulesStateMu` as the single state lock
5. ✅ **Do** — use `rebuildMu` for every `rebuildBlocklist`
6. ❌ **Don't** — use `getRulesState` → modify → `setRulesState`

---

## 13. Firewall Architecture — Custom Chains

### 13.1 Original Problem (Orphaned Rules Leak)

Before the Custom Chains change, `manage_iptables` added dynamic `RETURN` rules directly into `OUTPUT`:

```text
┌──────────────────────────────────────────────┐
│  OUTPUT (nat) — before                               │
│                                                      │
│  1. -d 127.0.0.1 -p udp --dport 53 -j RETURN  ← dyn │
│  2. -d 127.0.0.1 -p tcp --dport 53 -j RETURN  ← dyn │
│  3. -d 9.9.9.9   -p udp --dport 53 -j RETURN  ← dyn │
│  ...                                                 │
└──────────────────────────────────────────────┘
```

**Catastrophic scenario**:
| Event | Result |
|---|---|
| Day 1: TOML = [9.9.9.9, 8.8.8.8] | rules 9.9.9.9 and 8.8.8.8 |
| Day 2: TOML = [1.1.1.1] | 9.9.9.9 and 8.8.8.8 orphans ❌ |
| After 10 changes | 40+ orphan rules |

### 13.2 Solution — Custom Chains

```text
┌──────────────────────────────────────────────┐
│  OUTPUT (nat) — after                                │
│                                                      │
│  1. -p udp --dport 53 -j DNSCRYPT_OUT   ← static    │
│  2. -p tcp --dport 53 -j DNSCRYPT_OUT   ← static    │
└──────────────────────────────────────────────┘
                      │
                      │ jump
                      ▼
┌──────────────────────────────────────────────┐
│  DNSCRYPT_OUT (nat) — Custom Chain                   │
│                                                      │
│  1. -d 127.0.0.1 -j RETURN    ← dynamic (safe)      │
│  2. -d 9.9.9.9   -j RETURN    ← dynamic (safe)      │
│  3. -d 8.8.8.8   -j RETURN    ← dynamic (safe)      │
│  4. -j DNAT --to-destination 127.0.0.1:5354          │
│                                                      │
│  Cleanup: -F DNSCRYPT_OUT + -X DNSCRYPT_OUT          │
└──────────────────────────────────────────────┘
```

### 13.3 Advantages

| Feature | Detail |
|---|---|
| No orphans | `-F` + `-X` = full wipe |
| Clean OUTPUT | only two static rules |
| No comment needed | chain name is the identifier |
| idempotent | `-N` with `2>/dev/null` |
| robust to TOML change | complete rebuild |
| nftables-compatible | same philosophy |

### 13.4 Implementation Across Files

```text
┌───────────────────────────────────────────────┐
│  functions.sh                                         │
│    ├── manage_iptables()   → DNSCRYPT_OUT            │
│    ├── manage_ip6tables()  → DNSCRYPT_OUT6           │
│    ├── manage_nftables()   → dnscrypt_filter (table) │
│    ├── _legacy_cleanup_iptables()                     │
│    └── _legacy_cleanup_ip6tables()                    │
├───────────────────────────────────────────────┤
│  post-fs-data.sh → inline_firewall_cleanup()          │
│  uninstall.sh → _inline_cleanup_firewall()            │
│  customize.sh → _inline_cleanup_firewall()            │
│  main.go → startService() / stopService()             │
└───────────────────────────────────────────────┘
```

### 13.5 Legacy Cleanup (Migration)

```bash
_inline_cleanup_firewall() {
    # 1) Custom Chain cleanup
    iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
    iptables -t nat -F DNSCRYPT_OUT
    iptables -t nat -X DNSCRYPT_OUT

    # 2) Legacy cleanup (older versions)
    iptables -t nat -D OUTPUT -p udp --dport 53 \
        -j DNAT --to-destination 127.0.0.1:5354 \
        -m comment --comment "dnscrypt_smart_filter"

    for _ip in 127.0.0.1 9.9.9.9 8.8.8.8 ...; do
        iptables -t nat -D OUTPUT -d "$_ip" \
            -p udp --dport 53 -j RETURN
    done
}
```

### 13.6 Design Decisions

#### Why Custom Chains and not IPset?

| Criterion | Custom Chains | IPset |
|---|---|---|
| Compatibility | full iptables | requires `xt_set` |
| Complexity | low | medium |
| Performance | enough (< 10 IPs) | excellent for thousands |
| Cleanup | `-F` + `-X` | `ipset destroy` |
| Decision | ✅ chosen | ❌ overkill |

### 13.7 Notes for Contributors

When adding a new firewall feature:
1. ✅ **Do** — add it inside `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`.
2. ❌ **Don't** — pollute `OUTPUT` / `INPUT` / `FORWARD`.
3. ✅ **Do** — use `-A "$chain"`.
4. ❌ **Don't** — use `-I OUTPUT`.
5. ✅ **Do** — update `_inline_cleanup_firewall` in the 3 files.

**Golden rule**:
The public `OUTPUT` must always remain clean. All dynamic rules are placed and removed inside Custom Chains.

---

## 14. DNS Binaries Management

See [`DNS_BINARIES.md`](DNS_BINARIES.md) for the full document.

### 14.1 Philosophy

Before this level, the project suffered from:

| Problem | Impact |
|---|---|
| **Embedded URLs** in the code | GitHub format might change → silent failure |
| **Duplicated version** in 5 files | potential drift |
| **`i386` vs `x86`** | different names → conflict |
| **No SHA256** | no integrity check |
| **No cache** | every build = fresh download |
| **No fallback** | if GitHub fails → build fails |
| **Slow CI** | ~30 s per release |
| **No retry** | transient failure → workflow fails |

**Solution**: the Level 4 system with 7 layers of reliability.

### 14.2 Principles

| Principle | Implementation |
|---|---|
| **Single Source of Truth** | `proxy/dnscrypt-proxy.version` |
| **Delegation** | `scripts/fetch_dns_binaries.sh` |
| **Multi-Source Fallback** | 5 sequential sources |
| **SHA256 Verification** | binary integrity check |
| **Local Cache** | `~/.cache/...` |
| **Offline Mode** | build without internet |
| **Retry Logic** | `curl --retry 2` per URL + 5-source fallback |

### 14.3 Main Components

```text
┌────────────────────────────────────────────────┐
│  [1] Single Source of Truth                             │
│      proxy/dnscrypt-proxy.version → "2.1.18"           │
└────────────────────────────────────────────────┘
                     │
        ┌──────────┼───────────┬─────────────┐
        ▼           ▼             ▼              ▼
┌──────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐
│ fetch_    │  │ package_ │  │ release  │  │ ci.yml   │
│ dns_      │  │ module.sh│  │ .yml     │  │ (verify) │
│ binaries  │  │          │  │          │  │          │
│ .sh       │  │          │  │          │  │          │
└──────────┘ └─────────┘ └─────────┘ └──────────┘
```

### 14.4 Fetch Mechanism (5 sources)

| # | Source | Priority |
|:-:|---|:---:|
| 1 | GitHub API (real asset names) | 🥇 |
| 2 | `android_X-V.zip` (2.1.18+) | 🥈 |
| 3 | `android-X-V.zip` (older) | 🥉 |
| 4 | `android_X_V.zip` (underscore) | — |
| 5 | jsDelivr CDN | — |

### 14.5 Cache Structure

```text
~/.cache/dnscrypt-proxy-webui/dns-binaries/
├── dnscrypt-proxy-arm64       (binary)
├── dnscrypt-proxy-arm
├── dnscrypt-proxy-x86_64
├── dnscrypt-proxy-i386
└── .manifest.json             (SHA256 + URL + timestamp)
```

### 14.6 i386 ↔ x86 Mapping

**Architectural problem**:

| Source | Name |
|---|---|
| GitHub (dnscrypt-proxy) | `i386` |
| Staging (customize.sh) | `x86` |

**Solution**: `map_to_cache_name()` in `package_module.sh`.

### 14.7 SHA256 Verification

```text
┌────────────────────────────┐
│  On fetch:                      │
│   1. download binary            │
│   2. compute SHA256             │
│   3. save in .manifest.json     │
└────────────┬───────────────┘
               ▼
┌─────────────────────────────┐
│  On use:                         │
│   1. read SHA from manifest      │
│   2. compute actual SHA          │
│   3. compare                     │
│   ✅ → use                      │
│   ❌ → re-fetch                 │
└─────────────────────────────┘
```

### 14.8 Retry Logic

**Problem**:
- `fetch_dns_binaries.sh` may fail due to:
  - Transient GitHub API rate limit.
  - Transient network timeout.
  - Temporary CDN issue.

**Solution**:

```bash
# Two layers:
# 1) curl --retry 2 --retry-delay 1 (per URL, inside download_url)
# 2) 5-source fallback chain (in build_candidate_urls)

# Note: MAX_RETRIES=3 was removed in v1.1.0 — it was declared
# but never used. Retries are handled entirely by curl + the
# fallback chain.
```

**Retry schedule (per URL)**:
| Attempt | Delay | Total |
|:---:|---|:---:|
| 1 | — | 0 s |
| 2 | 1 s | 1 s |
| (fail) | — | next source |

### 14.9 Version Update (Single Command)

**Before:**

```bash
# edit 5 files manually
```

**After:**

```bash
# edit one file
echo "2.1.19" > proxy/dnscrypt-proxy.version
```

### 14.10 Design Decisions

#### Why a `.version` file and not `.json`?

| Format | Evaluation |
|---|---|
| `dnscrypt-proxy.version` ✅ | clear + concise |
| `dns-version.json` | overkill |
| `.dns-version` | hidden (easily forgotten) |

#### Why a standalone `fetch_dns_binaries.sh`?

| Alternative | Problem |
|---|---|
| Inline code | duplication + hard to maintain |
| Shared shell library | complexity + namespace pollution |
| **standalone script** | ✅ clear, easy to test |

#### Why 5 sources?

| Alternative | Problem |
|---|---|
| GitHub API only | fails on rate limit |
| GitHub Releases only | fails on format change |
| Cache only | fails on first build |
| **5 sequential sources** | ✅ 99.9% reliability |

### 14.11 Notes for Contributors

When editing the DNS binaries system:
1. ✅ **Do** — use `proxy/dnscrypt-proxy.version`.
2. ✅ **Do** — use `fetch_dns_binaries.sh`.
3. ✅ **Do** — use `map_to_cache_name` for i386/x86.
4. ❌ **Don't** — embed the DNS version anywhere else.
5. ❌ **Don't** — write URLs manually.
6. ❌ **Don't** — skip SHA256 verification.

**Golden rule**:
> **Never embed the DNS version anywhere — always use `proxy/dnscrypt-proxy.version`.**

---

## 15. Platform Abstraction

### 15.1 Problem

The code relied only on Android paths:

| Path | Android | Linux | macOS |
|---|:---:|:---:|:---:|
| `/system/bin/sh` | ✅ | ❌ | ❌ |
| `/bin/sh` | ⚠️ (may not exist) | ✅ | ✅ |
| `/usr/bin/sh` | ❌ | ✅ | ✅ |

### 15.2 Solution

```go
func getSystemShell() string {
    systemShellOnce.Do(func() {
        candidates := []string{"/system/bin/sh", "/bin/sh", "/usr/bin/sh"}
        for _, c := range candidates {
            if _, err := os.Stat(c); err == nil {
                systemShellPath = c
                return
            }
        }
        systemShellPath = "sh"  // PATH lookup
    })
    return systemShellPath
}
```

### 15.3 Usage

```go
func runShell(cmd string) error {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    command := exec.CommandContext(ctx, getSystemShell(), "-c", cmd)
    // ...
}
```

### 15.4 Impact

| Environment | Before | After |
|---|:---:|:---:|
| Android | ✅ | ✅ |
| Ubuntu (CI) | ❌ fails | ✅ works |
| macOS (dev) | ❌ fails | ✅ works |
| Termux | ⚠️ sometimes | ✅ works |

### 15.5 Performance

- **First call**: `os.Stat` on 3 paths → ~50 µs.
- **Subsequent**: `sync.Once` → <10 ns.
- **Total overhead**: essentially zero.

---

## 16. Metrics Abstraction

### 16.1 Problem

**Upstream incompatibility**:
- `monitoring_ui` (dnscrypt-proxy) returns **Prometheus text format**.
- `dashboard.html` expects **JSON**.
- Upstream cannot be modified.

### 16.2 Solution — Adapter Pattern

```text
┌──────────────────────────────────────────────┐
│  Client Layer                                        │
│  (dashboard.html)                                    │
│  expects: JSON                                       │
└─────────────────┬────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│  Adapter Layer                                         │
│  (metricsProxyHandler)                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  1. HTTP GET /metrics (via MONITORING_UI_PORT)  │  │
│  │  2. parsePrometheus(text) → map[string]float64 │  │
│  │  3. buildDashboardJSON(map) → map[string]any   │  │
│  │  4. json.Encode(response)                       │  │
│  └──────────────────────────────────────────┘  │
└─────────────────┬──────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────┐
│  Upstream Layer                                      │
│  (monitoring_ui :8080)                               │
│  returns: Prometheus text                            │
└──────────────────────────────────────────────┘
```

**v1.1.0 (MEM-3)**: The URL now uses the `MONITORING_UI_PORT`
constant. The behavior is unchanged, but the reserved port has
a single source of truth.

### 16.3 Multiple Metric Names Support

`findMetric(prom, name1, name2, name3)` tries all names:

```go
totalQ := findMetric(prom,
    "dnscrypt_proxy_query_total",     // ← modern form
    "dnscrypt_query_total",           // ← old form
    "dnscrypt_proxy_queries_total",   // ← variant
)
```

**Reason**: dnscrypt-proxy may change metric names between versions.

### 16.4 Label Aggregation

Prometheus supports labels:

```
dnscrypt_proxy_cache_hits_total{type="positive"} 100
dnscrypt_proxy_cache_hits_total{type="negative"} 50
```

`parsePrometheus` sums all values:

```go
result[name] += val  // 100 + 50 = 150
```

**Reason**: the Dashboard expects one number per metric.

### 16.5 Related Files

- `main.go` — `parsePrometheus`, `buildDashboardJSON`, `metricsProxyHandler`.
- `dashboard.html` — `renderDashboard(data)`.
- `docs/API.md` — `§6.1.14 /api/metrics`.

### 16.6 Performance

| Metric | Before | After |
|---|:---:|:---:|
| Content-Type | `application/json` (wrong) | `application/json; charset=utf-8` ✅ |
| Dashboard | ❌ broken | ✅ works |
| Parse time | N/A (fail) | ~50 µs (10 metrics) |
| End-to-end | N/A (fail) | ~5–15 ms |

### 16.7 v1.1.0 — Exposing Profile & Memory via runtime_info

`runtime_info` now carries two additional fields that the
Dashboard and WebUI surface in the System Info panel:

```json
{
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

**Where these come from**:

| Field | Source | Type |
|---|---|---|
| `profile_key` | `readSelectedProfile()` at startup / `currentProfile` after change | string |
| `memory_limit_mb` | `memoryLimitForProfile(currentProfile) / (1024*1024)` | int |

**Why expose them**:

- **Observability** — a user reporting GC/perf issues can paste
  the runtime_info output and the maintainer immediately knows
  which memory limit was in effect.
- **Verification** — the System Info panel in both WebUI and
  Dashboard displays the effective limit, so the user can
  compare against the expected value for their profile.
- **No extra cost** — `memory_limit_mb` is a simple integer
  division on a value already stored in memory.

**Shell equivalent**:

- `functions.sh:get_profile_memory_hint()` returns a
  human-readable string like `"120 MB (pro)"` for use by
  `service.sh`, `action.sh`, and `status.sh`.
- It is **read-only** — it does not call `debug.SetMemoryLimit`.

---

## Legend — Post-Release Fixes

| # | Description | Section |
|:-:|---|---|
| **A** | STATUS_FILE semantics | §4.6.1 |
| **B** | metricsProxyHandler /metrics | §4.6.2 |
| **C** | IPv6 client IP | §4.6.3 |
| **D** | Port Collision Guard | §4.6.4 |
| **E** | Section-restricted TOML | §4.6.5 |
| **G** | Exact key matching | §4.7.1 |
| **H** | recordLoginAttempt | §4.7.2 |
| **I** | isRunDirUsable cache | §4.7.3 |
| **J** | isPortOpen native Go | §4.7.4 |
| **K** | Asset Serving Fix | §4.7.5 |
| **M** | Metrics JSON conversion | §4.8.1 |
| **N** | getSystemShell fallback | §4.8.2 |
| **O** | Basic Auth rate limiting | §4.8.3 |
| **P** | Section header with comment | §4.8.4 |
| **Q** | Per-port cache | §4.8.5 |
| **R** | Exact endpoint matching | §4.8.6 |
| **S** | Login POST-only | §4.8.7 |
| **T** | readConfPort range check | §4.8.8 |
| **U** | /readyz localhost-only | §4.8.9 |
| **V** | shellQuote injection protection | §4.8.10 |
| **W** | Auth cache (60 s) | §4.8.11 |
| **X** | rebuildMu mutex (RACE-1) | §4.8.12 |
| **Y** | runtime_info ports (PORT-2) | §4.8.13 |
| **Z** | Preserve Settings on Upgrade | §4.8.14 |
| **MEM-1** | Dynamic memory limit per profile | §4.9.1 |
| **MEM-2** | Extended shellQuote charset | §4.9.2 |
| **MEM-3** | MONITORING_UI_PORT in metrics handler | §4.9.3 |

### Official Fix Numbers

| # | Description | Reference |
|:-:|---|---|
| **Fix #1** | Dashboard JSON Conversion | §4.8.1 |
| **Fix #2** | Shell fallback (getSystemShell) | §4.8.2 |
| **Fix #3** | Preserve Settings on Upgrade | §4.8.14 |
| **Fix #4** | `.gitignore` negation | (outside ARCHITECTURE) |
| **Fix #5** | Pre-commit hooks fixed | (outside ARCHITECTURE) |
| **Fix #6** | Asset Serving Fix | §4.7.5 (K) |
| **Fix #7** | CodeQL config drift | (outside ARCHITECTURE) |
| **Fix #8** | Basic Auth Rate Limiting | §4.8.3 |
| **Fix #9** | `fuser` PID parsing | (outside ARCHITECTURE) |
| **Fix #10** | Section header with comment | §4.8.4 |
| **Fix #11** | Per-port cache | §4.8.5 |
| **Fix #12** | Exact endpoint matching | §4.8.6 |
| **NEW-1** | Login POST-only (CSRF) | §4.8.7 |
| **NEW-2** | hasEndpoint usage | (merged in Fix #12) |
| **NEW-3** | readConfPort range check | §4.8.8 |
| **NEW-4** | /readyz localhost-only | §4.8.9 |
| **NEW-5** | shellQuote injection protection | §4.8.10 |
| **NEW-6** | Auth cache (60 s) | §4.8.11 |
| **RACE-1** | rebuildMu mutex | §4.8.12 |
| **PORT-2** | runtime_info ports | §4.8.13 |
| **MEM-1** | Dynamic memory limit per profile | §4.9.1 |
| **MEM-2** | Extended shellQuote charset | §4.9.2 |
| **MEM-3** | MONITORING_UI_PORT in metrics handler | §4.9.3 |

> **v1.1.0 note**: MEM-1 / MEM-2 / MEM-3 are not audit
> corrections — they close edge cases rather than fix known
> exploitable vulnerabilities. See `docs/SECURITY.md` §17 for
> the distinction between audit corrections and runtime
> improvements.

---

## References

- [CHANGELOG.md](../CHANGELOG.md) — version history
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/API.md](API.md) — HTTP API Reference
- [docs/DNS_BINARIES.md](DNS_BINARIES.md) — DNS binaries (Level 4)
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/ROADMAP.md](ROADMAP.md) — Roadmap
- [Effective Go](https://go.dev/doc/effective_go)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Netfilter Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [DNSCrypt Protocol Specification](https://dnscrypt.info/protocol)

---

**Last updated**: 2026-09-26
**Version**: v1.1.0
**Author**: gasciljh