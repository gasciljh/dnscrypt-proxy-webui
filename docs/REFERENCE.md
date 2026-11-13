# Technical Reference — DNSCrypt Smart Filter

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Audience**: Developers and integrators.
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Scope**: This is the **single consolidated technical reference**
> for DNSCrypt Smart Filter. It merges seven source files — the
> former `ARCHITECTURE.md`, `API.md`, `BACKUP.md`,
> `COMPATIBILITY.md`, `DNS_BINARIES.md`, `MANIFEST_NOTES.md`, and
> `GLOSSARY.md` — into one document.
>
> **No fixed ceiling** (see `docs/MAP.md` §1). The reference must
> be complete to be useful; trimming it would mean some behavior,
> endpoint, or compatibility constraint is undocumented.
>
> **Audience split**:
> - End users → [`docs/GUIDE.md`](GUIDE.md)
> - Contributors → [`docs/CONTRIBUTING.md`](CONTRIBUTING.md)
> - Security researchers → [`SECURITY.md`](../SECURITY.md)
> - Developers / integrators → **this file**

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [HTTP API](#2-http-api)
3. [Data Flow & Internals](#3-data-flow--internals)
4. [Backup System](#4-backup-system)
5. [Compatibility Matrix](#5-compatibility-matrix)
6. [DNS Binaries Pipeline](#6-dns-binaries-pipeline)
7. [Manifest `x-note-*` Fields](#7-manifest-x-note--fields)
8. [Glossary](#8-glossary)
9. [File Layout](#9-file-layout)

---

## 1. Architecture

### 1.1 Purpose

DNSCrypt Smart Filter turns an Android device into a **filtered, encrypted DNS server** without a VPN, via:

- Transparent redirection of DNS queries (port 53) → `127.0.0.1:5354`
- Full encryption (DNSCrypt / DoH)
- Ad / tracker blocking via updatable lists
- Web interface for control (bilingual: English default + Arabic toggle)
- Persistent user-data preservation across upgrades, renames, reinstalls, and uninstalls
- Optional companion Android app served at `/app-debug.apk`
- One-tap root install for the companion app via `install_app.sh`
- **Local Timezone rendering** — The WebUI displays the last update time using the device's local timezone (via Unix timestamp) instead of raw UTC.
- **Fully Modularized Shell Architecture** — Shell scripts are organized into a dedicated `lib/` directory with a layered bootstrap mechanism.

### 1.2 Architectural Principles

| Principle | Implementation |
|---|---|
| **Separation of Concerns** | Go for HTTP, Shell for OS, JS for UI |
| **Zero-Footprint** | Streaming I/O, bounded buffers, 1 MB log rotation |
| **Atomic Operations** | All writes via `.tmp` + `rename` |
| **Graceful Degradation** | Fallbacks everywhere |
| **Localhost-Only** | All servers on `127.0.0.1` (by default) |
| **Idempotent** | Running scripts twice changes nothing |
| **Bounded Concurrency** | SSE writes bounded by a 30-second deadline |
| **Single Source of Truth** | `VERSION` + `module.prop` + `proxy/dnscrypt-proxy.version` + `proxy/app-apk.version` |
| **Clean State** | `STATUS_FILE` = user intent |
| **Custom Chains** | iptables/ip6tables in dedicated chains |
| **Platform-Agnostic Shell** | `getSystemShell()` works on Linux/macOS/Android |
| **Exact Endpoint Matching** | `hasEndpoint()` instead of `strings.Contains` |
| **Structured Metrics** | Prometheus → JSON in `metricsProxyHandler` |
| **Rate-Limited Auth** | Basic Auth protected by rate limiting |
| **Serialized Blocklist Rebuilds** | `rebuildMu` prevents race condition |
| **Dynamic Ports** | `runtime_info` returns actual ports |
| **Dynamic Memory Limit** | Per-profile soft limit via `memoryLimitForProfile()` |
| **Multi-Source Discovery** | Search for user data everywhere |
| **Persistent Backup** | `/sdcard/dnscrypt-webui-backup/` survives uninstall |
| **Modular Shell (lib/)** | Layer 0 (`lib/*.sh`) + Layer 1 (`boot-mini.sh`) + Layer 2 (`functions.sh`) |
| **Install-Method Modal** | WebUI confirm modal offers 3 actions across 2 categories |
| **Root Install Cascade** | `install_app.sh` tries 5 `pm install` strategies |
| **SELinux Staging** | APK staged to `/data/local/tmp/` — never `setenforce 0` |
| **One-Shot CSRF Token** | 60-second TTL token for `install_companion_app` |
| **Per-IP Install Rate Limit** | 5 failed attempts / 15 min lockout |
| **Localized Timestamps** | Backend emits Unix epoch; Frontend uses `toLocaleString()` |

### 1.3 Dependencies

| Component | Version | Purpose |
|---|---|---|
| **Go** | 1.22 | Backend |
| **DNSCrypt-proxy** | 2.1.20 | DNS engine |
| **Magisk / KernelSU** | 20.4+ / 0.9+ | Module framework |
| **HaGeZi blocklists** | latest | Blocklists |
| **iptables / nftables** | — | DNS redirection |
| **Companion Android app** | 1.0.0 | Optional native WebView wrapper (`proxy/app-apk.version`) |
| **Android PackageManager** | API 21+ | `pm install` cascade for companion app |
| **`filepath-securejoin`** | v0.7.0 | Path-injection hardening in `removeModule` (ADR-0002) |

DNSCrypt-proxy version is determined by `proxy/dnscrypt-proxy.version` — see §6.

Companion app version is determined by `proxy/app-apk.version` — see `scripts/fetch_app_apk.sh`.

The `filepath-securejoin` dependency is the project's **only** external Go dependency. Any future external dependency requires its own ADR — see `docs/adr/0002-external-dependency.md`.

### 1.4 Layered Bootstrap (ADR-0003)

The shell code is split into three layers with an explicit dependency direction:

```text
┌───────────────────────────────────────────────────────────────┐
│  Layer 0 — lib/*.sh (6 modules)                               │
│    constants.sh, fallbacks.sh, process.sh, http.sh,           │
│    backup.sh, firewall.sh.                                    │
│    Zero dependencies. Sourced by Layer 1.                     │
└──────────────────────────────┬────────────────────────────────┘
                               │ . (source)
                               ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 1 — boot-mini.sh                                       │
│    Aggregator, PATH setup, 50MB emergency log rotation,       │
│    sources Layer 0 modules in order.                          │
└──────────────────────────────┬────────────────────────────────┘
                               │ . (source)
                               ▼
┌───────────────────────────────────────────────────────────────┐
│  Layer 2 — functions.sh                                       │
│    Advanced helpers (runtime paths, cleanup, webui launch).   │
│    Sources boot-mini.sh at load time.                         │
└──────────────────────────────┬────────────────────────────────┘
                               │ . (source)
                               ▼
┌───────────────────────────────────────────────────────────────┐
│  Callers — service.sh / action.sh / status.sh / watchdog.sh   │
│    / uninstall.sh / post-fs-data.sh / customize.sh            │
│  Consumers of Layer 2 (which transitively provides 0 + 1).    │
└───────────────────────────────────────────────────────────────┘
```

**No caller changes.** The split is transparent to every script that sources `functions.sh`.

**The single legitimate fallback**: `boot-mini.sh §[4]` sets `_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because `lib/constants.sh` may fail to source during a partial extraction. `customize.sh` inherits this value by sourcing `boot-mini.sh`. `ci.yml` Step 10 recognizes this fallback explicitly. Any other shell script with a hardcoded `_MONITORING_UI_PORT=8080` fails the build.

**Why three layers**: before the split, the 5 primitives were duplicated across 7+ shell scripts, and advanced functions were bundled with bootstrapping. The `lib/` extraction separates "constants" from "primitives" from "orchestration" — matching the Unix philosophy of small, single-purpose modules.

**CI guard**: `ci.yml`'s `backup-smoke-test` job verifies that `functions.sh` sources `boot-mini.sh` and does NOT redefine any of the Layer-0 primitives. `make check-boot-mini` runs the same checks locally.

**Reference**: `docs/adr/0003-layered-bootstrap.md`.

### 1.5 Overall Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                     Android Device (Rooted)                         │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Magisk / KernelSU Module                         │  │
│  │                                                               │  │
│  │  ┌──────────────────┐    ┌──────────────────────────────┐     │  │
│  │  │  WebUI           │    │  DNSCrypt-proxy              │     │  │
│  │  │  (Go binary)     │◄───┤  (Go binary - upstream)      │     │  │
│  │  │  :9090           │    │  :5354                       │     │  │
│  │  │  :9091 Dashboard │    │  :8080 monitoring_ui         │     │  │
│  │  │  + MEM-1         │    │  (Prometheus metrics)        │     │  │
│  │  │  + BAK-1         │    │                              │     │  │
│  │  │  + EN/AR toggle  │    │                              │     │  │
│  │  │  + /app-debug.apk│    │                              │     │  │
│  │  │  + companion     │    │                              │     │  │
│  │  │    install       │    │                              │     │  │
│  │  │    (4 endpoints) │    │                              │     │  │
│  │  └────────┬─────────┘    └──────────────┬───────────────┘     │  │
│  │           │                              │                     │  │
│  │           │ HTTP/SSE                     │ DNS                 │  │
│  │           │                              │                     │  │
│  │  ┌────────▼──────────────────────────────▼───────────────┐     │  │
│  │  │           Shell Scripts (BusyBox sh)                  │     │  │
│  │  │  lib/*.sh (Layer 0 — 6 modules)                       │     │  │
│  │  │  boot-mini.sh (Layer 1 — aggregator)                  │     │  │
│  │  │  functions.sh (Layer 2 — sources Layer 1)             │     │  │
│  │  │  Consumers: customize / service / action / status /   │     │  │
│  │  │             watchdog / uninstall / post-fs-data       │     │  │
│  │  │  manage_firewall → Custom Chains                      │     │  │
│  │  │  getSystemShell() fallback                            │     │  │
│  │  │  auto_backup_if_needed() / rotate_backups()           │     │  │
│  │  │  copy_with_context() / backup_user_files()            │     │  │
│  │  │  install_app.sh (5-level cascade; 75 s deadline;      │     │  │
│  │  │                 EXIT/INT/TERM traps exit 130/143)     │     │  │
│  │  └────────┬──────────────────────────────┬───────────────┘     │  │
│  │           │                              │                     │  │
│  │  ┌────────▼──────────┐    ┌──────────────▼───────────────┐     │  │
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
│  │       Persistent Backup Store                                  │  │
│  │  /sdcard/dnscrypt-webui-backup/                                │  │
│  │    ├── current/                (live snapshot)                 │  │
│  │    ├── <timestamp>-<version>-<pid>/                            │  │
│  │    ├── <timestamp>-manual-<pid>/                               │  │
│  │    ├── <timestamp>-auto-<pid>/                                 │  │
│  │    ├── txn-*  /  orphan-txn-*  (transactions)                  │  │
│  │    ├── apk/                    (companion APK mirror)          │  │
│  │    │   ├── app-debug.apk                                       │  │
│  │    │   └── app-debug.apk.sha256                                │  │
│  │    ├── .last_stable            (pointer)                       │  │
│  │    ├── .last_auto_backup                                       │  │
│  │    ├── .upgrade_history.json                                   │  │
│  │    └── README.md                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.6 Components

| Component | Language | Responsibilities |
|---|---|---|
| **main.go** | Go | HTTP API, SSE, auth, blocklist management, Prometheus → JSON, dynamic memory limit, auto-backup triggers, rotation after pre-critical backup, transaction cleanup, `backups` runtime_info field, watchdog token generation, manifest-based snapshot detection + mtime sort, `/app-debug.apk` route, CodeQL path-injection hardening in `removeModule`, 4 companion-app endpoints + 10 helpers, three-layer logger split, port cache, **Unix timestamps for local time rendering** |
| **install_app.sh** | Shell (BusyBox) | 5-level `pm install` cascade, SELinux staging to `/data/local/tmp/`, Play Protect temporary disable (75 s cascade deadline), SHA256 verification, AR + EN error translation, `--status` / `--uninstall` / `--help` / `--version` modes. Staged at the module root by `customize.sh §[12]`. Three-way signal-trap split with exit codes 130 / 143 |
| **lib/*.sh** | Shell (BusyBox) | Layer 0: 6 modular libraries (`constants`, `fallbacks`, `process`, `http`, `backup`, `firewall`). Zero dependencies. |
| **boot-mini.sh** | Shell (BusyBox) | Layer 1: Aggregator, sources `lib/*.sh`, sets up PATH and log rotation. |
| **functions.sh** | Shell (BusyBox) | Layer 2: Advanced runtime functions, sources `boot-mini.sh`. |
| **dnscrypt-proxy** | Go (upstream) | The actual DNS engine |
| **Companion Android app** | Kotlin (separate repo) | Native WebView wrapper (`web/app-debug.apk`, optional) |
| **Shell scripts** | sh | Install, launch, watchdog, firewall, memory hint, backup/restore, rotation rewrite, recovery mode, SELinux context preservation, watchdog token reader, APK mirror |
| **META-INF bootstrap** | sh | Magisk/KernelSU entry point |
| **index.html** | HTML+JS | Main interface (bilingual: EN default + AR toggle). Install-method modal. Companion button state + status card fixes. **Displays local timezone via `toLocaleString()`**. |
| **dashboard.html** | HTML+JS | Monitoring dashboard (bilingual). Section-nav + centered hint fixes. |
| **sw.js** | JS | Service Worker (PWA), language-neutral, `CACHE_VERSION=v1.6.0`, 11-file precache |
| **manifest.json** | JSON | PWA manifest (`version=1.6.0`, 2 `x-note-*` fields) |

### 1.7 State Management

#### 1.7.1 Server-side State

| State | Storage | Persistence | Writer |
|---|---|---|---|
| `currentRules` | memory | rebuild from files | `atomicSaveRulesInternal` |
| `sessions` | memory | lost on restart | `createSession` / `destroySession` |
| `loginAttempts` | memory | lost on restart | `recordLoginAttempt` |
| `serverBindAddr` | memory | reassigned in main() | `main()` |
| `STATUS_FILE` | `run/dnscrypt.status` | yes | `startService` / `stopService` only |
| `PID_FILE` | `run/dnscrypt.pid` | yes | `startService` / `os.Remove` |
| `selected_profile` | `selected_profile.txt` | yes | `updateProfile` |
| DNS version | `proxy/dnscrypt-proxy.version` | yes | manual |
| Companion app version | `proxy/app-apk.version` | yes | manual |
| `portCacheMap` | memory | lost on restart | `isPortOpenCached` |
| `systemShell` | memory (sync.Once) | lost on restart | `getSystemShell` |
| `authCache` | memory | lost on restart | `getMonitoringAuth` |
| `rebuildMu` | memory | lost on restart | `rebuildBlocklist` |
| `currentMemLimit` | memory | recomputed at startup | `applyMemoryLimit` |
| `backupMu` | memory | lost on restart | `createAutoBackup` |
| `watchdogTok` | memory | lost on restart (regenerated) | `getWatchdogToken` |
| `$PERSISTENT_BACKUP` | `/sdcard/...` | yes | `customize.sh`, `service.sh`, `main.go` |
| `.last_stable` | file | yes | `customize.sh` |
| `.upgrade_history.json` | file | yes | `customize.sh` |
| `.watchdog_token` | file | yes | `customize.sh` or `main.go` |
| `installTokens` | memory | lost on restart | `generateInstallToken()` |
| `installAttempts` | memory | lost on restart | `recordInstallAttempt()` |
| `companionStateCache` | memory | lost on restart | `getCompanionState()` |
| `cachedWebPort` / `cachedDashPort` | memory | lost on restart | `readConfPortCached()` |

**Note on ephemeral state**: the three companion-install states are deliberately ephemeral:
- **`installTokens`** — a token lives at most 60 s.
- **`installAttempts`** — a per-IP rate limiter.
- **`companionStateCache`** — a pure performance cache.

#### 1.7.2 Client-side State

| State | Storage | Lifetime |
|---|---|---|
| Drafts (Allowlist/Denylist) | localStorage | 1 hour |
| Session token | memory only (cookie-based) | tab lifetime |
| Server hashes | memory | page lifetime |
| `currentStatus` | memory | page lifetime |
| `PORTS` | memory | page lifetime (from runtime_info) |
| Language preference | `localStorage['dnscrypt-lang']` | persistent |
| `companionState` | memory + `sessionStorage['companion-state']` | page lifetime + F5 |
| `cardHintTimer` / `cardHintRemoveTimer` | memory | page lifetime |
| `sessionExpired` / `isRefreshing` | memory | page lifetime |

#### 1.7.3 Conflict Detection

```text
Client                          Server
  │                               │
  ├── save(content, hash_A) ──────► │
  │                               ├── if hash_A ≠ current_hash:
  │                               │      return 409 conflict
  │◄────── 200 {hash: B} ──────────┤
  │                               │
  ├── next save: hash_B           │
```

`appendDenylist()` passes `getRulesState().DenylistHash` to `saveDenylist()`. Both now use the same hash source, so an external modification of `denylist.txt` no longer produces a spurious `conflict` response.

#### 1.7.4 Status State Machine — STATUS_FILE

```text
User Intent (STATUS_FILE)      Actual State (probe)
───────────────────────       ──────────────────────

START                                  ┌──── ON ────┐
  │                                    │            │
  ├──► startService() ──► [ON] ────────►│            │
  │                              ▲     │            │
  │                        Watchdog    │            │
  │                        restarts    │            │
  │                        on crash    │            │
  │                              │     │            │
  │                        [ON]─┴─────┘            │
  │                              [crash]            │
  │                                [OFF]────────────┘
  │
  └──► stopService() ──► [OFF]

User stops ──────────────────────► [OFF]
```

`STATUS_FILE` is written only by `startService` / `stopService` (and by the disable path in `service.sh`); it is read-only from the perspective of `getStatus()`.

### 1.8 File Layout

#### 1.8.1 Runtime Layout

```text
/data/adb/modules/dnscrypt-proxy-webui/
├── module.prop                    # Magisk definition
├── service.sh                     # boot service
├── post-fs-data.sh                # early cleanup
├── action.sh                      # Magisk Action (+ --backup/--diagnose)
├── status.sh                      # status (+ --diagnose/--json)
├── uninstall.sh                   # cleanup + orphan txn preservation
├── functions.sh                   # Layer 2 shell orchestrator
├── boot-mini.sh                   # Layer 1 aggregator
├── watchdog.sh                    # standalone process (token auth)
├── customize.sh                   # installer (10 layers + APK mirror)
├── install_app.sh                 # 5-level cascade
├── .module.fingerprint            # module fingerprint
├── disable                        # disable flag (optional)
├── recovery                       # recovery trigger (optional)
│
├── lib/                           # Layer 0 (6 modular libraries)
│   ├── constants.sh               # Single source of truth (paths, ports)
│   ├── fallbacks.sh               # Standalone primitives
│   ├── process.sh                 # /proc-based process management
│   ├── http.sh                    # HTTP client (curl/wget cascade)
│   ├── backup.sh                  # User-data preservation & rotation
│   └── firewall.sh                # nftables/iptables management
│
├── web/                           # Frontend (bilingual: EN default + AR toggle)
│   ├── index.html
│   ├── dashboard.html
│   ├── manifest.json
│   ├── sw.js
│   ├── offline.html
│   ├── app-debug.apk              # companion APK (optional)
│   ├── app-debug.apk.sha256       # APK SHA256 (optional)
│   ├── icon-192.svg / icon-512.svg
│   ├── icon-192.png / icon-512.png
│   ├── apple-touch-icon.png
│   ├── favicon-32x32.png / favicon-16x16.png / favicon.ico
│
└── proxy/                         # Backend
    ├── dnscrypt-webui             # binary (Go)
    ├── dnscrypt-proxy             # binary (upstream)
    ├── dnscrypt-proxy.version     # DNS engine version (2.1.20)
    ├── app-apk.version            # companion app version (1.0.0)
    ├── dnscrypt-proxy.toml        # config
    ├── webui.conf                 # config
    ├── blocklist.txt              # output
    ├── blocklist.raw              # source
    ├── allowlist.txt / denylist.txt
    ├── selected_profile.txt
    ├── blocked-ips.txt
    └── run/                       # runtime (0700)
        ├── dnscrypt.pid / webui.pid / watchdog.pid
        ├── dnscrypt.status        # ← user intent
        ├── update_progress.txt
        ├── .bootstrap_cache
        └── .watchdog_token

/sdcard/dnscrypt-webui-backup/     # persistent backup
├── current/                       # live snapshot (always up-to-date)
├── <timestamp>-<version>-<pid>/   # historical snapshot
├── <timestamp>-manual-<pid>/      # pre-critical backup
├── <timestamp>-auto-<pid>/        # periodic backup
├── txn-<timestamp>-<pid>/         # in-flight transaction (short-lived)
├── orphan-txn-<timestamp>-<pid>/  # preserved interrupted install
├── apk/                           # companion APK mirror
│   ├── app-debug.apk
│   └── app-debug.apk.sha256
├── .last_stable                   # pointer to last known-good snapshot
├── .last_auto_backup              # mtime marker for periodic backup
├── .upgrade_history.json          # full upgrade log (with jq)
├── .upgrade_history.txt           # fallback log (without jq)
├── .pending_notification          # transient; read+deleted by main.go
└── README.md                      # user-facing guide

/data/adb/dnscrypt-recovery        # external recovery trigger (optional)
```

**Note on shell scripts**: All 10 shell scripts (`install_app.sh`, `boot-mini.sh`, `customize.sh`, `service.sh`, etc.) are staged at the **module root** (next to `customize.sh`), not under `proxy/`. `main.go` resolves `install_app.sh` via `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`. All of them are extracted by `customize.sh §[12]` and verified by `customize.sh §[16]`'s critical-files check.

#### 1.8.2 Repository Layout (83 tracked files)

**Tracked files**: 83 — canonical.

**Build artifacts**: 0–11, depending on local build state. All are gitignored by `.gitignore` §[20].

**Directories**: 16–19, following the same build-state dependency.

```text
dnscrypt-proxy-webui/          # 83 tracked files + 0-11 build artifacts
│
├── Root files (15)
│   ├── VERSION                    # module version (v1.6.0)
│   ├── module.prop                # Magisk/KernelSU definition
│   ├── update.json                # auto-update metadata
│   ├── LICENSE                    # MIT
│   ├── README.md                  # project overview
│   ├── CHANGELOG.md               # version history
│   ├── CODE_OF_CONDUCT.md
│   ├── SECURITY.md                # security policy
│   ├── Makefile
│   ├── .editorconfig / .gitattributes / .gitignore
│   ├── .pre-commit-config.yaml
│   ├── .secrets.baseline
│   └── .shellcheckrc
│
├── Root shell scripts (10)
│   ├── customize.sh / install_app.sh / post-fs-data.sh
│   ├── service.sh / action.sh / status.sh / uninstall.sh
│   ├── functions.sh / boot-mini.sh / watchdog.sh
│
├── .github/ (12 tracked files + 4 subdirs)
│   ├── CODEOWNERS / dependabot.yml
│   ├── PULL_REQUEST_TEMPLATE.md / PULL_REQUEST_TEMPLATE/release.md
│   ├── ISSUE_TEMPLATE/{bug_report.yml, config.yml, feature_request.yml}
│   ├── codeql/codeql-config.yml
│   └── workflows/{ci.yml, codeql.yml, release.yml, upgrade-test.yml}
│
├── .devcontainer/ (2)
│   ├── devcontainer.json / setup.sh
│
├── META-INF/ (2)
│   └── com/google/android/{update-binary, updater-script}
│
├── scripts/ (6)
│   ├── fetch_dns_binaries.sh / fetch_app_apk.sh
│   ├── generate-icons.sh / package_module.sh
│   ├── release.sh / release-patch.sh
│
├── lib/ (6 tracked files)
│   ├── constants.sh / fallbacks.sh / process.sh
│   ├── http.sh / backup.sh / firewall.sh
│
├── proxy/ (8 tracked files)
│   ├── main.go / go.mod / go.sum / build.sh
│   ├── dnscrypt-proxy.toml / dnscrypt-proxy.version
│   ├── webui.conf / app-apk.version
│
├── web/ (13 tracked files + 2 build artifacts)
│   ├── index.html / dashboard.html / manifest.json / sw.js / offline.html
│   ├── icon-192.svg / icon-512.svg / icon-192.png / icon-512.png
│   ├── apple-touch-icon.png / favicon-32x32.png / favicon-16x16.png / favicon.ico
│   ├── [app-debug.apk]            # build artifact (gitignored)
│   └── [app-debug.apk.sha256]     # build artifact (gitignored)
│
├── dist/                          # ← entire directory is gitignored
│   ├── [dnscrypt-webui-<ver>-module.zip]
│   └── [dnscrypt-webui-<ver>-module.zip.sha256]
│
└── docs/ (9 user-facing files)
    ├── GUIDE.md / REFERENCE.md / CONTRIBUTING.md / ROADMAP.md / MAP.md
    ├── adr/ (4 files)
    │   ├── README.md
    │   ├── 0001-release-workflow.md
    │   ├── 0002-external-dependency.md
    │   └── 0003-layered-bootstrap.md
    └── (the following 19 files merged into the above)
        └── [API.md, ARCHITECTURE.md, BACKUP.md, BRANCHING.md,
             COMPATIBILITY.md, DEVELOPMENT.md, DNS_BINARIES.md,
             EMERGENCY.md, FAQ.md, GLOSSARY.md, HALL_OF_FAME.md,
             INSTALL.md, MANIFEST_NOTES.md, RELEASE_PROCESS.md,
             SECURITY.md, TROUBLESHOOTING.md, UPGRADE.md,
             adr/0001..0006, adr/0007, adr/0008, adr/0009]
```

#### 1.8.3 File Count by Directory

**The three canonical states**:

| State | When | Tracked | Artifacts | Working tree | Dirs |
|---|---|:---:|:---:|:---:|:---:|
| **Fresh clone** | After `git clone <repo>` | 83 | 0 | 83 | 16 |
| **After package** | After `make fetch-apk && make package` | 83 | 4 | 87 | 18 |
| **After full build** | After `make build` | 83 | 11 | 94 | 19 |

**Cross-check — reproducible with three commands**:

```bash
git ls-files | wc -l
find . -type f -not -path './.git/*' | wc -l
find . -type d -not -path './.git/*' -not -name '.git' | wc -l
```

### 1.9 Performance

#### 1.9.1 Memory Profile

| Metric | Value |
|---|---|
| RAM (WebUI idle) | ~15 MB |
| RAM (WebUI peak) | ~35 MB |
| Battery | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (100K entries) | ~200 ms |
| `rebuildBlocklist` (500K entries) | ~1 s |
| Companion install (local root) | ~5–15 s (typical; bounded by 75 s deadline) |

**Companion install additions**: `installTokens` and `installAttempts` add negligible memory (< 1 KB per active install session). `companionStateCache` is a single small struct (< 200 bytes).

**Port cache addition**: adds two short strings and one `time.Time` — under 100 bytes.

#### 1.9.2 CPU Profile

| Operation | Duration |
|---|---|
| `generateInstallToken()` | ~10 µs |
| `validateAndConsumeInstallToken()` | < 5 µs |
| `isInstallLockedOut()` | < 5 µs |
| `getCompanionState()` (cache hit) | < 1 µs |
| `getCompanionState()` (cache miss) | ~50–150 ms |
| `callInstallScript()` | 5–15 s typical, 60+ s worst case |
| `getWebUIPort()` / `getDashboardPort()` (cache hit) | < 1 µs |
| `getWebUIPort()` / `getDashboardPort()` (cache miss) | ~10–50 µs |

#### 1.9.3 Disk I/O

The companion install flow adds:

| Operation | I/O |
|---|---|
| Copy APK to `/data/local/tmp/` | ~3 MB write (one-time per install) |
| SHA256 verify (if `.sha256` present) | ~3 MB read + hash (~5 ms) |

A single `/api?action=runtime_info` request previously triggered two `webui.conf` reads. After the port cache, at most one read per 30-second window.

#### 1.9.4 Backup Storage

| Metric | Value |
|---|---|
| Size per snapshot | ~30–100 KB (5 config files) |
| Total with rotation (21 snapshots) | **~2.5 MB max** |
| APK mirror (`apk/`) | **~3 MB (one-time)** |
| Backup duration | < 5 s wall |
| Restore duration | < 3 s |
| Rotation policy | Keep 21 newest by **mtime**, with `.last_stable` + newest-install protection |
| Pre-critical backup frequency | On every destructive write |
| Periodic backup interval | 24 h (service.sh) |

#### 1.9.5 Companion APK Storage

| Metric | Value |
|---|---|
| APK size (typical) | ~3 MB |
| Cache location (build machine) | `~/.cache/dnscrypt-proxy-webui/app/` |
| Module ZIP impact | +~3 MB (optional) |
| Persistent backup mirror (`apk/`) | +~3 MB (best-effort, one-time) |
| Runtime memory impact | 0 MB — served as a static file |
| Cache-Control | `public, max-age=3600, immutable` |
| Git tracking | Not tracked (`.gitignore` §[20]) |
| Total storage footprint (worst case) | ~6 MB (module + backup mirror) |

### 1.10 Blocklist Filtering Strategy

#### 1.10.1 Filter Model

```text
blocklist.raw         → downloaded source (public list)
       │
       ▼ (rebuild)
blocklist.txt         → final output (filtered)
       │
       ▼ (read by dnscrypt-proxy)
engine queries        → local check (fast) → upstream
```

#### 1.10.2 Rebuild Algorithm

```text
1. Read allowlist.txt → allowSet (normalized domains)
2. Read denylist.txt → denyLines
3. Stream blocklist.raw line-by-line:
     - normalize domain
     - if suffix match in allowSet → skip
     - else → write to output
4. Append denyLines between markers:
       # === CUSTOM_DENYLIST_START ===
       <deny lines>
       # === CUSTOM_DENYLIST_END ===
5. Atomic write to blocklist.txt
```

#### 1.10.3 Normalization Rules

| Rule | Example |
|---|---|
| Strip `||` prefix | `||ads.com^` → `ads.com` |
| Strip `^` suffix | `ads.com^` → `ads.com` |
| Strip `*.` prefix | `*.ads.com` → `ads.com` |
| Strip `.` prefix | `.ads.com` → `ads.com` |
| Lowercase | `ADS.COM` → `ads.com` |
| Skip comments | `# foo` → (skip) |

#### 1.10.4 Suffix Matching

The allowlist check is **suffix-aware**:

```text
blocked = "ads.example.com"
allowed = "example.com"

match:
  ads.example.com    ≠ example.com
  example.com        == example.com ✓

→ allow (bypass block)
```

Allowing `example.com` bypasses its entire subdomain tree.

### 1.11 Firewall Architecture — Custom Chains

#### 1.11.1 Why Custom Chains

The original release added dynamic RETURN rules directly to the public `OUTPUT` chain. When `bootstrap_resolvers` changed, old RETURN rules were left behind.

**Rule**: never pollute a public chain (OUTPUT/INPUT/FORWARD) with dynamic rules. Use a dedicated Custom Chain — deleting it wipes all its rules.

#### 1.11.2 Chain Structure

```text
OUTPUT (nat) — public chain, only jump rules
    -A OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
    -A OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT

DNSCRYPT_OUT (custom chain)
    RETURN for each bootstrap IP + loopback
    DNAT for the rest
```

Same structure for IPv6 in `DNSCRYPT_OUT6`.

#### 1.11.3 Bootstrap Resolver Handling

The engine queries `bootstrap_resolvers` directly on port 53. If they are not excluded from DNAT, a loop occurs:

```text
packet leaves → DNAT → 127.0.0.1:5354 → dnscrypt-proxy → loop
```

**Solution**: RETURN rules for every bootstrap resolver and for loopback. The list is read from the TOML at runtime (`get_dynamic_bootstrap`), not hardcoded.

#### 1.11.4 Cross-Protocol Separation

| Protocol | Firewall | Bootstrap handling |
|---|---|---|
| IPv4 | iptables | RETURN for IPv4 bootstrap |
| IPv6 | ip6tables | RETURN for IPv6 bootstrap |
| Any | nftables | `case` filter per rule |

Mixing IPv4 rules into IPv6 or vice versa would break the firewall silently.

#### 1.11.5 Blind Cleanup

`manage_firewall 0` invokes every backend's cleanup path unconditionally. This guarantees no orphan rules even if the device switched backends between two runs.

### 1.12 Trade-offs & Decisions (Summary)

This section summarizes the key trade-offs made across the project. Full decision records live in `docs/adr/`.

| Decision | Rationale | Alternative(s) rejected |
|---|---|---|
| **Layered Bootstrap** — Layer 0 (`lib/*.sh`) + Layer 1 (`boot-mini.sh`) + Layer 2 (`functions.sh`) | Single source of truth for 6 modular libraries; no caller changes | Keep duplication, merge into one file, per-script copies |
| **Modular lib/ directory** | Separates concerns: constants, primitives, orchestration; reduces duplication across 7+ scripts | Keep monolithic, single-file library |
| **Unix timestamp for UI times** | Timezone-agnostic; frontend renders local time | Send pre-formatted UTC string (rejected: shows wrong time for non-UTC users) |
| **`toLocaleString()` with locale** | Respects device timezone and language simultaneously | Hardcode timezone (rejected: breaks for travelers) |
| **One-tap root install** — 5-level `pm install` cascade | Fast, one-tap, no browser UX | `<a download>` link, WebView-install intent, `intent://` URL |
| **SELinux staging** — `/data/local/tmp/` — never `setenforce 0` | SELinux stays enforcing; simple, one command | `setenforce 0`, `chcon` on module dir, bind-mount |
| **Install-method modal** — 3 actions × 2 categories | Presents all three paths in one interaction | Direct install on click, no choice |
| **Three-way signal trap** — EXIT/INT/TERM with `_CLEANED_UP` | Cleanup runs exactly once; INT exits 130, TERM exits 143 | Single `EXIT INT TERM` handler (allows resume after SIGINT) |
| **75-second cascade deadline** | < `INSTALL_TIMEOUT` (90 s), so trap always fires | Unbounded, deadline > `INSTALL_TIMEOUT`, deadline = `INSTALL_TIMEOUT` |
| **Logger three-layer split** — `logWithLevel` / `logLocked` / `writeLocked` | Go mutexes are not reentrant; avoids deadlock on rotation failure | Channel-based async logger, deferred error reporting, remove recursive call |
| **Port cache** — 30 s TTL | Collapses two `webui.conf` reads per request | No cache, infinite cache, longer TTL |
| **HTTP_WRITE_TIMEOUT = 150 s** | > `INSTALL_TIMEOUT` (90 s) + serialization + drain | Keep 60 s, per-endpoint timeouts |
| **Install failure returns HTTP 200** | Well-formed request; body carries AR/EN message | 4xx for install failure |
| **install-family 401 suppression** | 401 from install endpoints means token expiry, not session expiry | Forward all 401s to session-expired path |

**Full decision records**:
- `docs/adr/0001-release-workflow.md`
- `docs/adr/0002-external-dependency.md`
- `docs/adr/0003-layered-bootstrap.md`

### 1.13 Platform & Metrics Abstraction

#### 1.13.1 Platform Abstraction

`getSystemShell()` tries:
1. `/system/bin/sh` (Android)
2. `/bin/sh` (Linux/macOS)
3. `/usr/bin/sh` (BSD)
4. Fallback: `"sh"` (PATH-resolved)

Result cached via `sync.Once`. Every optional tool (`nft`, `iptables`, `jq`, `md5sum`, `sha256sum`, `restorecon`, `chcon`, `base64`, `rsvg-convert`, `magick`, `convert`, `inkscape`, `icotool`, `timeout`, `busybox`) is probed via `command -v` before use.

`install_app.sh` uses the same platform detection as `functions.sh`. Its cascade levels are all Android-specific (`pm install`, `install-create`, `magisk su`, `cmd package`). The script is only meaningful on Android.

**Shell resolution in `main.go`**: `callInstallScript()` also resolves the shell through `getSystemShell()`, matching every other shell invocation in the file.

#### 1.13.2 Metrics Abstraction

```go
body, _ := io.ReadAll(resp.Body)
var upstream map[string]interface{}
if err := json.Unmarshal(body, &upstream); err == nil {
    json.NewEncoder(w).Encode(upstream)
    return
}
prom := parsePrometheus(string(body))
dashboardJSON := buildDashboardJSON(prom)
json.NewEncoder(w).Encode(dashboardJSON)
```

`parsePrometheus` strips label sets from metric names and sums duplicate series. `buildDashboardJSON` maps the aggregated values into the Dashboard's schema.

---

## 2. HTTP API

### 2.1 Overview

#### 2.1.1 Basics

| Item | Value |
|---|---|
| **Protocol** | HTTP/1.1 |
| **Binding** | `127.0.0.1` only (not reachable from the network by default) |
| **Encoding** | UTF-8 |
| **Content-Type** | `application/json` (default for responses) |
| **Auth** | Bearer / Cookie / Basic / Watchdog token / Install token |
| **Language** | The WebUI is bilingual (English default + Arabic toggle). The API itself is **language-neutral** — it returns JSON without localized strings, except for AR/EN message pairs on install errors (§2.4.6). |

**Timeout hierarchy** — two families with different orderings:

**Install family** (`install_companion_app`) — cascade strictly inside handler:

```text
cascade (75 s) < handler (90 s) < WriteTimeout (150 s)
                            and
client (120 s) < WriteTimeout (150 s)
```

The cascade deadline is deliberately shorter than the handler timeout, so the `EXIT / INT / TERM` trap inside `install_app.sh` always fires before `main.go`'s `exec.CommandContext` kills the script.

**Non-install family** (every other endpoint) — the client may exceed the server WriteTimeout only for `update_profile`:

| Endpoint | Client | Server WriteTimeout |
|---|---:|---:|
| `update_profile` | 310 s | 150 s |
| all others | 15 s | 150 s |

**Localhost gate**: `main.go` applies `isLocalRequest()` to **all three install surfaces** — `POST /api/install_companion_app`, `POST /api/uninstall_companion_app`, and `GET /api?action=install_token`. A non-loopback request to any of the three returns HTTP 403 with a JSON body.

**Service Worker bypass**: all four companion-install endpoints live under `/api/*`, which is handled by the Service Worker's bypass rule 2. The two GitHub URLs are external origins (bypass rule 1). The `/app-debug.apk` fallback path is bypass rule 9. No Service Worker change was required for v1.5.0 or v1.6.0.

#### 2.1.2 Port Constraints

| Port | Purpose | Note |
|:----:|---|---|
| **9090** | WebUI (default) | Configurable via `webui.conf` |
| **9091** | Dashboard (default) | Configurable via `webui.conf` |
| **8080** | `monitoring_ui` (internal) | **Reserved — do not use** |
| **5354** | DNS engine (internal) | Reserved — do not use |

`main.go` refuses to start if `PORT == DASHBOARD_PORT`, or if either equals `8080`. `readConfPort()` validates `[1, 65535]`; values outside the range fall back to the default.

`getWebUIPort()` / `getDashboardPort()` route through a 30-second TTL cache. Editing `webui.conf` may show the old port for up to 30 s. A `main.go` restart always re-reads the file.

#### 2.1.3 Endpoint Map

```text
┌──────────────────────────────────────────────────────────────────────┐
│  Public (no auth)                                                    │
│    GET  /healthz                 Liveness check                      │
│    GET  /readyz                  Readiness (localhost-only)          │
│    GET  /app-debug.apk           Companion APK (optional; 404 if absent) │
│    GET  /sw.js /manifest.json /icons…/offline.html  Static assets    │
│    GET  /                        index.html                          │
│                                                                      │
│  Auth required (GET)                                                 │
│    GET  /api?action=status             Service status                │
│    GET  /api?action=get_profile        Current profile               │
│    GET  /api?action=get_custom_rules   Rules content                 │
│    GET  /api?action=get_rules_state    Hash state                    │
│    GET  /api?action=stats              Blocked count                 │
│    GET  /api?action=resources          RAM usage                     │
│    GET  /api?action=logs               Recent logs                   │
│    GET  /api?action=list_logs          Log files list                │
│    GET  /api?action=read_log           Read log file                 │
│    GET  /api?action=get_progress       Progress                      │
│    GET  /api?action=check_old_modules  Old modules                   │
│    GET  /api/runtime_info              Build + ports + memory        │
│    GET  /api/runtime_info/             (trailing slash form)         │
│    GET  /api?action=runtime_info       (query-string form)           │
│    GET  /api?action=install_token      One-shot CSRF token (60 s)    │
│    GET  /api?action=companion_app_state Install state (30 s cache)   │
│    GET  /api/download_log              Download log file             │
│    GET  /api/metrics                   Metrics (Dashboard)           │
│    GET  /events                        SSE stream                    │
│                                                                      │
│  Auth required (POST)                                                │
│    POST /api/auth/login                Login (POST-only)             │
│    POST /api/auth/logout               Logout (POST-only)            │
│    POST /api/update_profile            Update blocklist              │
│    POST /api/save_allowlist            Save allowlist                │
│    POST /api/save_denylist             Save denylist                 │
│    POST /api/save_custom_rules         Save both                     │
│    POST /api/append_denylist           Append to denylist            │
│    POST /api/clear_log_file            Clear one log                 │
│    POST /api/clear_logs                Clear main log                │
│    POST /api/remove_module             Remove old module             │
│    POST /api/toggle_service            Toggle on/off                 │
│    POST /api/restart_service           Restart DNS                   │
│    POST /api/install_companion_app     Root install (CSRF token)     │
│    POST /api/uninstall_companion_app   Uninstall (not exposed in UI) │
│                                                                      │
│  Watchdog token OR user auth (POST)                                  │
│    POST /api/ensure_running_service    Ensure DNS running            │
│      • localhost + POST + valid X-Watchdog-Token → allowed           │
│      • otherwise → normal user auth (Bearer/Cookie/Basic)            │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Authentication

#### 2.2.1 Schemes

| Scheme | Header/Cookie | Priority | Rate Limited |
|---|---|:---:|:---:|
| Watchdog token | `X-Watchdog-Token: <64-hex>` | 0 (endpoint-scoped) | No |
| Bearer | `Authorization: Bearer <token>` | 1 | No |
| Cookie | `Cookie: dnscrypt_session=<token>` | 2 | No |
| Basic | `Authorization: Basic <base64>` | 3 | Yes |

**Watchdog token** is checked **before** user schemes but only for `POST /api/ensure_running_service` from a loopback address (§2.2.8).

**Install token** is **not** an alternative to the schemes above. It is an additional per-request credential required **in addition to** a valid session for `POST /api/install_companion_app` (§2.2.7).

#### 2.2.2 Credentials Source

From the `[monitoring_ui]` section of `dnscrypt-proxy.toml` only (section tracking, no linear scan). Cached for 60 seconds.

```toml
[monitoring_ui]
  enabled = true
  listen_address = '127.0.0.1:8080'
  username = 'admin_xxxxxxxx'
  password = 'xxxxxxxxxxxxxxxxxxxxxxxx'
```

**Missing section**: if `[monitoring_ui]` has no non-empty username/password, `checkAuth()` treats every request as authorized. This is intentional for the default localhost setup, but means a missing config is not fail-closed. If `BIND_ADDR` is anything other than `127.0.0.1` / `::1`, `main.go` refuses to start without credentials (see `SECURITY.md` §5.1).

#### 2.2.3 Login — POST-only

`/api/auth/login` accepts **POST only**. GET/HEAD/PUT/DELETE → **405 Method Not Allowed** with `Allow: POST`.

**Request (JSON):**

```http
POST /api/auth/login HTTP/1.1
Host: 127.0.0.1:9090
Content-Type: application/json

{
  "username": "admin_abc12345",
  "password": "SecurePassword12345678"
}
```

**Response (200):**

```http
HTTP/1.1 200 OK
Content-Type: application/json
Set-Cookie: dnscrypt_session=<token>; Path=/; Max-Age=86400; HttpOnly; Secure; SameSite=Lax

{
  "status": "ok",
  "message": "Login successful"
}
```

No `token` field in the response — authentication relies solely on the HttpOnly cookie. `Secure` is set only when `BIND_ADDR` is a loopback address.

**Response (405):**

```json
{
  "status": "error",
  "message": "Login requires POST (CSRF protection)"
}
```

**Response (401 / 429):**

```json
{"status": "error", "message": "Invalid credentials"}
{"status": "error", "message": "Too many attempts. Try again later."}
```

#### 2.2.4 Cookie Properties

| Property | Value |
|---|---|
| Name | `dnscrypt_session` |
| Path | `/` |
| MaxAge | 86400 (24 h) |
| HttpOnly | true |
| Secure | conditional on loopback bind |
| SameSite | Lax |

`Secure` is true for `127.0.0.1` / `::1` / `localhost`, false otherwise (LAN access). `SameSite=Lax` (not `Strict`) is chosen so PWA shortcuts work; CSRF protection comes from POST-only state-changing endpoints.

#### 2.2.5 Logout — POST-only

`/api/auth/logout` accepts **POST only**. On success, the cookie is cleared (`Max-Age=0`).

```http
POST /api/auth/logout HTTP/1.1
Cookie: dnscrypt_session=<token>

HTTP/1.1 200 OK
Set-Cookie: dnscrypt_session=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax

{"status": "ok"}
```

#### 2.2.6 Authentication Flow

```text
User → POST /api/auth/login {username, password}
    ↓
main.go — handleAPI
    if hasEndpoint(path, "auth/login") {
        if r.Method != POST → 405 + Allow: POST
        handleLogin(w, r)
    }
    ↓
handleLogin()
    1. ip := getClientIP(r)   ← IPv6-safe
    2. if isLockedOut(ip) → 429
    3. read credentials (JSON body)
    4. subtle.ConstantTimeCompare
    5. if fail → recordLoginAttempt(ip, false)
    6. if success → createSession + Set-Cookie
    7. response: {status, message}
```

The Watchdog token path (§2.2.8) runs **before** any of the above when the request is a localhost POST to `ensure_running_service`. The install token path (§2.2.7) runs **after** normal auth.

#### 2.2.7 Install Token (v1.5.0)

A **one-shot CSRF token** consumed by `POST /api/install_companion_app`. It is **not** a session scheme. It is an additional per-request nonce.

```text
┌──────────────────────────────────────────────────────────────┐
│  Token lifecycle                                             │
│                                                              │
│  1. Client → GET /api?action=install_token                   │
│     • checkAuth() must succeed                               │
│     • isLocalRequest() must succeed                          │
│     • generateInstallToken():                                │
│         – 32 bytes from crypto/rand                          │
│         – hex-encode → 64 chars                              │
│         – store in installTokens[token] = {expiry: now + 60s}│
│     • response: {"token": "abc...", "ttl": 60}               │
│                                                              │
│  2. Client → POST /api/install_companion_app body: token=<tok>│
│     • checkAuth() must succeed                               │
│     • isLocalRequest() must succeed                          │
│     • isInstallLockedOut(ip) must be false                   │
│     • validateAndConsumeInstallToken(token):                 │
│         – constant-time scan of installTokens                │
│         – if not found OR expired → 401                      │
│         – if found → delete from map (single-use) → allow    │
│     • recordInstallAttempt(ip, success)                      │
│     • callInstallScript() runs install_app.sh                │
│                                                              │
│  3. Expired tokens are garbage-collected lazily              │
└──────────────────────────────────────────────────────────────┘
```

**Characteristics**:

| Aspect | Value |
|---|---|
| Entropy | 32 bytes `crypto/rand` → 64 hex (256-bit) |
| TTL | 60 seconds (`INSTALL_TOKEN_TTL`) |
| Reusable | ❌ Deleted from the map on first successful use |
| Consumed by | `POST /api/install_companion_app` only |
| Rate-limited | Yes — 5 failed install attempts / 15 min per IP |
| Session-related | No — orthogonal to cookie/bearer schemes |
| Localhost-only | Yes — `isLocalRequest()` gate on token issuance **and** install |
| **Comparison** | **`subtle.ConstantTimeCompare`** (constant-time iteration) |

**Constant-time comparison**: `validateAndConsumeInstallToken()` uses `subtle.ConstantTimeCompare` against every token stored in the `installTokens` map. Go's map iteration order is randomized per call, so the comparison cost also does not reveal the matched entry's position. Additional defense-in-depth layers:
- **256-bit entropy**: guessing is infeasible (2^256 space).
- **Single-use**: an intercepted token cannot be replayed.
- **60 s TTL**: the replay window is minimal.
- **Per-IP rate limit**: 5 attempts / 15 min per IP.
- **Localhost-only**: remote attackers cannot reach the endpoint at all.

**Why not persist the token**: unlike the watchdog token (§2.2.8), the install token is in-memory only. Server restart invalidates all outstanding tokens — acceptable because the TTL is 60 s.

**Client-side handling (IDX-401-DISTINCT)**: the WebUI's `xhrRequest()` suppresses the generic "Session Expired" modal for **token-consuming** install-family URLs (`install_companion_app` and `uninstall_companion_app`). A 401 from either of these is still surfaced to the caller and rendered as `t('installTokenError')`.

> **Note on 401 from `/api?action=install_token`**: this endpoint **issues** tokens; it does not consume them. A 401 here means **session expired** (the cookie or bearer token is invalid), NOT token-expired. The client MUST handle it via the standard session-expired path — NOT via `installTokenError`. Only `/api/install_companion_app` and `/api/uninstall_companion_app` return 401 for **token-expiry**. This distinction is enforced in `isInstallFamilyUrl()` — `install_token` is deliberately excluded from that list.

#### 2.2.8 Watchdog Token

The watchdog needs to call `POST /api/ensure_running_service` to recover a crashed DNS engine. In v1.1.0, this endpoint had only an implicit "localhost bypass" — exploitable via CSRF. Since v1.2.0, a **token** replaces the bypass:

- **Localhost-scoped**: `isLocalRequest(r)` still required.
- **POST-only**: only `POST /api/ensure_running_service`.
- **Constant-time**: `subtle.ConstantTimeCompare`.
- **Not rate-limited**: a flapping DNS engine does not lock the watchdog out.
- **Persistent**: the token file survives restarts.
- **Fail-closed**: if the token file is missing and no token is sent, falls back to normal user auth.

**Migration guidance for API clients**:
- If your client previously relied on the localhost bypass, it must now read `$RUN_DIR/.watchdog_token` and send `X-Watchdog-Token: <token>`.
- If your client uses a **Cookie/Bearer/Basic** session, **no change** is required.

### 2.3 Rate Limiting

#### 2.3.1 Limits (v1.6.0)

| Endpoint | Limit | Window |
|---|---|---|
| `POST /api/auth/login` | 5 failed attempts | 15 min |
| Basic Auth (any endpoint) | 5 failed attempts | 15 min |
| `POST /api/install_companion_app` | 5 **failed** attempts | 15 min |
| Watchdog token (`ensure_running_service`, localhost) | unlimited | — |
| `GET /api?action=install_token` | unlimited | — |
| `GET /api/*` (with Cookie/Bearer) | unlimited | — |
| `POST /api/*` (with Cookie/Bearer) | unlimited | — |

The install rate limit is **per-IP** and uses a **separate** state map (`installAttempts`) from the login limiter (`loginAttempts`). A failed login does not affect the install counter and vice versa. A **successful** install resets the counter for that IP.

#### 2.3.2 Behavior

- 5 failed attempts → 15-minute lockout.
- Lockout per IP; IPv4 and IPv6 supported via `net.SplitHostPort`.
- `X-Forwarded-For` is **not** used (localhost-only design).

**Response (429 — login / Basic Auth):**

```json
{
  "status": "error",
  "message": "Too many attempts. Try again later."
}
```

**Response (429 — install, v1.5.0+):**

```json
{
  "status": "error",
  "action": "install",
  "reason": "rate_limited",
  "message": "Too many install attempts. Try again in 15 minutes."
}
```

#### 2.3.3 Basic Auth Rate Limiting

Failed Basic Auth attempts are recorded in `loginAttempts` and share the same 5/15 min lockout as login. A successful Basic Auth resets the counter.

#### 2.3.4 Client IP Extraction

```go
func getClientIP(r *http.Request) string {
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return strings.Trim(r.RemoteAddr, "[]")
    }
    return host
}
```

- IPv4 `127.0.0.1:12345` → `127.0.0.1` ✓
- IPv6 `[::1]:12345` → `::1` ✓

#### 2.3.5 Auth Cache (60 s)

`getMonitoringAuth()` caches credentials for 60 seconds. Empty results are **never** cached (a failed read is retried on the next request). Changing credentials in TOML takes effect within ≤ 60 s; for immediate effect, restart the WebUI.

### 2.4 Response Format

#### 2.4.1 Success — Four Shapes

**Shape A — status-tagged** (most POST endpoints):

```json
{ "status": "ok", ...endpoint-specific fields... }
```

**Shape B — status field carrying a value** (short read-only status):

```json
{ "status": "ON" }
{ "status": "OFF" }
```

**Shape C — flat object, no status field** (read-only GETs):

```json
{ "token": "...", "ttl": 60 }
{ "allowlist": "...", "denylist": "..." }
{ ...runtime_info fields... }
```

**Shape D — install result** (v1.5.0+, two-part):

```json
{ "status": "ok" | "error", "action": "install" | "uninstall", ... }
```

See §2.4.6 for the full install-result shape.

#### 2.4.2 Error

```json
{
  "status": "error",
  "message": "Error description",
  "reason": "machine_readable_reason (optional)",
  "details": "Additional details (optional)"
}
```

**Exceptions** (two endpoints use a different shape):
- **`/readyz`** — on non-localhost, returns `{"error": "readyz is localhost-only"}` with HTTP 403.
- **`/api/metrics`** — `metricsProxyHandler` uses `{"error": "..."}` for its own error responses (401 / 500 / 502 / 503). See §2.6.14.

#### 2.4.3 Conflict

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```
*HTTP status: 409 Conflict.*

#### 2.4.4 Started (async)

```json
{
  "status": "started",
  "message": "Update in progress..."
}
```

#### 2.4.5 Not Found

```json
{
  "status": "error",
  "message": "unknown action: \"foo\""
}
```
*HTTP status: 404 Not Found.*

#### 2.4.6 Install Result (v1.5.0+)

`install_companion_app` uses a **two-part** shape: `{status, action, ...}`.

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

**Install failure** (HTTP 200):

```json
{
  "status": "error",
  "action": "install",
  "reason": "all_strategies_failed",
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
  "reason": "invalid_token" | "rate_limited" | "not_localhost" |
            "script_not_found" | "invalid_mode" | "no_json_output"
}
```

**`reason` field values**:

| HTTP | Source | Values |
|:---:|---|---|
| **4xx** | `main.go` | `invalid_token`, `rate_limited`, `not_localhost`, `script_not_found`, `invalid_mode`, `no_json_output` |
| **200** | `install_app.sh` | `apk_not_found`, `apk_empty`, `apk_too_small`, `apk_not_zip`, `sha_mismatch`, `insufficient_storage`, `all_strategies_failed` |

**Why a failed install returns HTTP 200**: a failed install is a valid outcome of a well-formed request. The WebUI needs to read the AR/EN message from the body. Only auth/rate-limit/token failures use 4xx.

**Client-side rendering (IDX-429, IDX-401-DISTINCT)**:
- **HTTP 429** → `t('installRateLimited')`.
- **HTTP 401** from a **token-consuming endpoint** (`install_companion_app` / `uninstall_companion_app`) → `t('installTokenError')`.
- **HTTP 401** from `install_token` → **standard session-expired path** (never `installTokenError` — see §2.2.7 for the reasoning).
- **HTTP 403** → `t('installError')` with a "localhost only" hint.
- **Other 4xx / 5xx** → `t('installError')`.

The two 401 branches are only distinguishable by **which endpoint produced the 401**, not by the response body. The client selects the branch by URL — `isInstallFamilyUrl()` returns true only for the two token-consuming endpoints.

### 2.5 Error Codes

#### 2.5.1 Table

| HTTP | Meaning | Example |
|---|---|---|
| 200 | ok / success | — |
| 200 | started | `update_profile` |
| 200 | install error | `install_companion_app` (status=error in body) |
| 400 | bad input | missing param |
| 401 | unauthorized | session expired / invalid watchdog token / invalid install token |
| 403 | forbidden | path traversal / `/readyz` from LAN / install from non-localhost |
| 404 | path/action not found | `?action=foo` |
| 405 | method not allowed | GET on POST endpoint / Login GET |
| 409 | conflict | concurrent edit |
| 413 | file too large | POST > 5 MB |
| 415 | unsupported media type | POST with non-form Content-Type |
| 429 | too many requests | rate limit (login + Basic Auth + install) |
| 500 | internal error | panic recovery |
| 502 | upstream error | monitoring_ui error |
| 503 | not ready | `/readyz` fail |

#### 2.5.2 404 vs 405 — Difference

| Case | HTTP | Response |
|---|---|---|
| **Unknown action** (`?action=foo`) | 404 | `{"status": "error", "message": "unknown action: \"foo\""}` |
| **Disallowed method** (GET on POST endpoint) | 405 | `{"status": "error", "message": "This endpoint requires POST (CSRF-GET protection)", "hint": "Use POST /api/<name>_service"}` + `Allow: POST` |
| **Login GET** | 405 | `{"status": "error", "message": "Login requires POST (CSRF protection)"}` + `Allow: POST` |
| **`/readyz` from LAN** | 403 | `{"error": "readyz is localhost-only"}` |
| **Install from non-localhost** | 403 | `{"status": "error", "action": "install", "reason": "not_localhost", "message": "Forbidden: install is localhost-only"}` |
| **Invalid install token** | 401 | `{"status": "error", "action": "install", "reason": "invalid_token", "message": "Invalid or expired install token"}` |
| **Install rate limit** | 429 | `{"status": "error", "action": "install", "reason": "rate_limited", "message": "Too many install attempts. Try again in 15 minutes."}` |
| **`install_token` from non-localhost** | 403 | `{"status": "error", "action": "install_token", "reason": "not_localhost", "message": "Forbidden: install is localhost-only"}` |

#### 2.5.3 Install-Specific Error Messages (v1.5.0+)

`install_app.sh` produces a structured JSON error response with localized AR + EN messages. The WebUI displays the message matching the user's language, plus an optional hint.

| `reason` | `message_en` (excerpt) | Typical cause |
|---|---|---|
| `apk_not_found` | "Companion APK not found in the module" | Dev build without the APK |
| `apk_empty` | "Companion APK is empty" | Failed download / partial copy |
| `apk_too_small` | "Companion APK is suspiciously small" | Truncated file |
| `apk_not_zip` | "Companion APK is not a valid ZIP archive" | Corrupted file |
| `sha_mismatch` | "Integrity check failed" | Tampered/corrupted APK |
| `insufficient_storage` | "Insufficient storage" | Device storage full |
| `all_strategies_failed` | "All install strategies failed" | All 5 cascade levels failed |

Each error may also carry `hint_ar` / `hint_en`. The WebUI renders both, and offers a **"⬇️ Download manually"** fallback button that navigates to `/app-debug.apk`.

### 2.6 GET Endpoints

#### 2.6.1 `GET /api?action=status`

```json
{ "status": "ON" }
```

Values: `ON` — DNS engine running, `OFF` — stopped. Read-only; does not write STATUS_FILE.

#### 2.6.2 `GET /api?action=get_profile`

```json
{
  "key": "pro",
  "name": "HaGeZi PRO",
  "entries": 250000,
  "is_empty": false,
  "last_update": "2026-11-12T04:03:46Z",
  "last_update_unix": 1794456226,
  "memory_limit_mb": 120
}
```

**`last_update`** — RFC3339 UTC string. Kept as a fallback for older clients.

**`last_update_unix`** — integer Unix timestamp (seconds since epoch). **New in v1.6.0.** The WebUI uses this field to display the time in the device's local timezone via `toLocaleString()`. See §3.10 for the full flow diagram.

**Why both fields**: the Unix timestamp is timezone-agnostic and solves the UTC display bug without breaking clients that still read the RFC3339 string.

#### 2.6.3 `GET /api?action=get_custom_rules`

```json
{
  "allowlist": "googleadservices.com\ns.youtube.com\n",
  "denylist": "facebook.com\ntiktok.com\n"
}
```

#### 2.6.4 `GET /api?action=get_rules_state`

```json
{
  "allowlist_hash": "abc123...",
  "denylist_hash": "def456..."
}
```

The hashes returned here are the authoritative source that `saveDenylist()` and `appendDenylist()` consult for their conflict checks. A client that mirrors these hashes and passes them back as `expected_hash` will not see spurious 409 conflicts when `denylist.txt` was modified externally.

#### 2.6.5 `GET /api?action=stats`

```json
{ "blocked_today": "1523" }
```

#### 2.6.6 `GET /api?action=resources`

```json
{ "ram": "18 MB" }
```

#### 2.6.7 `runtime_info` — ports + profile + memory + backups

Three equivalent entry points (all invoke `buildRuntimeInfo()`):

| Form | Handler | Notes |
|---|---|---|
| `GET /api/runtime_info` | `handleRuntimeInfo` | canonical path form |
| `GET /api/runtime_info/` | `handleRuntimeInfo` | trailing slash |
| `GET /api?action=runtime_info` | `handleAPI` | query-string form |

**Response (v1.6.0):**

```json
{
  "version": "v1.6.0",
  "commit": "a1b2c3d",
  "build_time": "1791626400",
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
    "last_backup": "2026-11-12 15:00:00",
    "last_backup_name": "20261112-150000-manual",
    "last_stable": "20261112-095826-v1.6.0",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

**Field groups**:

| Group | Fields |
|---|---|
| Build info | `version`, `commit`, `build_time`, `build_time_human`, `project_url` |
| Runtime paths | `run_dir`, `status_file`, `pid_file`, `progress_file`, `log_file` |
| Network | `bind_addr` |
| Dynamic ports | `webui_port`, `dashboard_port` |
| Memory profile | `profile_key`, `memory_limit_mb` |
| Companion app | `app_version` |
| Backups | 7 fields (below) |

**`backups` object — full schema**:

| Field | Type | Description |
|---|---|---|
| `available` | int | Number of snapshots (detection rule: `.manifest.json` presence — SNAP-MANIFEST) |
| `in_flight_txn` | int | Number of `txn-*` directories |
| `orphan_txn` | int | Number of `orphan-txn-*` directories |
| `last_backup` | string \| null | mtime of the newest snapshot (`YYYY-MM-DD HH:MM:SS`) |
| `last_backup_name` | string \| null | Directory name of the newest snapshot (sort key: mtime, SNAP-MTIME) |
| `last_stable` | string \| null | Content of `.last_stable` pointer, or null |
| `path` | string | Absolute path of the persistent backup directory |

`webui_port` / `dashboard_port` are served from a 30 s TTL cache. A manual `webui.conf` edit + immediate reload may show the old value for up to 30 s. A restart always re-reads the file.

#### 2.6.8 `GET /api?action=logs`

Last 300 lines from the log.

```json
{ "logs": "[2026-11-12T10:30:00Z] 🚀 Starting DNSCrypt WebUI...\n[...]" }
```

#### 2.6.9 `GET /api?action=list_logs`

```json
{
  "status": "ok",
  "files": [
    { "name": "dnscrypt_main.log", "size": 45312, "mtime": 1791626400, "type": "active", "extension": ".log" },
    { "name": "dnscrypt_main.log.1726900000.old.gz", "size": 12456, "mtime": 1791626400, "type": "archive", "extension": ".gz" },
    { "name": "dnscrypt_credentials.txt", "size": 250, "mtime": 1791626400, "type": "sensitive", "extension": ".txt" }
  ],
  "count": 3
}
```

#### 2.6.10 `GET /api?action=read_log&file=<name>&confirm=1`

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

**Response (sensitive file, no `confirm=1`):**

```json
{
  "status": "requires_confirm",
  "message": "Sensitive file requires confirmation",
  "name": "dnscrypt_credentials.txt"
}
```

#### 2.6.11 `GET /api?action=get_progress`

```json
{ "progress": "50|Downloading..." }
```

Format: `percent|message`.

#### 2.6.12 `GET /api?action=check_old_modules`

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

#### 2.6.13 `GET /api/download_log?file=<name>&confirm=1`

Binary stream (`application/octet-stream`). Headers:

```http
Content-Type: application/octet-stream
Content-Disposition: attachment; filename="dnscrypt_main.log"
Content-Length: 45312
Cache-Control: no-cache, no-store, must-revalidate
```

**Error responses** (plain text bodies, not JSON):

| Condition | HTTP | Body |
|---|---|---|
| Not authenticated | 401 | `Unauthorized` |
| Path outside whitelist | 403 | `Forbidden` |
| Sensitive file without `confirm=1` | 403 | `Confirmation required` |
| File not found | 404 | (empty, from `http.NotFound`) |
| File size > 100 MB | 413 | `File too large` |

#### 2.6.14 `GET /api/metrics` (Dashboard, port 9091)

Proxies `monitoring_ui` (port 8080). The upstream URL is built from the `MONITORING_UI_PORT` Go constant. If the upstream response is already JSON, it is passed through. Otherwise, Prometheus text is converted via `parsePrometheus()` + `buildDashboardJSON()`.

**Response (200 OK):**

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Cache-Control: no-cache, no-store, must-revalidate

{
  "generated_at": "2026-11-12T10:30:00Z",
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

**Error responses** — this endpoint uses `{"error": "..."}` instead of `{status, message}`:

| HTTP | `error` value |
|---|---|
| 401 | `"Unauthorized Access"` |
| 500 | `"Monitoring authentication not configured"` or `"Failed to create proxy request"` |
| 502 | `"Upstream returned HTTP <code>"` or `"Failed to read upstream response"` |
| 503 | `"DNSCrypt-Proxy is stopped or unreachable"` |

#### 2.6.15 `GET /app-debug.apk` — Companion Android App

Serves the optional companion Android app APK. **Public route** — no authentication required.

**Response (200 — APK present):**

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.android.package-archive
Cache-Control: public, max-age=3600, immutable
Content-Length: 3145728
```

**Response (404 — APK absent, dev build):**

```http
HTTP/1.1 404 Not Found
Content-Type: text/plain; charset=utf-8
X-Content-Type-Options: nosniff

404 page not found
```

**v1.5.0+ note**: the WebUI install button no longer links directly to this route. It opens the **install-method modal** (IDX-24) whose primary action performs a root install via `POST /api/install_companion_app`. The `/app-debug.apk` route remains reachable as a **fallback** when the local install fails.

#### 2.6.16 `GET /api?action=install_token` (v1.5.0)

Generates a **one-shot CSRF token** for the companion app install flow. The token is consumed by the next `POST /api/install_companion_app`.

**Auth**: session cookie (or Bearer/Basic). **Localhost-only**.

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

**Response (401):**

```json
{ "status": "error", "message": "Unauthorized" }
```

**Response (403 — non-localhost):**

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
| `ttl` | int | Token lifetime in seconds. Always `60`. |

**Characteristics**:
- **Single-use**: removed from the server-side map on the first successful use.
- **Ephemeral**: memory only. A restart invalidates all tokens.
- **Lazy GC**: expired tokens are removed on the next `generateInstallToken()` call.
- **Not rate-limited**: generating a token is cheap and side-effect-free. The rate limit applies to the install attempt (§2.7.14).

#### 2.6.17 `GET /api?action=companion_app_state` (v1.5.0)

Returns the current install state of the companion app.

**Auth**: session cookie (or Bearer/Basic).

**Cache**: server-side, **30 seconds** (`COMPANION_STATE_CACHE_TTL`). Invalidated after every install/uninstall attempt — success OR failure. A failed install may still register the package a few seconds later; the cache must not keep reporting `{installed: false}`.

**Request:**

```http
GET /api?action=companion_app_state HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
```

**Response (200 — installed):**

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

**Response (200 — not installed):**

```json
{
  "status": "ok",
  "action": "status",
  "installed": false,
  "package": "com.gasciljh.dnsproxy.debug",
  "expected_version": "1.0.0"
}
```

When not installed, `install_app.sh` returns the **default candidate** name (`com.gasciljh.dnsproxy.debug`) in the `package` field and **omits** `version_name`.

**Response (200 — different version):**

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

**Package name candidates**: the server tries three candidates in order:
1. `com.gasciljh.dnsproxy.debug` (default)
2. `com.gasciljh.dnsproxy`
3. `com.gasciljh.dnscrypt_proxy` (legacy)

**WebUI usage**: the button label is set based on three cases:
- **Not installed** → 📲 "Install App" (enabled).
- **Installed, version match** → ✅ "Installed" (disabled).
- **Installed, version mismatch** → 🔄 "Update App" (enabled).

### 2.7 POST Endpoints

**Content-Type requirement**: every POST endpoint that reads a request body calls `requireFormContentType()`. Accepted values: `application/x-www-form-urlencoded`, `multipart/form-data`, or **Empty** (for compatibility with `wget --post-data=''`). Any other Content-Type returns **HTTP 415**.

**Body size limit**: `MaxBytesReader` caps every POST body at **5 MB** (`MAX_POST_BODY_SIZE`). Exceeding → HTTP 413 with a JSON body.

#### 2.7.1 `POST /api/auth/login`

See §2.2.3.

#### 2.7.2 `POST /api/auth/logout`

See §2.2.5.

#### 2.7.3 `POST /api/update_profile`

**Pre-critical backup**: `createAutoBackup("pre-profile-change")` before writing.

**Request:**

```http
POST /api/update_profile HTTP/1.1
Content-Type: application/x-www-form-urlencoded

profile=pro
```
*Values: `light`, `normal`, `pro`, `proplus`, `ultimate`.*

**Response (200 — async):**

```json
{
  "status": "started",
  "message": "Update in progress..."
}
```

#### 2.7.4 `POST /api/save_allowlist`

**Pre-critical backup**: `createAutoBackup("pre-allowlist-save")`.

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

**Response (409 conflict):**

```json
{
  "status": "conflict",
  "message": "Modified in another session"
}
```

#### 2.7.5 `POST /api/save_denylist`

Same as `save_allowlist` but uses the `denylist` param. Pre-critical backup: `createAutoBackup("pre-denylist-save")`.

#### 2.7.6 `POST /api/save_custom_rules`

Save both atomically. Pre-critical backup: `createAutoBackup("pre-custom-rules-save")`.

```http
POST /api/save_custom_rules HTTP/1.1
Content-Type: application/x-www-form-urlencoded

allowlist=googleadservices.com&denylist=facebook.com
```

Response shape: same as `save_allowlist`.

#### 2.7.7 `POST /api/append_denylist`

**Pre-critical backup**: performed **once** by the delegated `saveDenylist` path.

```http
POST /api/append_denylist HTTP/1.1
Content-Type: application/x-www-form-urlencoded

content=tracker.example.com%0Aads.example.com
```

**Response (200 — rules applied):**

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

**Response (200 — no change):**

```json
{
  "status": "ok",
  "changed": false,
  "message": "No changes detected",
  ...
}
```

The internal hash check uses `getRulesState().DenylistHash` — the same source consulted by `saveDenylist()`. An externally modified `denylist.txt` no longer produces a spurious 409.

#### 2.7.8 `POST /api/clear_log_file`

```http
POST /api/clear_log_file HTTP/1.1
Content-Type: application/x-www-form-urlencoded

file=dnscrypt_main.log.1726700000.old.gz
```

**Response:**

```json
{ "status": "ok", "message": "File cleared successfully" }
```

#### 2.7.9 `POST /api/clear_logs`

Clear the main log.

```json
{ "status": "ok", "message": "Logs cleared successfully" }
```

#### 2.7.10 `POST /api/remove_module`

**v1.4.0 CodeQL hardening**: the handler sanitizes the caller-provided path via `filepath.Base()` and rebuilds the final path from the trusted `MODULES_DIR` constant using `securejoin.SecureJoin`. Closes two CodeQL `go/path-injection` alerts. See `SECURITY.md` §5.34.

**Request:**

```http
POST /api/remove_module HTTP/1.1
Content-Type: application/x-www-form-urlencoded

path=/data/adb/modules/dnscrypt-old
```

**Response (200):**

```json
{ "status": "ok", "message": "Old module removed successfully" }
```

**Response (400):**

```json
{ "status": "error", "message": "Invalid module name" }
```

#### 2.7.11 `POST /api/toggle_service`

POST only (CSRF protection — was GET in earlier versions).

```http
POST /api/toggle_service HTTP/1.1
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200):**

```json
{ "status": "ON" }
```

**Response (busy):**

```json
{ "status": "error", "message": "Service is busy" }
```

**Response to GET (error):**

```http
HTTP/1.1 405 Method Not Allowed
Allow: POST

{
  "status": "error",
  "message": "This endpoint requires POST (CSRF-GET protection)",
  "hint": "Use POST /api/toggle_service"
}
```

#### 2.7.12 `POST /api/restart_service`

```http
POST /api/restart_service HTTP/1.1
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200):**

```json
{ "status": "ON" }
```

#### 2.7.13 `POST /api/ensure_running_service`

Called by the Watchdog **and** (since v1.3.0) by `service.sh` at boot to ensure the DNS engine starts even when the WebUI has not yet loaded.

**Authentication (v1.2.0)** — **two** auth paths, in this order:
1. **Watchdog token** (preferred): POST + loopback + valid `X-Watchdog-Token` header (constant-time compared).
2. **Normal user auth** (Bearer/Cookie/Basic).

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
{ "status": "ON", "action": "started" }
```

**Response (already running):**

```json
{ "status": "ON", "action": "none", "message": "Already running" }
```

**Response (401 — no token, no user auth):**

```json
{ "status": "error", "message": "Unauthorized" }
```

#### 2.7.14 `POST /api/install_companion_app` (v1.5.0)

Performs a **root-level install** of the companion Android app. The server runs `install_app.sh`, which tries a 5-level `pm install` cascade.

**Layout note**: `install_app.sh` is staged at the module root by `customize.sh §[12]` — not under `proxy/`. The path is resolved by `main.go`'s `getInstallScript()` via `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`.

**Auth**: session cookie (or Bearer/Basic) **AND** a valid one-shot CSRF token from §2.6.16. **Localhost only.**

**Rate limit**: 5 **failed** attempts / 15 min per IP. A successful install resets the counter.

**Retry policy**: WebUI disables retries for this endpoint (`retries = 0`). Rationale: the first request consumes the CSRF token; a retry would produce "Invalid or expired install token" even when the first install is still in progress.

**Timeouts**:
- Client (WebUI `getTimeoutForUrl`): **120 s**.
- Server (`main.go` §[3b] `INSTALL_TIMEOUT`): **90 s**.
- Cascade (`install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS`): **75 s**.
- HTTP WriteTimeout (server, all responses): **150 s**.

**Request:**

```http
POST /api/install_companion_app HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
Content-Type: application/x-www-form-urlencoded

token=abc123def456789abc123def456789abc123def456789abc123def4567890
```

**Response (200 — install succeeded):** (See §2.4.6)

**Response (200 — install failed):** (See §2.4.6)

**Response (401 — invalid or expired token):**

```json
{
  "status": "error",
  "action": "install",
  "reason": "invalid_token",
  "message": "Invalid or expired install token"
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

**The 5-level cascade** (first success wins):

| Level | Command | Notes |
|:-:|---|---|
| **1** | `pm install -r --user 0 <apk>` | Direct install as current user |
| **2** | `pm install -r --user 0 -i com.android.shell <apk>` | Shell-attributed |
| **3** | Session-based (`install-create` + `install-write` + `install-commit`) | Same API Google Play uses |
| **4** | `magisk su -c "pm install -r <apk>"` | Explicit Magisk root |
| **5** | `cmd package install -r <apk>` | Modern PackageManager shell entrypoint (Android 8.0+) |

After each level, the script polls `pm list packages` for up to 15 s to confirm success (the exit code of `pm install` alone is not reliable across ROMs).

**SELinux staging**: the APK is copied to `/data/local/tmp/dnscrypt-companion.apk` (context `shell_data_file`, readable by `system_server`). **SELinux is never disabled** — no `setenforce 0`. The staged copy is removed on exit by the trap.

**Trap semantics**: three separate handlers (`EXIT` / `INT` / `TERM`) with a `_CLEANED_UP` re-entry guard inside a named `_cleanup_app()` function. The `INT` handler calls `exit 130`; the `TERM` handler calls `exit 143`. `main.go` sends SIGKILL after `INSTALL_TIMEOUT`, which is uncatchable — the 75 s cascade deadline ensures the trap fires before that point.

**Play Protect**: the package verifier is temporarily disabled during the cascade, and restored on exit via the three-way trap. The trap restores the exact captured value (`$_VERIFIER_ORIG`), not a hardcoded `1`.

**SHA256 verification**: if `web/app-debug.apk.sha256` is present, the APK's SHA256 is verified before any install strategy. If absent, the script degrades to advisory mode.

#### 2.7.15 `POST /api/uninstall_companion_app` (v1.5.0)

Removes the companion app package.

**Status**: implemented and functional; **not exposed** in the v1.5.0+ install-method modal (IDX-24).

**Auth**: session cookie (or Bearer/Basic). **Localhost only.**

**Request:**

```http
POST /api/uninstall_companion_app HTTP/1.1
Host: 127.0.0.1:9090
Cookie: dnscrypt_session=<token>
Content-Length: 0
```

**Response (200 — uninstall succeeded):**

```json
{
  "status": "ok",
  "action": "uninstall",
  "package": "com.gasciljh.dnsproxy.debug",
  "message": "uninstalled"
}
```

**Response (404 — not installed)**: `install_app.sh --uninstall` exits with code 4 when the package is not installed:

```json
{
  "status": "ok",
  "action": "uninstall",
  "package": "com.gasciljh.dnsproxy.debug",
  "message": "not_installed"
}
```

### 2.8 Path Matching

#### 2.8.1 `hasEndpoint()`

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

#### 2.8.2 Comparison

| Path | `strings.Contains` (old) | `hasEndpoint` (new) |
|------|:---:|:---:|
| `/api/update_profile` | ✅ | ✅ |
| `/api/update_profile/` | ✅ | ✅ |
| `/api/update_profile_evil` | ✅ (**bug**) | ❌ |
| `/prefix/api/update_profile` | ✅ (**bug**) | ❌ |
| `/api/update_profile/child` | ✅ (**bug**) | ❌ |
| `/api/save_allowlist_extra` | ❌ | ❌ |

### 2.9 SSE Events

#### 2.9.1 Connection

**Endpoint**: `GET /events`
**Headers**: `Accept: text/event-stream`
**Response headers**:

```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
X-Accel-Buffering: no
```

#### 2.9.2 Event Types

| Event | Data | Push behavior |
|---|---|---|
| status | `ON` / `OFF` | on change |
| stats | `{"blocked_today":"1523"}` | once per connection + on toggle/restart/update |
| resources | `{"ram":"18 MB"}` | once per connection + on toggle/restart/update |
| progress | `50\|Downloading...` | during update |
| keepalive | `: keepalive` | every 15 s |

#### 2.9.3 Example Stream

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

#### 2.9.4 SSE Write Deadline

```go
rc := http.NewResponseController(w)
_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))  // 30 s
fmt.Fprint(w, msg)
if err := flusher.Flush(); err != nil {
    return  // releases the goroutine
}
```

### 2.10 Health Checks

#### 2.10.1 `GET /healthz`

Liveness check. Always returns `ok` if the server is running.

```http
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Cache-Control: no-store

ok
```

**Public** — no auth.

#### 2.10.2 `GET /readyz` — localhost-only

Readiness check. Verifies dependencies. Non-localhost requests → **403 Forbidden**.

**Response (200) — from localhost:**

```json
{
  "config": "ok",
  "blocklist": "ok",
  "run_dir": "ok",
  "dns_engine": "ok",
  "version": "v1.6.0",
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
  "version": "v1.6.0",
  "status": "unhealthy"
}
```

**Response (403) — from LAN:**

```http
HTTP/1.1 403 Forbidden

{ "error": "readyz is localhost-only" }
```

### 2.11 Examples

#### 2.11.1 cURL

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

**Full companion install flow (v1.5.0+):**

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

#### 2.11.2 Python

```python
import requests

BASE = "http://127.0.0.1:9090"
DASHBOARD = "http://127.0.0.1:9091"

# requests.Session persists cookies across requests.
s = requests.Session()
s.post(f"{BASE}/api/auth/login", json={
    "username": "admin_abc12345",
    "password": "SecurePass123",
})

print(f"Service: {s.get(f'{BASE}/api?action=status').json()['status']}")

# Metrics
metrics = s.get(f"{DASHBOARD}/api/metrics").json()
print(f"Total queries: {metrics['total_queries']}")

# v1.5.0+ — Companion install flow
token_resp = s.get(f"{BASE}/api?action=install_token").json()
install_resp = s.post(f"{BASE}/api/install_companion_app",
                      data={"token": token_resp["token"]})

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
```

#### 2.11.3 Backup Diagnostics

```bash
# Read the full backup state
curl -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api?action=runtime_info" | jq '.backups'
```

### 2.12 Version-Aware Behavior

#### 2.12.1 Backward Compatibility

All **v1.4.0 clients** work unchanged against the v1.5.0 and v1.6.0 APIs. The v1.5.0+ additions are **strictly additive**:
- 4 new endpoints.
- 1 new field in the install response.
- 1 raised timeout.
- 1 new localhost-only restriction on `install_token`.

The v1.6.0 additions are also strictly additive:
- 1 new response field (`last_update_unix` on `get_profile`).
- No API changes.

#### 2.12.2 Additive vs Breaking

| Category | v1.5.0+ | v1.6.0 |
|---|---|---|
| **Additive** | 4 endpoints, 1 request body param (`token`), response fields, timeout raise | 1 response field (`last_update_unix`) |
| **Breaking** | None | None |
| **Behavioral changes** (may affect clients) | `install_token` is localhost-only; retries disabled for `install_companion_app` | None — old clients continue to read `last_update` (RFC3339) unchanged |

---

## 3. Data Flow & Internals

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
├──► createAutoBackup("pre-profile-change")
│      ├──► backup_user_files() → snapshot to /sdcard/.../<ts>-manual-<pid>/
│      ├──► rotate_backups 21 (ROT-MANIFEST + ROT-MTIME + ROT-PROTECT)
│      └──► best-effort: failure logs warning, does NOT block update
│
├──► writeProgress(5, "Connecting...")
├──► downloadWithProgress(URL, tempFile)
│      ├──► atomicWriteStream()
│      └──► broadcastEvent("progress", "10|...") → SSE
│
├──► validateBlocklist(tempFile)
│
├──► rebuildBlocklist()   ← protected by rebuildMu (RACE-1)
│      ├──► rebuildMu.Lock()
│      ├──► read allowlist.txt → Set
│      ├──► read denylist.txt → []string
│      ├──► stream blocklist.raw → atomicWriteStream(blocklist.txt)
│      └──► rebuildMu.Unlock()  (defer)
│
├──► atomicWriteFile(SELECTED_FILE, key)
├──► applyMemoryLimit(key)
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

**Boot sequence** (three phases):

```text
Phase 1 — post-fs-data (before system_server)
  Script:  post-fs-data.sh
  Role:    emergency cleanup (only when the module is disabled)
  Actions:
    1. inline_firewall_cleanup (Custom Chains + legacy)
    2. pkill -9 dnscrypt-proxy
    3. pkill -9 dnscrypt-webui
    4. rm stale PID files
    5. Write STATUS_FILE = OFF

Phase 2 — service (sys.boot_completed = 1)
  Script:  service.sh
  Role:    start WebUI + DNS engine + watchdog
  Actions:
    1. Read webui.conf (PORT, AUTO_RESTART_*)
    2. Wait for network readiness
    3. do_cleanup_proxy (kill leftovers)
    4. do_cleanup_transactions
    5. Start WebUI (setsid → busybox setsid → nohup)
    6. Launch watchdog.sh as a separate process
    7. Bounded wait for the WebUI port
    8. Mirror APK + .sha256 to apk/
    9. Auto-backup if needed (24 h interval)
   10. Rotate backups (21 max)
   11. Read .pending_notification (log only)
   12. Call POST /api/ensure_running_service with X-Watchdog-Token

Phase 3 — runtime (watchdog.sh standalone)
  Loop (30 s → 600 s exponential backoff per service):
    • If $MODDIR/disable exists → exit 0
    • If WebUI port closed and AUTO_RESTART_WEBUI=1 and 5354/udp closed
    • If STATUS_FILE = "ON" and 5354/udp closed
      → POST /api/ensure_running_service (with token)
    • Reset backoff on success and on STATUS_FILE change
```

**Interaction between phases**:

| Event | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| Module disabled | Full cleanup + exit | Skipped | Skipped |
| Fresh install | Runs (no-op) | Full startup | Full monitoring |
| Upgrade | Runs (no-op) | Full startup | Full monitoring |
| Reboot | Runs (no-op) | Full startup | Full monitoring |

**Watchdog process model**: `watchdog.sh` is launched by `service.sh` as a **separate process** (via `setsid` / `nohup`), not as a subshell. This is critical: `$$` inside `watchdog.sh` must resolve to the watchdog's own PID, not the parent's. The watchdog requires **exactly 5 positional arguments** and exits 1 otherwise. Its HTTP client cascade is three-way (`curl` → `wget` → `busybox wget`), all invoked through `env -i` with explicit `PATH`, `HOME=/data/local/tmp`, and empty proxy variables — so an inherited `http_proxy` cannot redirect the localhost API call. It does **not** participate in the companion install flow.

### 3.4 Dashboard Metrics

```text
User Browser → GET http://127.0.0.1:9091/api/metrics
│
▼
main.go :9091 (Dashboard Server)
│
├──► metricsProxyHandler
│    1. checkAuth(r)
│    2. getMonitoringAuth()  ← auth cache 60 s
│    3. HTTP GET http://127.0.0.1:<MONITORING_UI_PORT>/api/metrics
│       (Basic Auth)
│    4. body, _ := io.ReadAll(resp.Body)
│    5. if valid JSON → pass through
│    6. else → parsePrometheus() + buildDashboardJSON()
│    7. json.NewEncoder(w).Encode(...)
│
▼
User Browser receives JSON:
  { generated_at, total_queries, blocked_queries,
    cache_stats, resolver_health, top_domains, ... }
```

### 3.5 DNS Binaries Fetch

```text
CI / Developer
│
▼
scripts/fetch_dns_binaries.sh
│
├──► read proxy/dnscrypt-proxy.version → "2.1.20"
│
├──► cache check
│      ├── ~/.cache/.../dnscrypt-proxy-arm64    ✓
│      ├── ~/.cache/.../dnscrypt-proxy-arm      ✓
│      ├── ~/.cache/.../dnscrypt-proxy-x86_64   ✓
│      └── ~/.cache/.../dnscrypt-proxy-i386     ✗
│
├──► for missing: 4 fallback sources
│      1. GitHub API       → real asset names
│      2. android_X-V.zip  → 2.1.18+ format
│      3. android-X-V.zip  → older format
│      4. android_X_V.zip  → underscore format
│
├──► SHA256 verification
│
└──► save to cache + .manifest.json
```

### 3.6 Companion APK Fetch

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
├──► if missing: two URL fallbacks, tried in order
│      1. .../releases/download/v1.0.0/app-debug.apk
│      2. .../releases/latest/download/app-debug.apk
│
├──► SHA256 + .manifest.json
│
├──► output: dist/DNS-Proxy-v1.0.0.apk + .sha256
│
└──► release.yml stages to web/app-debug.apk before packaging
```

The release pipeline also fetches and stages the `.sha256` file at `web/app-debug.apk.sha256`. This enables SHA256 verification by `install_app.sh` during a root install. If the `.sha256` file is absent, `install_app.sh` degrades to advisory mode.

**Build artifacts**: `web/app-debug.apk` and `web/app-debug.apk.sha256` are **not tracked by git** (see `.gitignore` §[20]).

### 3.7 Login Flow

```text
User Browser → POST /api/auth/login
Content-Type: application/json
Body: {"username": "admin", "password": "..."}
│
▼
main.go — handleAPI
│
├──► if hasEndpoint(r.URL.Path, "auth/login") {
│        if r.Method != POST → 405 + Allow: POST
│        handleLogin(w, r)
│    }
│
▼
handleLogin()
  1. ip := getClientIP(r)  ← IPv6-safe
  2. if isLockedOut(ip) → 429
  3. read credentials (POST body)
  4. subtle.ConstantTimeCompare
  5. if fail → recordLoginAttempt(ip, false)
  6. if success → createSession + Set-Cookie
     (no token in response — cookie-only)
```

### 3.8 Rebuild Blocklist Concurrency (RACE-1)

```text
Thread 1 (updateProfile — in goroutine)
  os.Rename(tempFile, RAW_BLOCKLIST_FILE)
  rebuildBlocklist()
    ├── rebuildMu.Lock()
    ├── ... (I/O)
    └── defer rebuildMu.Unlock()

                            ⚡ ⚡ ⚡

Thread 2 (atomicSaveRulesInternal — HTTP handler)
  rulesStateMu.Lock()
  atomicWriteFile(ALLOWLIST_FILE, ...)
  rebuildBlocklist()
    ├── rebuildMu.Lock()  ← waits for Thread 1
    ├── ... (I/O)
    └── defer rebuildMu.Unlock()
  currentRules = rulesStateSnapshot{...}
  rulesStateMu.Unlock()
```

Result: `BLOCKLIST` is always consistent (no race conditions).

### 3.9 Dynamic Ports (PORT-2)

```text
Startup (main.go)
  serverPort = getWebUIPort()      ← from webui.conf
  dashboardPort = getDashboardPort() ← from webui.conf
  if serverPort == dashboardPort → FATAL
  if either == MONITORING_UI_PORT → FATAL
│
│ GET /api/runtime_info
▼
buildRuntimeInfo()
  {
    "version": "...",
    "webui_port": "9090",
    "dashboard_port": "9091",
    "bind_addr": "127.0.0.1",
    "profile_key": "pro",       ← from file
    "memory_limit_mb": 120,
    "app_version": "1.0.0",     ← from file
    "backups": { ... }
  }
│
▼
Frontend (index.html / dashboard.html)
  if (data.webui_port) PORTS.webui = ...
  if (data.dashboard_port) { PORTS.dashboard = ...; updateDashboardLink(); }
  // display profile + memory limit + backup state
```

### 3.10 Local Timezone Rendering Flow (v1.6.0)

**Background**: Prior to v1.6.0, the WebUI displayed the "Last Update" time as a raw UTC string (e.g., `04:03:46`), which was confusing for users in different timezones — a user in Yemen (UTC+3) would see `04:03:46` when their device clock showed `07:03:46`.

**Solution**: The backend now emits a **Unix timestamp** (`last_update_unix`) alongside the existing RFC3339 string (`last_update`). The frontend uses the Unix timestamp to render the time in the device's local timezone via `toLocaleString()`.

```text
┌─────────────────────────────────────────────────────────────┐
│  Backend (main.go) — buildProfileResponse()                 │
│                                                             │
│  lastUpdateMu.Lock()                                        │
│  if (TTL expired) {                                         │
│      modTime := fi.ModTime()                                │
│      lastUpdateStr  = modTime.UTC().Format(time.RFC3339)    │
│      lastUpdateUnix = modTime.Unix()                        │
│      lastUpdateCache     = lastUpdateStr                    │
│      lastUpdateUnixCache = lastUpdateUnix                   │
│      lastUpdateTime = time.Now()                            │
│  }                                                          │
│  lastUpdateMu.Unlock()                                      │
│                                                             │
│  return { ...,                                              │
│           "last_update":      lastUpdateStr,  // fallback   │
│           "last_update_unix": lastUpdateUnix, // v1.6.0 new │
│           ... }                                             │
└──────────────────────────────┬──────────────────────────────┘
                               │  JSON Response
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Frontend (index.html)                                      │
│                                                             │
│  loadProfile():                                             │
│    data.last_update_unix → 1794456226                       │
│                                                             │
│  renderProfileData():                                       │
│    var lu = formatUnixTimestamp(data.last_update_unix);     │
│    if (lu) {                                                │
│      $('lastUpdateText').textContent =                      │
│        t('lastUpdateLabel') + ' ' + lu;                     │
│    } else if (data.last_update) {                           │
│      // Fallback for older backends                         │
│      $('lastUpdateText').textContent =                      │
│        t('lastUpdateLabel') + ' ' + data.last_update;       │
│    }                                                        │
└──────────────────────────────┬──────────────────────────────┘
                               │  DOM Update
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Browser (Device Local Timezone)                            │
│                                                             │
│  Last update: 2026/11/12 07:03:46                           │
│  (Yemen time — UTC+3)                                       │
└─────────────────────────────────────────────────────────────┘
```

**Implementation details**:

| Layer | Where | Behavior |
|---|---|---|
| **Backend** | `main.go` → `buildProfileResponse()` | Emits both `last_update` (RFC3339 UTC) and `last_update_unix` (epoch seconds). Preserves the 5-second `lastUpdateCache` TTL to avoid disk I/O. |
| **Backend** | `main.go` → `updateProfileBody()` | After a successful profile update, sets `lastUpdateCache = time.Now().UTC().Format(time.RFC3339)` and `lastUpdateUnixCache = time.Now().Unix()`. |
| **Frontend** | `index.html` → `formatUnixTimestamp(unix)` | `new Date(unix * 1000).toLocaleString(currentLang === 'ar' ? 'ar-EG' : 'en-US', { ... })`. Returns `null` on any error, triggering the fallback branch. |
| **Frontend** | `index.html` → `renderProfileData(data)` | Prefers `last_update_unix`; falls back to `last_update` when the Unix field is absent or unparseable. |
| **Dashboard** | `dashboard.html` → `renderRuntimeInfo()` | Already used the same mtime + `toLocaleString()` pattern for `last_backup` — no change required. |

**Key invariants**:
- `last_update_unix` is **timezone-agnostic** (seconds since epoch).
- `last_update` (RFC3339 UTC) remains the fallback for older clients.
- The 5-second TTL cache is preserved — no disk I/O regression.
- The frontend uses `toLocaleString()` with the user's active language (`ar-EG` or `en-US`).
- Both fields are derived from the **same** `modTime` — they cannot disagree.

### 3.11 Memory Limit Flow (MEM-1)

```text
Startup (main.go)
  initialProfile := readSelectedProfile()
  applyMemoryLimit(initialProfile)
     ↓
  limit := memoryLimitForProfile(profile)
     light=80, normal=100, pro=120, proplus=160, ultimate=220
     ↓
  debug.SetMemoryLimit(limit)
  (Go runtime: SOFT limit → GC pressure, not OOM)
│
│ user changes profile
▼
POST /api/update_profile?profile=ultimate
  updateProfile("ultimate")
    ├── download + validate
    ├── rebuildBlocklist (with rebuildMu)
    ├── atomicWriteFile(SELECTED_FILE, "ultimate")
    └── applyMemoryLimit("ultimate")
           ↓
         debug.SetMemoryLimit(220 MB)
```

**Key invariants**:

| Invariant | Where enforced |
|---|---|
| `debug.SetMemoryLimit` called only from `main.go` | Go runtime |
| The limit is a **soft** limit (no OOM on breach) | Go runtime design |
| Recomputed at startup + every profile change | `main()` + `updateProfile()` |
| Shell scripts only **read** the hint | `get_profile_memory_hint()` |
| `runtime_info` exposes the effective limit | `buildRuntimeInfo()` |

### 3.12 Backup & Restore Flow

**Design philosophy**: *"Search for user data everywhere — do not guess whether this is an upgrade."*

```text
Install / Upgrade (customize.sh)
│
├── Layer 1 — Multi-source discovery (7 candidates)
│     • $MODPATH/proxy
│     • /data/adb/modules/dnscrypt-.../proxy
│     • /data/adb/modules/DNSCrypt-.../proxy
│     • /data/adb/modules/DNSCrypt-...WebUI/proxy
│     • $PERSISTENT_BACKUP/current
│     • $PERSISTENT_BACKUP
│     • /data/local/tmp/dnscrypt-webui-backup
│   First candidate with ≥ 3 valid files wins
│
├── Layer 2 — Persistent backup
│   → snapshot to /sdcard/dnscrypt-webui-backup/<ts>-<ver>-<pid>/
│   → write .manifest.json (SHA256 per file)
│   → atomic update of current/
│
├── Layer 3 — SHA256 integrity (advisory)
│
├── Layer 4 — Transactional upgrade
│   START → extract → COMMIT (or ROLLBACK on failure)
│
├── Layer 5 — Root-solution compat (Magisk/KernelSU/APatch)
│
├── Layer 6 — SELinux context preservation
│   restorecon → chcon → no-op
│
├── Layer 7 — Recovery mode
│   Trigger file → restore last known-good
│
├── Layer 8 — Config migrations (version-aware)
│
├── Layer 9 — Auto-backup (24 h) + rotation (21 snapshots)
│
└── Layer 10 — Observability
    .upgrade_history.json + 7-field runtime_info.backups
```

**Rotation policy**:

| Aspect | Behaviour |
|---|---|
| Snapshot detection | Presence of `.manifest.json` (ROT-MANIFEST) |
| Sort key | mtime, numeric descending (ROT-MTIME) |
| Protected targets | 21 newest + `.last_stable` + newest install (ROT-PROTECT) |
| APK mirror `apk/` | Excluded by name AND by missing manifest (two independent protections) |

**Recovery-mode interaction**: snapshot-and-reapply — `[8a]` restores to `$MODPATH/proxy/` AND snapshots to `$MODPATH/.recovery_snapshot/`; `[9]` unzips (overwrites); `[9b2]` re-applies the snapshot. `[9c]` is skipped.

**APK mirror (§[10c])**: `customize.sh` mirrors the companion APK and its `.sha256` to `$PERSISTENT_BACKUP/apk/` (best-effort). See §4.4.5 for the file format and §4.6.3 for the rotation protection.

### 3.13 Companion App Install Flow (v1.5.0)

The user's entry point is the WebUI install button (`#pwaInstallBtn` in `web/index.html`). Clicking it triggers a sequence that ends either in a root-level `pm install` or in a browser download from GitHub.

**End-to-end sequence (local install path)**:

```text
1. User clicks "Install App" (handleCompanionInstall())
2. GET /api?action=install_token
     • checkAuth() + isLocalRequest()
     • generateInstallToken(): 32-byte crypto/rand → hex → 64 chars
     • store in installTokens with TTL = 60 s
     • return { "token": "abc...", "ttl": 60 }
3. Show install-method modal (IDX-24)
     ┌──────────────────────────────────────────────────┐
     │  📲 Install App                                    │
     │  📦 Local install (recommended)                    │
     │     [ Install locally ]                            │
     │  🌐 Download from GitHub                           │
     │     [ Open GitHub page ] [ Direct download ]       │
     │              [ Cancel ]                            │
     └──────────────────────────────────────────────────┘
4. (user chose "Install locally")
   POST /api/install_companion_app  body: token=<csrf>
     • checkAuth() + isLocalRequest()
     • isInstallLockedOut(ip)  ← 5 attempts / 15 min
     • validateAndConsumeInstallToken(token)  ← one-shot
     • recordInstallAttempt(ip)
     • callInstallScript() runs install_app.sh (INSTALL_TIMEOUT = 90 s)
     • parse JSON from stdout
     • return structured response
5. install_app.sh (5-level cascade)
     Pre-flight: APK exists + non-empty + ZIP magic + size > 100 KB
                 + free space ≥ 3× APK size
     SELinux staging: cp APK → /data/local/tmp/dnscrypt-companion.apk
     Play Protect: capture $_VERIFIER_ORIG; set to 0;
                   trap → restore $_VERIFIER_ORIG on exit
     Cascade (first success wins):
       (1) pm install -r --user 0 <apk>
       (2) pm install -r --user 0 -i com.android.shell <apk>
       (3) session-based: install-create + install-write + install-commit
       (4) magisk su -c "pm install -r <apk>"
       (5) cmd package install -r <apk>
     Cascade deadline: CASCADE_DEADLINE_SECONDS = 75 (checked before each)
     After each strategy: poll up to 15 s for package registration
     Output: single-line JSON on stdout
6. WebUI renders result
     Success → showMsg + refreshCompanionState() → button "✅ Installed"
     Failure → error modal with localized message + hint
               + fallback button "⬇️ Download manually" → /app-debug.apk
```

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
| Shell injection | `shellQuote()` on all paths in `main.go` callers; `install_app.sh` uses hardcoded path + double-quoting |
| SELinux relaxation | NEVER `setenforce 0` — staging instead |
| Play Protect interference | temporary disable + restore via trap, bounded by 75 s cascade deadline |
| Play Protect restore value | trap restores `$_VERIFIER_ORIG` |
| APK tampering | SHA256 verification if `.sha256` present |
| Staged APK leftover | Three-way trap (EXIT/INT/TERM) removes it on every exit path |
| Signal-interrupt resume | INT exits 130, TERM exits 143 |
| Audit | full log in `dnscrypt_main.log` |

**Package name detection**:

```text
com.gasciljh.dnsproxy.debug    (default)
com.gasciljh.dnsproxy
com.gasciljh.dnscrypt_proxy    (legacy)
```

**Timeout hierarchy (four nested bounds)**:

| Level | Value | Source | Purpose |
|---|:-:|---|---|
| Client (WebUI) | 120 s | `web/index.html` `getTimeoutForUrl()` | Leaves headroom for HTTP round-trip + JSON parsing |
| HTTP WriteTimeout | 150 s | `main.go` §[3] `HTTP_WRITE_TIMEOUT` | Bounds the entire response-writing phase |
| Server handler | 90 s | `main.go` §[3b] `INSTALL_TIMEOUT` | Bounds the `exec.CommandContext` call |
| Cascade (script) | 75 s | `install_app.sh` §[2] `CASCADE_DEADLINE_SECONDS` | Ensures the trap fires inside the server timeout |

### 3.14 Backend Structure (main.go)

| Section | Purpose |
|---|---|
| `[0]`–`[4]` | Version vars, paths, constants, types |
| `[5]` | Rules state + `rebuildMu` (RACE-1) |
| `[6]`–`[7]` | HTTP Client + Paths |
| `[8]`–`[13]` | Variables, Config, Logging, Atomic Writes |
| `[14]` | SSE (with Write Deadline) |
| `[15]`–`[17]` | Stats, Auth (Basic/Bearer/Cookie/Watchdog Token) |
| `[17d]` | Companion app install helpers (10 functions) |
| `[18]`–`[19]` | Process/Port Checks + Service Lifecycle |
| `[20]`–`[23]` | Entries Count, Download, Domain Matching |
| `[24]`–`[27]` | Atomic Rules Save, Profile Management |
| `[28]`–`[29]` | Old Modules, Log Files |
| `[30]`–`[33]` | runtime_info, healthz/readyz, API, Login |
| `[34]` | serveStaticAssets (whitelist) |
| `[35]` | metricsProxyHandler |
| `[36b]` | Auto-backup + rotation + notifications |
| `[36c]` | Transaction cleanup at startup |
| `[37]` | main() |

**Size**: **~4,900 lines**.

**Note on `install_app.sh` layout**: staged at the module root by `customize.sh §[12]`. The path is resolved by `getInstallScript()` via `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`.

**API endpoints**: see §2.6 and §2.7 of this file for the full 32-endpoint reference.

**Backend fixes summary**: The full fix history is documented in `SECURITY.md` §15. Key categories:
- **Critical backend fixes** (v1.0.0): `STATUS_FILE` semantics, `metricsProxyHandler` path, IPv6 client IP, port collision guard, section-restricted TOML, dashboard JSON conversion, `getSystemShell()` fallback, Basic Auth rate limiting, section header with comment, per-port cache, exact endpoint matching, login POST-only, `readConfPort` range check, `/readyz` localhost-only, `shellQuote` injection protection, auth cache 60 s, `rebuildMu` mutex, `runtime_info` dynamic ports.
- **v1.1.0 additions**: MEM-1, MEM-2, MEM-3.
- **v1.2.0 additions**: BAK-1..BAK-4, WD-TOKEN, BUG-A..L.
- **v1.3.0 additions**: SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT.
- **v1.4.0 additions**: APK-1, APK-2, CQ-FIX, IOS-REMOVE.
- **v1.5.0 additions**: APK-3..APK-8, APK-11, APK-12, CIA-1..16, V15-CODE-01..04, MAIN-REENT-01, MAIN-PORTCACHE-01, MAIN-DEADLOCALHOST-01, MAIN-APPENDHASH-01, MAIN-02..05, MAIN-CACHE-01.
- **v1.6.0 additions**: local timezone rendering (`last_update_unix`), `lib/` modularization (no behavior change in main.go), preserved 5-second `lastUpdateCache` TTL, `buildBackupInfo` now sorts snapshots by **mtime** (matching `rotate_backups` and `status.sh`).

### 3.15 Concurrency Model

| Resource | Protection |
|---|---|
| `currentRules` | `sync.RWMutex` (`rulesStateMu`) |
| `rebuildMu` | `sync.Mutex` (RACE-1) |
| `sessions` | `sync.RWMutex` (`sessionsMu`) |
| `loginAttempts` | `sync.Mutex` |
| `authCacheMu` | `sync.RWMutex` (empty values never cached) |
| `serviceMutex` | `sync.Mutex` (`TryLock`) |
| `cachedStatus` | `sync.Mutex` |
| `cachedCount` | `sync.Mutex` |
| `sseClients` | `sync.Mutex` |
| `downloadClient` | `sync.Mutex` |
| `runDirUsable` | `sync.Mutex` (30 s cache) |
| `portCacheMap` | `sync.Mutex` |
| `systemShell` | `sync.Once` |
| `memLimitMu` | `sync.Mutex` (MEM-1) |
| `backupMu` | `sync.Mutex` |
| `watchdogTokMu` | `sync.RWMutex` |
| `lastUpdateMu` | `sync.Mutex` (5 s TTL) |
| `installTokens` | `sync.Mutex` (`installTokensMu`) |
| `installAttempts` | `sync.Mutex` (`installAttemptsMu`) |
| `companionStateCache` | `sync.Mutex` (30 s TTL) |
| `portConfMu` | `sync.RWMutex` (30 s TTL) |

**Key rationale**:
- **`backupMu`** — two rapid user actions could trigger two `createAutoBackup` calls that operate on the same source directory. `backupMu` serializes them.
- **`installTokens`** — each install request consumes a one-shot CSRF token. The store is a `map[string]installToken` with a TTL. Expired entries are evicted lazily on the next `generateInstallToken()` call.
- **`installAttempts`** — mirrors `loginAttempts`. It stores `{count, lockoutUntil}` per IP. The lockout is 15 minutes after 5 failed attempts.
- **`companionStateCache`** — prevents forking `pm list packages` on every page load. 30-second TTL. Invalidated explicitly after every install/uninstall attempt.
- **`portConfMu`** — `getWebUIPort()` and `getDashboardPort()` are called on every `/api?action=runtime_info` request. The 30-second TTL cache collapses those two reads into at most one. The cache key is the caller-declared `which` argument (`"webui"` or `"dashboard"`).
- **`lastUpdateMu`** — protects the `lastUpdateCache` and `lastUpdateUnixCache` fields (v1.6.0 addition). The 5-second TTL is unchanged from v1.5.0 — the v1.6.0 change only adds a second cached field, not a new cache policy.

### 3.16 SSE Implementation

```text
broadcastEvent(event, data)
  ├── sseMutex.Lock()
  ├── for each client channel:
  │   ├── select { case ch <- msg: default: }
  │   └── (non-blocking)
  └── sseMutex.Unlock()
│
│ (client channels)
▼
sseHandler(w, r)  [per-client goroutine]
  ├── rc := http.NewResponseController(w)
  ├── ch := make(chan string, 100)  ← Buffered
  ├── loop:
  │   ├── select {
  │   │   case msg := <-ch:
  │   │     rc.SetWriteDeadline(now + 30 s)  ← Deadline
  │   │     fmt.Fprint(w, msg)
  │   │     if err := flusher.Flush(); err != nil { return }
  │   │   case <-ticker.C:
  │   │     rc.SetWriteDeadline(now + 30 s)
  │   │     fmt.Fprint(w, ": keepalive\n\n")
  │   │     flusher.Flush()
  │   │   case <-r.Context().Done(): return
  │   │ }
  │   └── }
  └── }
```

**Why Write Deadline**: if the client is slow, TCP buffer fills up → `Fprint` / `Flush` block → goroutine hangs forever → DoS. The 30-second write deadline closes the connection when a flush cannot complete in time.

**Constants**:

| Constant | Value | Reason |
|---|---|---|
| `SSE_WRITE_TIMEOUT` | 30 s | Enough for slow networks, short enough to prevent DoS |
| `SSE_KEEPALIVE_INTERVAL` | 15 s | Less than WriteTimeout to renew the deadline |
| `ch buffer` | 100 | Absorbs bursts without blocking the producer |

---

## 4. Backup System

### 4.1 Why a Backup System

#### 4.1.1 The root cause

Before the persistent-backup layer, the installer (`customize.sh`) used a path-comparison check to detect upgrades:

```sh
if [ -d "$_EXISTING_MODULE" ] && [ "$_EXISTING_MODULE" != "$MODPATH" ]; then
    UPGRADE_DETECTED=1
fi
```

On an **in-place upgrade** (the most common case), `$_EXISTING_MODULE` equals `$MODPATH`, so the condition was always false. Result: the 5 user config files were silently overwritten by the new module's defaults, and the user lost hours of manual rule configuration.

The same bug affected:
- Folder renames (`DNSCrypt-Proxy-Webui`, etc.)
- KernelSU / APatch installs (different folder handling)
- Reinstalls after uninstall
- Corrupted in-place data

#### 4.1.2 The fix

The backup system replaces the "detect if this is an upgrade" approach with a **"search for user data everywhere"** philosophy:

> Never ask *"is this an upgrade?"*.
> Always ask *"where is the user data?"*.

This is implemented as 10 defensive layers (see §3.12), of which the backup system is a central piece.

#### 4.1.3 Why persistent, not tmp?

An earlier approach created backups in `/data/local/tmp/`:

```sh
BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
```

Two problems:
1. **`/data/local/tmp/` is cleared on reboot.** A user who installed the module and rebooted would lose their backup before they could use it.
2. **`/data/local/tmp/` is deleted on module uninstall.** A user who uninstalled the module then reinstalled it later would have no way to recover their settings.

The current system uses `/sdcard/dnscrypt-webui-backup/`, which:
- Survives reboots.
- Survives module uninstall.
- Survives factory reset of `/data` (but not of `/sdcard`).
- Is visible to the user from any file manager.
- Is accessible over USB (MTP).

### 4.2 The 5 Preserved Files

Only these five files are preserved. Everything else is either rebuilt, re-downloaded, or regenerated.

| File | Purpose | Size (typical) |
|------|---------|:--------------:|
| `webui.conf` | WebUI + Dashboard ports, `BIND_ADDR`, `LOG_LEVEL` | ~500 B |
| `dnscrypt-proxy.toml` | DNSCrypt engine config + credentials | ~20 KB |
| `selected_profile.txt` | Active blocklist profile (`light`/`normal`/`pro`/`proplus`/`ultimate`) | ~5 B |
| `allowlist.txt` | User-defined allowlist | 0 B – 100 KB |
| `denylist.txt` | User-defined denylist | 0 B – 100 KB |

#### 4.2.1 What is NOT preserved (and why)

| File | Reason |
|------|--------|
| `blocklist.txt` | Derived from `blocklist.raw` + user rules; rebuilt on every profile update |
| `blocklist.raw` | Downloaded from the internet; re-fetched |
| `public-resolvers.md` | Cache of dnscrypt-proxy's server list; regenerated |
| `blocked-ips.txt` | Static defaults; regenerated |
| `run/` | Runtime state only (PIDs, status, progress) |
| Binaries (`dnscrypt-proxy`, `dnscrypt-webui`) | Shipped fresh with each release |
| Log files | Rotated; not user data |
| **Companion APK** (`web/app-debug.apk`) | Build artifact of the module ZIP; not user data. Mirrored to `apk/` — see §4.3.1 |
| **`install_app.sh`** | Staged at module root by `customize.sh §[12]`; deleted with the module. Not user data |
| **`lib/*.sh`** | Staged at module root by `customize.sh §[12]`; deleted with the module. Not user data (v1.6.0) |

#### 4.2.2 Typical snapshot size

| Content | Size |
|---------|:----:|
| Empty allowlist + denylist | ~25 KB |
| Moderate rules (~200 lines each) | ~30 KB |
| Heavy rules (~5,000 lines each) | ~120 KB |

With the 21-snapshot cap, total backup storage is at most ~2.5 MB (plus the ~3 MB APK mirror — see §4.6.4).

### 4.3 Directory Layout

#### 4.3.1 Full tree

```text
/sdcard/dnscrypt-webui-backup/
├── current/                                          ← live snapshot (always latest)
│   ├── webui.conf
│   ├── dnscrypt-proxy.toml
│   ├── selected_profile.txt
│   ├── allowlist.txt
│   ├── denylist.txt
│   └── .manifest.json
│
├── 20261112-095826-v1.6.0-12345/                     ← install snapshot (customize.sh)
│   ├── webui.conf
│   ├── ...
│   └── .manifest.json
│
├── 20261112-140000-auto-12345/                       ← periodic snapshot (service.sh)
│   └── ...
│
├── 20261112-150000-manual-12345/                     ← manual snapshot (action.sh)
│   └── ...
│
├── 20261112-152000-manual-12345-a1b2/                ← pre-critical snapshot (main.go)
│   └── ...
│
├── txn-20261112-160000-12345/                        ← in-flight transaction
│   ├── .state                                        ← "START" | "COMMIT" | "ROLLBACK"
│   ├── .pid                                          ← installer PID
│   └── <copied user files>
│
├── orphan-txn-20261111-120000-11111/                 ← preserved unfinished transaction
│   └── ...                                           ← (renamed during uninstall)
│
├── apk/                                              ← companion APK mirror (v1.5.0+)
│   ├── app-debug.apk
│   └── app-debug.apk.sha256
│
├── .last_stable                                      ← pointer to last known-good snapshot
├── .last_auto_backup                                 ← marker for periodic backup (mtime)
├── .upgrade_history.json                             ← full upgrade log
├── .upgrade_history.txt                              ← text fallback (no jq)
├── .pending_notification                             ← read by main.go at startup
└── README.md                                         ← user-facing guide
```

#### 4.3.2 Directory name conventions

**Every snapshot directory ends with a `-<pid>` suffix.** This was added to prevent second-level timestamp collisions when two processes start a backup in the same wall-clock second. The `main.go` variant adds an additional `-<rand4>` (4 random hex chars).

| Prefix / pattern | Created by | Purpose |
|------------------|-----------|---------|
| `current/` | `customize.sh`, `lib/backup.sh` | Live snapshot — always up-to-date |
| `<timestamp>-<version>-<pid>/` | `customize.sh` at install | Historical snapshot, tagged with module version |
| `<timestamp>-auto-<pid>/` | `lib/backup.sh` on periodic trigger | Historical snapshot from `service.sh` |
| `<timestamp>-manual-<pid>/` | `action.sh --backup`, `lib/backup.sh` | Historical snapshot from a manual user action |
| `<timestamp>-manual-<pid>-<rand4>/` | `main.go:createAutoBackup` | Pre-critical snapshot from a destructive operation |
| `txn-<timestamp>-<pid>/` | `customize.sh` at transaction begin | In-flight upgrade transaction |
| `orphan-txn-<timestamp>-<pid>/` | `uninstall.sh` (rename) | Preserved unfinished transaction |
| **`apk/`** | `customize.sh §[27]` | Companion APK mirror — **not** a snapshot (see §4.6.3) |

**Timestamp format**: `YYYYMMDD-HHMMSS` (local device time).

**Detection key (SNAP-MANIFEST)**: A directory is treated as a snapshot **iff** it contains a `.manifest.json` file.

**Ordering key (SNAP-MTIME / ROT-MTIME)**: The authoritative ordering key is **mtime** (numeric, descending), not the directory name.

**`apk/` exclusion**: the `apk/` subfolder is not a snapshot. It has no `.manifest.json` (so SNAP-MANIFEST excludes it), and every rotation and listing implementation also skips it by name via a `case` statement (two independent protections — see §4.6.3).

#### 4.3.3 The `current/` directory

`current/` is a **live mirror** of the most recent successful snapshot. It is updated (via `rm -rf` + `mkdir` + copy) on every successful install, auto-backup, manual backup, or pre-critical backup.

`current/` is the **second-priority recovery source** in Layer 7 (after `.last_stable`, before in-place data).

#### 4.3.4 Language preference (not preserved)

The WebUI's language preference (`localStorage['dnscrypt-lang']`) is **not** part of the backup. It is:
- Client-side only — never transmitted to the server.
- Stored per-browser — different on each device that opens the WebUI.
- Not in the backup directory — the backup contains only the 5 server-side config files.

### 4.4 Backup Triggers

There are **four** triggers. Each writes a different directory-name suffix to make the source identifiable.

#### 4.4.1 Install / Upgrade (Layer 2)

**Trigger**: `customize.sh` runs during a module install or upgrade.

**When**: Before extraction, after the source is identified by Layer 1 (multi-source detection).

**Target directory**: `<timestamp>-<version>-<pid>/`

| Scenario | Backup created? |
|----------|:---------------:|
| Fresh install (no source found) | No |
| In-place upgrade (source found) | Yes |
| Rename-based recovery | Yes |
| Reinstall after uninstall | Yes (from `/sdcard/`) |

**Code reference**: `customize.sh §[24]`.

#### 4.4.2 Periodic Auto-Backup (Layer 9)

**Trigger**: `service.sh` runs `auto_backup_if_needed()` at each boot.

**When**: If the last auto-backup is older than **24 hours** (86400 s).

**Target directory**: `<timestamp>-auto-<pid>/`

**Marker file**: `.last_auto_backup` (empty file; its mtime is read via `stat -c %Y` with a BSD `stat -f %m` fallback).

**Code reference**: `lib/backup.sh` `auto_backup_if_needed`.

#### 4.4.3 Pre-Critical Backup (Layer 9)

**Trigger**: `main.go` calls `createAutoBackup(reason)` before a destructive operation.

**When**: Immediately before any of these **five** operations:

| Operation | Reason string | Endpoint |
|-----------|---------------|----------|
| Profile change | `pre-profile-change` | `POST /api/update_profile` |
| Allowlist save | `pre-allowlist-save` | `POST /api/save_allowlist` |
| Denylist save | `pre-denylist-save` | `POST /api/save_denylist` |
| Combined rules save | `pre-custom-rules-save` | `POST /api/save_custom_rules` |
| Append denylist | `pre-denylist-save` (via `saveDenylist`) | `POST /api/append_denylist` |

**Reason-string note**: `append_denylist` does not call `createAutoBackup` directly. It delegates to `saveDenylist`, which triggers the backup with the reason `pre-denylist-save`.

**Target directory**: `<timestamp>-manual-<pid>-<rand4>/` (the suffix is `-manual` because these are triggered by user actions — the "pre-critical" nature is recorded only in the log line, not in the directory name).

**Serialization**: `main.go` holds a `sync.Mutex` (`backupMu`) for the entire duration of the shell invocation (bounded by `AUTO_BACKUP_TIMEOUT = 15 s`). This prevents two rapid user actions from triggering overlapping backups on the same source directory.

**Best-effort**: if the backup fails, a warning is logged but the destructive operation proceeds. The backup must **never** block the user's intent.

**Code reference**: `main.go §[48]` `createAutoBackup`.

#### 4.4.4 Manual Backup (CLI)

**Trigger**: user runs `action.sh --backup`.

**When**: anytime.

**Target directory**: `<timestamp>-manual-<pid>/`

**Behavior**: backs up the 5 user config files, writes `.manifest.json`, rotates old snapshots (keep 21 using ROT-* semantics), and prints the current backup state.

**Code reference**: `action.sh §[7]`.

#### 4.4.5 Trigger summary

| Trigger | Automatic? | Suffix | Frequency |
|---------|:----------:|--------|-----------|
| Install / Upgrade | Yes | `<version>-<pid>` | Per install |
| Periodic | Yes | `auto-<pid>` | Max 1 per 24 h |
| Pre-critical (`main.go`) | Yes | `manual-<pid>-<rand4>` | Per destructive op |
| Manual (`action.sh`) | No | `manual-<pid>` | User-initiated |

### 4.5 File Formats

#### 4.5.1 `.manifest.json` (per snapshot)

Every snapshot directory contains a `.manifest.json` file:

```json
{
  "version": "v1.6.0",
  "timestamp": "20261112-095826",
  "source": "/data/adb/modules/dnscrypt-proxy-webui/proxy",
  "root_solution": "magisk",
  "files_count": 5,
  "files": [
    { "name": "webui.conf",            "sha256": "a1b2c3d4e5f6..." },
    { "name": "dnscrypt-proxy.toml",   "sha256": "f6e5d4c3b2a1..." },
    { "name": "selected_profile.txt",  "sha256": "1234567890ab..." },
    { "name": "allowlist.txt",         "sha256": "abcdef123456..." },
    { "name": "denylist.txt",          "sha256": "654321fedcba..." }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Module version at the time of the snapshot, **or** `"unknown"` for runtime snapshots |
| `timestamp` | string | `YYYYMMDD-HHMMSS` |
| `source` | string | Absolute path of the source directory |
| `root_solution` | string | `magisk` / `kernelsu` / `apatch` / `unknown` |
| `files_count` | number | Number of files successfully copied (0–5) |
| `files[].name` | string | File name (no path) |
| `files[].sha256` | string | SHA256 hash, or empty if `sha256sum` is unavailable |

**`version` field accuracy**:

| Creator | `version` value | `root_solution` value |
|---|---|---|
| `customize.sh` (install / upgrade) | Actual module version (e.g. `v1.6.0`) | Detected at install time |
| `main.go:createAutoBackup` | `"unknown"` | `"unknown"` |
| `action.sh --backup` (via `lib/backup.sh:backup_user_files`) | `"unknown"` | `"unknown"` |
| `service.sh:auto_backup_if_needed` | `"unknown"` | `"unknown"` |

**Consumer note**: tools that read `.manifest.json` (e.g. `verify_backup_integrity`) must treat `version` as advisory. The integrity check is based on per-file `sha256` hashes, not on `version`.

#### 4.5.2 `.last_stable` (single line)

Contains the **directory name** (not path) of the last known-good snapshot:

```text
20261112-095826-v1.6.0-12345
```

**Updated when**: a snapshot is created by `customize.sh` and verification passes.

**Read by**:
- `customize.sh §[8]` (recovery mode).
- `main.go:buildBackupInfo()` (exposed as `runtime_info.backups.last_stable`).
- `status.sh --json` (exposed as `.backups.last_stable`).
- `status.sh --diagnose` (informational display).
- `lib/backup.sh:rotate_backups()` (ROT-PROTECT): the `.last_stable` target is **never pruned**, even when it would otherwise fall outside the 21-newest window.

**Not updated by runtime backups** (`main.go`, `service.sh`, `action.sh`). Only install-time snapshots update `.last_stable`. Deliberate: the pointer must reference a version-tagged snapshot, not a runtime snapshot whose `version` field is `"unknown"`.

#### 4.5.3 `.last_auto_backup` (empty marker file)

An empty file whose **mtime** is used as the "last auto-backup timestamp".

**Created/updated by**: `lib/backup.sh:auto_backup_if_needed`.

**Read by**:

```sh
stat -c %Y "$PERSISTENT_BACKUP/.last_auto_backup" \
  || stat -f %m "$PERSISTENT_BACKUP/.last_auto_backup" \
  || echo 0
```

If the marker is missing, the age is treated as 0 → backup runs immediately.

#### 4.5.4 `.upgrade_history.json` (append-only log)

A JSON file that records every install / upgrade:

```json
{
  "upgrades": [
    {
      "from": "v1.5.0",
      "to": "v1.6.0",
      "date": "2026-11-12T10:30:00Z",
      "source": "/data/adb/modules/dnscrypt-proxy-webui/proxy",
      "root": "magisk",
      "files": 5
    }
  ]
}
```

**Written by**: `customize.sh:log_upgrade()` when `jq` is available.

**Fallback (no `jq`)**: a plain-text `.upgrade_history.txt`:

```text
2026-11-12T10:30:00Z | v1.5.0 → v1.6.0 | source=/data/adb/modules/dnscrypt-proxy-webui/proxy | files=5
```

**Rotation**: the history file is **not rotated** — it grows slowly (~200 bytes per upgrade).

#### 4.5.5 `.pending_notification` (transient)

A single-line file written by `customize.sh` after a successful restore during an upgrade.

**Read by**: `main.go:checkPendingNotifications()` at startup.

**Action**: content is logged, then the file is deleted by `main.go` (only). `service.sh` also reads the file (for the boot log) but does **not** delete it — deletion is centralized in `main.go` to avoid a race.

#### 4.5.6 `README.md` (user guide)

A static user-facing guide generated on first install. It explains what is backed up, the directory structure, how rotation works, how to restore manually, and how to trigger recovery mode.

**Never auto-updated** after creation — the user can edit it freely.

### 4.6 Retention and Rotation

#### 4.6.1 Policy

Rotation caps the number of snapshots at **21**. The implementation is **count-based**: it keeps the 21 newest snapshots, sorted by **mtime descending** (ROT-MTIME), with two additional protected targets that are never pruned (ROT-PROTECT):
- The `.last_stable` target (recovery pointer).
- The newest install snapshot (name matching `-v<digit>`).

There are no daily / weekly / monthly tiers today.

**Planned enhancement (v1.7.0)**: a tiered policy is under consideration (Daily × 5, Weekly × 4, Monthly × 12). Tracked in `docs/ROADMAP.md` §2.4.

#### 4.6.2 When rotation runs

Rotation runs **after** a successful backup:
- `service.sh:rotate_backups 21` (after periodic auto-backup).
- `action.sh --backup` (after manual backup).
- `main.go:createAutoBackup` (after a pre-critical backup; the rotation is invoked in the same shell call as the backup itself).
- `customize.sh §[24]` (after an install-time snapshot — the installer has its own mirror of `rotate_backups`).

#### 4.6.3 What is never rotated

| Item | Reason |
|------|--------|
| `current/` | Always needed for recovery |
| `txn-*/` | In-flight transactions |
| `orphan-txn-*/` | Preserved unfinished transactions |
| **`apk/`** | Companion APK mirror — two independent protections (see below) |
| `.last_stable` | Recovery pointer — **ROT-PROTECT target** |
| The newest install snapshot (`-v<digit>`) | **ROT-PROTECT target** — used by rollback and `.upgrade_history` |
| `.last_auto_backup` | Age marker |
| `.upgrade_history.json` / `.txt` | Audit trail |
| `README.md` | User guide |
| `.restore_snap.*` | Transient scratch from `restore_user_files` |

**The `apk/` protection is doubled**:
1. **Name skip** — every `rotate_backups` and `list_snapshots` implementation contains `apk` inside its `case` skip statement.
2. **Manifest absence** — the `apk/` subfolder has no `.manifest.json` (it is not a snapshot), so even if the `case` skip were removed, ROT-MANIFEST would still exclude it.

Either protection alone would be sufficient. Both are present so that a future refactor cannot accidentally prune the mirror.

#### 4.6.4 Storage footprint

| Scenario | Snapshot count | Total size |
|----------|:--------------:|:----------:|
| Fresh install, no history | 1 (`current` only) | ~25 KB |
| Typical user (5 snapshots) | 5 | ~150 KB |
| Heavy user (21 snapshots) | 21 | ~2.5 MB |
| With orphan transactions | +1–3 | +~100 KB |
| **With APK mirror** | **21** | **~2.5 MB + ~3 MB = ~5.5 MB** |

**Max theoretical footprint**: ~6 MB. Negligible on any modern Android device.

#### 4.6.5 Rotation ordering — mtime, not directory name

`rotate_backups` sorts snapshots by **mtime**, not by directory name.

**Why mtime, not directory name?**
- **Robust against clock drift**: if the system clock is set backwards between two snapshots, the directory-name order would no longer reflect the actual creation order. mtime (written by the filesystem itself) is monotonic under normal conditions.
- **Robust against manual renames**: renaming a snapshot directory does not change its position in the rotation order.
- **Robust against custom-named snapshots**: a snapshot created by a future tool with a different naming scheme is still correctly ordered.
- **Aligns with the API**: `main.go:buildBackupInfo()` uses the same mtime sort (SNAP-MTIME), so `runtime_info.backups.last_backup_name` and `rotate_backups`'s "newest" agree.

**Detection rule (ROT-MANIFEST)**:

A directory is a rotation candidate **iff**:
1. Its name is not `current`, `txn-*`, `orphan-txn-*`, `apk`, or `.restore_snap.*`.
2. It contains a `.manifest.json` file.

Directories without a manifest are **ignored** by rotation, even if their name matches the timestamp pattern.

**Protected targets (ROT-PROTECT)**:

Two additional targets are preserved on top of the 21-newest window:

| Target | How it is identified | Why it is protected |
|--------|----------------------|---------------------|
| `.last_stable` target | Content of `$PERSISTENT_BACKUP/.last_stable` | The recovery pointer; pruning it would break recovery mode |
| Newest install snapshot | Name matching `-v<digit>` | Used by rollback and by `.upgrade_history`; pruning it would break rollback |

**Shell command used by `lib/backup.sh:rotate_backups`**:

```sh
for _d in */; do
    _d="${_d%/}"
    [ -d "$_d" ] || continue
    case "$_d" in
        current|txn-*|orphan-txn-*|apk|.restore_snap.*) continue ;;
    esac
    [ -f "$_d/.manifest.json" ] || continue
    _mt=$(stat -c %Y "$_d" 2>/dev/null) \
        || _mt=$(stat -f %m "$_d" 2>/dev/null) \
        || _mt=0
    printf '%s %s\n' "$_mt" "$_d"
done | sort -rn -k1,1
```

The `sort -rn -k1,1` sorts numerically on the first field (mtime), descending. The second field (directory name) is used only as a stable tiebreaker when two snapshots share the same mtime.

### 4.7 Manual Operations

#### 4.7.1 Create a manual backup

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Expected output** (matches `action.sh §[7]`):

```text
╔════════════════════════════════════════════════════════╗
║  💾 DNSCrypt – Manual Backup                           ║
╚════════════════════════════════════════════════════════╝

  Source: /data/adb/modules/dnscrypt-proxy-webui/proxy
  Target: /sdcard/dnscrypt-webui-backup

  ✅ Backup created: /sdcard/dnscrypt-webui-backup/20261112-150000-manual-12345 (5 file(s))

  Current backup state:
    7 snapshot(s), latest 0s ago
```

If the backup fails (0 files copied), the script exits with code 3.

#### 4.7.2 List snapshots

```bash
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; list_snapshots"
```

Or via the CLI:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | grep -A 20 "Backups"
```

#### 4.7.3 Inspect a snapshot

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/20261112-095826-v1.6.0-12345/"
su -c "cat /sdcard/dnscrypt-webui-backup/20261112-095826-v1.6.0-12345/.manifest.json"
```

#### 4.7.4 Restore manually

```bash
# 1. Identify the desired snapshot
SNAP="20261112-095826-v1.6.0-12345"

# 2. Copy the 5 files back
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/webui.conf            /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/dnscrypt-proxy.toml   /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/selected_profile.txt  /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/allowlist.txt         /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp /sdcard/dnscrypt-webui-backup/$SNAP/denylist.txt          /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 3. Fix SELinux contexts
su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"

# 4. Restart the service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

#### 4.7.5 Trigger recovery mode

If the module is unbootable or user data is corrupted:

```bash
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"
```

On next boot, `customize.sh` restores the last known-good snapshot and continues with the normal install flow. See `docs/GUIDE.md` §8 for the full procedure.

**Snapshot-and-reapply strategy**:

An earlier draft of the recovery mode had a bug where the ZIP extraction step (`customize.sh §[12]`) overwrote `webui.conf` and `dnscrypt-proxy.toml` **after** the recovery restore (`§[8]`), and the subsequent restore step (`§[14]`) was skipped in recovery mode — so 2 of the 5 restored files were silently lost.

The current implementation uses snapshot-and-reapply that keeps the extraction logic of `§[12]` untouched:

| Phase | Section | What happens |
|-------|---------|--------------|
| **A** | `§[8]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **AND** copy each one to `$MODPATH/.recovery_snapshot/` |
| **B** | `§[12]` | Extract the ZIP normally — overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults |
| **C** | `§[13]` | Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/` |
| **D** | `§[14]` | Skipped when `RECOVERY_MODE=1` — already handled by A + C |

**Partial re-application**: if `§[13]` re-applies fewer files than were snapshotted, the snapshot directory is **preserved** at `$MODPATH/.recovery_snapshot/` so the user can recover the remaining files manually.

See `SECURITY.md` §5.32.1 for the security analysis.

#### 4.7.6 Delete a snapshot

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup/20261112-140000-v1.6.0-12345"
```

**Note**: deleting the snapshot that `.last_stable` points to will cause recovery mode to fall back to `current/` (or to the in-place data). If you want to be safe, delete non-`.last_stable` snapshots only.

#### 4.7.7 Delete everything

**⚠️ Destructive**: this removes all backups. The user data currently in the module's `proxy/` directory is **not** affected.

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

The next boot will recreate the directory (empty).

#### 4.7.8 Copy backups off-device

```bash
adb shell su -c "tar czf /sdcard/dnscrypt-backup-$(date +%Y%m%d).tar.gz /sdcard/dnscrypt-webui-backup"
adb pull /sdcard/dnscrypt-backup-20261112.tar.gz
```

#### 4.7.9 Access the companion APK mirror

The `apk/` subfolder (see §4.3.1 and §4.10.7) holds a copy of the companion Android app, mirrored there by `customize.sh §[27]` at install time.

**Locate the mirror**:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/apk/"
# Expected:
#   app-debug.apk
#   app-debug.apk.sha256
```

**Verify integrity**:

```bash
su -c "cd /sdcard/dnscrypt-webui-backup/apk && sha256sum -c app-debug.apk.sha256"
# Expected: app-debug.apk: OK
```

**Install from the mirror**:

```bash
su -c "pm install -r /sdcard/dnscrypt-webui-backup/apk/app-debug.apk"
```

#### 4.7.10 What about the language preference?

The WebUI's language preference (`localStorage['dnscrypt-lang']`) is **not** part of any backup. See §4.3.4.

### 4.8 Programmatic Access

#### 4.8.1 Via `runtime_info` (recommended)

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

**Response (7 fields)**:

```json
{
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-11-12 15:00:00",
  "last_backup_name": "20261112-150000-manual-12345",
  "last_stable": "20261112-095826-v1.6.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `available` | int | Number of snapshots. **Detection rule (SNAP-MANIFEST)**: a directory counts as a snapshot **iff** it contains a `.manifest.json` file. Excludes `current/`, `txn-*`, `orphan-txn-*`, and `apk/` by name. |
| `in_flight_txn` | int | Number of `txn-*` directories (install in progress or interrupted) |
| `orphan_txn` | int | Number of `orphan-txn-*` directories (preserved interrupted installs) |
| `last_backup` | string \| null | Modification time of the newest snapshot |
| `last_backup_name` | string \| null | Directory name of the newest snapshot. **Sort key (SNAP-MTIME)**: mtime, descending. |
| `last_stable` | string \| null | Content of the `.last_stable` pointer file, or null if not set |
| `path` | string | Absolute path of the backup directory |

**Displayed in**: WebUI and Dashboard System Info panels.

**Read-only**: `runtime_info` does not create or modify backups.

**Consumer pattern**: if `in_flight_txn > 0` or `orphan_txn > 0`, the backup layer needs attention — see `docs/GUIDE.md` §7 (Troubleshooting).

#### 4.8.2 Via `status.sh --json`

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq '.backups'
```

**Response (same 7 fields, plus 2 diagnostic-only)**:

```json
{
  "status": "ok",
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-11-12 15:00:00",
  "last_backup_name": "20261112-150000-manual-12345",
  "last_backup_age_seconds": 3600,
  "last_stable": "20261112-095826-v1.6.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

The two extra fields:
- `status` — `"ok"` / `"empty"` / `"missing"`.
- `last_backup_age_seconds` — numeric age (for scripting).

**Consistency guarantee**: the two schemas match on the seven shared fields. If they ever diverge, it indicates a `main.go` / `status.sh` version mismatch — restart the WebUI and re-run the commands.

`status.sh --json` uses the same SNAP-MANIFEST detection and SNAP-MTIME sort as `main.go` (via the shared `list_snapshots` helper). So `available` and `last_backup_name` agree between the API and the shell tool for every input, including custom-named snapshots.

#### 4.8.3 Via `status.sh --check` (one-liner)

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
```

**Output example**:

```text
v1.6.0 | DNS=UP | WEBUI=UP | PROFILE=pro | MEM=120 MB (pro) | ENTRIES=250000 | BACKUP=7snap/1h ago | RUNDIR=/data/adb/modules/dnscrypt-proxy-webui/proxy/run
```

The `BACKUP=` field format is `<count>snap/<age>`.

#### 4.8.4 Via `status.sh --diagnose`

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

Produces a full human-readable report including:
- System + module info.
- The 5 user data files with size + mtime.
- Backup listing (sorted by mtime descending via the shared `list_snapshots` helper).
- In-flight + orphan transaction listings.
- Recovery mode state.
- Pending notification content.
- Health checks with a final check summary.

### 4.9 Verification

#### 4.9.1 Integrity checks — Layer 3

Layer 3 (integrity verification) runs on every snapshot before use. The checks are:
1. **Non-empty**: file exists and has size > 0.
2. **Not oversized**: file size < 10 MB (rejects corrupted uploads).
3. **SHA256 (advisory)**: `.manifest.json` records each file's hash. A mismatch is logged as a warning but does **not** block a restore. Rationale: the snapshot was just created from the same source; a mismatch would indicate a filesystem issue, but refusing to restore would be worse than restoring with a warning.

**`verify_backup_integrity()`** performs a real SHA256 comparison (not just size). The implementation uses a 3-tier extraction to read the expected hash from `.manifest.json`:
1. `jq` (most robust, handles multi-line JSON).
2. `awk` (fallback, handles multi-line JSON with regex escaping).
3. `grep` + `sed` (last resort, fragile with escaped chars).

If none of the three tiers extracts a hash (e.g. `sha256sum` is unavailable, or the manifest is malformed), the check is **skipped** for that file rather than failing.

#### 4.9.2 Running verification manually

```bash
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; \
       SNAP=\$(list_snapshots 1); \
       echo \"Verifying: \$SNAP\"; \
       for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do \
         [ -s \"/sdcard/dnscrypt-webui-backup/\$SNAP/\$f\" ] \
           && echo \"  OK \$f\" \
           || echo \"  MISSING \$f\"; \
       done"
```

### 4.10 Security Model

#### 4.10.1 Permissions

| Path | Mode | Owner | Rationale |
|------|:----:|:-----:|-----------|
| `/sdcard/dnscrypt-webui-backup/` | `0700` | root | Owner-only |
| Snapshot directories | `0700` | root | Owner-only |
| Snapshot files | `0600` | root | Owner-only |
| `.manifest.json` | `0600` | root | Owner-only |
| `.last_stable` | `0600` | root | Owner-only |
| `.upgrade_history.json` | `0600` | root | Owner-only |
| `README.md` | `0644` | root | Readable by user |
| **`apk/` subfolder** | **`0755`** | **root** | Readable — companion APK is a public asset |
| **`apk/app-debug.apk`** | **`0644`** | **root** | Readable — same reason |
| **`apk/app-debug.apk.sha256`** | **`0644`** | **root** | Readable — same reason |

**Note**: on Android, `/sdcard/` is typically a FUSE mount. Permission semantics differ from ext4. The `0700`/`0600` modes are enforced by the underlying storage layer where possible; the primary protection is that `/sdcard/` is only accessible to apps with `READ_EXTERNAL_STORAGE` or root.

**`apk/` exception**: the mirror folder uses `0755` (not `0700`) because the companion APK is a public asset intended to be readable by non-root file managers. This matches the behavior of `GET /app-debug.apk`, which serves the same file without authentication.

#### 4.10.2 What backups contain

| Data | Included? | Sensitivity |
|------|:---------:|-------------|
| WebUI/Dashboard ports | Yes | Low |
| `BIND_ADDR` | Yes | Low |
| `LOG_LEVEL` | Yes | Low |
| DNSCrypt credentials (in TOML) | Yes | **High** |
| `selected_profile.txt` | Yes | Low |
| User rules (allowlist/denylist) | Yes | Medium |
| DNSCrypt server list cache | No | N/A |
| Binaries | No | N/A |
| Log files | No | N/A |
| **Companion APK** (`web/app-debug.apk`) | **No** (but mirrored to `apk/` — see §4.10.7) | N/A |
| **WebUI language preference** | **No** | N/A (browser-side only) |

**Note**: the DNSCrypt credentials (username/password for the internal monitoring_ui) are included because they live in `dnscrypt-proxy.toml → [monitoring_ui]`. The snapshot directory is `0700`, so only root can read them.

#### 4.10.3 SELinux contexts

Every copied file receives its original SELinux context:
- **Preferred**: `restorecon` (reads `file_contexts` and applies the correct context).
- **Fallback**: `chcon u:object_r:magisk_file:s0` (hardcoded context used by Magisk modules).

If neither tool is available, the copy succeeds without context restoration. This is rare on Android (both tools exist in `/system/bin/`).

#### 4.10.4 Integrity guarantees

| Threat | Mitigation |
|--------|-----------|
| Bit rot in a snapshot | SHA256 in `.manifest.json` (advisory) |
| Empty/truncated file | Non-empty + size checks before restore |
| Malicious file substitution | Not mitigated (root-only directory) |
| Unauthorized read | `0700`/`0600` permissions |
| Directory deletion | `current/` and `.last_stable` ensure at least one recovery path |
| Pruning the recovery target | **ROT-PROTECT** — `.last_stable` and the newest install snapshot are never pruned |
| Orphaned manifest-less snapshots | **ROT-MANIFEST** — a snapshot requires a manifest to be a rotation candidate |
| **APK mirror accidentally pruned** | **Two independent protections** — name skip in `case` + manifest absence (see §4.6.3) |

#### 4.10.5 Threat model summary

The backup system assumes:
- The device is rooted.
- `/sdcard/` is mounted and writable by root.
- The backup directory is **not** protected from a malicious root app.

**`backupMu` — serialization guarantee**: Two concurrent calls to `createAutoBackup` (e.g. from two rapid user actions) could each operate on the same source directory. Without serialization, this would result in two concurrent shell invocations writing to the same `.manifest.json` and to the same `.tmp` files, with the possibility of a corrupted snapshot.

`main.go` holds a single `sync.Mutex` (`backupMu`) for the entire duration of the shell invocation (`runShellWithTimeout(..., AUTO_BACKUP_TIMEOUT = 15 s)`). The second caller blocks until the first finishes.

**What `backupMu` does NOT protect against**:
- A user manually running `action.sh --backup` while the WebUI is also triggering a pre-critical backup. `action.sh` is a shell script; it does not coordinate with `main.go`'s mutex. In practice this is safe because the shell script uses `<pid>`-suffixed directory names (see §4.3.2) and atomic writes for the manifest.

**What ROT-PROTECT does NOT protect against**:
- A user manually deleting the `.last_stable` target directory. ROT-PROTECT only prevents `rotate_backups` from pruning it — it does not prevent explicit `rm -rf`.
- A `.last_stable` file whose content names a directory that no longer exists. In that case, recovery mode falls back to `current/`, then to in-place data. See §4.7.5.

#### 4.10.6 Language toggle — security considerations

The WebUI's bilingual feature (English default + Arabic toggle) is a **client-side only** concern. From a security standpoint:
- **No server state**: the language preference is stored in `localStorage['dnscrypt-lang']` and never transmitted to the API. There is no session-side, no user-side, and no server-side state tied to the language.
- **No new network requests**: the toggle does not trigger any fetch/XHR/SSE activity. It only manipulates the DOM.
- **No SW cache pollution**: the Service Worker caches the HTML once. Both `translations.en` and `translations.ar` objects are inline in the same file.
- **No XSS regression**: all translated strings pass through `textContent` / `escapeHtml()` exactly like their English counterparts. The Arabic strings are static constants in the HTML source — they are not user-controlled.

#### 4.10.7 Companion APK mirror — security considerations

The `apk/` subfolder is a **best-effort** copy of the companion APK and its `.sha256` sidecar. From a security standpoint:
- **Public asset, not secret**: the APK is the same file served by `GET /app-debug.apk` (no auth required). It is intended to be readable.
- **Not a snapshot**: the folder has no `.manifest.json` and is skipped by name in every rotation and listing implementation (see §4.6.3). It cannot displace real snapshots in the rotation order.
- **Not one of the 5 preserved files**: the mirror is created by `customize.sh §[27]` at install time, not by the `backup_user_files` path. It is orthogonal to the config backup.
- **Integrity verification**: the `.sha256` sidecar (written by `fetch_app_apk.sh` and staged by `release.yml`) is copied alongside the APK. `install_app.sh` verifies the hash before attempting any install strategy.
- **Android signature verification**: the OS verifies the APK's package signature at install time, regardless of where the APK came from. The mirror cannot install a different APK than the one it holds.

#### 4.10.8 Rotation hardening

The rotation rewrite (ROT-MANIFEST + ROT-MTIME + ROT-PROTECT) tightens the backup layer in two ways:
1. **Detection requires a manifest (ROT-MANIFEST)** — a directory named like a snapshot but lacking `.manifest.json` is not counted and not rotated. This prevents an attacker (or a confused user) from injecting a fake snapshot directory that would displace real snapshots in the rotation order.
2. **Protected targets (ROT-PROTECT)** — the `.last_stable` pointer and the newest install snapshot cannot be silently pruned. This guarantees that the recovery path remains intact even under aggressive rotation.

---

## 5. Compatibility Matrix

### 5.1 Overview

#### 5.1.1 Status Symbols

| Symbol | Meaning |
|:-----:|--------|
| ✅ | **Supported and tested** |
| 🟢 | **Supported** (not tested on every device) |
| ⚠️ | **Works with caveats** (needs configuration) |
| 🔶 | **Beta** (needs more testing) |
| ❌ | **Not supported** |

#### 5.1.2 Minimum Requirements

| Requirement | Minimum | Recommended |
|---------|:-----------:|:---------:|
| **Android** | 5.0 (API 21) | 10+ (API 29) |
| **Root** | Magisk 20.4 | Magisk 26+ |
| **Kernel** | 3.10 | 4.14+ |
| **RAM** | 1 GB | 2 GB+ |
| **Storage** | 20 MB | 30 MB+ |
| **Storage (`/sdcard/`)** | **6 MB** | **50 MB+** (for backups + APK mirror) |
| **Architecture** | arm64 / arm / x86_64 / x86 | arm64 |

**`/sdcard/` storage breakdown**:
- Persistent backup directory: each snapshot uses ~30–100 KB; the rotation cap (21 snapshots) bounds the total to ~2.5 MB.
- Companion APK mirror (`apk/`): ~3 MB (best-effort, one-time).
- Metadata (`manifest.json`, `.upgrade_history`, `current/`, `README.md`): < 150 KB.
- **Total steady-state `/sdcard/` usage**: **~5.6 MB**.

### 5.2 Android Versions

| Version | API | Status | Notes |
|---------|:---:|:------:|-------|
| **15** | 35 | 🟢 | Needs testing |
| **14** | 34 | ✅ | Tested |
| **13** | 33 | ✅ | Tested |
| **12** | 31-32 | ✅ | Tested |
| **11** | 30 | ✅ | Tested |
| **10** | 29 | ✅ | Tested (backup + install fully supported) |
| **9** | 28 | 🟢 | Works |
| **8.1** | 27 | 🟢 | Works (strategy 5 available) |
| **8.0** | 26 | 🟢 | Works (strategy 5 available) |
| **7.1** | 25 | ⚠️ | May need iptables adjustments; **strategies 1–4 only** |
| **7.0** | 24 | ⚠️ | Same |
| **6.0** | 23 | ⚠️ | Doze mode issues; **strategies 1–4 only** |
| **5.1** | 22 | ⚠️ | Limited (backup dir OK, but SELinux tools may be missing); **strategies 1–4 only** |
| **5.0** | 21 | ⚠️ | Minimum supported; **strategies 1–4 only** |

#### 5.2.1 Android-specific Notes

**Android 10+**: Full support. Private DNS integration. SELinux permissive with no issues. Dashboard works. Dynamic memory limit applies. Backup fully supported. Bilingual WebUI works in all modern browsers. Companion app installs smoothly (all 5 strategies). SELinux staging + Play Protect trap both work.

**Android 8–9**: Works. Battery optimization may stop the Watchdog. Add to exceptions. Backup works — same FUSE mount. Companion app install works (all 5 strategies).

**Android 6–7**: Doze mode stops services. Disable battery optimization. iptables may differ. `getSystemShell()` works correctly. Backup works but `restorecon` may not be available (falls back to `chcon`). Install cascade uses strategies 1–4 only (strategy 5 requires Android 8.0+).

**Android 5**: Requires kernel 3.10+. May not support nftables. `pgrep -x` may not work properly — fallback in code. Backup works but `sha256sum` may be missing (advisory mode). Install cascade uses strategies 1–4 only.

#### 5.2.2 Dashboard Browser Compatibility

| Browser | SVG Icons | PNG Icons | JSON Metrics | Login POST | Profile/Memory | Backups Display | Bilingual (EN+AR) | Install Modal |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Chrome 90+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Firefox 92+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Safari 15+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Samsung Internet (recent) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IE 11 (Windows desktop only)** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### 5.2.3 System Info Panel Fields

The System Info panel in both `index.html` and `dashboard.html` displays fields populated from `runtime_info`:

| Row | Field | Type |
|---|---|---|
| **Profile** | `profile_key` | string |
| **Memory limit** | `memory_limit_mb` | int |
| **Backups** | `backups.available` | int |
| **Latest Backup** | `backups.last_backup_name` | string \| null |
| **Last Stable** | `backups.last_stable` | string \| null |
| **In-flight Txn** | `backups.in_flight_txn` | int |
| **Orphan Txn** | `backups.orphan_txn` | int |
| **Backup Path** | `backups.path` | string |
| **Companion app button** | `companionState.installed` | bool |

#### 5.2.4 Backup Compatibility by Android Version

| Android | `/sdcard/` mount | `sha256sum` | `restorecon` | Backup support |
|---|:---:|:---:|:---:|:---:|
| **5.0 – 5.1** | FUSE (legacy) | ⚠️ may be missing | ⚠️ may be missing | 🟢 Partial (advisory checks skipped) |
| **6.0 – 7.1** | FUSE | ✅ | ⚠️ falls back to `chcon` | 🟢 Full |
| **8.0 – 9.0** | FUSE | ✅ | ✅ | ✅ Full |
| **10 – 13** | FUSE | ✅ | ✅ | ✅ Full |
| **14 – 15** | FUSE | ✅ | ✅ | ✅ Full |

#### 5.2.5 Platform Support

| Platform | `getSystemShell()` | `hasEndpoint()` | Dashboard JSON | `memoryLimitForProfile` | **backup helpers** | **install cascade** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Android | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux (CI) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) | ❌ (no `pm`) |
| macOS (dev) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) | ❌ (no `pm`) |
| Termux | ⚠️ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) | ❌ (no `pm`) |
| Windows (WSL2) | ✅ | ✅ | ✅ | ✅ | ⚠️ (no `/sdcard/`) | ❌ (no `pm`) |

#### 5.2.6 Companion Install Compatibility by Android Version (v1.5.0+)

| Android | Strategy 1<br>`pm install -r --user 0` | Strategy 2<br>`pm install -r -i com.android.shell` | Strategy 3<br>Session-based | Strategy 4<br>`magisk su` | Strategy 5<br>`cmd package install` |
|---|:---:|:---:|:---:|:---:|:---:|
| **5.0 – 5.1** | ✅ | ✅ | ✅ | ✅ (Magisk only) | ❌ (API 26+) |
| **6.0** | ✅ | ✅ | ✅ | ✅ (Magisk only) | ❌ (API 26+) |
| **7.0 – 7.1** | ✅ | ✅ | ✅ | ✅ (Magisk only) | ❌ (API 26+) |
| **8.0+** | ✅ | ✅ | ✅ | ✅ (Magisk only) | ✅ |

### 5.3 ROMs

| ROM | Status | Notes |
|-----|:------:|-------|
| **Stock Android** | ✅ | Any version |
| **LineageOS** | ✅ | All versions |
| **Pixel Experience** | ✅ | Tested |
| **Evolution X** | ✅ | Tested |
| **crDroid** | ✅ | Tested |
| **AOSP Extended** | ✅ | Tested |
| **MIUI (Xiaomi)** | ⚠️ | Needs MIUI optimization disabled; backup dir works |
| **OneUI (Samsung)** | ⚠️ | May stop the service automatically |
| **ColorOS (OPPO)** | ⚠️ | Aggressive battery killer |
| **OxygenOS (OnePlus)** | 🟢 | Works |
| **EMUI (Huawei)** | ⚠️ | May stop the service |
| **FuntouchOS (vivo)** | ⚠️ | Aggressive killing |
| **RealmeUI** | ⚠️ | Same |
| **Custom GSI** | 🟢 | Works |

#### 5.3.1 ROM-specific Configuration

**MIUI**:
```text
Settings → Apps → Manage apps → DNSCrypt
→ Autostart: ON
→ Battery saver: No restrictions
→ Other permissions: Start in background
```

**OneUI**:
```text
Settings → Device care → Battery → Background usage limits
→ Never sleeping apps → Add DNSCrypt
```

**ColorOS**:
```text
Settings → Battery → App battery management → DNSCrypt
→ Allow background activity
→ Allow auto-launch
```

#### 5.3.2 Setting Preservation — Evolution

**Legacy mechanism** (pre-v1.2.0): the installer preserved the 5 config files using a backup in `/data/local/tmp/dnscrypt-upgrade-backup-$$`. This was **deleted on reboot** and **lost on uninstall**.

**Current mechanism** (v1.2.0+): the 10 defensive layers replace the legacy mechanism. The 5 files are now preserved in `/sdcard/dnscrypt-webui-backup/`, which **survives reboot**, **uninstall**, and **factory reset of `/data`**.

#### 5.3.3 Bilingual WebUI on Different ROMs

The WebUI's language toggle works on **all ROMs** because it is a purely browser-side feature. However, the **browser shipped with the ROM** matters:

| ROM family | Default browser | Bilingual support |
|---|---|---|
| AOSP / LineageOS | AOSP Browser / Chrome | ✅ |
| MIUI | MIUI Browser (Chromium-based) | ✅ |
| OneUI | Samsung Internet | ✅ (recent versions) |
| ColorOS | Oppo Browser (Chromium-based) | ✅ |
| EMUI | Huawei Browser | ⚠️ (may need Chrome for full RTL) |
| Custom GSI | Chrome / Firefox | ✅ |

**Recommendation**: For best results with the Arabic (RTL) layout, use **Chrome 88+**, **Firefox 92+**, or a recent version of **Samsung Internet**.

#### 5.3.4 ROM-specific Install Cascade Notes (v1.5.0+)

| ROM family | Typical winning strategy | Pre-requisite |
|---|---|---|
| AOSP / LineageOS | 1 | None |
| Pixel Experience / Evolution X / crDroid | 1 | None |
| MIUI / HyperOS | 2 | "Install via USB" must be enabled in Developer options (otherwise every strategy fails with `INSTALL_FAILED_USER_RESTRICTED`) |
| OneUI (Samsung) | 1 | None |
| ColorOS (OPPO) | 1 or 3 | "Install from unknown sources" must be enabled for the calling app |
| FuntouchOS (vivo) | 1 or 3 | Same |
| EMUI (Huawei) | 1 or 3 | Same |
| OxygenOS / HydrogenOS (OnePlus) | 1 | None |
| Custom GSI | 1 | None |

**Common ROM-specific failures**:

| Error | ROM | Mitigation |
|---|---|---|
| `INSTALL_FAILED_USER_RESTRICTED` | MIUI / HyperOS | Enable: Settings → Developer options → Install via USB |
| `INSTALL_FAILED_VERIFICATION_FAILURE` | Any ROM with Play Protect | The v1.5.0+ trap disables Play Protect temporarily; a residual failure means the trap did not fire (check `install_app.sh` log) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Any ROM | Signature mismatch — uninstall the previous version manually |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | Any ROM | Installed version is newer — uninstall the current version manually |

### 5.4 Kernels

| Kernel | Version | Status |
|---|---|:---:|
| Linux 3.10 | 3.10 | ⚠️ |
| Linux 3.18 | 3.18 | ⚠️ |
| Linux 4.4 | 4.4 | 🟢 |
| Linux 4.9 | 4.9 | ✅ |
| Linux 4.14 | 4.14 | ✅ |
| Linux 4.19 | 4.19 | ✅ |
| Linux 5.4 | 5.4 | ✅ |
| Linux 5.10 | 5.10 | ✅ |
| Linux 5.15 | 5.15 | ✅ |
| Linux 6.1 | 6.1 | ✅ |
| Linux 6.6 | 6.6 | ✅ |

#### 5.4.1 Kernel Requirements

| Feature | Minimum | Status |
|---|---|---|
| iptables-nat | 3.10 | ✅ |
| nftables | 4.10 | ✅ |
| netns | 3.0 | ✅ |
| cgroup v2 | 4.5 | ✅ |
| `/bin/sh` | 4.x+ | ✅ (Linux dev) |
| `sync.Once` (Go runtime) | 4.4+ | ✅ |
| `sync.Mutex` (Go runtime) | 3.x+ | ✅ |
| `debug.SetMemoryLimit` | 3.x+ (Go runtime) | ✅ |
| `rename(2)` atomicity | 3.x+ | ✅ (transactions) |
| `sha256sum` (from coreutils) | Android 4.4+ | ✅ (backup) |
| `restorecon` / `chcon` | SELinux kernel | ✅ (Layer 6) |
| `stat -c %Y` / `stat -f %m` | Any | ✅ (ROT-MTIME) |
| **`pm install --user 0`** | **Android 5.0+** | ✅ |
| **`pm install-create/write/commit`** | **Android 5.0+** | ✅ |
| **`cmd package install`** | **Android 8.0+** | ⚠️ (skipped on older versions) |
| **`settings put global package_verifier_enable`** | **Android 4.2+** | ✅ |
| **`/data/local/tmp/` writable** (SELinux staging) | **All** | ✅ |

**Note**: `debug.SetMemoryLimit` was introduced in Go 1.19. Since the project uses Go 1.22, this is available on all supported kernel versions — the kernel itself is not involved.

**Note**: The transactional upgrade system (Layer 4) relies on POSIX-atomic `rename(2)` for its `commit_transaction` and `rollback_transaction` operations. Every supported kernel provides this.

**Note**: The install cascade depends on **userspace** `pm` / `cmd` / `settings` commands, not on kernel features.

**Note — SELinux staging**: `/data/local/tmp/` must be writable by root with the `shell_data_file` context. Every Android build since 4.3 uses this context for `/data/local/tmp/`, so the v1.5.0+ staging path works on every supported kernel.

#### 5.4.2 Kernel Issues

**Kernel 3.10–3.18**:
- May not support `--wait` in `iptables`.
- May not support `nft`.
- `getSystemShell()` works (selects `/system/bin/sh`).
- ⚠️ **`sha256sum` may be missing** — the backup layer falls back to size checks (advisory).
- ⚠️ **Install cascade uses strategies 1–4 only.**

**Kernel 4.14**:
- Supports `nft` with some limitations.
- `manage_nftables` works but may need fallback.
- ✅ Backup fully supported.
- ✅ Install cascade fully supported (all 5 strategies available if Android 8.0+).

### 5.5 Chipsets (SoCs)

| SoC | Architecture | Status |
|---|---|:---:|
| Snapdragon 8 Gen 3 | arm64-v8a | ✅ |
| Snapdragon 8 Gen 2 | arm64-v8a | ✅ |
| Snapdragon 888 | arm64-v8a | ✅ |
| Snapdragon 865 | arm64-v8a | ✅ |
| Snapdragon 7xx | arm64-v8a | ✅ |
| Snapdragon 6xx | arm64-v8a / armeabi-v7a | ✅ |
| Snapdragon 4xx | arm64-v8a / armeabi-v7a | ✅ |
| Exynos 2100+ | arm64-v8a | ✅ |
| Exynos 990 | arm64-v8a | ✅ |
| Exynos 9820 | arm64-v8a | ✅ |
| Dimensity 9000+ | arm64-v8a | ✅ |
| Dimensity 1000+ | arm64-v8a | ✅ |
| Helio G series | arm64-v8a / armeabi-v7a | 🟢 |
| Kirin 9000 | arm64-v8a | 🟢 |
| Kirin 980 | arm64-v8a | 🟢 |
| Tensor (Pixel 6+) | arm64-v8a | ✅ |
| Intel x86 (Atom) | x86 / x86_64 | 🟢 |

#### 5.5.1 Architecture Support

| Architecture (ABI) | Binaries | Status |
|---|---|:---:|
| `arm64-v8a` | `*-arm64` | ✅ |
| `armeabi-v7a` | `*-arm` | ✅ |
| `x86_64` | `*-amd64` | ✅ |
| `x86` | `*-386` | ✅ |

#### 5.5.2 Performance by Architecture

| Arch | `parsePrometheus` | `hasEndpoint` | Memory |
|---|:---:|:---:|:---:|
| arm64-v8a | ~50 µs | <100 ns | ~15 MB |
| armeabi-v7a | ~150 µs | <200 ns | ~15 MB |
| x86_64 | ~40 µs | <80 ns | ~15 MB |
| x86 | ~200 µs | <250 ns | ~15 MB |

#### 5.5.3 RACE-1 Performance

| Arch | `rebuildBlocklist` (100K) | `rebuildBlocklist` (500K) |
|---|:---:|:---:|
| arm64-v8a | ~200 ms | ~1 s |
| armeabi-v7a | ~600 ms | ~3 s |
| x86_64 | ~180 ms | ~900 ms |
| x86 | ~800 ms | ~4 s |

#### 5.5.4 Memory Profile by Device RAM (MEM-1)

| Device RAM | Recommended profile | WebUI soft limit | Filters |
|---|:---:|---:|:---:|
| **1 GB** | `light` | 80 MB | ~40K entries |
| **2 GB** | `normal` | 100 MB | ~120K entries |
| **3 GB** | `pro` (default) | 120 MB | ~250K entries |
| **4 GB** | `proplus` | 160 MB | ~350K entries |
| **6 GB+** | `ultimate` | 220 MB | ~500K entries |

**What "Soft Limit" Means**: `debug.SetMemoryLimit` is a **soft** limit. The Go runtime does **not** kill the process when the limit is reached — it runs GC more aggressively instead. Setting the limit too low → GC runs constantly → CPU waste → the WebUI appears slow. Setting the limit too high → RAM waste.

**How to Change the Profile**:
```bash
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**How to Read the Value**:
```bash
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
```

### 5.6 Firewall Backends

| Backend | Status | Priority |
|---|:---:|---|
| **nftables** | ✅ | 1 (preferred) |
| **iptables** | ✅ | 2 |
| **ip6tables** | ✅ | complementary |
| none | ⚠️ | no redirect |

#### 5.6.1 Compatibility Matrix

| Backend | Android 5 | 8 | 10 | 12 | 14 |
|---|:---:|:---:|:---:|:---:|:---:|
| nftables | ❌ | ⚠️ | 🟢 | ✅ | ✅ |
| iptables | ✅ | ✅ | ✅ | ✅ | ✅ |
| ip6tables | ⚠️ | ✅ | ✅ | ✅ | ✅ |

#### 5.6.2 Custom Chains

| Backend | Custom Chain Name | Cleanup Method |
|---|---|---|
| iptables | `DNSCRYPT_OUT` | `-F` + `-X` |
| ip6tables | `DNSCRYPT_OUT6` | `-F` + `-X` |
| nftables | `dnscrypt_filter` (table) | `delete table` |

#### 5.6.3 Verify Firewall After v1.6.0 Upgrade

```bash
su -c "iptables -t nat -L DNSCRYPT_OUT -n"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"  # → 0
su -c "nft list table inet dnscrypt_filter 2>/dev/null | head -5"
```

### 5.7 Root Solutions

| Solution | Status | Min Version |
|---|:---:|---|
| Magisk | ✅ | 20.4 |
| Magisk Delta | ✅ | latest |
| KernelSU | ✅ | 0.9.0 |
| APatch | ✅ | latest |
| SuperSU | ❌ | Legacy |
| KingRoot | ❌ | Untrusted |
| Magisk Canary | ✅ | latest |

#### 5.7.1 Root Features

| Feature | Min Version |
|---|---|
| `ui_print` | 20.0 |
| `abort` | 20.0 |
| `set_perm_recursive` | 20.0 |
| KernelSU API | 0.9.0 |
| **APatch compatibility** | **APatch (any)** |
| **`magisk su -c`** (strategy 4) | **Magisk any** |
| **`modules_update/` fallback** | **APatch any** |

#### 5.7.2 Root + Feature Compatibility

| Feature | Magisk 20.4+ | KernelSU | APatch |
|---|:---:|:---:|:---:|
| Backup/Restore | ✅ | ✅ | ✅ |
| Multi-source detection | ✅ | ✅ | ✅ |
| Persistent backup to `/sdcard/` | ✅ | ✅ | ✅ |
| SHA256 verification | ✅ | ✅ | ✅ |
| Transactional upgrades | ✅ | ✅ | ✅ |
| `modules_update/` fallback | n/a | n/a | ✅ |
| SELinux preservation | ✅ | ✅ | ✅ |
| Recovery mode | ✅ | ✅ | ✅ |
| Config migrations | ✅ | ✅ | ✅ |
| Auto-backup + rotation | ✅ | ✅ | ✅ |
| CLI diagnose | ✅ | ✅ | ✅ |
| `runtime_info.backups` | ✅ | ✅ | ✅ |
| MEM-1..MEM-3 | ✅ | ✅ | ✅ |
| Bilingual WebUI | ✅ | ✅ | ✅ |
| DNS auto-start fix | ✅ | ✅ | ✅ |
| SNAP-* / ROT-* | ✅ | ✅ | ✅ |
| Companion app route | ✅ | ✅ | ✅ |
| CodeQL fix `removeModule` | ✅ | ✅ | ✅ |
| **Install cascade — strategy 1** | ✅ | ✅ | ✅ |
| **Install cascade — strategy 2** | ✅ | ✅ | ✅ |
| **Install cascade — strategy 3** | ✅ | ✅ | ✅ |
| **Install cascade — strategy 4** (`magisk su`) | ✅ | ❌ (Magisk-only) | ❌ (Magisk-only) |
| **Install cascade — strategy 5** (`cmd package`) | ✅ | ✅ | ✅ |
| **SELinux staging to `/data/local/tmp/`** | ✅ | ✅ | ✅ |
| **Play Protect trap** | ✅ | ✅ | ✅ |
| **One-shot CSRF token** | ✅ | ✅ | ✅ |
| **Per-IP install rate limit** | ✅ | ✅ | ✅ |
| **`lib/*.sh` Layer 0 modules** | ✅ | ✅ | ✅ |
| **`boot-mini.sh` Layer 1 aggregator** | ✅ | ✅ | ✅ |
| **`functions.sh` Layer 2 orchestrator** | ✅ | ✅ | ✅ |
| **`install_app.sh` at module root** | ✅ | ✅ | ✅ |
| **APK mirror to `apk/`** | ✅ | ✅ | ✅ |
| **Local timezone rendering (`last_update_unix`)** | ✅ | ✅ | ✅ |

**Note on strategy 4**: `magisk su -c "pm install -r ..."` is **Magisk-only** — it requires the `magisk` binary. On KernelSU and APatch, the cascade simply skips strategy 4 and continues with the other four.

#### 5.7.3 Verification on Device

```bash
# 1. Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# 2. Backup layers present
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP transaction_begin \
         detect_root_solution copy_with_context RECOVERY_MODE; do
  su -c "grep -q '$L' /data/adb/modules/dnscrypt-proxy-webui/customize.sh" \
    && echo "✅ $L" || echo "❌ $L"
done

# 3. Backup helpers
for H in backup_user_files restore_user_files rotate_backups; do
  su -c "grep -q '$H' /data/adb/modules/dnscrypt-proxy-webui/lib/backup.sh" \
    && echo "✅ $H" || echo "❌ $H"
done

# 4. MEM-1
L=$(su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info" | jq -r '.memory_limit_mb')
[ -n "$L" ] && [ "$L" -gt 0 ] && echo "✅ MEM-1 active (limit=$L MB)"

# 5. Companion APK
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>/dev/null" \
    && echo "✅ Companion APK present" || echo "ℹ️ Companion APK absent (optional)"

# 6. iOS PWA logic removed
su -c "grep -q 'isIOSDevice' /data/adb/modules/dnscrypt-proxy-webui/web/index.html" \
    && echo "❌ iOS logic still present" || echo "✅ iOS logic removed"

# 7. Install-method modal
su -c "grep -q 'showInstallModal' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ IDX-24 modal present'"

# 8. Four install endpoints
for E in install_companion_app install_token companion_app_state uninstall_companion_app; do
  su -c "grep -q '$E' /data/adb/modules/dnscrypt-proxy-webui/proxy/main.go 2>/dev/null" \
    && echo "✅ $E" || echo "❌ $E"
done

# 9. install_app.sh — 5 cascade levels
for pattern in 'pm install -r --user 0' \
               'pm install -r --user 0 -i com.android.shell' \
               'pm install-create' 'magisk su' 'cmd package install'; do
    su -c "grep -q '$pattern' /data/adb/modules/dnscrypt-proxy-webui/install_app.sh" && \
        echo "  ✅ $pattern" || echo "  ❌ $pattern"
done

# 10. install_app.sh — 75 s deadline
su -c "grep -q 'CASCADE_DEADLINE_SECONDS=75' /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && echo '✅ 75 s deadline'"

# 11. No setenforce 0
su -c "grep -v '^[[:space:]]*#' /data/adb/modules/dnscrypt-proxy-webui/install_app.sh | grep -q 'setenforce 0' && echo '❌ setenforce 0 found' || echo '✅ no setenforce 0'"

# 12. Three-way trap split
su -c "grep -q \"trap '_cleanup_app' EXIT\" /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && echo '✅ EXIT trap'"
su -c "grep -q \"trap '_cleanup_app; exit 130' INT\" /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && echo '✅ INT trap (exit 130)'"
su -c "grep -q \"trap '_cleanup_app; exit 143' TERM\" /data/adb/modules/dnscrypt-proxy-webui/install_app.sh && echo '✅ TERM trap (exit 143)'"

# 13. Modular lib/ — 6 modules
for M in constants fallbacks process http backup firewall; do
    su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/lib/$M.sh" && \
        echo "  ✅ lib/$M.sh" || echo "  ❌ lib/$M.sh"
done

# 14. boot-mini.sh is Layer 1 aggregator
su -c "grep -q 'lib/constants.sh\|_LIB_BASE' /data/adb/modules/dnscrypt-proxy-webui/boot-mini.sh && echo '✅ Layer 1 sources Layer 0'"

# 15. functions.sh is Layer 2
su -c "grep -q 'boot-mini.sh' /data/adb/modules/dnscrypt-proxy-webui/functions.sh && echo '✅ Layer 2 sources Layer 1'"

# 16. v1.6.0 timezone fix — backend
su -c "grep -q 'last_update_unix' /data/adb/modules/dnscrypt-proxy-webui/proxy/main.go && echo '✅ v1.6.0 timezone fix present'"

# 17. v1.6.0 timezone fix — frontend
su -c "grep -q 'formatUnixTimestamp' /data/adb/modules/dnscrypt-proxy-webui/web/index.html && echo '✅ v1.6.0 frontend timezone fix present'"

# 18. APK mirror
if su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk"; then
    su -c "ls -la /sdcard/dnscrypt-webui-backup/apk/" 2>/dev/null && \
        echo "✅ APK mirror present" || \
        echo "ℹ️ APK mirror not created (best-effort)"
else
    echo "ℹ️ APK not bundled (dev build) — mirror skipped silently"
fi
```

### 5.8 Known Issues

**Generic**:
1. Battery optimization stops the Watchdog (Android 8-9) — add to exceptions.
2. MIUI kills background — Autostart + No battery restrictions.
3. ColorOS kills aggressively — allow background activity.
4. iptables `--wait` unsupported (Kernel < 3.14) — fallback.
5. nft `inet` family unsupported (Kernel < 4.10) — fallback to `ip`.
6. DNS leak on IPv6 (some ROMs) — `block_ipv6 = true`.
7. Hotspot DNS leak (Android < 11) — additional rules.
8. Private DNS conflict (Android 9+) — disabled automatically.
9. VPN apps conflict — cannot run together.
10. SELinux enforcing blocks (rare) — requires permissive.
11. Orphans from old versions — cleaned automatically.
12. Dashboard shows empty data (pre-v1.0.0) — update.
13. Basic Auth locked after 5 attempts — wait 15 min or restart.
14. 404 for unknown action (v1.0.0+) — update the script.
15. CI Go build fails on Linux (pre-v1.0.0) — update.
16. Settings lost on upgrade (pre-v1.0.0) — update to v1.2.0+.
17. Login GET rejected (405) — use POST.
18. `/readyz` from LAN rejected (403) — use `/healthz`.
19. Credentials change delay (60 s) — wait 60 s or restart.
20. Blocklist rebuild may take time on long lists — normal (RACE-1).

**v1.5.0+ install-flow**:

| # | Issue | Workaround |
|:-:|---|---|
| 21 | Install token expired (HTTP 401) | Close modal, click **Install App** again to fetch a fresh token |
| 22 | Install rate-limited (HTTP 429) | Wait 15 minutes, or restart the WebUI (`action.sh --restart`) |
| 23 | All cascade strategies failed | Check modal's `message_en` / `hint_en`. Common: MIUI USB block, Play Protect, version downgrade, signature mismatch, corrupt APK |
| 24 | Play Protect blocks even after trap | Disable Play Protect manually for the duration |
| 25 | SELinux staging file left behind | Only on hard reboot or SIGKILL — `rm -f /data/local/tmp/dnscrypt-companion.apk` |
| 26 | APK mirror missing after upgrade | Best-effort copy. Manual: `mkdir -p /sdcard/dnscrypt-webui-backup/apk && cp $MODDIR/web/app-debug.apk* /sdcard/dnscrypt-webui-backup/apk/` |
| 27 | `boot-mini.sh` missing after upgrade | Reinstall v1.6.0 ZIP |
| 28 | Install-method modal does not open | Clear SW cache in browser, or use **🔄 Force Refresh** |
| 29 | WebUI shows UTC instead of local time (v1.5.0) | **Fixed in v1.6.0**. Hard-refresh the WebUI |
| 30 | `lib/` scripts not found after manual install | Cause: ZIP extracted without `lib/`. Verify `ls $MODDIR/lib/` shows 6 files |
| 31 | `boot-mini.sh` fails to source a `lib/` module | SELinux context loss — `restorecon -R $MODDIR/lib/` |
| 32 | Bash completion or editor mis-highlights `lib/*.sh` | Cosmetic — files use `ksh` shebangs |

### 5.9 Testing & Reporting

#### 5.9.1 Recommended Tests for v1.6.0

**A. Modular Bootstrap Test**:

```bash
# 1. All 6 lib/ modules present
su -c "ls -la $MODDIR/lib/"

# 2. boot-mini.sh is the Layer 1 aggregator
su -c "grep -c 'lib/constants.sh\|_LIB_BASE' $MODDIR/boot-mini.sh"

# 3. functions.sh is Layer 2
su -c "grep -q 'boot-mini.sh' $MODDIR/functions.sh && echo 'OK'"

# 4. Source chain works end-to-end
su -c ". $MODDIR/functions.sh; type init_runtime_paths >/dev/null 2>&1 && echo '✅ Layer chain OK'"

# 5. No Layer-0 primitive redefined
for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
    su -c "grep -qE '^${fn}[[:space:]]*\(\)' $MODDIR/functions.sh" && \
        echo "❌ $fn redefined" || echo "✅ $fn lives only in Layer 0"
done
```

**B. Timezone Fix Test**:

```bash
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=get_profile" | \
    jq '{last_update, last_update_unix}'

# Open WebUI → check "Last update:" matches device clock
```

**C. Install Cascade Test** (per ROM):

```bash
# 1. Generate token
TOKEN=$(curl -s -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')

# 2. Install
curl -s -b /tmp/cookies.txt \
    -X POST http://127.0.0.1:9090/api/install_companion_app \
    -d "token=$TOKEN" | jq '.strategy'

# 3. Verify cleanup
su -c "ls -la /data/local/tmp/dnscrypt-companion.apk 2>&1"
su -c "settings get global package_verifier_enable"
su -c "getenforce"
```

**D. APK Mirror Test**:

```bash
# 1. Check mirror
su -c "ls -la /sdcard/dnscrypt-webui-backup/apk/ 2>&1"

# 2. Verify SHA256
su -c "cd /sdcard/dnscrypt-webui-backup/apk && sha256sum -c app-debug.apk.sha256"

# 3. Verify NOT counted as snapshot
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name'"
```

**E. Backup Rotation Semantics Test**:

```bash
# 1. Create manifest-less directory
su -c "mkdir -p /sdcard/dnscrypt-webui-backup/29991231-235959-test"
su -c "echo 'test' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/webui.conf"

# 2. Read count (should be unchanged)
BEFORE=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
AFTER=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
[ "$BEFORE" = "$AFTER" ] && echo "✅ SNAP-MANIFEST active"

# 3. Add manifest, re-check
su -c "echo '{}' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/.manifest.json"
AFTER2=$(curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
[ "$AFTER2" -gt "$AFTER" ] && echo "✅ SNAP-MANIFEST active (manifest counted)"

# 4. Cleanup
su -c "rm -rf /sdcard/dnscrypt-webui-backup/29991231-235959-test"
```

#### 5.9.2 Contributing Reports

We welcome:
- Compatibility reports from rare devices.
- Testing on different or modified ROMs.
- Solutions and workarounds for known issues.
- Detailed logs.
- Dashboard reports on different browsers.
- Platform reports (Linux, macOS, WSL2).
- Performance reports.
- Memory-limit reports per device RAM tier.
- Backup/restore reports across devices and root solutions.
- Bilingual WebUI reports across browsers.
- Snapshot-detection (SNAP-MANIFEST) and rotation (ROT-*) reports.
- Companion app installation reports on various ROMs.
- Install cascade reports across ROM families.
- Modular bootstrap reports, APK mirror reports.
- **Timezone rendering reports across devices and languages (v1.6.0)**.

**How to contribute**: see `docs/CONTRIBUTING.md` §7 (Recognition) and `.github/ISSUE_TEMPLATE/bug_report.yml`.

### 5.10 Quick Reference Card

```bash
# ─────────────────────────────────────────────────────────────
# Version info
# ─────────────────────────────────────────────────────────────
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.version"
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/app-apk.version"

# ─────────────────────────────────────────────────────────────
# Device info
# ─────────────────────────────────────────────────────────────
getprop ro.product.cpu.abi
getprop ro.build.version.release
getprop ro.build.version.sdk
uname -r

# ─────────────────────────────────────────────────────────────
# Module architecture (v1.6.0)
# ─────────────────────────────────────────────────────────────
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/lib/"

# ─────────────────────────────────────────────────────────────
# Runtime state
# ─────────────────────────────────────────────────────────────
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# ─────────────────────────────────────────────────────────────
# API access
# ─────────────────────────────────────────────────────────────
# Read CREDS using the shared helper (section-aware, quote-aware)
CREDS=$(su -c ". /data/adb/modules/dnscrypt-proxy-webui/lib/constants.sh; read_toml_credentials" | paste -sd:)

curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | jq
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

# ─────────────────────────────────────────────────────────────
# Timezone verification (v1.6.0)
# ─────────────────────────────────────────────────────────────
curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
    jq '{last_update, last_update_unix}'

curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
    jq -r '.last_update_unix' | xargs -I {} date -d @{}

date
```

---

## 6. DNS Binaries Pipeline

### 6.1 Overview

#### 6.1.1 What is dnscrypt-proxy?

**dnscrypt-proxy** is the encrypted DNS engine the project depends on:
- Source: [DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- License: ISC License
- Availability: 4 architectures (arm64, arm, i386, x86_64)
- Current version: **2.1.20**

**Three versions coexist in the project** — do not confuse them:

| Version | Source file | Value |
|---|---|:---:|
| **DNS version** (upstream) | `proxy/dnscrypt-proxy.version` | `2.1.20` |
| **Module version** (this project) | `VERSION` | `v1.6.0` |
| **Companion app version** | `proxy/app-apk.version` | `1.0.0` |

#### 6.1.2 Single Source of Truth

**Path:** `proxy/dnscrypt-proxy.version`
**Content:** `2.1.20` (single line)

**Consumers**:
- `scripts/fetch_dns_binaries.sh` — reads the version to build download URLs.
- `scripts/package_module.sh` — maps `x86` → `i386` when copying to staging.
- `.github/workflows/ci.yml` — verifies presence.
- `.github/workflows/release.yml` — verifies presence + packages.

#### 6.1.3 Upgrade Scenario

**Before Level 4** (pre-v1.0.0): 5 files manually edited.

**After Level 4**: single file edit — everything else updates automatically.

### 6.2 How It Works

#### 6.2.1 General Flow

```text
┌──────────────────────────────────────────────────────────────┐
│  [1] Read the version                                        │
│      proxy/dnscrypt-proxy.version → "2.1.20"                 │
└──────────────────────────────┬───────────────────────────────┘
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  [2] Check Cache                                             │
│      ~/.cache/dnscrypt-proxy-webui/dns-binaries/             │
└──────────────────────────────┬───────────────────────────────┘
                               ▼
                        ┌──────────────┐
                        │ Cache        │
                        │ complete?    │
                        └──────┬───────┘
                   ✓ Yes       │       ✗ No
                       │       │       │
                       ▼       │       ▼
                 ┌──────────┐  │  ┌──────────────────┐
                 │ Use      │  │  │ Call fetch script│
                 │ cache    │  │  └────────┬─────────┘
                 └──────────┘  │           ▼
                       │       │  ┌──────────────────┐
                       │       │  │ Try 4 fallback   │
                       │       │  │     sources      │
                       │       │  └────────┬─────────┘
                       │       │           ▼
                       │       │  ┌──────────────────┐
                       │       │  │ SHA256 verify    │
                       │       │  └────────┬─────────┘
                       │       │           ▼
                       │       │  ┌──────────────────┐
                       │       │  │ Save to cache    │
                       │       │  └────────┬─────────┘
                       └───────┴───────────┘
                               ▼
                       ┌──────────────────┐
                       │ Copy to staging  │
                       │ (i386 → x86 map) │
                       └────────┬─────────┘
                                ▼
                       ┌──────────────────┐
                       │ Create Magisk ZIP│
                       └──────────────────┘
```

#### 6.2.2 Architecture Mapping

| GitHub name | Cache name | Staging name | WebUI arch |
|---|---|---|---|
| `arm64` | `arm64` | `arm64` | `arm64` |
| `arm` | `arm` | `arm` | `arm` |
| `x86_64` | `x86_64` | `x86_64` | `amd64` |
| `i386` | `i386` | **`x86`** ⚠️ | `386` |

**⚠️ Important architectural note:** `customize.sh` expects `dnscrypt-proxy-x86` (Android convention), but GitHub provides `i386` (Linux convention).

**Solution:** `map_to_cache_name()` in `package_module.sh`:
```bash
map_to_cache_name() {
    case "$1" in
        dnscrypt-proxy-x86)    echo "dnscrypt-proxy-i386" ;;
        dnscrypt-proxy-x86_64) echo "dnscrypt-proxy-x86_64" ;;
        dnscrypt-proxy-arm64)  echo "dnscrypt-proxy-arm64" ;;
        dnscrypt-proxy-arm)    echo "dnscrypt-proxy-arm" ;;
        *) echo "$1" ;;
    esac
}
```

### 6.3 4 Fallback Sources

| # | Source | Description |
|:-:|---|---|
| **1** | GitHub API | Actual asset names (most accurate) |
| **2** | `android_<arch>-<version>.zip` | Format 2.1.18+ |
| **3** | `android-<arch>-<version>.zip` | Older format |
| **4** | `android_<arch>_<version>.zip` | Underscore format |

**URL examples (for `arm64`, version `2.1.20`)**:
1. `https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/tags/2.1.20` → assets list
2. `.../download/2.1.20/dnscrypt-proxy-android_arm64-2.1.20.zip`
3. `.../download/2.1.20/dnscrypt-proxy-android-arm64-2.1.20.zip`
4. `.../download/2.1.20/dnscrypt-proxy-android_arm64_2.1.20.zip`

#### 6.3.1 Considered and Rejected: jsDelivr CDN

jsDelivr was considered as a fifth fallback. It was rejected because its `/gh/` endpoint serves files from the **git tree**, not release assets. `dnscrypt-proxy` release ZIPs are published as GitHub Release assets and are therefore **not** in the git tree.

### 6.4 Cache Structure

```text
~/.cache/dnscrypt-proxy-webui/dns-binaries/
├── dnscrypt-proxy-arm64          ← binary (arm64-v8a)
├── dnscrypt-proxy-arm            ← binary (armeabi-v7a)
├── dnscrypt-proxy-x86_64         ← binary (x86_64)
├── dnscrypt-proxy-i386           ← binary (i386, 32-bit)
└── .manifest.json                ← metadata (SHA256 + URL + timestamp)
```

#### 6.4.1 `.manifest.json`

```json
{
  "dnscrypt-proxy-arm64": {
    "sha256": "a1b2c3d4e5f6...",
    "version": "2.1.20",
    "url": "https://github.com/DNSCrypt/...",
    "fetched_at": "2026-11-12T10:30:00Z"
  },
  "dnscrypt-proxy-arm": { "...": "..." },
  "dnscrypt-proxy-x86_64": { "...": "..." },
  "dnscrypt-proxy-i386": { "...": "..." }
}
```

#### 6.4.2 Cache Invalidation

| Scenario | Action |
|---|---|
| New version in `dnscrypt-proxy.version` | ✅ Re-fetch |
| `--force` | ✅ Re-fetch |
| SHA mismatch | ✅ Re-fetch |
| Size < 3 MB | ✅ Re-fetch |
| Cache complete | ⏸️ Use it |

#### 6.4.3 Cache Size

| Binary | Approximate size |
|---|:---:|
| `dnscrypt-proxy-arm64` | ~8 MB |
| `dnscrypt-proxy-arm` | ~7 MB |
| `dnscrypt-proxy-x86_64` | ~7.5 MB |
| `dnscrypt-proxy-i386` | ~7 MB |
| **Total** | **~30 MB** |

#### 6.4.4 Cache TTL

| Layer | TTL | Source |
|---|:---:|---|
| **GitHub Actions Cache** | 7 days (auto) | GitHub |
| **Local cache** | ∞ (until `--force`) | Developer |
| **CI cache** | Depends on `dns_version` | Workflow |

### 6.5 SHA256 Verification

**Three distinct SHA256 checks exist** — do not confuse them:

| Verification | Target | File |
|---|---|---|
| **DNS binaries SHA256** | Downloaded `dnscrypt-proxy` binaries | `.manifest.json` in DNS cache |
| **Backup integrity SHA256** | The 5 user config files | `.manifest.json` in each backup snapshot |
| **Companion APK SHA256** | The downloaded `app-debug.apk` | `web/app-debug.apk.sha256` sidecar |

### 6.6 Retry Logic

`fetch_dns_binaries.sh` delegates retry to `curl`:

```bash
curl_args=(
    -fsSL
    --max-time "$HTTP_TIMEOUT"   # 30 s per attempt
    --retry 2                    # 3 total attempts (1 + 2 retries)
    --retry-delay 1              # 1 s between attempts
)
```

**Per-source-URL attempt schedule**:

| Attempt | Delay before | Notes |
|:---:|---|:---:|
| 1 | — | Initial GET |
| 2 | 1 s | First retry |
| (fail) | — | Falls through to the next source |

**Worst case across the whole arch** (4 sources × 3 attempts) = 12 `curl` invocations, each with a 30 s `--max-time` ceiling.

### 6.7 CI Integration

| Workflow | Role | Trigger |
|---|---|---|
| **`release.yml`** | Uses cache or fetches; + metadata consistency + APK `.sha256` staging | On tag push `v*` |
| **`ci.yml`** | Verifies presence + metadata; + APK metadata check + Step 8/9/10 guards | Every push/PR to `main` or `develop` |
| **`upgrade-test.yml`** | 42-scenario data-preservation matrix | **Manual (`workflow_dispatch`) only** |
| **`codeql.yml`** | SAST — Go security analysis | Push/PR + weekly schedule |

**Comparison table**:

| Pipeline | Script | Cache dir | Target artifact |
|---|---|---|---|
| **DNS binaries** | `scripts/fetch_dns_binaries.sh` | `~/.cache/dnscrypt-proxy-webui/dns-binaries` | `dnscrypt-proxy-*` binaries |
| **Companion APK** | `scripts/fetch_app_apk.sh` | `~/.cache/dnscrypt-proxy-webui/app` | `app-debug.apk` |

### 6.8 Command Reference

```bash
# Fetch all architectures (default)
./scripts/fetch_dns_binaries.sh

# Single architecture
./scripts/fetch_dns_binaries.sh --arch arm64

# Full details
./scripts/fetch_dns_binaries.sh --verbose

# Force re-fetch (bypass cache)
./scripts/fetch_dns_binaries.sh --force

# Offline (cache only)
./scripts/fetch_dns_binaries.sh --offline

# JSON output (CI)
./scripts/fetch_dns_binaries.sh --json | jq '.summary'

# Fetch the companion APK (default cache-first)
./scripts/fetch_app_apk.sh

# Custom output directory (used by release.yml)
./scripts/fetch_app_apk.sh --output-dir ./dist
```

### 6.9 Updating the Version

#### 6.9.1 Updating dnscrypt-proxy

```bash
# 1. Verify the new version
curl -s https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest | jq -r .tag_name

# 2. Update the file
echo "2.1.21" > proxy/dnscrypt-proxy.version

# 3. Commit
git add proxy/dnscrypt-proxy.version
git commit -m "build: bump dnscrypt-proxy to 2.1.21"
git push origin develop
```

#### 6.9.2 Module Version Bump

```bash
echo "v1.6.0" > VERSION
sed -i 's/^version=.*/version=v1.6.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1060000/' module.prop
$EDITOR update.json

git add VERSION module.prop update.json
git commit -m "release: v1.6.0"
```

#### 6.9.3 Difference Table

| Upgrade | What changes | Action | Affected workflows |
|---|---|---|---|
| **DNS version** (2.1.18 → 2.1.20) | `proxy/dnscrypt-proxy.version` | ✅ One file | `release.yml`, `ci.yml` |
| **Module version** (v1.5.0 → v1.6.0) | `VERSION` + `module.prop` + `update.json` | Automated via `release.sh` | `ci.yml`, `release.yml` |
| **Companion app version** (1.0.0 → 1.1.0) | `proxy/app-apk.version` | ✅ One file | `release.yml`, `ci.yml` (metadata check) |

#### 6.9.4 Version History

| Release | Module Version | DNS Version | Companion App | Notes |
|---|:---:|:---:|:---:|---|
| First stable | v1.0.0 | 2.1.18 | — | 33 audit corrections |
| Polish | v1.1.0 | 2.1.18 | — | MEM-1/2/3 |
| Data preservation | v1.2.0 | 2.1.18 | — | 10 layers + BAK-1..4 + FIX-1/2 |
| PWA + boot fix | v1.3.0 | 2.1.18 | — | PWA button + LED + DNS auto-start + rotation refinements |
| Companion app | v1.4.0 | 2.1.18 | 1.0.0 | Companion APK + CodeQL fix + iOS removal |
| Companion one-tap install | v1.5.0 | 2.1.18 | 1.0.0 | Companion install flow + Layered Bootstrap + APK mirror |
| **Architecture & UX** | **v1.6.0** | **2.1.20** | **1.0.0** | **WebUI timezone fix, PWA cache bump, lib/ modularization, DNS version bump** |

---

## 7. Manifest `x-note-*` Fields

### 7.1 Purpose

`web/manifest.json` is parsed by the browser on every PWA install. Its file size directly affects the install prompt latency and the Service Worker's precache count.

The v1.6.0 manifest carries **2 `x-note-*` fields** totaling ~0.3 KB:

| Field | Status |
|---|---|
| `x-note-last-updated` | `2026-11-12` (v1.6.0) |
| `x-note-version` | `Mirrors main.go BuildVersion with the 'v' prefix stripped (PWA spec requires plain X.Y.Z).` |

**Historical note**: Earlier releases carried up to 10 `x-note-*` fields totaling ~6 KB. The trimmed manifest now stores only 2 lightweight metadata markers; the technical detail that used to live inline now lives in this section.

### 7.2 Source of Truth

| `x-note-*` field in manifest.json | Full reference |
|---|---|
| `x-note-last-updated` | Header |
| `x-note-version` | `VERSION` + `REFERENCE.md` §1.8 |

### 7.3 Maskable Safe Zone

#### 7.3.1 W3C Specification

Per the [W3C Web App Manifest](https://www.w3.org/TR/appmanifest/#maskable), the **maskable safe zone** is a **circle** whose diameter is **80%** of the icon's smallest dimension, centered on the icon.

For a **512×512** canvas:
```text
radius = (512 × 0.8) / 2 = 204.8 px
center = (256, 256)
test   : (x - 256)² + (y - 256)² ≤ 41943
```

#### 7.3.2 Current Icon

`web/icon-512.svg` is declared in the manifest with **two purposes** (as two separate entries — the spec requires one entry per purpose):

| Entry | `src` | `purpose` |
|---|---|---|
| `icons[2]` | `/icon-512.png` | `any` |
| `icons[4]` | `/icon-512.png` | `maskable` |

#### 7.3.3 Shield Control-Point Analysis

Every control point of the shield path in `icon-512.svg` fits inside the W3C safe circle with comfortable margins:

| Point | Coordinates | Distance from center | Margin |
|---|---:|---:|---:|
| Top vertex | (256, 60) | 196.0 px | **+8.8 px** |
| Right shoulder | (416, 142) | 196.5 px | **+8.3 px** |
| Right edge | (416, 256) | 160.0 px | +44.8 px |
| Bottom vertex | (256, 448) | 192.0 px | +12.8 px |
| Left shoulder | (96, 142) | 196.5 px | **+8.3 px** |
| Left edge | (96, 256) | 160.0 px | +44.8 px |

**Result**: no clipping on launchers that apply a **40% circular mask** (Pixel Launcher, most AOSP builds).

#### 7.3.4 Known Limitations

On OEM launchers with **45%+ circular masks**, the shield's shoulders may clip by a few pixels. This is inherent to a shield-shaped icon at 512 px — a purpose-built maskable asset would require a different silhouette. See `docs/ROADMAP.md` §2.1 item 3 (dedicated maskable icon).

### 7.4 Icon Source Pipeline

#### 7.4.1 Mapping

`scripts/generate-icons.sh` produces every PNG/ICO from the two SVG sources:

| Source SVG | Output file | Size | Purpose |
|---|---|---:|---|
| `icon-192.svg` | `icon-192.png` | 192×192 | PWA small |
| `icon-512.svg` | `icon-512.png` | 512×512 | PWA large |
| `icon-512.svg` | `apple-touch-icon.png` | 180×180 | Launcher fallback |
| `icon-512.svg` | `favicon-32x32.png` | 32×32 | Modern favicon |
| `icon-512.svg` | `favicon-16x16.png` | 16×16 | Legacy favicon |
| `favicon-16/32.png` | `favicon.ico` | multi | IE + bookmarks |

#### 7.4.2 Critical Note

**`icon-192.png` is generated from `icon-192.svg`**, NOT from `icon-512.svg`. The two SVG sources have different viewBox scales and different corner treatments (rounded vs full-bleed). Mixing them would produce a visually inconsistent small icon.

#### 7.4.3 Regeneration Command

```bash
./scripts/generate-icons.sh --force
```

**Always regenerate PNGs before bumping `CACHE_VERSION` in `web/sw.js`.** Otherwise, clients with an existing cache keep the old PNGs for the full `CACHE_VERSION` lifetime.

### 7.5 Language Policy

#### 7.5.1 Decision

The project is **English default + Arabic toggle**. The manifest declares:
```json
"lang": "en",
"dir": "ltr"
```

#### 7.5.2 Rationale

- **Single canonical default** — English (Global Edition).
- **First-class Arabic** — full RTL CSS, bilingual strings in every HTML file, no fork or parallel codebase.
- **Client-side only** — the toggle is stored in `localStorage['dnscrypt-lang']` and never transmitted.
- **Server-neutral** — the HTTP API returns JSON without localized strings (except AR/EN message pairs on install errors).

#### 7.5.3 Runtime Behavior

| State | `document.documentElement` |
|---|---|
| First visit | `lang="en" dir="ltr"` |
| User clicks toggle | `lang="ar" dir="rtl"` |
| Reload | Restored from `localStorage` in a `<script>` in `<head>` (before CSS paints, to avoid FOUC) |

#### 7.5.4 Service Worker

The SW is **language-neutral**. It does not read `localStorage` (not available inside a Service Worker context) and caches only language-agnostic assets.

### 7.6 PWA Constraints

#### 7.6.1 Shortcuts — The Problem

The module exposes **two separate HTTP servers**: WebUI on port **9090**, Dashboard on port **9091**.

In browser terms, these are **different origins** (`http://127.0.0.1:9090` ≠ `http://127.0.0.1:9091`).

#### 7.6.2 Shortcuts — Manifest Constraint

A Web App Manifest's `shortcuts[]` URLs **MUST be same-origin with the manifest's `start_url`**. A single manifest installed from port 9090 cannot navigate to port 9091 through a shortcut.

#### 7.6.3 Shortcuts — Current Design

Both shortcuts in `web/manifest.json` use **relative URLs**:
```json
"url": "/?source=shortcut_webui"
"url": "/?source=shortcut_dashboard"
```

These resolve to the manifest's **current origin** at install time.

| Install origin | Both shortcuts open |
|---|---|
| 9090 (WebUI) | WebUI |
| 9091 (Dashboard) | Dashboard |

#### 7.6.4 Shortcuts — Compensating Mechanism

Because shortcuts cannot cross origins, the WebUI provides a **dynamic Dashboard link** built from `/api?action=runtime_info`:

```javascript
// web/index.html
if (data.dashboard_port) {
    PORTS.dashboard = String(data.dashboard_port);
    updateDashboardLink();
}
```

This link works for any configured port and any hostname (127.0.0.1, `[::1]`, LAN IPs).

#### 7.6.5 Shortcuts — Future Fix

The long-term solution is to **unify the WebUI and Dashboard on a single port** (e.g. Dashboard at `/dashboard`), which would eliminate the dual-origin problem entirely. See `docs/ROADMAP.md` §2.1 item 2.

#### 7.6.6 Precache — Exclusion of `/dashboard.html`

The `sw.js` header labels this decision `SW-PRECACHE-01`. `PRECACHE_ASSETS` contains **11 files** and does **not** include `/dashboard.html`.

**Why**:
- The WebUI (9090) and Dashboard (9091) are distinct origins.
- On the **WebUI origin**, `/dashboard.html` does not exist as a distinct file — the catch-all route in `main.go` serves `index.html` for any unknown path. Precaching `/dashboard.html` there would cache the wrong content under a misleading key.
- On the **Dashboard origin**, `/dashboard.html` duplicates `/`.

#### 7.6.7 Precache — Exclusion of `/app-debug.apk`

The companion Android app is **not** in `PRECACHE_ASSETS` and is not precached by any other mechanism.

**Why**:
- `/app-debug.apk` is a ~3 MB static download, not a PWA asset.
- Precaching it would bloat the SW cache by ~3 MB on every PWA install.
- Precaching it would fail if the APK is absent (developer builds) — a partial precache with a 404 entry.
- Precaching it would duplicate storage with the browser's own HTTP cache, which `main.go` already drives via `Cache-Control: public, max-age=3600, immutable`.

**Instead**: `shouldBypass()` rule 9 lets the browser handle `/app-debug.apk` directly — the browser's HTTP cache is the right storage layer for a one-time download.

#### 7.6.8 Precache — Bypass Rules Reference

`shouldBypass(request)` in `web/sw.js` returns `true` for 9 classes of requests. Every bypass corresponds to a deliberate decision about what the SW should **not** cache:

| # | Rule | Rationale |
|:-:|---|---|
| 1 | External origins | Never interfere with third parties (incl. the GitHub URLs) |
| 2 | `/api` and `/api/*` | Always fresh (state changes) — covers all 4 companion-install endpoints |
| 3 | `/events` | SSE stream, cannot be cached |
| 4 | `/auth/*` | Must always hit the server |
| 5 | `/healthz`, `/readyz` | Liveness probes need fresh responses |
| 6 | `/sw.js` | The browser must see byte changes |
| 7 | Non-GET | Mutation methods must not be cached |
| 8 | `Authorization` header | Bearer/token requests are session-scoped |
| 9 | `/app-debug.apk` | Long-lived HTTP cache is the correct storage layer (see §7.6.7) |

The `/api` check matches exactly `/api` or `/api/<anything>` — not any path that merely starts with `/api`. This prevents a future `/apiary`-style route from accidentally bypassing the SW.

### 7.7 Companion APK Integration

#### 7.7.1 Serving

The companion Android app is served at:
```text
GET /app-debug.apk
```

Public route — **no authentication**. Returns 404 when the APK is absent (developer builds).

#### 7.7.2 Cache-Control

```http
Cache-Control: public, max-age=3600, immutable
```

The browser's own HTTP cache is the primary storage layer. The Service Worker bypasses this path — see §7.6.7 for the full rationale.

#### 7.7.3 Version Pinning

The APK version is pinned in `proxy/app-apk.version` (currently `1.0.0`, no `v` prefix). This is the **Single Source of Truth** for the companion app version.

A version bump in that file propagates to:
- `scripts/fetch_app_apk.sh` (fetcher)
- `web/index.html`'s `getCompanionApkUrl()` (dynamic URL builder)
- `release.yml` (staging step)

#### 7.7.4 SHA256 Verification

When `web/app-debug.apk.sha256` is present in the module ZIP, `install_app.sh` verifies the APK hash before any install strategy is attempted. If the file is absent (dev builds), the script degrades to advisory mode.

#### 7.7.5 Source Repository

The APK is built in a separate repository: **[gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)**.

The module's `release.yml` fetches it at build time via `scripts/fetch_app_apk.sh`.

### 7.8 Note on `.secrets.baseline`

The `version` field in `.secrets.baseline` is **owned and managed by the `detect-secrets` tool itself**. It identifies the baseline schema version the tool uses to interpret the file — it is **not** the module version, and it is not the version of any project artifact.

**Do not update this field during module releases.** The value is set by `detect-secrets` when the baseline is first created and is only changed by a tool upgrade that bumps the schema.

> **v1.6.0 note**: the current `.secrets.baseline` carries the value `1.6.0`, updated as part of the v1.6.0 release to keep the file self-consistent with the rest of the project. This is a **cosmetic** alignment — the value has no functional effect on `detect-secrets`. The tool reads its own `schema_version` field, not this one.

---

## 8. Glossary

### 8.1 DNS Terms

#### DNS — Domain Name System

A system that translates domain names (e.g. `google.com`) into IP addresses (e.g. `142.250.185.46`).

**Without it**: You would type `142.250.185.46` instead of `google.com`.

**Default port**: `53` (UDP/TCP).

#### DNSCrypt

**DNS query encryption protocol** developed by [OpenDNS](https://www.opendns.com/).

**Purpose**: Prevent ISPs from seeing or tampering with DNS queries.

**Port**: `443` (UDP/TCP).
**Encryption**: X25519 + XSalsa20-Poly1305.

**Difference from DoH**: DNSCrypt is lighter (smaller data size) — better on mobile networks.

#### DoH — DNS over HTTPS

**Sending DNS queries over HTTPS** (port 443) — appears like a normal website visit.

**Purpose**: Bypass firewalls that block port 53.

**Providers**: Cloudflare, Google, Quad9.

**Difference from DNSCrypt**: DoH uses standard HTTPS — works anywhere but slightly heavier.

#### DoT — DNS over TLS

**Sending DNS queries over TLS** (port 853).

**Difference from DoH**: DoT uses a dedicated port (853) → easier to block.

**Difference from DNSCrypt**: DoT uses standard TLS 1.3 — but is easily blocked.

#### DNSSEC — DNS Security Extensions

**Security extensions for DNS** that cryptographically verify response authenticity (signature).

**Purpose**: Prevent DNS spoofing attacks.

**⚠️ Note**: DNSSEC ensures **authenticity** — not privacy (that's DNSCrypt/DoH's job).

#### Bootstrap Resolvers

**Public DNS servers** used only to download the actual server list (`public-resolvers.md`).

**After download**: Not used — the engine starts using DNSCrypt/DoH servers.

**Example**:
```toml
bootstrap_resolvers = ['9.9.9.9:53', '8.8.8.8:53', '1.1.1.1:53', '1.0.0.1:53']
```

**⚠️** Excluded from DNS redirection via `RETURN` rules inside `DNSCRYPT_OUT`.

#### DNS Leak

**Leakage of DNS queries** outside the encrypted tunnel (e.g. silently using the ISP's DNS).

**Common causes**:
- VPN does not redirect DNS.
- Some apps use their own DNS (hardcoded).
- IPv6 routing not covered.

**Test**: Visit [dnsleaktest.com](https://www.dnsleaktest.com).

#### Blocklist

**List of blocked domains** — the actual source of blocking.

**Levels**: Light, Normal, PRO, PRO++, Ultimate.

**Source**: [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists).

#### DNS Engine

**The actual DNS engine** — `dnscrypt-proxy` itself.

**In the project**:
- Binary: `proxy/dnscrypt-proxy`
- Version: `proxy/dnscrypt-proxy.version` (2.1.20)
- Listens on: `127.0.0.1:5354` (UDP/TCP)

### 8.2 Network & Firewall Terms

#### iptables

**Linux firewall tool** (Netfilter).

**Common tables**:
- `filter` — allow/reject packets.
- `nat` — address translation (DNAT/SNAT).
- `mangle` — modify packet fields.

**Example from the project**:
```bash
iptables -t nat -I OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT
```

**⚠️ Note**: On Android 10+, `nftables` is often used instead.

#### nftables

**Modern replacement for iptables** (Kernel 4.10+).

**Advantages**: Faster, cleaner, supports IPv4 and IPv6 in the same rules.

**Example from the project**:
```bash
nft add table inet dnscrypt_filter
nft add chain inet dnscrypt_filter dnscrypt_chain '{ type nat hook output priority -100; }'
```

#### Custom Chains

**Dedicated iptables chains** created and managed independently from the public chains.

**In the project**:
- `DNSCRYPT_OUT` (IPv4).
- `DNSCRYPT_OUT6` (IPv6).

**Philosophy**:
- ✅ Dynamic rules go **inside** the chain.
- ✅ Public `OUTPUT` is clean (two static rules).
- ✅ Cleanup = `-F` + `-X` = complete wipe in one shot.

**Reason**: Prevent **Orphans** when changing `bootstrap_resolvers`.

#### DNAT — Destination NAT

**Destination address translation** of a network packet.

**In the project**:
```bash
-j DNAT --to-destination 127.0.0.1:5354
```
Means: "Any DNS query going to any server → redirect to local DNSCrypt engine".

#### RETURN

**End processing of the packet in the current chain** and return to before the `jump`.

**In the project**:
```bash
-A DNSCRYPT_OUT -d 127.0.0.1 -j RETURN
-A DNSCRYPT_OUT -d 9.9.9.9   -j RETURN
```
Means: "Do not redirect DNS queries from the DNSCrypt engine itself → prevent infinite loop".

#### Orphan Rules

**Leftover firewall rules** with no effect (orphaned) — due to lack of cleanup.

**Problem**: Accumulate over time → pollute the firewall.

**Solution in the project**: Custom Chains — **no orphans**.

#### IPv4

**Fourth version of the Internet Protocol** — 32-bit addresses.

**Format**: `192.168.1.1`

**Maximum**: ~4.3 billion addresses (exhausted in 2011).

#### IPv6

**Sixth version** — 128-bit addresses.

**Format**: `2001:db8::1` or `[::1]` (localhost).

**Advantage**: ~340 undecillion addresses.

**In the project**: Full support via `DNSCRYPT_OUT6` and `getClientIP()`.

**Note**: `isLocalRequest()` uses `net.IP.IsLoopback()`, which correctly accepts IPv4-mapped IPv6 forms like `::ffff:127.0.0.1`.

#### Loopback — 127.0.0.1 / ::1

**The "device itself" address** — does not leave the device.

**IPv4**: `127.0.0.1`
**IPv6**: `::1`

**In the project**: All servers run on loopback (by default) for security.

**Note**: The install-family endpoints (`install_companion_app`, `uninstall_companion_app`, `install_token`) are **localhost-only** — `isLocalRequest()` is checked before authentication.

#### Race Condition

**Condition where two operations reach the same data at the same time** → unexpected results.

**Solution**: Mutexes + Atomic writes.

**Test**: `go run -race main.go`.

**In the project**:
- `rebuildMu` protects `rebuildBlocklist` (RACE-1).
- `backupMu` serializes pre-critical backups.
- The logger three-layer split eliminates a latent deadlock on log-rotation failure.

### 8.3 Web & Security Terms

#### PWA — Progressive Web App

**Web app** that can be installed on the home screen like a normal app.

**Requirements**:
- `manifest.json` — description and icons.
- `sw.js` — Service Worker.
- HTTPS or localhost.

**In the project**: Works on `http://127.0.0.1:9090`.

**Install-button evolution**:
- Browser-adaptive `beforeinstallprompt` flow (early releases).
- Direct `<a download href="/app-debug.apk">` link (v1.4.0).
- Install-method modal (IDX-24) offering three actions across two categories (v1.5.0+). See `REFERENCE.md` §3.13.

#### Service Worker (SW)

**Script that runs in the background** — controls network and storage.

**Functions**:
- Caching (offline support).
- Intercepting requests.
- Update notifications.

**In the project**: `web/sw.js` — manages Cache + detects updates.

**⚠️ Dual-origin limitation**: SW is bound to a single origin (9090 ≠ 9091).

**Bypass rule 9**: The `/app-debug.apk` path is bypassed by the SW. The browser's HTTP cache is the correct storage layer for a ~3 MB download (served with `Cache-Control: public, max-age=3600, immutable` by `main.go`).

**v1.6.0 note**: `CACHE_VERSION` in `sw.js` was bumped to `v1.6.0`. This forces clients to discard their old cache and re-fetch the new assets (including the timezone-fixed `index.html`). Without this bump, the WebUI timezone fix would not reach existing clients.

#### SSE — Server-Sent Events

**Unidirectional HTTP connection** — server pushes updates to client.

**Difference from WebSocket**:
- ✅ SSE: Simple, unidirectional (server → client).
- ⚠️ WebSocket: Complex, bidirectional.

**In the project**: `/events` endpoint — sends service status, progress, statistics.

**SSE Write Deadline**: 30 s (DoS protection).

#### CSP — Content-Security-Policy

**HTTP header** that restricts resource sources (Scripts, Styles, Images).

**Purpose**: Prevent XSS attacks.

**Example from the project**:
```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'
```

**⚠️ Note**: `'unsafe-inline'` is currently present (planned for removal in a future release — see `docs/ROADMAP.md` §2.1 item 1).

**`web/offline.html` has NO CSP meta**: The page's own scripts would be silently blocked by a restrictive `default-src 'none'`.

#### CSRF — Cross-Site Request Forgery

**Attack that tricks the browser** into sending an unwanted request (using the victim's cookies).

**Example**:
```html
<img src="http://127.0.0.1:9090/api/toggle_service">
<!-- If opened from a malicious site → executes! -->
```

**Solution in the project**: **CSRF-GET Protection** — all state endpoints → POST only.

**Additional**: The install endpoint requires a **one-shot CSRF token** (60 s TTL, single-use, localhost-only). See `REFERENCE.md` §2.2.7.

#### XSS — Cross-Site Scripting

**Attack that injects malicious JavaScript** into a web page.

**Solution**:
- `escapeHtml()` on all outputs.
- Strict CSP.
- `textContent` instead of `innerHTML`.

#### CORS — Cross-Origin Resource Sharing

**HTTP header** that allows or blocks access from different domains.

**In the project**: `Same-Origin` only (no actual CORS).

#### COOP — Cross-Origin-Opener-Policy

**Header that protects against side-channel attacks** (like Spectre).

**Value**: `same-origin` (no sharing with other windows).

#### CORP — Cross-Origin-Resource-Policy

**Header that prevents external pages** from loading project resources.

**Value**: `same-origin`.

#### SameSite — SameSite Cookie Attribute

**Cookie value** that determines when it is sent across cross-site requests.

| Value | Top-level GET | Cross-site POST | Note |
|---|:---:|:---:|---|
| `None` | ✅ | ✅ | Dangerous |
| `Lax` | ✅ | ❌ | Balanced |
| `Strict` | ❌ | ❌ | Breaks PWA shortcuts |

**In the project**: `Lax` (balanced between security and PWA support).

#### HttpOnly

**Cookie attribute** that prevents JavaScript from reading it.

**Benefit**: Even if XSS exists, it cannot steal the session.

#### Clickjacking

**Attack that places the page in a transparent iframe** and tricks the user into clicking.

**Solution**: `X-Frame-Options: DENY` (present in the project).

### 8.4 Android & Root Terms

#### Root

**Superuser privileges** (like `sudo` on Linux).

**Without it**: The module cannot modify iptables or system settings.

#### Magisk

**Most popular Android root tool** — systemless modification.

**Features**:
- Supports Systemless Modules.
- Hides root from apps (MagiskHide/DenyList).

**In the project**: Supported from 20.4+.

**Note**: install cascade strategy 4 (`magisk su -c "pm install"`) is Magisk-only. It is skipped on KernelSU/APatch — the cascade continues with the other four strategies.

#### KernelSU

**Modern alternative to Magisk** that works in kernel space.

**Advantages**: Less detectable, faster.

**In the project**: Supported from 0.9.0+.

#### APatch

**Another alternative** combining KernelSU and kernel patching.

**In the project**: Supported (latest).

#### Module

**ZIP package** installed via Magisk/KernelSU/APatch.

**Components**:
- `module.prop` — description and version.
- `customize.sh` — installation script.
- `service.sh` — runs at boot.
- `lib/*.sh` — Layer 0 modular libraries (v1.6.0).
- `boot-mini.sh` — Layer 1 aggregator (v1.6.0).
- `functions.sh` — Layer 2 orchestrator (v1.6.0).
- Optional `web/app-debug.apk` (companion Android app).
- `install_app.sh` (5-level `pm install` cascade), staged at the module root by `customize.sh §[12]`.

**Bootstrap**: `META-INF/com/google/android/update-binary` — the root manager's entry point.

**Extraction**: `customize.sh §[12]` extracts `install_app.sh`, `boot-mini.sh`, and the `lib/*.sh` modules to the module root (not under `proxy/`). All are verified as critical files by `customize.sh §[16]`.

#### ROM

**Modified operating system** (historically Read-Only Memory).

**Examples**: LineageOS, Pixel Experience, MIUI, OneUI.

#### Kernel

**System kernel** — manages hardware and processes.

**Common Android versions**: 3.10, 4.4, 4.14, 5.4, 5.15.

**In the project**: Requires 3.10+.

#### API Level

**Android version number** (for programming).

| Android | API |
|---|:---:|
| 5.0 | 21 |
| 10 | 29 |
| 14 | 34 |
| 15 | 35 |

**In the project**: Minimum API 21 (Android 5.0).

**Note**: install cascade strategy 5 (`cmd package install`) requires **Android 8.0+** (API 26). On older versions the cascade skips it and uses strategies 1–4.

#### ABI / Architecture

**Processor architecture** — determines the appropriate binaries.

| ABI | Description |
|---|---|
| `arm64-v8a` | ARM 64-bit (modern) |
| `armeabi-v7a` | ARM 32-bit |
| `x86_64` | Intel 64-bit |
| `x86` | Intel 32-bit |

**In the project**: Supports all four.

#### SELinux

**Android's mandatory access control framework.** Every file has a security context; `system_server` can only read files with specific contexts.

**Staging context**: `install_app.sh` copies the APK to `/data/local/tmp/dnscrypt-companion.apk` (context `shell_data_file`), which `system_server` **can** read.

**Hard rule**: **`setenforce 0` is never called** by this project.

#### PackageManager

**Android's package installation service.** The `pm` shell command and the `cmd package` shell entrypoint are front-ends to it.

**In the project**: The install cascade invokes PackageManager via 5 strategies (see `REFERENCE.md` §3.13). Android verifies the APK's package signature regardless of which strategy succeeds.

### 8.5 Project-Specific Terms

#### `lib/` Directory

**Modularized shell library** introduced in v1.6.0.

**Contents** (Layer 0):
- `constants.sh` — Single source of truth (paths, ports, TOML parsers).
- `fallbacks.sh` — Standalone primitives (port checks, config readers).
- `process.sh` — `/proc`-based process management.
- `http.sh` — Unified HTTP client (curl → wget cascade).
- `backup.sh` — User-data preservation, transaction management, rotation.
- `firewall.sh` — nftables/iptables management for DNS redirection.

**Architecture**: See §1.4 (Layered Bootstrap).

**Why**: To improve maintainability, avoid code duplication, and adhere to the Single Responsibility Principle. Before v1.6.0, the 5 primitives were duplicated across 7+ shell scripts — a single change required a manual sweep of every copy.

**CI guard**: `ci.yml` Step 9 verifies all 6 modules are present and that `functions.sh` does not redefine any Layer-0 primitive.

#### Unix Timestamp

**A time representation** that counts the number of seconds since 00:00:00 UTC on 1 January 1970.

**Usage in v1.6.0**: The WebUI timezone fix. The backend sends `last_update_unix` to the frontend, which uses `new Date(unix * 1000).toLocaleString()` to render the time in the device's local timezone, solving the UTC display bug.

**Contrast with RFC3339**: RFC3339 strings with a `Z` suffix (`"2026-11-12T04:03:46Z"`) are also timezone-agnostic, but they require the client to parse the string and convert to local time. A Unix timestamp is a single number — trivially convertible in JavaScript via `new Date(seconds * 1000)`.

**Why both are kept in `get_profile`**: The `last_update_unix` field is new in v1.6.0 and is preferred by the frontend. The `last_update` (RFC3339) field is kept for backward compatibility with v1.5.0 clients that do not understand the new field.

#### `toLocaleString()`

**JavaScript method** on the `Date` object that returns a string representation of the date in the specified locale and timezone.

**Usage in v1.6.0**:
```javascript
new Date(unix * 1000).toLocaleString(
    currentLang === 'ar' ? 'ar-EG' : 'en-US',
    { year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hour12: false }
);
```

**Behavior**: The browser uses the device's configured timezone automatically. A user in Yemen (UTC+3) sees `2026/11/12 07:03:46` even if the backend sent `1794456226` (which is `04:03:46` UTC).

**Why locale matters**: `ar-EG` renders Arabic numerals (`٢٠٢٦/١١/١٢`) and RTL layout. `en-US` renders Latin digits in LTR. Both respect the device's timezone.

#### Timezone-Agnostic

**A property of data** that does not depend on any timezone. Unix timestamps are timezone-agnostic because they represent an absolute instant in time. RFC3339 strings with a `Z` suffix are also timezone-agnostic (they explicitly indicate UTC).

**Contrast**: A string like `"2026-11-12 04:03:46"` without a timezone indicator is timezone-ambiguous — it could mean any of 24+ possible instants. The WebUI displayed such strings in v1.5.0, which caused the timezone bug fixed in v1.6.0.

#### STATUS_FILE

**File that represents "User Intent"**.

**Values**:
- `ON` — User wants the service running.
- `OFF` — User stopped it manually.

**Written only by** `startService()` / `stopService()` (and by the `disable` path in `service.sh`).

**Path**: `proxy/run/dnscrypt.status`.

#### User Intent

**Architectural concept** — what the user actually wants (not the actual system state).

**Difference**:
- **User intent**: `ON` (for example).
- **Actual state**: May be `OFF` (due to crash).

**Benefit**: Watchdog relies on intent for restart.

#### Watchdog

**Standalone process** that monitors WebUI and DNS Engine and restarts them on failure.

**In the project**: `watchdog.sh` — runs with exponential backoff.

- Separate DNS backoff + reset on STATUS_FILE change.
- Logs active profile + memory hint at startup.
- Sends `X-Watchdog-Token` header to `/api/ensure_running_service`. Reads the token from `$RUN_DIR/.watchdog_token` on every call (no cache). Read-only with respect to the backup directory.
- **Does not participate in the companion install flow.**

#### Audit Correction

**Numbered security or architectural fix** (#1, #17, ...).

**Registry ceiling**:
- v1.0.0: **33** entries.
- v1.1.0 – v1.6.0: **No new entries**. The registry remains at #33.

**Full registry**: `SECURITY.md` §15.

#### Hotfix

**Quick fix** for an existing release — without adding features.

**Format**: `vX.Y.Z` (PATCH bump).

**In the current context**: A hotfix from `v1.6.0` would be `v1.6.1` (PATCH release via `scripts/release-patch.sh`).

#### Allowlist

**Whitelist** — domains excluded from blocking.

**Example**:
```text
googleadservices.com
s.youtube.com
*.whatsapp.net
```

A pre-critical backup is created before each save.

#### Denylist

**Blacklist** — domains with additional blocking.

**Example**:
```text
facebook.com
tiktok.com
```

A pre-critical backup is created before each save.

#### Profile

**Profile file** that determines the protection level (Blocklist).

**5 levels**:

| Profile | Entries | Soft limit |
|---|---:|---:|
| `light` | ~40K | 80 MB |
| `normal` | ~120K | 100 MB |
| `pro` (default) | ~250K | 120 MB |
| `proplus` | ~350K | 160 MB |
| `ultimate` | ~500K | 220 MB |

The profile choice is preserved by the 10 defensive layers (it lives in `selected_profile.txt`, one of the 5 preserved files).

#### Credentials

**Login credentials** (username + password) for WebUI/Dashboard.

**Automatically generated** in `customize.sh` during installation.

**Saved in**: `[monitoring_ui]` in `dnscrypt-proxy.toml`.

**Also present** in the persistent backup at `/sdcard/dnscrypt-webui-backup/current/dnscrypt-proxy.toml`.

#### Port Guard

**Security measure** that rejects port 8080 assignment.

**Reason**: Port 8080 is reserved for `[monitoring_ui]` in `dnscrypt-proxy.toml`.

**Applied in**: 8 files (`main.go` + 7 shell scripts: `customize.sh`, `functions.sh`, `boot-mini.sh`, `action.sh`, `status.sh`, `service.sh`, `watchdog.sh`).

#### `_MONITORING_UI_PORT`

**Shell-side constant** for the reserved `monitoring_ui` port (`8080`).

**Defined in**: `lib/constants.sh` (Layer 0).

**Mirrored in**: `main.go` as `MONITORING_UI_PORT`.

**Consumed by**: `customize.sh`, `functions.sh`, `action.sh`, `status.sh`, `service.sh`, `watchdog.sh`.

**Single source of truth**: Before v1.5.0, the constant was duplicated across 7 shell scripts. The Layered Bootstrap moved it to `boot-mini.sh` in v1.5.0, and then to `lib/constants.sh` in v1.6.0 as part of the modularization.

**CI guard**: `ci.yml` Step 10 verifies both the shell value (`lib/constants.sh`) and the Go value (`main.go`) are `"8080"`.

**Fallback**: `boot-mini.sh §[4]` sets `_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because `lib/constants.sh` may fail to source during a partial extraction. `customize.sh` inherits the value by sourcing `boot-mini.sh`. This is the **sole documented fallback**; `ci.yml` Step 10 rejects any other redeclare.

#### Layered Bootstrap

**Architectural pattern** (Phase 0) that splits the shell library into three files/layers with an explicit dependency direction — see `docs/adr/0003-layered-bootstrap.md`.

**Three layers**:

| Layer | File | Contents |
|---|---|---|
| **Layer 0** | `lib/*.sh` (6 modules) | Constants, fallbacks, process, http, backup, firewall. Zero dependencies |
| **Layer 1** | `boot-mini.sh` | Aggregator: sources `lib/*.sh`, sets up PATH, log rotation |
| **Layer 2** | `functions.sh` | Advanced runtime functions. Sources `boot-mini.sh` |

**Caller scripts unchanged** — `service.sh`, `action.sh`, `status.sh`, `watchdog.sh`, `uninstall.sh`, `post-fs-data.sh`, `customize.sh` still source `functions.sh`.

**CI enforcement**: `ci.yml` Step 9 fails the build if a module is missing from `lib/`, if `functions.sh` doesn't source `boot-mini.sh`, or if `functions.sh` redefines a Layer-0 primitive.

**Local check**: `make check-boot-mini`.

#### `filepath-securejoin`

**External Go dependency** — `github.com/cyphar/filepath-securejoin v0.7.0`.

**First and only external Go dependency** in the project.

**Purpose**: Safely join a trusted base directory with an untrusted path component. Introduced to close two CodeQL `go/path-injection` alerts in `removeModule`.

**Scope**: Exactly one call site — `removeModule` in `proxy/main.go`:
```go
name := filepath.Base(modulePath)
cleanPath, err := securejoin.SecureJoin(MODULES_DIR, name)
```

**Pinned in**: `proxy/go.mod` + `proxy/go.sum`.

**Compliance rule**: Any future external dependency requires its own ADR (per `docs/adr/0002-external-dependency.md`).

#### APK Mirror (`apk/` subfolder)

**Best-effort copy** of the companion APK at `/sdcard/dnscrypt-webui-backup/apk/`.

**Created by**: `customize.sh §[27]` at install time.

**Contents**:
- `app-debug.apk`
- `app-debug.apk.sha256` (if present in the module ZIP)

**Two independent rotation protections**:
1. **Name skip** — every `rotate_backups` and `list_snapshots` implementation contains `apk` in its `case` skip statement.
2. **Manifest absence** — the `apk/` subfolder has no `.manifest.json`, so ROT-MANIFEST excludes it.

**Mode**: `0755` (public asset — same file as `GET /app-debug.apk`).

**Survives uninstall**: `uninstall.sh` explicitly preserves the `apk/` subfolder.

**Removal**: Manual — `su -c "rm -rf /sdcard/dnscrypt-webui-backup/apk"`.

#### Companion Install Flow

**End-to-end flow** that installs the companion Android app from the WebUI with a single tap.

**Entry point**: The **Install App** button (`#pwaInstallBtn`) in the WebUI header.

**Sequence**:
1. `handleCompanionInstall()` → `GET /api?action=install_token` (60 s TTL one-shot CSRF token).
2. Show the **install-method modal (IDX-24)**.
3. User chooses one of three actions:
   - **Install locally** → `POST /api/install_companion_app` → `install_app.sh` → 5-level `pm install` cascade.
   - **Open GitHub page** → external browser tab.
   - **Direct download** → external browser download.
4. On success → toast "✅ Companion app installed", button becomes "✅ Installed".
5. On failure → error modal with localized AR/EN message + hint + **⬇️ Download manually** fallback button.

#### Install-Method Modal (IDX-24)

**WebUI modal** that replaces the v1.4.0 direct `<a download>` link.

**Structure** (two categories, three actions):

| Category | Action | What it does |
|---|---|---|
| **Local** | Install locally | `POST /api/install_companion_app` → `install_app.sh` → 5-level `pm install` cascade |
| **GitHub** | Open GitHub page | `window.open()` → companion repo release page |
| **GitHub** | Direct download | `window.open()` → APK download URL built from `companionState.expected_version` |

**Backdrop-click guard**: The shared backdrop-click handler in `index.html` checks `installModalActive` before closing — a stray tap outside the modal MUST NOT dismiss it, because every valid exit path is responsible for resetting `companionInstallInFlight`.

#### 5-Level pm install Cascade

**Install strategy** used by `install_app.sh`. Tries **5 levels** in order; the first success wins.

| Level | Command | Notes |
|:-:|---|---|
| **1** | `pm install -r --user 0 <apk>` | Direct install as the current user |
| **2** | `pm install -r --user 0 -i com.android.shell <apk>` | Shell-attributed (MIUI/HyperOS) |
| **3** | Session-based (`install-create` + `install-write` + `install-commit`) | Same API Google Play uses |
| **4** | `magisk su -c "pm install -r <apk>"` | Magisk-only — skipped on KernelSU/APatch |
| **5** | `cmd package install -r <apk>` | Android 8.0+ only — skipped on older |

**After each strategy**: The script polls `pm list packages` for up to 15 s.

#### One-Shot CSRF Token

**Single-use token** required by `POST /api/install_companion_app`.

**Characteristics**:

| Aspect | Value |
|---|---|
| Entropy | 32 bytes → 64 hex (256-bit) |
| TTL | 60 seconds (`INSTALL_TOKEN_TTL`) |
| Single-use | Yes (deleted on first successful use) |
| Comparison | `subtle.ConstantTimeCompare` |
| Localhost-only | Yes |
| Rate-limited | Yes (only the POST endpoint) |
| Persisted | ❌ Memory only |

#### Per-IP Install Rate Limit

**Rate limiter** on `POST /api/install_companion_app`.

**Parameters**:

| Parameter | Value |
|---|---|
| Attempts | 5 (`MAX_INSTALL_ATTEMPTS`) |
| Lockout | 15 minutes (`INSTALL_LOCKOUT_PERIOD`) |
| Per | IP (IPv6-safe via `getClientIP`) |
| Reset on success | Yes |
| Lockout response | HTTP 429 + `{"status":"error","action":"install","reason":"rate_limited",...}` |

**Separate from login**: Uses a dedicated `installAttempts` map.

#### SELinux Staging

**Mechanism** for making the APK readable by `system_server`.

**Problem**: `/data/adb/` has SELinux context `adb_data_file`, which `system_server` **cannot read**.

**Fix**: Copy the APK to `/data/local/tmp/dnscrypt-companion.apk` — SELinux context `shell_data_file`, readable by `system_server`.

**Hard rule**: **`setenforce 0` is never called**. SELinux is never disabled.

**Cleanup**: The staged APK is removed on every catchable exit path by the three-way `EXIT`/`INT`/`TERM` trap.

#### Play Protect Trap

**Temporary disable + restore** of the package verifier during the install cascade.

**Capture values**:
- `"1"` — was **enabled** → restore `1`.
- `"0"` — was **disabled** → restore `0`.
- `"null"` — key unset → `settings delete` on restore.
- `""` (read failure) — do not touch.

**Duration**: Bounded by the 75-second cascade deadline.

#### 75-Second Cascade Deadline

**Wall-clock deadline** for the entire `install_app.sh` cascade.

**Constant**: `CASCADE_DEADLINE_SECONDS = 75`.

**Why 75 s**:
- Strictly less than `main.go`'s `INSTALL_TIMEOUT = 90 s`.
- Ensures the `EXIT`/`INT`/`TERM` trap always fires before the parent process kills the script with SIGKILL (uncatchable — the Play Protect verifier would remain disabled).

**Per-strategy cap**: `STRATEGY_TIMEOUT = 20 s`.

#### `install_app.sh`

**Shell script** that performs the 5-level `pm install` cascade.

**Source location**: `install_app.sh` (repository root).

**Staged location**: **module root** (`$MODDIR/install_app.sh`) — staged by `customize.sh §[12]`.

**Resolved by**: `main.go`'s `getInstallScript()` via `filepath.Join(MODDIR, INSTALL_SCRIPT_REL)`.

**Modes**:

| Invocation | Output |
|---|---|
| `install_app.sh` (no args) | Install (JSON) |
| `install_app.sh --status` | Status (JSON) |
| `install_app.sh --uninstall` | Uninstall (JSON) |
| `install_app.sh --version` | Version (text) |
| `install_app.sh --help` | Help (text) |

**Exit codes**:

| Code | Meaning |
|:---:|---|
| 0 | Success |
| 1 | APK missing / corrupt / SHA256 mismatch |
| 2 | All install strategies failed, or uninstall failed |
| 3 | Invalid arguments |
| 4 | Not installed (`--uninstall` / `--status` only) |
| 130 | Interrupted by SIGINT (128 + 2) |
| 143 | Terminated by SIGTERM (128 + 15) |

#### Localhost Gate

**Security control** — all three install surfaces are **localhost-only**, checked **before** authentication.

**Applied to**:
- `POST /api/install_companion_app`.
- `POST /api/uninstall_companion_app`.
- `GET /api?action=install_token`.

**Implementation**: `isLocalRequest()` uses `net.IP.IsLoopback()`.

#### Logger Three-Layer Split

**Go refactor** in `main.go` that eliminates a latent deadlock on log-rotation failure.

**Structure**:

| Layer | Function | Contract |
|---|---|---|
| **1** | `logWithLevel(level, msg)` | Public entry point. Applies level filter, acquires `logMutex`, delegates to `logLocked`. |
| **2** | `logLocked(level, msg)` | Internal. **MUST** be called with `logMutex` held. Performs rotation, delegates to `writeLocked`. |
| **3** | `writeLocked(level, msg)` | Internal. **MUST** be called with `logMutex` held. Writes a single formatted line. |

#### Port Cache

**Go refactor** that adds a 30-second TTL cache to `webui.conf` port reads.

**Structure**: `portConfMu` (`sync.RWMutex`) + `readConfPortCached()` helper.

**Behavior**:
- `getWebUIPort()` and `getDashboardPort()` route through `readConfPortCached(key, defaultPort, which)`.
- Two **independent** slots (`webui` and `dashboard`).
- `CONF_PORT_CACHE_TTL = 30 * time.Second`.

#### `isLocalRequest()` (M-1)

**Go function** in `main.go` that reports whether the request originated from the loopback interface.

**Uses `net.IP.IsLoopback()`** — correctly accepts:
- Any `127.0.0.0/8` address.
- IPv4-mapped IPv6 forms like `::ffff:127.0.0.1`.
- `::1` (IPv6 loopback).

Rejects non-IP inputs via `net.ParseIP` (fail-closed).

#### `HTTP_WRITE_TIMEOUT`

**Go constant** in `main.go` — `150 * time.Second`.

**Purpose**: Bounds the entire response-writing phase of every HTTP request.

**Why 150 s**:
- The `install_companion_app` handler has a server-side budget of `INSTALL_TIMEOUT = 90 s`.
- `HTTP_WRITE_TIMEOUT` must be **strictly greater** than `INSTALL_TIMEOUT` + serialization + network drain.
- **150 s leaves 60 s of headroom**.

#### `INSTALL_TIMEOUT`

**Go constant** in `main.go` — `90 * time.Second`.

**Purpose**: Bounds the `exec.CommandContext` call that runs `install_app.sh`.

**Relationship to other timeouts**:

| Level | Value | Source |
|---|:-:|---|
| Client (WebUI) | 120 s | `web/index.html` `getTimeoutForUrl()` |
| HTTP WriteTimeout | 150 s | `main.go` `HTTP_WRITE_TIMEOUT` |
| Server handler | 90 s | `main.go` `INSTALL_TIMEOUT` |
| Cascade (script) | 75 s | `install_app.sh` `CASCADE_DEADLINE_SECONDS` |

### 8.6 Common Abbreviations

| Abbreviation | Meaning |
|:---:|---|
| **ABI** | Application Binary Interface |
| **ACL** | Access Control List |
| **ADR** | Architecture Decision Record |
| **API** | Application Programming Interface |
| **APK** | Android Package Kit |
| **CI/CD** | Continuous Integration / Deployment |
| **CORS** | Cross-Origin Resource Sharing |
| **COOP** | Cross-Origin-Opener-Policy |
| **CORP** | Cross-Origin-Resource-Policy |
| **CSP** | Content-Security-Policy |
| **CSRF** | Cross-Site Request Forgery |
| **CRLF** | Carriage Return + Line Feed |
| **DNAT** | Destination Network Address Translation |
| **DNS** | Domain Name System |
| **DoH** | DNS over HTTPS |
| **DoS** | Denial of Service |
| **DoT** | DNS over TLS |
| **FUSE** | Filesystem in Userspace |
| **GC** | Garbage Collector / Collection |
| **HTTP** | Hypertext Transfer Protocol |
| **HTTPS** | HTTP Secure |
| **IDX** | Frontend state-fix identifier |
| **IP** | Internet Protocol |
| **JSON** | JavaScript Object Notation |
| **JWT** | JSON Web Token |
| **LMK** | Low Memory Killer |
| **MTP** | Media Transfer Protocol |
| **NAT** | Network Address Translation |
| **OOM** | Out Of Memory |
| **PWA** | Progressive Web App |
| **RBAC** | Role-Based Access Control |
| **RMW** | Read-Modify-Write |
| **RSS** | Resident Set Size |
| **SAST** | Static Application Security Testing |
| **SBOM** | Software Bill of Materials |
| **SemVer** | Semantic Versioning |
| **SELinux** | Security-Enhanced Linux |
| **SSE** | Server-Sent Events |
| **SSRF** | Server-Side Request Forgery |
| **SW** | Service Worker |
| **TLS** | Transport Layer Security |
| **TOML** | Tom's Obvious Minimal Language |
| **TTL** | Time To Live |
| **UDP** | User Datagram Protocol |
| **UI** | User Interface |
| **UTC** | Coordinated Universal Time |
| **XHR** | XMLHttpRequest |
| **XSS** | Cross-Site Scripting |
| **YAML** | YAML Ain't Markup Language |

### 8.7 Fixes Index

The **Audit Corrections Registry** lives in `SECURITY.md` §15 (currently at **#33**; next expected **#34** in a future release).

The **v1.2.0 runtime additions** (BAK-1..BAK-4, FIX-1, FIX-2, WD-TOKEN), **v1.3.0 features** (SNAP-*/ROT-*), **v1.4.0 integration** (companion app, CodeQL fix), **v1.5.0 Global Edition** (companion install flow, Layered Bootstrap, `filepath-securejoin`, APK mirror, frontend fixes, backend corrections), and **v1.6.0 Architecture & UX** (`lib/` modularization, timezone fix, PWA cache bump, DNS version bump to 2.1.20, `buildBackupInfo` mtime sort) are documented in `CHANGELOG.md`.

**See also**:
- `CHANGELOG.md` §[v1.0.0] through §[v1.6.0] — version history
- `SECURITY.md` §15 — full audit corrections registry
- `SECURITY.md` §5.31–§5.36 — security-relevant changes per version

### 8.8 Contributing

Found a missing term? Or an unclear definition?
- 🐛 **Open an Issue** titled `[Docs] Glossary: term X`.
- 🔧 **Submit a PR** directly to add it.
- 📖 Follow the existing formatting style.
- ✅ Make sure to add the appropriate section (8.1–8.7).
- 🌐 **Arabic translation**: glossary is English-only by project convention.

**Adding a term for a new release**: also:
- Reference the corresponding `CHANGELOG.md` entry.
- Cross-reference `SECURITY.md` §5.31–§5.36 or the relevant section of `REFERENCE.md` where applicable.
- Update §8.7 (Fixes Index) if the term is a fix or correction.

---

## 9. File Layout

The repository and runtime file layouts are documented in **§1.8 of this file**:
- **§1.8.1** — Runtime layout (module installed on device, including `$MODDIR`, `$MODDIR/lib/`, `$MODDIR/proxy/`, `$MODDIR/web/`, `$MODDIR/proxy/run/`, and `/sdcard/dnscrypt-webui-backup/`).
- **§1.8.2** — Repository layout (84 tracked files, 0–11 build artifacts).
- **§1.8.3** — File count by directory (three canonical states: fresh clone, after package, after full build).

**Why this section exists separately**: §1.8 is the authoritative source for file counts and paths. This §9 entry exists so that readers searching for "file layout" land on a cross-reference rather than duplicating the content. See `docs/MAP.md` §2 Rule 3 (One home per fact).

For the same three-state model, see `README.md` §Project Structure. The documentation map — the 12 user-facing files plus `docs/MAP.md` itself — is defined in `docs/MAP.md` §1.

**Quick cross-check — reproducible with three commands**:

```bash
git ls-files | wc -l
find . -type f -not -path './.git/*' | wc -l
find . -type d -not -path './.git/*' -not -name '.git' | wc -l
```

---

*End of REFERENCE.md.*

*This file is the single consolidated technical reference for DNSCrypt Smart Filter. It merges seven source files — the former `ARCHITECTURE.md`, `API.md`, `BACKUP.md`, `COMPATIBILITY.md`, `DNS_BINARIES.md`, `MANIFEST_NOTES.md`, and `GLOSSARY.md` — into one document.*

*For end-user documentation, see `docs/GUIDE.md`. For contribution workflow, see `docs/CONTRIBUTING.md`. For the security model, see `SECURITY.md`. For version history, see `CHANGELOG.md`.*