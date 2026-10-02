# Architecture — DNSCrypt Smart Filter

Comprehensive architecture document explaining how the system works internally.

**Version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     `manifest.json` `lang` field defaults to `en` and `dir` to
>     `ltr`; the toggle updates them at runtime. The user's choice
>     is persisted in `localStorage['dnscrypt-lang']`. Documentation
>     remains English-only by project convention.
>
>     **Note**: the bilingual interface has been present since
>     v1.0.0 — v1.2.0 does NOT introduce it. What v1.2.0 adds is
>     a documentation convention (English-only source comments)
>     and a clarification that the toggle is purely client-side.
>   • Added §3.10 (Backup & Restore Flow) documenting the 10
>     defensive layers introduced in v1.2.0.
>   • Added §4.10 (v1.2.0 Backend Additions) covering:
>       - BAK-1: `buildBackupInfo()` returns 7 fields
>       - BAK-2: `createAutoBackup(reason)` triggered by 5
>         destructive endpoints (4 distinct reason strings; see
>         §4.10.2)
>       - BAK-3: `cleanupOldTransactions()` preserves START/ROLLBACK
>       - BAK-4: `checkPendingNotifications()` reads and clears
>   • **§3.10 (Recovery Mode interaction)** documents the actual
>     **snapshot-and-reapply** strategy used in `customize.sh` —
>     section `[8a]` snapshots the restored files to
>     `$MODPATH/.recovery_snapshot/`, and a new section `[9b2]`
>     re-applies them **after** the `unzip` in `[9]`. This is
>     deliberately different from a "filter the unzip argument
>     list" approach. The rationale is documented inline in
>     §3.10.
>   • **Corrected in this revision**: §4.10.2 (BAK-2) now
>     documents the **actual reason string** for
>     `appendDenylist` — `"pre-denylist-save"` (via
>     `saveDenylist`) — instead of the previously incorrect
>     `"pre-append-denylist"`. `appendDenylist` delegates to
>     `saveDenylist`, which is where the pre-critical backup is
>     triggered.
>   • **§4.10.1** (`runtime_info.backups` schema) documents
>     **7 fields** (not 5):
>       `available`, `in_flight_txn`, `orphan_txn`,
>       `last_backup`, `last_backup_name`, `last_stable`,
>       `path`. This aligns `main.go`'s JSON schema with the
>     one produced by `status.sh --json` **on these 7 common
>     fields**; `status.sh --json` additionally exposes
>     `status` and `last_backup_age_seconds` (see §4.10.6).
>   • **§6.5 (Service Worker update flow)** documents the
>     banner fix in both `index.html` **and** `dashboard.html`.
>   • **§8 (File Layout)** now reflects the actual repository
>     layout:
>       - Total tracked files: **87** (not 86).
>       - `.github/` contains **12 files** (not 13): the
>         four root files, one PR template directory, three
>         issue templates, and **four** workflow files
>         (`ci.yml`, `codeql.yml`, `release.yml`,
>         `upgrade-test.yml`).
>   • **§4.3 (Concurrency Model)** updated with `backupMu` and
>     `watchdogTokMu`.
>   • **§4.4 (SSE Implementation)** — removed the misleading
>     `withCredentials` note from the client example.
>   • **§4.5 (Security Features)** updated with v1.2.0 items
>     (including the watchdog token; see §4.5.1).
>   • **§5.4–§5.6 (Shell Scripts)** updated with backup
>     helpers, the uninstall policy, and the watchdog token.
>   • **§7 (State Management)** updated with v1.2.0 runtime
>     state, including `.watchdog_token`.
>   • **§9 (Watchdog & Recovery)** — the Watchdog does
>     **not** participate in any of the 10 defensive layers.
>     It is explicitly read-only with respect to the backup
>     directory.
>   • **§10 (Performance)** updated with backup storage metrics
>     and watchdog-token lookup cost.
>   • **§11 (Trade-offs)** extended with §11.25–§11.30.
>   • **§12 (Blocklist Filtering Strategy)** updated with the
>     pre-critical backup integration and the documented
>     `append_denylist` limitation (§12.8).
>   • **§16 (Metrics Abstraction)** updated with the 7-field
>     `backups` object.
>   • Updated Legend and the Official Fix Numbers table with
>     BAK-1..BAK-4, FSH-10, FSH-11, ACT-5, WD-TOKEN.
>   • **Encoding correction (this revision)**: fixed mojibake in
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters. All symbols now render as proper UTF-8,
>     and every box diagram is aligned to a fixed interior width.
>   • No structural changes — v1.2.0 is a data-preservation
>     release, not a re-architecture.

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
- Web interface for control (bilingual: English default + Arabic toggle)
- **Persistent user-data preservation** across upgrades, renames, reinstalls, and uninstalls (v1.2.0)

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
| **Watchdog Token** | Constant-time auth for `/api/ensure_running_service` (v1.2.0) |
| **Serialized Blocklist Rebuilds** | `rebuildMu` prevents race condition |
| **Dynamic Ports** | `runtime_info` returns actual ports |
| **Auth Cache** | 60 s TTL to reduce I/O (empty results never cached) |
| **v1.1.0 — Dynamic Memory Limit** | Per-profile soft limit via `memoryLimitForProfile()` |
| **v1.1.0 — Extended Shell Escaping** | `shellQuote()` covers `{`, `}`, `\n`, `\t` |
| **v1.1.0 — Port Constant Reuse** | `MONITORING_UI_PORT` used in every reference |
| **v1.2.0 — Multi-Source Discovery** | Search for user data everywhere; never guess "is upgrade?" |
| **v1.2.0 — Persistent Backup** | `/sdcard/dnscrypt-webui-backup/` survives uninstall + `/data` reset |
| **v1.2.0 — Transactional Upgrade** | Atomic install with rollback; `txn-*` / `orphan-txn-*` |
| **v1.2.0 — Recovery Mode (snapshot-and-reapply)** | Trigger file restores last known-good config **after** the ZIP extraction step |
| **v1.2.0 — Bilingual WebUI** | English default + Arabic toggle, client-side only; documentation remains English-only |
| **v1.2.0 — Atomic `current/`** | `current/` updated via `.current.tmp.$$` + `.current.old.$$` + `mv` |
| **v1.2.0 — Unique Snapshot Names** | `<ts>-<version>-<pid>` / `<ts>-manual-<pid>` / `<ts>-auto-<pid>` |

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
┌─────────────────────────────────────────────────────────────────────┐
│                     Android Device (Rooted)                         │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Magisk / KernelSU Module                         │  │
│  │                                                               │  │
│  │  ┌────────────────────┐    ┌──────────────────────────────┐   │  │
│  │  │  WebUI             │    │  DNSCrypt-proxy              │   │  │
│  │  │  (Go binary)       │◄───┤  (Go binary - upstream)      │   │  │
│  │  │  :9090             │    │  :5354                       │   │  │
│  │  │  :9091 Dashboard   │    │  :8080 monitoring_ui         │   │  │
│  │  │  (JSON conversion) │    │  (Prometheus metrics)        │   │  │
│  │  │  + MEM-1           │    │                              │   │  │
│  │  │  + BAK-1           │    │                              │   │  │
│  │  │  + EN/AR toggle    │    │                              │   │  │
│  │  └─────────┬──────────┘    └──────────────┬───────────────┘   │  │
│  │            │                              │                   │  │
│  │            │ HTTP/SSE                     │ DNS               │  │
│  │            │                              │                   │  │
│  │  ┌─────────▼──────────────────────────────▼───────────────┐   │  │
│  │  │           Shell Scripts (BusyBox sh)                   │   │  │
│  │  │  customize / service / action / status                 │   │  │
│  │  │  manage_firewall → Custom Chains                       │   │  │
│  │  │  getSystemShell() fallback                             │   │  │
│  │  │  get_profile_memory_hint()  (v1.1.0)                   │   │  │
│  │  │  auto_backup_if_needed()    (v1.2.0)                   │   │  │
│  │  │  rotate_backups()           (v1.2.0)                   │   │  │
│  │  │  copy_with_context()        (v1.2.0)                   │   │  │
│  │  │  backup_user_files()        (v1.2.0)                   │   │  │
│  │  │  restore_user_files()       (v1.2.0)                   │   │  │
│  │  │  get_watchdog_token()       (v1.2.0)                   │   │  │
│  │  └─────────┬────────────────────────────┬─────────────────┘   │  │
│  │            │                            │                     │  │
│  │  ┌─────────▼──────────┐    ┌────────────▼───────────────┐     │  │
│  │  │  Watchdog          │    │  iptables / nftables       │     │  │
│  │  │  (standalone)      │    │  DNSCRYPT_OUT / _OUT6      │     │  │
│  │  │  reads STATUS      │    │  (Custom Chains)           │     │  │
│  │  │  DNS backoff       │    │                            │     │  │
│  │  │  uses token        │    │                            │     │  │
│  │  └────────────────────┘    └────────────────────────────┘     │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │           User Applications                                   │  │
│  │  (Chrome, Games, Apps → :53 → 127.0.0.1:5354)                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │       Persistent Backup Store (v1.2.0)                        │  │
│  │  /sdcard/dnscrypt-webui-backup/                               │  │
│  │    ├── current/                (live snapshot)                │  │
│  │    ├── <timestamp>-<version>-<pid>/                           │  │
│  │    ├── <timestamp>-manual-<pid>/                              │  │
│  │    ├── <timestamp>-auto-<pid>/                                │  │
│  │    ├── txn-*  /  orphan-txn-*  (transactions)                 │  │
│  │    ├── .last_stable            (pointer)                      │  │
│  │    ├── .last_auto_backup                                      │  │
│  │    ├── .upgrade_history.json                                  │  │
│  │    └── README.md                                              │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Components

| Component | Language | Responsibilities |
|---|---|---|
| **main.go** | Go | HTTP API, SSE, auth, blocklist management, Prometheus → JSON, dynamic memory limit, **auto-backup triggers (v1.2.0)**, **rotation after pre-critical backup (v1.2.0)**, **transaction cleanup (v1.2.0)**, **`backups` runtime_info field (v1.2.0)**, **watchdog token generation (v1.2.0)** |
| **dnscrypt-proxy** | Go (upstream) | The actual DNS engine |
| **Shell scripts** | sh | Install, launch, watchdog, firewall, memory hint, **backup/restore (v1.2.0)**, **rotation (v1.2.0)**, **recovery mode (v1.2.0)**, **SELinux context preservation (v1.2.0)**, **watchdog token reader (v1.2.0)** |
| **META-INF bootstrap** | sh | Magisk/KernelSU entry point — loads `util_functions.sh` and calls `install_module` (which runs `customize.sh`) |
| **index.html** | HTML+JS | Main interface (bilingual: EN default + AR toggle) |
| **dashboard.html** | HTML+JS | Monitoring dashboard (bilingual: EN default + AR toggle) |
| **sw.js** | JS | Service Worker (PWA), language-neutral |

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
├──► createAutoBackup("pre-profile-change")   ← v1.2.0 (BAK-2)
│      │
│      ├──► runShellWithTimeout(
│      │         ". functions.sh; ensure_backup_dir;
│      │          backup_user_files <src> <dst> &&
│      │          . functions.sh; rotate_backups 21",
│      │         15 s)
│      │
│      ├──► functions.sh:backup_user_files()
│      │      → snapshot of the 5 user config files
│      │      → /sdcard/dnscrypt-webui-backup/<ts>-manual-<pid>-<rand>/
│      │      → write .manifest.json (SHA256)
│      │
│      ├──► functions.sh:rotate_backups 21
│      │      → keep 21 newest snapshots by directory name
│      │
│      └──► (best-effort: failure logs a warning but
│             does NOT block the update)
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

**v1.2.0 note**: the pre-critical backup runs **before** any
destructive operation. It is serialized by `backupMu` (see §4.3)
so that two rapid user actions cannot trigger overlapping
backups on the same source directory. After a successful
backup, `rotate_backups 21` is invoked **in the same shell
call** to prevent unbounded accumulation. A failed backup logs
a warning but never blocks the operation.

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
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  GET http://127.0.0.1:9091/api/metrics                       │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  main.go :9091 (Dashboard Server)                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  metricsProxyHandler                                   │  │
│  │  1. checkAuth(r)                                       │  │
│  │  2. getMonitoringAuth()  ← auth cache 60 s             │  │
│  │  3. HTTP GET http://127.0.0.1:<MONITORING_UI_PORT>     │  │
│  │              /api/metrics                              │  │
│  │     (Basic Auth)                                       │  │
│  │     ← v1.1.0: uses the constant, not "8080"            │  │
│  └────────────────────────┬───────────────────────────────┘  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  dnscrypt-proxy :8080 (monitoring_ui)                        │
│  returns JSON (or Prometheus text fallback)                  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  main.go — metricsProxyHandler (continues)                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  4. body, _ := io.ReadAll(resp.Body)                   │  │
│  │  5. if valid JSON → pass through                       │  │
│  │  6. else → parsePrometheus()                           │  │
│  │           + buildDashboardJSON()                       │  │
│  │  7. json.NewEncoder(w).Encode(...)                     │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  JSON response with: generated_at, total_queries,            │
│  blocked_queries, cache_stats, ...                           │
└──────────────────────────────────────────────────────────────┘
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
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  POST /api/auth/login                                        │
│  Content-Type: application/json                              │
│  Body: {"username": "admin", "password": "..."}              │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  main.go — handleAPI                                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  if hasEndpoint(r.URL.Path, "auth/login") {            │  │
│  │      if r.Method != http.MethodPost {                  │  │
│  │          w.Header().Set("Allow", "POST")               │  │
│  │          w.WriteHeader(405)                            │  │
│  │          return                                        │  │
│  │      }                                                 │  │
│  │      handleLogin(w, r)                                 │  │
│  │  }                                                     │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  handleLogin()                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  1. ip := getClientIP(r)  ← IPv6-safe                  │  │
│  │  2. if isLockedOut(ip) → 429                           │  │
│  │  3. read credentials (POST body)                       │  │
│  │  4. subtle.ConstantTimeCompare                         │  │
│  │  5. if fail → recordLoginAttempt(ip, false)            │  │
│  │  6. if success → createSession + Set-Cookie            │  │
│  │     (no token in response — cookie-only)               │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 3.7 Rebuild Blocklist Concurrency (RACE-1)

