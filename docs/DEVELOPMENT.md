# Development Guide — DNSCrypt Smart Filter

> Developer guide: environment setup, building, debugging, and releasing.

**Version**: v1.4.0
**Last updated**: 2026-10-06
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 release date.
>   • **Companion Android app integration** — the module ZIP may
>     now include `web/app-debug.apk`. The WebUI install button
>     is a direct `<a download>` link.
>   • **CodeQL `go/path-injection` closed** in `removeModule` via
>     `filepath.Base()` + `filepath.Join()` sanitization.
>   • **iOS PWA logic removed** — Android-only project.
>   • **§8.15 (new)** — v1.4.0 Companion App Debugging.
>   • **§9 (extended)** — `fetch-apk` and `check-app-version` make
>     targets documented.
>   • **§10.8 (Golden Rules)** gained **Rule #24** — companion
>     APK safety requirement.
>   • **§10.12 (Full References)** extended with the companion
>     app repository.
>   • All examples updated to reflect the current release
>     (`v1.4.0` / `v1.4.1`).
>   • **Encoding correction (this revision)**: every mojibake
>     sequence (e.g. `вҖ”` instead of `—`, `вҶ’` instead of `→`,
>     `вң…` instead of `✅`) has been replaced with proper UTF-8.
>     All section markers, arrows, checkmarks, warnings, and box
>     drawing characters now render correctly.

> **v1.3.0 changes** (previously undocumented in this file):
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **PWA install button** (WebUI) — smart, dynamic install
>     button that adapts to the browser: native
>     `beforeinstallprompt` dialog on Chromium-based browsers, or
>     a friendly unsupported-browser modal with Play Store links
>     for Chrome / Edge / Brave.
>   • **Live status LED** on the Today counter — 12×12 LED that
>     pulses green when the DNS engine is running and turns solid
>     red when stopped.
>   • **`service.sh` — DNS auto-start after boot** (critical fix):
>     the DNS engine was not starting automatically after a reboot
>     when the user had previously left the service ON.
>   • No new audit corrections.
>   • **§8.13 (new)** — v1.3.0 Boot-flow debugging.

> **v1.2.0 changes** (kept for reference):
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • **§1.2 Architectural Principles** gained 5 entries for the
>     v1.2.0 data-preservation release.
>   • **§4.3 (File Changes)** extended with a v1.2.0 column
>     documenting every file changed during the
>     data-preservation cycle.
>   • **§5.4 Commit Examples** gained 5 examples for the v1.2.0
>     additions (BAK-1 .. BAK-4, FIX-1, FIX-2).
>   • **§7 CI/CD** updated with `backup-smoke-test` and
>     `upgrade-test.yml`.
>   • **§8.12, §8.13, §8.14** (v1.2.0) — backup debugging, matrix
>     testing, bilingual WebUI debugging.
>   • **§9 Make Targets** extended with three v1.2.0 targets.
>   • **§10.8 Golden Rules** gained Rules #22 and #23.

