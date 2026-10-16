# Architecture — DNSCrypt Smart Filter

Comprehensive architecture document explaining how the system works internally.

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-15
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.5.0 changes**:
>   • **Layered Bootstrap (Phase 0)**: shell primitives extracted
>     into `proxy/boot-mini.sh` (Layer 0) and consumed by
>     `proxy/functions.sh` (Layer 1). See §1.2, §2.1, §2.2, §5.0,
>     §8.1, §8.2, and `docs/adr/0008-layered-bootstrap.md`.
>   • **Companion app one-tap install (IDX-24)**: the WebUI install
>     button now opens an **install-method modal** offering
>     **three actions across two categories**:
>       (1) **Install locally** — POST `/api/install_companion_app`
>           with a one-shot CSRF token; the server runs
>           `proxy/install_app.sh` — a 5-level `pm install` cascade.
>       (2) **Open GitHub page** — external URL.
>       (3) **Direct download from GitHub** — external URL.
>     See §3.11, §4.14, and §5.8.
>   • **New shell script** `install_app.sh` (1,101 lines, staged at
>     the module root) — 5-level `pm install` cascade with SELinux
>     staging, Play Protect temporary disable, SHA256 verification,
>     per-IP rate limiting, and AR + EN error translation. See §5.8.
>   • **Four new backend endpoints** in `proxy/main.go`:
>       - `POST /api/install_companion_app`
>       - `POST /api/uninstall_companion_app`
>       - `GET  /api?action=install_token`
>       - `GET  /api?action=companion_app_state`
>     See §4.2 and §4.14.
>   • **New concurrency primitives**: `installTokens` and
>     `installAttempts` mutexes. See §4.3.
>   • **Frontend state fixes** (`web/index.html` and `web/dashboard.html`):
>       - IDX-23 — companion button state survives language toggles.
>       - IDX-23b — status card updates instantly on language toggle.
>       - IDX-25 / IDX-25a — Dashboard section-nav buttons scroll
>         correctly with a centered hint toast.
>     See §6.9 and §6.10.
>   • **File count**: **97 tracked files** + **0-11 build artifacts**
>     (all gitignored). Working-tree total: **97-108 files** across
>     **15-18 directories**. See §8.2 and §8.3.
>   • **MANIFEST_NOTES.md (v1.5.0)** — new file consolidating every
>     `x-note-*` technical detail extracted from
>     `web/manifest.json`. See §8.2 and §17.
>   • **Cross-file coordination**: `customize.sh §[9]` extracts
>     `install_app.sh` and `boot-mini.sh`; `main.go`'s `R3-01`
>     doc-comment refreshed. See §4.6.7, §5.8, and §8.1.
>   • No breaking changes to the 7-field `runtime_info.backups`
>     schema. No breaking changes to the 10 defensive layers. No
>     breaking changes to the watchdog token model.

> **v1.5.0+ post-release patches**:
>   See §17 — Documentation Corrections to This File for the
>   consolidated table.
>
>   Highlights:
>   • `install_app.sh` line count: **1,101** (canonical).
>   • File counts: **97 tracked**, **+7** added in v1.5.0,
>     **18** in `proxy/`, **19** in `docs/`.
>   • `docs/adr/0008-layered-bootstrap.md` and
>     `docs/MANIFEST_NOTES.md` added to the tree.
>   • §5.8.4 trap snippet matches `install_app.sh` (trap installed
>     BEFORE the `settings put`, not inside the `if` block).
>   • All `MAN-TRIM-CHANGELOG` references removed.

> **v1.4.0 changes** (historical):
>   • Companion Android app integrated — `web/app-debug.apk` is now
>     bundled into the module ZIP as an OPTIONAL build artifact.
>   • `removeModule` hardened against CodeQL `go/path-injection`.
>   • iOS PWA logic removed from `web/index.html` (Android-only).
>   • **File count**: 89 tracked files + 1 build artifact.

> **v1.3.0 changes** (historical):
>   • Client-side features: PWA install button + live status LED.
>   • Boot-path correctness fix (`service.sh`): DNS auto-start.
>   • Server-side refinements (see §4.13): SNAP-MANIFEST +
>     SNAP-MTIME; ROT-*.