```text
┌──────────────────────────────────────────────────────────────┐
│  Thread 1 (updateProfile — in goroutine)                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  os.Rename(tempFile, RAW_BLOCKLIST_FILE)               │  │
│  │  rebuildBlocklist()                                    │  │
│  │    ├── rebuildMu.Lock()                                │  │
│  │    ├── ... (I/O)                                       │  │
│  │    └── defer rebuildMu.Unlock()                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                            ⚡ ⚡ ⚡
┌──────────────────────────────────────────────────────────────┐
│  Thread 2 (atomicSaveRulesInternal — HTTP handler)           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  rulesStateMu.Lock()                                   │  │
│  │  atomicWriteFile(ALLOWLIST_FILE, ...)                  │  │
│  │  rebuildBlocklist()                                    │  │
│  │    ├── rebuildMu.Lock()  ← waits for Thread 1          │  │
│  │    ├── ... (I/O)                                       │  │
│  │    └── defer rebuildMu.Unlock()                        │  │
│  │  currentRules = rulesStateSnapshot{...}                │  │
│  │  rulesStateMu.Unlock()                                 │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

Result: `BLOCKLIST` is always consistent (no race conditions).

### 3.8 Dynamic Ports (PORT-2)

```text
┌──────────────────────────────────────────────────────────────┐
│  Startup (main.go)                                           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  serverPort = getWebUIPort()      ← from webui.conf    │  │
│  │  dashboardPort = getDashboardPort()← from webui.conf   │  │
│  │  if serverPort == dashboardPort → FATAL                │  │
│  │  if serverPort == MONITORING_UI_PORT → FATAL           │  │
│  │  if dashboardPort == MONITORING_UI_PORT → FATAL        │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ GET /api/runtime_info
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  buildRuntimeInfo()                                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  {                                                     │  │
│  │    "version": "...",                                   │  │
│  │    "webui_port": "9090",                               │  │
│  │    "dashboard_port": "9091",                           │  │
│  │    "bind_addr": "127.0.0.1",                           │  │
│  │    "profile_key": "pro",       ← v1.2.0 (from file)    │  │
│  │    "memory_limit_mb": 120,     ← v1.1.0 (MEM-1)        │  │
│  │    "backups": { ... }          ← v1.2.0 (BAK-1)        │  │
│  │    ...                                                 │  │
│  │  }                                                     │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Frontend (index.html / dashboard.html)                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  if (data.webui_port) PORTS.webui = ...                │  │
│  │  if (data.dashboard_port) {                            │  │
│  │      PORTS.dashboard = ...                             │  │
│  │      updateDashboardLink()                             │  │
│  │  }                                                     │  │
│  │  // v1.1.0: display profile + memory limit             │  │
│  │  riItem("riProfile", data.profile_key)                 │  │
│  │  riItem("riMemoryLimit", data.memory_limit_mb)         │  │
│  │  // v1.2.0: display backup state                       │  │
│  │  riItem("riBackupCount", bk.available)                 │  │
│  │  riItem("riBackupLatest", bk.last_backup_name)         │  │
│  │  riItem("riBackupLastStable", bk.last_stable)          │  │
│  │  riItem("riBackupInFlight", bk.in_flight_txn)          │  │
│  │  riItem("riBackupOrphan", bk.orphan_txn)               │  │
│  │  riItem("riBackupPath", bk.path)                       │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Links work with custom ports                                │
│  • Dashboard link in index.html                              │
│  • "Back to WebUI" link in dashboard.html                    │
│  • LAN access (window.location.hostname)                     │
│  • IPv6 support ([::1])                                      │
│  • System Info panel shows profile + memory + backups        │
└──────────────────────────────────────────────────────────────┘
```

### 3.9 Memory Limit Flow (v1.1.0 — MEM-1)

```text
┌──────────────────────────────────────────────────────────────┐
│  Startup (main.go)                                           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  initialProfile := readSelectedProfile()               │  │
│  │  applyMemoryLimit(initialProfile)                      │  │
│  │     ↓                                                  │  │
│  │  limit := memoryLimitForProfile(profile)               │  │
│  │     light=80, normal=100, pro=120,                     │  │
│  │     proplus=160, ultimate=220 (MB)                     │  │
│  │     ↓                                                  │  │
│  │  debug.SetMemoryLimit(limit)                           │  │
│  │  (Go runtime: SOFT limit → GC pressure, not OOM)       │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ user changes profile
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  POST /api/update_profile?profile=ultimate                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  updateProfile("ultimate")                             │  │
│  │    ├── download + validate                             │  │
│  │    ├── rebuildBlocklist (with rebuildMu)               │  │
│  │    ├── atomicWriteFile(SELECTED_FILE, "ultimate")      │  │
│  │    └── applyMemoryLimit("ultimate")   ← v1.1.0         │  │
│  │           ↓                                            │  │
│  │         debug.SetMemoryLimit(220 MB)                   │  │
│  │         log: "memory limit adjusted: 120 → 220"        │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ Shell scripts need the hint
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  functions.sh                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  get_profile_memory_hint()                             │  │
│  │    → "120 MB (pro)"  /  "220 MB (ultimate)"            │  │
│  │                                                        │  │
│  │  Read-only. Does not call SetMemoryLimit.              │  │
│  │  Used by service.sh / action.sh / status.sh            │  │
│  │  for user-facing display (System Info, logs).          │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Key invariants**:

| Invariant | Where enforced |
|---|---|
| `debug.SetMemoryLimit` is called only from `main.go` | Go runtime |
| The limit is a **soft** limit (no OOM on breach) | Go runtime design |
| The limit is recomputed at startup + on every profile change | `main()` + `updateProfile()` |
| Shell scripts only **read** the hint, never set the limit | `get_profile_memory_hint()` |
| `runtime_info` exposes the effective limit for observability | `buildRuntimeInfo()` |

### 3.10 Backup & Restore Flow (v1.2.0)

**Design philosophy**: *"Search for user data everywhere —
do not guess whether this is an upgrade."*

```text
┌──────────────────────────────────────────────────────────────────┐
│  Install / Upgrade (customize.sh)                                │
└──────────────────────────────┬───────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┬──────────────┐
              │                │                │              │
              ▼                ▼                ▼              ▼
        ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
        │ Layer 1  │    │ Layer 5  │    │ Layer 7  │    │ Layer 4  │
        │ Multi-   │    │ Root-    │    │ Recovery │    │ Txn      │
        │ source   │    │ solution │    │ mode     │    │ begin    │
        │ detect   │    │ compat   │    │ check    │    │          │
        └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘
             │               │               │               │
             └───────────────┴───────┬───────┴───────────────┘
                                     │
                                     ▼
        ┌────────────────────────────────────────────────────┐
        │  FOUND_SOURCE (≥ 3 valid files)                    │
        │  7 candidate paths on Magisk/KernelSU:             │
        │    1. $MODPATH/proxy                               │
        │    2. /data/adb/modules/dnscrypt-.../proxy         │
        │    3. /data/adb/modules/DNSCrypt-.../proxy         │
        │    4. /data/adb/modules/DNSCrypt-...WebUI/proxy    │
        │    5. $PERSISTENT_BACKUP/current                   │
        │    6. $PERSISTENT_BACKUP                           │
        │    7. /data/local/tmp/dnscrypt-webui-backup        │
        │  + 2 more on APatch (modules_update/)              │
        └────────────────────────┬───────────────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
        ┌───────────┐      ┌───────────┐      ┌───────────┐
        │ Layer 2   │      │ Layer 3   │      │ Layer 6   │
        │ Persistent│      │ Integrity │      │ SELinux   │
        │ backup    │      │ SHA256    │      │ restorecon│
        └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
              │                  │                  │
              └──────────────────┼──────────────────┘
                                 │
                                 ▼
        ┌────────────────────────────────────────────────────┐
        │  Extract ZIP (all 4 binaries + shell scripts +     │
        │  config + web assets)                              │
        │                                                    │
        │  In RECOVERY MODE:                                 │
        │   • [8a] already restored the 5 user files AND     │
        │     copied them to $MODPATH/.recovery_snapshot/    │
        │   • [9] unzips everything (this OVERWRITES         │
        │     webui.conf and dnscrypt-proxy.toml with        │
        │     defaults)                                      │
        │   • [9b2] re-applies the 5 files from the          │
        │     snapshot (see below)                           │
        └────────────────────────┬───────────────────────────┘
                                 │
                                 ▼
        ┌────────────────────────────────────────────────────┐
        │  Restore 5 user files from FOUND_SOURCE            │
        │    → proxy/webui.conf                              │
        │    → proxy/dnscrypt-proxy.toml                     │
        │    → proxy/selected_profile.txt                    │
        │    → proxy/allowlist.txt                           │
        │    → proxy/denylist.txt                            │
        │  With SELinux context + chmod 0600                 │
        └────────────────────────┬───────────────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
        ┌───────────┐      ┌───────────┐      ┌───────────┐
        │ Layer 8   │      │ Layer 9   │      │ Layer 10  │
        │ Migrate   │      │ Rotate    │      │ Log +     │
        │ config    │      │ backups   │      │ read      │
        │           │      │ (max 21)  │      │ pending   │
        └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
              │                  │                  │
              └──────────────────┼──────────────────┘
                                 │
                                 ▼
        ┌────────────────────────────────────────────────────┐
        │  COMMIT transaction → remove txn dir               │
        │  Write .last_stable pointer                        │
        │  Write .upgrade_history.json (or .txt)             │
        └────────────────────────────────────────────────────┘
```

**Recovery-mode interaction (v1.2.0 implementation)**:

`customize.sh` uses a **snapshot-and-reapply** strategy when a
recovery trigger is present (`$MODPATH/recovery` or
`/data/adb/dnscrypt-recovery`):