> **📖 Branching, Release & Decisions**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Publishing a release → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)
> - Companion app repository → https://github.com/gasciljh/dnscrypt-proxy-app

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
10. [v1.4.0 — Contributor Notes](#10-v140--contributor-notes)

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
| **curl** | — | Fetch DNS binaries + companion APK |

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

**v1.1.0 additions**:

- **Dynamic Memory Limit (MEM-1)** — `memoryLimitForProfile()` sets
  the Go soft memory limit per blocklist profile. Prevents GC
  thrashing on heavy profiles.
- **Extended `shellQuote` Charset (MEM-2)** — covers `{`, `}`, `\n`,
  `\t` in addition to the 20-char set.
- **Reserved Port Constant (MEM-3)** — `MONITORING_UI_PORT` used in
  the metrics handler, no hardcoded `"8080"`.

**v1.2.0 additions**:

- **Multi-Source Discovery (Layer 1)** — the installer searches 7
  candidate locations for user data. It never asks *"is this an
  upgrade?"* — it always asks *"where is the user data?"*.
- **Persistent Backup (Layer 2)** — all user config files are
  snapshotted to `/sdcard/dnscrypt-webui-backup/`, which survives
  reboot, uninstall, and `/data` reset.
- **Transactional Upgrade (Layer 4)** — every install runs inside a
  `txn-*` directory. On failure, an automatic rollback restores the
  previous state.
- **Recovery Mode (Layer 7)** — a trigger file (`recovery`) restores
  the last known-good config on next boot.
- **Bilingual WebUI** — the WebUI ships with English as the default
  language and an in-page toggle that switches to Arabic.

**v1.3.0 additions**:

- **PWA Install Button** — a smart, dynamic install button that
  adapts to the browser (`beforeinstallprompt` on Chromium-based
  browsers, unsupported-browser modal with Play Store links
  otherwise).
- **Live Status LED** — 12×12 LED on the Today counter. Pulses green
  when the DNS engine is running, solid red when stopped.
- **DNS Auto-Start After Boot** — `service.sh` performs a bounded
  wait for WebUI readiness and then calls
  `POST /api/ensure_running_service` directly.

**v1.4.0 additions**:

- **Companion Android App Integration** — an optional
  `web/app-debug.apk` is bundled into the module ZIP. Fetched by
  `scripts/fetch_app_apk.sh`, served at `GET /app-debug.apk`.
- **CodeQL Path-Injection Hardening** — `removeModule` uses
  `filepath.Base()` + `filepath.Join()` to eliminate the
  `go/path-injection` alerts.
- **iOS PWA Removal** — Android-only project. All iOS detection
  logic removed from `web/index.html`.

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

**v1.2.0 / v1.3.0 / v1.4.0 note**: No new ADR was added in these
cycles. The 10 defensive layers, the PWA install button, and the
companion APK integration are documented as runtime additions and
feature releases — not architectural decisions. See
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
pkg install git make golang shellcheck jq python curl

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

### 3.5 Build with v1.4.0

Before building, verify all features are present:

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

# --- v1.4.0 — Companion APK ---
grep -q 'APK_FILE' main.go && echo "✅ APK_FILE constant"
grep -q '/app-debug.apk' main.go && echo "✅ APK route"
grep -q 'filepath.Base(modulePath)' main.go && echo "✅ CodeQL fix"

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
├── VERSION                          # Single source of truth (v1.4.0)
│
├── .github/                         # CI/CD
│   ├── workflows/
│   │   ├── ci.yml                   # Build matrix + backup-smoke-test + APK metadata
│   │   ├── codeql.yml               # Security scanning (SAST)
│   │   ├── release.yml              # Signed release + companion APK staging
│   │   └── upgrade-test.yml         # 42-scenario data-preservation matrix
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   │
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── PULL_REQUEST_TEMPLATE/
│   │   └── release.md
│   │
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── SECURITY.md
│
├── .devcontainer/                   # Unified dev environment
│   ├── devcontainer.json
│   └── setup.sh
│
├── scripts/                         # Build & release tools
│   ├── fetch_dns_binaries.sh        # DNS binaries fetcher (Level 4)
│   ├── fetch_app_apk.sh             # Companion APK fetcher (v1.4.0)
│   ├── generate-icons.sh            # PNG/ICO icon generator
│   ├── package_module.sh            # Build Magisk ZIP
│   ├── release.sh                   # Stable / Prerelease automation
│   └── release-patch.sh             # PATCH-only (hotfix) automation
│
├── proxy/                           # Backend (Go + Shell)
│   ├── action.sh                    # Magisk Action handler (--backup, --diagnose)
│   ├── app-apk.version              # Companion app version (v1.4.0)
│   ├── build.sh                     # 4-arch cross-compile
│   ├── customize.sh                 # Magisk installer (10 data-preservation layers)
│   ├── dnscrypt-proxy.toml          # DNSCrypt engine config
│   ├── dnscrypt-proxy.version       # DNS binary version (2.1.18)
│   ├── functions.sh                 # Shared shell library (backup helpers)
│   ├── go.mod                       # Go module definition
│   ├── main.go                      # HTTP server
│   ├── post-fs-data.sh              # Early boot cleanup
│   ├── service.sh                   # Boot service + auto-backup + DNS auto-start
│   ├── status.sh                    # Status display (incl. --diagnose)
│   ├── uninstall.sh                 # Cleanup + orphan txn preservation
│   ├── watchdog.sh                  # Standalone watchdog process
│   └── webui.conf                   # WebUI/Dashboard config
│
├── web/                             # Frontend (bilingual: EN default + AR toggle)
│   ├── apple-touch-icon.png
│   ├── app-debug.apk                # Companion APK (optional, v1.4.0)
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
└── docs/                            # Documentation (25 files + 7 ADRs)
    ├── adr/
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
    ├── RELEASE_PROCESS.md
    ├── ROADMAP.md
    ├── SECURITY.md
    ├── TROUBLESHOOTING.md
    └── UPGRADE.md
```

### 4.2 Key Files

| File | Size | Purpose |
|---|---|---|
| `proxy/main.go` | ~95 KB | HTTP server + task manager + auto-backup + APK route |
| `proxy/functions.sh` | ~30 KB | Shared shell library (backup helpers) |
| `proxy/customize.sh` | ~55 KB | Installer (10 data-preservation layers) |
| `proxy/watchdog.sh` | ~16 KB | Service state monitor |
| `scripts/fetch_app_apk.sh` | ~11 KB | Companion APK fetcher (v1.4.0) |
| `web/index.html` | ~135 KB | Main UI (bilingual EN/AR + PWA button) |
| `web/dashboard.html` | ~78 KB | Monitoring dashboard (bilingual EN/AR) |

### 4.3 v1.0.0 / v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0 File Changes

| File | v1.0.0 | v1.1.0 | v1.2.0 | v1.3.0 | v1.4.0 |
|---|---|---|---|---|---|
| `proxy/main.go` | 20 fixes | MEM-1/2/3 | BAK-1..4 | — | APK route + CodeQL fix |
| `proxy/customize.sh` | Legacy backup | Port collision fix | 10 layers | — | — |
| `proxy/functions.sh` | fuser PID | `get_profile_memory_hint` | Backup helpers | — | — |
| `proxy/service.sh` | — | Profile hint | Auto-backup + rotation | DNS auto-start fix | — |
| `proxy/status.sh` | — | `--check` / `--json` | `--diagnose` (Layer 10) | — | — |
| `proxy/action.sh` | — | `--check` extension | `--backup` / `--diagnose` | — | — |
| `proxy/uninstall.sh` | — | No auto-backup | Preserves backup + orphan txn | — | — |
| `proxy/watchdog.sh` | — | Profile hint | Read-only backup snapshot | — | — |
| `web/index.html` | PORT-2 | Profile + memory | Bilingual + backup state | PWA button + LED | `<a download>` + iOS removal |
| `web/dashboard.html` | PORT-2 | Profile + memory | Bilingual + backup state | SW banner fix | — |
| `web/offline.html` | — | **CSP removal (critical)** | Bilingual + safe-box | — | — |
| `web/manifest.json` | Version + notes | `x-note-memory` | Language defaults | — | — |
| `web/sw.js` | PNG icons | `CACHE_VERSION` | Bump + docs | — | — |
| `web/icon-192.svg` | — | Header clarified | Header expanded | — | — |
| `web/icon-512.svg` | — | Header corrected | Maskable-safe-zone math | — | — |
| `.pre-commit-config.yaml` | golangci-lint v2 | + shellcheck-py | No new hooks | — | — |
| `.gitignore` | `proxy/run/*` | Removed 2 no-op negations | Backup patterns | — | + `web/app-debug.apk` |
| `.gitattributes` | `merge=union` | — | `dnscrypt-proxy.version` rule | — | + `app-apk.version` rule |
| `.editorconfig` | — | — | `[proxy/run/*.tmp_*]` | — | — |
| `.github/workflows/ci.yml` | + `develop` | — | + `backup-smoke-test` | — | + APK metadata check |
| `.github/workflows/codeql.yml` | + `develop` | — | Documentation | — | — |
| `.github/workflows/release.yml` | + sync step | — | Documentation | — | + APK fetch + stage |
| `.github/workflows/upgrade-test.yml` | — | — | **NEW** | — | — |
| `scripts/fetch_dns_binaries.sh` | Level 4 | Documentation | Documentation | Header bump | — |
| `scripts/fetch_app_apk.sh` | — | — | — | — | **NEW** |
| `scripts/package_module.sh` | — | — | Documentation | — | + optional APK bundling |
| `scripts/release.sh` | v1.0.0 | Documentation | Documentation | — | — |
| `scripts/release-patch.sh` | v1.0.0 | Documentation | Documentation | — | — |
| `proxy/app-apk.version` | — | — | — | — | **NEW** |
| `.github/PULL_REQUEST_TEMPLATE.md` | Target section | — | Data-preservation + bilingual | — | + APK checklist |
| `.github/PULL_REQUEST_TEMPLATE/release.md` | v1.0.0 | — | v1.2.0 checks | — | v1.3.0/v1.4.0 checks |
| `.github/CODEOWNERS` | `docs/adr/` | — | Data-preservation files | — | — |
| `docs/BRANCHING.md` | v1.0.0 | Rulesets fix | v1.2.0 changes | Header bump | Header + v1.4.0 |
| `docs/RELEASE_PROCESS.md` | v1.0.0 | v1.1.0 update | v1.2.0 changes | — | — |
| `docs/UPGRADE.md` | — | §3.0 | §3.1 | — | — |
| `docs/BACKUP.md` | — | — | **NEW** | — | — |
| `docs/EMERGENCY.md` | — | — | **NEW** | — | — |
| `docs/adr/README.md` | v1.0.0 | v1.1.0 | v1.2.0 | — | — |
| `docs/ARCHITECTURE.md` | — | v1.1.0 | §3.10, §4.10 | — | v1.3.0 + v1.4.0 blocks |
| `docs/API.md` | — | v1.1.0 | 7-field backups | — | `/app-debug.apk` + v1.4.0 changelog |
| `docs/SECURITY.md` | — | §5.30 | §5.31, §5.32 | — | — |
| `docs/TROUBLESHOOTING.md` | — | v1.1.0 | Backup diagnostics | — | — |
| `docs/GLOSSARY.md` | — | v1.1.0 | 20+ terms | — | — |
| `docs/HALL_OF_FAME.md` | — | Memory Architect | Data Guardian | — | Companion App Tester |
| `docs/FAQ.md` | — | Q111–Q120 | Q121–Q130 | — | — |
| `docs/INSTALL.md` | — | v1.1.0 | Manual backup | — | — |
| `docs/CONTRIBUTING.md` | — | v1.1.0 | Backup testing | — | v1.4.0 additions |
| `docs/COMPATIBILITY.md` | — | v1.1.0 | Backup compatibility | — | — |
| `docs/DEVELOPMENT.md` | — | v1.1.0 | Backup debugging | — | v1.3.0 + v1.4.0 |
| `docs/DNS_BINARIES.md` | — | v1.1.0 | Documentation | Header bump | Header + v1.4.0 note |
| `docs/ROADMAP.md` | — | v1.1.0 | v1.2.0 delivered | — | — |
| `CHANGELOG.md` | — | `[v1.1.0]` | `[v1.2.0]` | `[v1.3.0]` | `[v1.4.0]` |
| `README.md` | — | Badge + RAM table | Data Preservation | PWA button | Android App section |
| `SECURITY.md` | — | v1.1.0 | BAK summary | — | CodeQL fix |
| `.github/SECURITY.md` | — | — | v1.2.0 summary | — | — |
| `VERSION` | `v1.0.0` | `v1.1.0` | `v1.2.0` | `v1.3.0` | `v1.4.0` |
| `module.prop` | `v1.0.0` | `v1.1.0` | `v1.2.0` | `v1.3.0` | `v1.4.0` |
| `update.json` | `v1.0.0` | `v1.1.0` | `v1.2.0` | `v1.3.0` | `v1.4.0` |

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

# Verify backup shell functions
make check-backup

# Run all local validations
make check-all

# Verify companion app metadata
make check-app-version
```

### 5.4 Commit

```bash
git add proxy/main.go
git commit -m "feat(proxy): add new endpoint"
```

#### Commit patterns by version

**v1.0.0 examples (kept for reference)**:

```bash
# Architectural fix (Audit Correction)
git commit -m "fix(proxy): convert Prometheus metrics to JSON

Dashboard was broken because metricsProxyHandler returned
Prometheus text with Content-Type: application/json.

Added parsePrometheus() and buildDashboardJSON() to convert on the fly.

Audit Correction #25
Refs: docs/SECURITY.md"

# Security fix
git commit -m "security(auth): enforce rate limiting on Basic Auth

checkAuth did not record failed Basic Auth attempts, allowing
unlimited brute force on LAN.

Audit Correction #22
Refs: docs/SECURITY.md"

# Concurrency fix (RACE-1)
git commit -m "fix(concurrency): serialize rebuildBlocklist calls

Two callers could run rebuildBlocklist concurrently, corrupting BLOCKLIST.

Added rebuildMu sync.Mutex with coarse-grained locking.

Audit Correction #32
Refs: docs/SECURITY.md"

# Dynamic ports fix (PORT-2)
git commit -m "feat(api): return webui_port + dashboard_port in runtime_info

index.html and dashboard.html had hardcoded ports.

Added dynamic port discovery via runtime_info.

Audit Correction #33
Refs: docs/SECURITY.md"

# Login POST-only fix (NEW-1)
git commit -m "security(auth): enforce POST-only on login/logout

GET /api/auth/login?username=X&password=Y was accepted, creating
CSRF vector and leaking credentials to browser history.

Audit Correction #28
Refs: docs/SECURITY.md"
```

**v1.1.0 examples (kept for reference)**:

```bash
# MEM-1 — Dynamic memory limit
git commit -m "feat(proxy): add dynamic memory limit per profile

debug.SetMemoryLimit was hardcoded to 80MB for all profiles. On
'ultimate', actual working set approaches 200MB → GC thrashing.

Added memoryLimitForProfile() + applyMemoryLimit():
  light=80, normal=100, pro=120, proplus=160, ultimate=220 (MB)

Refs: docs/SECURITY.md §5.30.1
Refs: docs/ARCHITECTURE.md §3.9, §4.9.1"

# MEM-2 — Extended shellQuote charset
git commit -m "security(shell): extend shellQuote character set

Added {, }, \\n, \\t for brace expansion and word-splitting
defense-in-depth.

Refs: docs/SECURITY.md §5.30.2"

# MEM-3 — MONITORING_UI_PORT in metrics handler
git commit -m "refactor(proxy): use MONITORING_UI_PORT constant in metrics handler

metricsProxyHandler contained a hardcoded 8080 URL.

Now uses the MONITORING_UI_PORT constant.

Refs: docs/SECURITY.md §5.30.3"
```

**v1.2.0 examples (kept for reference)**:

```bash
# BAK-1 — 7-field backups schema
git commit -m "feat(api): extend runtime_info.backups to 7 fields

Added:
  in_flight_txn  — count of txn-* directories
  orphan_txn     — count of orphan-txn-* directories

The two endpoints (main.go + status.sh) now produce identical
JSON on the 7 shared fields. Additive change.

Refs: docs/SECURITY.md §5.31
Refs: docs/API.md §6.1.7
Refs: docs/BACKUP.md §8.1
Refs: docs/ARCHITECTURE.md §4.10.1"

# BAK-2 — createAutoBackup + backupMu
git commit -m "feat(backup): add pre-critical auto-backup before destructive ops

Added createAutoBackup(reason) called from 5 destructive endpoints
(4 distinct reason strings):
  - updateProfile           → 'pre-profile-change'
  - saveAllowlist           → 'pre-allowlist-save'
  - saveDenylist            → 'pre-denylist-save'
  - saveCustomRulesCombined → 'pre-custom-rules-save'
  - appendDenylist(content) → delegates to saveDenylist

Serialized by a new sync.Mutex (backupMu).

Refs: docs/SECURITY.md §5.31.3
Refs: docs/BACKUP.md §4.3, §12.5
Refs: docs/ARCHITECTURE.md §4.10.2"

# FIX-1 — Recovery-mode snapshot-and-reapply
git commit -m "fix(installer): use snapshot-and-reapply in recovery mode

Fixed a bug where the ZIP extraction step overwrote 2 of 5 restored
files. Uses §[8a] (restore + snapshot) + §[9] (extract) + §[9b2]
(re-apply from snapshot).

Refs: docs/SECURITY.md §5.32.1
Refs: docs/ARCHITECTURE.md §3.10
Refs: docs/BACKUP.md §7.5"

# FIX-2 — Service Worker update-banner
git commit -m "fix(webui): send SKIP_WAITING to the correct worker

The [Reload] button sent SKIP_WAITING to the OLD worker, causing an
infinite loop. Fixed in both index.html and dashboard.html.

Refs: docs/SECURITY.md §5.32.2

# Language — Add an EN/AR string pair
git commit -m "feat(webui): add string X in EN + AR

Added the new user-facing string X to all three HTML pages:
  - web/index.html
  - web/dashboard.html
  - web/offline.html

Refs: docs/ARCHITECTURE.md §6.7"
```

**v1.3.0 examples (new)**:

```bash
# PWA install button + live status LED
git commit -m "feat(webui): add PWA install button and live status LED

PWA install button:
  - Always visible (except when already installed / standalone).
  - Chromium-based: native beforeinstallprompt dialog.
  - Unsupported browsers: friendly modal with Play Store links.

Live status LED:
  - 12x12 LED on the Today counter.
  - Pulses green when the DNS engine is running.
  - Solid red when the service is stopped.

Refs: docs/ARCHITECTURE.md §6.4
Refs: CHANGELOG.md §[v1.3.0]"

# DNS auto-start after boot
git commit -m "fix(service): ensure DNS starts after boot

Root cause: watchdog.sh waits 30s before its first API call, by
which time the WebUI may not have finished binding. The watchdog
retries with exponential backoff, leaving DNS unavailable for
minutes after boot.

Fix: service.sh now performs a direct, bounded wait for the WebUI
to become ready (up to 60s), then calls
POST /api/ensure_running_service itself.

Refs: service.sh §[19]
Refs: CHANGELOG.md §[v1.3.0] → Fixed"
```

**v1.4.0 examples (new)**:

```bash
# Companion APK bundle
git commit -m "feat(app): bundle companion Android app in module ZIP

Added an OPTIONAL companion app asset to the module ZIP:

  - proxy/app-apk.version       — Single Source of Truth (1.0.0)
  - scripts/fetch_app_apk.sh    — fetcher (cache + SHA256 + JSON)
  - GET /app-debug.apk          — new static route in main.go
  - web/index.html              — install button uses <a download>
  - .github/workflows/release.yml — fetch + stage APK steps
  - .github/workflows/ci.yml      — verify companion app metadata
  - scripts/package_module.sh     — optional APK bundling

The APK is best-effort: a missing APK is a warning, not a failure.

Refs: docs/ARCHITECTURE.md
Refs: docs/API.md §1.3
Refs: CHANGELOG.md §[v1.4.0]"

# CodeQL path-injection fix
git commit -m "fix(api): close CodeQL path-injection in removeModule

Two alerts (go/path-injection #1, #2) closed by routing the
caller-provided path through filepath.Base() and rebuilding the
final path from the trusted MODULES_DIR constant + the sanitized
basename.

Before: os.RemoveAll(modulePath)
After:  name := filepath.Base(modulePath)
        cleanPath := filepath.Join(MODULES_DIR, name)
        os.RemoveAll(cleanPath)

Refs: docs/SECURITY.md
Refs: CHANGELOG.md §[v1.4.0] → Fixed"

# iOS PWA removal
git commit -m "refactor(webui): remove iOS PWA logic (Android-only)

Removed ~35 lines of iOS-specific logic from web/index.html:

  - isIOSDevice() helper
  - pwaStepIos1/2/3 translations (EN + AR)
  - iOS branches in getBrowserName(), isBrowserSupported(),
    getPWAInstallSteps(), showPWAInstructionsModal()

Refs: docs/ARCHITECTURE.md §6.4
Refs: CHANGELOG.md §[v1.4.0] → Removed"
```

**Rules**:
- **v1.0.0 fixes**: Mention `Audit Correction #XX` in the footer.
- **v1.1.0 runtime improvements**: Use
  `Refs: docs/SECURITY.md §5.30.N` (not an audit number).
- **v1.2.0 additions**: Use `Refs: docs/SECURITY.md §5.31` (BAK-N)
  or `§5.32` (FIX-N).
- **v1.3.0 features**: Reference `CHANGELOG.md §[v1.3.0]` and the
  relevant `docs/ARCHITECTURE.md` section.
- **v1.4.0 features**: Reference `CHANGELOG.md §[v1.4.0]`,
  `docs/ARCHITECTURE.md`, and `docs/API.md`.
- **WebUI language changes**: Always mention **both** languages
  were updated.

### 5.5 Push and Open a PR

```bash
git push -u origin feature/my-feature
# Then open a Pull Request on GitHub — TARGET: develop
```

**⚠️ Critical**: Select `develop` as the **base branch** for your PR.
Opening a PR against `main` for a feature will be closed.

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
| Reversing a previous decision | Create a new ADR that supersedes the old one |
| Simple bug fix / refactor | Regular PR (no ADR) |
| Runtime improvement that does NOT change architecture | Regular PR + SECURITY.md note (no ADR) |
| Adding an EN/AR string pair | Regular PR (no ADR) |
| **v1.3.0**: PWA button / live LED / boot fix | Regular PR (no ADR) |
| **v1.4.0**: companion APK integration | Regular PR (no ADR — additive asset) |

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
./scripts/release.sh v1.5.0
```

**PATCH-only release** (from `main`):

```bash
./scripts/release-patch.sh v1.4.1
```

Both scripts:

1. Validate the SemVer format.
2. Compute `versionCode`.
3. Update `VERSION`, `module.prop`, `update.json`.
4. Create a commit + tag.
5. Push to `origin`.

**GitHub Actions** (`.github/workflows/release.yml`) then:

1. Builds 4 architectures.
2. Fetches the companion APK (v1.4.0+) and stages it.
3. Packages the Magisk ZIP.
4. Creates the GitHub Release.
5. **Auto-syncs `main → develop`**.

### 6.2 SemVer

```text
v<MAJOR>.<MINOR>.<PATCH>[-prerelease]

v1.0.0        ← first stable release
v1.1.0        ← second stable (polish)
v1.2.0        ← third stable (data preservation)
v1.3.0        ← fourth stable (PWA + boot fix)
v1.4.0        ← fifth stable (current — companion app)
v1.4.1        ← next patch (hotfix) if needed
v1.5.0        ← next minor (feature)
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
| v1.3.0 | 1030000 |
| v1.4.0 | 1040000 |
| v1.4.1 | 1040001 |
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
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.5.0?template=release.md
```

**Full decision**: [ADR-0005](adr/0005-release-specific-pr-template.md).

### 6.6 Manual Release (Fallback)

If `release.sh` is unavailable:

```bash
# 1. Ensure you are on develop
git checkout develop
git pull origin develop

# 2. Update VERSION
echo "v1.5.0" > VERSION

# 3. Update module.prop
sed -i 's/^version=.*/version=v1.5.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1050000/' module.prop

# 4. Update update.json
$EDITOR update.json

# 5. Update CHANGELOG.md
$EDITOR CHANGELOG.md

# 6. Commit + tag + push
git add VERSION module.prop update.json CHANGELOG.md
git commit -m "release: v1.5.0"
git tag -a v1.5.0 -m "Release v1.5.0"
git push origin develop
git push origin v1.5.0
```

### 6.7 Full Details

See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for:

- Release types (Stable, Prerelease, Hotfix).
- `release.sh` + `release-patch.sh` options.
- GitHub Actions pipeline (including v1.4.0 APK steps).
- Post-release verification.
- Rollback procedures.
- Back-merge after hotfixes.

### 6.8 Upgrade Guide

See [`docs/UPGRADE.md`](UPGRADE.md) for:

- The `v1.0.0 → v1.1.0` upgrade path (§3.0).
- The `v1.1.0 → v1.2.0` upgrade path (§3.1).
- Settings preservation across upgrades.
- Rollback procedures.
- Emergency recovery.

### 6.9 Companion App Release Integration (v1.4.0)

The companion APK is published from a **separate repository**
([`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)).
The release pipeline in **this** repository does **not** build the
APK — it only **fetches** it.