> **v1.2.0 changes** (historical):
>   • Global edition — English default + Arabic toggle.
>   • Added §3.10 (Backup & Restore Flow).
>   • Added §4.10 (v1.2.0 Backend Additions).
>   • Added §4.5.1 (Watchdog Token).

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
17. [Documentation Corrections to This File](#17-documentation-corrections-to-this-file)

---

## 1. Overview

### 1.1 Purpose

Turn an Android device into a **filtered, encrypted DNS server** without a VPN, via:

- Transparent redirection of DNS queries (port 53) → `127.0.0.1:5354`
- Full encryption (DNSCrypt / DoH)
- Ad / tracker blocking via updatable lists
- Web interface for control (bilingual: English default + Arabic toggle)
- **Persistent user-data preservation** across upgrades, renames, reinstalls, and uninstalls (v1.2.0)
- **Optional companion Android app** (v1.4.0) served at `/app-debug.apk`
- **One-tap root install for the companion app** (v1.5.0) via
  `install_app.sh`, with an install-method modal offering
  **three actions across two categories** (IDX-24)
- **Layered Bootstrap** (v1.5.0 Phase 0) — a two-file shell library
  with explicit Layer 0 / Layer 1 separation

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
| **Single Source of Truth** | `VERSION` + `module.prop` + `proxy/dnscrypt-proxy.version` + `proxy/app-apk.version` |
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
| **v1.2.0 — Multi-Source Discovery** | Search for user data everywhere |
| **v1.2.0 — Persistent Backup** | `/sdcard/dnscrypt-webui-backup/` survives uninstall + `/data` reset |
| **v1.2.0 — Transactional Upgrade** | Atomic install with rollback |
| **v1.2.0 — Recovery Mode (snapshot-and-reapply)** | Trigger file restores last known-good config **after** the ZIP extraction step |
| **v1.2.0 — Bilingual WebUI** | English default + Arabic toggle, client-side only |
| **v1.2.0 — Atomic `current/`** | `.current.tmp.$$` + `.current.old.$$` + `mv` |
| **v1.2.0 — Unique Snapshot Names** | `<ts>-<version>-<pid>` / `<ts>-manual-<pid>` / `<ts>-auto-<pid>` |
| **v1.3.0 — Manifest-Based Snapshot Detection** | A directory is a snapshot iff it contains `.manifest.json` |
| **v1.3.0 — mtime Sort** | Robust against clock drift and custom snapshot names |
| **v1.3.0 — Protected Snapshots** | `.last_stable` target and newest install are never pruned |
| **v1.3.0 — Boot-Path DNS Auto-Start** | `service.sh` performs a bounded wait + direct API call |
| **v1.4.0 — CodeQL Path-Injection Hardening** | `removeModule` uses `filepath.Base()` + `securejoin.SecureJoin` |
| **v1.4.0 — Optional Companion APK** | `web/app-debug.apk` served at `/app-debug.apk` |
| **v1.5.0 Phase 0 — Layered Bootstrap** | Layer-0 primitives extracted into `proxy/boot-mini.sh`; Layer-1 consumers in `proxy/functions.sh` |
| **v1.5.0 — Install-Method Modal (IDX-24)** | WebUI confirm modal offers three actions across two categories |
| **v1.5.0 — Root Install Cascade** | `install_app.sh` tries 5 `pm install` strategies in order |
| **v1.5.0 — SELinux Staging** | APK staged to `/data/local/tmp/` — SELinux never disabled |
| **v1.5.0 — Play Protect Temporary Disable** | Saved + restored via three-way trap; cascade bounded by 75 s deadline |
| **v1.5.0 — One-Shot CSRF Token** | 60-second TTL token for `install_companion_app` |
| **v1.5.0 — Per-IP Install Rate Limit** | 5 failed attempts / 15 min lockout |
| **v1.5.0 — Client State Survives Language Toggles (IDX-23)** | `companionState` is the single source of truth |
| **v1.5.0 — Instant Status-Card Language Update (IDX-23b)** | `renderAllDynamic()` funnels all language-sensitive elements |
| **v1.5.0 — Dashboard Section-Nav Fix (IDX-25)** | `updateNavLinks()` uses real card IDs |
| **v1.5.0 — Dashboard Centered Hint (IDX-25a)** | Toast centered in viewport |
| **v1.5.0 — Manifest Notes Extraction** | `x-note-*` bulk moved to `docs/MANIFEST_NOTES.md` |

### 1.3 Dependencies

| Component | Version | Purpose |
|---------|:-------:|-------|
| **Go** | 1.22 | Backend |
| **DNSCrypt-proxy** | 2.1.18 | DNS engine |
| **Magisk/KernelSU** | 20.4+ / 0.9+ | Module framework |
| **HaGeZi blocklists** | latest | Blocklists |
| **iptables/nftables** | — | DNS redirection |
| **DNS Binaries** | Level 4 | DNS binary management (5 fallback sources) |
| **Companion Android app** | 1.0.0 | Optional native WebView wrapper (`proxy/app-apk.version`) |
| **Android PackageManager** | API 21+ | `pm install` cascade for companion app (v1.5.0) |

DNSCrypt-proxy version is determined by `proxy/dnscrypt-proxy.version` — see [`DNS_BINARIES.md`](DNS_BINARIES.md).

Companion app version is determined by `proxy/app-apk.version` — see `scripts/fetch_app_apk.sh`.

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
│  │  ┌──────────────────┐    ┌─────────────────────────────┐     │  │
│  │  │  WebUI           │    │  DNSCrypt-proxy              │    │  │
│  │  │  (Go binary)     │◄───┤  (Go binary - upstream)      │    │  │
│  │  │  :9090           │    │  :5354                       │    │  │
│  │  │  :9091 Dashboard │    │  :8080 monitoring_ui         │    │  │
│  │  │  (JSON conversion)│    │  (Prometheus metrics)        │    │  │
│  │  │  + MEM-1          │    │                              │    │  │
│  │  │  + BAK-1          │    │                              │    │  │
│  │  │  + EN/AR toggle   │    │                              │    │  │
│  │  │  + /app-debug.apk │    │                              │    │  │
│  │  │  + install_app    │    │                              │    │  │
│  │  │    (4 endpoints)  │    │                              │    │  │
│  │  └────────┬─────────┘    └──────────────┬───────────────┘    │  │
│  │           │                              │                     │  │
│  │           │ HTTP/SSE                     │ DNS                 │  │
│  │           │                              │                     │  │
│  │  ┌────────▼──────────────────────────────▼───────────────┐    │  │
│  │  │           Shell Scripts (BusyBox sh)                   │    │  │
│  │  │  Layer 0: boot-mini.sh (5 primitives + constant)       │    │  │
│  │  │  Layer 1: functions.sh (sources boot-mini.sh)          │    │  │
│  │  │  Consumers: customize / service / action / status /    │    │  │
│  │  │             watchdog / uninstall / post-fs-data        │    │  │
│  │  │  manage_firewall → Custom Chains                       │    │  │
│  │  │  getSystemShell() fallback                             │    │  │
│  │  │  get_profile_memory_hint()  (v1.1.0)                   │    │  │
│  │  │  auto_backup_if_needed()    (v1.2.0)                   │    │  │
│  │  │  rotate_backups()           (v1.2.0, rewritten v1.3.0) │    │  │
│  │  │  copy_with_context()        (v1.2.0)                   │    │  │
│  │  │  backup_user_files()        (v1.2.0)                   │    │  │
│  │  │  restore_user_files()       (v1.2.0)                   │    │  │
│  │  │  get_watchdog_token()       (v1.2.0)                   │    │  │
│  │  │  install_app.sh             (v1.5.0 — 1,101 lines,     │    │  │
│  │  │                              cascade deadline = 75 s,   │    │  │
│  │  │                              EXIT/INT/TERM traps       │    │  │
│  │  │                              with exit 130/143)         │    │  │
│  │  └────────┬──────────────────────────────┬───────────────┘    │  │
│  │           │                              │                     │  │
│  │  ┌────────▼──────────┐    ┌──────────────▼─────────────┐      │  │
│  │  │  Watchdog          │    │  iptables / nftables       │      │  │
│  │  │  (standalone)      │    │  DNSCRYPT_OUT / _OUT6      │      │  │
│  │  │  reads STATUS      │    │  (Custom Chains)           │      │  │
│  │  │  DNS backoff       │    │                            │      │  │
│  │  │  uses token        │    │                            │      │  │
│  │  └────────────────────┘    └────────────────────────────┘      │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │           User Applications                                   │  │
│  │  (Chrome, Games, Apps → :53 → 127.0.0.1:5354)                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │       Persistent Backup Store (v1.2.0, extended v1.5.0)       │  │
│  │  /sdcard/dnscrypt-webui-backup/                               │  │
│  │    ├── current/                (live snapshot)                │  │
│  │    ├── <timestamp>-<version>-<pid>/                           │  │
│  │    ├── <timestamp>-manual-<pid>/                              │  │
│  │    ├── <timestamp>-auto-<pid>/                                │  │
│  │    ├── txn-*  /  orphan-txn-*  (transactions)                 │  │
│  │    ├── apk/                    (v1.5.0 — APK mirror)          │  │
│  │    │   ├── app-debug.apk                                      │  │
│  │    │   └── app-debug.apk.sha256                               │  │
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
| **main.go** | Go | HTTP API, SSE, auth, blocklist management, Prometheus → JSON, dynamic memory limit, auto-backup triggers (v1.2.0), rotation after pre-critical backup (v1.2.0), transaction cleanup (v1.2.0), `backups` runtime_info field (v1.2.0), watchdog token generation (v1.2.0), manifest-based snapshot detection + mtime sort (v1.3.0), `/app-debug.apk` route (v1.4.0), CodeQL path-injection hardening in `removeModule` (v1.4.0), 4 companion-app endpoints + 10 helpers (v1.5.0), three-layer logger split, port cache for `getWebUIPort` / `getDashboardPort` |
| **install_app.sh** | Shell (BusyBox) | 5-level `pm install` cascade (v1.5.0), SELinux staging to `/data/local/tmp/`, Play Protect temporary disable (cascade bounded by 75 s deadline), SHA256 verification, AR + EN error translation, `--status` / `--uninstall` / `--help` / `--version` modes. Staged at the **module root** (next to `customize.sh`), not under `proxy/`. Three-way signal-trap split with exit 130/143. 1,101 lines. |
| **boot-mini.sh** | Shell (BusyBox) | **Layer 0 primitives (v1.5.0 Phase 0)**: `log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`, `_MONITORING_UI_PORT`. Zero dependencies. Single source of truth for the reserved port constant. |
| **dnscrypt-proxy** | Go (upstream) | The actual DNS engine |
| **Companion Android app** | Kotlin (separate repo) | Native WebView wrapper (`web/app-debug.apk`, optional, v1.4.0) |
| **Shell scripts** | sh | Install, launch, watchdog, firewall, memory hint, backup/restore (v1.2.0), rotation rewrite (v1.3.0), recovery mode (v1.2.0), SELinux context preservation (v1.2.0), watchdog token reader (v1.2.0), APK mirror (v1.5.0) |
| **META-INF bootstrap** | sh | Magisk/KernelSU entry point |
| **index.html** | HTML+JS | Main interface (bilingual: EN default + AR toggle). Install-method modal (v1.5.0, IDX-24). IDX-23 + IDX-23b fixes (v1.5.0). IDX-429 + IDX-401-DISTINCT fixes (v1.5.0+) |
| **dashboard.html** | HTML+JS | Monitoring dashboard (bilingual: EN default + AR toggle). Section-nav fix (IDX-25) + centered hint (IDX-25a) (v1.5.0). DASH-REFRESH-01 + DASH-SESSION-RETRY-01 + DASH-HINT-01 + DASH-HINT-02 fixes (v1.5.0+) |
| **sw.js** | JS | Service Worker (PWA), language-neutral, `CACHE_VERSION=v1.5.0` |
| **manifest.json** | JSON | PWA manifest (`version=1.5.0`, 6 `x-note-*` fields) |
| **docs/MANIFEST_NOTES.md** | Markdown | Consolidated reference for every `x-note-*` field extracted from `manifest.json` (v1.5.0) |

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
│      │      → v1.3.0: manifest-based detection
│      │      → v1.3.0: mtime sort, descending
│      │      → v1.3.0: preserves .last_stable + newest install
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
│      ├──► rebuildMu.Lock()
│      ├──► read allowlist.txt → Set
│      ├──► read denylist.txt → []string
│      ├──► stream blocklist.raw
│      ├──► atomicWriteStream(blocklist.txt)
│      └──► rebuildMu.Unlock()  (defer)
│
├──► atomicWriteFile(SELECTED_FILE, key)
├──► applyMemoryLimit(key)   ← v1.1.0: MEM-1
│
├──► stopService() / startService()
│
└──► writeProgress(100, "Protection applied")
```

**v1.2.0 note**: the pre-critical backup runs **before** any
destructive operation. It is serialized by `backupMu`.

**v1.3.0 note**: `rotate_backups` now detects snapshots by the
presence of `.manifest.json` and sorts them by **mtime**
descending.

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
│      ├──► pkill -9 dnscrypt-proxy
│      ├──► STATUS_FILE = "OFF"  ← legitimate write (user requested)
│      ├──► manage_firewall 0 (Custom Chain cleanup)
│      └──► ...
│
├──► startService()
│      ├──► exec dnscrypt-proxy -config ...
│      ├──► waitForProcessAndPort(45 s)
│      ├──► settings delete global private_dns_mode
│      ├──► manage_firewall 1 (Custom Chain create)
│      └──► STATUS_FILE = "ON"   ← legitimate write
│
└──► broadcastEvent("status", "ON")
```

### 3.4 Dashboard Metrics

```text
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  GET http://127.0.0.1:9091/api/metrics                       │
└──────────────────────────────┬───────────────────────────────┘
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
│  └────────────────────────┬───────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  dnscrypt-proxy :8080 (monitoring_ui)                        │
│  returns JSON (or Prometheus text fallback)                  │
└──────────────────────────────┬───────────────────────────────┘
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
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  JSON response with: generated_at, total_queries,            │
│  blocked_queries, cache_stats, ...                           │
└──────────────────────────────────────────────────────────────┘
```

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
│      ├── ~/.cache/.../dnscrypt-proxy-arm64    ✓
│      ├── ~/.cache/.../dnscrypt-proxy-arm      ✓
│      ├── ~/.cache/.../dnscrypt-proxy-x86_64   ✓
│      └── ~/.cache/.../dnscrypt-proxy-i386     ✗
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

### 3.5b Companion APK Fetch (v1.4.0, extended in v1.5.0)

```text
Release pipeline (.github/workflows/release.yml)
│
▼
scripts/fetch_app_apk.sh
│
├──► read proxy/app-apk.version → "1.0.0"
│
├──► cache check
│      ~/.cache/dnscrypt-proxy-webui/app/DNS-Proxy-v1.0.0.apk
│
├──► if missing: download from
│      https://github.com/gasciljh/dnscrypt-proxy-app/
│        releases/download/v1.0.0/app-debug.apk
│
├──► SHA256 + .manifest.json
│
├──► output:
│      dist/DNS-Proxy-v1.0.0.apk
│      dist/DNS-Proxy-v1.0.0.apk.sha256
│
└──► release.yml stages it to web/app-debug.apk before packaging
```

**v1.5.0 addition**: the release pipeline also fetches and stages
the `.sha256` file at `web/app-debug.apk.sha256`. This enables
SHA256 verification by `install_app.sh` during a root install. If
the `.sha256` file is absent (e.g. a local developer build),
`install_app.sh` degrades to advisory mode.

**Build artifacts**: `web/app-debug.apk` and
`web/app-debug.apk.sha256` are **not tracked by git**
(see `.gitignore` §[20]).

### 3.6 Login Flow

```text
┌──────────────────────────────────────────────────────────────┐
│  User Browser                                                │
│  POST /api/auth/login                                        │
│  Content-Type: application/json                              │
│  Body: {"username": "admin", "password": "..."}              │
└──────────────────────────────┬───────────────────────────────┘
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
└──────────────────────────────┬───────────────────────────────┘
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
└──────────────────────────────┬───────────────────────────────┘
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
│  │    "app_version": "1.0.0",     ← v1.4.0 (from file)    │  │
│  │    "backups": { ... }          ← v1.2.0 (BAK-1)        │  │
│  │    ...                                                 │  │
│  │  }                                                     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
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
│  │  // v1.2.0: display backup state                       │  │
│  │  // v1.5.0: display app_version for install URLs       │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
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
└──────────────────────────────┬───────────────────────────────┘
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
| `runtime_info` exposes the effective limit | `buildRuntimeInfo()` |

### 3.10 Backup & Restore Flow (v1.2.0, extended in v1.3.0 and v1.5.0)

**Design philosophy**: *"Search for user data everywhere —
do not guess whether this is an upgrade."*

```text
┌──────────────────────────────────────────────────────────────┐
│  Install / Upgrade (customize.sh)                            │
└──────────────────────────────┬───────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
        ┌──────────┐    ┌──────────┐    ┌──────────┐
        │ Layer 1  │    │ Layer 5  │    │ Layer 7  │
        │ Multi-   │    │ Root-    │    │ Recovery │
        │ source   │    │ solution │    │ mode     │
        │ detect   │    │ compat   │    │ check    │
        └────┬─────┘    └────┬─────┘    └────┬─────┘
             │               │               │
             └───────────────┼───────────────┘
                             │
                             ▼
        ┌──────────────────────────────────────────────────────┐
        │  FOUND_SOURCE (≥ 3 valid files)                      │
        │  7 candidate paths on Magisk/KernelSU:               │
        │    1. $MODPATH/proxy                                 │
        │    2. /data/adb/modules/dnscrypt-.../proxy           │
        │    3. /data/adb/modules/DNSCrypt-.../proxy           │
        │    4. /data/adb/modules/DNSCrypt-...WebUI/proxy      │
        │    5. $PERSISTENT_BACKUP/current                     │
        │    6. $PERSISTENT_BACKUP                             │
        │    7. /data/local/tmp/dnscrypt-webui-backup          │
        │  + 2 more on APatch (modules_update/)                │
        └──────────────────────────┬───────────────────────────┘
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
        ┌──────────────────────────────────────────────────────┐
        │  Extract ZIP (all 4 binaries + shell scripts +       │
        │  config + web assets + optional companion APK +      │
        │  install_app.sh + boot-mini.sh + .sha256)            │
        │                                                      │
        │  In RECOVERY MODE:                                   │
        │   • [8a] already restored the 5 user files AND       │
        │     copied them to $MODPATH/.recovery_snapshot/      │
        │   • [9] unzips everything (this OVERWRITES           │
        │     webui.conf and dnscrypt-proxy.toml with          │
        │     defaults)                                        │
        │   • [9b2] re-applies the 5 files from the            │
        │     snapshot                                         │
        └──────────────────────────┬───────────────────────────┘
                                 │
                                 ▼
        ┌──────────────────────────────────────────────────────┐
        │  Restore 5 user files from FOUND_SOURCE              │
        │    → proxy/webui.conf                                │
        │    → proxy/dnscrypt-proxy.toml                       │
        │    → proxy/selected_profile.txt                      │
        │    → proxy/allowlist.txt                             │
        │    → proxy/denylist.txt                              │
        │  With SELinux context + chmod 0600                   │
        └──────────────────────────┬───────────────────────────┘
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
        ┌──────────────────────────────────────────────────────┐
        │  COMMIT transaction → remove txn dir                 │
        │  Write .last_stable pointer                          │
        │  Write .upgrade_history.json (or .txt)               │
        │  [v1.5.0] §[10c] mirrors APK + .sha256 to apk/       │
        │           (best-effort)                              │
        └──────────────────────────────────────────────────────┘
```

**Layer 9 (rotation) — v1.3.0 update**:

| Aspect | v1.2.0 behaviour | v1.3.0 behaviour |
|---|---|---|
| Snapshot detection | Directory name pattern | Presence of `.manifest.json` |
| Sort key | Lexicographic directory name | **mtime** (numeric, descending) |
| Protected targets | 21 newest by name | 21 newest by mtime + `.last_stable` + newest install |
| Custom-named snapshots | Ignored | Recognized (via manifest) |

**v1.5.0 addition to Layer 10 — APK mirror (§[10c])**:

`customize.sh` §[10c] now mirrors the companion APK and its
`.sha256` to `$PERSISTENT_BACKUP/apk/` (best-effort).

**Recovery-mode interaction**: unchanged from v1.2.0.

### 3.11 Companion App Install Flow (v1.5.0)

The user's entry point is the WebUI install button
(`#pwaInstallBtn` in `web/index.html`). Clicking it triggers a
sequence that ends either in a root-level `pm install` or in a
browser download from GitHub.

**End-to-end sequence (local install path)**:

```text
┌──────────────────────────────────────────────────────────────┐
│  1. User clicks "Install App"                                │
│     (web/index.html → handleCompanionInstall())              │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  2. GET /api?action=install_token                            │
│     • checkAuth()                                            │
│     • isLocalRequest()                                       │
│     • generateInstallToken()                                 │
│       → 32-byte crypto/rand → hex → 64 chars                 │
│       → store in installTokens with TTL = 60 s               │
│     • return { "token": "abc...", "ttl": 60 }                │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  3. Show install-method modal (IDX-24)                       │
│     ┌──────────────────────────────────────────────────┐  │
│     │  📲 Install App                                    │  │
│     │                                                    │  │
│     │  📦 Local install (recommended)                    │  │
│     │     [ Install locally ]                            │  │
│     │                                                    │  │
│     │  🌐 Download from GitHub                           │  │
│     │     [ Open GitHub page ] [ Direct download ]       │  │
│     │                                                    │  │
│     │              [ Cancel ]                            │  │
│     └──────────────────────────────────────────────────┘  │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼ (user chose "Install locally")
┌──────────────────────────────────────────────────────────────┐
│  4. POST /api/install_companion_app                          │
│     body: token=<csrf>                                       │
│     • checkAuth()                                            │
│     • isLocalRequest()                                       │
│     • isInstallLockedOut(ip)  ← 5 attempts / 15 min          │
│     • validateAndConsumeInstallToken(token)  ← one-shot      │
│     • recordInstallAttempt(ip)                               │
│     • callInstallScript()                                    │
│       → runShellWithTimeout(                                 │
│           "install_app.sh",                                  │
│           INSTALL_TIMEOUT = 90 s)   ← main.go §[3b]          │
│     • parse JSON from stdout                                 │
│     • return structured response                             │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  5. install_app.sh (5-level cascade)                         │
│                                                              │
│     Pre-flight:                                              │
│       • APK exists + non-empty                               │
│       • ZIP magic (PK)                                       │
│       • size > 100 KB                                        │
│       • free space on /data ≥ 3× APK size                    │
│                                                              │
│     SELinux staging:                                         │
│       • cp APK → /data/local/tmp/dnscrypt-companion.apk      │
│       • context: shell_data_file                             │
│                                                              │
│     Play Protect:                                            │
│       • capture $_VERIFIER_ORIG                              │
│       • set to 0                                             │
│       • trap → restore $_VERIFIER_ORIG on exit               │
│                                                              │
│     Cascade (first success wins):                            │
│       (1) pm install -r --user 0 <apk>                       │
│       (2) pm install -r -i com.android.shell <apk>           │
│       (3) session-based:                                     │
│             install-create + install-write + install-commit  │
│       (4) magisk su -c "pm install -r <apk>"                 │
│       (5) cmd package install -r <apk>                       │
│                                                              │
│     Cascade deadline:                                        │
│       • CASCADE_DEADLINE_SECONDS = 75                        │
│       • checked before each strategy                         │
│       • < INSTALL_TIMEOUT (90 s) → trap always fires         │
│                                                              │
│     After each strategy:                                     │
│       • poll up to 15 s for the package to appear in         │
│         `pm list packages`                                   │
│                                                              │
│     Output (single-line JSON on stdout):                     │
│       {                                                      │
│         "status": "ok",                                      │
│         "action": "install",                                 │
│         "strategy": 1,                                       │
│         "package": "com.gasciljh.dnsproxy.debug",            │
│         "version_name": "1.0.0",                             │
│         "sha_verified": true,                                │
│         "message_ar": "...",                                 │
│         "message_en": "..."                                  │
│       }                                                      │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  6. WebUI renders result                                     │
│                                                              │
│  Success:                                                    │
│    • showMsg(t('installSuccess'), 'success')                 │
│    • refreshCompanionState() → button becomes "✅ Installed"  │
│                                                              │
│  Failure:                                                    │
│    • Show error modal with:                                  │
│      – Localized error message (AR or EN)                    │
│      – Optional hint (AR or EN)                              │
│      – Fallback button: "⬇️ Download manually"                │
│        → window.location.href = '/app-debug.apk'             │
└──────────────────────────────────────────────────────────────┘
```

**Alternative paths (from the modal — two GitHub actions)**:

| User chose | Action |
|---|---|
| **Open GitHub page** | `window.open(APP_GITHUB_PAGE_URL, '_blank', 'noopener,noreferrer')` |
| **Direct download from GitHub** | `window.open(getCompanionApkUrl(), '_blank', 'noopener,noreferrer')` |
| **Cancel** | `closeConfirmModal()` |
| **Manual download** (from failure modal) | `window.location.href = '/app-debug.apk'` |

**Where each path is intercepted**:

| Path | Intercepted by | Rule |
|---|---|---|
| `POST /api/install_companion_app` | SW bypass | rule 2 (`/api/*`) |
| `POST /api/uninstall_companion_app` | SW bypass | rule 2 |
| `GET /api?action=install_token` | SW bypass | rule 2 |
| `GET /api?action=companion_app_state` | SW bypass | rule 2 |
| `https://github.com/...` | SW bypass | rule 1 (external origin) |
| `/app-debug.apk` | SW bypass | rule 9 |

**Security properties**:

| Concern | Mitigation |
|---|---|
| Unauthorized install | `checkAuth()` required |
| Remote install | `isLocalRequest()` required on all three install surfaces |
| Brute force | 5 failed attempts / 15 min per IP |
| CSRF | one-shot token (60 s TTL) |
| Path traversal | APK path hardcoded in Go + sh |
| Shell injection | `shellQuote()` on all paths |
| SELinux relaxation | NEVER `setenforce 0` — staging instead |
| Play Protect interference | temporary disable + restore via trap, bounded by 75 s cascade deadline |
| Play Protect restore value | trap restores `$_VERIFIER_ORIG` |
| APK tampering | SHA256 verification if `.sha256` present |
| Staged APK leftover | Three-way trap (EXIT/INT/TERM) removes it on every exit path |
| Signal-interrupt resume | INT exits 130, TERM exits 143 |
| Audit | full log in `dnscrypt_main.log` |

**Package name detection**:

```
com.gasciljh.dnsproxy.debug   (default)
com.gasciljh.dnsproxy
com.gasciljh.dnscrypt_proxy    (legacy)
```

`install_app.sh` tries each candidate in order when polling for
the installed package.

**Polling after each strategy**:

```
After strategy N completes:
  for i in 1..15:                            (15 s max)
    if pm list packages | grep -q <pkg>:
      → strategy N succeeded → break cascade
    sleep 1
  → if not found, try strategy N+1
```

**Timeout hierarchy** (four nested bounds):

| Level | Value | Source | Purpose |
|---|:-:|---|---|
| **Client (WebUI)** | 120 s | `web/index.html` `getTimeoutForUrl()` | Leaves headroom for HTTP round-trip + JSON parsing |
| **HTTP WriteTimeout** | 150 s | `main.go` §[3] `HTTP_WRITE_TIMEOUT` | Bounds the entire response-writing phase |
| **Server handler** | 90 s | `main.go` §[3b] `INSTALL_TIMEOUT` | Bounds the `exec.CommandContext` call in `callInstallScript()` |
| **Cascade (script)** | 75 s | `install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS` | Bounds the loop; ensures the trap fires inside the server timeout |

---

## 4. Backend Component (main.go)

### 4.1 Structure

| Section | Purpose |
|---|---|
| `[0]`–`[4]` | Version vars, paths, constants, types |
| `[5]` | Rules state + `rebuildMu` (RACE-1) |
| `[6]`–`[7]` | HTTP Client + Paths |
| `[8]`–`[13]` | Variables, Config, Logging, Atomic Writes |
| `[14]` | SSE (with Write Deadline) |
| `[15]`–`[17]` | Stats, Auth (Basic/Bearer/Cookie/Watchdog Token) |
| `[17d]` | v1.5.0 — Companion app install helpers (10 functions) |
| `[18]`–`[19]` | Process/Port Checks + Service Lifecycle |
| `[20]`–`[23]` | Entries Count, Download, Domain Matching |
| `[24]`–`[27]` | Atomic Rules Save, Profile Management |
| `[28]`–`[29]` | Old Modules, Log Files |
| `[30]`–`[33]` | runtime_info, healthz/readyz, API, Login |
| `[34]` | serveStaticAssets (whitelist) |
| `[35]` | metricsProxyHandler |
| `[36b]` | Auto-backup + rotation + notifications (v1.2.0) |
| `[36c]` | Transaction cleanup at startup (v1.2.0) |
| `[37]` | main() |

**Size**: 5,726 lines (v1.5.0). The v1.5.0 cycle added ~250 lines
on top of the v1.4.0 baseline. The v1.5.0+ post-release patch
cycle added a small amount on top of that (three-layer logger
split + port cache).

### 4.2 API Endpoints

| Method | Path | Action | Auth | Timeout |
|---|---|---|---|---|
| GET | `/healthz` | Health check | No | 5 s |
| GET | `/app-debug.apk` | Companion Android app (v1.4.0) | No | 15 s |
| GET | `/readyz` | Readiness | Local-only | 5 s |
| GET | `/api?action=X` | Various actions | Yes | 15 s |
| POST | `/api/save_allowlist` | Save allowlist (+ backup + rotate) | Yes | 15 s |
| POST | `/api/save_denylist` | Save denylist (+ backup + rotate) | Yes | 15 s |
| POST | `/api/update_profile` | Update blocklist (+ backup + rotate) | Yes | 310 s |
| POST | `/api/save_custom_rules` | Save both (+ backup + rotate) | Yes | 15 s |
| POST | `/api/append_denylist` | Append to denylist — requires `content` param | Yes | 15 s |
| POST | `/api/toggle_service` | Toggle on/off | Yes | 60 s |
| POST | `/api/restart_service` | Restart | Yes | 60 s |
| POST | `/api/ensure_running_service` | Ensure DNS running | Watchdog token or normal auth | 60 s |
| POST | `/api/auth/login` | Login (POST-only) | No | 15 s |
| POST | `/api/auth/logout` | Logout (POST-only) | Yes | 15 s |
| GET | `/api/runtime_info` | Build + ports + profile + memory + backups | Yes | 15 s |
| GET | `/api/download_log` | Download log file | Yes | 15 s |
| GET | `/api/metrics` | Prometheus → JSON | Yes | 15 s |
| GET | `/events` | SSE stream | Yes | ∞ (30 s per flush) |
| POST | `/api/install_companion_app` | Install companion app via root (v1.5.0) | Yes + CSRF token | 120 s |
| POST | `/api/uninstall_companion_app` | Uninstall companion app (v1.5.0) | Yes | 60 s |
| GET | `/api?action=install_token` | One-shot CSRF token (v1.5.0) | Yes | 15 s |
| GET | `/api?action=companion_app_state` | Companion install state (v1.5.0) | Yes | 15 s |

**Static assets (v1.4.0)**: 12 entries in `serveStaticAssets`,
including `/app-debug.apk`.

**Companion install timeout (v1.5.0)**: the
`install_companion_app` endpoint uses a **120-second** timeout
(vs. 15 s for other API calls). This accommodates slow ROMs
where the 5-level cascade + Play Protect scan can take 60+ s.
The WebUI's `getTimeoutForUrl()` mirrors this value.

**Install retry policy (v1.5.0)**: the WebUI disables retries for
`install_companion_app` (`xhrPost` checks `retries = 0`). This
is deliberate: the first request consumes the one-shot CSRF
token, so a retry would produce "Invalid or expired install
token" even if the first install were still in progress.

**HTTP WriteTimeout (v1.5.0+)**: `main.go`'s `HTTP_WRITE_TIMEOUT`
is **150 s** — strictly greater than `INSTALL_TIMEOUT` (90 s). The
60-second value that shipped in v1.5.0 was corrected in the
post-release patch cycle because a slow install would complete
successfully on the device but the client would see a connection
reset before the JSON response arrived.

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
| `portCacheMap` | `sync.Mutex` | Per-port cache |
| `systemShell` | `sync.Once` | Platform detection |
| `memLimitMu` | `sync.Mutex` | Memory limit state (v1.1.0 — MEM-1) |
| `backupMu` | `sync.Mutex` | Serializes auto-backup calls (v1.2.0 — BAK-2) |
| `watchdogTokMu` | `sync.RWMutex` | Watchdog token cache (v1.2.0 — WD-TOKEN) |
| `lastUpdateMu` | `sync.Mutex` | `last_update` TTL cache |
| `installTokens` | `sync.Mutex` (`installTokensMu`) | CSRF token store (v1.5.0) |
| `installAttempts` | `sync.Mutex` (`installAttemptsMu`) | Per-IP install rate limiter (v1.5.0) |
| `companionStateCache` | `sync.Mutex` | 30-second cache for `companion_app_state` (v1.5.0) |
| `portConfMu` | `sync.RWMutex` | webui.conf port cache, 30 s TTL |

**`backupMu` rationale**: two rapid user actions could trigger
two `createAutoBackup` calls that operate on the same source
directory. `backupMu` serializes them.

**`installTokens` rationale (v1.5.0)**: each install request
consumes a one-shot CSRF token. The store is a
`map[string]installToken` with a TTL. A periodic GC (or lazy
eviction on access) removes expired entries. The mutex is held
only for map operations, not for the entire install duration.

**`installAttempts` rationale (v1.5.0)**: the per-IP rate
limiter mirrors `loginAttempts`. It stores `{count, lockoutUntil}`
per IP. The lockout is 15 minutes after 5 failed attempts. The
mutex is held only for map access.

**`companionStateCache` rationale (v1.5.0)**: `GET /api?action=companion_app_state`
would otherwise fork `pm list packages` on every page load. The
30-second cache prevents that. The cache is invalidated
explicitly after every install/uninstall attempt — success or
failure.

**`portConfMu` rationale**: `getWebUIPort()` and
`getDashboardPort()` are called on every
`/api?action=runtime_info` request. Each call would otherwise
read `webui.conf` from disk. The 30-second TTL cache collapses
those two reads into at most one. The cache key is the
caller-declared `which` argument (`"webui"` or `"dashboard"`),
so the two endpoints do not accidentally share a cache slot.

### 4.4 SSE Implementation

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

**Why Write Deadline?** If the client is slow: TCP buffer fills
up → `Fprint` / `Flush` block → the goroutine hangs forever →
DoS. The 30-second write deadline closes the connection when a
flush cannot complete in time.

**Chosen values**:

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
- `shellQuote()` (shell injection protection) — extended in v1.1.0
- `readConfPort` range check (1-65535)
- Auth cache 60 s (I/O reduction) — empty results never cached
- `rebuildMu` mutex (RACE-1: BLOCKLIST consistency)
- MEM-1: Dynamic per-profile memory limit (v1.1.0)
- MEM-3: `MONITORING_UI_PORT` constant (v1.1.0)
- BAK-1: `runtime_info.backups` exposes 7 fields (v1.2.0)
- BAK-2: Pre-critical backup + rotation before destructive operations (v1.2.0)
- BAK-3: `cleanupOldTransactions()` preserves ROLLBACK/START (v1.2.0)
- BAK-4: `checkPendingNotifications()` reads and clears (v1.2.0)
- Watchdog token: closes the CSRF hole on `ensure_running_service` (v1.2.0)
- CodeQL `go/path-injection` fix in `removeModule` (v1.4.0)
- Public static asset: `/app-debug.apk` requires no auth (v1.4.0)
- One-shot CSRF token on `install_companion_app` (v1.5.0)
- Per-IP install rate limit (5 / 15 min) (v1.5.0)
- SELinux staging (never `setenforce 0`) (v1.5.0)
- Play Protect temporary disable + restore via trap, bounded by 75 s cascade deadline (v1.5.0)
- `shellQuote()` on all paths in `install_app.sh` (v1.5.0)
- `callInstallScript()` uses `getSystemShell()` (v1.5.0)
- Logger split into three layers; rotation failure no longer re-enters `logWithLevel`
- `isLocalRequest` no longer contains an unreachable `"localhost"` branch
- Install-family localhost gate covers `install_companion_app`, `uninstall_companion_app`, and the `install_token` GET endpoint

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
│  2. If the file is missing, main.go creates it               │
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
│  5. On mismatch or missing header → fall through to          │
│     normal user auth (Bearer / Cookie / Basic) → 401.        │
└──────────────────────────────────────────────────────────────┘
```

**Characteristics**:

- **Localhost-scoped**: `isLocalRequest` is still required.
- **Constant-time**: no timing leak on comparison.
- **Not rate-limited**: token requests bypass the login limiter.
- **Persistent**: the token file survives restarts.
- **Fail-closed**: if the token file is missing and no token
  is sent, the request falls back to normal user auth.

#### 4.5.2 Companion Install Security (v1.5.0)

| Concern | Mitigation |
|---|---|
| Unauthorized install | `checkAuth()` required |
| Remote install | `isLocalRequest()` required on all three surfaces |
| Brute force | 5 failed attempts / 15 min per IP |
| CSRF | one-shot token (60 s TTL) |
| Path traversal | APK path hardcoded in Go + sh |
| Shell injection | `shellQuote()` on all paths |
| SELinux relaxation | NEVER `setenforce 0` — staging instead |
| Play Protect interference | temporary disable + restore via trap, bounded by 75 s cascade deadline |
| APK tampering | SHA256 verification if `web/app-debug.apk.sha256` is present |
| Audit | full log in `dnscrypt_main.log` |
| State caching | `companion_app_state` cached 30 s |
| Install lockout | `installAttempts[ip].lockoutUntil` = `now + 15 min` after 5 failed attempts |
| Staged APK leftover | Three-way trap (EXIT/INT/TERM) removes it on every catchable exit path |

**Token lifecycle (v1.5.0)**:

```text
1. GET /api?action=install_token
     ↓
2. generateInstallToken()
     • 32 bytes from crypto/rand
     • hex-encode → 64 chars
     • store in installTokens[token] = { expiry: now + 60s }
     ↓
3. Return { "token": "abc...", "ttl": 60 }
     ↓
4. Client POSTs with body "token=abc..."
     ↓
5. validateAndConsumeInstallToken(token)
     • Look up in installTokens
     • If not found → 401 "Invalid or expired install token"
     • If found → delete from map (one-shot) → allow
     ↓
6. Old tokens are garbage-collected lazily
```

### 4.6 Backend Fixes (Summary)

The full fix history is documented in `docs/API.md` §11 and
`docs/SECURITY.md` §17.

#### 4.6.1 v1.0.0 — Critical Backend Fixes

| Fix | Topic | Reference |
|---|---|---|
| A | `STATUS_FILE` semantics (read-only from `getStatus`) | SECURITY.md §5.14 |
| B | `metricsProxyHandler` path | SECURITY.md §5.20 |
| C | IPv6 client IP (`getClientIP`) | SECURITY.md §5.15 |
| D | Port collision guard (`MONITORING_UI_PORT`) | SECURITY.md §5.16 |
| E | Section-restricted TOML parsing | SECURITY.md §5.17 |
| Fix #1 | Dashboard JSON conversion | SECURITY.md §5.20 |
| Fix #2 | `getSystemShell()` fallback | §15 |
| Fix #8 | Basic Auth rate limiting | SECURITY.md §5.18 |
| Fix #10 | Section header with trailing comment | SECURITY.md §5.19 |
| Fix #11 | Per-port cache | §10 |
| Fix #12 | Exact endpoint matching (`hasEndpoint`) | SECURITY.md §5.20 |
| NEW-1 | Login POST-only (CSRF) | SECURITY.md §5.23 |
| NEW-3 | `readConfPort` range check | SECURITY.md §5.24 |
| NEW-4 | `/readyz` localhost-only | SECURITY.md §5.25 |
| NEW-5 | `shellQuote` injection protection | SECURITY.md §5.26 |
| NEW-6 | Auth cache 60 s | SECURITY.md §5.27 |
| RACE-1 | `rebuildMu` mutex | SECURITY.md §5.28 |
| PORT-2 | `runtime_info` dynamic ports | SECURITY.md §5.29 |

#### 4.6.2 v1.1.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| MEM-1 | Dynamic memory limit per profile | §3.9, SECURITY.md §5.30.1 |
| MEM-2 | Extended `shellQuote` charset | SECURITY.md §5.30.2 |
| MEM-3 | `MONITORING_UI_PORT` constant | SECURITY.md §5.30.3 |

#### 4.6.3 v1.2.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| BAK-1 | `buildBackupInfo()` — 7-field schema | §4.10.1 |
| BAK-2 | `createAutoBackup(reason string)` + `rotate_backups` | §4.10.2 |
| BAK-3 | `cleanupOldTransactions()` | §4.10.3 |
| BAK-4 | `checkPendingNotifications()` | §4.10.4 |
| WD-TOKEN | Watchdog token (closes CSRF hole) | §4.5.1 |
| BUG-A..L | Post-audit corrections | §4.11 |

#### 4.6.4 v1.3.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| SNAP-MANIFEST | `buildBackupInfo` — manifest-based detection | §4.13.1 |
| SNAP-MTIME | `buildBackupInfo` — mtime sort for `last_backup_name` | §4.13.1 |
| ROT-MANIFEST | `rotate_backups` — manifest-based detection | §4.13.2 |
| ROT-MTIME | `rotate_backups` — mtime sort | §4.13.2 |
| ROT-PROTECT | `rotate_backups` — preserve `.last_stable` + newest install | §4.13.2 |

#### 4.6.5 v1.4.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| APK-1 | `APK_FILE` constant + `serveStaticAssets` entry + `serveFile` per-extension Cache-Control | §4.12.1 |
| APK-2 | `/app-debug.apk` route | §4.12.2 |
| CQ-FIX | CodeQL `go/path-injection` fix in `removeModule` | §4.12.3 |
| IOS-REMOVE | iOS PWA logic removed from `web/index.html` | §6.8 |

#### 4.6.6 v1.5.0 — Backend Additions

| ID | Topic | Reference |
|---|---|---|
| APK-3 | `COMPANION_PKG` constant (retained-for-documentation) | §4.14.1 |
| APK-4 | `INSTALL_SCRIPT_REL` + `getInstallScript()` | §4.14.1 |
| APK-5 | `POST /api/install_companion_app` handler | §4.14.2 |
| APK-6 | `GET /api?action=companion_app_state` handler + 30 s cache | §4.14.3 |
| APK-7 | `POST /api/uninstall_companion_app` handler | §4.14.4 |
| APK-8 | `.sha256` sidecar bundling in `release.yml` | §14.13 |
| APK-11 | `INSTALL_TIMEOUT = 90 s`, `INSTALL_TOKEN_TTL = 60 s`, `MAX_INSTALL_ATTEMPTS = 5`, `INSTALL_LOCKOUT_PERIOD = 15 min` | §4.14.5 |
| APK-12 | Package name candidates (owned by `install_app.sh`) | §4.14.1, §5.8.7 |
| CIA-1..16 | `install_app.sh` implementation details | §5.8 |

#### 4.6.7 v1.5.0 Code-Review Corrections

Four code-quality corrections applied to `proxy/main.go` during
the v1.5.0 code-review cycle. All four are behaviour-preserving.

| ID | Location | Change |
|---|---|---|
| V15-CODE-01 | `getCompanionState()` Phase-3 | Comment corrected |
| V15-CODE-02 | `main()` startup banner | `LoginAttempts=InstallAttempts=%v (shared constant)` |
| V15-CODE-03 | `callInstallScript()` | `sh` → `getSystemShell()` |
| V15-CODE-04 | `handleAPI()` recover block | Added `logWithLevel("error", ...)` before the 500 response |
| V15-CODE-15 | `R3-01` header block | Doc-comment refreshed: 7 → EIGHT shell scripts extracted by `customize.sh §[9]` |

#### 4.6.8 v1.5.0+ Post-Release Backend Patches

Four additional corrections applied to `proxy/main.go` after the
v1.5.0 Global Edition sweep. **None is an audit correction**.

| ID | Location | Type | Change |
|---|---|---|---|
| MAIN-REENT-01 | §[10] Logging | 🔴 Bug (deadlock) | Logger split into three layers: `logWithLevel` (public, level filter + lock), `logLocked` (internal, assumes lock held, performs rotation), `writeLocked` (internal, assumes lock held, writes a single line). The rotation-failure warning now goes through `writeLocked`, never through `logWithLevel`. |
| MAIN-PORTCACHE-01 | §[3] + §[8] + §[9] | 🟡 Performance | `getWebUIPort()` / `getDashboardPort()` route through `readConfPortCached(key, defaultPort, which)`, backed by a 30-second TTL cache and the `portConfMu` RWMutex. |
| MAIN-DEADLOCALHOST-01 | §[16] | 🟢 Dead code | `isLocalRequest()` no longer contains an unreachable `"localhost"` comparison. |
| MAIN-APPENDHASH-01 | §[26] | 🟡 Edge case | `appendDenylist()` now passes `getRulesState().DenylistHash` to `saveDenylist()` instead of `fileHash(DENYLIST_FILE)`. |

**MAIN-REENT-01 — deadlock scenario**: the pre-patch
`logWithLevel` held `logMutex` and called `logWithLevel`
recursively from inside the rotation branch when `os.Rename`
failed. `sync.Mutex` is **not reentrant** in Go, so a failed
rename on a full or read-only `/data/local/tmp` would deadlock
the calling goroutine — and, because `logMutex` serialises every
log call, every other goroutine that tried to log afterwards.
The pre-patch `recover()` did not help: the failure mode was a
hang, not a panic.

**MAIN-PORTCACHE-01 — cache key**: the `which` argument to
`readConfPortCached` is a short string (`"webui"` or
`"dashboard"`) used as the cache slot selector. The two callers
pass distinct values, so `getWebUIPort()` and
`getDashboardPort()` never share a slot.

**MAIN-DEADLOCALHOST-01 — why the branch was dead**:
`net.SplitHostPort` operates on the raw `RemoteAddr` string
produced by the OS network stack. That string always contains an
IP literal. It is never the DNS name `"localhost"` — that name
is resolved by the client before the TCP handshake.

**MAIN-APPENDHASH-01 — divergence scenario**: `getRulesState()`
returns `currentRules`, updated by `initRulesState()` at startup
and by `atomicSaveRulesInternal()` after every successful save.
If `denylist.txt` is modified externally without a corresponding
update to `currentRules`, the two hash sources diverge. The
pre-patch `appendDenylist` read the file with
`fileHash(DENYLIST_FILE)`; the `saveDenylist` it then called
compared that hash against `currentRules.DenylistHash` (still
the old value), producing a spurious conflict.

### 4.7 Post-Release Fixes

#### 4.7.1 Fix G — Exact Key Matching

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
if success {
    delete(loginAttempts, ip)
    return
}
attempt := loginAttempts[ip]
if attempt == nil { attempt = &LoginAttempt{}; loginAttempts[ip] = attempt }
```

#### 4.7.3 Fix I — `isRunDirUsable` (30 s cache)

```go
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

#### 4.7.4 Fix J — `isPortOpen` native Go

**Before**: `fork/exec` + `source functions.sh` every 3 s.
**After**: read `/proc/net/udp{,6}` directly.

#### 4.7.5 Fix K — Asset Serving

**Added 7 static files**:
- `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`
- `favicon-32x32.png`, `favicon-16x16.png`, `favicon.ico`
- `offline.html`

### 4.8 v1.0.0 Backend Fixes (Details)

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

```go
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

See §4.9.2.

#### 4.8.16 Fix W — Auth Cache 60 s (Fix NEW-6)

See §4.5.

#### 4.8.17 Fix X — `rebuildMu` mutex (RACE-1)

See §3.7.

#### 4.8.18 Fix Y — `runtime_info` ports (PORT-2)

See §3.8.

#### 4.8.19 Fix Z — Preserve Settings (Fix #3)

The v1.0.0 mechanism (`BACKUP_TMP` in `/data/local/tmp/`) is
superseded by the v1.2.0 10-layer architecture (§4.10).

### 4.9 v1.1.0 Backend Additions

#### 4.9.1 MEM-1 — Dynamic Memory Limit per Profile

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
    prevLimit := currentMemLimit
    _ = debug.SetMemoryLimit(limit)
    currentMemLimit = limit
    currentProfile = key
    logWithLevel("info", fmt.Sprintf(
        "memory limit adjusted: %d MB → %d MB (profile=%s)",
        prevLimit/(1024*1024), limit/(1024*1024), key))
}
```

#### 4.9.2 MEM-2 — Extended `shellQuote` Character Set

**After (v1.1.0)**: adds `{`, `}`, `\n`, `\t` (24 characters total).

#### 4.9.3 MEM-3 — `MONITORING_UI_PORT` in Metrics Handler

```go
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
```

### 4.10 v1.2.0 Backend Additions

#### 4.10.1 BAK-1 — `buildBackupInfo()` (7-field schema)

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

**Snapshot detection & ordering** (superseded by §4.13.1 in
v1.3.0): v1.2.0 used a name pattern; v1.3.0 uses manifest
presence + mtime sort.

#### 4.10.2 BAK-2 — `createAutoBackup(reason string)`

**Called from** — 5 destructive endpoints, but only 4 distinct
reason strings:

| Caller | Reason |
|---|---|
| `updateProfile()` | `"pre-profile-change"` |
| `saveAllowlist()` | `"pre-allowlist-save"` |
| `saveDenylist()` | `"pre-denylist-save"` |
| `saveCustomRulesCombined()` | `"pre-custom-rules-save"` |
| `appendDenylist(content)` | *(no own reason — calls `saveDenylist`)* |

**Semantics**:
- **Best-effort**: a failed backup logs a warning and returns.
- **Serialized**: `backupMu`.
- **Delegated to shell**: `functions.sh:backup_user_files`.
- **Rotation**: `rotate_backups 21` in the same shell call.
- **Timeout**: `AUTO_BACKUP_TIMEOUT = 15 s`.

#### 4.10.3 BAK-3 — `cleanupOldTransactions()`

Called from `main()` at startup. Removes leftover `COMMIT`'d
transaction directories. Preserves `START` / `ROLLBACK` /
missing.

#### 4.10.4 BAK-4 — `checkPendingNotifications()`

Reads `.pending_notification` at startup, logs its content, and
removes the file.

#### 4.10.5 WD-TOKEN — Watchdog Token

See §4.5.1.

#### 4.10.6 Status Field Alignment

The `runtime_info.backups` object and the `status.sh --json`
output share the same **7 fields**. `status.sh --json`
additionally exposes `status` and `last_backup_age_seconds`
(diagnostic-only).

### 4.11 v1.2.0 Post-Audit Corrections

See §4.6.3 (BUG-A..BUG-L). The full set of twelve corrections to
`main.go`, all of which fix behaviours that clients could
observe.

### 4.12 v1.4.0 Backend Additions

#### 4.12.1 APK-1 — `APK_FILE` + `serveStaticAssets` + `serveFile`

```go
// v1.4.0 - companion Android app APK (optional)
APK_FILE = filepath.Join(WEB_DIR, "app-debug.apk")
```

```go
"/app-debug.apk": {
    path:        APK_FILE,
    contentType: "application/vnd.android.package-archive",
},
```

```go
func serveFile(w http.ResponseWriter, r *http.Request, path, contentType string) {
    setSecurityHeaders(w)
    if strings.HasSuffix(path, ".apk") {
        w.Header().Set("Cache-Control", "public, max-age=3600, immutable")
    } else {
        w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
    }
    if contentType != "" {
        w.Header().Set("Content-Type", contentType)
    }
    if _, err := os.Stat(path); err != nil {
        http.NotFound(w, r)
        return
    }
    http.ServeFile(w, r, path)
}
```

#### 4.12.2 APK-2 — `/app-debug.apk` route

Registered in **both** the WebUI mux (port 9090) and the
Dashboard mux (port 9091).

#### 4.12.3 CQ-FIX — CodeQL `go/path-injection` in `removeModule`

**Before (v1.3.0)**:

```go
cleanPath := filepath.Clean(modulePath)
if err := os.RemoveAll(cleanPath); err != nil { /* ... */ }
```

**After (v1.4.0)**:

```go
name := filepath.Base(modulePath)
if name == "" || name == "." || name == ".." ||
    name == string(filepath.Separator) {
    return map[string]interface{}{
        "status":  "error",
        "message": "Invalid module name",
    }
}

