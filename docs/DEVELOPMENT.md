# Development Guide — DNSCrypt Smart Filter

> Developer guide: environment setup, building, debugging, and releasing.

**Version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • `§1.2 Architectural Principles` gained 5 entries for the
>     v1.2.0 data-preservation release:
>       - Multi-Source Discovery (Layer 1)
>       - Persistent Backup (Layer 2)
>       - Transactional Upgrade with rollback (Layer 4)
>       - Recovery Mode (Layer 7)
>       - Bilingual WebUI (EN default + AR toggle)
>   • `§4.3 (v1.0.0 / v1.1.0 File Changes)` extended with a
>     v1.2.0 column documenting every file changed during the
>     data-preservation cycle.
>   • `§5.4 Commit Examples` gained 5 examples for the v1.2.0
>     additions:
>       - BAK-1 (7-field `runtime_info.backups`)
>       - BAK-2 (`createAutoBackup` + `backupMu`)
>       - BAK-3 (`cleanupOldTransactions`)
>       - BAK-4 (`checkPendingNotifications`)
>       - FIX-1 (recovery-mode reorder)
>       - FIX-2 (Service Worker update banner)
>   • `§7 CI/CD` updated:
>       - `ci.yml` now runs a `backup-smoke-test` job.
>       - `release.yml` unchanged (no pipeline changes in v1.2.0).
>       - New `.github/workflows/upgrade-test.yml` documented.
>   • `§8 Debugging` extended:
>       - **§8.12 (new)** — v1.2.0 Backup Debugging.
>       - **§8.13 (new)** — Testing the 42-scenario matrix
>         locally.
>       - **§8.14 (new)** — v1.2.0 Bilingual WebUI Debugging.
>   • `§9 Make Targets` extended with three v1.2.0 targets:
>       - `check-backup` — validate the backup shell functions.
>       - `check-all` — run all local validations.
>       - `diagnose-help` — print device-side diagnostic commands.
>   • `§10.8 Golden Rules` gained **Rule #22** — v1.2.0 backup
>     observability requirement — and **Rule #23** — bilingual
>     WebUI string requirement.
>   • `§10.12 Full References` extended with the three new
>     documentation files:
>       - [`docs/BACKUP.md`](BACKUP.md)
>       - [`docs/EMERGENCY.md`](EMERGENCY.md)
>       - [`docs/UPGRADE.md`](UPGRADE.md)
>   • Release examples updated from `v1.2.0` to `v1.3.0`
>     (stable) and `v1.1.1` to `v1.2.1` (PATCH), since v1.2.0 is
>     now the current release.
>   • **Bilingual WebUI note**: the WebUI ships with English as the
>     default language and an in-page toggle (`langToggle`) that
>     switches to Arabic. The user's choice is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **FIX-1 description in §5.4** — The FIX-1 commit example
>     previously described a "reorder + exclude" strategy. The
>     actual implementation in `customize.sh` uses a
>     **snapshot-and-reapply** strategy (`§[8a]` + `§[9]` +
>     `§[9b2]`). The description has been corrected to match the
>     shipped code. See `docs/ARCHITECTURE.md` §3.10 for the flow
>     diagram.
>   • 🔧 **Reason string in §5.4 (BAK-2)** — The BAK-2 commit
>     example previously listed `pre-append-denylist` for the
>     `appendDenylist` call site. The actual reason string
>     recorded by `main.go` is `pre-denylist-save`, because
>     `appendDenylist` delegates to `saveDenylist` (which is
>     where the pre-critical backup is triggered). The example
>     has been corrected.