**The fetch flow**:

1. `release.yml` runs the `Fetch companion Android app APK` step.
2. The script reads `proxy/app-apk.version` to determine which APK
   version to download.
3. The APK is placed in `dist/DNS-Proxy-v<version>.apk`.
4. The `Stage APK for module ZIP` step copies it to
   `web/app-debug.apk`.
5. `scripts/package_module.sh` bundles it into the ZIP
   (best-effort).

**When to bump `proxy/app-apk.version`**:

- When the companion repo publishes a **new APK release**.
- Not on every module release.

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
8. golangci-lint v2.5.0.
9. Go build (4 architectures).
10. YAML validation.
11. Scripts syntax validation.
12. Build matrix (4 archs).

**`backup-smoke-test` job** (v1.2.0):

1. `bash -n` on 8 shell scripts.
2. Function-presence checks for all 10 defensive layers.
3. `PERSISTENT_BACKUP` path consistency.
4. v1.2.0 documentation reference checks.
5. Version-consistency check across 5 files.

**Companion app metadata check** (v1.4.0):

1. `proxy/app-apk.version` format validation.
2. `scripts/fetch_app_apk.sh` presence check.

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
2. **Fetch companion APK** (v1.4.0+).
3. Build (4 archs).
4. **Stage APK for module ZIP** (v1.4.0+).
5. Package (ZIP).
6. Sign.
7. Generate SBOM.
8. Release.
9. **Sync `main → develop`**.