expectedPrefix := MODULES_DIR + string(filepath.Separator)
if !strings.HasPrefix(filepath.Clean(modulePath), expectedPrefix) {
    return map[string]interface{}{
        "status":  "error",
        "message": "Invalid path",
    }
}

cleanPath, err := securejoin.SecureJoin(MODULES_DIR, name)
if err != nil {
    return map[string]interface{}{
        "status":  "error",
        "message": "Invalid path",
    }
}
```

### 4.13 v1.3.0 Backend Additions

#### 4.13.1 SNAP-MANIFEST + SNAP-MTIME — `buildBackupInfo()`

**1. Snapshot detection** — manifest-based:

```go
manifestPath := filepath.Join(PERSISTENT_BACKUP, name, ".manifest.json")
if _, err := os.Stat(manifestPath); err != nil {
    continue
}
```

**2. Sort key for `last_backup_name`** — mtime:

```go
sort.Slice(snapshots, func(i, j int) bool {
    fi, errI := snapshots[i].Info()
    fj, errJ := snapshots[j].Info()
    if errI != nil || errJ != nil {
        return snapshots[i].Name() < snapshots[j].Name()
    }
    return fi.ModTime().Before(fj.ModTime())
})
```

#### 4.13.2 ROT-MANIFEST + ROT-MTIME + ROT-PROTECT — `rotate_backups()`

```sh
for _d in */; do
    _d="${_d%/}"
    [ -d "$_d" ] || continue
    case "$_d" in
        current|txn-*|orphan-txn-*|apk) continue ;;
    esac
    [ -f "$_d/.manifest.json" ] || continue
    _mt=$(stat -c %Y "$_d" 2>/dev/null) \
        || _mt=$(stat -f %m "$_d" 2>/dev/null) \
        || _mt=0
    case "$_mt" in ''|*[!0-9]*) _mt=0 ;; esac
    printf '%s %s\n' "$_mt" "$_d"
