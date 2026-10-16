# DNSCrypt Smart Filter

*Last updated: 2026-10-15 — v1.5.0 (Global Edition)*

System-wide DNS filtering for Android devices, built on DNSCrypt and dnscrypt-proxy.

[![CI](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml/badge.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-v1.5.0-blue.svg)](https://github.com/gasciljh/dnscrypt-proxy-webui/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%205%2B-brightgreen.svg)](https://www.android.com/)
[![Magisk](https://img.shields.io/badge/Magisk-20.4%2B-orange.svg)](https://github.com/topjohnwu/Magisk)
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-purple.svg)](https://kernelsu.org/)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8.svg)](https://go.dev/)
[![Android App](https://img.shields.io/badge/Android%20App-v1.0.0-3DDC84.svg)](https://github.com/gasciljh/dnscrypt-proxy-app)

> **📖 Project documentation**:
> - Git workflow → [`docs/BRANCHING.md`](docs/BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md)
> - Architecture Decisions → [`docs/adr/README.md`](docs/adr/README.md)
> - Backup system → [`docs/BACKUP.md`](docs/BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](docs/EMERGENCY.md)
> - Manifest technical notes → [`docs/MANIFEST_NOTES.md`](docs/MANIFEST_NOTES.md)
> - Version history → [`CHANGELOG.md`](CHANGELOG.md)
>
> **🎯 Current version**: **v1.5.0** — Companion app one-tap install.
> Released 2026-10-13.

> **v1.5.0 adds**: a **one-tap root install** for the companion
> Android app. The WebUI install button opens an **install-method
> modal** (IDX-24) offering **three actions across two categories**:
> a local `pm install` (via `proxy/install_app.sh`, a 5-level cascade
> bounded by a 75-second deadline), plus two GitHub fallbacks
> (open release page + direct APK download). The companion button
> state now **survives language toggles** (IDX-23), the **status
> card** updates instantly on language switch (IDX-23b), and the
> Dashboard section-nav "Runtime Info" / "Diagnostic Files" buttons
> now scroll correctly (IDX-25) with a **centered hint toast** when
> the target card is collapsed (IDX-25a).
>
> **v1.5.0 Phase 0**: the shell layer was split into **Layer 0**
> (`proxy/boot-mini.sh`) and **Layer 1** (`proxy/functions.sh`).
> The five primitives (`log_msg`, `get_run_dir`, `read_conf`,
> `is_port_open`, `get_webui_port`) and `_MONITORING_UI_PORT` now
> live in one place. CI guards against drift.

> **v1.4.0 added**: a **companion Android app** bundled into the
> module ZIP as an OPTIONAL asset (`web/app-debug.apk`). **CodeQL
> path-injection alerts** in `removeModule` (proxy/main.go) were
> closed via `filepath.Base()` sanitization + `filepath-securejoin`
> (see ADR-0007). **iOS PWA logic is removed** (Android-only
> project).

> **v1.3.0 added**: a **smart dynamic PWA install button**, a
> **live status LED** on the Today counter, **DNS auto-start after
> boot** (bounded wait + direct API call in `service.sh`), plus
> **server-side refinements** in `main.go` and `functions.sh`.

> **v1.2.0 added**: the **10 defensive layers** for user-data
> preservation — persistent backup at
> `/sdcard/dnscrypt-webui-backup/`, multi-source detection,
> transactional installs with rollback, recovery mode, SHA256
> integrity verification, SELinux context preservation.

> **v1.1.0 added**: dynamic Go runtime memory limit per blocklist
> profile (light=80 MB → ultimate=220 MB), extended `shellQuote`,
> and the `MONITORING_UI_PORT` constant.

See [`CHANGELOG.md`](CHANGELOG.md) for the full v1.5.0 changelog.

---

## Overview

DNSCrypt Smart Filter is a Magisk / KernelSU / APatch module that turns an
Android device into a filtered, encrypted DNS resolver.

- Local DNS engine on `127.0.0.1:5354` (DNSCrypt / DoH)
- Transparent redirection of port 53 traffic to the local engine
- Multi-level blocklists (HaGeZi Light → Ultimate)
- Allowlist / Denylist with a browser editor
- Bilingual WebUI (English default + Arabic toggle)
- Separate monitoring Dashboard with JSON metrics
- Installable PWA with offline fallback
- **v1.1.0**: Dynamic Go runtime memory limit per blocklist profile
- **v1.2.0**: 10 defensive layers for user-data preservation
- **v1.3.0**: Smart dynamic PWA install button + live status LED +
  DNS auto-start after boot
- **v1.4.0**: Companion Android app integrated — a native WebView
  wrapper (~3 MB) bundled into the module ZIP as an OPTIONAL asset
  (`web/app-debug.apk`). CodeQL path-injection alerts in
  `removeModule` closed via `filepath-securejoin` (ADR-0007).
- **v1.5.0 Phase 0**: Layered Bootstrap — Layer-0 shell primitives
  extracted into `proxy/boot-mini.sh`.
- **v1.5.0**: One-tap root install for the companion app via
  `proxy/install_app.sh` (5-level `pm install` cascade, bounded by
  a 75-second deadline) with an install-method modal (IDX-24)
  offering three actions across two categories.

Works at the system level — no per-app configuration, no VPN.

### 📱 Optional Android App

For a native experience without requiring a browser, install
the companion app:

**→ [dnscrypt-proxy-app v1.0.0](https://github.com/gasciljh/dnscrypt-proxy-app/releases/tag/v1.0.0)**

| Feature | Details |
|---|---|
| Size | ~3 MB |
| Stack | Kotlin + WebView |
| Min Android | 5.0 (API 21) |
| Browser required | ❌ No |
| Telemetry | ❌ None |

**Installation paths (v1.5.0)**:

1. **One-tap root install** (recommended) — Click the **Install App**
   button in the WebUI. An install-method modal (IDX-24) opens;
   choose **"Install locally"**. The server runs
   `proxy/install_app.sh`, which tries a 5-level `pm install`
   cascade bounded by a 75-second deadline. Requires root and the
   APK to be present in the module ZIP.
2. **Download from GitHub** — In the same modal, choose **"Open
   GitHub page"** (opens the release page) or **"Direct download
   from GitHub"** (downloads the APK). Useful for devices without
   root or when the root flow is blocked.
3. **Direct APK path** — Fallback: the route `GET /app-debug.apk`
   remains available if all install strategies fail.

The companion app is fetched by `scripts/fetch_app_apk.sh` from the
[dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)
repository and staged at `web/app-debug.apk` before packaging. Its
version is pinned in `proxy/app-apk.version` (currently `1.0.0`, no
`v` prefix). As of v1.5.0, the APK is also mirrored (best-effort) to
`/sdcard/dnscrypt-webui-backup/apk/` by `customize.sh §[10c]`, and
its `.sha256` is staged alongside it at `web/app-debug.apk.sha256`.

---

## Requirements

### Mandatory

| Requirement | Minimum |
|---|---|
| Android | 5.0 (API 21) |
| Root | Magisk 20.4+ / KernelSU 0.9+ / APatch |
| Kernel | 3.10+ |
| RAM | 1 GB |
| Storage (`/data`) | ~20 MB free |
| Storage (`/sdcard`) | **~6 MB free** — persistent backup ≈ 2.5 MB + APK mirror ≈ 3 MB (see [Storage on /sdcard](#storage-on-sdcard-v120)) |
| Architecture | `arm64-v8a` / `armeabi-v7a` / `x86_64` / `x86` |

> **Note on `/sdcard`**: the `~6 MB` figure is the sum of the two
> steady-state contributors (backup ≈ 2.5 MB + APK mirror ≈ 3 MB)
> plus a small safety margin. If your device has less than 6 MB free
> on `/sdcard`, the backup layer degrades gracefully — see
> [`docs/BACKUP.md`](docs/BACKUP.md) §5 for the failure semantics.

### Recommended by Profile (v1.1.0)

The Go runtime soft memory limit is computed per profile by `main.go`.

| Device RAM | Recommended profile | WebUI soft limit | Filtered entries |
|---|:---:|---:|---:|
| 1 GB | Light | 80 MB | ~40,000 |
| 2 GB | Normal | 100 MB | ~120,000 |
| 3 GB | **PRO** (default) | 120 MB | ~250,000 |
| 4 GB | PRO++ | 160 MB | ~350,000 |
| 6 GB+ | Ultimate | 220 MB | ~500,000 |

### Incompatible with

- AdAway (port conflict)
- VPN apps (routing conflict)
- SuperSU (legacy)

---

## Installation

1. Download `dnscrypt-webui-1.5.0-module.zip` from
   [Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases/latest).
2. Install via Magisk Manager / KernelSU Manager / APatch.
3. Save the credentials shown on-screen (also stored at
   `/data/local/tmp/dnscrypt_credentials.txt`).
4. Reboot.
5. Open `http://127.0.0.1:9090` and log in.
6. Select a blocklist profile and press **Apply**.
7. (v1.5.0) Optionally install the companion app: click **Install App**
   in the WebUI header → **"Install locally"** for a root install, or
   choose a GitHub option.

The installer (`customize.sh`) prints the expected memory limit for your
active profile during installation (v1.1.0), mirrors the companion APK
to `/sdcard/dnscrypt-webui-backup/apk/` (v1.5.0, best-effort), and runs
the 10 defensive layers described below (v1.2.0).

### Data preservation (v1.2.0)

The installer runs **10 defensive layers** to protect your 5 user
config files:

- **Layer 1** — Multi-source detection (7 candidate locations).
- **Layer 2** — Persistent backup to `/sdcard/dnscrypt-webui-backup/`.
- **Layer 3** — SHA256 integrity verification (advisory).
- **Layer 4** — Transactional install with automatic rollback.
- **Layer 5** — Root-solution compatibility (Magisk / KernelSU / APatch).
- **Layer 6** — SELinux context preservation.
- **Layer 7** — Recovery mode (trigger file).
- **Layer 8** — Config migrations.
- **Layer 9** — Auto-backup (24 h) + rotation (max 21 snapshots).
- **Layer 10** — Observability (`status.sh --diagnose` + 7-field
  `runtime_info.backups`).

**What is preserved**:

- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

**Where it lives**: `/sdcard/dnscrypt-webui-backup/` — survives
reboot and module uninstall. A factory reset of `/data` (including
the standard "wipe data/factory reset" in recovery) **will** wipe
`/sdcard` on modern Android, since `/sdcard` is a FUSE mount over
`/data/media/<userId>`. Only recoveries that offer an explicit
"preserve `/data/media`" step avoid this. Keep an off-device copy
of any backup you cannot afford to lose.

### Companion app install flow (v1.5.0)

The WebUI install button opens an install-method modal (IDX-24)
offering **three actions across two categories**:

| Category | Action | Path | Requires |
|---|---|---|---|
| **Local** | **Install locally** (recommended) | `POST /api/install_companion_app` → `proxy/install_app.sh` → 5-level `pm install` cascade | Root; APK present in module ZIP |
| **GitHub** | **Open GitHub page** | `window.open()` → `https://github.com/gasciljh/dnscrypt-proxy-app` | Internet |
| **GitHub** | **Direct download from GitHub** | `window.open()` → `.../releases/download/v<app_version>/app-debug.apk` | Internet |

The **local install path** is a 5-level cascade:

1. `pm install -r --user 0 <apk>`
2. `pm install -r -i com.android.shell <apk>`
3. Session-based (`install-create` + `install-write` + `install-commit`)
4. `magisk su -c "pm install -r <apk>"`
5. `cmd package install -r <apk>`

The APK is staged to `/data/local/tmp/` first (to avoid SELinux
`avc: denied` errors on `/data/adb/`), and the Play Protect verifier
is temporarily disabled during the install. **SELinux is never
disabled.**

**Cascade deadline**: the 5-level cascade is bounded by a
**75-second wall-clock deadline** (`CASCADE_DEADLINE_SECONDS = 75`).
The deadline is deliberately shorter than the server-side
`INSTALL_TIMEOUT = 90 s` (in `main.go` §[3b]), so the `EXIT / INT /
TERM` trap always fires before `main.go`'s context deadline kills
the script — guaranteeing the Play Protect verifier is restored.

**Rate limiting**: 5 **failed** attempts / 15 min per IP.

**CSRF**: one-shot token (60-second TTL) from
`GET /api?action=install_token`.

**Fallback**: if all strategies fail, the UI offers a link to
`/app-debug.apk` (direct download).

If the APK is absent from the build (e.g. a local developer build
without a network fetch), the route returns 404 and the modal's
local install path fails cleanly — the rest of the WebUI continues
to work normally.

**Exit codes** (`install_app.sh`):

| Code | Meaning |
|:---:|---|
| 0 | Success |
| 1 | APK missing / corrupt / SHA256 mismatch |
| 2 | All install strategies failed (install) OR uninstall failed |
| 3 | Invalid arguments |
| 4 | Not installed (`--uninstall` / `--status` only) |
| 130 | Interrupted by SIGINT (128 + 2) |
| 143 | Terminated by SIGTERM (128 + 15) |

> **Cache notes (v1.5.0)**:
> - `web/app-debug.apk` and `web/app-debug.apk.sha256` are **not
>   tracked by git** — they are build artifacts (see `.gitignore`
>   §[20]).
> - The APK is **not precached by the Service Worker**. It is
>   served with a long-lived `Cache-Control` header by `main.go`;
>   the browser's own HTTP cache is the primary storage layer.
> - The GitHub URLs are external origins and are bypassed by the
>   Service Worker (rule 1).

---

## Ports

| Port | Service | Configurable |
|:----:|---|---|
| 9090 | WebUI | `webui.conf` → `PORT` |
| 9091 | Dashboard | `webui.conf` → `DASHBOARD_PORT` |
| 8080 | monitoring_ui (internal) | fixed |
| 5354 | DNS engine (internal) | fixed |

Port `8080` is reserved. `main.go` refuses to start if `PORT` or
`DASHBOARD_PORT` conflicts with it. Port values outside `[1, 65535]`
fall back to defaults.

---

## Blocklist Profiles

| Profile | Source | Approximate entries | WebUI soft limit (v1.1.0) |
|---|---|---:|---:|
| Light | HaGeZi Light | ~40,000 | 80 MB |
| Normal | HaGeZi Normal | ~120,000 | 100 MB |
| PRO | HaGeZi PRO | ~250,000 | 120 MB |
| PRO++ | HaGeZi PRO++ | ~350,000 | 160 MB |
| Ultimate | HaGeZi Ultimate | ~500,000 | 220 MB |

Source: [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists).

---

## Architecture

```text
User Apps → :53 (DNS)
    ↓
iptables / ip6tables / nftables
(Custom Chains: DNSCRYPT_OUT / DNSCRYPT_OUT6)
    ↓
dnscrypt-proxy :5354
    ├── blocklist.txt (local filter)
    └── DNSCrypt / DoH (encrypted upstream)

WebUI :9090     ← HTTP / SSE ←────── browser
Dashboard :9091 ← /api/metrics (JSON proxy)
                  → monitoring_ui :8080

Companion install (v1.5.0):
    WebUI button ──▶ install-method modal (IDX-24)
        ├──▶ local: POST /api/install_companion_app
        │             └──▶ proxy/install_app.sh
        │                    └──▶ 5-level `pm install` cascade
        │                         (bounded by 75 s deadline)
        ├──▶ GitHub page  (external)
        └──▶ GitHub APK   (external, direct download)

Persistent Backup :/sdcard/dnscrypt-webui-backup/
    ← 10 defensive layers (v1.2.0)
    ← protects the 5 user config files
    ← survives reboot and module uninstall
    ← apk/ subfolder mirrors web/app-debug.apk (v1.5.0)

Companion APK: web/app-debug.apk   (build artifact — gitignored)
    ← served at /app-debug.apk
    ← fetched by scripts/fetch_app_apk.sh
    ← NOT precached by the Service Worker

Shell layout (v1.5.0 Phase 0 — Layered Bootstrap):
    proxy/boot-mini.sh  (Layer 0 — 5 primitives + constant)
            ↑ sourced by
    proxy/functions.sh  (Layer 1 — advanced functions)
            ↑ sourced by
    service.sh / action.sh / status.sh / watchdog.sh /
    uninstall.sh / post-fs-data.sh / customize.sh
```

Components:

| Component | Language | Role |
|---|---|---|
| `proxy/main.go` | Go | HTTP server, auth, blocklist rebuild, metrics proxy, dynamic memory limit, pre-critical backups, watchdog token, `/app-debug.apk` route, CodeQL-hardened `removeModule`, 4 companion-app endpoints + 10 helpers |
| `proxy/install_app.sh` | Shell (BusyBox) | 5-level `pm install` cascade + SELinux staging + Play Protect disable (bounded by 75 s deadline) + 7 AR/EN error translations + SHA256 advisory + `$_VERIFIER_ORIG` restore on trap |
| `proxy/boot-mini.sh` | Shell (BusyBox) | **Layer 0 primitives (v1.5.0 Phase 0)**: `log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`, `_MONITORING_UI_PORT`. Zero dependencies |
| `proxy/*.sh` | Shell (BusyBox) | Install, service lifecycle, watchdog, firewall, backup helpers, rotation rewrite, APK mirror, Layer-1 |
| `web/` | HTML / CSS / JS | WebUI, Dashboard, PWA (bilingual EN/AR), install-method modal, state fixes |
| `scripts/` | Bash | Build, packaging, DNS binaries fetcher, companion APK fetcher, release automation |

---

## Project Structure

```text
dnscrypt-proxy-webui/          # 97 tracked files + 0-11 build artifacts (97-108 total)
├── .editorconfig                    # EditorConfig rules (LF, indent, charset)
├── .gitattributes                   # Git attributes (LF enforcement, export-ignore)
├── .gitignore                       # Git ignore rules (build, secrets, IDE, APK)
├── .pre-commit-config.yaml          # Pre-commit hooks
├── .secrets.baseline                # detect-secrets baseline
├── .shellcheckrc                    # ShellCheck configuration
├── CHANGELOG.md                     # Version history
├── CODE_OF_CONDUCT.md               # Contributor Covenant v2.1
├── LICENSE                          # MIT License
├── Makefile                         # Unified commands (+ check-boot-mini)
├── module.prop                      # Magisk/KernelSU definition
├── README.md                        # Overview (EN)
├── SECURITY.md                      # Security policy (root summary)
├── update.json                      # Auto-update metadata
├── VERSION                          # Single source of truth (v1.5.0)
│
├── .github/                         # CI/CD (13 files + 4 subdirs = 17 entries)
│   ├── CODEOWNERS                   # Auto-assign reviewers
│   ├── dependabot.yml               # Dependency updates
│   ├── SECURITY.md                  # Security policy (summary)
│   ├── PULL_REQUEST_TEMPLATE.md     # Default PR template
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── release.md               # Release-specific PR template
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml           # Bug report template
│   │   ├── config.yml               # Issue template chooser
│   │   └── feature_request.yml      # Feature request template
│   ├── codeql/                      # CodeQL configuration
│   │   └── codeql-config.yml        # CodeQL config
│   └── workflows/
│       ├── ci.yml                   # Build matrix + verify install_app.sh + verify boot-mini.sh
│       ├── codeql.yml               # Security scanning (SAST)
│       ├── release.yml              # Signed release + stage APK + .sha256
│       └── upgrade-test.yml         # 42-scenario data-preservation matrix
│
├── .devcontainer/                   # Unified dev environment (2 files)
│   ├── devcontainer.json            # VS Code Dev Container config
│   └── setup.sh                     # Auto-install dev tools
│
├── META-INF/                        # Magisk bootstrap (2 files)
│   └── com/google/android/
│       ├── update-binary            # Magisk entry point
│       └── updater-script           # "#MAGISK" marker
│
├── scripts/                         # Build & release tools (6 files)
│   ├── fetch_dns_binaries.sh        # DNS binaries fetcher
│   ├── fetch_app_apk.sh             # Companion APK fetcher
│   ├── generate-icons.sh            # PNG/ICO icon generator
│   ├── package_module.sh            # Build Magisk ZIP (bundles boot-mini.sh)
│   ├── release.sh                   # Stable / Prerelease automation
│   └── release-patch.sh             # PATCH-only (hotfix) automation
│
├── proxy/                           # Backend (Go + Shell) — 18 tracked files
│   ├── action.sh                    # Magisk Action button
│   ├── app-apk.version              # Companion app version (1.0.0)
│   ├── boot-mini.sh                 # Layer 0 primitives (v1.5.0 Phase 0)
│   ├── build.sh                     # 4-arch cross-compile
│   ├── customize.sh                 # Magisk installer (10 layers + APK mirror)
│   ├── dnscrypt-proxy.toml          # DNSCrypt engine config
│   ├── dnscrypt-proxy.version       # DNS binary version (2.1.18)
│   ├── functions.sh                 # Layer 1 shell library (sources boot-mini.sh)
│   ├── go.mod                       # Go module definition (1 dep — filepath-securejoin)
│   ├── go.sum                       # Go dependency checksums
│   ├── install_app.sh               # 5-level pm install cascade (v1.5.0)
│   ├── main.go                      # HTTP server (4 companion-app endpoints)
│   ├── post-fs-data.sh              # Early boot cleanup
│   ├── service.sh                   # Boot service + periodic auto-backup
│   ├── status.sh                    # Status display (+ --diagnose/--json)
│   ├── uninstall.sh                 # Cleanup + orphan txn preservation
│   ├── watchdog.sh                  # Standalone watchdog (token auth)
│   └── webui.conf                   # WebUI/Dashboard config
│
├── web/                             # Frontend (PWA, bilingual EN/AR) — 13 tracked + 2 artifacts
│   ├── apple-touch-icon.png         # Launcher icon fallback
│   ├── dashboard.html               # Monitoring dashboard (IDX-25, IDX-25a)
│   ├── favicon.ico                  # IE + bookmarks
│   ├── favicon-16x16.png            # Legacy favicon
│   ├── favicon-32x32.png            # Modern favicon
│   ├── icon-192.png                 # PWA icon (PNG)
│   ├── icon-192.svg                 # PWA icon (SVG)
│   ├── icon-512.png                 # PWA icon (maskable PNG)
│   ├── icon-512.svg                 # PWA icon (maskable SVG)
│   ├── index.html                   # Main UI (install-method modal)
│   ├── manifest.json                # PWA manifest (version=1.5.0, 5 x-note fields)
│   ├── offline.html                 # Offline fallback page
│   ├── sw.js                        # Service Worker (CACHE_VERSION=v1.5.0)
│   ├── [app-debug.apk]              # ← build artifact, gitignored
│   └── [app-debug.apk.sha256]       # ← build artifact, gitignored
│
├── dist/                            # ← entire directory is gitignored
│   ├── [dnscrypt-webui-<version>-module.zip]
│   └── [dnscrypt-webui-<version>-module.zip.sha256]
│
└── docs/                            # Documentation (19 + 9 in adr/ = 28 files)
    ├── adr/                         # Architecture Decision Records (9 files)
    │   ├── README.md                # ADR index + template + methodology
    │   ├── 0001-two-branch-model.md
    │   ├── 0002-automated-releases.md
    │   ├── 0003-post-release-sync.md
    │   ├── 0004-unified-pr-template.md          (⚠️ Superseded)
    │   ├── 0005-release-specific-pr-template.md
    │   ├── 0006-rename-hotfix-to-release-patch.md
    │   ├── 0007-external-dependency-securejoin.md   # ← v1.4.1
    │   └── 0008-layered-bootstrap.md            # ← v1.5.0
    │
    ├── API.md                       # HTTP API reference
    ├── ARCHITECTURE.md              # System architecture
    ├── BACKUP.md                    # Backup system reference
    ├── BRANCHING.md                 # Git branching strategy
    ├── COMPATIBILITY.md             # Device compatibility matrix
    ├── CONTRIBUTING.md              # Contribution guide
    ├── DEVELOPMENT.md               # Developer guide
    ├── DNS_BINARIES.md              # DNS binaries management
    ├── EMERGENCY.md                 # Emergency recovery
    ├── FAQ.md                       # Common questions
    ├── GLOSSARY.md                  # Terms & abbreviations
    ├── HALL_OF_FAME.md              # Contributors recognition
    ├── INSTALL.md                   # Installation guide
    ├── MANIFEST_NOTES.md            # Manifest technical notes (v1.5.0)
    ├── RELEASE_PROCESS.md           # Release process guide
    ├── ROADMAP.md                   # Future plans
    ├── SECURITY.md                  # Threat model + disclosure
    ├── TROUBLESHOOTING.md           # Troubleshooting guide
    └── UPGRADE.md                   # Version upgrade guide
```

> **`dist/` clarification**: the `dist/` directory is **entirely
> gitignored** — not just the files inside it. Any file placed under
> `dist/` (release ZIPs, checksums, staging output) is invisible to
> `git status`, `git ls-files`, and the GitHub tree view. The names
> shown above use the placeholder `<version>` because the exact file
> name changes at every release (e.g.
> `dnscrypt-webui-1.5.0-module.zip` for the current release).
>
> The same rule applies to the two `web/app-debug.apk*` artifacts:
> they are gitignored individually via `.gitignore` §[20], not
> because of a parent-directory rule.

**File count** (v1.5.0 — verified against `git ls-files` and `find`):

| Category | Count | Notes |
|---|:---:|---|
| **Tracked files** | **97** | `git ls-files \| wc -l` — canonical; matches GitHub |
| **Build artifacts** | **0–11** | gitignored; varies by local build state |
| **Working tree total** | **97–108** | `find . -type f \| wc -l` (excluding `.git/`) |
| **Directories** | **15–18** | `find . -type d \| wc -l` (excluding `.git/`) |

**The three canonical states** (all reproducible from a fresh clone):

| State | When | Tracked | Artifacts | Working tree | Dirs |
|---|---|:---:|:---:|:---:|:---:|
| **Fresh clone** | After `git clone` | 97 | 0 | 97 | 15 |
| **After package** | After `make fetch-apk && make package` | 97 | 4 | 101 | 17 |
| **After full build** | After `make build` | 97 | 11 | 108 | 18 |

**The 4 artifacts of the "package" state**:

- `dist/dnscrypt-webui-<version>-module.zip`
- `dist/dnscrypt-webui-<version>-module.zip.sha256`
- `web/app-debug.apk`
- `web/app-debug.apk.sha256`

**The 7 additional artifacts of the "full build" state**:

- `proxy/build/dnscrypt-webui-{arm64,arm,amd64,386}` (4 binaries)
- `proxy/build/checksums.txt`
- `proxy/build/.build-arm.log`
- `proxy/build/.build-386.log`

All 11 artifacts are ignored by `.gitignore`. The **tracked** count
(97) is fixed and does not depend on the local build state.

**Per-directory breakdown of the 97 tracked files**:

| Directory | Tracked | Notes |
|---|:---:|---|
| Root | **15** | Version + config + governance + hidden configs + `.shellcheckrc` |
| `.github/` | **13** | CI + templates + CodeQL config (4 additional subdirectories) |
| `.devcontainer/` | **2** | Dev environment |
| `META-INF/` | **2** | Magisk bootstrap |
| `scripts/` | **6** | Build + release tooling |
| `proxy/` | **18** | Go + Shell (includes `boot-mini.sh` and `install_app.sh`) |
| `web/` (tracked) | **13** | 5 HTML/JSON/JS + 8 icons |
| `docs/` (files only) | **19** | Documentation guides (includes `MANIFEST_NOTES.md`) |
| `docs/adr/` | **9** | ADR-0001..0008 + README |
| **Total** | **97** | **Committed to the repository** |

**Cross-check** — reproducible with three commands:

```bash
git ls-files | wc -l                                    # 97
find . -type f -not -path './.git/*' | wc -l            # 97 / 101 / 108
find . -type d -not -path './.git/*' -not -name '.git' | wc -l   # 15 / 17 / 18
```

The same three-state model is shared by `docs/ARCHITECTURE.md`
§8.2–§8.3 and `web/manifest.json`'s `x-note-companion-apk` field.

**The 7 tracked files added in v1.5.0**:

- `.shellcheckrc`
- `.github/codeql/codeql-config.yml`
- `docs/adr/0007-external-dependency-securejoin.md`
- `docs/adr/0008-layered-bootstrap.md`
- `docs/MANIFEST_NOTES.md`
- `proxy/boot-mini.sh`
- `proxy/go.sum`

---

## CLI Commands

```bash
# Full status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# JSON status (includes 7-field backups object in v1.2.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

# One-line status (includes profile + memory hint in v1.1.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# Full diagnostic report (v1.2.0 — Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"

# Restart WebUI
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# Manual backup (v1.2.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# Comprehensive check (DNS + WebUI + profile + memory + backup)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --check"

# Companion app install status (v1.5.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh --status"

# Direct companion app install (v1.5.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh"

# Uninstall companion app (v1.5.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh --uninstall"

# Show install_app.sh version (v1.5.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh --version"

# Show install_app.sh help — full mode reference + exit codes (v1.5.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/install_app.sh --help"
```

---

## Configuration

`proxy/webui.conf`:

```
PORT=9090
DASHBOARD_PORT=9091
BIND_ADDR=127.0.0.1
AUTO_RESTART_DNS=1
AUTO_RESTART_WEBUI=1
LOG_LEVEL=info
```

Rules:

- No spaces around `=`
- No trailing comments on the same line
- `PORT` and `DASHBOARD_PORT` must differ
- `BIND_ADDR=0.0.0.0` requires credentials set in
  `dnscrypt-proxy.toml` → `[monitoring_ui]`

`proxy/dnscrypt-proxy.toml` controls the DNS engine itself (listen
addresses, resolver selection, cache, blocklists, monitoring UI).
Credentials for the internal monitoring UI live in `[monitoring_ui]`.

### Persistent Backup Directory (v1.2.0, extended v1.5.0)

```
/sdcard/dnscrypt-webui-backup/
├── current/                          # live mirror (always up-to-date)
├── <timestamp>-<version>-<pid>/      # install snapshot
├── <timestamp>-manual-<pid>/         # manual snapshot
├── <timestamp>-auto-<pid>/           # periodic snapshot
├── txn-<timestamp>-<pid>/            # in-flight transaction
├── orphan-txn-<timestamp>-<pid>/     # preserved interrupted install
├── apk/                              # companion APK mirror (v1.5.0)
│   ├── app-debug.apk                 # ← best-effort copy of web/app-debug.apk
│   └── app-debug.apk.sha256          # ← SHA256 (if present in ZIP)
├── .last_stable                      # recovery pointer
├── .last_auto_backup                 # periodic marker (mtime)
├── .upgrade_history.json             # upgrade log
└── README.md                         # user guide
```

Permissions: `0700` on directories, `0600` on files (owned by root).
The `apk/` subfolder is created with `0755` (no explicit mode in
`customize.sh §[10c]`). Rotation: keeps the 21 newest snapshots,
sorted by **mtime** descending with `.last_stable` and
newest-install protection. The `apk/` subfolder is preserved by two
independent mechanisms (no `.manifest.json`, explicit `case` skip).

### Shell library layout (v1.5.0 Phase 0 — Layered Bootstrap)

The module's shell code is split into two layers:

| Layer | File | Contents |
|---|---|---|
| **Layer 0** | `proxy/boot-mini.sh` | `log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`, `_MONITORING_UI_PORT`. Zero dependencies |
| **Layer 1** | `proxy/functions.sh` | Every other shell helper (firewall, backups, cleanup, WebUI launcher, TOML reader, ...). Sources `boot-mini.sh` at load time |

**Callers** (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`,
`uninstall.sh`, `post-fs-data.sh`, `customize.sh`) source
`functions.sh` as before — nothing changes at the call site.

**Why two files**: before Phase 0 the five primitives were duplicated
across 7+ shell scripts. A single change (e.g. adding SNAP-MANIFEST
in v1.3.0 or `apk/` in v1.5.0) required a manual sweep of every copy.
The Layer-0 file makes the primitives a single source of truth.

**Local verification**: `make check-boot-mini` runs the same checks
that CI runs, and `make check-all` includes it.

### Go module (v1.4.1+)

`proxy/go.mod` declares the WebUI backend module:

```go
module dnscrypt-webui

go 1.22

require github.com/cyphar/filepath-securejoin v0.7.0
```

- **Exactly ONE external dependency** (`filepath-securejoin`,
  authorized by [ADR-0007](docs/adr/0007-external-dependency-securejoin.md)).
- **`proxy/go.sum`** pins the dependency + its 4 test-only
  transitive deps. Auto-generated by `go mod tidy` — must not be
  edited by hand.
- **v1.5.0 added no new external dependency** — `go.mod` and
  `go.sum` are functionally unchanged from v1.4.1.

---

## HTTP API

All endpoints on `http://127.0.0.1:9090` unless noted.

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| GET | `/healthz` | No | Liveness check |
| GET | `/readyz` | Localhost only | Readiness check |
| GET | `/app-debug.apk` | No | Companion Android app APK — returns 404 when absent |
| GET | `/api?action=status` | Yes | Service status (ON / OFF) |
| GET | `/api?action=get_profile` | Yes | Current profile + entry count + `memory_limit_mb` |
| GET | `/api?action=get_custom_rules` | Yes | Allowlist + Denylist content |
| GET | `/api?action=runtime_info` | Yes | Build info + ports + `profile_key` + `memory_limit_mb` + `backups` object |
| GET | `/api?action=logs` | Yes | Last log lines |
| GET | `/api?action=list_logs` | Yes | List diagnostic files |
| GET | `/api?action=companion_app_state` | Yes | Companion app install state — 30-second cache |
| GET | `/api?action=install_token` | Yes | One-shot CSRF token for companion install — 60-second TTL |
| GET | `/events` | Yes | SSE stream |
| GET | `/api/metrics` | Yes | Dashboard JSON (port 9091) |
| POST | `/api/auth/login` | No | Login (POST-only) |
| POST | `/api/auth/logout` | Yes | Logout (POST-only) |
| POST | `/api/update_profile` | Yes | Update blocklist (+ pre-critical backup) |
| POST | `/api/save_allowlist` | Yes | Save allowlist (+ pre-critical backup) |
| POST | `/api/save_denylist` | Yes | Save denylist (+ pre-critical backup) |
| POST | `/api/save_custom_rules` | Yes | Save both (+ pre-critical backup) |
| POST | `/api/append_denylist` | Yes | Append to denylist (requires `content` param) |
| POST | `/api/toggle_service` | Yes | Toggle DNS engine |
| POST | `/api/restart_service` | Yes | Restart DNS engine |
| POST | `/api/ensure_running_service` | Watchdog token | Ensure DNS running |
| POST | `/api/install_companion_app` | Yes + CSRF token | Install companion app via root — 5 attempts / 15 min rate limit |
| POST | `/api/uninstall_companion_app` | Yes | Uninstall companion app — reserved for future UI |

### `runtime_info.backups` (v1.2.0)

A 7-field object:

```json
{
  "available": 5,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-29 15:00:00",
  "last_backup_name": "20260929-150000-manual-12345",
  "last_stable": "20260929-095826-v1.2.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

Full reference: [`docs/API.md`](docs/API.md) §6.1.7.

### `companion_app_state` (v1.5.0)

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

### `install_token` (v1.5.0)

```json
{
  "token": "abc123def456...",
  "ttl": 60
}
```

---

## Security

Applied protections:

**Authentication**

- BIND_ADDR defaults to `127.0.0.1`; public binds require credentials
- Login POST-only (CSRF protection)
- Basic Auth rate limiting (5 attempts / 15 minutes)
- Constant-time password comparison (`subtle.ConstantTimeCompare`)
- HttpOnly session cookies with `SameSite=Lax`
- CSRF-GET protection on state-changing endpoints
- Watchdog token (`X-Watchdog-Token`) on `ensure_running_service`
- One-shot CSRF token (60-second TTL) on
  `install_companion_app`

**Headers**

- Strict CSP, `X-Frame-Options: DENY`, `nosniff`, COOP, CORP

**Input validation**

- `MaxBytesReader` (5 MB) on all POST bodies
- `/readyz` restricted to localhost
- `shellQuote()` on all dynamic shell paths
- `readConfPort()` range check (1–65535)
- `removeModule` routes the caller-provided path through
  `filepath.Base()` + `filepath-securejoin.SecureJoin`
- `install_app.sh` uses a hardcoded APK path and `shellQuote()` on
  all paths. No user-controlled data reaches any path expression.

**Firewall**

- Custom iptables / ip6tables chains (no orphan rules)
- nftables support via `dnscrypt_filter` table
- IPv4/IPv6 separation (no cross-protocol contamination)

**State & concurrency**

- STATUS_FILE represents user intent (not process state)
- `rebuildMu` mutex serializes blocklist rebuilds (RACE-1)
- `backupMu` mutex serializes pre-critical backups
- `installTokens` + `installAttempts` mutexes — CSRF token store +
  per-IP rate limiter
- Auth cache (60 s) reduces file I/O

**Data preservation (v1.2.0)**

- 10 defensive layers for user config files
- Persistent backup directory with `0700`/`0600` permissions
- SHA256 integrity verification (advisory)
- Transactional install with rollback
- Recovery mode via trigger file
- SELinux context preservation (`restorecon` / `chcon`)

**Companion install hardening (v1.5.0)**

- **SELinux**: staging to `/data/local/tmp/` (context
  `shell_data_file`) — **SELinux is never disabled**
- **Play Protect**: temporarily disabled during install and restored
  on exit (via a three-way `EXIT / INT / TERM` trap). The cascade is
  bounded by a **75-second deadline** so the trap always fires before
  `main.go`'s 90-second `INSTALL_TIMEOUT` kills the script. The trap
  restores the exact captured value (`$_VERIFIER_ORIG`).
- **SHA256**: verified against `web/app-debug.apk.sha256` if present;
  otherwise advisory mode
- **Rate limit**: 5 failed attempts / 15 min per IP
- **Localhost only**: `isLocalRequest()` gate on all three install
  surfaces (install, uninstall, install_token)
- **Audit log**: full install log in `dnscrypt_main.log`

**Public static asset**

- `/app-debug.apk` is served without authentication (static asset,
  no secrets). Missing file → 404; existing file → 200 with
  `Cache-Control: public, max-age=3600, immutable`.

Report vulnerabilities privately: [`SECURITY.md`](SECURITY.md).

---

## Performance

### Baseline (all profiles)

| Metric | Value |
|---|---|
| RAM (WebUI idle) | ~15 MB |
| RAM (WebUI peak) | ~25 MB |
| Battery | ~1–2% / day |
| DNS latency (cached) | ~1–5 ms |
| Service startup | ~2–5 s |
| `rebuildBlocklist` (100K entries) | ~200 ms |
| `rebuildBlocklist` (500K entries) | ~1 s |
| Companion install (local root) | ~5–15 s (typical; bounded by 75 s deadline) |

### RAM by Profile (v1.1.0)

| Profile | Soft limit | WebUI RSS (idle) | WebUI RSS (peak) |
|---|---:|---:|---:|
| Light | 80 MB | ~15 MB | ~25 MB |
| Normal | 100 MB | ~15 MB | ~30 MB |
| PRO | 120 MB | ~15 MB | ~35 MB |
| PRO++ | 160 MB | ~15 MB | ~45 MB |
| Ultimate | 220 MB | ~15 MB | ~60 MB |

**Note**: "WebUI RSS" is the actual resident memory of the WebUI
process. The "soft limit" is the ceiling at which the Go runtime
starts running GC more aggressively — it is not the RSS.

The limit is recomputed:

- At startup (in `main()`)
- After every profile change (in `updateProfile()`)

**Observability**:

```bash
# Effective limit for the active profile
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'

# Backup state
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

# Companion app install state
curl -s "http://127.0.0.1:9090/api?action=companion_app_state" | jq
```

### Backup Storage (v1.2.0)

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

### Storage on /sdcard (v1.2.0)

The module writes a single persistent directory on `/sdcard`:
`/sdcard/dnscrypt-webui-backup/`.

| Component | Typical size | Notes |
|---|---:|---|
| **Snapshots** (up to 21) | **~2.5 MB max** | 5 user config files per snapshot (~30–100 KB each) |
| **APK mirror** (`apk/`) | **~3 MB** | One-time copy of `web/app-debug.apk` + `.sha256` |
| **Metadata** | **< 50 KB** | `.last_stable`, `.last_auto_backup`, `.upgrade_history.json`, `README.md`, manifests |
| **`current/` mirror** | **~100 KB** | Live snapshot, atomically replaced |
| **Total (steady state)** | **~5.6 MB** | Sum of the above |
| **Requirement in the table** | **~6 MB** | Total + small safety margin for `txn-*` during an upgrade |

**What is NOT on `/sdcard`:**

- The module itself (`/data/adb/modules/dnscrypt-proxy-webui/`, ~30 MB)
- The DNS engine binaries and WebUI binaries — they live under
  `/data/adb/modules/.../proxy/`
- The Service Worker caches — they live in the browser's
  `Cache Storage`, not on `/sdcard`
- The companion APK inside the module
  (`/data/adb/modules/.../web/app-debug.apk`, ~3 MB) — that copy is
  separate from the `apk/` mirror. It is removed with the module on
  uninstall; the mirror survives.

**What happens when `/sdcard` is full:**

The backup layer degrades gracefully:

1. `ensure_backup_dir()` fails → no new snapshot is created; the
   install/upgrade continues.
2. Existing snapshots are preserved (rotation is not attempted when
   the directory is not writable).
3. The user sees a warning in `dnscrypt_main.log` and in the WebUI
   System Info panel (`backups.available` stops increasing).

No user config file is lost — the primary copies still live under
`/data/adb/modules/dnscrypt-proxy-webui/proxy/`. The backup is a
defense-in-depth layer, not a hard dependency.

Full reference: [`docs/BACKUP.md`](docs/BACKUP.md), especially §5
for the failure semantics and §8 for the retention policy.

### APK mirror size (v1.5.0)

| Metric | Value |
|---|---|
| Size of `apk/app-debug.apk` | ~3 MB |
| Size of `apk/app-debug.apk.sha256` | ~87 B |
| Created by | `customize.sh` §[10c] (best-effort) |
| Recreated on | Every module install/upgrade |
| Rotated? | ❌ No — not a snapshot |
| Removed on uninstall? | ❌ No — preserved with the backup dir |
| Optional? | ✅ Yes — absent if the module ZIP omitted the APK |

If the module ZIP does not contain `web/app-debug.apk` (e.g. a local
developer build), the mirror step is skipped silently and no `apk/`
directory is created. The rest of the module works normally.

---

## Development

```bash
# 1. Clone
git clone https://github.com/gasciljh/dnscrypt-proxy-webui.git
cd dnscrypt-proxy-webui

# 2. Switch to develop (the integration branch)
git checkout develop

# 3. Common commands
make version           # show current version (v1.5.0)
make build             # build all 4 architectures
make package           # build + package
make clean             # clean build outputs
make check-backup      # validate backup shell functions
make check-all         # run all local validations
make fetch-apk         # fetch companion APK into dist/
make check-app-version # verify companion app metadata
make check-install-app # verify install_app.sh
make check-boot-mini   # verify Layer 0 / Layer 1 split
make diagnose-help     # how to run diagnose on a device
make help              # show available targets
```

**Branching**: This project uses `main` (stable releases) + `develop`
(integration). Never commit to `main` directly — open a PR against
`develop`.

**Toolchain**: Go 1.22+, Android NDK r26b+ (for cross-compilation).

**Dependency policy**: the WebUI backend uses the Go standard library
plus **exactly one** external dependency —
`github.com/cyphar/filepath-securejoin v0.7.0` (see
[ADR-0007](docs/adr/0007-external-dependency-securejoin.md)). Any
future external dependency requires its own ADR.

**Full guide**: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

---

## Building

```bash
cd proxy
./build.sh --clean --parallel          # all 4 architectures
./build.sh --single arm64              # one architecture
./build.sh --info                      # environment / NDK info
./build.sh --package                   # binaries ZIP
```

Output: `proxy/build/dnscrypt-webui-{arm64,arm,amd64,386}`.

Reproducible builds via `SOURCE_DATE_EPOCH` (extracted from the last
commit).

---

## Releasing

Releases are automated through two scripts:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `release.sh` | Stable / Prerelease | `develop` or `release/*` | Any |
| `release-patch.sh` | Hotfix (PATCH only) | `main` | PATCH only |

**Stable release** (from `develop`):

```bash
./scripts/release.sh v1.5.0
```

**PATCH release** (from `main`):

```bash
./scripts/release-patch.sh v1.5.1
```

Both scripts:

1. Update version files (VERSION, module.prop, update.json).
2. Create an **annotated** tag (`git tag -a`, not `git tag -s` —
   there is no GPG signing).
3. Push to `origin`.

GitHub Actions (`.github/workflows/release.yml`) then:

1. Fetches the companion APK into `dist/`.
2. Fetches its `.sha256` if available.
3. Stages both at `web/app-debug.apk` + `web/app-debug.apk.sha256`
   before packaging.
4. Builds the module ZIP (includes `proxy/install_app.sh`).
5. Publishes the release with 8 artifacts.
6. **Attempts** to sync `main → develop` (`continue-on-error: true`).

**On the auto-sync**: `release.yml` runs the sync step on every tag
push, regardless of the tag's origin. If the sync succeeds, nothing
is required from you. If it fails (e.g. a real merge conflict),
back-merge manually:

```bash
make sync
```

**Release PRs** (`release/*` or `hotfix/*` → `main`) should use the
release-specific PR template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...<branch>?template=release.md
```

**Validation**: `ci.yml`'s `backup-smoke-test` job validates the 10
defensive layers, and `upgrade-test.yml` runs 42 scenarios before
release. Both jobs also verify `install_app.sh`, the Layer 0 /
Layer 1 split, and the version consistency across 5 files.

Full guide: [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).

---

## Documentation

| File | Purpose |
|---|---|
| [`docs/INSTALL.md`](docs/INSTALL.md) | Installation guide |
| [`docs/FAQ.md`](docs/FAQ.md) | Common questions |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Diagnostics and fixes |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System architecture |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Threat model + Audit Corrections + §18 documentation corrections |
| [`docs/API.md`](docs/API.md) | HTTP API reference |
| [`docs/BACKUP.md`](docs/BACKUP.md) | Backup system reference |
| [`docs/EMERGENCY.md`](docs/EMERGENCY.md) | Emergency recovery |
| [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) | Device compatibility matrix |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Developer guide |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Contribution guidelines |
| [`docs/BRANCHING.md`](docs/BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md) | Release process guide |
| [`docs/MANIFEST_NOTES.md`](docs/MANIFEST_NOTES.md) | Manifest technical notes (maskable, icon pipeline, backup schema, ports, shortcuts) |
| [`docs/adr/README.md`](docs/adr/README.md) | Architecture Decision Records |
| [`docs/adr/0007-external-dependency-securejoin.md`](docs/adr/0007-external-dependency-securejoin.md) | External dependency policy |
| [`docs/adr/0008-layered-bootstrap.md`](docs/adr/0008-layered-bootstrap.md) | Layered Bootstrap Pattern |
| [`docs/UPGRADE.md`](docs/UPGRADE.md) | Version upgrade guide |
| [`docs/DNS_BINARIES.md`](docs/DNS_BINARIES.md) | DNS binaries management |
| [`docs/GLOSSARY.md`](docs/GLOSSARY.md) | Terms and abbreviations |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Future plans |
| [`docs/HALL_OF_FAME.md`](docs/HALL_OF_FAME.md) | Contributors |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community guidelines |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |

---

## Contributing

- **Bug reports** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=bug_report.yml)
- **Feature requests** → [Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues/new?template=feature_request.yml)
- **Pull requests** → follow [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
- **Branch policy** → [`docs/BRANCHING.md`](docs/BRANCHING.md)
- **Architecture decisions** → [`docs/adr/README.md`](docs/adr/README.md)
- **Security reports** → [`SECURITY.md`](SECURITY.md)

**Contribution requirements**:

- Any PR touching the 10 defensive layers must update
  `docs/BACKUP.md` and `docs/EMERGENCY.md`.
- Any new user-facing string must supply both `en` and `ar` entries.
- Any destructive operation on user data must call
  `createAutoBackup(reason)` first.
- Any PR touching `scripts/fetch_app_apk.sh` must keep
  `proxy/app-apk.version` as the single source of truth for the
  companion app version.
- Any PR touching `proxy/install_app.sh` must keep the 5-level
  cascade order intact, must never disable SELinux, and must
  preserve the 75-second cascade deadline. The Play Protect
  temporary-disable block must always restore the original value
  via a `trap`.
- Any PR touching the install-method modal (IDX-24) in
  `web/index.html` must preserve the three existing actions and
  must keep all GitHub URLs pointing at the official
  `gasciljh/dnscrypt-proxy-app` repository.
- Any PR adding an external Go dependency must include its own ADR
  in `docs/adr/`.
- Any PR that changes the set of shell scripts extracted by
  `proxy/customize.sh` §[9] must update the MISSING critical-files
  check in §[10] and the corresponding CI verification step.
- Any PR that adds, removes, or renames a `docs/*.md` file must
  update the Documentation table above and the file-count tables
  in this README.

**Data Guardian badge**: Test the backup/restore system across
3+ devices or 3+ root solutions and submit a report. See
[`docs/HALL_OF_FAME.md`](docs/HALL_OF_FAME.md).

This project follows the
[Contributor Covenant v2.1](CODE_OF_CONDUCT.md).

---

## Related Projects

| Project | Description |
|---|---|
| [**dnscrypt-proxy-app**](https://github.com/gasciljh/dnscrypt-proxy-app) | Native Android WebView wrapper for this WebUI (optional, ~3 MB APK, fetched by `scripts/fetch_app_apk.sh`) |

---

## Credits

- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) — DNS engine
- [HaGeZi DNS Blocklists](https://github.com/hagezi/dns-blocklists) — blocklists
- [Magisk](https://github.com/topjohnwu/Magisk) — module framework
- [KernelSU](https://github.com/tiann/KernelSU) — alternative module framework
- [APatch](https://github.com/bmax121/APatch) — root solution
- [filepath-securejoin](https://github.com/cyphar/filepath-securejoin) — path-injection hardening
- [ShellCheck](https://github.com/koalaman/shellcheck) — shell linting
- [shfmt](https://github.com/mvdan/sh) — shell formatting
- [golangci-lint](https://github.com/golangci/golangci-lint) — Go linting
- [Go runtime/debug](https://pkg.go.dev/runtime/debug#SetMemoryLimit) — for `SetMemoryLimit`
- [Android FUSE documentation](https://source.android.com/docs/core/storage) — for `/sdcard/` mount behavior
- [Android SELinux documentation](https://source.android.com/docs/security/features/selinux) — for `restorecon` / `chcon`
- [Android PackageManager documentation](https://developer.android.com/reference/android/content/pm/PackageManager) — for `pm install`

---

## License

MIT — see [`LICENSE`](LICENSE).

The Code of Conduct is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

---

## Links

### Main module

- Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
- Releases: https://github.com/gasciljh/dnscrypt-proxy-webui/releases
- Issues: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- Discussions: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- Security reports: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new

### Companion app

- Repository: https://github.com/gasciljh/dnscrypt-proxy-app
- Releases: https://github.com/gasciljh/dnscrypt-proxy-app/releases
- Issues: https://github.com/gasciljh/dnscrypt-proxy-app/issues