**v1.4.0 additions**:

- The `Fetch companion Android app APK` step runs
  `scripts/fetch_app_apk.sh --output-dir ./dist`.
- The `Stage APK for module ZIP` step copies
  `dist/DNS-Proxy-v*.apk` → `web/app-debug.apk`.
- The release assets list includes `dist/DNS-Proxy-v*.apk` +
  `.sha256`.

**v1.2.0 / v1.3.0 note**: The release pipeline structure is
unchanged from v1.2.0 — the v1.3.0 changes are client-side, and
the v1.4.0 additions are additive workflow steps.

### 7.3 `.github/workflows/codeql.yml`

- Full analysis (SAST).
- `queries: security-extended`.
- **Triggers**: push/PR to `main` or `develop` + weekly.
- **v1.4.0 note**: The last two `go/path-injection` alerts were
  closed by the `removeModule` fix in `main.go`, not by a change
  to this workflow.

### 7.4 `.github/workflows/upgrade-test.yml` (v1.2.0)

- **42-scenario matrix**: 3 root solutions × 2 source versions ×
  7 scenarios.
- **Trigger**: manual (`workflow_dispatch`) + weekly schedule.
- **Purpose**: validate the 10 defensive layers.
- **Runs in**: ~10 minutes.
- **Not part of the release pipeline** — it is a QA tool.