done | sort -rn -k1,1
```

> **v1.5.0 note**: as of v1.5.0, the `case` skip above also
> includes `apk`. The `apk/` subfolder was introduced by
> `customize.sh §[10c]` as the companion APK mirror.

### 4.14 v1.5.0 Backend Additions

The v1.5.0 release adds **4 endpoints** and **10 helpers** to
`proxy/main.go`. All are confined to two new sections: `[3b]`
(constants) and `[17d]` (helpers).

#### 4.14.1 APK-3 + APK-4 + APK-12 — Constants

**Section `[3b]` — Constants**:

```go
const (
    COMPANION_PKG             = "com.gasciljh.dnsproxy.debug"  // reference only

    INSTALL_SCRIPT_REL        = "install_app.sh"       // relative to MODDIR
    INSTALL_TIMEOUT           = 90 * time.Second
    INSTALL_TOKEN_TTL         = 60 * time.Second
    MAX_INSTALL_ATTEMPTS      = 5
    INSTALL_LOCKOUT_PERIOD    = 15 * time.Minute
    COMPANION_STATE_CACHE_TTL = 30 * time.Second
)
```

**Rationale**:

- **`COMPANION_PKG` default** — used for logging and as a
  greppable reference. The actual detected name is returned in
  the response, coming from `install_app.sh`.
- **`INSTALL_SCRIPT_REL = "install_app.sh"`** — the path is
  **relative to `MODDIR`** (the module root).
- **`INSTALL_TIMEOUT = 90 s`** — bounded by the script's
  75-second `CASCADE_DEADLINE_SECONDS`.
- **`INSTALL_TOKEN_TTL = 60 s`** — the CSRF token lives only as
  long as the modal is open.
- **`MAX_INSTALL_ATTEMPTS = 5` / `INSTALL_LOCKOUT_PERIOD = 15 min`**
  — mirrors the login rate limit for consistency.
- **`COMPANION_STATE_CACHE_TTL = 30 s`** — avoids forking
  `pm list packages` on every WebUI page load.

#### 4.14.2 APK-5 — `POST /api/install_companion_app`

**Actual flow (from `handleAPI`) — §[32]**:

```go
// Before checkAuth:
if r.Method == http.MethodPost &&
    (hasEndpoint(r.URL.Path, "install_companion_app") ||
        hasEndpoint(r.URL.Path, "uninstall_companion_app")) {
    if !isLocalRequest(r) {
        action := "install"
        if hasEndpoint(r.URL.Path, "uninstall_companion_app") {
            action = "uninstall"
        }
        writeInstallError(w, http.StatusForbidden, action,
            "not_localhost", "Forbidden: install is localhost-only")
        return
    }
}

// ... checkAuth, MaxBytesReader, etc. ...

if hasEndpoint(r.URL.Path, "install_companion_app") {
    if !requireFormContentType(w, r) {
        return
    }
    result := installCompanionApp(r)
    status := classifyInstallResult(result)
    if status != http.StatusOK {
        w.WriteHeader(status)
    }
    json.NewEncoder(w).Encode(result)
    return
}
```

**Actual handler — §[17d]**:

```go
func installCompanionApp(r *http.Request) map[string]interface{} {
    ip := getClientIP(r)

    if isInstallLockedOut(ip) {
        return map[string]interface{}{
            "status":  "error",
            "action":  "install",
            "message": "Too many install attempts. Try again in 15 minutes.",
            "reason":  "rate_limited",
        }
    }

    tok := r.FormValue("token")
    if !validateAndConsumeInstallToken(tok) {
        recordInstallAttempt(ip, false)
        return map[string]interface{}{
            "status":  "error",
            "action":  "install",
            "message": "Invalid or expired install token",
            "reason":  "invalid_token",
        }
    }

    logEvent("📲 install_companion_app requested by " + ip)
    result := callInstallScript("install")

    if result["status"] == "ok" {
        recordInstallAttempt(ip, true)
    } else {
        recordInstallAttempt(ip, false)
    }

    invalidateCompanionStateCache()
    return result
}
```

**Response shapes**:

| Case | HTTP | Body |
|---|---|---|
| Success | 200 | `{ "status": "ok", "action": "install", "strategy": 1, ... }` |
| Failure (all strategies) | 200 | `{ "status": "error", "action": "install", "message_ar": "...", "message_en": "...", ... }` |
| Rate limited | 429 | `{ "status": "error", "action": "install", "message": "Too many install attempts. Try again in 15 minutes.", "reason": "rate_limited" }` |
| CSRF failure | 401 | `{ "status": "error", "action": "install", "message": "Invalid or expired install token", "reason": "invalid_token" }` |
| Non-localhost | 403 | `{ "status": "error", "action": "install", "reason": "not_localhost", "message": "Forbidden: install is localhost-only" }` |

Note: **failure is 200, not 4xx**. This is deliberate — a
failed install is a valid outcome of a well-formed request, and
the WebUI needs to read the AR/EN message from the body. Only
auth/rate-limit/token failures use 4xx.

#### 4.14.3 APK-6 — `GET /api?action=companion_app_state`

**Actual handler — §[17d]**:

```go
func getCompanionState() map[string]interface{} {
    // Phase 1 — fast cache lookup (short critical section).
    companionStateMutex.Lock()
    if !companionStateTime.IsZero() &&
        time.Since(companionStateTime) < COMPANION_STATE_CACHE_TTL {
        var cached map[string]interface{}
        if json.Unmarshal([]byte(companionStateCache), &cached) == nil {
            companionStateMutex.Unlock()
            return cached
        }
    }
    companionStateMutex.Unlock()

    // Phase 2 — probe OUTSIDE the lock.
    result := callInstallScript("status")

    // Phase 3 — store the fresh result (short critical section).
    companionStateMutex.Lock()
    if !companionStateTime.IsZero() &&
        time.Since(companionStateTime) < COMPANION_STATE_CACHE_TTL {
        companionStateMutex.Unlock()
        return result
    }
    if b, err := json.Marshal(result); err == nil {
        companionStateCache = string(b)
        companionStateTime = time.Now()
    }
    companionStateMutex.Unlock()

    return result
}
```

**Response shape**:

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

**Cache invalidation**: `invalidateCompanionStateCache()` is
called after every install/uninstall attempt — success or
failure. A failed install may still register the package after
`install_app.sh`'s internal poll timed out.

#### 4.14.4 APK-7 — `POST /api/uninstall_companion_app`

**Actual handler — §[17d]**:

```go
func uninstallCompanionApp() map[string]interface{} {
    logEvent("🗑 uninstall_companion_app requested")
    result := callInstallScript("uninstall")
    invalidateCompanionStateCache()
    return result
}
```

Currently reserved for future UI. The WebUI's install-method
modal (IDX-24) does not expose an uninstall button in v1.5.0.

#### 4.14.5 APK-11 — Timeouts + Retry Policy

| Constant | Value | Consumer |
|---|---|---|
| `INSTALL_TIMEOUT` | 90 s | `callInstallScript()` shell timeout |
| `INSTALL_TOKEN_TTL` | 60 s | `generateInstallToken()` |
| `MAX_INSTALL_ATTEMPTS` | 5 | `isInstallLockedOut()` |
| `INSTALL_LOCKOUT_PERIOD` | 15 min | `isInstallLockedOut()` |
| `COMPANION_STATE_CACHE_TTL` | 30 s | `getCompanionState()` |
| `CASCADE_DEADLINE_SECONDS` | 75 s | `install_app.sh` §[13] cascade loop |
| `HTTP_WRITE_TIMEOUT` | 150 s | `main.go` http.Server |

**WebUI counterpart**: `web/index.html` `getTimeoutForUrl()`
returns `120000` (120 s) for any URL containing
`install_companion_app`.

**Retry policy**: `web/index.html` `xhrPost()` disables retries
for `install_companion_app`:

```javascript
var retries = (url.indexOf('install_companion_app') !== -1) ? 0 : 3;
```

**Timeout hierarchy** (four nested bounds):

| Level | Value | Source |
|---|:-:|---|
| Client | 120 s | `web/index.html` `getTimeoutForUrl()` |
| Server WriteTimeout | 150 s | `main.go` `HTTP_WRITE_TIMEOUT` |
| Server handler | 90 s | `main.go` §[3b] `INSTALL_TIMEOUT` |
| Cascade | 75 s | `install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS` |

#### 4.14.6 v1.5.0+ — `callInstallScript()` uses `getSystemShell()`

The pre-patch implementation built the shell command as:

```go
cmd = "sh " + shellQuote(script)   // ← PATH-dependent
```

The post-patch implementation resolves the interpreter through
`getSystemShell()`:

```go
shell := getSystemShell()
cmd = shell + " " + shellQuote(script)
```

#### 4.14.7 v1.5.0+ — Companion state cache invalidation

Both `installCompanionApp()` and `uninstallCompanionApp()` call
`invalidateCompanionStateCache()` after `callInstallScript()`
returns — **unconditionally**, whether the operation succeeded
or failed.

**Why**: a failed install attempt can still have partially
succeeded. The cache must not keep reporting
`{installed: false}` when the package manager may have
registered the app a few seconds later.

---

## 5. Shell Scripts

### 5.0 Layered Bootstrap (v1.5.0 Phase 0)

The shell code is split into two layers with an explicit
dependency direction:

```text
┌───────────────────────────────────────────────────────────────┐
│  Layer 0 — proxy/boot-mini.sh                                 │
│    log_msg, get_run_dir, read_conf, is_port_open,             │
│    get_webui_port, _MONITORING_UI_PORT                        │
│    Zero dependencies. Sourced by Layer 1.                     │
└──────────────────────────────┬────────────────────────────────┘
                               │ . (source)
                               ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 1 — proxy/functions.sh                                 │
│    Advanced helpers (firewall, backup, rotation, cleanup,     │
│    WebUI launcher, TOML reader, watchdog token reader).       │
│    Sources boot-mini.sh at load time.                         │
└──────────────────────────────┬────────────────────────────────┘
                               │ . (source)
                               ▼