> **📖 Branching, Release & Decisions**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Publishing a release → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Environment Setup](#2-environment-setup)
3. [Building](#3-building)
4. [Project Structure](#4-project-structure)
5. [Daily Workflow](#5-daily-workflow)
6. [Release](#6-release)
7. [CI/CD](#7-cicd)
8. [Debugging](#8-debugging)
9. [Make Targets](#9-make-targets)
10. [v1.2.0 — Contributor Notes](#10-v120--contributor-notes)

---

## 1. Overview

### 1.1 Toolchain

| Tool | Version | Purpose |
|---|---|---|
| **Go** | 1.22+ | Backend |
| **Android NDK** | r26b+ | Cross-compilation |
| **Make** | 4.0+ | Build orchestration |
| **ShellCheck** | 0.10+ | Shell linting |
| **shfmt** | 3.8+ | Shell formatting |
| **golangci-lint** | v2.5.0+ | Go linting |
| **markdownlint** | latest | Markdown linting |
| **yamllint** | latest | YAML linting |
| **actionlint** | latest | GitHub Actions linting |
| **pre-commit** | 3.5+ | Git hooks |
| **jq** | 1.6+ | JSON manipulation |
| **python3** | 3.8+ | Scripts + validation |
| **zip / unzip** | — | Packaging |

### 1.2 Architectural Principles

- **Zero external deps** — stdlib only.
- **Reproducible builds** — same commit → same binary.
- **Atomic operations** — no half-written files.
- **Fallbacks everywhere** — no silent failure.
- **Custom Chains** — iptables/ip6tables use dedicated chains.
- **User Intent** — `STATUS_FILE` represents user intent, not process state.
- **Section-Restricted TOML** — read from `[monitoring_ui]` only.
- **Platform-Agnostic Shell** — `getSystemShell()` + `sync.Once`.
- **Exact Endpoint Matching** — `hasEndpoint()`.
- **Structured Metrics** — Prometheus → JSON in `metricsProxyHandler`.
- **Login POST-Only** — CSRF protection on `/api/auth/login` and `/api/auth/logout`.
- **`/readyz` Localhost-Only** — info-leak prevention.
- **Shell Injection Protection** — `shellQuote()`.
- **Port Range Validation** — `readConfPort()` accepts `[1, 65535]` only.
- **Serialized Rebuilds** — `rebuildMu` (RACE-1).
- **Dynamic Ports** — `runtime_info` returns actual ports (PORT-2).
- **Auth Cache** — 60 s TTL to reduce I/O (NEW-6).
- **Decision Transparency** — architectural decisions documented as ADRs.
- **Dynamic Memory Limit (v1.1.0 — MEM-1)** — `memoryLimitForProfile()` sets the Go soft memory limit per blocklist profile. Prevents GC thrashing on heavy profiles.
- **Extended `shellQuote` Charset (v1.1.0 — MEM-2)** — covers `{`, `}`, `\n`, `\t` in addition to the 20-char set.
- **Reserved Port Constant (v1.1.0 — MEM-3)** — `MONITORING_UI_PORT` used in the metrics handler, no hardcoded `"8080"`.
- **Multi-Source Discovery (v1.2.0 — Layer 1)** — the installer searches 7 candidate locations for user data. It never asks "is this an upgrade?" — it always asks "where is the user data?".
- **Persistent Backup (v1.2.0 — Layer 2)** — all user config files are snapshotted to `/sdcard/dnscrypt-webui-backup/`, which survives reboot, uninstall, and `/data` reset.
- **Transactional Upgrade (v1.2.0 — Layer 4)** — every install runs inside a `txn-*` directory. On failure, an automatic rollback restores the previous state.
- **Recovery Mode (v1.2.0 — Layer 7)** — a trigger file (`recovery`) restores the last known-good config on next boot.
- **Bilingual WebUI (v1.2.0)** — the WebUI ships with English as the default language and an in-page toggle that switches to Arabic. The user's preference is stored client-side in `localStorage['dnscrypt-lang']`. Documentation remains English-only by project convention.

### 1.3 Architecture Decisions

The decisions that shaped this project are documented as **ADRs**:

| ADR | Decision |
|---|---|
| [ADR-0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) |
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0004](adr/0004-unified-pr-template.md) | Unified PR template (⚠️ Superseded) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

**Current ADR count**: 6 (5 accepted + 1 superseded).

**v1.2.0 note**: No new ADR was added in the v1.2.0 cycle. The
10 defensive layers and 4 runtime additions (BAK-1..BAK-4) are
documented as runtime improvements in
[`docs/SECURITY.md`](SECURITY.md) §5.31 and §17.2, not as
architectural decisions. See
[`docs/adr/README.md`](adr/README.md) §3.3 for the criteria.

Full index: [`docs/adr/README.md`](adr/README.md).

---

## 2. Environment Setup

### 2.1 Clone the Repository

```bash
# 1. Clone
git clone https://github.com/gasciljh/dnscrypt-proxy-webui.git
cd dnscrypt-proxy-webui

# 2. Verify branches
git branch -r
# Expected: origin/main, origin/develop

# 3. Checkout develop (the integration branch)
git checkout develop
git pull origin develop

# 4. Verify
git branch --show-current
# Expected: develop
```

**Important**: Always work on `develop`, never on `main`. See
[`docs/BRANCHING.md`](BRANCHING.md) for details.

### 2.2 Linux (Ubuntu / Debian)

```bash
# Basics
sudo apt update
sudo apt install -y \
    git make curl jq \
    golang-1.22 \
    shellcheck \
    python3 python3-pip \
    zip unzip

# shfmt
curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64" \
    -o /tmp/shfmt
sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt

# golangci-lint v2.5.0
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | \
    sudo sh -s -- -b /usr/local/bin v2.5.0

# actionlint
go install github.com/rhysd/actionlint/cmd/actionlint@latest

# markdownlint (npm)
sudo npm install -g markdownlint-cli

# yamllint + pre-commit
pip3 install --user yamllint pre-commit

# Verify
go version
shellcheck --version
golangci-lint version
```

**Expected output**:

```text
go version go1.22.x
0.10.0
golangci-lint has version 2.5.0
```

### 2.3 macOS

```bash
brew install go make jq shellcheck shfmt golangci-lint
brew install markdownlint-cli yamllint actionlint pre-commit
```

⚠️ **Note**: `golangci-lint` from Homebrew may be v1.x. Verify:

```bash
golangci-lint version
# Must be v2.x

# If v1:
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.5.0
```

### 2.4 Android NDK

```bash
# Method 1: SDK Manager
sdkmanager --install "ndk;26.1.10909125"

# Method 2: Direct download
wget https://dl.google.com/android/repository/android-ndk-r26b-linux.zip
unzip android-ndk-r26b-linux.zip -d ~/android-ndk
export ANDROID_NDK_HOME=~/android-ndk/android-ndk-r26b
```

### 2.5 Termux (Android)

```bash
pkg update
pkg install git make golang shellcheck jq python

# Additional tools
pip install yamllint pre-commit

# Verify
go version
```

⚠️ **Note**: Termux does not fully support `golangci-lint`. Use:

```bash
go vet ./...
gofmt -l .
```

### 2.6 VS Code Configuration

```json
// .vscode/settings.json
{
  "go.useLanguageServer": true,
  "go.lintTool": "golangci-lint",
  "go.lintFlags": ["--fast"],
  "editor.formatOnSave": true,
  "[shellscript]": {
    "editor.defaultFormatter": "foxundermoon.shell-format"
  },
  "shellcheck.enable": true,
  "shellcheck.run": "onType"
}
```

### 2.7 Dev Container (Strongly Recommended)

```bash
# 1. Open the project in VS Code
code .

# 2. F1 → "Dev Containers: Reopen in Container"
# 3. Wait ~2-4 minutes
```

All tools are installed automatically via
`.devcontainer/setup.sh` (including golangci-lint v2.5.0).

---

## 3. Building

### 3.1 Full Build

```bash
# Via Makefile
make build

# Or directly
cd proxy && ./build.sh
```

### 3.2 `build.sh` Options

```bash
./build.sh --help                    # Help
./build.sh --info                    # Environment info
./build.sh --clean --parallel        # Clean parallel build
./build.sh --single arm64            # Single architecture
./build.sh --output-dir /tmp/build   # Custom output dir
./build.sh --keep-logs               # Keep build logs
./build.sh --package                 # Create binaries ZIP
```

### 3.3 Output

```text
proxy/build/
├── dnscrypt-webui-arm64
├── dnscrypt-webui-arm
├── dnscrypt-webui-amd64
├── dnscrypt-webui-386
└── checksums.txt
```

### 3.4 Reproducible Builds

- `SOURCE_DATE_EPOCH` from the last commit.
- `-trimpath` to normalize paths.
- `-buildid=` to remove random signatures.
- **Result**: same commit → same SHA-256.

### 3.5 Build with v1.2.0

Before building, verify the v1.0.0 + v1.1.0 + v1.2.0 features are present:

```bash
cd proxy

# --- v1.0.0 fixes ---
grep -c 'func getSystemShell' main.go            # Expected: 1
grep -c 'func parsePrometheus' main.go           # Expected: 1
grep -c 'func buildDashboardJSON' main.go        # Expected: 1
grep -c 'func hasEndpoint' main.go               # Expected: 1
grep -c 'func shellQuote' main.go                # Expected: 1
grep -c 'func readConfPort' main.go              # Expected: 1

# --- v1.0.0 — no hardcoded shell path ---
! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' main.go
# Expected: success (no result)

# --- v1.0.0 — RACE-1 ---
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' main.go && echo "✅ RACE-1"

# --- v1.0.0 — PORT-2 ---
grep -A30 'func buildRuntimeInfo' main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# --- v1.1.0 — MEM-1 ---
grep -q 'func memoryLimitForProfile' main.go && echo "✅ MEM-1"
grep -q 'func applyMemoryLimit' main.go && echo "✅ MEM-1 (apply)"
grep -q 'MEMORY_LIMIT_ULTIMATE' main.go && echo "✅ MEM-1 (constants)"
! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' main.go && echo "✅ MEM-1 (no hardcoded)"

# --- v1.1.0 — MEM-2 ---
grep -A5 'func shellQuote' main.go | grep -q "'{'" && echo "✅ MEM-2 (braces)"
grep -A8 'func shellQuote' main.go | grep -q "r == '\\\\n'" && echo "✅ MEM-2 (newline)"

# --- v1.1.0 — MEM-3 ---
grep -A5 'func metricsProxyHandler' main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

# --- v1.2.0 — BAK-1 (7-field backups) ---
grep -A30 'func buildBackupInfo' main.go | grep -q 'in_flight_txn' && echo "✅ BAK-1 in_flight_txn"
grep -A30 'func buildBackupInfo' main.go | grep -q 'orphan_txn' && echo "✅ BAK-1 orphan_txn"

# --- v1.2.0 — BAK-2 (createAutoBackup + backupMu) ---
grep -q 'func createAutoBackup' main.go && echo "✅ BAK-2 createAutoBackup"
grep -q 'backupMu' main.go && echo "✅ BAK-2 backupMu"

# --- v1.2.0 — BAK-3 (cleanupOldTransactions) ---
grep -q 'func cleanupOldTransactions' main.go && echo "✅ BAK-3"

# --- v1.2.0 — BAK-4 (checkPendingNotifications) ---
grep -q 'func checkPendingNotifications' main.go && echo "✅ BAK-4"

# --- v1.2.0 — Layer presence in shell scripts ---
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
         begin_transaction rollback_transaction commit_transaction \
         detect_root_solution copy_with_context RECOVERY_TRIGGER \
         migrate_config; do
    grep -q "$L" customize.sh && echo "✅ $L" || echo "❌ $L"
done

# --- Build ---
./build.sh --clean --parallel

# --- Verify checksums ---
cat build/checksums.txt
```

---

## 4. Project Structure

### 4.1 Tree

```text
dnscrypt-proxy-webui/
├── .editorconfig                    # EditorConfig rules (LF, indent, charset)
├── .gitattributes                   # Git attributes (LF enforcement, export-ignore)
├── .gitignore                       # Git ignore rules (build, secrets, IDE)
├── .pre-commit-config.yaml          # Pre-commit hooks
├── .secrets.baseline                # detect-secrets baseline
├── CHANGELOG.md                     # Version history
├── CODE_OF_CONDUCT.md               # Contributor Covenant v2.1
├── LICENSE                          # MIT License
├── Makefile                         # Unified commands
├── module.prop                      # Magisk/KernelSU definition
├── README.md                        # Overview
├── SECURITY.md                      # Security policy (root summary)
├── update.json                      # Auto-update metadata
├── VERSION                          # Single source of truth (v1.2.0)
│
├── .github/                         # CI/CD
│   ├── workflows/
│   │   ├── ci.yml                   # Build matrix for 4 architectures + backup-smoke-test
│   │   ├── codeql.yml               # Security scanning (SAST)
│   │   ├── release.yml              # Signed release + sync main → develop
│   │   └── upgrade-test.yml         # 42-scenario data-preservation matrix (v1.2.0)
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml           # Bug report template
│   │   ├── config.yml               # Issue template chooser
│   │   └── feature_request.yml      # Feature request template
│   │
│   ├── PULL_REQUEST_TEMPLATE.md     # Default PR template
│   ├── PULL_REQUEST_TEMPLATE/       # Additional PR templates
│   │   └── release.md               # Release-specific PR template
│   │
│   ├── CODEOWNERS                   # Auto-assign reviewers
│   ├── dependabot.yml               # Dependency updates
│   └── SECURITY.md                  # Security policy (summary)
│
├── .devcontainer/                   # Unified dev environment
│   ├── devcontainer.json            # VS Code Dev Container config
│   └── setup.sh                     # Auto-install dev tools
│
├── scripts/                         # Build & release tools
│   ├── fetch_dns_binaries.sh        # DNS binaries fetcher (Level 4)
│   ├── generate-icons.sh            # PNG/ICO icon generator
│   ├── package_module.sh            # Build Magisk ZIP
│   ├── release.sh                   # Stable / Prerelease automation
│   └── release-patch.sh             # PATCH-only (hotfix) automation
│
├── proxy/                           # Backend (Go + Shell)
│   ├── action.sh                    # Magisk Action button handler (--backup, --diagnose)
│   ├── build.sh                     # 4-arch cross-compile
│   ├── customize.sh                 # Magisk installer (10 data-preservation layers)
│   ├── dnscrypt-proxy.toml          # DNSCrypt engine config
│   ├── dnscrypt-proxy.version       # DNS binary version (2.1.18)
│   ├── functions.sh                 # Shared shell library (backup helpers)
│   ├── go.mod                       # Go module definition
│   ├── main.go                      # HTTP server
│   ├── post-fs-data.sh              # Early boot cleanup
│   ├── service.sh                   # Boot service + periodic auto-backup
│   ├── status.sh                    # Status display (5 modes incl. --diagnose)
│   ├── uninstall.sh                 # Cleanup + orphan txn preservation
│   ├── watchdog.sh                  # Standalone watchdog process
│   └── webui.conf                   # WebUI/Dashboard config
│
├── web/                             # Frontend (bilingual: EN default + AR toggle)
│   ├── apple-touch-icon.png         # iOS icon (180×180)
│   ├── dashboard.html               # Monitoring dashboard
│   ├── favicon.ico                  # IE + bookmarks
│   ├── favicon-16x16.png            # Legacy favicon
│   ├── favicon-32x32.png            # Modern favicon
│   ├── icon-192.png                 # PWA icon (PNG, legacy browsers)
│   ├── icon-192.svg                 # PWA icon (SVG, modern browsers)
│   ├── icon-512.png                 # PWA icon (maskable PNG)
│   ├── icon-512.svg                 # PWA icon (maskable SVG)
│   ├── index.html                   # Main UI (FSM + SW Update + EN/AR toggle)
│   ├── manifest.json                # PWA manifest (lang=en, dir=ltr defaults)
│   ├── offline.html                 # Offline fallback page
│   └── sw.js                        # Service Worker
│
└── docs/                            # Documentation (21 files + 7 ADRs)
    ├── adr/                         # Architecture Decision Records (7 files)
    ├── API.md                       # HTTP API reference
    ├── ARCHITECTURE.md              # System architecture
    ├── BACKUP.md                    # Backup system reference (v1.2.0)
    ├── BRANCHING.md                 # Git branching strategy
    ├── COMPATIBILITY.md             # Device compatibility matrix
    ├── CONTRIBUTING.md              # Contribution guide
    ├── DEVELOPMENT.md               # This file
    ├── DNS_BINARIES.md              # DNS binaries management
    ├── EMERGENCY.md                 # Emergency recovery (v1.2.0)
    ├── FAQ.md                       # Common questions
    ├── GLOSSARY.md                  # Terms & abbreviations
    ├── HALL_OF_FAME.md              # Contributors recognition
    ├── INSTALL.md                   # Installation guide
    ├── RELEASE_PROCESS.md           # Release process guide
    ├── ROADMAP.md                   # Future plans
    ├── SECURITY.md                  # Threat model + disclosure
    ├── TROUBLESHOOTING.md           # Troubleshooting guide
    └── UPGRADE.md                   # Version upgrade guide
```

### 4.2 Key Files

| File | Size | Purpose |
|---|---|---|
| `proxy/main.go` | ~95 KB | HTTP server + task manager (Backend) + auto-backup |
| `proxy/functions.sh` | ~30 KB | Shared shell library (backup helpers) |
| `proxy/customize.sh` | ~55 KB | Installer (10 data-preservation layers) |
| `proxy/watchdog.sh` | ~16 KB | Service state monitor |
| `web/index.html` | ~135 KB | Main UI (bilingual EN/AR) |
| `web/dashboard.html` | ~78 KB | Monitoring dashboard (bilingual EN/AR) |

### 4.3 v1.0.0 / v1.1.0 / v1.2.0 File Changes

| File | v1.0.0 | v1.1.0 | v1.2.0 |
|---|---|---|---|
| `proxy/main.go` | Fix #1, #2, #5, #6, #7, #8, #10, #11, #12, NEW-1..NEW-6, RACE-1, PORT-2 | MEM-1, MEM-2, MEM-3 | BAK-1 (7-field backups), BAK-2 (`createAutoBackup` + `backupMu`), BAK-3 (`cleanupOldTransactions`), BAK-4 (`checkPendingNotifications`) |
| `proxy/customize.sh` | Backup/restore (legacy) | Port collision fix + memory hint | 10 defensive layers (multi-source, persistent backup, integrity, transactions, root detection, SELinux, recovery mode, migrations, rotation, history) |
| `proxy/functions.sh` | `fuser` PID parsing | `get_profile_memory_hint()` + `SELECTED_PROFILE_FILE` | `backup_user_files`, `restore_user_files`, `rotate_backups`, `auto_backup_if_needed`, `cleanup_old_transactions`, `copy_with_context`, `verify_backup_integrity`, `write_manifest`, `get_backup_dir`, `ensure_backup_dir`, `get_last_backup_time` |
| `proxy/service.sh` | — | Profile + memory hint at boot | `auto_backup_if_needed(86400)`, `rotate_backups(21)`, `cleanup_old_transactions`, reads `.pending_notification`, backup summary logging |
| `proxy/status.sh` | — | `--check`, `--json`, default output extended | New `--diagnose` mode (Layer 10), 7-field `backups` in `--json`, "Backup & Recovery" section in default output |
| `proxy/action.sh` | — | `--check` reports profile + memory | New `--backup` flag, new `--diagnose` flag, "Backup & Recovery" section in `--check` |
| `proxy/uninstall.sh` | — | No auto-backup | Preserves `/sdcard/dnscrypt-webui-backup/`, cleans legacy v1.0.0 backup dir, renames `txn-*` (START) to `orphan-txn-*` |
| `proxy/watchdog.sh` | — | Profile + memory hint at startup | **Read-only** backup snapshot in startup banner (does not modify the backup layer) |
| `web/index.html` | PORT-2 dynamic links | Profile + memory in System Info | Bilingual (EN default + AR toggle), backup state in System Info, SW update-banner fix |
| `web/dashboard.html` | PORT-2 dynamic links | Profile + memory in System Info | Bilingual (EN default + AR toggle), backup state in System Info, SW update-banner fix |
| `web/offline.html` | — | **CRITICAL** — removed restrictive CSP meta | Bilingual (EN default + AR toggle), "Your data is safe" info box, recovery mode hint |
| `web/manifest.json` | Version + port notes | `x-note-memory`, `x-note-runtime-info`, `x-note-icon-source` | `lang=en` (default), `dir=ltr` (default), `x-note-backup`, `x-note-backup-paths`, `x-note-recovery`, `x-note-language`, `x-note-docs` |
| `web/sw.js` | PNG icons in precache | `CACHE_VERSION` bump + comment cleanup | `CACHE_VERSION` bump to v1.2.0, documented SW independence from the backup layer |
| `web/icon-192.svg` | — | Header clarified | Header expanded with design decisions |
| `web/icon-512.svg` | — | Header corrected | Header expanded with maskable-safe-zone math |
| `.pre-commit-config.yaml` | golangci-lint v2 | + shellcheck-py hook | No new hooks (existing cover v1.2.0) |
| `.gitignore` | `proxy/run/*` | Removed 2 no-op negations | Backup staging patterns in §[19] |
| `.gitattributes` | `merge=union` for CHANGELOG + VERSION | — | `proxy/dnscrypt-proxy.version` rule added |
| `.editorconfig` | — | — | `[proxy/run/*.tmp_*]` pattern added |
| `.github/workflows/ci.yml` | + `develop` in triggers | — | + `backup-smoke-test` job |
| `.github/workflows/codeql.yml` | + `develop` in triggers | — | Documentation updates only |
| `.github/workflows/release.yml` | + `Sync main → develop` step | — | Documentation updates only |
| `.github/workflows/upgrade-test.yml` | — | — | **NEW** — 42-scenario data-preservation matrix |
| `scripts/release.sh` | 🆕 v1.0.0 | Documentation only | Documentation only |
| `scripts/release-patch.sh` | 🆕 v1.0.0 (renamed) | Documentation only | Documentation only |
| `.github/PULL_REQUEST_TEMPLATE.md` | + Target Branch section | — | + Data-preservation checklist, bilingual WebUI check |
| `.github/PULL_REQUEST_TEMPLATE/release.md` | 🆕 v1.0.0 | — | + v1.2.0 data-preservation checks |
| `.github/CODEOWNERS` | + `docs/adr/`, `release-patch.sh` | — | + data-preservation files enumerated |
| `docs/BRANCHING.md` | 🆕 v1.0.0 | Rulesets UI fix | v1.2.0 changes block + version examples |
| `docs/RELEASE_PROCESS.md` | 🆕 v1.0.0 | v1.1.0 update | v1.2.0 changes block |
| `docs/UPGRADE.md` | — | 🆕 v1.1.0 (§3.0) | §3.1 (v1.1.0 → v1.2.0) added |
| `docs/BACKUP.md` | — | — | **NEW** — backup system reference |
| `docs/EMERGENCY.md` | — | — | **NEW** — emergency recovery guide |
| `docs/adr/README.md` | 🆕 v1.0.0 | v1.1.0 update | v1.2.0 changes block |
| `docs/adr/0001` → `0006` | 🆕 v1.0.0 | Post-release verification | Post-release verification |
| `docs/ARCHITECTURE.md` | — | v1.1.0 update | §3.10 (backup flow), §4.10 (BAK-1..BAK-4), §8.4 (META-INF), §6.7 (bilingual WebUI) |
| `docs/API.md` | — | v1.1.0 update | 7-field `backups` schema, §10.6 (backup diagnostics), §10.7 (recovery mode), §10.8 (language-neutral API) |
| `docs/SECURITY.md` | — | §5.30 (MEM-1/2/3) | §5.31 (Data Preservation Security Model), §5.32 (Recovery Mode Correctness Fix) |
| `docs/TROUBLESHOOTING.md` | — | v1.1.0 update | §4.12 (memory), §4.13 (SW banner), §4.14 (recovery data loss), §5.14, §5.15, §6.10, §7.8–§7.11, §15.13–§15.15 |
| `docs/GLOSSARY.md` | — | v1.1.0 update | 13 new terms + 4 abbreviations |
| `docs/HALL_OF_FAME.md` | — | Memory Architect badge | Data Guardian badge |
| `docs/FAQ.md` | — | Q111–Q120 | Q121–Q130 (backup questions) |
| `docs/INSTALL.md` | — | v1.1.0 update | §10.5 (manual backup before uninstall) |
| `docs/CONTRIBUTING.md` | — | v1.1.0 update | §8.9 (backup testing), §8.11 (bilingual testing), Golden Rule #22/#23, Data Guardian badge |
| `docs/COMPATIBILITY.md` | — | v1.1.0 update | §5.5 (backup compatibility), §8.4 (v1.2.0 issues), §1.6 (bilingual) |
| `docs/DEVELOPMENT.md` | — | v1.1.0 update | §8.12 (backup debugging), §8.13 (matrix testing), §8.14 (bilingual debugging), Golden Rule #22/#23 |
| `docs/DNS_BINARIES.md` | — | v1.1.0 update | v1.2.0 changes block |
| `docs/ROADMAP.md` | — | v1.1.0 update | v1.2.0 delivered section |
| `docs/HALL_OF_FAME.md` | — | Memory Architect badge | Data Guardian badge (v1.2.0) |
| `CHANGELOG.md` | — | `[v1.1.0]` section | `[v1.2.0]` section |
| `README.md` | — | v1.1.0 badge + RAM-by-profile table | v1.2.0 badge + 10-layer description + Data Preservation section |
| `SECURITY.md` | — | v1.1.0 update | v1.2.0 changes + BAK-1..BAK-4 summary |
| `.github/SECURITY.md` | — | — | v1.2.0 changes summary |

---

## 5. Daily Workflow

### 5.1 Start from `develop`

```bash
git checkout develop
git pull origin develop
```

**Rule**: Always branch from `develop`, never from `main`. See
[`docs/BRANCHING.md`](BRANCHING.md) §4.

### 5.2 Create a New Branch

```bash
# Choose the correct prefix (see docs/BRANCHING.md §3)
git checkout -b feature/my-feature
# or: fix/..., docs/..., chore/..., refactor/..., test/...
```

### 5.3 Develop and Verify

```bash
# Edit files
nano proxy/main.go

# Verify Go build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..

# Verify shell syntax
bash -n proxy/*.sh scripts/*.sh

# Format
gofmt -w proxy/
shfmt -w -i 4 -ci proxy/*.sh scripts/*.sh

# (v1.2.0) Verify backup shell functions
make check-backup

# (v1.2.0) Run all local validations
make check-all
```

### 5.4 Commit

```bash
git add proxy/main.go
git commit -m "feat(proxy): add new endpoint"
```

**v1.0.0 / v1.1.0 / v1.2.0 commit patterns**:

```bash
# Architectural fix (Audit Correction)
git commit -m "fix(proxy): convert Prometheus metrics to JSON

Dashboard was broken because metricsProxyHandler returned
Prometheus text with Content-Type: application/json.

Added parsePrometheus() and buildDashboardJSON() to convert on the fly.

Audit Correction #25
Refs: docs/SECURITY.md"

# Behavioral fix (shell fallback)
git commit -m "fix(ci): add getSystemShell() fallback for Linux

runShell hardcoded /system/bin/sh, which doesn't exist on Linux/macOS,
breaking CI Go builds.

Added getSystemShell() that probes /system/bin/sh, /bin/sh, /usr/bin/sh.

Refs: docs/ARCHITECTURE.md"

# Security fix
git commit -m "security(auth): enforce rate limiting on Basic Auth

checkAuth did not record failed Basic Auth attempts, allowing
unlimited brute force on LAN.

Now uses loginAttempts with same 5/15min policy as handleLogin.

Audit Correction #22
Refs: docs/SECURITY.md"

# Concurrency fix (RACE-1)
git commit -m "fix(concurrency): serialize rebuildBlocklist calls

Two callers (updateProfile + atomicSaveRulesInternal) could run
rebuildBlocklist concurrently, corrupting BLOCKLIST.

Added rebuildMu sync.Mutex with coarse-grained locking.

Audit Correction #32
Refs: docs/SECURITY.md"

# Dynamic ports fix (PORT-2)
git commit -m "feat(api): return webui_port + dashboard_port in runtime_info

index.html and dashboard.html had hardcoded ports, breaking links
when PORT or DASHBOARD_PORT were customized.

Added dynamic port discovery via runtime_info; frontend now builds
URLs using window.location.hostname.

Audit Correction #33
Refs: docs/SECURITY.md"

# Login POST-only fix (NEW-1)
git commit -m "security(auth): enforce POST-only on login/logout

GET /api/auth/login?username=X&password=Y was accepted, creating
CSRF vector via <img src=...> and leaking credentials to browser
history + server logs.

Audit Correction #28
Refs: docs/SECURITY.md"

# v1.1.0 — MEM-1 (Dynamic memory limit)
git commit -m "feat(proxy): add dynamic memory limit per profile

debug.SetMemoryLimit was hardcoded to 80MB for all profiles. On
'ultimate', actual working set approaches 200MB → GC thrashing.

Added memoryLimitForProfile() + applyMemoryLimit():
  light=80, normal=100, pro=120, proplus=160, ultimate=220 (MB)

Applied at startup and on every profile change. Exposed via
runtime_info.memory_limit_mb.

Refs: docs/SECURITY.md §5.30.1
Refs: docs/ARCHITECTURE.md §3.9, §4.9.1"

# v1.1.0 — MEM-2 (Extended shellQuote charset)
git commit -m "security(shell): extend shellQuote character set

shellQuote() escaped 20 shell metacharacters. Added {, }, \\n, \\t
for brace expansion and word-splitting defense-in-depth.

No known exploit existed — this is defense-in-depth.

Refs: docs/SECURITY.md §5.30.2"

# v1.1.0 — MEM-3 (MONITORING_UI_PORT in metrics handler)
git commit -m "refactor(proxy): use MONITORING_UI_PORT constant in metrics handler

metricsProxyHandler contained a hardcoded 'http://127.0.0.1:8080/api/metrics'.

Now uses the MONITORING_UI_PORT constant — single source of truth
for the reserved port.

Behavior is unchanged.

Refs: docs/SECURITY.md §5.30.3"

# v1.2.0 — BAK-1 (7-field backups schema)
git commit -m "feat(api): extend runtime_info.backups to 7 fields

runtime_info.backups returned 5 fields:
  available, last_backup, last_backup_name, last_stable, path

The status.sh --json tool has always returned 7 fields. This
asymmetry forced API clients to special-case the two endpoints.

Added:
  in_flight_txn  — count of txn-* directories
  orphan_txn     — count of orphan-txn-* directories

The two endpoints now produce identical JSON on the 7 shared
fields. This is an additive change.

Refs: docs/SECURITY.md §5.31
Refs: docs/API.md §6.1.7
Refs: docs/BACKUP.md §8.1
Refs: docs/ARCHITECTURE.md §4.10.1"

# v1.2.0 — BAK-2 (createAutoBackup + backupMu)
git commit -m "feat(backup): add pre-critical auto-backup before destructive ops

The 5 user config files were only snapshotted at install time. A
user who edited their allowlist after install had no way to roll
back a mistake.

Added createAutoBackup(reason) called from 5 destructive endpoints,
but only 4 distinct reason strings because appendDenylist delegates
to saveDenylist:

  - updateProfile           → 'pre-profile-change'
  - saveAllowlist           → 'pre-allowlist-save'
  - saveDenylist            → 'pre-denylist-save'
  - saveCustomRulesCombined → 'pre-custom-rules-save'
  - appendDenylist(content) → (no own reason — delegates to
                               saveDenylist, which uses
                               'pre-denylist-save')

Serialized by a new sync.Mutex (backupMu).

Best-effort: a failed backup logs a warning but never blocks
the user's action.

Refs: docs/SECURITY.md §5.31.3
Refs: docs/BACKUP.md §4.3, §12.5
Refs: docs/ARCHITECTURE.md §4.10.2"

# v1.2.0 — BAK-3 (cleanupOldTransactions)
git commit -m "feat(backup): clean up leftover COMMIT'd transactions at startup

The transaction system (Layer 4) creates txn-* directories during
install. After a successful commit, customize.sh removes its own
txn dir. But if the installer was killed AFTER writing COMMIT and
BEFORE the removal step, a COMMIT'd txn dir is left behind
indefinitely.

Added cleanupOldTransactions() called at startup from main().
It removes txn-* dirs with .state == 'COMMIT' and PRESERVES:
  - START    (may contain the only copy of user data)
  - ROLLBACK (already applied, safe to keep for audit)
  - orphan-txn-* (user-managed)

Refs: docs/ARCHITECTURE.md §4.10.3
Refs: docs/BACKUP.md §5.6"

# v1.2.0 — BAK-4 (checkPendingNotifications)
git commit -m "feat(backup): read .pending_notification at startup

customize.sh writes .pending_notification after a successful
restore during an upgrade. Without a reader, the message was
never surfaced to the user.

Added checkPendingNotifications() called once at startup from
main(). It reads the file, logs the content via logEvent, and
removes the file.

Idempotent: missing file → no-op. Empty file → removed silently.

Refs: docs/ARCHITECTURE.md §4.10.4
Refs: docs/BACKUP.md §5.5"

# v1.2.0 — FIX-1 (Recovery-mode correctness via snapshot-and-reapply)
git commit -m "fix(installer): use snapshot-and-reapply in recovery mode

In an early v1.2.0 draft, the ZIP extraction step (customize.sh
§[9]) ran AFTER the recovery restore (§[8a]) and overwrote
webui.conf + dnscrypt-proxy.toml with the ZIP's defaults. The
subsequent restore step (§[9c]) was skipped in recovery mode, so
2 of the 5 restored files were silently lost.

Fixed with a snapshot-and-reapply strategy that keeps the
extraction logic of §[9] untouched and does not depend on
knowing the ZIP's contents:

  §[8a]  Restore the 5 files into \$MODPATH/proxy/ AND copy each
         one to \$MODPATH/.recovery_snapshot/.
  §[9]   Extract the ZIP normally. This overwrites webui.conf
         and dnscrypt-proxy.toml with the ZIP's defaults —
         unavoidable without knowing the ZIP's contents.
  §[9b2] Re-apply the 5 files from \$MODPATH/.recovery_snapshot/
         back into \$MODPATH/proxy/.
  §[9c]  Skipped when RECOVERY_MODE=1 — already handled by A+D.

Partial re-application preserves the snapshot directory at
\$MODPATH/.recovery_snapshot/ for manual recovery.

All 5 files now survive recovery mode. The normal-install path
is byte-for-byte identical to the pre-recovery behavior.

Refs: docs/SECURITY.md §5.32.1
Refs: docs/ARCHITECTURE.md §3.10
Refs: docs/EMERGENCY.md §9.6
Refs: docs/BACKUP.md §7.5"

# v1.2.0 — FIX-2 (Service Worker update banner)
git commit -m "fix(webui): send SKIP_WAITING to the correct worker

The [Reload] button in the SW update banner sent SKIP_WAITING to
navigator.serviceWorker.controller (the OLD worker), which
ignored it. The new worker stayed in the 'waiting' state, so the
banner reappeared on every page reload → infinite loop.

Fixed by:
  1. Sending SKIP_WAITING to swRegistration.waiting (new worker).
  2. Reloading on the 'controllerchange' event.
  3. Guarding double-clicks with a pendingReload flag.

Scope: the v1.1.0 fix applied only to index.html. The v1.2.0
release completes the fix in dashboard.html as well.

Refs: docs/SECURITY.md §5.32.2
Refs: docs/EMERGENCY.md §9.7"

# v1.2.0 — Language: Add an EN/AR string pair
git commit -m "feat(webui): add string X in EN + AR

Added the new user-facing string X to all three HTML pages:
  - web/index.html      → translations.en + translations.ar
  - web/dashboard.html  → translations.en + translations.ar
  - web/offline.html    → translations.en + translations.ar

The default language remains English. Verified both LTR and RTL
rendering with the langToggle button.

Refs: docs/ARCHITECTURE.md §6.7
Refs: docs/CONTRIBUTING.md §8.11"
```

**Rules**:
- **v1.0.0 fixes**: Mention `Audit Correction #XX` in the footer.
- **v1.1.0 runtime improvements**: Use `Refs: docs/SECURITY.md §5.30.N` (not an audit number).
- **v1.2.0 additions**: Use `Refs: docs/SECURITY.md §5.31` (BAK-N) or `§5.32` (FIX-N).
- **WebUI language changes**: Always mention **both** languages were updated.
- Reference `docs/SECURITY.md#...` and explain **why**, not just what.

### 5.5 Push and Open a PR

```bash
git push -u origin feature/my-feature
# Then open a Pull Request on GitHub — TARGET: develop
```

**⚠️ Critical**: Select `develop` as the **base branch** for your PR.
Opening a PR against `main` for a feature will be closed.

**See** [`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md).

### 5.6 After Merge

```bash
git checkout develop
git pull origin develop
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

**Note**: GitHub can auto-delete the remote branch if
`Settings → General → Automatically delete head branches` is enabled.

### 5.7 Architecture Decisions

For **non-trivial** architectural or process decisions, document them
as an **ADR**:

| When | Action |
|---|---|
| New architectural decision | Create `docs/adr/NNNN-title.md` |
| Reversing a previous decision | Create a new ADR that supersedes the old one (never edit the old ADR) |
| Simple bug fix / refactor | Regular PR (no ADR) |
| **v1.2.0**: runtime improvement that does NOT change architecture | Regular PR + SECURITY.md note (no ADR) |
| **v1.2.0**: adding an EN/AR string pair | Regular PR (no ADR) |

**Full methodology**: [`docs/adr/README.md`](adr/README.md) §3 and §7.

**Current ADRs**: 6 (see [`docs/adr/README.md`](adr/README.md) §6).

---

## 6. Release

> **📖 The full step-by-step process is documented in [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md).**
>
> This section is a **summary**.

### 6.1 Overview

Releases are triggered by pushing a version tag. Two scripts are
available:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `scripts/release.sh` | Stable, Prerelease | `develop` or `release/*` | Any |
| `scripts/release-patch.sh` | Hotfix (PATCH only) | **`main`** | PATCH only |

**Stable release** (from `develop`):

```bash
./scripts/release.sh v1.3.0
```

**PATCH-only release** (from `main`):

```bash
./scripts/release-patch.sh v1.2.1
```

Both scripts:
1. Validate the SemVer format.
2. Compute `versionCode`.
3. Update `VERSION`, `module.prop`, `update.json`.
4. Create a commit + tag.
5. Push to `origin`.

**GitHub Actions** (`.github/workflows/release.yml`) then:
1. Builds 4 architectures.
2. Packages the Magisk ZIP.
3. Generates SBOM + Cosign signature.
4. Creates the GitHub Release.
5. **Auto-syncs `main → develop`**.

### 6.2 SemVer

```text
v<MAJOR>.<MINOR>.<PATCH>[-prerelease]

v1.0.0        ← first stable release
v1.1.0        ← second stable (polish)
v1.2.0        ← third stable (current — data preservation)
v1.2.1        ← next patch (hotfix) if needed
v1.3.0        ← next minor (feature)
v2.0.0        ← next major (breaking)
```

### 6.3 versionCode Format

```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX
```

| Version | versionCode |
|---|:---:|
| v1.0.0 | 1000000 |
| v1.0.1 | 1000001 |
| v1.1.0 | 1010000 |
| v1.1.1 | 1010001 |
| v1.2.0 | 1020000 |
| v1.2.1 | 1020001 |
| v2.0.0 | 2000000 |

**Constraint**: `PATCH` ≤ 99, `HOTFIX` ≤ 99.

### 6.4 PATCH Releases (Hotfix)

`scripts/release-patch.sh` enforces **3 additional safety rules**:

1. **Branch must be `main`** — refuses to run from `develop`.
2. **`MAJOR` and `MINOR` must not change** — rejects non-PATCH bumps.
3. **`PATCH` must be exactly `current + 1`** — rejects skipping versions.

**Full rationale**: [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

**After a PATCH release**:

```bash
make sync   # back-merge main → develop
```

### 6.5 Release PR Template

PRs targeting `main` (from `release/*` or `hotfix/*`) use the
release-specific template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.3.0?template=release.md
```

**Full decision**: [ADR-0005](adr/0005-release-specific-pr-template.md).

### 6.6 Manual Release (Fallback)

If `release.sh` is unavailable:

```bash
# 1. Ensure you are on develop
git checkout develop
git pull origin develop

# 2. Update VERSION
echo "v1.3.0" > VERSION

# 3. Update module.prop
sed -i 's/^version=.*/version=v1.3.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1030000/' module.prop

# 4. Update update.json
$EDITOR update.json

# 5. Update CHANGELOG.md
$EDITOR CHANGELOG.md

# 6. Commit + tag + push
git add VERSION module.prop update.json CHANGELOG.md
git commit -m "release: v1.3.0"
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin develop
git push origin v1.3.0
```

### 6.7 Full Details

See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for:
- Release types (Stable, Prerelease, Hotfix).
- `release.sh` + `release-patch.sh` options.
- GitHub Actions pipeline (11 steps).
- Post-release verification (Cosign, SBOM, SHA256).
- Rollback procedures.
- Back-merge after hotfixes.

### 6.8 Upgrade Guide

See [`docs/UPGRADE.md`](UPGRADE.md) for:
- The `v1.0.0 → v1.1.0` upgrade path (§3.0).
- The `v1.1.0 → v1.2.0` upgrade path (§3.1).
- Settings preservation across upgrades.
- Rollback procedures.
- Emergency recovery.

---

## 7. CI/CD

### 7.1 `.github/workflows/ci.yml`

Runs on **push / PR to `main` or `develop`**:

**Build job** (4 architectures):
1. VERSION validation.
2. DNS version validation.
3. Consistency check.
4. ShellCheck.
5. shfmt.
6. gofmt.
7. go vet.
8. **golangci-lint v2.5.0**.
9. **Go build** (4 architectures).
10. YAML validation.
11. Scripts syntax validation (`bash -n`).
12. Build matrix (4 archs).

**v1.2.0 — `backup-smoke-test` job** (new):
1. `bash -n` on 8 shell scripts.
2. `shellcheck --severity=warning` on 5 scripts.
3. Function-presence checks for all 10 defensive layers.
4. `PERSISTENT_BACKUP` path consistency.
5. v1.2.0 documentation reference checks.

**Total**: 12+ steps in the build job + 5 steps in the backup job.

**Triggers**:

```yaml
on:
  push:
    branches: [main, develop]
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
```

### 7.2 `.github/workflows/release.yml`

On tag push `v*`:

1. Verify (tag + VERSION + DNS version).
2. Build (4 archs).
3. Package (ZIP + 13 web files).
4. Sign (Cosign keyless).
5. SBOM (SPDX + CycloneDX).
6. Release.
7. **Sync `main → develop`** (post-release, per [ADR-0003](adr/0003-post-release-sync.md)).

**v1.2.0 note**: `release.yml` is **unchanged** from v1.1.0. The
data-preservation layers ship inside existing files, so the
release pipeline did not need any modification. The bilingual
WebUI is served as static assets and needs no pipeline change.

### 7.3 `.github/workflows/codeql.yml`

- Full analysis (SAST).
- `queries: security-extended`.
- **Triggers**: push/PR to `main` or `develop` + weekly.
- **v1.2.0 note**: Documentation updates only — no workflow changes.

### 7.4 `.github/workflows/upgrade-test.yml` (v1.2.0 — new)

- **42-scenario matrix**: 3 root solutions × 2 source versions × 7 scenarios.
- **Trigger**: manual (`workflow_dispatch`) + weekly schedule.
- **Purpose**: validate the 10 defensive layers across the
  combinations that matter most.
- **Runs in**: ~10 minutes.
- **Not part of the release pipeline** — it is a QA tool.

**Matrix definition**:

| Dimension | Values |
|---|---|
| Root solution | Magisk, KernelSU, APatch |
| Source version | v1.0.0, v1.1.0 |
| Scenario | fresh-install, in-place-upgrade, rename-folder, reinstall-after-uninstall, recovery-mode, interrupted-install, custom-ports |

### 7.5 Local CI Simulation

```bash
# Go build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/main.go main.go && cd ..

# Linting
golangci-lint run --timeout=7m ./proxy/...
shellcheck --severity=warning proxy/*.sh scripts/*.sh
shfmt --diff --indent 4 --case-indent proxy/*.sh scripts/*.sh
gofmt -l proxy/

# Scripts syntax
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# Build
make build

# (v1.2.0) Backup shell functions
make check-backup

# (v1.2.0) All local validations
make check-all

# (v1.2.0) Verify the upgrade-test matrix is present
test -f .github/workflows/upgrade-test.yml && echo "✅ upgrade-test.yml present"
```

### 7.6 CI Troubleshooting

**If CI fails**:

```bash
# 1. Verify Go build locally
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go

# 2. Check linters
golangci-lint run --timeout=7m ./proxy/...
shellcheck --severity=warning proxy/*.sh scripts/*.sh
```

**If `golangci-lint` fails**:

```bash
# Check version
golangci-lint version
# Must be v2.x

# Update
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.5.0
```

**If Go build fails on Linux**:
- Ensure you're on `v1.0.0+` (has `getSystemShell` fallback).
- Verify: `grep -q 'func getSystemShell' proxy/main.go`.
- Verify `runShell`: `grep -n 'getSystemShell()' proxy/main.go`.

**If `backup-smoke-test` fails (v1.2.0)**:
- Verify the layer function names in `customize.sh` and
  `functions.sh`.
- Run locally: `make check-backup`.
- Check `docs/BACKUP.md` and `docs/EMERGENCY.md` are present.

### 7.7 Branch Protection

Recommended settings for the repository:

- **`main`**: Require PR + 1 approval + passing CI + CodeQL + Backup Smoke Test.
- **`develop`**: Require passing CI + CodeQL + Backup Smoke Test.
- **Tags `v*`**: Restrict who can create/delete.

**Full details**: [`docs/BRANCHING.md`](BRANCHING.md) §6.

---

## 8. Debugging

### 8.1 Go

```bash
# Run with debug logs
cd proxy
LOG_LEVEL=debug go run main.go

# Delve
dlv debug main.go

# Race detector
go run -race main.go

# go vet
go vet ./...
```

### 8.2 Shell

```bash
# Trace execution
bash -x proxy/service.sh

# ShellCheck
shellcheck proxy/service.sh
shellcheck --severity=warning proxy/*.sh

# shfmt
shfmt -d -i 4 -ci proxy/*.sh
```

### 8.3 On the Device

```bash
# Logs
su -c "tail -f /data/local/tmp/dnscrypt_main.log"

# Status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# Ports
su -c "ss -tulnp | grep -E '9090|9091|5354|8080'"

# iptables
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n -v"

# STATUS_FILE
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
```

### 8.4 Dashboard Debugging (Fix #1)

```bash
# 1. Verify JSON conversion
curl -s http://127.0.0.1:9091/api/metrics | jq '.total_queries'

# 2. Verify Content-Type
curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type
# Expected: Content-Type: application/json; charset=utf-8

# 3. Test main.go directly
grep -q 'func parsePrometheus' proxy/main.go && echo "✅ Fix #1 present"
```

### 8.5 Shell Fallback Debugging (Fix #2)

```bash
# 1. Test getSystemShell
cd proxy
cat > /tmp/test_shell.go << 'EOF'
package main
import ("fmt"; "os")
func main() {
    candidates := []string{"/system/bin/sh", "/bin/sh", "/usr/bin/sh"}
    for _, c := range candidates {
        if _, err := os.Stat(c); err == nil {
            fmt.Println("Would use:", c)
            return
        }
    }
    fmt.Println("Would use: sh (PATH)")
}
EOF
go run /tmp/test_shell.go
```

### 8.6 Network Tests

```bash
# API
curl -v http://127.0.0.1:9090/api?action=status

# SSE
curl -N http://127.0.0.1:9090/events

# Health
curl http://127.0.0.1:9090/healthz
curl http://127.0.0.1:9090/readyz

# Metrics
curl -s http://127.0.0.1:9091/api/metrics | jq

# runtime_info (PORT-2 + MEM-1 + BAK-1)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
```

### 8.7 WebUI Debugging

```javascript
// In DevTools Console

// SSE state
console.log(sse.readyState);

// Cache
caches.keys().then(console.log);

// Service Worker
navigator.serviceWorker.getRegistrations().then(console.log);

// currentStatus (v1.0.0)
console.log(window.currentStatus);

// PORTS (v1.0.0)
console.log(window.PORTS);

// v1.2.0 — verify bilingual state
document.documentElement.lang  // → "en" (default) or "ar"
document.documentElement.dir   // → "ltr" (default) or "rtl"
localStorage.getItem('dnscrypt-lang')  // → "en" | "ar" | null

// v1.2.0 — check SW update banner state
console.log(window.pendingReload);
console.log(swRegistration && swRegistration.waiting);
```

### 8.8 v1.0.0 Specific Debugging

#### Fix #1 — Dashboard JSON

```bash
su -c "curl -s http://127.0.0.1:9091/api/metrics" | jq '.total_queries'
su -c "curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type"
su -c "grep -A3 '^\[monitoring_ui\]' /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"
```

#### Fix #8 — Basic Auth rate limit

```bash
for i in {1..7}; do
    curl -u "user:wrong" -o /dev/null -w "%{http_code}\n" \
        http://127.0.0.1:9090/api?action=status
done
# Expected: 401 × 6 then 401 (locked)
```

#### Fix #10 — Section header

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml" | grep -A1 '^\[monitoring_ui\]'
```

#### Fix #11 — Per-port cache

```bash
grep -q 'portCacheMap' proxy/main.go && echo "✅ Fix #11 present"
```

#### Fix #12 — Exact endpoint matching

```bash
curl -i "http://127.0.0.1:9090/api?action=unknown_xyz"
# Expected: 404 Not Found
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12 present"
```

#### NEW-1 — Login POST-only

```bash
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 + Allow: POST
```

#### NEW-3 — readConfPort range

```bash
grep -A20 'func readConfPort' proxy/main.go | grep -E 'n < 1|n > 65535'
```

#### NEW-4 — /readyz localhost

```bash
curl -i "http://127.0.0.1:9090/readyz"  # localhost → 200/503
curl -i "http://192.168.1.5:9091/readyz"  # LAN → 403
```

#### NEW-5 — shellQuote

```bash
grep -q 'func shellQuote' proxy/main.go && echo "✅"
```

#### NEW-6 — Auth cache

```bash
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅"
```

### 8.9 RACE-1 + PORT-2 Debugging

#### RACE-1 — rebuildMu mutex

```bash
# Static audit (mutex presence)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"
```

**Note**: If you see `panic: sync: unlock of unlocked mutex`, `rebuildMu` was double-unlocked.

#### PORT-2 — runtime_info ports

```bash
# 1. runtime_info returns ports
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. Static audit (backend)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ backend"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"dashboard_port"' && echo "✅ backend"

# 3. Static audit (frontend)
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html"

# 4. Integration (with custom ports)
# Change PORT=8081 in webui.conf
su -c "curl -s http://127.0.0.1:8081/api?action=runtime_info | jq '.webui_port'"
# Expected: "8081"
```

### 8.10 v1.1.0 Memory Limit Debugging (MEM-1)

#### Static Audit

```bash
# 1. Function presence
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1 function"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ MEM-1 apply"

# 2. All 5 profile constants + default
for c in LIGHT NORMAL PRO PROPLUS ULTIMATE DEFAULT; do
    grep -q "MEMORY_LIMIT_$c" proxy/main.go && echo "✅ MEMORY_LIMIT_$c"
done

# 3. No hardcoded 80MB limit remains
! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded"

# 4. Called from main() and updateProfile()
grep -c 'applyMemoryLimit(' proxy/main.go
# Expected: >= 3 (definition + 2 call sites)
```

#### Runtime Checks

```bash
# 1. Effective limit for the active profile
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
# Expected: 80 / 100 / 120 / 160 / 220

# 2. Active profile key
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'"
# Expected: light / normal / pro / proplus / ultimate

# 3. Startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=<key>, limit=<N> MB

# 4. Profile file vs runtime (must match)
diff <(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt") \
     <(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'")
# Expected: no diff
```

#### GC Thrashing Symptoms (pre-v1.1.0)

If you suspect the memory limit is causing slowness:

```bash
# 1. Get the WebUI PID
PID=$(su -c "pgrep -x dnscrypt-webui" | head -1)

# 2. Sample CPU usage over 5 s
su -c "top -b -n 5 -d 1 -p $PID | tail -5"

# If CPU usage is > 30% while idle → GC thrashing
# Solution: check the active profile matches the device RAM tier
# (see docs/COMPATIBILITY.md §5.4)
```

### 8.11 Testing All Profiles (v1.1.0)

One-shot verification script for all 5 profiles:

```bash
#!/system/bin/sh
# test-all-profiles.sh — v1.1.0+
# Verifies that each profile sets the correct memory_limit_mb.

PROFILES="light normal pro proplus ultimate"

echo "Testing all 5 profiles..."
echo ""

for P in $PROFILES; do
    echo "=== Profile: $P ==="

    # Set the profile
    su -c "echo '$P' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
    su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
    sleep 5

    # Query runtime_info
    RESULT=$(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -c '{profile_key, memory_limit_mb}'")
    echo "  Result: $RESULT"

    # Log line
    su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1" | sed 's/^/  /'

    echo ""
done

echo "Done. Expected limits:"
echo "  light    → 80"
echo "  normal   → 100"
echo "  pro      → 120"
echo "  proplus  → 160"
echo "  ultimate → 220"
```

**To use**:

```bash
nano /sdcard/test-all-profiles.sh
# paste the script above
su -c "sh /sdcard/test-all-profiles.sh"
```

### 8.12 v1.2.0 Backup Debugging (new)

#### Static Audit — Layer presence

```bash
# All 10 layers present in customize.sh
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
         begin_transaction rollback_transaction commit_transaction \
         detect_root_solution copy_with_context RECOVERY_TRIGGER \
         migrate_config; do
    grep -q "$L" proxy/customize.sh && echo "✅ $L" || echo "❌ $L"
done

# Backup helpers in functions.sh
for H in auto_backup_if_needed rotate_backups backup_user_files \
         restore_user_files cleanup_old_transactions \
         get_backup_dir ensure_backup_dir get_last_backup_time \
         copy_with_context verify_backup_integrity write_manifest; do
    grep -q "$H" proxy/functions.sh && echo "✅ $H" || echo "❌ $H"
done

# main.go additions
grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2 createAutoBackup"
grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 backupMu"
grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"
grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"

# 7-field backups schema
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ BAK-1 in_flight_txn"
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'orphan_txn' && echo "✅ BAK-1 orphan_txn"
```

#### Runtime Audit — Backup state

```bash
# 1. Backup directory exists and is well-formed
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# 2. Counts and metadata
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

# 3. Cross-check with status.sh --json
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq '.backups'"

# 4. Verify the 5 files exist in current/
su -c "ls /sdcard/dnscrypt-webui-backup/current/"

# 5. Read the .last_stable pointer
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"

# 6. Read the upgrade history
su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.json | jq"
```

#### Diagnose mode (Layer 10)

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**Expected sections**:
- ✅ System Information
- ✅ Module Information
- ✅ Service Status
- ✅ Recovery & Notifications
- ✅ User Data Files (all 5 present)
- ✅ Backups (count + latest)
- ✅ Health Checks
- ✅ Diagnosis (✅ All systems operational)

#### Common backup issues

| Symptom | Diagnosis | Fix |
|---|---|---|
| `backups.available == 0` | No snapshot yet | Wait for first boot, or run `action.sh --backup` |
| `backups.last_backup_name == null` | No snapshot exists | Same as above |
| `backups.in_flight_txn > 0` | Install in progress or interrupted | Wait, or inspect `txn-*` manually |
| `backups.orphan_txn > 0` | Interrupted install preserved | Inspect `orphan-txn-*` before deleting |
| `backups.path` empty | `PERSISTENT_BACKUP` unset | Should never happen — check `main.go` global |
| Backup directory missing on device | `/sdcard/` not mounted at install time | Reboot (`service.sh` creates it) |

#### Manual verification of Layer 4 (transactions)

```bash
# Inspect any in-flight transaction
su -c "ls -la /sdcard/dnscrypt-webui-backup/txn-*/"
su -c "cat /sdcard/dnscrypt-webui-backup/txn-*/.state"
su -c "cat /sdcard/dnscrypt-webui-backup/txn-*/.pid"

# Verify no COMMIT'd txn leftovers (should be 0 after startup)
su -c "ls -d /sdcard/dnscrypt-webui-backup/txn-*/ 2>/dev/null | \
       while read d; do [ \"\$(cat \$d/.state 2>/dev/null)\" = 'COMMIT' ] && echo \$d; done"
```

#### Manual verification of Layer 7 (recovery mode)

See [`docs/EMERGENCY.md`](EMERGENCY.md) §9.6 for the full
procedure. The short version:

```bash
# 1. Set a distinctive value
su -c "sed -i 's/^PORT=9090/PORT=9191/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 2. Take a backup
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

# 3. Trigger recovery
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# 4. After reboot, verify PORT=9191 is still present
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

### 8.13 Testing the 42-scenario Matrix Locally (new)

The `.github/workflows/upgrade-test.yml` file defines a
**42-scenario matrix** (3 root solutions × 2 source versions ×
7 scenarios). You can trigger it locally via the GitHub CLI or
reproduce a subset by hand.

#### Full matrix via GitHub CLI

```bash
# 1. Trigger the workflow
gh workflow run upgrade-test.yml

# 2. List the run
gh run list --workflow=upgrade-test.yml --limit 1

# 3. Watch it
gh run watch

# 4. View the results
gh run view
```

#### Reproduce a single scenario by hand

Example: **in-place upgrade from v1.1.0 to v1.2.0 on Magisk**.

```bash
# 1. Install v1.1.0 on a test device
# (Download v1.1.0 ZIP from GitHub Releases, install via Magisk)

# 2. Configure some settings
# (Change profile to 'ultimate', add an allowlist entry)

# 3. Take a baseline snapshot
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose-before.txt

# 4. Install v1.2.0 ZIP over v1.1.0 via Magisk

# 5. Reboot and wait 60 s

# 6. Verify the result
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose-after.txt

diff /sdcard/diagnose-before.txt /sdcard/diagnose-after.txt
# Focus on: profile, ports, allowlist count, backup state

# 7. Verify the 5 preserved files
su -c "ls /sdcard/dnscrypt-webui-backup/current/"
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
```

#### Emulation limitation

The matrix runs in a container, not on a real device. It cannot
fully emulate:
- **SELinux contexts** (`restorecon` / `chcon` are stubbed).
- **The Magisk/KernelSU/APatch module folder lifecycle.**
- **Real FUSE mount behavior on `/sdcard/`.**

For the FULL test, use a real device — see §8.12.

### 8.14 v1.2.0 Bilingual WebUI Debugging (new)

#### Static Audit — Language toggle presence

```bash
# Toggle button present in all three pages
grep -q 'id="langToggle"' web/index.html && echo "✅ index toggle"
grep -q 'id="langToggle"' web/dashboard.html && echo "✅ dashboard toggle"
grep -q 'id="langToggle"' web/offline.html && echo "✅ offline toggle"

# Both language objects present
grep -q 'en:' web/index.html && grep -q 'ar:' web/index.html && echo "✅ index en+ar"
grep -q 'en:' web/dashboard.html && grep -q 'ar:' web/dashboard.html && echo "✅ dashboard en+ar"
grep -q 'en:' web/offline.html && grep -q 'ar:' web/offline.html && echo "✅ offline en+ar"

# localStorage key used
grep -q "dnscrypt-lang" web/index.html && echo "✅ index localStorage"
grep -q "dnscrypt-lang" web/dashboard.html && echo "✅ dashboard localStorage"
grep -q "dnscrypt-lang" web/offline.html && echo "✅ offline localStorage"

# RTL CSS rules present
grep -q '\[dir="rtl"\]' web/index.html && echo "✅ index RTL"
grep -q '\[dir="rtl"\]' web/dashboard.html && echo "✅ dashboard RTL"
grep -q '\[dir="rtl"\]' web/offline.html && echo "✅ offline RTL"

# manifest.json defaults
grep -q '"lang": "en"' web/manifest.json && echo "✅ manifest lang=en"
grep -q '"dir": "ltr"' web/manifest.json && echo "✅ manifest dir=ltr"
```

#### Runtime Audit — In-browser state

Open the WebUI in Chrome DevTools Console:

```javascript
// 1. Initial state (before any toggle)
document.documentElement.lang  // → "en"
document.documentElement.dir   // → "ltr"
localStorage.getItem('dnscrypt-lang')  // → null (or whatever was last stored)

// 2. Click the langToggle button, then re-check
document.documentElement.lang  // → "ar"
document.documentElement.dir   // → "rtl"
localStorage.getItem('dnscrypt-lang')  // → "ar"

// 3. Verify no network activity
// (Check the Network tab — clicking the toggle should NOT
//  produce any fetch/XHR/SSE requests.)

// 4. Reload the page
// → The page should still show Arabic
document.documentElement.lang  // → "ar"
```

#### Common issues

| Symptom | Cause | Fix |
|---|---|---|
| Toggle button missing | HTML markup deleted | Restore `<button id="langToggle">` in the header |
| `t('someKey')` returns the raw key name | Missing translation | Add the key to both `translations.en` and `translations.ar` |
| Text doesn't flip to RTL | Missing `[dir="rtl"]` CSS rules | Restore the RTL CSS block |
| Preference not persisted | `localStorage` read/write broken | Check `toggleLanguage()` |
| Arabic text renders as boxes (□□□) | Browser font missing Arabic glyphs | Use Chrome 88+, Firefox 92+, or Samsung Internet 16+ |
| Toggle causes page reload | Event handler bound incorrectly | Verify `addEventListener('click', ...)` not `onclick` |
| Toggle sends network requests | Server-side state was added | Revert to client-side only (`localStorage`) |

#### Verify no server-side impact

```bash
# The API is language-neutral — no lang-related fields
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq | grep -i lang
# Expected: no output

curl -s http://127.0.0.1:9090/api?action=status | jq
# Expected: {"status": "ON"} (or OFF) — no language field
```

#### Verify the SW cache is language-neutral

```bash
# The SW caches the HTML once (with both language objects inline).
# Inspect web/sw.js for CACHE_VERSION and the precache list.
grep -A20 'PRECACHE' web/sw.js | head -25
# The list should include index.html, dashboard.html, offline.html,
# and the icons. No language-specific variants.
```

---

## 9. Make Targets

### 9.1 Available Targets

| Target | Description | Version |
|--------|-------------|---|
| `make all` | Alias for `make build` | v1.0.0 |
| `make help` | Show help | v1.0.0 |
| `make version` | Show current version | v1.0.0 |
| `make build` | Build all 4 architectures | v1.0.0 |
| `make package` | Build all 4 architectures (same as build) | v1.0.0 |
| `make clean` | Remove `proxy/build/` and `dist/` | v1.0.0 |
| **`make check-backup`** | **Validate the backup shell functions** | **v1.2.0** |
| **`make check-all`** | **Run all local validations** | **v1.2.0** |
| **`make diagnose-help`** | **Show how to run `status.sh --diagnose` on a device** | **v1.2.0** |
| `make release VERSION=vX.Y.Z` | Stable / Prerelease release | v1.0.0 |
| `make release-patch VERSION=vX.Y.Z` | PATCH-only release | v1.0.0 |
| `make sync` | Sync `develop` with `main` | v1.0.0 |

### 9.2 Examples

```bash
# Show version
make version
# Expected: v1.2.0

# Show help
make help
# Expected:
#   DNSCrypt Smart Filter
#
#     VERSION: v1.2.0
#
#     Build:
#       make build                          - Build all architectures
#       make package                        - Build + ZIP
#       make clean                          - Clean outputs
#       make version                        - Show current version
#
#     Validation:
#       make check-backup                   - Validate backup shell functions
#       make check-all                      - Run all local validations
#       make diagnose-help                  - How to run diagnose on a device
#
#     Release:
#       make release VERSION=vX.Y.Z         - Stable release (from develop)
#       make release-patch VERSION=vX.Y.Z   - PATCH release (from main)
#       make sync                           - Sync develop with main

# Build
make build

# Package
make package

# Clean
make clean

# (v1.2.0) Backup shell validation
make check-backup

# (v1.2.0) All local validations
make check-all

# (v1.2.0) Device-side diagnostics help
make diagnose-help

# Stable release
make release VERSION=v1.3.0

# PATCH release
make release-patch VERSION=v1.2.1

# Sync after PATCH release
make sync
```

### 9.3 Target Behavior Details

**`make release`** — requires `VERSION=...` on the command line. Fails with a helpful message if omitted:

```text
❌ No version specified.

   Usage: make release VERSION=v1.3.0
   Current file VERSION: v1.2.0

   See docs/RELEASE_PROCESS.md for details.
```

**`make release-patch`** — same guard. Reminds you to be on `main` and to run `make sync` afterwards.

**`make sync`** — fetches `origin/main` and `origin/develop`, then fast-forwards `develop` (or falls back to a regular merge), and pushes to `origin`.

### 9.4 `make check-backup` (v1.2.0 — new)

**What it does**:
1. `bash -n` syntax check on 5 scripts:
   - `proxy/customize.sh`
   - `proxy/service.sh`
   - `proxy/functions.sh`
   - `proxy/status.sh`
   - `proxy/uninstall.sh`
2. If `shellcheck` is available: `shellcheck --severity=warning`
   on the same 5 scripts.
3. Prints a summary.

**What it does NOT do**:
- Does NOT run the scripts.
- Does NOT need a device.
- Does NOT download anything.

**When to run**:
- ✅ Before every commit that touches the backup layer.
- ✅ Before opening a PR.
- ✅ After any change to `functions.sh` or `customize.sh`.

**Example output**:

```text
━━━ Validating backup shell functions ━━━

  [1/2] bash -n syntax check...
    ✔ customize.sh
    ✔ service.sh
    ✔ functions.sh
    ✔ status.sh
    ✔ uninstall.sh

  [2/2] shellcheck (if available)...
    ✔ shellcheck clean

✅ Backup shell validation complete
```

### 9.5 `make check-all` (v1.2.0 — new)

Runs:
1. `bash -n` on **all** shell scripts (`proxy/*.sh`, `scripts/*.sh`).
2. `shellcheck --severity=warning` on all shell scripts.
3. `gofmt -l proxy/` — must be empty.
4. `make check-backup` — the backup-specific validation.

**When to run**:
- ✅ Before pushing to your feature branch.
- ✅ As a final sanity check before opening a PR.
- ✅ When CI is green but you want to verify locally.

### 9.6 Where to Add New Targets

If you add a new target:

1. Add it to `Makefile` with a `## comment` if it should appear in `make help`.
2. Update the "Available Targets" table above.
3. Update the `help:` target's output in `Makefile`.
4. Add it to `.PHONY` if it is not a file.

---

## 10. v1.2.0 — Contributor Notes

### 10.1 Branch Policy Reminder

> **📖 Full strategy**: [`docs/BRANCHING.md`](BRANCHING.md)

| Situation | Branch | PR target | Template | ADR? |
|---|---|---|---|---|
| New feature | `feature/*` | `develop` | Default | If non-trivial |
| Non-critical fix | `fix/*` | `develop` | Default | Usually no |
| Documentation | `docs/*` | `develop` | Default | No |
| Maintenance | `chore/*` | `develop` | Default | No |
| Refactor | `refactor/*` | `develop` | Default | If architectural |
| Tests | `test/*` | `develop` | Default | No |
| WebUI string change (EN + AR) | `feature/*` or `fix/*` | `develop` | Default | No |
| Release prep | `release/*` | `main` | `?template=release.md` | No |
| Emergency fix | `hotfix/*` | `main` | `?template=release.md` | No |

**Golden rule**: Never open a PR against `main` for a feature/fix/docs change.

### 10.2 When Adding a New Feature

1. ✅ Use `hasEndpoint(path, name)` instead of `strings.Contains`.
2. ✅ Use `getSystemShell()` instead of hardcoded `/system/bin/sh`.
3. ✅ Use `parsePrometheus` + `buildDashboardJSON` for any metrics.
4. ✅ Use `isPortOpenCached(port)` with per-port map.
5. ✅ Use `shellQuote()` for any dynamic path in shell.
6. ✅ Use `readConfPort()` for any port read.
7. ✅ Respect rate limiting in any new auth endpoint.
8. ✅ Use `rebuildMu` for any operation touching `rebuildBlocklist` (RACE-1).
9. ✅ Use `runtime_info` for any endpoint needing ports (PORT-2).
10. ✅ Use `sync.Once` for one-time operations (e.g. shell detection).
11. ✅ Update `docs/API.md` if you added an endpoint.
12. ✅ Update `CHANGELOG.md`.
13. ✅ Target `develop` in your PR.
14. ✅ Consider an ADR for non-trivial decisions.
15. ✅ **(v1.1.0)** If adding a new blocklist profile: update
    `MEMORY_LIMIT_*`, `memoryLimitForProfile()`, the 5 inline
    fallbacks (`functions.sh`, `service.sh`, `action.sh`,
    `status.sh`, `watchdog.sh`), and the profile table in
    `customize.sh`.
16. ✅ **(v1.1.0)** If adding a `runtime_info` field: update
    `buildRuntimeInfo()`, `web/index.html`, and
    `web/dashboard.html`.
17. ✅ **(v1.1.0)** Never hardcode `"8080"` — always use
    `MONITORING_UI_PORT`.
18. ✅ **(v1.2.0)** If adding a new destructive operation on user
    data: call `createAutoBackup(reason)` first, and document the
    new reason in `docs/BACKUP.md` §4.3.
19. ✅ **(v1.2.0)** If adding a new preserved file: update the
    `USER_FILES` list in **all 5** scripts (`customize.sh`,
    `functions.sh`, `service.sh`, `status.sh`, `uninstall.sh`),
    the "5 Preserved Files" table in `README.md`, and
    `docs/BACKUP.md` §2.
20. ✅ **(v1.2.0)** If changing the rotation policy: update the
    constant in **all 4** scripts (`customize.sh`,
    `functions.sh`, `service.sh`, `action.sh`) and
    `docs/BACKUP.md` §6.
21. ✅ **(v1.2.0)** If changing the `runtime_info.backups` schema:
    update `buildBackupInfo()` in `main.go` and keep
    `status.sh --json` in sync. See `docs/API.md` §6.1.7.
22. ✅ **(v1.2.0)** If adding a user-facing string: update
    `translations.en` **and** `translations.ar` in all three HTML
    files (`index.html`, `dashboard.html`, `offline.html`).
23. ✅ **(v1.2.0)** If touching the language toggle: verify RTL
    layout in Chrome 88+, Firefox 92+, and Samsung Internet 16+.

### 10.3 When Fixing a Bug

1. ✅ Verify the fix with `make build`.
2. ✅ Add `Audit Correction #XX` in commit footer (if v1.0.0 fix).
3. ✅ Update `docs/SECURITY.md` (if security-related).
4. ✅ Update `docs/TROUBLESHOOTING.md` (if a common issue).
5. ✅ Add HTML anchor `<a name="XXX"></a>` (if you created a new section).
6. ✅ If the fix is concurrency-related → add `defer rebuildMu.Unlock()` and verify.
7. ✅ If the fix is port-related → verify `runtime_info` output.
8. ✅ If the fix is memory-limit-related (v1.1.0) → test all 5 profiles.
9. ✅ **(v1.2.0)** If the fix is backup-related → run §8.12 in full.
10. ✅ **(v1.2.0)** If the fix is recovery-mode-related → verify the
    `§[8a] → §[9] → §[9b2]` snapshot-and-reapply flow in
    `customize.sh` still preserves all 5 files. See
    `docs/ARCHITECTURE.md` §3.10.
11. ✅ **(v1.2.0)** If the fix touches a user-facing string →
    verify both English and Arabic render correctly (§8.14).
12. ✅ **Target `develop` in your PR**.

### 10.4 When Editing Shell Scripts

1. ✅ Use `_MONITORING_UI_PORT="8080"` (Port Guard).
2. ✅ Do not write `STATUS_FILE` from a read-only function.
3. ✅ Use `pgrep -x` instead of `pgrep -f`.
4. ✅ Use `fuser -n tcp` with `tr ' ' '\n' | grep -E '^[0-9]+$' | head -1`.
5. ✅ Use `in_section` boolean when parsing TOML.
6. ✅ Test on both Android + Linux (via devcontainer).
7. ✅ **(v1.1.0)** For profile-related scripts, use the
   `get_profile_memory_hint()` helper (or its inline fallback).
8. ✅ **(v1.2.0)** Use `copy_with_context` instead of a bare `cp -f`
   for any user file — it restores SELinux context and sets mode
   `0600`.
9. ✅ **(v1.2.0)** Reference the `PERSISTENT_BACKUP` global; never
   hardcode `/sdcard/dnscrypt-webui-backup`.
10. ✅ **(v1.2.0)** Reference the `USER_FILES` global; never hardcode
    the 5-file list.
11. ✅ **(v1.2.0)** For rotation, sort by **directory name**, not
    `mtime`. This is what keeps the ordering stable across
    `rsync` copies.

### 10.5 When Editing Concurrency

1. ✅ Any operation touching `BLOCKLIST`/`ALLOWLIST`/`DENYLIST` uses `rebuildMu`.
2. ✅ Use `defer unlock()` always.
3. ✅ Avoid deadlock (do not call a function that locks the same mutex).
4. ✅ Verify with `go run -race main.go`.
5. ✅ **(v1.1.0)** `currentMemLimit` and `currentProfile` are only
   accessed while holding `memLimitMu`.
6. ✅ **(v1.2.0)** Any call to `createAutoBackup` is serialized by
   `backupMu`. Do NOT add a second mutex; if you need
   serialization, use the existing one.
7. ✅ **(v1.2.0)** `backupMu` is held for the entire shell
   invocation (`AUTO_BACKUP_TIMEOUT = 15 s`). Do NOT perform
   long operations while holding it.

### 10.6 When Editing Frontend

1. ✅ Use `window.location.hostname` instead of `127.0.0.1` (PORT-2).
2. ✅ Use `PORTS.webui` / `PORTS.dashboard` (updated from `runtime_info`).
3. ✅ Fallback to 9090/9091 before `runtime_info` loads.
4. ✅ Use `escapeHtml()` for all user input.
5. ✅ Use `textContent` instead of `innerHTML` where possible.
6. ✅ **(v1.1.0)** Display `profile_key` + `memory_limit_mb` in the
   System Info panel (with `"unknown"` fallback for older servers).
7. ✅ **(v1.2.0)** Display the 6 user-facing backup fields in the
   System Info panel (`available`, `last_backup_name`,
   `last_stable`, `in_flight_txn`, `orphan_txn`, `path`).
8. ✅ **(v1.2.0)** Any new user-facing string must be added to
   **both** `translations.en` and `translations.ar` in all three
   HTML files. The default language must remain English.
9. ✅ **(v1.2.0)** Never send the language preference to the
   server. It lives only in `localStorage['dnscrypt-lang']`.
10. ✅ **(v1.2.0)** Respect `[dir="rtl"]` CSS rules for any new
    layout element.
11. ✅ **(v1.2.0)** For the SW update banner, send `SKIP_WAITING` to
    `swRegistration.waiting`, not to
    `navigator.serviceWorker.controller`.

### 10.7 When Publishing a Release

1. ✅ **Stable / Prerelease** → `./scripts/release.sh vX.Y.Z` from `develop`.
2. ✅ **PATCH-only** → `./scripts/release-patch.sh vX.Y.Z` from `main`.
3. ✅ Use the release PR template (`?template=release.md`).
4. ✅ After PATCH release → `make sync`.
5. ✅ **(v1.2.0)** Run `make check-backup` before tagging.
6. ✅ **(v1.2.0)** Verify the `upgrade-test.yml` matrix is green
   (see §8.13).
7. ✅ **(v1.2.0)** Verify the bilingual WebUI is intact
   (§8.14, Static Audit).
8. ✅ See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for details.

### 10.8 Golden Rules

> **1.** Never pollute `OUTPUT` with dynamic rules — use Custom Chains.
>
> **2.** Never write `STATUS_FILE` from read-only functions.
>
> **3.** Never use `strings.Contains` for paths — use `hasEndpoint`.
>
> **4.** Never use hardcoded `/system/bin/sh` — use `getSystemShell()`.
>
> **5.** Never skip rate limiting on new auth endpoints.
>
> **6.** Never embed the DNS version — use `proxy/dnscrypt-proxy.version`.
>
> **7.** Preserve user settings on upgrade (backup/restore).
>
> **8.** Any new metric → Prometheus → JSON.
>
> **9.** Never allow GET on `/api/auth/login` or `/api/auth/logout`.
>
> **10.** Never allow `/readyz` from outside localhost.
>
> **11.** Use `shellQuote()` for any dynamic path in shell command.
>
> **12.** Use `readConfPort()` for any port read (range check).
>
> **13.** Use `rebuildMu` for any operation touching `rebuildBlocklist`.
>
> **14.** Use `runtime_info` for ports — never hardcode in HTML.
>
> **15.** Use `defer unlock()` on every mutex.
>
> **16.** Use `sync.Once` for one-time operations.
>
> **17.** Use `window.location.hostname` in JS instead of `127.0.0.1` (LAN support).
>
> **18.** Open PRs against `develop` — never against `main` (see `docs/BRANCHING.md`).
>
> **19.** Document non-trivial decisions as ADRs — reversals require a new ADR (see `docs/adr/README.md`).
>
> **20.** Use `release-patch.sh` for PATCH-only releases — never `release.sh` directly from `main` (see [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)).
>
> **21.** **(v1.1.0)** Never hardcode the memory limit — always use
> `memoryLimitForProfile(key)` and expose the effective value via
> `runtime_info.memory_limit_mb`. Any new profile must be added to
> **five** places: `MEMORY_LIMIT_*`, `memoryLimitForProfile()`, the
> inline fallback in `functions.sh`, the inline fallback in
> `service.sh`/`action.sh`/`status.sh`/`watchdog.sh`, and the profile
> table in `customize.sh`.
>
> **22.** **(v1.2.0)** Never remove a user data file without a backup.
> Any destructive operation on user data must call
> `createAutoBackup(reason)` first (or be routed through
> `copy_with_context` for restore). Any change to the 10 defensive
> layers must update **all** of: `docs/BACKUP.md`,
> `docs/EMERGENCY.md`, `docs/SECURITY.md` §5.31, and
> `docs/ARCHITECTURE.md` §3.10.
>
> **23.** **(v1.2.0)** Never add a user-facing string to the WebUI
> without the matching **Arabic** entry. Every new key must appear
> in `translations.en` **and** `translations.ar` of `index.html`,
> `dashboard.html`, and `offline.html`. The default must remain
> English. The language preference lives in
> `localStorage['dnscrypt-lang']` and is **never** sent to the
> server.

### 10.9 Reference Map

| Topic | File |
|---------|------|
| v1.0.0 fixes | `CHANGELOG.md` §[v1.0.0] |
| v1.1.0 features | `CHANGELOG.md` §[v1.1.0] |
| v1.2.0 features | `CHANGELOG.md` §[v1.2.0] |
| Branch workflow | `docs/BRANCHING.md` |
| Release process | `docs/RELEASE_PROCESS.md` |
| ADR system | `docs/adr/README.md` |
| Dashboard JSON | `docs/API.md` |
| Exact matching | `docs/API.md` |
| Shell fallback | `docs/ARCHITECTURE.md` |
| Basic Auth rate limit | `docs/SECURITY.md` |
| Platform abstraction | `docs/ARCHITECTURE.md` |
| Metrics abstraction | `docs/ARCHITECTURE.md` |
| Login POST-only | `docs/SECURITY.md` |
| `readConfPort` range | `docs/SECURITY.md` |
| `/readyz` localhost | `docs/SECURITY.md` |
| `shellQuote` injection | `docs/SECURITY.md` |
| Auth cache | `docs/SECURITY.md` |
| `rebuildMu` (RACE-1) | `docs/SECURITY.md` |
| `runtime_info` (PORT-2) | `docs/SECURITY.md` |
| Preserve settings | `docs/SECURITY.md` |
| Contribution guide | `docs/CONTRIBUTING.md` |
| Commit convention | `docs/CONTRIBUTING.md` §5 |
| PR process | `docs/CONTRIBUTING.md` §6 |
| v1.1.0 Memory limit (MEM-1) | `docs/SECURITY.md` §5.30.1 + `docs/ARCHITECTURE.md` §3.9 |
| v1.1.0 shellQuote (MEM-2) | `docs/SECURITY.md` §5.30.2 |
| v1.1.0 Monitoring port (MEM-3) | `docs/SECURITY.md` §5.30.3 |
| **v1.2.0 Backup system** | **`docs/BACKUP.md`** |
| **v1.2.0 Emergency recovery** | **`docs/EMERGENCY.md`** |
| **v1.2.0 Data-preservation model** | **`docs/SECURITY.md` §5.31** |
| **v1.2.0 Recovery-mode fix** | **`docs/SECURITY.md` §5.32** |
| **v1.2.0 Backup & restore flow** | **`docs/ARCHITECTURE.md` §3.10** |
| **v1.2.0 BAK-1..BAK-4** | **`docs/ARCHITECTURE.md` §4.10** |
| **v1.2.0 7-field backups schema** | **`docs/API.md` §6.1.7** |
| **v1.2.0 Bilingual WebUI** | **`docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8** |
| **v1.0.0 → v1.1.0 upgrade** | **`docs/UPGRADE.md` §3.0** |
| **v1.1.0 → v1.2.0 upgrade** | **`docs/UPGRADE.md` §3.1** |
| Release scripts | `scripts/release.sh`, `scripts/release-patch.sh` |

### 10.10 Script Comparison

| Aspect | `release.sh` | `release-patch.sh` |
|---|---|---|
| **Purpose** | Stable / Prerelease | Hotfix (PATCH only) |
| **Branch** | `develop` or `release/*` | **`main`** (enforced) |
| **MAJOR bump** | Allowed | ❌ Rejected |
| **MINOR bump** | Allowed | ❌ Rejected |
| **PATCH bump** | Allowed | ✅ Required (exact +1) |
| **Delegates to** | — | `release.sh` |
| **`make` target** | `make release` | `make release-patch` |
| **ADR** | [ADR-0002](adr/0002-automated-releases.md) | [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) |

### 10.11 ADRs Referenced

| ADR | Title |
|---|---|
| [ADR-0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) |
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `scripts/release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0004](adr/0004-unified-pr-template.md) | Unified PR template (⚠️ Superseded) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

### 10.12 Full References

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture + Trade-offs + §3.10, §4.10, §6.7 |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry + §5.31, §5.32 |
| [`docs/API.md`](API.md) | HTTP API Reference + §6.1.7, §10.8 |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting (§7.8–§7.11 for backups) |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix + §5.5 |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide (§3.0, §3.1) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/FAQ.md`](FAQ.md) | Common questions (Q121–Q130 = v1.2.0) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary (BAK/MEM terms) |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/ROADMAP.md`](ROADMAP.md) | Roadmap |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
| [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) | Community guidelines |

---

📚 **References**

- [Effective Go](https://go.dev/doc/effective_go)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [golangci-lint Migration Guide](https://golangci-lint.run/product/migration-guide/)
- [Magisk Developer Guide](https://topjohnwu.github.io/Magisk/guides.html)
- [Netfilter iptables Custom Chains](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — Full architecture
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/BRANCHING.md](BRANCHING.md) — Branching strategy
- [docs/RELEASE_PROCESS.md](RELEASE_PROCESS.md) — Release process
- [docs/UPGRADE.md](UPGRADE.md) — Version upgrade guide
- [docs/BACKUP.md](BACKUP.md) — Backup system reference (v1.2.0)
- [docs/EMERGENCY.md](EMERGENCY.md) — Emergency recovery (v1.2.0)
- [docs/adr/README.md](adr/README.md) — ADR system
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guide
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting

---

<div align="center">

**Last updated**: 2026-10-02
**Version**: v1.3.0
**Author**: gasciljh

</div>