### 7.5 Local CI Simulation

```bash
# Go build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/main main.go && cd ..

# Linting
golangci-lint run --timeout=7m ./proxy/...
shellcheck --severity=warning proxy/*.sh scripts/*.sh
shfmt --diff --indent 4 --case-indent proxy/*.sh scripts/*.sh
gofmt -l proxy/

# Scripts syntax
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# Build
make build

# Backup shell functions
make check-backup

# All local validations
make check-all

# Companion app metadata
make check-app-version

# Verify the upgrade-test matrix is present
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

**If `backup-smoke-test` fails (v1.2.0)**:

- Verify the layer function names in `customize.sh` and
  `functions.sh`.
- Run locally: `make check-backup`.
- Check `docs/BACKUP.md` and `docs/EMERGENCY.md` are present.

**If the companion app metadata check fails (v1.4.0)**:

- Verify `proxy/app-apk.version` exists and has format `X.Y.Z`.
- Verify `scripts/fetch_app_apk.sh` is present.
- Run locally: `make check-app-version`.

### 7.7 Branch Protection

Recommended settings for the repository:

- **`main`**: Require PR + 1 approval + passing CI + CodeQL +
  Backup Smoke Test.
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

# runtime_info
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq

# Companion APK (v1.4.0)
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
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

// v1.3.0 — PWA install state
console.log(window.pwaInstalled);
console.log(window.pwaCapable);
console.log(window.deferredInstallPrompt);
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

#### NEW-4 — /readyz localhost

```bash
curl -i "http://127.0.0.1:9090/readyz"  # localhost → 200/503
curl -i "http://192.168.1.5:9091/readyz"  # LAN → 403
```

### 8.9 RACE-1 + PORT-2 Debugging

#### RACE-1 — rebuildMu mutex

```bash
# Static audit (mutex presence)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"
```

**Note**: If you see `panic: sync: unlock of unlocked mutex`,
`rebuildMu` was double-unlocked.

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
```

#### Runtime Checks

```bash
# 1. Effective limit for the active profile
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
# Expected: 80 / 100 / 120 / 160 / 220

# 2. Active profile key
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'"

# 3. Startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
```

#### GC Thrashing Symptoms (pre-v1.1.0)

```bash
# 1. Get the WebUI PID
PID=$(su -c "pgrep -x dnscrypt-webui" | head -1)

# 2. Sample CPU usage over 5 s
su -c "top -b -n 5 -d 1 -p $PID | tail -5"

# If CPU usage is > 30% while idle → GC thrashing
# Solution: check the active profile matches the device RAM tier
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

### 8.12 v1.2.0 Backup Debugging

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
| Backup directory missing on device | `/sdcard/` not mounted at install time | Reboot (`service.sh` creates it) |

### 8.13 v1.3.0 Boot-Flow Debugging

#### DNS auto-start fix (v1.3.0)

If the DNS engine does not start automatically after a reboot:

```bash
# 1. Verify the fix is present in service.sh
grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ fix marker"
grep -q 'ensure_running_service' proxy/service.sh && echo "✅ direct API call"

# 2. Check the boot log markers
su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log"
# Expected:
#   🔧 [v1.3.0 FIX] Ensuring DNS starts after boot...
#   ✅ WebUI ready after Ns
#   Calling ensure_running_service API...
#   ✅ [v1.3.0 FIX] DNS start requested successfully

# 3. Verify user intent
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
# Expected: ON (if the user wants DNS running)

# 4. Verify the watchdog token file exists
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: -rw------- root root
```

#### PWA install button (v1.3.0)

```bash
# 1. Verify the button is present
grep -q 'pwaInstallBtn' web/index.html && echo "✅ PWA button"

# 2. Verify the unsupported-browser modal
grep -q 'showPWAInstructionsModal' web/index.html && echo "✅ unsupported modal"

# 3. Verify the live status LED
grep -q 'led-on\|led-off' web/index.html && echo "✅ status LED"
```

### 8.14 v1.2.0 Testing the 42-scenario Matrix

The `.github/workflows/upgrade-test.yml` file defines a
**42-scenario matrix**. You can trigger it locally via the GitHub CLI:

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
# 2. Configure some settings (change profile, add allowlist entries)
# 3. Take a baseline snapshot
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose-before.txt

# 4. Install v1.2.0 ZIP over v1.1.0 via Magisk
# 5. Reboot and wait 60 s
# 6. Verify the result
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose-after.txt

diff /sdcard/diagnose-before.txt /sdcard/diagnose-after.txt

# 7. Verify the 5 preserved files
su -c "ls /sdcard/dnscrypt-webui-backup/current/"
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
```

**Emulation limitation**: The matrix runs in a container, not on a
real device. It cannot fully emulate SELinux contexts, the module
folder lifecycle, or real FUSE mount behavior on `/sdcard/`.

### 8.15 v1.4.0 Companion App Debugging (new)

#### Static checks