┌───────────────────────────────────────────────────────────────┐
│  Callers — service.sh / action.sh / status.sh / watchdog.sh   │
│    / uninstall.sh / post-fs-data.sh / customize.sh            │
│  Consumers of Layer 1 (which transitively provides Layer 0).  │
└───────────────────────────────────────────────────────────────┘
```

**No caller changes in Phase 0.** The split is transparent to
every script that sources `functions.sh`.

**Why two files**: before Phase 0 the five primitives were
duplicated across 7+ shell scripts. A single change (e.g. adding
SNAP-MANIFEST in v1.3.0 or `apk/` in v1.5.0) required a manual
sweep of every copy. The Layer-0 file makes the primitives a
single source of truth without restructuring the call graph.

**CI guard**: `ci.yml`'s `backup-smoke-test` job verifies that
`functions.sh` sources `boot-mini.sh` and does NOT redefine any
of the five Layer-0 primitives. `make check-boot-mini` runs the
same checks locally.

### 5.1 Roles

| Script | Role | Trigger |
|---|---|---|
| `boot-mini.sh` | **Layer 0 primitives** (v1.5.0 Phase 0) | sourced |
| `customize.sh` | Install (+ backup/restore + 10 layers + APK mirror + install_app.sh extraction) | Magisk install |
| `service.sh` | Start services + periodic auto-backup + boot-path DNS auto-start | boot_completed |
| `post-fs-data.sh` | Emergency cleanup | early boot |
| `watchdog.sh` | Monitoring (services only) + token auth | standalone |
| `action.sh` | Open WebUI + `--backup` + `--diagnose` | Magisk Action |
| `status.sh` | Display status + `--diagnose` + `--json` | manual |
| `uninstall.sh` | Cleanup + orphan txn preservation | Magisk remove |
| `functions.sh` | **Layer 1** shell library | sourced |
| `install_app.sh` | 5-level `pm install` cascade | main.go via `/api/install_companion_app` |
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
  ├── log active profile + memory hint
  ├── cleanupOldTransactions()
  ├── read .pending_notification
  ├── auto_backup_if_needed(24 h)
  ├── rotate_backups(21)
  ├── start WebUI
  ├── bounded wait for WebUI ready (up to 60 s)
  ├── direct POST /api/ensure_running_service
  │           with X-Watchdog-Token header
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
  ├── read-only snapshot of backup state
  │
  └── loop:
        ├── sleep BACKOFF (30 s → 600 s exponential)
        ├── check disable
        ├── check WebUI → restart if needed
        └── check STATUS_FILE:
              - "ON"  → call POST /api/ensure_running_service
                        with X-Watchdog-Token header
              - "OFF" → skip (respect user intent)
```

**v1.3.0 note**: `service.sh` no longer depends solely on the
watchdog for boot-path DNS auto-start.

**v1.5.0 note**: The watchdog does **not** participate in the
companion app install flow. The install cascade is initiated by
`main.go` in response to an HTTP request, not by the watchdog.

**Signal handling note (v1.5.0+)**: `install_app.sh` runs in a
**separate process group** from the WebUI. If the WebUI is
restarted mid-cascade (e.g. by the watchdog restarting it for an
unrelated reason), the cascade continues to completion. This is
a deliberate design: install operations should not be
interruptible by WebUI restarts.

### 5.4 Backup Helpers in `functions.sh`

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
| `get_watchdog_token` | Read `$RUN_DIR/.watchdog_token` |

### 5.5 What Shell Scripts Do NOT Do

| Script | Non-responsibility |
|---|---|
| `post-fs-data.sh` | Does not touch `/sdcard/dnscrypt-webui-backup/` |
| `watchdog.sh` | Does not trigger backups |
| `service.sh` | Does not create pre-critical backups |
| `main.go` | Does not copy files itself — delegates to `functions.sh` |
| `uninstall.sh` | Does not delete the persistent backup directory |
| `install_app.sh` | Does not modify the WebUI's state — it is a pure "install and report" tool |

### 5.6 Uninstall Policy (v1.2.0)

`uninstall.sh` performs four decisions with respect to the
backup directory:

1. **Preserve `current/` and `<timestamp>-*` snapshots**.
2. **Preserve `orphan-txn-*` directories**.
3. **Rename `txn-*` with `.state=START` to `orphan-txn-*`**.
4. **Remove `txn-*` directories with `.state=COMMIT` or
   `.state=ROLLBACK`**.

**v1.5.0 note**: The `apk/` subfolder is preserved by the same
policy — it lives inside `$PERSISTENT_BACKUP`.

### 5.7 Watchdog Token Reader (v1.2.0)

See §4.5.1 and §5.4. Unchanged in v1.5.0.

### 5.8 `install_app.sh` (v1.5.0)

`install_app.sh` is the **1,101-line** shell script that
performs the 5-level `pm install` cascade. Its design priorities
are:

1. **Safety first** — never disable SELinux, never persist a
   Play Protect change.
2. **Broad compatibility** — 5 install strategies cover every
   realistic Android ROM.
3. **Deterministic output** — a single-line JSON on stdout, so
   `main.go` can parse it without shell-style heuristics.
4. **Localization** — AR + EN messages for the WebUI modal.

The script is staged at the **module root** (next to
`customize.sh`), not under `proxy/`. `main.go`'s
`getInstallScript()` resolves it via
`filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`.

**File layout note**: `customize.sh §[9]` extracts both
`install_app.sh` and `boot-mini.sh` into the module root. The
§[10] critical-files check verifies their presence. Any change
to the extracted script set must update both lists.

#### 5.8.1 Modes

| Invocation | Behavior |
|---|---|
| `install_app.sh` | Install the companion app (default) |
| `install_app.sh --status` | Print JSON install state |
| `install_app.sh --uninstall` | Remove the package |
| `install_app.sh --version` | Print the script version |
| `install_app.sh --help` | Print usage |

#### 5.8.2 Pre-flight Checks

Before attempting any install strategy:

1. **APK exists + non-empty** — `[ -s "$APK_PATH" ]`
2. **ZIP magic** — first two bytes are `PK` (0x50 0x4B)
3. **Size > 100 KB** — rejects truncated or placeholder files
4. **Free space on `/data` ≥ 3× APK size** — leaves headroom

If any check fails, the script exits with a JSON error response.

#### 5.8.3 SELinux Staging

`/data/adb/` has the SELinux context `adb_data_file`, which the
`system_server` process **cannot read**. The fix is to **stage
the APK** to `/data/local/tmp/` first:

```sh
STAGING_DIR="/data/local/tmp"
STAGING_APK="$STAGING_DIR/dnscrypt-companion.apk"

cp "$APK_PATH" "$STAGING_APK" 2>/dev/null
chmod 0644 "$STAGING_APK" 2>/dev/null
```

**Critically**: SELinux is **never disabled**. The script does
not call `setenforce 0`.

**Staged-APK cleanup**: the trap removes the staged APK on every
catchable exit path. The trap is split into **three separate
handlers** (`EXIT` / `INT` / `TERM`) with a `_CLEANED_UP`
re-entry guard inside a named `_cleanup_app()` function:

```sh
_CLEANED_UP=0

_cleanup_app() {
    if [ "$_CLEANED_UP" = "1" ]; then
        return 0
    fi
    _CLEANED_UP=1

    if [ "$_STAGED_OK" = "1" ] && [ -f "$STAGING_APK" ]; then
        rm -f "$STAGING_APK" 2>/dev/null
    fi

    if [ "$_VERIFIER_RESTORE" = "1" ]; then
        settings put global package_verifier_enable "$_VERIFIER_ORIG" 2>/dev/null
    fi

    return 0
}

trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM
```

**Why the split**: in POSIX sh, a trapped signal whose handler
does **not** call `exit` causes the script to **resume
execution** after the trap body returns. A single `EXIT INT TERM`
handler cleaned up but did not exit, so SIGINT during a direct CLI
invocation would resume the cascade loop.

#### 5.8.4 Play Protect Temporary Disable

Google Play Protect can silently block `pm install` of an APK
that did not originate from the Play Store. `install_app.sh`
temporarily disables the verifier for the duration of the
cascade.

**Trap installation order (important)**: the traps are
installed **before** any irreversible state change. Otherwise a
signal arriving between the `settings put` and the `trap`
installation would leave Play Protect permanently disabled.

```sh
# Install the traps BEFORE any irreversible state change.
trap '_cleanup_app' EXIT
trap '_cleanup_app; exit 130' INT
trap '_cleanup_app; exit 143' TERM

_VERIFIER_ORIG=$(_read_verifier_state 2>/dev/null)

case "$_VERIFIER_ORIG" in
    "1")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
        fi
        ;;
    "0")
        : # already disabled
        ;;
    "null")
        if settings put global package_verifier_enable 0 2>/dev/null; then
            _VERIFIER_RESTORE=1
        fi
        ;;
    *)
        # Unreadable — do not touch.
        _VERIFIER_RESTORE=0
        _VERIFIER_ORIG=""
        ;;
esac
```

**Cascade deadline**: the cascade is bounded by a **75-second
`CASCADE_DEADLINE_SECONDS`** constant, checked before each
strategy. The 75 s deadline is deliberately shorter than
`main.go`'s 90 s `INSTALL_TIMEOUT`.

**Restore value**: the trap restores the **exact captured
value** (`$_VERIFIER_ORIG`), not a hardcoded `1`.

**Caveats**:
- **Not restored on force reboot** — `settings put` writes to
  the system settings database. A force-reboot during the
  install may leave `package_verifier_enable` at `0` until the
  next Play Protect scan.
- **SIGKILL skips the trap** — `main.go` sends SIGKILL after
  `INSTALL_TIMEOUT`; SIGKILL is uncatchable. The 75-second
  cascade deadline exists to ensure the trap fires before that
  point on every realistic install.

#### 5.8.5 Cascade

The 5 strategies are tried in order. The first one that
succeeds (verified by polling `pm list packages`) wins; no
further strategies are attempted.

**Strategy 1** — direct install as the current user:

```sh
pm install -r --user 0 "$APK_PATH"
```

**Strategy 2** — install attributed to the shell app:

```sh
pm install -r --user 0 -i com.android.shell "$APK_PATH"
```

**Strategy 3** — session-based install:

```sh
local _session
_session=$(pm install-create -r --user 0 2>/dev/null | grep -oE '\[[0-9]+\]' | tr -d '[]')

if [ -z "$_session" ]; then
    STRATEGY_OUTPUT="install-create failed"
    return 1
fi

if ! pm install-write "$_session" base "$APK_PATH" >/dev/null 2>&1; then
    STRATEGY_OUTPUT="install-write failed"
    pm install-abandon "$_session" >/dev/null 2>&1
    return 1
fi

STRATEGY_OUTPUT=$(pm install-commit "$_session" 2>&1)
_pkg_installed
```

This uses the `pm install-create` / `pm install-write` /
`pm install-commit` API — the same API Google Play uses.

**Strategy 4** — magisk `su`:

```sh
magisk su -c "pm install -r --user 0 '$APK_PATH'"
```

**Strategy 5** — `cmd package install`:

```sh
cmd package install -r --user 0 "$APK_PATH"
```

**Cascade deadline**: the loop is bounded by the 75-second
`CASCADE_DEADLINE_SECONDS` constant. The deadline is checked at
the top of each iteration.

#### 5.8.6 Polling After Each Strategy

The polling helper is `_wait_for_install()`:

```sh
_wait_for_install() {
    local _timeout="${1:-15}"
    local _i=0
    while [ "$_i" -lt "$_timeout" ]; do
        _refresh_companion_pkg
        if _pkg_installed; then
            return 0
        fi
        sleep 1
        _i=$((_i + 1))
    done
    return 1
}
```

**Why 15 s?** Session-based installs (strategy 3) can take a few
seconds to commit on slow ROMs.

**Why polling instead of exit code?** Some ROMs return exit
code 0 from `pm install` even when the install was rejected.

#### 5.8.7 Package Detection

The detection helper is `_detect_companion_pkg()`:

```sh
COMPANION_PKG_CANDIDATES="com.gasciljh.dnsproxy.debug com.gasciljh.dnsproxy com.gasciljh.dnscrypt_proxy"

_detect_companion_pkg() {
    local _p
    for _p in $COMPANION_PKG_CANDIDATES; do
        if pm list packages 2>/dev/null | grep -qFx "package:$_p"; then
            printf '%s' "$_p"
            return 0
        fi
    done
    printf '%s' "com.gasciljh.dnsproxy.debug"
    return 0
}
```

The order is: debug → release → legacy.

> **Location note**: the candidate list is defined **only** in
> `install_app.sh`. `main.go` does not maintain a parallel list.

#### 5.8.8 Error Translation

The script detects 7 common failure modes and translates each
to AR + EN.

#### 5.8.9 Output Format

The script prints a **single-line JSON** object on stdout.

**Success example**:

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

#### 5.8.10 Implementation Notes

| ID | Topic |
|---|---|
| CIA-1 | Pre-flight checks (see §5.8.2) |
| CIA-2..5 | 5-level cascade (see §5.8.5) |
| CIA-6 | Error translation (AR + EN) — 7 common failure modes |
| CIA-7 | **Post-install verification** — the script extracts `version_name` via `dumpsys package <pkg>` and returns it in the JSON payload. **The script does NOT compare this value against `proxy/app-apk.version`** — the comparison is performed by the WebUI |
| CIA-8 | JSON output is guaranteed to be single-line |
| CIA-9 | Three modes (`--status`, `--uninstall`, default install) |
| CIA-10 | `SC2155` fix — declare and assign on separate lines |
| CIA-11 | `SC2329` fix — the `_attempt()` dispatcher uses an explicit `case` statement |
| CIA-12 | **`MODDIR` multi-strategy resolver** — five-step resolution (see `install_app.sh` header) |
| CIA-13 | JSON number detection — `apk_size` is a number; `version_name` is a string |
| CIA-14 | **`log_msg` silent no-op guard** — the guard uses OR (not nested AND); the write is wrapped in a command group `{ echo ... >> "$LOG_FILE"; } 2>/dev/null` |
| CIA-15 | `_json_escape` converts C0 control characters to their JSON escape sequences |
| CIA-16 | `_refresh_companion_pkg` is called from `_wait_for_install()` (per poll iteration) and the outer cascade loop |

---

## 6. Frontend

### 6.1 Structure

| File | Purpose | Size |
|---|---|---|
| `index.html` | Main WebUI (EN default + AR toggle) | ~160 KB |
| `dashboard.html` | Monitoring dashboard (EN default + AR toggle) | ~86 KB |
| `manifest.json` | PWA manifest (`lang="en"`, `dir="ltr"`, `version="1.5.0"`) | ~3 KB |
| `sw.js` | Service Worker (`CACHE_VERSION="v1.5.0"`) | ~24 KB |
| `offline.html` | Offline page (EN default + AR toggle) | ~18 KB |
| `app-debug.apk` | Companion Android app (optional) — build artifact, gitignored | ~3 MB |
| `app-debug.apk.sha256` | SHA256 of the APK — build artifact, gitignored | 87 B |
| `icon-192.svg` | Small icon | ~9 KB |
| `icon-512.svg` | Maskable icon | ~9 KB |
| `icon-192.png` | PWA icon | ~14 KB |
| `icon-512.png` | PWA icon | ~78 KB |
| `apple-touch-icon.png` | Launcher icon fallback | ~18 KB |
| `favicon-32x32.png` | favicon | ~1.4 KB |
| `favicon-16x16.png` | favicon | ~553 B |
| `favicon.ico` | favicon | ~4.7 KB |

**Manifest size reduction (v1.5.0)**: the manifest was reduced
from ~6 KB to ~3 KB by moving 7 `x-note-*` fields to
`docs/MANIFEST_NOTES.md`. The manifest now carries 6 fields
(`x-note-last-updated`, `x-note-version`, `x-note-companion-apk`,
`x-note-shortcuts`, `x-note-docs`). See §17 and
[`MANIFEST_NOTES.md`](MANIFEST_NOTES.md).

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

**v1.5.0 note**: The `shouldBypass()` rule for `/api/*` covers
all 4 companion-app endpoints. The Service Worker **never**
caches install state, tokens, or install results.

**v1.5.0 — precache count**: `PRECACHE_ASSETS` now contains
**12 files** (was 11 in v1.4.0). The addition is
`/dashboard.html`, which was previously fetched only on demand.

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
        │                           ┌────────┴────────┐
        │                           │                 │
        │                         [ok]             [error]
        │                           │                 │
        │                           ▼                 ▼
        └───────────────────────── VIEW ◄─────── ROLLBACK
```

### 6.4 PWA Features

- **Installable**: manifest + SW + icons (PNG + SVG fallback)
- **Offline**: standalone offline page (`offline.html`)
- **Update**: banner with CHECK_UPDATE
- **Shortcuts**: direct shortcut + Dashboard shortcut
- **Maskable icon**: PNG (for Android)
- **SameSite=Lax**: works from shortcuts easily
- **Favicons**: PNG + ICO for all browsers
- **Launcher icon fallback**: `apple-touch-icon.png`
- **Dynamic Ports**: links updated from `runtime_info`
- **LAN Support**: `window.location.hostname` instead of `127.0.0.1`
- **v1.1.0**: System Info panel shows `profile_key` + `memory_limit_mb`
- **v1.2.0**: System Info panel shows the 7-field backup state
- **v1.2.0**: Bilingual WebUI (EN default + AR toggle)
- **v1.3.0**: Smart dynamic PWA install button, live status LED
- **v1.4.0**: Install button is `<a download href="/app-debug.apk">`
- **v1.5.0**: Install button opens the install-method modal (IDX-24) — three actions across two categories
- **v1.5.0**: Companion button state survives language toggles (IDX-23)
- **v1.5.0**: Status card updates instantly on language toggle (IDX-23b)
- **v1.5.0**: Dashboard section-nav buttons scroll correctly (IDX-25) + centered hint (IDX-25a)
- **v1.5.0+**: Install rate-limit message rendered distinctly (IDX-429)
- **v1.5.0+**: Install-family 401 no longer triggers session-expired modal (IDX-401-DISTINCT)
- **v1.5.0+**: Dashboard `sessionExpired` reset on 401 (DASH-REFRESH-01 + DASH-SESSION-RETRY-01)
- **v1.5.0+**: Card-expand hint uses dual timers + `scrollend` (DASH-HINT-01 + DASH-HINT-02)

### 6.5 Service Worker Update Flow

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
│  Future solution (planned):                                  │
│                                                              │
│  Unify on a single port:                                     │
│  • Dashboard served from the same 9090 at /dashboard         │
│  • Single origin → single SW → offline for both              │
│  • refactor main.go (mux routing)                            │
└──────────────────────────────────────────────────────────────┘
```

### 6.7 Language Toggle (v1.2.0)