| Phase | Section | Purpose |
|---|---|---|
| **A** | `[8a]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **and** also copy them to `$MODPATH/.recovery_snapshot/` |
| **B** | `[9]` | Extract `proxy/*` from the ZIP — this overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's default copies |
| **C** | `[9b]` | Move root-level web assets into `web/` |
| **D** | `[9b2]` | Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/` |
| **E** | `[9c]` | Skipped when `RECOVERY_MODE=1` (already handled) |

**The v1.1.0 bug**:
Phase B (`unzip -o 'proxy/*'`) overwrote `webui.conf` and
`dnscrypt-proxy.toml` with the ZIP's defaults, and Phase E was
skipped because `RECOVERY_MODE=1`. Result: two of the five
restored files were silently lost.

**The v1.2.0 fix**:
Rather than excluding the two files from the `unzip` argument
list (which would require knowing exactly what the ZIP
contains), `[8a]` now also saves a copy of each restored file
to `$MODPATH/.recovery_snapshot/`. Section `[9b2]` then
re-applies these files after the extraction.

**Why this approach is preferred over filtering the unzip
argument list**:
- It does **not** depend on knowing what the ZIP contains.
  If a future release adds or removes files under `proxy/`,
  the fix keeps working.
- It keeps the extraction logic of `[9]` untouched, so the
  normal-install path is byte-for-byte identical to the
  pre-recovery behavior.
- The snapshot dir is `$MODPATH/.recovery_snapshot/` (dot-
  prefixed, cleaned up in `[9b2]`) so it never appears in
  the final module layout.

**CSH-5 behavior**: If re-application is partial (i.e. fewer
files were re-applied than were snapshotted), the snapshot
directory is **preserved** at `$MODPATH/.recovery_snapshot/`
so the user can recover the remaining files manually.

**Idempotency**: the entire install is idempotent.

---

## 4. Backend Component (main.go)

### 4.1 Structure

| Section | Purpose |
|---|---|
| `[0] - [4]` | Version vars, paths, constants, types |
| `[5]` | Rules state + `rebuildMu` (RACE-1) |
| `[6] - [7]` | HTTP Client + Paths |
| `[8] - [13]` | Variables, Config, Logging, Atomic Writes |
| `[14]` | SSE (with Write Deadline) |
| `[15] - [17]` | Stats, Auth (Basic/Bearer/Cookie/Watchdog Token) |
| `[18] - [19]` | Process/Port Checks + Service Lifecycle |
| `[20] - [23]` | Entries Count, Download, Domain Matching |
| `[24] - [27]` | Atomic Rules Save, Profile Management |
| `[28] - [29]` | Old Modules, Log Files |
| `[30] - [33]` | runtime_info, healthz/readyz, API, Login |
| `[34]` | serveStaticAssets (whitelist) |
| `[35]` | metricsProxyHandler |
| `[36b]` | **Auto-backup + rotation + notifications (v1.2.0)** |
| `[36c]` | **Transaction cleanup at startup (v1.2.0)** |
| `[37]` | main() |

**Size**: ~2,400 lines (v1.2.0).

### 4.2 API Endpoints

| Method | Path | Action | Auth | Timeout |
|---|---|---|---|---|
| GET | `/healthz` | Health check | No | 5 s |
| GET | `/readyz` | Readiness | Local-only | 5 s |
| GET | `/api?action=X` | Various actions | Yes | 15 s |
| POST | `/api/save_allowlist` | Save allowlist (+ backup + rotate) | Yes | 15 s |
| POST | `/api/save_denylist` | Save denylist (+ backup + rotate) | Yes | 15 s |
| POST | `/api/update_profile` | Update blocklist (+ backup + rotate) | Yes | 310 s |
| POST | `/api/save_custom_rules` | Save both (+ backup + rotate) | Yes | 15 s |
| POST | `/api/append_denylist` | Append to denylist — **requires `content` param** (triggers a backup via `saveDenylist`) | Yes | 15 s |
| POST | `/api/toggle_service` | Toggle on/off | Yes | 60 s |
| POST | `/api/restart_service` | Restart | Yes | 60 s |
| POST | `/api/ensure_running_service` | Ensure DNS running | Watchdog token (localhost) or normal auth | 60 s |
| POST | `/api/auth/login` | Login (POST-only) | No | 15 s |
| POST | `/api/auth/logout` | Logout (POST-only) | Yes | 15 s |
| GET | `/api/runtime_info` | Build + ports + profile + memory + backups | Yes | 15 s |
| GET | `/api/download_log` | Download log file | Yes | 15 s |
| GET | `/api/metrics` | Prometheus → JSON | Yes | 15 s |
| GET | `/events` | SSE stream | Yes | ∞ (30 s per flush) |

### 4.3 Concurrency Model

| Resource | Protection | Notes |
|---|---|---|
| `currentRules` | `sync.RWMutex` (`rulesStateMu`) | Atomic rules state |
| `rebuildMu` | `sync.Mutex` | Serializes rebuildBlocklist (RACE-1) |
| `sessions` | `sync.RWMutex` (`sessionsMu`) | Session map |
| `loginAttempts` | `sync.Mutex` | Rate limiting (login + Basic Auth) |
| `authCacheMu` | `sync.RWMutex` | Auth cache 60 s (empty values never cached) |
| `serviceMutex` | `sync.Mutex` (`TryLock`) | Service lifecycle |
| `cachedStatus` | `sync.Mutex` | Status cache |
| `cachedCount` | `sync.Mutex` | Entries count cache |
| `sseClients` | `sync.Mutex` | SSE clients map |
| `downloadClient` | `sync.Mutex` | HTTP client cache |
| `runDirUsable` | `sync.Mutex` | Cache 30 s |
| `portCacheMap` | `sync.Mutex` | Per-port cache (Fix #11) |
| `systemShell` | `sync.Once` | Platform detection (Fix #2) |
| `memLimitMu` | `sync.Mutex` | Memory limit state (v1.1.0 — MEM-1) |
| **`backupMu`** | **`sync.Mutex`** | **Serializes auto-backup calls (v1.2.0 — BAK-2)** |
| **`watchdogTokMu`** | **`sync.RWMutex`** | **Watchdog token cache (v1.2.0 — WD-TOKEN)** |
| **`lastUpdateMu`** | **`sync.Mutex`** | **`last_update` TTL cache (v1.2.0 — BUG-H fix)** |

**`backupMu` rationale**: two rapid user actions could trigger
two `createAutoBackup` calls that operate on the same source
directory. `backupMu` serializes them. The lock is held for the
entire shell invocation (bounded by `AUTO_BACKUP_TIMEOUT = 15 s`).
A side effect of this design is that if the shell times out,
the lock is released but the child process may still be running
for a brief moment — the caller does not retry automatically.

### 4.4 SSE Implementation

#### 4.4.1 Diagram

```text
┌──────────────────────────────────────────────────────────────┐
│  broadcastEvent(event, data)                                 │
│    ├── sseMutex.Lock()                                       │
│    ├── for each client channel:                              │
│    │   ├── select { case ch <- msg: default: }               │
│    │   └── (non-blocking)                                    │
│    └── sseMutex.Unlock()                                     │
└──────────────────────────────────────────────────────────────┘
│
│ (client channels)
▼
┌──────────────────────────────────────────────────────────────┐
│  sseHandler(w, r)  [per-client goroutine]                    │
│    ├── rc := http.NewResponseController(w)                   │
│    ├── ch := make(chan string, 100)  ← Buffered              │
│    ├── loop:                                                 │
│    │   ├── select {                                          │
│    │   │   case msg := <-ch:                                 │
│    │   │     rc.SetWriteDeadline(now + 30 s)  ← Deadline     │
│    │   │     fmt.Fprint(w, msg)                              │
│    │   │     if err := flusher.Flush(); err != nil {         │
│    │   │       return  ← releases goroutine                  │
│    │   │     }                                               │
│    │   │   case <-ticker.C:                                  │
│    │   │     rc.SetWriteDeadline(now + 30 s)                 │
│    │   │     fmt.Fprint(w, ": keepalive\n\n")                │
│    │   │     flusher.Flush()                                 │
│    │   │   case <-r.Context().Done():                        │
│    │   │     return                                          │
│    │   │ }                                                   │
│    │   └── }                                                 │
│    └── }                                                     │
└──────────────────────────────────────────────────────────────┘
```

#### 4.4.2 Why Write Deadline?

**Problem in the traditional design:**

```go
// http.Server.WriteTimeout = 0 (infinite) — to allow long SSE
fmt.Fprint(w, msg)      // ← may block if TCP buffer full
flusher.Flush()         // ← may block
```

If the client is slow: TCP buffer fills up → `Fprint` / `Flush`
block → the goroutine hangs forever → DoS.

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

#### 4.4.4 Client-Side Example (v1.2.0 note)

```javascript
// v1.2.0: `withCredentials` was removed from the WebUI and
// Dashboard clients. Cookies are sent automatically for
// same-origin requests, so the option is unnecessary.
const sse = new EventSource('/events');
```

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
- `shellQuote()` (shell injection protection) — extended in v1.1.0
- `readConfPort` range check (1-65535)
- Auth cache 60 s (I/O reduction) — **empty results never cached** (BUG-C fix)
- `rebuildMu` mutex (RACE-1: BLOCKLIST consistency)
- **v1.1.0 — MEM-1**: Dynamic per-profile memory limit
- **v1.1.0 — MEM-3**: `MONITORING_UI_PORT` constant
- **v1.2.0 — BAK-1**: `runtime_info.backups` exposes 7 fields
- **v1.2.0 — BAK-2**: Pre-critical backup + rotation before destructive operations
- **v1.2.0 — BAK-3**: `cleanupOldTransactions()` preserves ROLLBACK/START
- **v1.2.0 — BAK-4**: `checkPendingNotifications()` reads and clears
- **v1.2.0 — Language toggle**: client-side only, no server state
- **v1.2.0 — Watchdog token**: closes the CSRF hole on `ensure_running_service` (see §4.5.1)
- **v1.2.0 — BUG-A..L fixes**: See the "Post-audit corrections" table below.

#### 4.5.1 Watchdog Token (v1.2.0)

The watchdog (`watchdog.sh`) needs to call
`POST /api/ensure_running_service` to recover a crashed DNS
engine. In v1.1.0 this endpoint was protected only by an
implicit "localhost bypass" — which was exploitable: any web
page loaded in a browser on the same device could silently
trigger a service restart.

v1.2.0 replaces the bypass with a token:

```text
┌──────────────────────────────────────────────────────────────┐
│  Token lifecycle                                             │
│                                                              │
│  1. customize.sh §[19b] generates a 64-hex token             │
│     during install and writes it to:                         │
│         $RUN_DIR/.watchdog_token   (mode 0600)               │
│                                                              │
│  2. If the file is missing (e.g. user disabled the           │
│     WebUI before first startup), main.go creates it          │
│     on the next run via loadOrCreateWatchdogToken().         │
│                                                              │
│  3. watchdog.sh reads the file on every API call             │
│     (no cache) and sends it as:                              │
│         X-Watchdog-Token: <token>                            │
│                                                              │
│  4. main.go verifyWatchdogToken() compares the               │
│     header against the file using                            │
│     subtle.ConstantTimeCompare.                              │
│                                                              │
│  5. On mismatch or missing header → 401.                     │
└──────────────────────────────────────────────────────────────┘
```

**Characteristics**:

- **Localhost-scoped**: `isLocalRequest` is still required;
  a remote request with a valid token is rejected.
- **Constant-time**: no timing leak on comparison.
- **Not rate-limited**: token requests bypass the login
  limiter, so a flapping DNS engine does not lock the
  watchdog out.
- **Persistent**: the token file survives restarts. It is
  regenerated only if the file is missing.
- **Fail-closed**: if the token file is missing and no token
  is sent, the request falls back to normal user auth — which
  the watchdog does not have — so the request is rejected.
  `watchdog.sh` logs "no auth header" and backs off.

The token file is excluded from the 5-file preservation set
(it is a runtime secret, not user config). If the file is
deleted, `main.go` regenerates it on the next run and
`watchdog.sh` picks it up on its next API call.

**v1.2.0 data-preservation security model**:

| Concern | v1.2.0 mitigation |
|---|---|
| Backup tampering | SHA256 checksums in `.manifest.json` |
| Backup leakage | Directory permissions `0700` (best-effort on `/sdcard`) |
| Recovery abuse | Requires an explicit trigger file |
| SELinux relaxation | Contexts restored via `restorecon` / `chcon` |
| Transaction race | Numbered transaction dirs with `.state` file |
| Disk exhaustion | Rotation capped at 21 snapshots |
| Sensitive file inclusion | Only the 5 user config files |
| Stale cache on restore | SW bypasses all `/api/*` paths |
| Language toggle state | Client-side only (`localStorage`); never sent to the server |
| Watchdog impersonation | Token file (0600) + `subtle.ConstantTimeCompare` |

### 4.6 Backend Fixes (Summary)

The full fix history is documented in `docs/API.md` §11 and
`docs/SECURITY.md` §17. This section summarizes the backend
fixes that shaped the current structure.

#### 4.6.1 v1.0.0 — Critical Backend Fixes

| Fix | Topic | Reference |
|---|---|---|
| A | `STATUS_FILE` semantics (read-only from `getStatus`) | SECURITY.md Audit #18 |
| B | `metricsProxyHandler` path | SECURITY.md Audit #25 |
| C | IPv6 client IP (`getClientIP`) | SECURITY.md Audit #19 |
| D | Port collision guard (`MONITORING_UI_PORT`) | SECURITY.md Audit #20 |
| E | Section-restricted TOML parsing | SECURITY.md Audit #21 |
| Fix #1 | Dashboard JSON conversion (Prometheus → JSON) | SECURITY.md Audit #25 |
| Fix #2 | `getSystemShell()` fallback for Linux/macOS | §15 |
| Fix #8 | Basic Auth rate limiting | SECURITY.md Audit #22 |
| Fix #10 | Section header with trailing comment | SECURITY.md Audit #23 |
| Fix #11 | Per-port cache | §10 |
| Fix #12 | Exact endpoint matching (`hasEndpoint`) | SECURITY.md Audit #24 |
| NEW-1 | Login POST-only (CSRF) | SECURITY.md Audit #28 |
| NEW-3 | `readConfPort` range check | SECURITY.md Audit #29 |
| NEW-4 | `/readyz` localhost-only | SECURITY.md Audit #30 |
| NEW-5 | `shellQuote` injection protection | SECURITY.md Audit #31 |
| NEW-6 | Auth cache 60 s | SECURITY.md §5.27 |
| RACE-1 | `rebuildMu` mutex | SECURITY.md Audit #32 |
| PORT-2 | `runtime_info` dynamic ports | SECURITY.md Audit #33 |

**Legend reference**: the letters A–E above map to the
detailed implementations in §4.8.

#### 4.6.2 v1.1.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| MEM-1 | Dynamic memory limit per profile | §4.9.1, SECURITY.md §5.30.1 |
| MEM-2 | Extended `shellQuote` charset | §4.9.2, SECURITY.md §5.30.2 |
| MEM-3 | `MONITORING_UI_PORT` constant | §4.9.3, SECURITY.md §5.30.3 |

#### 4.6.3 v1.2.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| BAK-1 | `buildBackupInfo()` — 7-field schema | §4.10.1 |
| BAK-2 | `createAutoBackup(reason string)` + `rotate_backups` | §4.10.2 |
| BAK-3 | `cleanupOldTransactions()` | §4.10.3 |
| BAK-4 | `checkPendingNotifications()` | §4.10.4 |
| WD-TOKEN | Watchdog token (closes CSRF hole) | §4.5.1 |
| BUG-A..L | Post-audit corrections | §4.11 |

#### 4.6.4 Post-Audit Corrections (v1.2.0)

A pre-release audit identified the following issues, all
corrected in-place within v1.2.0:

| ID | Topic |
|---|---|
| BUG-A | `appendDenylist` now requires a `content` parameter and appends it (previously a no-op) |
| BUG-B | CSRF bypass on `ensure_running_service` replaced by watchdog token |
| BUG-C | Auth cache no longer stores empty results |
| BUG-D | `createAutoBackup` now calls `rotate_backups 21` after success |
| BUG-E | Unique snapshot directory names (avoid same-second collision) |
| BUG-F | `clear_logs` now reports `os.Truncate` errors |
| BUG-G | `getStatusUncached` uses named return + sets `"OFF"` on panic |
| BUG-H | `last_update` cache is now TTL-based (5 s), not `sync.Once` |
| BUG-I | `runtime_info.profile_key` reads from `selected_profile.txt` |
| BUG-J | `isPidAlive` matches exact command names (no substring) |
| BUG-K | `runShellWithTimeout` log distinguishes timeout from exit non-zero |
| BUG-L | Watchdog token file written atomically |

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
    attempt = &LoginAttempt{}
    loginAttempts[ip] = attempt
}
if success {
    delete(loginAttempts, ip)
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

#### 4.7.3 Fix I — `isRunDirUsable` (30 s cache)

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

#### 4.7.4 Fix J — `isPortOpen` native Go

**Before**: `fork/exec` + `source functions.sh` every 3 s.
**After**: read `/proc/net/udp{,6}` directly.

#### 4.7.5 Fix K — Asset Serving

**Added 7 static files**:
- `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`
- `favicon-32x32.png`, `favicon-16x16.png`, `favicon.ico`
- `offline.html`

### 4.8 v1.0.0 Backend Fixes (Details)

This section retains the code-level details of the v1.0.0 fixes
that were fundamental to the security model. The v1.1.0 and
v1.2.0 additions are covered in §4.9 and §4.10.

#### 4.8.1 Fix A — `STATUS_FILE` semantics

`getStatusUncached` is read-only with respect to `STATUS_FILE`.
It never writes the file — only `startService` / `stopService`
in `main.go` and the disable path in `service.sh` write it.

#### 4.8.2 Fix B — `metricsProxyHandler` path

Uses `MONITORING_UI_PORT` constant (v1.1.0 — MEM-3) instead of
the previously hard-coded `"8080"`.

#### 4.8.3 Fix C — IPv6 client IP (`getClientIP`)

```go
func getClientIP(r *http.Request) string {
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return strings.Trim(r.RemoteAddr, "[]")
    }
    return host
}
```

#### 4.8.4 Fix D — Port Collision Guard

`main.go` refuses to start if `PORT`, `DASHBOARD_PORT`, or
their combination collides with `MONITORING_UI_PORT`.

#### 4.8.5 Fix E — Section-restricted TOML

`readMonitoringAuthFromFile` tracks whether it is inside
`[monitoring_ui]` and ignores any `username`/`password`
in other sections.

#### 4.8.6 Fix M — Metrics JSON conversion (Fix #1)

**Solution**:

```go
// 1. parser
func parsePrometheus(text string) map[string]float64 { ... }

// 2. converter
func buildDashboardJSON(prom map[string]float64) map[string]interface{} { ... }

// 3. handler
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
    // ...
    body, _ := io.ReadAll(resp.Body)
    var upstream map[string]interface{}
    if err := json.Unmarshal(body, &upstream); err == nil {
        json.NewEncoder(w).Encode(upstream)
        return
    }
    prom := parsePrometheus(string(body))
    dashboardJSON := buildDashboardJSON(prom)
    json.NewEncoder(w).Encode(dashboardJSON)
}
```

#### 4.8.7 Fix N — `getSystemShell` fallback (Fix #2)

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
```

#### 4.8.8 Fix O — Basic Auth Rate Limiting (Fix #8)

See `checkAuth()` in §4.5.

#### 4.8.9 Fix P — Section Header with Comment (Fix #10)

```go
if strings.HasPrefix(trimmed, "[") {
    if end := strings.Index(trimmed, "]"); end > 0 {
        section := strings.TrimSpace(trimmed[1:end])
        inSection = (section == "monitoring_ui")
        continue
    }
}
```

Applied in 4 files: `main.go`, `functions.sh`, `watchdog.sh`,
`customize.sh`.

#### 4.8.10 Fix Q — Per-Port Cache (Fix #11)

```go
type portCacheEntry struct {
    open bool
    time time.Time
}

var (
    portCacheMu  sync.Mutex
    portCacheMap = make(map[int]portCacheEntry)
)
```

#### 4.8.11 Fix R — Exact Endpoint Matching (Fix #12 + NEW-2)

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

Applied to 11 POST endpoints + `auth/login` + `auth/logout`.

#### 4.8.12 Fix S — Login POST-only (Fix NEW-1)

See §3.6.

#### 4.8.13 Fix T — `readConfPort` Range Check (Fix NEW-3)

```go
func readConfPort(key, defaultPort string) string {
    defer func() { recover() }()
    val := readConfValue(key, defaultPort)
    n, err := strconv.Atoi(val)
    if err != nil || n < 1 || n > 65535 {
        return defaultPort
    }
    return val
}
```

#### 4.8.14 Fix U — `/readyz` localhost-only (Fix NEW-4)

See §3.6.

#### 4.8.15 Fix V — `shellQuote` Injection Protection (Fix NEW-5)

See §4.9.2 for the v1.1.0 extension.

#### 4.8.16 Fix W — Auth Cache 60 s (Fix NEW-6)

See §4.5 and BUG-C fix.

#### 4.8.17 Fix X — `rebuildMu` mutex (RACE-1)

See §3.7.

#### 4.8.18 Fix Y — `runtime_info` ports (PORT-2)

See §3.8.

#### 4.8.19 Fix Z — Preserve Settings (Fix #3)

The v1.0.0 mechanism (`BACKUP_TMP` in `/data/local/tmp/`) is
superseded by the v1.2.0 10-layer architecture (§4.10).
Retained here as historical context.

### 4.9 v1.1.0 Backend Additions

#### 4.9.1 MEM-1 — Dynamic Memory Limit per Profile

**Before**:

```go
debug.SetMemoryLimit(80 * 1024 * 1024)  // hardcoded
```

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
- `main()` at startup (after `initPaths()`).
- `updateProfile()` after `atomicWriteFile(SELECTED_FILE)`.

#### 4.9.2 MEM-2 — Extended `shellQuote` Character Set

**After (v1.1.0)**: adds `{`, `}`, `\n`, `\t` (24 characters total).

#### 4.9.3 MEM-3 — `MONITORING_UI_PORT` in Metrics Handler

**After**:

```go
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

### 4.10 v1.2.0 Backend Additions

v1.2.0 introduces four additions to `main.go`, all confined to
two new sections (`[36b]` and `[36c]`) plus an extension to
`buildRuntimeInfo()` and the new watchdog token subsystem.

#### 4.10.1 BAK-1 — `buildBackupInfo()` (7-field schema)

**Purpose**: enumerate the persistent backup directory and
return a JSON object with 7 fields.

**Fields**:
- `available` — number of snapshots (excludes `current/`,
  `txn-*`, `orphan-txn-*`).
- `in_flight_txn` — number of `txn-*` directories.
- `orphan_txn` — number of `orphan-txn-*` directories.
- `last_backup` — human-readable mtime of the newest snapshot.
- `last_backup_name` — directory name of the newest snapshot.
- `last_stable` — content of `.last_stable`.
- `path` — absolute path of the backup directory.

**Response shape**:

```json
{
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-26 15:00:00",
  "last_backup_name": "20260926-150000-manual-1234",
  "last_stable": "20260926-095826-v1.2.0-5678",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**Ordering**: `last_backup_name` is chosen by lexicographic
sort of directory names (chronological for the
`<YYYYMMDD>-<HHMMSS>-...` naming convention).

**Consumed by**:
- The WebUI System Info panel (`index.html`).
- The Dashboard System Info panel (`dashboard.html`).
- Any API client reading `/api?action=runtime_info`.

#### 4.10.2 BAK-2 — `createAutoBackup(reason string)`

**Purpose**: snapshot the 5 user config files before a
destructive operation, and rotate backups afterwards.

**Called from** — 5 destructive endpoints, but only **4
distinct reason strings** (because `appendDenylist` delegates
to `saveDenylist`):

| Caller | Reason |
|---|---|
| `updateProfile()` | `"pre-profile-change"` |
| `saveAllowlist()` | `"pre-allowlist-save"` |
| `saveDenylist()` | `"pre-denylist-save"` |
| `saveCustomRulesCombined()` | `"pre-custom-rules-save"` |
| `appendDenylist(content)` | *(no own reason — calls `saveDenylist`, which uses `"pre-denylist-save"`)* |

**Corrected in this revision**: The `appendDenylist` entry
previously listed `"pre-append-denylist"` — that string does
**not** exist in the code. `appendDenylist` delegates to
`saveDenylist`, so the recorded reason is
`"pre-denylist-save"`.

**Semantics**:
- **Best-effort**: a failed backup logs a warning and returns.
  The user action proceeds.
- **Serialized**: `backupMu` ensures two rapid actions cannot
  trigger overlapping backups.
- **Delegated to shell**: `main.go` calls
  `functions.sh:backup_user_files` via `runShellWithTimeout`.
- **Rotation**: after a successful backup, `rotate_backups 21`
  is invoked **in the same shell call**.
- **Timeout**: `AUTO_BACKUP_TIMEOUT = 15 s`.
- **Unique target directory**: main.go generates
  `<ts>-manual-<pid>-<rand4>` and passes it to
  `backup_user_files` as the second argument. This avoids
  same-second collisions with `action.sh --backup`.

**Non-goals**:
- Does not trigger in recovery mode.

#### 4.10.3 BAK-3 — `cleanupOldTransactions()`

**Purpose**: remove leftover `COMMIT`'d transaction directories
that a previous install failed to clean up.

**Called from**: `main()` at startup.

**Logic**:
1. Read `$PERSISTENT_BACKUP`.
2. For each `txn-*` directory, read `.state`:
   - `COMMIT` → remove the directory.
   - `START` / `ROLLBACK` / missing → **preserve**.
3. Log the number of removed directories.

**Non-goals**:
- Does not touch `orphan-txn-*` directories.
- Does not touch `current/` or any `<timestamp>-...` snapshot.

#### 4.10.4 BAK-4 — `checkPendingNotifications()`

**Purpose**: read `.pending_notification` at startup, log its
content, and remove the file.

**File location**: `$PERSISTENT_BACKUP/.pending_notification`.

**Producer**: `customize.sh` writes this file after a successful
restore during an upgrade.

**Semantics**:
- Missing file → no-op (the common case).
- Empty file → removed silently (debug log).
- Non-empty file → logged with `logEvent("📢 " + msg)`, then removed.

**Rationale**: The installer cannot display messages after it
exits. A persistent notification file is the cleanest way to
pass a post-install message to the WebUI. `service.sh` reads
the file too (for the boot log) but does **not** delete it —
deletion is `main.go`'s exclusive responsibility.

#### 4.10.5 WD-TOKEN — Watchdog Token

See §4.5.1 for the design and lifecycle.

#### 4.10.6 Status Field Alignment

The `runtime_info.backups` object and the `status.sh --json`
output share the same **7 fields with the same semantics**:

| Field | `runtime_info` | `status.sh --json` |
|---|:---:|:---:|
| `available` | ✅ | ✅ |
| `in_flight_txn` | ✅ | ✅ |
| `orphan_txn` | ✅ | ✅ |
| `last_backup` | ✅ | ✅ |
| `last_backup_name` | ✅ | ✅ |
| `last_stable` | ✅ | ✅ |
| `path` | ✅ | ✅ |
| `status` | ❌ | ✅ |
| `last_backup_age_seconds` | ❌ | ✅ |

**Note**: They are **not byte-identical**. A consumer that needs
to work with both shapes should treat the 7 common fields as
the intersection and treat `status` / `last_backup_age_seconds`
as optional.

### 4.11 v1.2.0 Post-Audit Corrections

See §4.6.4 for the summary table. Each correction is
documented inline in `main.go`'s header.

---

## 5. Shell Scripts

### 5.1 Roles

| Script | Role | Trigger |
|---|---|---|
| `customize.sh` | Install (+ backup/restore + 10 layers) | Magisk install |
| `service.sh` | Start services + periodic auto-backup | boot_completed |
| `post-fs-data.sh` | Emergency cleanup | early boot |
| `watchdog.sh` | Monitoring (services only) + token auth | standalone |
| `action.sh` | Open WebUI + `--backup` + `--diagnose` | Magisk Action |
| `status.sh` | Display status + `--diagnose` + `--json` | manual |
| `uninstall.sh` | Cleanup + orphan txn preservation | Magisk remove |
| `functions.sh` | Shared library (incl. backup helpers + watchdog token reader) | sourced |
| `build.sh` | Cross-compile | manual / CI |
| `META-INF/com/google/android/update-binary` | Root manager entry point | Magisk install |

### 5.2 Boot Sequence

```text
Boot → Kernel → Init (mount /data)
  │
  ▼
post-fs-data.sh  ← emergency cleanup if disabled
  │              ← Custom Chain cleanup
  │              ← does NOT touch backups (see §5.5)
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
  ├── cleanupOldTransactions()          ← v1.2.0
  ├── read .pending_notification        ← v1.2.0
  ├── auto_backup_if_needed(24 h)       ← v1.2.0
  ├── rotate_backups(21)                ← v1.2.0
  ├── start WebUI
  └── start Watchdog (standalone, with token auth)
```

### 5.3 Watchdog Model

```text
watchdog.sh (real PID)
  │
  ├── write PID
  ├── trap TERM/INT/QUIT → cleanup
  ├── read watchdog token from $RUN_DIR/.watchdog_token
  ├── read credentials from [monitoring_ui] only (fallback)
  ├── v1.2.0: read-only snapshot of backup state
  │   (log line only — does NOT write)
  │
  └── loop:
        ├── sleep BACKOFF (30 s → 600 s exponential)
        ├── check disable
        ├── check WebUI → restart if needed
        └── check STATUS_FILE:
              - "ON"  → call POST /api/ensure_running_service
                        with X-Watchdog-Token header
              - "OFF" → skip (respect user intent)
              (separate DNS_BACKOFF + reset on STATUS change)
```

**RACE-1 integration**:
- `rebuildMu` prevents overlapping rebuilds.
- Watchdog does not call `rebuildBlocklist` directly.

**Token auth**:
- The watchdog reads the token on every API call (no cache)
  so a regenerated token is picked up without a restart.
- If the token file is missing, the watchdog falls back to
  Basic Auth (from `dnscrypt-proxy.toml`).
- If neither is available, the request goes without auth and
  the server returns 401 — the watchdog backs off correctly.

### 5.4 Backup Helpers in `functions.sh`

`functions.sh` exposes runtime helpers:

| Helper | Purpose |
|---|---|
| `get_backup_dir` | Return the persistent backup directory path |
| `ensure_backup_dir` | Create the backup root if missing |
| `write_manifest` | Write `.manifest.json` with per-file SHA256 |
| `verify_backup_integrity` | SHA256 + size + emptiness check |
| `backup_user_files` | Snapshot the 5 user config files |
| `restore_user_files` | Restore with SELinux + verification |
| `rotate_backups` | Prune to `keep_count` (default 21) |
| `get_last_backup_time` | Return the epoch mtime of `.last_auto_backup` |
| `auto_backup_if_needed` | Trigger a backup if older than 24 h |
| `cleanup_old_transactions` | Remove leftover `COMMIT`'d `txn-*` dirs |
| `copy_with_context` | Copy a single file with SELinux + chmod 0600 |
| **`get_watchdog_token`** | **Read `$RUN_DIR/.watchdog_token` (v1.2.0 — FSH-11)** |

The same helpers exist inline in `customize.sh` (install-time)
and in `action.sh`, `service.sh`, `status.sh`, and `watchdog.sh`
(fallbacks).

**FSH-10 (v1.2.0)**: `backup_user_files` and
`auto_backup_if_needed` append `-$$` (caller PID) to their
default target directory names. This mirrors the same fix in
`customize.sh` (BUG-CS-C) and in `main.go` (BUG-E), and
prevents two backups started in the same wall-clock second from
writing into the same directory.

**FSH-11 (v1.2.0)**: A new `get_watchdog_token` helper reads
the token written by `customize.sh` §[19b] or by `main.go`.
It is used by `watchdog.sh` (which implements an inline
equivalent for self-containment) and by any future script that
needs to authenticate to `ensure_running_service`.

### 5.5 What Shell Scripts Do NOT Do

| Script | Non-responsibility |
|---|---|
| `post-fs-data.sh` | Does not touch `/sdcard/dnscrypt-webui-backup/` — `/sdcard/` may not be mounted yet |
| `watchdog.sh` | Does not trigger backups — a flapping service would create a backup storm. Also read-only with respect to the backup directory |
| `service.sh` | Does not create pre-critical backups — that is `main.go`'s job |
| `main.go` | Does not copy files itself — delegates to `functions.sh` |
| `uninstall.sh` | Does not delete the persistent backup directory — see §5.6 |

### 5.6 Uninstall Policy (v1.2.0)

`uninstall.sh` performs four decisions with respect to the
backup directory:

1. **Preserve `current/` and `<timestamp>-*` snapshots** —
   These are the user's data. They survive uninstall so that a
   reinstall recovers the configuration automatically.
2. **Preserve `orphan-txn-*` directories** — These are the
   user's explicit signal that they want to inspect them
   manually.
3. **Rename `txn-*` with `.state=START` to `orphan-txn-*`** —
   An interrupted install's transaction is the only on-device
   copy of the user's data. The rename preserves it under a
   name that signals manual inspection is needed.
4. **Remove `txn-*` directories with `.state=COMMIT` or
   `.state=ROLLBACK`** — These are transient.

The user can always remove everything manually:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

Additionally, `uninstall.sh` removes the external recovery
trigger at `/data/adb/dnscrypt-recovery` (UNI-1 fix), because
the file's only meaning is "the NEXT install should enter
recovery mode" — which is void once the module is uninstalled.

### 5.7 Watchdog Token Reader (v1.2.0 — FSH-11)

The token is generated once and persists across restarts:

```text
┌──────────────────────────────────────────────────────────────┐
│  Generation                                                  │
│  ──────────                                                  │
│  • customize.sh §[19b]: 64 hex chars from                    │
│    /dev/urandom (fallback: sha256 of date+pid+rnd)           │
│  • main.go loadOrCreateWatchdogToken(): 32 bytes             │
│    from crypto/rand                                          │
│                                                              │
│  Persistence                                                 │
│  ───────────                                                 │
│  File:   $RUN_DIR/.watchdog_token                            │
│  Mode:   0600                                                │
│  Atomic: yes (tmp + rename)                                  │
│                                                              │
│  Consumption                                                 │
│  ───────────                                                 │
│  • watchdog.sh       reads on every API call                 │
│  • functions.sh      exposes get_watchdog_token              │
│  • main.go           verifyWatchdogToken() uses              │
│                      subtle.ConstantTimeCompare              │
└──────────────────────────────────────────────────────────────┘
```

---

## 6. Frontend

### 6.1 Structure

| File | Purpose | Size |
|---|---|---|
| `index.html` | Main WebUI (EN default + AR toggle) | ~140 KB |
| `dashboard.html` | Monitoring dashboard (EN default + AR toggle) | ~82 KB |
| `manifest.json` | PWA manifest (`lang="en"`, `dir="ltr"`) | ~4 KB |
| `sw.js` | Service Worker (language-neutral) | ~22 KB |
| `offline.html` | Offline page (EN default + AR toggle) | ~18 KB |
| `icon-192.svg` | Small icon | ~1.5 KB |
| `icon-512.svg` | Maskable icon | ~1.7 KB |
| `icon-192.png` | PWA icon | ~14 KB |
| `icon-512.png` | PWA icon | ~78 KB |
| `apple-touch-icon.png` | iOS | ~18 KB |
| `favicon-32x32.png` | favicon | ~1.4 KB |
| `favicon-16x16.png` | favicon | ~553 B |
| `favicon.ico` | favicon | ~4.7 KB |

### 6.2 Service Worker Caching Strategy

```text
┌──────────────────────────────────────────────────────────────┐
│  Request                                                     │
└──────────────────────────────┬───────────────────────────────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
                  ▼                         ▼
           BYPASS list?               Navigation?
           (shouldBypass())           (isNavigationRequest())
                  │                         │
                  ├─ /api/*                 ├─ Network-First (5 s timeout)
                  ├─ /events                │  → cache fallback
                  ├─ /auth/*                │  → /offline.html
                  ├─ /healthz, /readyz      │
                  ├─ /sw.js                 └─ Stale-While-Revalidate
                  ├─ non-GET                   (all other GET assets)
                  └─ Authorization header
                  │
                  ▼
           Let the browser handle it
```

**v1.2.0 note**: The `shouldBypass()` rule for `/api/*` covers
`runtime_info.backups`. The Service Worker **never** caches the
backup state — the user always sees the current state.

**Language-neutral**: The SW caches the HTML once (with both
`translations` objects inline). The language toggle operates
purely on the DOM; no additional cache entries are created.

### 6.3 State Machine (Edit Mode)

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
        │                           │              │
        │                         [ok]          [error]
        │                           │              │
        │                           ▼              ▼
        └────────────────────── VIEW ◄──── ROLLBACK
```

### 6.4 PWA Features

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
- **v1.2.0**: System Info panel shows the 7-field backup state
- **v1.2.0**: Bilingual WebUI (EN default + AR toggle). The
  `manifest.json` `lang` field defaults to `en` and `dir` to
  `ltr`. The toggle updates both at runtime.

### 6.5 Service Worker Update Flow (v1.2.0 fix)

Both `index.html` and `dashboard.html` share the same SW update
flow:

```text
┌──────────────────────────────────────────────────────────────┐
│  Page load                                                   │
│    ├── navigator.serviceWorker.register('/sw.js')            │
│    ├── if reg.waiting && controller → show banner            │
│    └── on updatefound → track installing.state               │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  User clicks [Reload]                                        │
│    ├── if pendingReload → return (guard)                     │
│    ├── pendingReload = true                                  │
│    ├── reg.waiting.postMessage({SKIP_WAITING})               │
│    └── wait for 'controllerchange' event                     │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  navigator.serviceWorker 'controllerchange'                  │
│    └── if pendingReload → location.reload()                  │
└──────────────────────────────────────────────────────────────┘
```

**v1.1.0 bug (fixed in v1.2.0)**:
The [Reload] button previously sent `SKIP_WAITING` to
`navigator.serviceWorker.controller` — the **old** worker — which
ignored it. The new worker stayed in the `waiting` state, so the
banner reappeared on every page reload. Infinite loop.

**v1.2.0 fix**:
- Send `SKIP_WAITING` to `swRegistration.waiting` (the **new**
  worker).
- Reload on the `controllerchange` event.
- Guard double-clicks with a `pendingReload` flag.

**Scope**: the fix now applies to **both** `index.html` **and**
`dashboard.html`. In v1.1.0, only `index.html` shipped the fix;
`dashboard.html` had the JS handlers but no
`<div id="swUpdateBanner">` block, so the banner could never be
shown. In v1.2.0, `dashboard.html` gained the same HTML block
and the same CSS rules as `index.html`, making the fix complete.

### 6.6 Dual-Origin Limitation

```text
┌──────────────────────────────────────────────────────────────┐
│  Architectural problem:                                      │
│                                                              │
│  • WebUI :9090  ← separate origin                            │
│  • Dashboard :9091 ← separate origin                         │
│                                                              │
│  Service Worker is limited to a single origin.               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Practical impact:                                           │
│                                                              │
│  • PWA installed from 9090 → offline for WebUI only          │
│  • PWA installed from 9091 → offline for Dashboard only      │
│  • Both = assets stored twice                                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Future solution (v1.3.x):                                   │
│                                                              │
│  Unify on a single port (Option A):                          │
│  • Dashboard served from the same 9090 at /dashboard         │
│  • Single origin → single SW → offline for both              │
│  • refactor main.go (mux routing)                            │
└──────────────────────────────────────────────────────────────┘
```

### 6.7 Language Toggle (v1.2.0)

All three HTML pages (`index.html`, `dashboard.html`, `offline.html`)
ship with the same language-toggle mechanism:

| Aspect | Implementation |
|---|---|
| Default language | English |
| Toggle button | `<button class="lang-toggle" id="langToggle">` in the header |
| Toggle icons | 🇸🇦 (to switch to Arabic) / 🇬🇧 (to switch to English) |
| Translation objects | `translations.en` and `translations.ar` inline in each page |
| Runtime function | `toggleLanguage()` — swaps `currentLang`, updates `html.lang`, `html.dir`, and re-renders |
| Preference storage | `localStorage['dnscrypt-lang']` (`"en"` or `"ar"`) |
| RTL CSS | `[dir="rtl"]` rules cover layout, arrows, and margins |
| Service Worker | Language-neutral — caches the HTML once |
| Server state | None — the toggle never talks to the API |

**Default on first visit**: English.

**No API impact**: The API is language-neutral. JSON payloads do
not contain localized strings. The `langToggle` is a purely
client-side concern.

**Documentation**: remains English-only by project convention.
Community translations are welcome as separate files
(`docs/*.<lang>.md`). Additional WebUI languages (FR, DE, ES,
RU, ZH, ...) are deferred to v1.4.0 — see `docs/ROADMAP.md` §6.

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
| `currentMemLimit` | memory | recomputed at startup | `applyMemoryLimit` (v1.1.0) |
| `currentProfile` | memory | recomputed at startup | `applyMemoryLimit` (v1.1.0) |
| **`backupMu`** | **memory** | **lost on restart** | **`createAutoBackup` (v1.2.0)** |
| **`watchdogTok`** | **memory** | **lost on restart (regenerated)** | **`getWatchdogToken` (v1.2.0)** |
| **`$PERSISTENT_BACKUP`** | **`/sdcard/...`** | **✓ (survives uninstall)** | **`customize.sh`, `service.sh`, `main.go` (v1.2.0)** |
| **`.last_stable`** | **file** | **✓** | **`customize.sh` (v1.2.0)** |
| **`.upgrade_history.json`** | **file** | **✓** | **`customize.sh` (v1.2.0)** |
| **`.last_auto_backup`** | **file (marker)** | **✓ (mtime)** | **`auto_backup_if_needed` (v1.2.0)** |
| **`.pending_notification`** | **file (transient)** | **✓** | **`customize.sh` writes; `main.go` deletes (v1.2.0)** |
| **`.watchdog_token`** | **file** | **✓** | **`customize.sh` or `main.go` (v1.2.0)** |

### 7.2 Client-side State

| State | Storage | Lifetime |
|---|---|---|
| Drafts (Allowlist/Denylist) | localStorage | 1 hour |
| Session token | memory only (cookie-based) | tab lifetime |
| Show idle | localStorage | persistent |
| Server hashes | memory | page lifetime |
| `currentStatus` | memory | page lifetime |
| `PORTS` | memory | page lifetime (updated from runtime_info) |
| **Language preference** | **`localStorage['dnscrypt-lang']`** | **persistent** |
| **Current language (runtime)** | **memory (`currentLang`)** | **page lifetime** |

**v1.2.0 note**: The `dnscrypt-lang` localStorage key **is
actively used** to persist the user's choice between English
(default) and Arabic. It is read at page load and written on
every toggle. The value is client-side only — it is never
transmitted to the server.

### 7.3 Conflict Detection

```text
Client                          Server
  │                               │
  ├── save(content, hash_A) ────► │
  │                               │
  │                               ├── if hash_A ≠ current_hash:
  │                               │      return 409 conflict
  │◄──── 200 {hash: B} ──────────┤
  │                               │
  ├── next save: hash_B           │
```

### 7.4 State Machine — STATUS_FILE

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  User Intent (STATUS_FILE)      Actual State (probe)         │
│  ────────────────────────       ────────────────────         │
│                                                              │
│  START                                  ┌─── ON ────┐        │
│    │                                    │            │        │
│    ├─► startService() ──► [ON] ────────►│            │        │
│    │                              ▲     │            │        │
│    │                        Watchdog    │            │        │
│    │                        restarts    │            │        │
│    │                        on crash    │            │        │
│    │                              │     │            │        │
│    │                        [ON]─┴─────│            │        │
│    │                              [crash]            │        │
│    │                                [OFF]────────────┘        │
│    │                                                         │
│    └─► stopService() ──► [OFF]                               │
│                                                              │
│  User stops ────────────────────► [OFF]──────────────────    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.5 User Intent vs Actual State

```text
┌──────────────────────────────────────────────────────────────┐
│  STATUS_FILE (User Intent)                                   │
│  ────────────────────────                                    │
│  • written only by startService() / stopService()            │
│  • NOT written by getStatusUncached (read-only)              │
│  • Watchdog depends on it                                    │
└──────────────────────────────────────────────────────────────┘
                              ↕
┌──────────────────────────────────────────────────────────────┐
│  Actual State (probe)                                        │
│  ────────────────────                                        │
│  • isProcessRunning() + isPortOpenCached(5354)               │
│  • read from getStatusUncached()                             │
│  • used in getStatus()                                       │
└──────────────────────────────────────────────────────────────┘
```

### 7.6 Backup State Machine (v1.2.0)

```text
┌──────────────────────────────────────────────────────────────┐
│  Install / Upgrade                                           │
│    ├── Layer 1: find source (≥ 3 valid files)                │
│    ├── Layer 2: snapshot to PERSISTENT_BACKUP                │
│    ├── Layer 3: verify SHA256                                │
│    ├── Layer 4: transaction begin/commit                     │
│    └── Layer 10: append .upgrade_history                     │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Steady State                                                │
│    ├── service.sh: auto_backup_if_needed(24 h)               │
│    ├── service.sh: rotate_backups(21)                        │
│    ├── main.go:    createAutoBackup on writes                │
│    ├── main.go:    rotate_backups(21) after each             │
│    ├── main.go:    checkPendingNotifications at boot         │
│    └── main.go:    cleanupOldTransactions at boot            │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Uninstall                                                   │
│    ├── txn-* with .state=COMMIT → removed                    │
│    ├── txn-* with .state=ROLLBACK → removed                  │
│    ├── txn-* with .state=START → renamed to                  │
│    │   orphan-txn-* → preserved                              │
│    └── current/ + <timestamp>-* → preserved                  │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Reinstall                                                   │
│    └── Layer 1 finds /sdcard/dnscrypt-webui-backup           │
│        → restores automatically                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. File Layout

### 8.1 Runtime Layout

```text
/data/adb/modules/dnscrypt-proxy-webui/
├── module.prop                    # Magisk definition
├── service.sh                     # boot service
├── post-fs-data.sh                # early cleanup
├── action.sh                      # Magisk Action (+ --backup/--diagnose)
├── status.sh                      # status (+ --diagnose/--json)
├── uninstall.sh                   # cleanup + orphan txn preservation
├── functions.sh                   # shared library (incl. backup helpers)
├── watchdog.sh                    # standalone process (token auth)
├── customize.sh                   # installer (10 layers)
├── .module.fingerprint            # module fingerprint
├── disable                        # disable flag (optional)
├── recovery                       # recovery trigger (optional, v1.2.0)
│
├── web/                           # Frontend (bilingual: EN default + AR toggle)
│   ├── index.html
│   ├── dashboard.html
│   ├── manifest.json              # lang="en", dir="ltr" (defaults)
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
        ├── .bootstrap_cache
        └── .watchdog_token        # ← v1.2.0

/sdcard/dnscrypt-webui-backup/     # persistent backup (v1.2.0)
├── current/                       # live snapshot (always up-to-date)
├── <timestamp>-<version>-<pid>/   # historical snapshot
├── <timestamp>-manual-<pid>/      # pre-critical backup
├── <timestamp>-auto-<pid>/        # periodic backup
├── txn-<timestamp>-<pid>/         # in-flight transaction (short-lived)
├── orphan-txn-<timestamp>-<pid>/  # preserved interrupted install
├── .last_stable                   # pointer to last known-good snapshot
├── .last_auto_backup              # mtime marker for periodic backup
├── .upgrade_history.json          # full upgrade log (with jq)
├── .upgrade_history.txt           # fallback log (without jq)
├── .pending_notification          # transient; read+deleted by main.go
└── README.md                      # user-facing guide

/data/adb/dnscrypt-recovery        # external recovery trigger (optional, v1.2.0)
```

### 8.2 Repository Layout (87 files)

> **Total tracked files**: **87** across 9 top-level directories.
>
> **Note**: The file count is 87, matching the count in
> `README.md`. The `.github/` directory contains 12 files:
> 4 root files, 1 PR template (inside `PULL_REQUEST_TEMPLATE/`),
> 3 issue templates, and 4 workflow files
> (`ci.yml`, `codeql.yml`, `release.yml`, `upgrade-test.yml`).

```text
dnscrypt-proxy-webui/
│
├── Root files (14)
│   ├── VERSION                    # module version (v1.2.0)
│   ├── module.prop                # Magisk/KernelSU definition
│   ├── update.json                # auto-update metadata
│   ├── LICENSE                    # MIT
│   ├── README.md                  # project overview
│   ├── CHANGELOG.md               # version history (v1.0.0 → v1.2.0)
│   ├── CODE_OF_CONDUCT.md         # Contributor Covenant v2.1
│   ├── SECURITY.md                # security policy (summary)
│   ├── Makefile                   # unified commands
│   ├── .editorconfig              # editor rules
│   ├── .gitattributes             # Git attributes
│   ├── .gitignore                 # Git ignore
│   ├── .pre-commit-config.yaml    # pre-commit hooks
│   └── .secrets.baseline          # detect-secrets baseline
│
├── .github/ (12)
│   ├── CODEOWNERS                 # auto-assign reviewers
│   ├── dependabot.yml             # dependency updates
│   ├── SECURITY.md                # security policy (short)
│   ├── PULL_REQUEST_TEMPLATE.md   # default PR template
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── release.md             # release-specific PR template
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml         # bug report template
│   │   ├── config.yml             # issue template chooser
│   │   └── feature_request.yml    # feature request template
│   └── workflows/
│       ├── ci.yml                 # build matrix (4 architectures)
│       ├── codeql.yml             # SAST security scanning
│       ├── release.yml            # annotated tag release + sync main → develop
│       └── upgrade-test.yml       # 42-scenario data-preservation matrix (v1.2.0)
│
├── .devcontainer/ (2)
│   ├── devcontainer.json          # VS Code Dev Container config
│   └── setup.sh                   # auto-install dev tools
│
├── META-INF/ (2)
│   └── com/google/android/
│       ├── update-binary          # Magisk bootstrap (calls customize.sh)
│       └── updater-script         # "#MAGISK" marker
│
├── scripts/ (5)
│   ├── fetch_dns_binaries.sh      # DNS binaries fetcher (Level 4)
│   ├── generate-icons.sh          # PNG/ICO icon generator
│   ├── package_module.sh          # build the Magisk ZIP
│   ├── release.sh                 # stable / prerelease automation
│   └── release-patch.sh           # PATCH-only (hotfix) automation
│
├── proxy/ (14)
│   ├── action.sh                  # Magisk Action button handler
│   ├── build.sh                   # cross-compile (4 archs)
│   ├── customize.sh               # installer (10 data-preservation layers)
│   ├── dnscrypt-proxy.toml        # DNSCrypt engine config
│   ├── dnscrypt-proxy.version     # DNS engine version (2.1.18)
│   ├── functions.sh               # shared shell library (incl. backup helpers)
│   ├── go.mod                     # Go module definition
│   ├── main.go                    # HTTP server (Go 1.22)
│   ├── post-fs-data.sh            # early boot cleanup
│   ├── service.sh                 # boot service + periodic auto-backup
│   ├── status.sh                  # status display (+ --diagnose/--json)
│   ├── uninstall.sh               # cleanup + orphan txn preservation
│   ├── watchdog.sh                # standalone watchdog process (token auth)
│   └── webui.conf                 # WebUI/Dashboard config
│
├── web/ (13, bilingual: EN default + AR toggle)
│   ├── index.html                 # main UI
│   ├── dashboard.html             # monitoring dashboard
│   ├── manifest.json              # PWA manifest (lang=en, dir=ltr defaults)
│   ├── sw.js                      # service worker
│   ├── offline.html               # offline fallback
│   ├── icon-192.svg               # small icon (SVG)
│   ├── icon-512.svg               # maskable icon (SVG)
│   ├── icon-192.png               # small icon (PNG)
│   ├── icon-512.png               # maskable icon (PNG)
│   ├── apple-touch-icon.png       # iOS icon
│   ├── favicon-32x32.png          # modern favicon
│   ├── favicon-16x16.png          # legacy favicon
│   └── favicon.ico                # IE + bookmarks
│
└── docs/ (18)
    ├── API.md
    ├── ARCHITECTURE.md            # this file
    ├── BACKUP.md                  # v1.2.0
    ├── BRANCHING.md
    ├── COMPATIBILITY.md
    ├── CONTRIBUTING.md
    ├── DEVELOPMENT.md
    ├── DNS_BINARIES.md
    ├── EMERGENCY.md               # v1.2.0
    ├── FAQ.md
    ├── GLOSSARY.md
    ├── HALL_OF_FAME.md
    ├── INSTALL.md
    ├── RELEASE_PROCESS.md
    ├── ROADMAP.md
    ├── SECURITY.md
    ├── TROUBLESHOOTING.md
    ├── UPGRADE.md                 # v1.2.0
    └── adr/ (7)
        ├── README.md
        ├── 0001-two-branch-model.md
        ├── 0002-automated-releases.md
        ├── 0003-post-release-sync.md
        ├── 0004-unified-pr-template.md          (superseded)
        ├── 0005-release-specific-pr-template.md
        └── 0006-rename-hotfix-to-release-patch.md
```

### 8.3 File Count by Directory

| Directory | Files | Notes |
|---|:---:|---|
| Root | 14 | Version + config + governance + hidden configs |
| `.github/` | 12 | CI (incl. `upgrade-test.yml`) + templates + policies |
| `.devcontainer/` | 2 | Dev environment |
| **`META-INF/`** | **2** | **Magisk bootstrap (update-binary + updater-script)** |
| `scripts/` | 5 | Build + release tooling |
| `proxy/` | 14 | Go backend + shell scripts + configs |
| `web/` | 13 | HTML + PWA + SVG/PNG/ICO icons |
| `docs/` | 18 | Documentation guides |
| `docs/adr/` | 7 | Architecture Decision Records |
| **Total** | **87** | Tracked in the repository |

**Cross-check**: `README.md` §Project Structure states the same
total (87). The two files now agree.

### 8.4 META-INF Bootstrap

The `META-INF/com/google/android/` directory is the standard
Magisk / KernelSU / APatch entry point. It contains exactly two
files:

| File | Purpose |
|---|---|
| `update-binary` | Shell script. Magisk invokes it with `$2` = `OUTFD` (log fd) and `$3` = `ZIPFILE` (absolute ZIP path). The script sources `/data/adb/magisk/util_functions.sh` and calls `install_module`, which extracts the ZIP and runs the module's `customize.sh`. |
| `updater-script` | Single line: `#MAGISK`. Tells Magisk this is a Magisk module ZIP. Without it, Magisk treats the ZIP as a recovery-flashable update. |

**Non-responsibility**: `update-binary` contains **no** DNSCrypt
logic. All installer logic lives in `proxy/customize.sh`. This
separation is standard practice for Magisk modules:

- `META-INF/*` — bootstrap provided by the module format.
- `customize.sh` — project-specific installation.

**Failure mode**: If `update-binary` fails (e.g. Magisk < 20.4),
the installer aborts with a clear message and never reaches
`customize.sh`. No partial state is created.

**v1.2.0 note**: The META-INF files are unchanged from v1.0.0.
The 10 data-preservation layers introduced in v1.2.0 are not
visible to `update-binary` — they live entirely in
`customize.sh` and the other shell scripts.

### 8.5 Runtime Files (System)

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
| DNS Engine | `is_port_open 5354 udp` | ensure_running API (POST) with watchdog token |

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
                      with X-Watchdog-Token header
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
POST /api/ensure_running_service (with watchdog token)
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

**Scenario 5 (v1.2.0): Recovering from a corrupted config**

Recovery mode is **not** handled by the Watchdog. It is handled
by `customize.sh` at install time. See §3.10 and
`docs/EMERGENCY.md`.

The Watchdog's only interaction with the backup system is
**read-only**: at startup, it logs the current snapshot count
and `.last_stable` pointer. It never writes to the backup
directory.

### 9.4 Watchdog Token

See §4.5.1 and §5.7 for the token design and lifecycle.

The token is what makes the recovery path work in a locked-down
system where the user has not set explicit credentials. Without
it, `POST /api/ensure_running_service` returns 401 and the DNS
engine stays down until a manual restart.

### 9.5 State-integrity Guarantee

```text
┌──────────────────────────────────────────────────────────────┐
│  Guarantee:                                                  │
│  ──────────                                                  │
│  • STATUS_FILE is never written from a read-only fn.         │
│  • Watchdog restarts after crash (reliably).                 │
│  • Watchdog respects user stop.                              │
│  • Firewall state always matches STATUS_FILE.                │
│  • BLOCKLIST always consistent (after RACE-1).               │
│  • Memory limit always matches active profile (v1.1.0).      │
│  • Backup layer never blocks a user action (v1.2.0).         │
│  • Recovery mode always restores all 5 user files            │
│    (v1.2.0 — see §3.10).                                     │
│  • Watchdog never writes to the backup directory.            │
│  • `current/` is never left in an empty state                │
│    (BUG-CS-B atomic update).                                 │
│  • Snapshot directory names are unique per second            │
│    (PID suffix, BUG-CS-C / BUG-E / FSH-10 / ACT-5).          │
│                                                              │
│  Implementation:                                             │
│  ───────────────                                             │
│  • main.go: getStatusUncached read-only                      │
│  • main.go: rebuildBlocklist protected by rebuildMu          │
│  • main.go: applyMemoryLimit called on startup + change      │
│  • main.go: createAutoBackup best-effort + rotation          │
│  • main.go: cleanupOldTransactions preserves START           │
│  • main.go: watchdog token verified in constant time         │
│  • customize.sh: [9b2] re-applies recovery snapshot          │
│  • customize.sh: create_persistent_backup returns 1 on 0     │
│  • customize.sh: [19b] pre-generates the watchdog token      │
│  • customize.sh: atomic current/ via tmp+mv                  │
│  • service.sh: STATUS_FILE = OFF only on disable             │
│  • watchdog.sh: read-only w.r.t. backups                     │
│  • watchdog.sh: sends X-Watchdog-Token header                │
└──────────────────────────────────────────────────────────────┘
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
- Setting the limit too high → RAM waste.

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
| `applyMemoryLimit` (v1.1.0) | ~10 ns |
| `rebuildBlocklist` (with rebuildMu) | same values |
| **`createAutoBackup` (delegated) (v1.2.0)** | **~100–300 ms wall, negligible CPU** |
| **`buildBackupInfo` (v1.2.0)** | **~1–3 ms with ≤ 21 snapshots** |
| **`cleanupOldTransactions` (v1.2.0)** | **~1 ms per `COMMIT`'d txn, runs once** |
| **`checkPendingNotifications` (v1.2.0)** | **<100 µs, runs once** |
| **`verifyWatchdogToken` (v1.2.0)** | **<5 µs (one file read + constant-time compare)** |

### 10.3 Disk I/O

| Operation | I/O |
|---|---|
| `atomicWriteFile` | tmp + fsync + rename |
| `atomicWriteStream` | 64 KB buffer |
| Log rotation | 1 MB threshold |
| Session GC | 30 min interval |
| `isRunDirUsable` | cache 30 s |
| `getMonitoringAuth` | cache 60 s |
| **`createAutoBackup` (v1.2.0)** | **reads 5 files + writes 5 files + SHA256 per file + rotation ls + rm -rf** |
| **`buildBackupInfo` (v1.2.0)** | **`ReadDir` + `Info()` + `ReadFile(.last_stable)`** |
| **`rotate_backups` (v1.2.0)** | **`rm -rf` on old snapshots — at most ~21 dirs** |
| **`getWatchdogToken` (v1.2.0)** | **1 file read (no cache) per API call** |

### 10.4 Network

| Connection | Timeout |
|---|---|
| Download blocklist | 300 s |
| HTTP API request | 15 s |
| SSE WriteTimeout | 30 s per flush |
| SSE keepalive | 15 s |
| DNS query | 5 s |
| DNS binaries download | 30 s + retry |
| **Watchdog API call (curl)** | **5 s (`--max-time 5`)** |

### 10.5 Dashboard Metrics Pipeline

| Stage | Time |
|---|---|
| `GET /metrics` (monitoring_ui) | ~5–15 ms |
| `io.ReadAll(body)` | ~0.1 ms |
| `parsePrometheus` | ~50 µs |
| `buildDashboardJSON` | ~5 µs |
| `json.Encode` | ~20 µs |
| **Total** | **~5–15 ms** |

**With Auth Cache (NEW-6)**:
- Before: `getMonitoringAuth` took ~5–10 ms (file I/O).
- After: cache hit → ~0.05 ms.

### 10.6 Backup Storage (v1.2.0)

| Metric | Value |
|---|---|
| Size per snapshot | ~30–100 KB (5 config files) |
| Total with rotation (21 snapshots) | ~2 MB max |
| Backup duration | < 5 s wall |
| Restore duration | < 3 s |
| Rotation policy | Keep 21 newest by directory name |
| Pre-critical backup frequency | On every destructive write |
| Periodic backup interval | 24 h (service.sh) |

**Observability**:

```bash
# Effective limit for the active profile
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'

# Active profile key
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'

# Backup state (7 fields)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

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
| **Backup pipeline** | **✓** | Possible | **Shell** (v1.2.0) |

### 11.2 Streaming vs Load-All

**Decision**: Streaming.
**Reason**: 500K lines × ~50 bytes = 25 MB. Load-all → 150 MB peak. Streaming → 2 MB.

### 11.3 Atomic vs Direct

**Decision**: Atomic (`tmp` + `fsync` + `rename`).

### 11.4 Watchdog: subshell vs standalone

**Decision**: standalone (`watchdog.sh` file).
**Reason**: `$$` in a subshell = parent PID. `$$` in a standalone file = real PID.

### 11.5 State: get-modify-set vs atomic

**Decision**: atomic (full lock).

### 11.6 SSE: WriteTimeout=0 vs SetWriteDeadline

**Decision**: `WriteTimeout=0` + `SetWriteDeadline(30 s)` per flush.

### 11.7 Custom Chains vs Direct OUTPUT

**Decision**: Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`).

### 11.8 STATUS_FILE: state vs intent

**Decision**: `STATUS_FILE` = "user intent" only.

### 11.9 Section-restricted TOML

**Decision**: read `[monitoring_ui]` only.

### 11.10 Single source of truth for DNS version

**Decision**: `proxy/dnscrypt-proxy.version` is the single source.

### 11.11 Delegation vs Inline

**Decision**: centralized script (`fetch_dns_binaries.sh`).

### 11.12 Multi-source fallback

**Decision**: 5 sources for DNS binaries.

### 11.13 Platform-agnostic shell

**Decision**: `getSystemShell()` instead of hardcoded `/system/bin/sh`.

### 11.14 Prometheus → JSON vs Raw Proxy

**Decision**: convert inside `metricsProxyHandler`.

### 11.15 Exact endpoint matching

**Decision**: `hasEndpoint(path, name)`.

### 11.16 Per-port cache

**Decision**: `map[int]portCacheEntry`.

### 11.17 Preserve settings on upgrade

**Decision (v1.0.0)**: backup before `unzip -o` + restore after.
**Superseded by** §11.25 (v1.2.0 — multi-source discovery).

### 11.18 Login POST-only

**Decision**: `/api/auth/login` and `/api/auth/logout` POST only.

### 11.19 rebuildMu — Coarse-grained vs Fine-grained

**Decision**: single `sync.Mutex` covering `rebuildBlocklist`.

### 11.20 runtime_info ports — Coarse vs Granular

**Decision**: `buildRuntimeInfo()` returns `webui_port` + `dashboard_port` in the same response.

### 11.21 Auth cache — Cache vs No Cache

**Decision**: cache 60 s in `getMonitoringAuth`, but **only
non-empty results** (BUG-C fix).

### 11.22 v1.1.0 — Dynamic vs Static Memory Limit

**Decision**: dynamic, per-profile soft limit.

**Chosen limits (MB)**:

| Profile | Limit | Reason |
|---|---:|---|
| light | 80 | 1 GB devices |
| normal | 100 | 2 GB devices |
| pro | 120 | 3 GB devices |
| proplus | 160 | 4 GB devices |
| ultimate | 220 | 6 GB+ devices |

### 11.23 v1.1.0 — Extended shellQuote vs Minimal Set

**Decision**: extend `shellQuote()` to also cover `{`, `}`, `\n`, `\t`.

### 11.24 v1.1.0 — Constant vs Hardcoded Reserved Port

**Decision**: use `MONITORING_UI_PORT` in `metricsProxyHandler`.

### 11.25 v1.2.0 — "Search Everywhere" vs "Detect Upgrade"

**Decision**: search for user data in **7 candidate locations**
(9 on APatch); do not ask whether this is an upgrade.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Path-comparison check (`$_EXISTING_MODULE != $MODPATH`) | silently fails on in-place upgrades — the original v1.1.0 bug |
| Read `VERSION` from the module folder | also fails when the folder was renamed |
| Only look in `/sdcard/dnscrypt-webui-backup/` | fails on first upgrade from v1.1.0 (no backup yet) |
| Only look in the current `$MODPATH` | fails after APatch deletes the module folder |
| **Multi-source candidate list (7 / 9)** | ✅ robust to renames, reinstalls, root-solution differences |

### 11.26 v1.2.0 — Persistent Backup vs tmp Backup

**Decision**: back up to `/sdcard/dnscrypt-webui-backup/`.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep `/data/local/tmp/` (v1.1.0 behavior) | cleared on reboot; lost before the user can use it |
| `/data/adb/modules/dnscrypt-proxy-webui/` | deleted on uninstall |
| Cloud / external storage | violates Zero-Telemetry + Localhost-Only |
| **`/sdcard/`** | ✅ survives reboot, uninstall, and `/data` reset |

### 11.27 v1.2.0 — Transactional Install vs Best-Effort Restore

**Decision**: transactional install with rollback + preserved
`orphan-txn-*` directories.

### 11.28 v1.2.0 — Bilingual WebUI (EN default + AR toggle) vs English-only

**Decision**: ship the WebUI with **English as the default
language** and an **in-page toggle to switch to Arabic**.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| English-only WebUI | Removes first-class access for Arabic-speaking users |
| Arabic-only WebUI | Removes the canonical default |
| Always render both languages | Doubles the DOM size; slower first paint |
| Server-side language detection | Adds server state; violates Localhost-First |
| **Client-side toggle with `localStorage`** | ✅ no server state; instant switch; zero API impact |

### 11.29 v1.2.0 — Watchdog Token vs Localhost Bypass

**Decision**: replace the localhost bypass on
`/api/ensure_running_service` with a token.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep the localhost bypass | CSRF exploitable from any page in a browser on the device |
| Require full user credentials for the watchdog | The user may not have set them; and the rate limiter would lock the watchdog out |
| Bind the watchdog endpoint to a different port | More moving parts; no clear security benefit over a token |
| **Token file (0600) + `X-Watchdog-Token`** | ✅ constant-time; localhost-scoped; not rate-limited |

### 11.30 v1.2.0 — Unique Snapshot Names vs `<ts>-<version>`

**Decision**: append `-<pid>` (and, for pre-critical backups, a
short random suffix) to snapshot directory names.

**Reason**: `date +%Y%m%d-%H%M%S` has second precision. Without
a PID suffix, two concurrent backups started in the same second
would write to the same directory. The added suffix:

- Is compatible with the rotation regex
  `^[0-9]{8}-[0-9]{6}-` (still matches).
- Is compatible with `buildBackupInfo`'s lexicographic sort.
- Is compatible with `.last_stable` (stores the full name).

Applied consistently in:

- `customize.sh` (BUG-CS-C)
- `main.go:createAutoBackup` (BUG-E)
- `functions.sh:backup_user_files` (FSH-10)
- `functions.sh:auto_backup_if_needed` (FSH-10)
- `action.sh:_inline_backup_now` (ACT-5)

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
saveAllowlist()
    │
    ├──► createAutoBackup("pre-allowlist-save")   ← v1.2.0
    │       → functions.sh:backup_user_files()
    │       → snapshot to /sdcard/dnscrypt-webui-backup/
    │       → functions.sh:rotate_backups 21
    │       (best-effort: failure does not block the save)
    │
    ▼
atomicSaveRulesInternal
    │
    ├──► rulesStateMu.Lock()
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
    │       ├── atomicWriteStream(BLOCKLIST_FILE)
    │       └── defer rebuildMu.Unlock()
    │
    ├──► currentRules = rulesStateSnapshot{...}
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

`rebuildBlocklist` uses `bufio.Scanner` with
`Buffer(64KB, 1MB)`.

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
| **pre-critical backup fails (v1.2.0)** | **logged as warning; write proceeds** |
| **rotation fails (v1.2.0)** | **logged as warning; write proceeds** |

### 12.7 Notes for Contributors

When adding a new filtering feature:
1. ✅ **Do** — add it in `main.go` (Go-native)
2. ❌ **Don't** — rewrite filtering logic in Shell
3. ✅ **Do** — use `atomicWriteStream` for writes
4. ✅ **Do** — keep `rulesStateMu` as the single state lock
5. ✅ **Do** — use `rebuildMu` for every `rebuildBlocklist`
6. ❌ **Don't** — use `getRulesState` → modify → `setRulesState`

### 12.8 `append_denylist` — Known Limitation

`POST /api/append_denylist` **requires a `content` parameter**
(BUG-A fix in v1.2.0). Without it, the endpoint returns:

```json
{"status": "error", "message": "Missing or empty 'content' parameter"}
```

When called **with** `content`, the endpoint:

1. Reads the current `denylist.txt`.
2. Appends the content (newline-normalized).
3. Calls `saveDenylist()` — which triggers the pre-critical
   backup (reason: `"pre-denylist-save"`) and the blocklist
   rebuild.
4. Returns the resulting entry count.

**Historical note**: In earlier drafts of v1.2.0, the endpoint
took no arguments and re-saved the current denylist unchanged,
producing a "no-op" that still consumed a pre-critical backup.
That behavior has been removed. Callers that relied on it (if
any) must now send a `content` parameter.

**Consumer note for the WebUI**: The current WebUI does not yet
send a `content` parameter. Callers should either:
- Provide `content` via the API, or
- Use `POST /api/save_denylist` with the full new content.

The WebUI-side update to use `append_denylist` with content is
planned for v1.2.1 or v1.3.0.

---

## 13. Firewall Architecture — Custom Chains

### 13.1 Original Problem (Orphaned Rules Leak)

Before the Custom Chains change, `manage_iptables` added dynamic
`RETURN` rules directly into `OUTPUT`:

```text
┌──────────────────────────────────────────────────────────────┐
│  OUTPUT (nat) — before                                       │
│                                                              │
│  1. -d 127.0.0.1 -p udp --dport 53 -j RETURN  ← dyn          │
│  2. -d 127.0.0.1 -p tcp --dport 53 -j RETURN  ← dyn          │
│  3. -d 9.9.9.9   -p udp --dport 53 -j RETURN  ← dyn          │
│  ...                                                         │
└──────────────────────────────────────────────────────────────┘
```

**Catastrophic scenario**:

| Event | Result |
|---|---|
| Day 1: TOML = [9.9.9.9, 8.8.8.8] | rules 9.9.9.9 and 8.8.8.8 |
| Day 2: TOML = [1.1.1.1] | 9.9.9.9 and 8.8.8.8 orphans ❌ |
| After 10 changes | 40+ orphan rules |

### 13.2 Solution — Custom Chains

```text
┌──────────────────────────────────────────────────────────────┐
│  OUTPUT (nat) — after                                        │
│                                                              │
│  1. -p udp --dport 53 -j DNSCRYPT_OUT   ← static             │
│  2. -p tcp --dport 53 -j DNSCRYPT_OUT   ← static             │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               │ jump
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  DNSCRYPT_OUT (nat) — Custom Chain                           │
│                                                              │
│  1. -d 127.0.0.1 -j RETURN    ← dynamic (safe)               │
│  2. -d 9.9.9.9   -j RETURN    ← dynamic (safe)               │
│  3. -d 8.8.8.8   -j RETURN    ← dynamic (safe)               │
│  4. -j DNAT --to-destination 127.0.0.1:5354                  │
│                                                              │
│  Cleanup: -F DNSCRYPT_OUT + -X DNSCRYPT_OUT                  │
└──────────────────────────────────────────────────────────────┘
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
┌──────────────────────────────────────────────────────────────┐
│  functions.sh                                                │
│    ├── manage_iptables()   → DNSCRYPT_OUT                    │
│    ├── manage_ip6tables()  → DNSCRYPT_OUT6                   │
│    ├── manage_nftables()   → dnscrypt_filter (table)         │
│    ├── _legacy_cleanup_iptables()                            │
│    └── _legacy_cleanup_ip6tables()                           │
├──────────────────────────────────────────────────────────────┤
│  post-fs-data.sh → inline_firewall_cleanup()                 │
│  uninstall.sh → _inline_cleanup_firewall()                   │
│  customize.sh → _inline_cleanup_firewall()                   │
│  main.go → startService() / stopService()                    │
└──────────────────────────────────────────────────────────────┘
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
The public `OUTPUT` must always remain clean.

---

## 14. DNS Binaries Management

See [`DNS_BINARIES.md`](DNS_BINARIES.md) for the full document.

### 14.1 Philosophy

Before Level 4, the project suffered from:

| Problem | Impact |
|---|---|
| **Embedded URLs** | GitHub format change → silent failure |
| **Duplicated version** | potential drift |
| **`i386` vs `x86`** | different names → conflict |
| **No SHA256** | no integrity check |
| **No cache** | fresh download per build |
| **No fallback** | GitHub failure → build failure |
| **Slow CI** | ~30 s per release |
| **No retry** | transient failure → workflow failure |

### 14.2 Principles

| Principle | Implementation |
|---|---|
| **Single Source of Truth** | `proxy/dnscrypt-proxy.version` |
| **Delegation** | `scripts/fetch_dns_binaries.sh` |
| **Multi-Source Fallback** | 5 sequential sources |
| **SHA256 Verification** | binary integrity check |
| **Local Cache** | `~/.cache/...` |
| **Offline Mode** | build without internet |
| **Retry Logic** | `curl --retry 2` + 5-source fallback |

### 14.3 Main Components

```text
┌──────────────────────────────────────────────────────────────┐
│  [1] Single Source of Truth                                  │
│      proxy/dnscrypt-proxy.version → "2.1.18"                 │
└──────────────────────────────┬───────────────────────────────┘
                               │
              ┌────────────────┼───────────────┬─────────────┐
              ▼                ▼               ▼             ▼
        ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
        │ fetch_   │    │ package_ │    │ release  │    │ ci.yml   │
        │ dns_     │    │ module.sh│    │ .yml     │    │ (verify) │
        │ binaries │    │          │    │          │    │          │
        │ .sh      │    │          │    │          │    │          │
        └──────────┘    └──────────┘    └──────────┘    └──────────┘
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

| Source | Name |
|---|---|
| GitHub (dnscrypt-proxy) | `i386` |
| Staging (customize.sh) | `x86` |

**Solution**: `map_to_cache_name()` in `package_module.sh`.

### 14.7 SHA256 Verification

```text
┌──────────────────────────────────────────────────────────────┐
│  On fetch:                                                   │
│   1. download binary                                         │
│   2. compute SHA256                                          │
│   3. save in .manifest.json                                  │
└──────────────────────────────┬───────────────────────────────┘
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  On use:                                                     │
│   1. read SHA from manifest                                  │
│   2. compute actual SHA                                      │
│   3. compare                                                 │
│   ✅ → use                                                   │
│   ❌ → re-fetch                                              │
└──────────────────────────────────────────────────────────────┘
```

### 14.8 Retry Logic

```bash
# Two layers:
# 1) curl --retry 2 --retry-delay 1 (per URL, inside download_url)
# 2) 5-source fallback chain (in build_candidate_urls)
```

### 14.9 Version Update

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
| Inline code | duplication |
| Shared shell library | complexity |
| **standalone script** | ✅ clear, easy to test |

#### Why 5 sources?

| Alternative | Problem |
|---|---|
| GitHub API only | fails on rate limit |
| GitHub Releases only | fails on format change |
| Cache only | fails on first build |
| **5 sequential sources** | ✅ 99.9% reliability |

### 14.11 Notes for Contributors

1. ✅ **Do** — use `proxy/dnscrypt-proxy.version`.
2. ✅ **Do** — use `fetch_dns_binaries.sh`.
3. ✅ **Do** — use `map_to_cache_name` for i386/x86.
4. ❌ **Don't** — embed the DNS version anywhere else.
5. ❌ **Don't** — write URLs manually.
6. ❌ **Don't** — skip SHA256 verification.

**Golden rule**:
> **Never embed the DNS version anywhere — always use
> `proxy/dnscrypt-proxy.version`.**

---

## 15. Platform Abstraction

### 15.1 Problem

The code relied only on Android paths:

| Path | Android | Linux | macOS |
|---|:---:|:---:|:---:|
| `/system/bin/sh` | ✅ | ❌ | ❌ |
| `/bin/sh` | ⚠️ | ✅ | ✅ |
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
        systemShellPath = "sh"
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

---

## 16. Metrics Abstraction

### 16.1 Problem

**Upstream incompatibility**:
- `monitoring_ui` (dnscrypt-proxy) returns **Prometheus text format**.
- `dashboard.html` expects **JSON**.
- Upstream cannot be modified.

### 16.2 Solution — Adapter Pattern

```text
┌──────────────────────────────────────────────────────────────┐
│  Client Layer                                                │
│  (dashboard.html)                                            │
│  expects: JSON                                               │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Adapter Layer                                               │
│  (metricsProxyHandler)                                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  1. HTTP GET /metrics (via MONITORING_UI_PORT)         │  │
│  │  2. parsePrometheus(text) → map[string]float64         │  │
│  │  3. buildDashboardJSON(map) → map[string]any           │  │
│  │  4. json.Encode(response)                              │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Upstream Layer                                              │
│  (monitoring_ui :8080)                                       │
│  returns: Prometheus text                                    │
└──────────────────────────────────────────────────────────────┘
```

**v1.1.0 (MEM-3)**: The URL now uses the `MONITORING_UI_PORT`
constant. Behavior is unchanged.

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

### 16.7 v1.1.0 + v1.2.0 — Exposing Profile, Memory, and Backups

`runtime_info` carries fields that the Dashboard and WebUI
surface in the System Info panel.

**v1.1.0 fields**:

```json
{
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

**v1.2.0 fields (BAK-1)**:

```json
{
  "backups": {
    "available": 7,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-09-26 15:00:00",
    "last_backup_name": "20260926-150000-manual-1234",
    "last_stable": "20260926-095826-v1.2.0-5678",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

**Where these come from**:

| Field | Source | Type |
|---|---|---|
| `profile_key` | `readSelectedProfile()` (file read) | string |
| `memory_limit_mb` | `memoryLimitForProfile(currentProfile) / (1024*1024)` | int |
| `available` | `len(snapshots)` | int |
| `in_flight_txn` | count of `txn-*` directories | int |
| `orphan_txn` | count of `orphan-txn-*` directories | int |
| `last_backup` | mtime of the newest snapshot | string \| null |
| `last_backup_name` | name of the newest snapshot | string \| null |
| `last_stable` | content of `.last_stable` | string \| null |
| `path` | `$PERSISTENT_BACKUP` | string |

**Why expose them**:

- **Observability** — a user reporting a GC, performance, or
  backup issue can paste the runtime_info output.
- **Verification** — the System Info panel in both WebUI and
  Dashboard displays the effective values.
- **Consistency** — the `backups` object shares its 7 fields
  with `status.sh --json`.
- **No extra cost** — every field is a simple operation on
  data already in memory (or one `ReadDir` + one `ReadFile`).

**Shell equivalent**:

- `functions.sh:get_profile_memory_hint()` → `"120 MB (pro)"`.
- `status.sh --json` → same 7-field `backups` object plus
  `status` and `last_backup_age_seconds`.

---

## Legend — Post-Release Fixes

| # | Description | Section |
|:-:|---|---|
| **A** | STATUS_FILE semantics | §4.8.1 |
| **B** | metricsProxyHandler /metrics | §4.8.2 |
| **C** | IPv6 client IP | §4.8.3 |
| **D** | Port Collision Guard | §4.8.4 |
| **E** | Section-restricted TOML | §4.8.5 |
| **G** | Exact key matching | §4.7.1 |
| **H** | recordLoginAttempt | §4.7.2 |
| **I** | isRunDirUsable cache | §4.7.3 |
| **J** | isPortOpen native Go | §4.7.4 |
| **K** | Asset Serving Fix | §4.7.5 |
| **M** | Metrics JSON conversion | §4.8.6 |
| **N** | getSystemShell fallback | §4.8.7 |
| **O** | Basic Auth rate limiting | §4.8.8 |
| **P** | Section header with comment | §4.8.9 |
| **Q** | Per-port cache | §4.8.10 |
| **R** | Exact endpoint matching | §4.8.11 |
| **S** | Login POST-only | §4.8.12 |
| **T** | readConfPort range check | §4.8.13 |
| **U** | /readyz localhost-only | §4.8.14 |
| **V** | shellQuote injection protection | §4.8.15 |
| **W** | Auth cache (60 s) | §4.8.16 |
| **X** | rebuildMu mutex (RACE-1) | §4.8.17 |
| **Y** | runtime_info ports (PORT-2) | §4.8.18 |
| **Z** | Preserve Settings on Upgrade | §4.8.19 |
| **MEM-1** | Dynamic memory limit per profile | §4.9.1 |
| **MEM-2** | Extended shellQuote charset | §4.9.2 |
| **MEM-3** | MONITORING_UI_PORT in metrics handler | §4.9.3 |
| **BAK-1** | `buildBackupInfo()` — 7-field schema | §4.10.1 |
| **BAK-2** | `createAutoBackup(reason string)` + rotation | §4.10.2 |
| **BAK-3** | `cleanupOldTransactions()` | §4.10.3 |
| **BAK-4** | `checkPendingNotifications()` | §4.10.4 |
| **WD-TOKEN** | Watchdog token (closes CSRF hole) | §4.5.1, §5.7 |
| **FSH-10** | PID suffix in default backup directory names | §5.4 |
| **FSH-11** | `get_watchdog_token()` helper | §5.4, §5.7 |
| **ACT-5** | PID suffix in `_inline_backup_now` | §5.4 |
| **BUG-A..L** | Post-audit corrections in `main.go` | §4.6.4, §4.11 |

### Official Fix Numbers

| # | Description | Reference |
|:-:|---|---|
| **Fix #1** | Dashboard JSON Conversion | §4.8.6 |
| **Fix #2** | Shell fallback (getSystemShell) | §4.8.7 |
| **Fix #3** | Preserve Settings on Upgrade | §4.8.19 |
| **Fix #4** | `.gitignore` negation | (outside ARCHITECTURE) |
| **Fix #5** | Pre-commit hooks fixed | (outside ARCHITECTURE) |
| **Fix #6** | Asset Serving Fix | §4.7.5 (K) |
| **Fix #7** | CodeQL config drift | (outside ARCHITECTURE) |
| **Fix #8** | Basic Auth Rate Limiting | §4.8.8 |
| **Fix #9** | `fuser` PID parsing | (outside ARCHITECTURE) |
| **Fix #10** | Section header with comment | §4.8.9 |
| **Fix #11** | Per-port cache | §4.8.10 |
| **Fix #12** | Exact endpoint matching | §4.8.11 |
| **NEW-1** | Login POST-only (CSRF) | §4.8.12 |
| **NEW-2** | hasEndpoint usage | (merged in Fix #12) |
| **NEW-3** | readConfPort range check | §4.8.13 |
| **NEW-4** | /readyz localhost-only | §4.8.14 |
| **NEW-5** | shellQuote injection protection | §4.8.15 |
| **NEW-6** | Auth cache (60 s) | §4.8.16 |
| **RACE-1** | rebuildMu mutex | §4.8.17 |
| **PORT-2** | runtime_info ports | §4.8.18 |
| **MEM-1** | Dynamic memory limit per profile | §4.9.1 |
| **MEM-2** | Extended shellQuote charset | §4.9.2 |
| **MEM-3** | MONITORING_UI_PORT in metrics handler | §4.9.3 |
| **BAK-1** | buildBackupInfo 7-field schema | §4.10.1 |
| **BAK-2** | createAutoBackup + rotation | §4.10.2 |
| **BAK-3** | cleanupOldTransactions | §4.10.3 |
| **BAK-4** | checkPendingNotifications | §4.10.4 |
| **WD-TOKEN** | Watchdog token | §4.5.1, §5.7 |
| **FSH-10** | PID suffix in backup names | §5.4 |
| **FSH-11** | get_watchdog_token | §5.4, §5.7 |
| **ACT-5** | PID suffix in inline backup | §5.4 |
| **BUG-A..L** | main.go post-audit corrections | §4.6.4, §4.11 |

> **v1.2.0 note**: BAK-1..BAK-4, MEM-1..MEM-3, WD-TOKEN,
> FSH-10, FSH-11, and ACT-5 are not audit corrections — they
> close edge cases and security holes rather than fix known
> exploitable vulnerabilities in earlier v1.2.0 drafts.
> See `docs/SECURITY.md` §17.1 and §5.31 for the distinction.

---

## References

- [CHANGELOG.md](../CHANGELOG.md) — version history
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/API.md](API.md) — HTTP API Reference
- [docs/BACKUP.md](BACKUP.md) — Backup System Reference (v1.2.0)
- [docs/EMERGENCY.md](EMERGENCY.md) — Emergency Recovery (v1.2.0)
- [docs/UPGRADE.md](UPGRADE.md) — Version Upgrade Guide (v1.2.0)
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
- [Magisk — Module Structure](https://topjohnwu.github.io/Magisk/guides.html)

---

**Last updated**: 2026-10-02
**Version**: v1.3.0
**Author**: gasciljh