```bash
# 1. The APK version file exists and has a valid format
cat proxy/app-apk.version
# Expected: a line like "1.0.0" (no "v" prefix)

# 2. The APK fetcher exists and is executable
test -x scripts/fetch_app_apk.sh && echo "✅ fetcher present"

# 3. The main.go route is present
grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
grep -q '/app-debug.apk' proxy/main.go && echo "✅ APK route"
grep -q 'application/vnd.android.package-archive' proxy/main.go && echo "✅ APK mime type"

# 4. The install button uses <a download>
grep -q 'href="/app-debug.apk"' web/index.html && echo "✅ download link"

# 5. The release workflow has both steps
grep -q 'Fetch companion Android app APK' .github/workflows/release.yml && echo "✅ fetch step"
grep -q 'Stage APK for module ZIP' .github/workflows/release.yml && echo "✅ stage step"

# 6. The CI workflow verifies metadata
grep -q 'Verify companion app metadata' .github/workflows/ci.yml && echo "✅ CI check"

# 7. The package_module.sh handles the optional APK
grep -q 'app-debug.apk' scripts/package_module.sh && echo "✅ packaging handles APK"

# 8. The CodeQL path-injection fix is preserved
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ CodeQL fix"
```

#### Local fetcher test

```bash
# 1. Clear any cached APK
rm -rf ~/.cache/dnscrypt-proxy-webui/app
rm -rf dist/DNS-Proxy-*.apk dist/DNS-Proxy-*.apk.sha256

# 2. Run the fetcher
./scripts/fetch_app_apk.sh --output-dir ./dist --verbose

# 3. Verify the output
ls -la dist/DNS-Proxy-*.apk
ls -la dist/DNS-Proxy-*.apk.sha256
cat ~/.cache/dnscrypt-proxy-webui/app/.manifest.json | jq

# 4. Run again (should hit the cache)
./scripts/fetch_app_apk.sh --output-dir ./dist
# Expected: "cache hit" and no network request
```

#### Offline mode test

```bash
# 1. Clear the cache
rm -rf ~/.cache/dnscrypt-proxy-webui/app

# 2. Run with --offline
./scripts/fetch_app_apk.sh --output-dir ./dist --offline
# Expected: exit code 1 with "cache missing (offline mode)"
```

#### Runtime test on device

```bash
# 1. Install a build that includes the APK
# 2. Verify the route
curl -sI http://127.0.0.1:9090/app-debug.apk | grep -i content-type
# Expected: application/vnd.android.package-archive

# 3. Verify the Cache-Control header
curl -sI http://127.0.0.1:9090/app-debug.apk | grep -i cache-control
# Expected: public, max-age=3600, immutable

# 4. Verify the WebUI install button works
# → Open the WebUI → click the install button → verify download starts
```

#### Fallback test (APK absent)

```bash
# 1. Temporarily move the APK away
su -c "mv /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk /data/local/tmp/app-debug.apk.bak"

# 2. Verify the route now returns 404
curl -sI http://127.0.0.1:9090/app-debug.apk | head -1
# Expected: HTTP/1.1 404 Not Found

# 3. Restore the APK
su -c "mv /data/local/tmp/app-debug.apk.bak /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk"
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
| `make package` | Build + package the Magisk ZIP (+ fetch APK) | v1.0.0 / v1.4.0 |
| `make clean` | Remove `proxy/build/` and `dist/` | v1.0.0 |
| `make check-backup` | Validate the backup shell functions | v1.2.0 |
| `make check-all` | Run all local validations | v1.2.0 |
| `make check-docs` | Verify required documentation | v1.2.0 |
| `make check-adr` | Verify committed ADRs | v1.2.0 |
| `make diagnose-help` | Show how to run `status.sh --diagnose` on a device | v1.2.0 |
| **`make fetch-apk`** | **Fetch the companion APK into `dist/`** | **v1.4.0** |
| **`make check-app-version`** | **Validate `proxy/app-apk.version`** | **v1.4.0** |
| `make release VERSION=vX.Y.Z` | Stable / Prerelease release | v1.0.0 |
| `make release-patch VERSION=vX.Y.Z` | PATCH-only release | v1.0.0 |
| `make sync` | Sync `develop` with `main` | v1.0.0 |

### 9.2 Examples

```bash
# Show version
make version
# Expected: v1.4.0

# Show help
make help

# Build
make build

# Package (with APK fetch)
make package

# Clean
make clean

# Backup shell validation
make check-backup

# All local validations
make check-all

# Device-side diagnostics help
make diagnose-help

# Companion app APK
make fetch-apk
make check-app-version

# Stable release
make release VERSION=v1.5.0

# PATCH release
make release-patch VERSION=v1.4.1

# Sync after PATCH release
make sync
```

### 9.3 Target Behavior Details

**`make release`** — requires `VERSION=...` on the command line.
Fails with a helpful message if omitted.

**`make release-patch`** — same guard. Reminds you to be on `main`
and to run `make sync` afterwards.

**`make sync`** — fetches `origin/main` and `origin/develop`, then
fast-forwards `develop` (or falls back to a regular merge), and
pushes to `origin`.

### 9.4 `make check-backup` (v1.2.0)

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

### 9.5 `make check-all` (v1.2.0)

Runs:

1. `bash -n` on **all** shell scripts.
2. `shellcheck --severity=warning` on all shell scripts.
3. `gofmt -l proxy/` — must be empty.
4. `make check-backup`.
5. `make check-docs`.
6. `make check-app-version` (v1.4.0).

**When to run**:

- ✅ Before pushing to your feature branch.
- ✅ As a final sanity check before opening a PR.
- ✅ When CI is green but you want to verify locally.

### 9.6 `make fetch-apk` (v1.4.0)

Downloads the companion APK from the
[`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)
releases into `dist/DNS-Proxy-v<version>.apk` plus a `.sha256` sidecar.

**What it does**:

1. Reads the version from `proxy/app-apk.version`.
2. Checks the local cache (`~/.cache/dnscrypt-proxy-webui/app`).
3. Downloads if missing.
4. Verifies the SHA256 and writes `.manifest.json`.
5. Copies the APK into `dist/`.

**When to run**:

- ✅ Before `make package` if you want the APK in the ZIP.
- ✅ After bumping `proxy/app-apk.version`.

**Options**:

```bash
./scripts/fetch_app_apk.sh --verbose
./scripts/fetch_app_apk.sh --offline
./scripts/fetch_app_apk.sh --force
./scripts/fetch_app_apk.sh --json | jq .
```

### 9.7 `make check-app-version` (v1.4.0)

Validates `proxy/app-apk.version` format (`X.Y.Z`, no `v` prefix).

```bash
make check-app-version
# Expected:
#   ✅ proxy/app-apk.version: 1.0.0 (valid)
#   ✅ scripts/fetch_app_apk.sh present
```

**When to run**:

- ✅ Before every release (the release workflow does it too).
- ✅ After any change to `proxy/app-apk.version`.
- ✅ After any change to `scripts/fetch_app_apk.sh`.

### 9.8 Where to Add New Targets

If you add a new target:

1. Add it to `Makefile` with a `## comment` if it should appear in
   `make help`.
2. Update the "Available Targets" table above.
3. Update the `help:` target's output in `Makefile`.
4. Add it to `.PHONY` if it is not a file.

---

## 10. v1.4.0 — Contributor Notes

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