All three HTML pages ship with the same language-toggle
mechanism:

| Aspect | Implementation |
|---|---|
| Default language | English |
| Toggle button | `<button class="lang-toggle" id="langToggle">` |
| Translation objects | `translations.en` and `translations.ar` inline |
| Runtime function | `toggleLanguage()` |
| Preference storage | `localStorage['dnscrypt-lang']` |
| RTL CSS | `[dir="rtl"]` rules |
| Service Worker | Language-neutral |
| Server state | None |

### 6.8 iOS PWA Logic Removal (v1.4.0)

**Android-only project.** All iOS-specific PWA code has been
removed from `web/index.html` (~35 lines).

**`apple-touch-icon.png` is retained** — it is **not**
iOS-only. It is used by Android launchers as an icon fallback.

### 6.9 Companion Button State Fix (v1.5.0 — IDX-23)

**Symptom**: after installing the companion app, the WebUI
button correctly showed "✅ Installed" — but on any language
toggle, it reverted to "Install App".

**Root cause**: `updateUIStrings()` unconditionally set the
button label to `t('pwaInstallBtn')` on every language switch.

**Fix**: a clear separation of state and render.

```text
┌──────────────────────────────────────────────────────────────┐
│  1. companionState (single source of truth)                  │
│     { installed, version_name, expected_version }            │
│                                                              │
│  2. refreshCompanionState()                                  │
│     • xhrGet('/api?action=companion_app_state')              │
│     • update companionState                                  │
│     • mirror to sessionStorage['companion-state']            │
│     • call renderCompanionButton()                           │
│                                                              │
│  3. renderCompanionButton() (pure render)                    │
│     • read companionState + t()                              │
│     • set button text, icon, aria-label, disabled, dataset   │
│                                                              │
│  4. renderAllDynamic()                                       │
│     • renderCompanionButton()                                │
│     • status area (IDX-23b)                                  │
│     • stats area                                             │
│     • diagnostic file list                                   │
│                                                              │
│  5. updateUIStrings()                                        │
│     • ... all static labels ...                              │
│     • renderAllDynamic()  ← THE ONLY dynamic hook            │
└──────────────────────────────────────────────────────────────┘
```

**Button states**:

| State | Icon | Text | Disabled | `data-mode` |
|---|---|---|---|---|
| Not installed | 📲 | "Install App" | no | `install` |
| Installed, version match | ✅ | "Installed" | yes | `none` |
| Installed, version mismatch | 🔄 | "Update App" | no | `install` |

**A11y bonus**: `aria-label` is now dynamic.

**Session storage note**: the state is also mirrored into
`sessionStorage['companion-state']` so that on F5, the button
paints the correct label **before** the async XHR completes.

**Modal-layout fix**: `_resetModalLayout()` is now called by
`showConfirmModal()` at its start.

**Install-button click guard**: `handleCompanionInstall()`
disables the install button while the one-shot CSRF token is
being fetched.

**IDX-429 — install rate-limit message**: the failure branch of
`doCompanionInstall()` distinguishes HTTP 429 (rate limit) from
the generic install failure, and renders `t('installRateLimited')`.

**IDX-401-DISTINCT — install-family 401 distinctness**: a 401
from the companion-install family (`/api/install_companion_app`
or `/api?action=install_token`) no longer triggers the generic
"Session Expired" modal. The install endpoints emit 401 by
design when the one-shot CSRF token has expired — a perfectly
valid session can still receive this response.

### 6.10 Status-Card Language Fix (v1.5.0 — IDX-23b)

**Symptom**: on language toggle, the "🟢 Service Running"
status card only updated **~3 s later**, not instantly.

**Root cause**: `updateStatusUI()` was only called from SSE
event handlers and the status poller.

**Fix**: `renderAllDynamic()` now includes the status area.

**DASH-REFRESH-01 — Dashboard `isRefreshing` reset on 401**:
the dashboard's `fetchDashboardData()` previously left
`isRefreshing = true` when the 401 branch short-circuited. The
fix resets `isRefreshing = false` (and clears the spinner
class) inside the 401 branch **before** calling
`handleSessionExpired()`.

**DASH-SESSION-RETRY-01 — Session Expired primary action is a
full retry**: the pre-patch primary action navigated to the
WebUI — which helped the user re-login, but left the Dashboard
tab frozen until a manual reload. The new action resets both
`sessionExpired` and `isRefreshing`, then calls
`location.reload()`.

### 6.11 Dashboard Section-Nav Fix (v1.5.0 — IDX-25)

**Symptom**: in the Dashboard's sticky section-nav, clicking
"Runtime Info" or "Diagnostic Files" did nothing.

**Root cause**: `updateNavLinks()` generated `href` values that
did not match any element's `id`:

```
href="#runtime-info"   vs   id="runtimeInfoCard"
href="#diag-files"     vs   id="diagFilesCard"
```

**Fix**: `updateNavLinks()` now points at the real camelCase IDs.

### 6.12 Dashboard Centered Hint (v1.5.0 — IDX-25a)

**Additional issue** (discovered after IDX-25 was applied): the
"Runtime Info" and "Diagnostic Files" cards are **collapsible**.

**UX decision**: show a **hint toast** that teaches the user how
to expand it.

**Hint text**:

- EN: `💡 Click the card header to expand`
- AR: `💡 اضغط على عنوان البطاقة لفتحها`

**Positioning**: the toast is **centered in the viewport**,
using the same visual style and position as the welcome toast in
`index.html`.

**DASH-HINT-01 — dual-timer for the hint lifecycle**: the
pre-patch implementation stored only the outer (4 s) timer in
`cardHintTimer`; the inner (400 ms) removal timer was an
anonymous `setTimeout` that could not be cancelled. The fix
introduces a second global, `cardHintRemoveTimer`, cleared
alongside the first inside `resetCardHintTimer()`.

**DASH-HINT-02 — `scrollend` listener with fallback**: the hint
is scheduled on the actual end of the browser's smooth scroll
via the `scrollend` event, with a 400 ms `setTimeout` fallback
for browsers that do not implement `scrollend`. Feature
detection must use `'onscrollend' in window` — `scrollend` is
exposed via `GlobalEventHandlers` on the window prototype
chain, not on `document`.

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
| Companion app version | `proxy/app-apk.version` | ✓ | manual |
| `portCacheMap` | memory | lost on restart | `isPortOpenCached` |
| `systemShell` | memory (sync.Once) | lost on restart | `getSystemShell` |
| `authCache` | memory | lost on restart | `getMonitoringAuth` |
| `rebuildMu` | memory | lost on restart | `rebuildBlocklist` |
| `currentMemLimit` | memory | recomputed at startup | `applyMemoryLimit` |
| `currentProfile` | memory | recomputed at startup | `applyMemoryLimit` |
| `backupMu` | memory | lost on restart | `createAutoBackup` |
| `watchdogTok` | memory | lost on restart (regenerated) | `getWatchdogToken` |
| `$PERSISTENT_BACKUP` | `/sdcard/...` | ✓ (survives uninstall) | `customize.sh`, `service.sh`, `main.go` |
| `.last_stable` | file | ✓ | `customize.sh` |
| `.upgrade_history.json` | file | ✓ | `customize.sh` |
| `.last_auto_backup` | file (marker) | ✓ (mtime) | `auto_backup_if_needed` |
| `.pending_notification` | file (transient) | ✓ | `customize.sh` writes; `main.go` deletes |
| `.watchdog_token` | file | ✓ | `customize.sh` or `main.go` |
| `installTokens` | memory | lost on restart | `generateInstallToken()` |
| `installAttempts` | memory | lost on restart | `recordInstallAttempt()` |
| `companionStateCache` | memory | lost on restart | `getCompanionState()` |
| `cachedWebPort` / `cachedDashPort` | memory | lost on restart | `readConfPortCached()` |

**v1.5.0 note on ephemeral state**: The three new v1.5.0 states
are all deliberately ephemeral:

- **`installTokens`** — a token lives at most 60 s.
- **`installAttempts`** — a per-IP rate limiter.
- **`companionStateCache`** — a pure performance cache.

**v1.5.0+ note on the port cache**: the `cachedWebPort` /
`cachedDashPort` state is populated by `readConfPortCached()`
and expires after `CONF_PORT_CACHE_TTL` (30 s). Loss on restart
is irrelevant — the next `/api?action=runtime_info` request
repopulates the cache from `webui.conf`.

### 7.2 Client-side State

| State | Storage | Lifetime |
|---|---|---|
| Drafts (Allowlist/Denylist) | localStorage | 1 hour |
| Session token | memory only (cookie-based) | tab lifetime |
| Show idle | localStorage | persistent |
| Server hashes | memory | page lifetime |
| `currentStatus` | memory | page lifetime |
| `PORTS` | memory | page lifetime (updated from runtime_info) |
| Language preference | `localStorage['dnscrypt-lang']` | persistent |
| Current language (runtime) | memory (`currentLang`) | page lifetime |
| `companionState` | memory + `sessionStorage['companion-state']` | page lifetime + F5 |
| `cardHintTimer` / `cardHintRemoveTimer` | memory | page lifetime |
| `cardHintScheduled` | memory | page lifetime |
| `sessionExpired` / `isRefreshing` | memory | page lifetime |

### 7.3 Conflict Detection

```text
Client                          Server
  │                               │
  ├── save(content, hash_A) ──────► │
  │                               │
  │                               ├── if hash_A ≠ current_hash:
  │                               │      return 409 conflict
  │◄───── 200 {hash: B} ──────────┤
  │                               │
  ├── next save: hash_B           │
```

**v1.5.0+ note**: `appendDenylist()` now passes
`getRulesState().DenylistHash` to `saveDenylist()` instead of
`fileHash(DENYLIST_FILE)`. Both now use the same hash source, so
an external modification of `denylist.txt` no longer produces a
spurious `conflict` response.

### 7.4 State Machine — STATUS_FILE

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  User Intent (STATUS_FILE)      Actual State (probe)         │
│  ────────────────────────       ──────────────────────       │
│                                                              │
│  START                                  ┌─── ON ────┐        │
│    │                                    │            │        │
│    ├──► startService() ──► [ON] ────────►│            │        │
│    │                              ▲     │            │        │
│    │                        Watchdog    │            │        │
│    │                        restarts    │            │        │
│    │                        on crash    │            │        │
│    │                              │     │            │        │
│    │                        [ON]─┴─────┐            │        │
│    │                              [crash]            │        │
│    │                                [OFF]────────────┘        │
│    │                                                         │
│    └──► stopService() ──► [OFF]                               │
│                                                              │
│  User stops ─────────────────────────► [OFF]──►              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 7.5 User Intent vs Actual State

See §7.4. `STATUS_FILE` is written only by `startService` /
`stopService` (and by the disable path in `service.sh`); it is
read-only from the perspective of `getStatus()`.

### 7.6 Backup State Machine (v1.2.0)

See §3.10. Extended in v1.5.0 with the APK mirror.

### 7.7 Companion Install State Machine (v1.5.0)

```text
┌──────────────────────────────────────────────────────────────┐
│  Idle                                                        │
│    • companionState.installed = false (default)              │
│    • companionState.installed = true (after install)         │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               │ user clicks "Install App"
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Token request                                               │
│    • GET /api?action=install_token                           │
│    • on success → showInstallModal(token)                    │
│    • on failure → showMsg(installTokenError)                 │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               │ user chooses from modal
                               ▼
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ Install   │   │ Open      │   │ Direct    │
        │ locally   │   │ GitHub    │   │ download  │
        └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
              │               │               │
              ▼               ▼               ▼
        ┌───────────┐   ┌───────────┐   ┌───────────┐
        │ POST      │   │ window.   │   │ window.   │
        │ install_  │   │ open()    │   │ open()    │
        │ companion │   │           │   │           │
        │ _app      │   │           │   │           │
        └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
              │               │               │
              │               └───────┬───────┘
              │                       │
              ▼                       ▼
        ┌───────────┐           ┌───────────┐
        │ Success?  │           │ Close     │
        │           │           │ modal     │
        └─────┬─────┘           └───────────┘
              │
        ┌─────┴─────┐
        │            │
        ▼            ▼
    ┌───────┐   ┌─────────────────┐
    │  OK   │   │  Failure          │
    │       │   │  • 401: token    │
    │       │   │    expired       │
    │       │   │    → installToken│
    │       │   │    Error          │
    │       │   │  • 429: rate     │
    │       │   │    limit         │
    │       │   │    → installRate │
    │       │   │    Limited       │
    │       │   │  • other:        │
    │       │   │    error modal + │
    │       │   │    "download     │
    │       │   │     manually"    │
    └───┬───┘   └─────────────────┘
        │
        ▼
    ┌─────────────────┐
    │ refreshCompanion │
    │ State()          │
    │  • button → ✅   │
    └─────────────────┘
```

**401 / 429 branch note**: both branches render distinct
messages. The 401 branch does **not** display the generic
"Session Expired" modal — `xhrRequest()` suppresses that modal
for install-family URLs. The 429 branch renders the new
`installRateLimited` translation string.

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
├── functions.sh                   # Layer 1 shell library (sources boot-mini.sh)
├── boot-mini.sh                   # v1.5.0 Phase 0 — Layer 0 primitives
├── watchdog.sh                    # standalone process (token auth)
├── customize.sh                   # installer (10 layers + APK mirror v1.5.0)
├── install_app.sh                 # v1.5.0 — 5-level cascade (1,101 lines)
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
│   ├── app-debug.apk              # companion APK (optional, v1.4.0)
│   ├── app-debug.apk.sha256       # APK SHA256 (optional, v1.5.0)
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
    ├── app-apk.version            # companion app version (v1.4.0)
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
├── apk/                           # companion APK mirror (v1.5.0)
│   ├── app-debug.apk              # ← best-effort copy
│   └── app-debug.apk.sha256       # ← SHA256 (if present)
├── .last_stable                   # pointer to last known-good snapshot
├── .last_auto_backup              # mtime marker for periodic backup
├── .upgrade_history.json          # full upgrade log (with jq)
├── .upgrade_history.txt           # fallback log (without jq)
├── .pending_notification          # transient; read+deleted by main.go
└── README.md                      # user-facing guide

/data/adb/dnscrypt-recovery        # external recovery trigger (optional, v1.2.0)
```

> **Note**: `install_app.sh` and `boot-mini.sh` are staged at the
> **module root** (next to `customize.sh`), **not** under `proxy/`.
> `main.go` resolves `install_app.sh` via
> `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`. Both files are
> extracted by `customize.sh §[9]` and verified by `customize.sh
> §[10]`'s critical-files check.

**Line counts (canonical, verified with `wc -l` on 2026-10-13)**:

| File | Lines |
|---|---:|
| `proxy/main.go` | 5,519 |
| `proxy/install_app.sh` | 935 |
| `proxy/customize.sh` | 2,718 |
| `proxy/functions.sh` | 2,059 |
| `proxy/uninstall.sh` | 1,387 |
| `proxy/watchdog.sh` | 1,090 |
| `scripts/package_module.sh` | 972 |

These values supersede any earlier figure. The canonical Line
counts table lives in `CHANGELOG.md`.

### 8.2 Repository Layout (97 tracked files)

> **Tracked files**: **97** — canonical. Verified with
> `git ls-files | wc -l`.
>
> **Build artifacts**: **0–11**, depending on local build state.
> All are gitignored by `.gitignore` §[20].
>
> **Directories**: **15–18**, following the same build-state
> dependency.

```text
dnscrypt-proxy-webui/          # 97 tracked files + 0-11 build artifacts (97-108 total)
│
├── Root files (15)
│   ├── VERSION                    # module version (v1.5.0)
│   ├── module.prop                # Magisk/KernelSU definition
│   ├── update.json                # auto-update metadata
│   ├── LICENSE                    # MIT
│   ├── README.md                  # project overview
│   ├── CHANGELOG.md               # version history
│   ├── CODE_OF_CONDUCT.md         # Contributor Covenant v2.1
│   ├── SECURITY.md                # security policy (summary)
│   ├── Makefile                   # unified commands
│   ├── .editorconfig              # editor rules
│   ├── .gitattributes             # Git attributes
│   ├── .gitignore                 # Git ignore
│   ├── .pre-commit-config.yaml    # pre-commit hooks
│   ├── .secrets.baseline          # detect-secrets baseline
│   └── .shellcheckrc              # ShellCheck config
│
├── .github/ (13 tracked files + 4 subdirs = 17 entries)
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   ├── SECURITY.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── release.md
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   ├── codeql/
│   │   └── codeql-config.yml
│   └── workflows/
│       ├── ci.yml                 # + verify install_app.sh + verify boot-mini.sh
│       ├── codeql.yml
│       ├── release.yml            # + stage .sha256
│       └── upgrade-test.yml
│
├── .devcontainer/ (2)
│   ├── devcontainer.json
│   └── setup.sh
│
├── META-INF/ (2)
│   └── com/google/android/
│       ├── update-binary
│       └── updater-script
│
├── scripts/ (6)
│   ├── fetch_dns_binaries.sh
│   ├── fetch_app_apk.sh
│   ├── generate-icons.sh
│   ├── package_module.sh          # + install_app.sh + boot-mini.sh
│   ├── release.sh
│   └── release-patch.sh
│
├── proxy/ (18 tracked files)
│   ├── action.sh
│   ├── app-apk.version
│   ├── boot-mini.sh               # v1.5.0 Phase 0 (NEW)
│   ├── build.sh
│   ├── customize.sh               # + APK mirror §[10c]
│   │                              # + install_app.sh extraction
│   │                              # + boot-mini.sh extraction
│   ├── dnscrypt-proxy.toml
│   ├── dnscrypt-proxy.version
│   ├── functions.sh
│   ├── go.mod                     # 1 dependency (filepath-securejoin)
│   ├── go.sum
│   ├── install_app.sh             # v1.5.0 (NEW — 1,101 lines)
│   ├── main.go                    # + 4 endpoints + 10 helpers
│   ├── post-fs-data.sh
│   ├── service.sh
│   ├── status.sh
│   ├── uninstall.sh
│   ├── watchdog.sh
│   └── webui.conf
│
├── web/ (13 tracked files + 2 build artifacts)
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
│   ├── favicon.ico
│   ├── [app-debug.apk]            # build artifact (gitignored)
│   └── [app-debug.apk.sha256]     # build artifact (gitignored)
│
├── dist/                          # ← entire directory is gitignored
│   ├── [dnscrypt-webui-<ver>-module.zip]
│   └── [dnscrypt-webui-<ver>-module.zip.sha256]
│
└── docs/ (19 tracked + 9 in adr/ = 28 tracked files)
    ├── API.md
    ├── ARCHITECTURE.md
    ├── BACKUP.md
    ├── BRANCHING.md
    ├── COMPATIBILITY.md
    ├── CONTRIBUTING.md
    ├── DEVELOPMENT.md
    ├── DNS_BINARIES.md
    ├── EMERGENCY.md
    ├── FAQ.md
    ├── GLOSSARY.md
    ├── HALL_OF_FAME.md
    ├── INSTALL.md
    ├── MANIFEST_NOTES.md              # ← v1.5.0 (NEW)
    ├── RELEASE_PROCESS.md
    ├── ROADMAP.md
    ├── SECURITY.md
    ├── TROUBLESHOOTING.md
    ├── UPGRADE.md
    └── adr/ (9 files)
        ├── README.md
        ├── 0001-two-branch-model.md
        ├── 0002-automated-releases.md
        ├── 0003-post-release-sync.md
        ├── 0004-unified-pr-template.md          (⚠️ Superseded)
        ├── 0005-release-specific-pr-template.md
        ├── 0006-rename-hotfix-to-release-patch.md
        ├── 0007-external-dependency-securejoin.md
        └── 0008-layered-bootstrap.md            # ← v1.5.0