**Golden rule**: Never open a PR against `main` for a
feature/fix/docs change.

### 10.2 When Adding a New Feature

1. ✅ Use `hasEndpoint(path, name)` instead of `strings.Contains`.
2. ✅ Use `getSystemShell()` instead of hardcoded `/system/bin/sh`.
3. ✅ Use `parsePrometheus` + `buildDashboardJSON` for any metrics.
4. ✅ Use `isPortOpenCached(port)` with per-port map.
5. ✅ Use `shellQuote()` for any dynamic path in shell.
6. ✅ Use `readConfPort()` for any port read.
7. ✅ Respect rate limiting in any new auth endpoint.
8. ✅ Use `rebuildMu` for any operation touching `rebuildBlocklist`.
9. ✅ Use `runtime_info` for any endpoint needing ports (PORT-2).
10. ✅ Use `sync.Once` for one-time operations.
11. ✅ Update `docs/API.md` if you added an endpoint.
12. ✅ Update `CHANGELOG.md`.
13. ✅ Target `develop` in your PR.
14. ✅ Consider an ADR for non-trivial decisions.
15. ✅ **(v1.1.0)** If adding a new blocklist profile: update
    `MEMORY_LIMIT_*`, `memoryLimitForProfile()`, the 5 inline
    fallbacks, and the profile table in `customize.sh`.
16. ✅ **(v1.1.0)** If adding a `runtime_info` field: update
    `buildRuntimeInfo()`, `web/index.html`, and
    `web/dashboard.html`.
17. ✅ **(v1.1.0)** Never hardcode `"8080"` — always use
    `MONITORING_UI_PORT`.
18. ✅ **(v1.2.0)** If adding a new destructive operation on user
    data: call `createAutoBackup(reason)` first, and document the
    new reason in `docs/BACKUP.md` §4.3.
19. ✅ **(v1.2.0)** If adding a new preserved file: update the
    `USER_FILES` list in **all 5** scripts, the "5 Preserved
    Files" table in `README.md`, and `docs/BACKUP.md` §2.
20. ✅ **(v1.2.0)** If changing the rotation policy: update the
    constant in **all 4** scripts and `docs/BACKUP.md` §6.
21. ✅ **(v1.2.0)** If changing the `runtime_info.backups` schema:
    update `buildBackupInfo()` in `main.go` and keep
    `status.sh --json` in sync.
22. ✅ **(v1.2.0)** If adding a user-facing string: update
    `translations.en` **and** `translations.ar` in all three HTML
    files.
23. ✅ **(v1.2.0)** If touching the language toggle: verify RTL
    layout in Chrome 88+, Firefox 92+, and Samsung Internet 16+.
24. ✅ **(v1.3.0)** If touching the PWA install button: verify
    the Chromium flow, the unsupported-browser modal, and the
    Play Store links.
25. ✅ **(v1.3.0)** If touching the boot flow: verify the DNS
    auto-start fix still works (see §8.13).
26. ✅ **(v1.4.0)** If adding a new static route: use
    `serveStaticAssets` and follow the per-extension
    Cache-Control pattern.
27. ✅ **(v1.4.0)** If touching the companion APK integration:
    update `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`,
    and the release workflow in lockstep.
28. ✅ **(v1.4.0)** If touching `removeModule`: keep the
    `filepath.Base()` + `filepath.Join()` sanitization.

### 10.3 When Fixing a Bug

1. ✅ Verify the fix with `make build`.
2. ✅ Add `Audit Correction #XX` in commit footer (if v1.0.0 fix).
3. ✅ Update `docs/SECURITY.md` (if security-related).
4. ✅ Update `docs/TROUBLESHOOTING.md` (if a common issue).
5. ✅ Add HTML anchor `<a name="XXX"></a>` (if a new section).
6. ✅ If the fix is concurrency-related → add
   `defer rebuildMu.Unlock()` and verify.
7. ✅ If the fix is port-related → verify `runtime_info` output.
8. ✅ If the fix is memory-limit-related (v1.1.0) → test all 5
   profiles.
9. ✅ **(v1.2.0)** If the fix is backup-related → run §8.12 in
   full.
10. ✅ **(v1.2.0)** If the fix is recovery-mode-related → verify
    the `§[8a] → §[9] → §[9b2]` snapshot-and-reapply flow.
11. ✅ **(v1.2.0)** If the fix touches a user-facing string →
    verify both English and Arabic render correctly.
12. ✅ **(v1.3.0)** If the fix is boot-flow-related → verify the
    DNS auto-start fix (see §8.13).
13. ✅ **(v1.3.0)** If the fix is PWA-related → verify the install
    button and the unsupported-browser modal.
14. ✅ **(v1.4.0)** If the fix is companion-APK-related → run the
    full §8.15 test suite.
15. ✅ **(v1.4.0)** If the fix touches `removeModule` → verify the
    CodeQL path-injection fix is preserved.
16. ✅ Target `develop` in your PR.

### 10.4 When Editing Shell Scripts

1. ✅ Use `_MONITORING_UI_PORT="8080"` (Port Guard).
2. ✅ Do not write `STATUS_FILE` from a read-only function.
3. ✅ Use `pgrep -x` instead of `pgrep -f`.
4. ✅ Use `fuser -n tcp` with `tr ' ' '\n' | grep -E '^[0-9]+$' | head -1`.
5. ✅ Use `in_section` boolean when parsing TOML.
6. ✅ Test on both Android + Linux (via devcontainer).
7. ✅ **(v1.1.0)** For profile-related scripts, use the
   `get_profile_memory_hint()` helper.
8. ✅ **(v1.2.0)** Use `copy_with_context` instead of a bare
   `cp -f` for any user file.
9. ✅ **(v1.2.0)** Reference the `PERSISTENT_BACKUP` global; never
   hardcode the path.
10. ✅ **(v1.2.0)** Reference the `USER_FILES` global; never
    hardcode the 5-file list.
11. ✅ **(v1.2.0)** For rotation, sort by **directory name**, not
    mtime.
12. ✅ **(v1.3.0)** Keep the `WATCHDOG_TOKEN_FILE` guard in
    `service.sh §[19]` so the script runs even if `functions.sh`
    failed to load.
13. ✅ **(v1.4.0)** When editing `scripts/fetch_app_apk.sh`, keep
    the cache-first + SHA256 + JSON output behavior.

### 10.5 When Editing Concurrency

1. ✅ Any operation touching `BLOCKLIST`/`ALLOWLIST`/`DENYLIST`
   uses `rebuildMu`.
2. ✅ Use `defer unlock()` always.
3. ✅ Avoid deadlock (do not call a function that locks the same
   mutex).
4. ✅ Verify with `go run -race main.go`.
5. ✅ **(v1.1.0)** `currentMemLimit` and `currentProfile` are only
   accessed while holding `memLimitMu`.
6. ✅ **(v1.2.0)** Any call to `createAutoBackup` is serialized by
   `backupMu`. Do NOT add a second mutex.
7. ✅ **(v1.2.0)** `backupMu` is held for the entire shell
   invocation (`AUTO_BACKUP_TIMEOUT = 15 s`). Do NOT perform long
   operations while holding it.

### 10.6 When Editing Frontend

1. ✅ Use `window.location.hostname` instead of `127.0.0.1` (PORT-2).
2. ✅ Use `PORTS.webui` / `PORTS.dashboard` (updated from
   `runtime_info`).