```

**Per-directory breakdown of the 97 tracked files**:

| Directory | Tracked | Notes |
|---|:---:|---|
| Root | **15** | Version + config + governance + hidden configs + `.shellcheckrc` |
| `.github/` (files only) | **13** | CI + templates + CodeQL config |
| `.devcontainer/` | **2** | Dev environment |
| `META-INF/` | **2** | Magisk bootstrap |
| `scripts/` | **6** | Build + release tooling |
| `proxy/` | **18** | Go + Shell (includes `boot-mini.sh` and `install_app.sh`) |
| `web/` (tracked) | **13** | 5 HTML/JSON/JS + 8 icons |
| `docs/` (files only) | **19** | Documentation guides (includes `MANIFEST_NOTES.md`) |
| `docs/adr/` | **9** | ADR-0001..0008 + README |
| **Total** | **97** | **Committed to the repository** |

**The 7 tracked files added in v1.5.0**:

- `.shellcheckrc`
- `.github/codeql/codeql-config.yml`
- `docs/adr/0007-external-dependency-securejoin.md`
- `docs/adr/0008-layered-bootstrap.md`
- `docs/MANIFEST_NOTES.md`
- `proxy/boot-mini.sh`
- `proxy/go.sum`

**Gitignored directories** (not counted in the 97 tracked files):

| Directory | Files | Purpose |
|---|:-:|---|
| `dist/` | 2 | Release ZIP + checksum |
| `proxy/build/` | 7 | Cross-compiled binaries + logs |
| `web/app-debug.apk` + `.sha256` | 2 | Companion app |
| **Total** | **11** | All ignored by `.gitignore` §[20] |

### 8.3 File Count by Directory

#### The three canonical states

| State | When | Tracked | Artifacts | Working tree | Dirs |
|---|---|:---:|:---:|:---:|:---:|
| **Fresh clone** | After `git clone <repo>` | 97 | 0 | 97 | 15 |
| **After package** | After `make fetch-apk && make package` | 97 | 4 | 101 | 17 |
| **After full build** | After `make build` | 97 | 11 | 108 | 18 |

#### Build artifacts (0-11 — depends on local build state)

| Directory / File | Fresh clone | After package | After full build |
|---|:-:|:-:|:-:|
| `dist/` (ZIP + `.sha256`) | 0 | 2 | 2 |
| `web/app-debug.apk` | 0 | 1 | 1 |
| `web/app-debug.apk.sha256` | 0 | 1 | 1 |
| `proxy/build/` (4 binaries + `checksums.txt` + 2 `.log`) | 0 | 0 | 7 |
| **Artifacts total** | **0** | **4** | **11** |

#### Grand totals

| Metric | Fresh clone | After package | After full build |
|---|:-:|:-:|:-:|
| Tracked files | 97 | 97 | 97 |
| Build artifacts | 0 | 4 | 11 |
| **Working tree** | **97** | **101** | **108** |
| **Directories** | **15** | **17** | **18** |

#### Cross-check — reproducible with three commands

```bash
# 1. Tracked files — canonical; should print 97
git ls-files | wc -l

# 2. Total files in working tree, excluding .git — 97/101/108 by state
find . -type f -not -path './.git/*' | wc -l

# 3. Total directories, excluding .git — 15/17/18 by state
find . -type d -not -path './.git/*' -not -name '.git' | wc -l
```

**Cross-check against other files**: `README.md` §Project
Structure uses the same three-state model and the same
per-directory breakdown, with `proxy/` = **18** and `docs/` =
**19**. The two files agree on all three states.

---

## 9. Watchdog & Recovery

See §5.3 for the watchdog model.

**v1.5.0 note — watchdog non-participation in companion install**:

The watchdog does **not** trigger, monitor, or interfere with
the companion app install flow. The install cascade is initiated
by `main.go` in response to an HTTP request, and it completes
within the request's lifetime. The watchdog's role is limited to
the WebUI and DNS engine processes.

If a user triggers an install and the WebUI is restarted mid-
cascade (e.g. by the watchdog restarting the WebUI process for
an unrelated reason), the cascade continues to completion —
because `install_app.sh` runs in a **separate process group**
from the WebUI.

This is a deliberate design: install operations should not be
interruptible by WebUI restarts.

**v1.5.0+ note — signal-handling patch**: the `install_app.sh`
trap is split into three separate handlers (`EXIT` / `INT` /
`TERM`) with a `_CLEANED_UP` re-entry guard. See §5.8.3 and
§5.8.4.

---

## 10. Performance

### 10.1 Memory Profile

| Metric | Value |
|---|---|
| RAM (WebUI idle) | ~15 MB |
| RAM (WebUI peak) | ~25 MB |
| Battery | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (100K entries) | ~200 ms |
| `rebuildBlocklist` (500K entries) | ~1 s |

**v1.5.0 addition**: `installTokens` and `installAttempts` add
negligible memory (< 1 KB per active install session).
`companionStateCache` is a single small struct (< 200 bytes).

**v1.5.0+ addition**: the `portConfMu` cache adds two short
strings (`cachedWebPort`, `cachedDashPort`) and one
`time.Time` — under 100 bytes.

### 10.2 CPU Profile

**v1.5.0 additions**:

| Operation | Duration |
|---|---|
| `generateInstallToken()` | ~10 µs |
| `validateAndConsumeInstallToken()` | < 5 µs |
| `isInstallLockedOut()` | < 5 µs |
| `getCompanionState()` (cache hit) | < 1 µs |
| `getCompanionState()` (cache miss) | ~50-150 ms |
| `callInstallScript()` | 5-15 s typical, 60+ s worst case |

**v1.5.0+ additions**:

| Operation | Duration |
|---|---|
| `getWebUIPort()` / `getDashboardPort()` (cache hit) | < 1 µs |
| `getWebUIPort()` / `getDashboardPort()` (cache miss) | ~10-50 µs (one `webui.conf` read) |

### 10.3 Disk I/O

The v1.5.0 companion install flow adds:

| Operation | I/O |
|---|---|
| Copy APK to `/data/local/tmp/` | ~3 MB write (one-time per install) |
| SHA256 verify (if `.sha256` present) | ~3 MB read + hash (~5 ms) |

**v1.5.0+ note**: a single `/api?action=runtime_info` request
previously triggered two `webui.conf` reads (one for `PORT`, one
for `DASHBOARD_PORT`). After the port cache, that request
triggers at most one read per 30-second window.

### 10.4 Network

The v1.5.0 companion install flow does **not** use the network
on the local install path.

### 10.5 Dashboard Metrics Pipeline

Unchanged from v1.4.0.

### 10.6 Backup Storage

The v1.5.0 `apk/` subfolder adds ~3 MB once (see §10.7).

### 10.7 Companion APK Storage

| Metric | Value |
|---|---|
| APK size (typical) | ~3 MB |
| Cache location (build machine) | `~/.cache/dnscrypt-proxy-webui/app/` |
| Module ZIP impact | +~3 MB (optional) |
| Persistent backup mirror (`apk/`) | +~3 MB (best-effort, one-time) |
| Runtime memory impact | 0 MB — served as a static file |
| Cache-Control | `public, max-age=3600, immutable` |
| Git tracking | ❌ Not tracked (`.gitignore` §[20]) |
| Total storage footprint (worst case) | ~6 MB (module + backup mirror) |

---

## 11. Trade-offs & Decisions

### 11.1 – 11.44

See the v1.4.0-era decisions. Unchanged.

### 11.45 v1.5.0 Phase 0 — Layered Bootstrap: Two Files vs Seven Copies

**Decision**: split the shell library into **Layer 0** (`proxy/boot-mini.sh`)
and **Layer 1** (`proxy/functions.sh`).

**Context**: before Phase 0, the five primitives (`log_msg`,
`get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`) and
the `_MONITORING_UI_PORT` constant were duplicated across 7+
shell scripts. A change to any primitive (e.g. adding
SNAP-MANIFEST support to `read_conf` in v1.3.0, or the `apk/`
skip in `rotate_backups` in v1.5.0) required a manual sweep of
every copy.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep the duplication, add a CI check that every copy is byte-identical | CI check would fail on legitimate per-caller variations (e.g. different log prefixes); a single source of truth is simpler |
| Merge all helpers into one `functions.sh` | No benefit — the duplication problem is that `functions.sh` was implicitly re-declaring primitives already defined by callers |
| Extract to a shared `.so` or equivalent | Not portable across BusyBox / mksh / APatch |
| Layer-0 file sourced by Layer-1 file | ✅ Single source of truth; no caller changes; explicit dependency direction |

**Trade-off**: one more file to maintain. In exchange, the
primitives have exactly one definition, and CI verifies that
`functions.sh` does not accidentally re-declare them.

### 11.46 v1.5.0 — Companion Install: Root Cascade vs Browser Download

**Decision**: replace the direct `<a download>` browser link
(v1.4.0) with a **root-level install cascade**.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep the `<a download>` link | The button label says "Install App" but the action only downloads |
| Use a WebView-install intent | Requires `REQUEST_INSTALL_PACKAGES` permission; not reliable across ROMs |
| Use an `intent://` URL | Only works inside a WebView, not in the browser |
| Root cascade (5 levels) | ✅ Fast, one-tap, no browser UX |

### 11.47 v1.5.0 — SELinux: Staging vs `setenforce 0`

**Decision**: **never** disable SELinux. Stage the APK to
`/data/local/tmp/`.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| `setenforce 0` during install | Disables the entire security layer for the duration |
| `chcon` on `/data/adb/` | Changes the module's own SELinux context |
| Bind-mount the APK elsewhere | Requires a mount namespace |
| Copy to `/data/local/tmp/` | ✅ Simple, single command, no security relaxation |

### 11.48 v1.5.0 — Package Name: Candidates vs Hardcoded

**Decision**: try **3 candidates** in order.

### 11.49 v1.5.0 — Companion Button: Modal vs Direct Install

**Decision**: show an **install-method modal** (IDX-24) instead
of installing immediately on click. The modal presents **three
actions across two categories** (local install + two GitHub
options).

### 11.50 v1.5.0 — Dashboard Hint: Centered vs Positioned

**Decision**: center the card-expand hint in the viewport
(IDX-25a).

### 11.51 v1.5.0 — Modal Layout Reset: Idempotent Pre-reset vs Manual

**Decision**: `showConfirmModal()` calls `_resetModalLayout()`
at its **start**, unconditionally.

### 11.52 v1.5.0 — Cascade Deadline: 75 s vs Unbounded

**Decision**: the 5-level cascade in `install_app.sh` is bounded
by a **75-second wall-clock deadline**.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Unbounded cascade | On a pathologically slow ROM, the cascade could run past `main.go`'s 90 s `INSTALL_TIMEOUT` without the trap firing |
| Deadline > `INSTALL_TIMEOUT` (e.g. 100 s) | The parent process would kill the script before the trap fires |
| Deadline = `INSTALL_TIMEOUT` (90 s) | No headroom for JSON output, exit trap, and shell teardown |
| Deadline = 75 s | ✅ Leaves 15 s of headroom |

### 11.53 v1.5.0 — Trap Restore Value: `$_VERIFIER_ORIG` vs Hardcoded `1`

**Decision**: the `EXIT INT TERM` trap restores the **exact
captured value** of `package_verifier_enable`.

### 11.54 v1.5.0 — `install_app.sh` Extraction: Extraction Fix vs Packaging Fix

**Decision**: fix the **extraction** side
(`customize.sh §[9]`), not the packaging side.

### 11.55 v1.5.0+ — Logger Reentrancy: Three-Layer Split vs Other Approaches

**Decision**: split the logger into three distinct functions:

- `logWithLevel(level, msg)` — public entry point: applies the
  level filter, acquires `logMutex`, delegates to `logLocked`.
- `logLocked(level, msg)` — internal: assumes `logMutex` is
  held. Performs rotation and delegates to `writeLocked`.
- `writeLocked(level, msg)` — internal: assumes `logMutex` is
  held. Writes a single formatted line. No level filter.

**Context**: the pre-patch `logWithLevel` held `logMutex` and
called `logWithLevel` recursively from inside the rotation
branch when `os.Rename` failed. `sync.Mutex` is **not
reentrant** in Go, so a failed rename on a full or read-only
`/data/local/tmp` would deadlock the calling goroutine.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Channel-based async logger (goroutine) | Non-deterministic log ordering; invasive refactor |
| Deferred error reporting (collect errors, print after unlock) | Adds a third state; defers the diagnostic |
| Remove the recursive call entirely (drop the warning) | Loses the diagnostic for the exact scenario that caused the deadlock |
| Three-layer split | ✅ Idiomatic in Go; minimal diff; preserves the public API |

### 11.56 v1.5.0+ — Port Cache: 30 s TTL vs No Cache vs Longer TTL

**Decision**: cache `webui.conf` port reads for **30 seconds**.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| No cache | Two `webui.conf` reads per `runtime_info` request |
| Cache indefinitely (until restart) | A manual `webui.conf` edit would require a restart |
| Longer TTL (e.g. 5 min) | Same surprise on a smaller scale |
| 30 s TTL | ✅ Collapses the two reads; the staleness window is shorter than any human edit-confirm cycle |

### 11.57 v1.5.0+ — HTTP WriteTimeout: 60 s vs 150 s

**Decision**: `HTTP_WRITE_TIMEOUT = 150 s`.

**Context**: the v1.5.0 release shipped with
`HTTP_WRITE_TIMEOUT = 60 s`, which is shorter than the
`INSTALL_TIMEOUT = 90 s` used by the companion install handler.
A slow install would complete successfully on the device but the
client would see a connection reset before the JSON response
arrived.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep 60 s, raise `INSTALL_TIMEOUT` to 45 s | Would truncate the cascade deadline, defeating the multi-strategy fallback |
| Per-endpoint `WriteTimeout` | Go's `http.Server` does not support per-handler write timeouts |
| `150 s` global | ✅ Leaves 60 s of headroom above `INSTALL_TIMEOUT` |

### 11.58 v1.5.0+ — Install Error Status: 200 for Failure vs 4xx

**Decision**: keep the server-side contract unchanged (200 for
install failure, 4xx for auth/rate-limit/token failures), and
fix the **frontend** to distinguish the three cases:

- 429 → `t('installRateLimited')`.
- 401 → `t('installTokenError')`.
- other → `t('installError')` (generic).

**Rationale**: an install failure is a **valid outcome of a
well-formed request**. The WebUI needs to read the AR/EN message
from the body. Only auth/rate-limit/token failures use 4xx.

### 11.59 v1.5.0+ — Install-Family 401 Handling: Suppress vs Forward

**Decision**: a 401 from `/api/install_companion_app` or
`/api?action=install_token` no longer triggers the generic
**"Session Expired"** modal.

**Rationale**: the install endpoints emit 401 by design when the
one-shot CSRF token has expired (60 s TTL, single use). A
perfectly valid session can still receive this response. The
pre-patch `xhrRequest()` called `handleSessionExpired()` on
**every** 401 — showing the user a misleading "your session
expired" dialog.

### 11.60 v1.5.0+ — Signal Traps: Single Handler vs Three Handlers

**Decision**: split the `install_app.sh` trap into **three
separate handlers** (`EXIT` / `INT` / `TERM`) with a
`_CLEANED_UP` re-entry guard inside a named `_cleanup_app()`
function.