3. ✅ Fallback to 9090/9091 before `runtime_info` loads.
4. ✅ Use `escapeHtml()` for all user input.
5. ✅ Use `textContent` instead of `innerHTML` where possible.
6. ✅ **(v1.1.0)** Display `profile_key` + `memory_limit_mb` in the
   System Info panel.
7. ✅ **(v1.2.0)** Display the 6 user-facing backup fields in the
   System Info panel.
8. ✅ **(v1.2.0)** Any new user-facing string must be added to
   **both** `translations.en` and `translations.ar` in all three
   HTML files.
9. ✅ **(v1.2.0)** Never send the language preference to the server.
10. ✅ **(v1.2.0)** Respect `[dir="rtl"]` CSS rules for any new
    layout element.
11. ✅ **(v1.2.0)** For the SW update banner, send `SKIP_WAITING` to
    `swRegistration.waiting`.
12. ✅ **(v1.3.0)** Keep the `pwaInstallBtn` smart-install flow
    (native dialog + unsupported-browser fallback).
13. ✅ **(v1.3.0)** Keep the live status LED in sync with
    `currentStatus` (see `updateStatsDisplay()`).
14. ✅ **(v1.4.0)** Keep the install button as
    `<a href="/app-debug.apk" download>`; do not reintroduce a
    JavaScript click handler.
15. ✅ **(v1.4.0)** Do not re-add iOS-specific logic
    (`isIOSDevice()`, `pwaStepIos1/2/3`, iOS branches) — the
    project is Android-only.

### 10.7 When Publishing a Release

1. ✅ **Stable / Prerelease** → `./scripts/release.sh vX.Y.Z` from
   `develop`.
2. ✅ **PATCH-only** → `./scripts/release-patch.sh vX.Y.Z` from
   `main`.
3. ✅ Use the release PR template (`?template=release.md`).
4. ✅ After PATCH release → `make sync`.
5. ✅ Run `make check-backup`.
6. ✅ Run `make check-app-version`.
7. ✅ Verify the `upgrade-test.yml` matrix is green.
8. ✅ Verify the bilingual WebUI is intact.
9. ✅ Verify the PWA install button + live status LED (v1.3.0+).
10. ✅ Verify the DNS auto-start fix (v1.3.0+).
11. ✅ Verify the companion APK integration (v1.4.0+).
12. ✅ See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for
    details.

### 10.8 Golden Rules

> **1.** Never pollute `OUTPUT` with dynamic rules — use Custom
> Chains.
>
> **2.** Never write `STATUS_FILE` from read-only functions.
>
> **3.** Never use `strings.Contains` for paths — use `hasEndpoint`.
>
> **4.** Never use hardcoded `/system/bin/sh` — use
> `getSystemShell()`.
>
> **5.** Never skip rate limiting on new auth endpoints.
>
> **6.** Never embed the DNS version — use
> `proxy/dnscrypt-proxy.version`.
>
> **7.** Preserve user settings on upgrade (backup/restore).
>
> **8.** Any new metric → Prometheus → JSON.
>
> **9.** Never allow GET on `/api/auth/login` or
> `/api/auth/logout`.
>
> **10.** Never allow `/readyz` from outside localhost.
>
> **11.** Use `shellQuote()` for any dynamic path in shell command.
>
> **12.** Use `readConfPort()` for any port read (range check).
>
> **13.** Use `rebuildMu` for any operation touching
> `rebuildBlocklist`.
>
> **14.** Use `runtime_info` for ports — never hardcode in HTML.
>
> **15.** Use `defer unlock()` on every mutex.
>
> **16.** Use `sync.Once` for one-time operations.
>
> **17.** Use `window.location.hostname` in JS instead of
> `127.0.0.1` (LAN support).
>
> **18.** Open PRs against `develop` — never against `main`.
>
> **19.** Document non-trivial decisions as ADRs — reversals
> require a new ADR.
>
> **20.** Use `release-patch.sh` for PATCH-only releases — never
> `release.sh` directly from `main`.
>
> **21.** **(v1.1.0)** Never hardcode the memory limit — always
> use `memoryLimitForProfile(key)` and expose the effective value
> via `runtime_info.memory_limit_mb`. Any new profile must be
> added to **five** places.
>
> **22.** **(v1.2.0)** Never remove a user data file without a
> backup. Any destructive operation on user data must call
> `createAutoBackup(reason)` first. Any change to the 10 defensive
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
>
> **24.** **(v1.4.0)** Never commit the companion APK
> (`web/app-debug.apk`) to git — it is a build artifact. Never
> change the APK fetch/stage logic without a matching update in
> `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`, and
> `.github/workflows/release.yml`. Always keep the install button
> as `<a href="/app-debug.apk" download>`.

### 10.9 Reference Map

| Topic | File |
|---------|------|
| v1.0.0 fixes | `CHANGELOG.md` §[v1.0.0] |
| v1.1.0 features | `CHANGELOG.md` §[v1.1.0] |
| v1.2.0 features | `CHANGELOG.md` §[v1.2.0] |
| v1.3.0 features | `CHANGELOG.md` §[v1.3.0] |
| v1.4.0 features | `CHANGELOG.md` §[v1.4.0] |
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
| v1.2.0 Backup system | `docs/BACKUP.md` |
| v1.2.0 Emergency recovery | `docs/EMERGENCY.md` |
| v1.2.0 Data-preservation model | `docs/SECURITY.md` §5.31 |
| v1.2.0 Recovery-mode fix | `docs/SECURITY.md` §5.32 |
| v1.2.0 Backup & restore flow | `docs/ARCHITECTURE.md` §3.10 |
| v1.2.0 BAK-1..BAK-4 | `docs/ARCHITECTURE.md` §4.10 |
| v1.2.0 7-field backups schema | `docs/API.md` §6.1.7 |
| v1.2.0 Bilingual WebUI | `docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8 |
| **v1.3.0 PWA install button** | **`docs/ARCHITECTURE.md` §6.4 + `CHANGELOG.md` §[v1.3.0]** |
| **v1.3.0 Live status LED** | **`docs/ARCHITECTURE.md` §6.4 + `CHANGELOG.md` §[v1.3.0]** |
| **v1.3.0 DNS auto-start fix** | **`proxy/service.sh` §[19] + `CHANGELOG.md` §[v1.3.0]** |
| **v1.4.0 Companion APK** | **`scripts/fetch_app_apk.sh` + `proxy/app-apk.version` + `docs/API.md` §1.3** |
| **v1.4.0 CodeQL fix** | **`docs/SECURITY.md` + `proxy/main.go` (`removeModule`)** |
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
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture + Trade-offs |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry |
| [`docs/API.md`](API.md) | HTTP API Reference |
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process guide |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide |
| [`docs/BACKUP.md`](BACKUP.md) | Backup system reference (v1.2.0) |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | Emergency recovery (v1.2.0) |
| [`docs/FAQ.md`](FAQ.md) | Common questions |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/ROADMAP.md`](ROADMAP.md) | Roadmap |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
| [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) | Community guidelines |
| [dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) | Companion Android app repository (v1.4.0) |

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

---

<div align="center">

**Last updated**: 2026-10-06
**Version**: v1.4.0
**Author**: gasciljh

</div>