**Context**: in POSIX sh, a trapped signal whose handler does
**not** call `exit` causes the script to **resume execution**
after the handler returns. The pre-patch single `EXIT INT TERM`
handler cleaned up but did not exit, so on SIGINT the cascade
loop continued — re-staging the APK and re-disabling Play
Protect.

**Impact**:

- **Direct CLI path** (`su -c "sh install_app.sh"`): Ctrl+C and
  SIGTERM now terminate immediately after cleanup. Exit codes
  are `130` and `143` respectively.
- **Primary invocation path** (`main.go` via
  `exec.CommandContext`): **no change**. `main.go` sends SIGKILL
  after `INSTALL_TIMEOUT` — SIGKILL is uncatchable.

### 11.61 v1.5.0+ — Dashboard Hint: Dual Timers + `scrollend`

**Decision**: the card-expand hint uses **two timers** (outer
4 s display + inner 400 ms fade-out removal) and is scheduled
via the `scrollend` event with a 400 ms `setTimeout` fallback.

**Context**:

- The pre-patch implementation stored only the outer timer in
  `cardHintTimer`; the inner removal timer was an anonymous
  `setTimeout` that could not be cancelled. A rapid
  double-click during the fade-out window left the inner timer
  running against the newly re-shown toast.
- The pre-patch scheduling used an unconditional
  `setTimeout(400)`, which fired too early on long scroll
  distances and unnecessarily late on short ones.

**Feature detection note**: `scrollend` is exposed via
`GlobalEventHandlers` on the window prototype chain. Testing
`'onscrollend' in document` always returns `false` — the event
name is on `window`, not on `document`.

### 11.62 v1.5.0 — Manifest Notes Extraction: Inline vs Sidecar

**Decision**: extract 7 `x-note-*` fields from
`web/manifest.json` into a new `docs/MANIFEST_NOTES.md`.

**Context**: the v1.4.0 manifest carried 11 `x-note-*` fields
totaling ~6 KB. The browser parses the entire manifest on every
PWA install. Large manifests delay the install prompt.

**Rejected alternatives**:

| Alternative | Problem |
|---|---|
| Keep all 11 fields inline | Slower install prompt; harder to diff |
| Delete the fields entirely | Loses technical documentation for contributors |
| Move only a few | Inconsistent — hard to know what lives where |
| Extract to `docs/MANIFEST_NOTES.md` + add `x-note-docs` pointer | ✅ Manifest stays ~3 KB; the reference moves to a versioned, greppable file |

**Result**: the manifest now carries 6 fields
(`x-note-last-updated`, `x-note-version`, `x-note-companion-apk`,
`x-note-shortcuts`, `x-note-docs`) at ~3 KB. The 7 extracted
fields (maskable, icon-source, language, backup-schema, ports,
future-work, extended companion-apk) live in
[`MANIFEST_NOTES.md`](MANIFEST_NOTES.md).

---

## 12. Blocklist Filtering Strategy

The blocklist filtering pipeline is unchanged from v1.4.0.

### 12.9 v1.5.0 non-scope

The companion app install flow is **not** a blocklist concern:

- It does not modify `blocklist.txt`.
- It does not trigger a `rebuildBlocklist`.
- It does not create a pre-critical backup.
- It does not participate in the 10 defensive layers.

The 5 user config files are unaffected by the install. The APK
is a **build artifact**, not user data.

---

## 13. Firewall Architecture — Custom Chains

The firewall architecture is unchanged from v1.4.0.

### 13.8 v1.5.0 non-scope

The companion app install flow does **not** modify any firewall
rules.

---

## 14. DNS Binaries Management

The DNS binaries management is unchanged from v1.4.0.

### 14.13 v1.5.0 — Companion APK Fetch

See §3.5b. The v1.5.0 addition is the `.sha256` staging in
`release.yml`. This is referenced throughout the document as
**APK-8**.

### 14.14 v1.5.0 — `fetch_app_apk.sh` non-change

`scripts/fetch_app_apk.sh` was **not modified** in v1.5.0. The
`.sha256` fetch is done inline in `release.yml`, not in the
script.

---

## 15. Platform Abstraction

The platform abstraction layer is unchanged from v1.4.0.

**v1.5.0 note**: `install_app.sh` uses the same platform
detection as `functions.sh`.

**V15-CODE-03 note**: `main.go`'s `callInstallScript()` also
resolves the shell through `getSystemShell()`, matching every
other shell invocation in the file.

---

## 16. Metrics Abstraction

The metrics abstraction is unchanged from v1.4.0.

### 16.8 v1.5.0 — Companion App Endpoints

The 4 companion-app endpoints are **not** part of the metrics
abstraction. They are handled directly by `handleAPI` and by
`installCompanionApp` / `uninstallCompanionApp` /
`getCompanionState`.

**Why**: the companion install flow is a one-shot operation,
not a metric.

---

## 17. Documentation Corrections to This File

This section consolidates every documentation-accuracy
correction applied to this file. None of these advances the
Audit Corrections Registry in `docs/SECURITY.md` §17 — that
registry remains at **#33**.

The table below is the authoritative index. Individual
corrections are described inline where they appear.

### 17.1 Pre-release sweep (v1.5.0)

| ID | Section | Correction |
|:-:|---|---|
| ARCH-DOC-02 | Legend | `APK-8` added to the Legend |
| ARCH-CROSS-01 | §4.14.1 | The `§4.12.4` reference in `manifest.json`'s `x-note-audit-v150-docs` was corrected to `§4.14.1` |
| ARCH-LAYOUT-01 | §2.2, §4.14.1, §5.8, §8.1 | `install_app.sh` staged at module root (not under `proxy/`) |
| ARCH-MANIFEST-01 | §2.2, §6.1, §11.62, §17.3 | `docs/MANIFEST_NOTES.md` added as the authoritative reference for extracted `x-note-*` fields |

### 17.2 Post-release sweep (v1.5.0+)

| ID | Section | Correction |
|:-:|---|---|
| ARCH-DOC-04 | Header + §8.2 + §8.3 | Repository file counts corrected: **90 → 97 tracked**, **2 → 11 artifacts**, **92 → 108 total**, **~12 → 18 dirs**. The **+7** tracked files added in v1.5.0 are enumerated in §8.2 |
| ARCH-DOC-05 | Header + §5.8 + §8.1 | `install_app.sh` line count corrected to the canonical value **1,101**. Two earlier correction chains (`ARCH-DOC-01`, `ARCH-DOC-03`) both edited `1,101 → 1,101` (no-op); the intermediate values were dropped. The current consolidated note is definitive |
| ARCH-DOC-06 | §8.2 + §8.3 | `proxy/` tracked-file count confirmed at **18**; `docs/` (files only) updated to **19**; the arithmetic in §8.2's sub-list now sums to **97** |
| ARCH-DOC-07 | §6.1 | `manifest.json` size updated from `~6 KB` to `~3 KB` following the v1.5.0 `x-note-*` extraction |
| ARCH-DATE-02 | Header + footer | Date bumped to **2026-10-15** |
| ARCH-CODE-05..08 | §2.1, §2.2, §5.8.4, §5.8.5 | Four code-review corrections to inline notes and snippets |

### 17.3 Layered Bootstrap & Manifest Notes documentation

The following v1.5.0 additions were **missing entirely** from
the pre-edit revision of this file. The current revision adds
them to:

**Layered Bootstrap (`proxy/boot-mini.sh`)**:

- §1.2 (Architectural Principles)
- §2.1 (Overall Diagram)
- §2.2 (Components table)
- §5.0 (new — Layered Bootstrap overview)
- §5.1 (Roles table)
- §5.2 (Boot Sequence)
- §8.1 (Runtime Layout)
- §8.2 (Repository Layout — `proxy/boot-mini.sh`,
  `docs/adr/0008-layered-bootstrap.md`)
- §11.45 (Trade-off: two files vs seven copies)
- §17.3 (this subsection)

**Manifest Notes (`docs/MANIFEST_NOTES.md`)**:

- §2.2 (Components table)
- §6.1 (Structure — manifest size note)
- §11.62 (Trade-off: inline vs sidecar extraction)
- §17.1 (ARCH-MANIFEST-01 identifier)
- §17.3 (this subsection)

### 17.4 Identifier cross-references

The following corrections are documented in sibling files. They
affect facts referenced from this document but are not
themselves corrections to `docs/ARCHITECTURE.md`.

| Identifier | File | Description |
|---|---|---|
| CHG-DOC-01 | `CHANGELOG.md` | `watchdog.sh` line count corrected 1,356 → 1,326 |
| HARD-SEC-XREF-01 | `docs/SECURITY.md` | Cross-reference block for the v1.5.0++ cycle |
| API-XREF-01 | `docs/API.md` | Cross-reference block for the v1.5.0++ cycle |
| README-DOC-02 | `README.md` | Per-directory count correction (96 → 97 tracked) |
| MAIN-XREF-01 | `proxy/main.go` | Documentation-only cross-reference block |
| SW-DOC-02 | `web/sw.js` | Endpoint re-attribution (4 endpoints = v1.5.0, not v1.4.0) |
| MAN-NOTES-01 | `docs/MANIFEST_NOTES.md` | Canonical reference for extracted `x-note-*` fields |

### 17.5 Deprecated identifiers

The following identifiers appeared in earlier revisions of
this file and are **no longer referenced**:

- **ARCH-DOC-01** — superseded by ARCH-DOC-05.
- **ARCH-DOC-03** — superseded by ARCH-DOC-05.
- **ARCH-DATE-01** — superseded by ARCH-DATE-02.
- **ARCH-LEGEND-01**, **ARCH-REF-01** — the Legend and
  References sections were restructured, and the identifiers
  were removed.
- **MAN-TRIM-CHANGELOG** — appeared in an earlier §6.1 note but
  was never defined anywhere. Removed.

---

## Legend — Post-Release Fixes

The full fix history is documented across the sections above.
This legend summarizes the v1.5.0 additions and the v1.5.0+
post-release patches.

### v1.5.0 Fix IDs

| ID | Description | Section |
|:-:|---|---|
| IDX-23 | Companion button state survives language toggles | §6.9 |
| IDX-23b | Status card updates instantly on language toggle | §6.10 |
| IDX-24 | Install-method modal — three actions across two categories | §3.11, §6.4 |
| IDX-25 | Dashboard section-nav dead links fixed | §6.11 |
| IDX-25a | Centered card-expand hint toast | §6.12 |
| APK-3 | `COMPANION_PKG` constant (retained-for-documentation) | §4.14.1 |
| APK-4 | `INSTALL_SCRIPT_REL` + `getInstallScript()` | §4.14.1 |
| APK-5 | `POST /api/install_companion_app` handler | §4.14.2 |
| APK-6 | `GET /api?action=companion_app_state` handler + 30 s cache | §4.14.3 |
| APK-7 | `POST /api/uninstall_companion_app` handler | §4.14.4 |
| APK-8 | `.sha256` sidecar bundling in `release.yml` | §14.13 |
| APK-11 | Install timeouts + token TTL + rate limits | §4.14.5, §5.8.6 |
| APK-12 | Package name candidates + polling detection | §4.14.1, §5.8.7 |
| CIA-1 | Pre-flight checks in `install_app.sh` | §5.8.2 |
| CIA-2..5 | 5-level `pm install` cascade | §5.8.5 |
| CIA-6 | Error translation (AR + EN) | §5.8.8 |
| CIA-7 | Post-install verification (version_name extraction; comparison is done by the WebUI) | §5.8.10 |
| CIA-8 | Single-line JSON output | §5.8.9 |
| CIA-9 | Three modes (`--status` / `--uninstall` / install) | §5.8.1 |
| CIA-10 | SC2155 fix | §5.8.10 |
| CIA-11 | SC2329 fix | §5.8.10 |
| CIA-12 | MODDIR 5-strategy resolver | §5.8.10 |
| CIA-13 | JSON number detection | §5.8.10 |
| CIA-14 | `log_msg` silent no-op guard (2 changes) | §5.8.10 |
| CIA-15 | `_json_escape` C0 control conversion | §5.8.10 |
| CIA-16 | `_refresh_companion_pkg` from 2 call sites | §5.8.10 |

### v1.5.0 Code-review cycle

| ID | File | Description |
|:-:|---|---|
| V15-CODE-01 | `proxy/main.go` | `getCompanionState()` Phase-3 comment corrected |
| V15-CODE-02 | `proxy/main.go` | GC banner restructured (`(shared constant)`) |
| V15-CODE-03 | `proxy/main.go` | `callInstallScript()` uses `getSystemShell()` |
| V15-CODE-04 | `proxy/main.go` | `handleAPI()` panic logging added |
| V15-CODE-05 | `proxy/install_app.sh` | 75-second cascade deadline (`CASCADE_DEADLINE_SECONDS`) |
| V15-CODE-06 | `proxy/install_app.sh` | Cross-ref `§4.12.4` → `§4.14.1` |
| V15-CODE-07 | `proxy/install_app.sh` | Trap restores `$_VERIFIER_ORIG` (not hardcoded `1`) |
| V15-CODE-09 | `docs/API.md` | §4.1 "three" → "four" response shapes |
| V15-CODE-10 | `docs/API.md` | §1.1 + §6.2.14 `INSTALL_TIMEOUT` source corrected |
| V15-CODE-11 | `web/manifest.json` | `§4.12.4` → `§4.14.1` in `x-note-docs` |
| V15-CODE-15 | `proxy/main.go` | `R3-01` doc-comment refreshed (7 → 8 shell scripts) |
| V15-CODE-16 | `web/manifest.json` | `x-note-companion-apk` item (10) corrected |
| CSH-22 | `proxy/customize.sh` | `install_app.sh` extraction fix |

### v1.5.0+ Post-release patch cycle

| ID | File | Description |
|:-:|---|---|
| MAIN-REENT-01 | `proxy/main.go` | Logger reentrancy eliminated (3-layer split) |
| MAIN-PORTCACHE-01 | `proxy/main.go` | 30 s TTL cache for `getWebUIPort` / `getDashboardPort` |
| MAIN-DEADLOCALHOST-01 | `proxy/main.go` | `isLocalRequest` dead branch removed |
| MAIN-APPENDHASH-01 | `proxy/main.go` | `appendDenylist` hash source aligned |
| MAIN-CACHE-01 | `proxy/main.go` | Companion state cache invalidated unconditionally |
| DASH-REFRESH-01 | `web/dashboard.html` | `isRefreshing` reset on 401 |
| DASH-SESSION-RETRY-01 | `web/dashboard.html` | Session-expired primary action is a full retry |
| DASH-HINT-01 | `web/dashboard.html` | Dual-timer hint lifecycle |
| DASH-HINT-02 | `web/dashboard.html` | `scrollend` listener with fallback |
| IDX-429 | `web/index.html` | Install rate-limit message distinct |
| IDX-401-DISTINCT | `web/index.html` | Install-family 401 suppresses session modal |
| ICON-512-SAFEZONE-01 | `web/icon-512.svg` | Shield path fits W3C maskable safe circle |
| CIA-DEF-03 | `proxy/install_app.sh` | Three-way trap split + exit codes 130/143 |
| MAN-NOTES-01 | `docs/MANIFEST_NOTES.md` | New file consolidating extracted `x-note-*` fields |

### Documentation Correction IDs (this file)

| ID | Description |
|:-:|---|
| ARCH-CROSS-01 | §4.12.4 → §4.14.1 cross-reference |
| ARCH-DATE-02 | Header date bumped to 2026-10-15 |
| ARCH-DOC-02 | `APK-8` added to Legend |
| ARCH-DOC-04 | Repository file counts corrected to 97/11/108/18 |
| ARCH-DOC-05 | `install_app.sh` line count consolidated to 1,101 |
| ARCH-DOC-06 | `proxy/` tracked count confirmed at 18; `docs/` updated to 19 |
| ARCH-DOC-07 | `manifest.json` size updated to ~3 KB |
| ARCH-LAYOUT-01 | `install_app.sh` staged at module root |
| ARCH-MANIFEST-01 | `docs/MANIFEST_NOTES.md` added as authoritative reference |

---

## References

- [CHANGELOG.md](../CHANGELOG.md) — version history
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections Registry + §5.36 (companion install security) + §18 (documentation corrections)
- [docs/API.md](API.md) — HTTP API Reference
- [docs/BACKUP.md](BACKUP.md) — Backup System Reference
- [docs/EMERGENCY.md](EMERGENCY.md) — Emergency Recovery
- [docs/UPGRADE.md](UPGRADE.md) — Version Upgrade Guide
- [docs/MANIFEST_NOTES.md](MANIFEST_NOTES.md) — Manifest technical notes (v1.5.0)
- [docs/DNS_BINARIES.md](DNS_BINARIES.md) — DNS binaries management
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/ROADMAP.md](ROADMAP.md) — Roadmap
- [docs/adr/0007-external-dependency-securejoin.md](adr/0007-external-dependency-securejoin.md) — External dependency policy (v1.4.1)
- [docs/adr/0008-layered-bootstrap.md](adr/0008-layered-bootstrap.md) — Layered Bootstrap Pattern (v1.5.0 Phase 0)
- [Effective Go](https://go.dev/doc/effective_go)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [POSIX — Signals and trap](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_28)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Netfilter Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [DNSCrypt Protocol Specification](https://dnscrypt.info/protocol)
- [Magisk — Module Structure](https://topjohnwu.github.io/Magisk/guides.html)
- [Android PackageManager documentation](https://developer.android.com/reference/android/content/pm/PackageManager)
- [Companion Android App](https://github.com/gasciljh/dnscrypt-proxy-app)

---

**Last updated**: 2026-10-15
**Version**: v1.5.0
**Author**: gasciljh
