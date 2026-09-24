# Development Guide — DNSCrypt Smart Filter

> Developer guide: environment setup, building, and releasing.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Branching, Release & Decisions**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Publishing a release → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)

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
10. [v1.0.0 — Contributor Notes](#10-v100--contributor-notes)

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

**Important**: Always work on `develop`, never on `main`. See [`docs/BRANCHING.md`](BRANCHING.md) for details.

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

All tools are installed automatically via `.devcontainer/setup.sh` (including golangci-lint v2.5.0).

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

### 3.5 Build with v1.0.0

Before building, verify the v1.0.0 fixes are present:

```bash
cd proxy

# 1. v1.0.0 fixes present
grep -c 'func getSystemShell' main.go            # Expected: 1
grep -c 'func parsePrometheus' main.go           # Expected: 1
grep -c 'func buildDashboardJSON' main.go        # Expected: 1
grep -c 'func hasEndpoint' main.go               # Expected: 1
grep -c 'func shellQuote' main.go                # Expected: 1
grep -c 'func readConfPort' main.go              # Expected: 1

# 2. No hardcoded shell path
! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' main.go
# Expected: success (no result)

# 3. RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' main.go && echo "✅ RACE-1"

# 4. PORT-2 (runtime_info ports)
grep -A30 'func buildRuntimeInfo' main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# 5. Build
./build.sh --clean --parallel

# 6. Verify checksums
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
├── README.md                        # Overview (EN)
├── SECURITY.md                      # Security policy (root summary)
├── update.json                      # Auto-update metadata
├── VERSION                          # Single source of truth (v1.0.0)
│
├── .github/                         # CI/CD
│   ├── workflows/
│   │   ├── ci.yml                   # Build matrix for 4 architectures
│   │   ├── codeql.yml               # Security scanning (SAST)
│   │   └── release.yml              # Signed release + sync main → develop
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml           # Bug report template
│   │   ├── config.yml               # Issue template chooser
│   │   └── feature_request.yml      # Feature request template
│   │
│   ├── PULL_REQUEST_TEMPLATE.md     # Default PR template
│   ├── PULL_REQUEST_TEMPLATE/       # Additional templates
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
│   ├── fetch_dns_binaries.sh        # Level 4 DNS binaries fetcher
│   ├── generate-icons.sh            # PNG/ICO icon generator
│   ├── package_module.sh            # Build Magisk ZIP
│   ├── release.sh                   # Stable / Prerelease automation
│   └── release-patch.sh             # PATCH-only (hotfix) automation
│
├── proxy/                           # Backend (Go + Shell)
│   ├── action.sh                    # Magisk Action button handler
│   ├── build.sh                     # 4-arch cross-compile
│   ├── customize.sh                 # Magisk installer (with backup/restore)
│   ├── dnscrypt-proxy.toml          # DNSCrypt engine config
│   ├── dnscrypt-proxy.version       # DNS binary version (2.1.18)
│   ├── functions.sh                 # Shared shell library
│   ├── go.mod                       # Go module definition
│   ├── main.go                      # HTTP server (~3550 lines)
│   ├── post-fs-data.sh              # Early boot cleanup
│   ├── service.sh                   # Boot service + Watchdog launcher
│   ├── status.sh                    # Status display (4 modes)
│   ├── uninstall.sh                 # Cleanup on removal
│   ├── watchdog.sh                  # Standalone watchdog process
│   └── webui.conf                   # WebUI/Dashboard config
│
├── web/                             # Frontend (PWA)
│   ├── apple-touch-icon.png         # iOS icon (180×180)
│   ├── dashboard.html               # Monitoring dashboard
│   ├── favicon.ico                  # IE + bookmarks
│   ├── favicon-16x16.png            # Legacy favicon
│   ├── favicon-32x32.png            # Modern favicon
│   ├── icon-192.png                 # PWA icon (PNG, legacy browsers)
│   ├── icon-192.svg                 # PWA icon (SVG, modern browsers)
│   ├── icon-512.png                 # PWA icon (maskable PNG)
│   ├── icon-512.svg                 # PWA icon (maskable SVG)
│   ├── index.html                   # Main UI (FSM + SW Update)
│   ├── manifest.json                # PWA manifest
│   ├── offline.html                 # Offline fallback page
│   └── sw.js                        # Service Worker (v1.0.0)
│
└── docs/                            # Documentation (23 files)
    ├── adr/                         # Architecture Decision Records (7 files)
    │   ├── README.md                # ADR index + template + methodology
    │   ├── 0001-two-branch-model.md
    │   ├── 0002-automated-releases.md
    │   ├── 0003-post-release-sync.md
    │   ├── 0004-unified-pr-template.md          (⚠️ Superseded)
    │   ├── 0005-release-specific-pr-template.md
    │   └── 0006-rename-hotfix-to-release-patch.md
    │
    ├── API.md                       # HTTP API reference
    ├── ARCHITECTURE.md              # System architecture
    ├── BRANCHING.md                 # Git branching strategy
    ├── COMPATIBILITY.md             # Device compatibility matrix
    ├── CONTRIBUTING.md              # Contribution guide
    ├── DEVELOPMENT.md               # This file
    ├── DNS_BINARIES.md              # DNS binaries management
    ├── FAQ.md                       # 90+ common questions
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
| `proxy/main.go` | ~90 KB | HTTP server + task manager (Backend) |
| `proxy/functions.sh` | ~22 KB | Shared shell library (with Custom Chains) |
| `proxy/watchdog.sh` | ~14 KB | Service state monitor |
| `web/index.html` | ~135 KB | Main UI |
| `web/dashboard.html` | ~78 KB | Monitoring dashboard |

### 4.3 v1.0.0 File Changes

| File | What changed |
|---|---|
| `proxy/main.go` | +14 modifications (Fix #1, #2, #5, #6, #7, #8, #10, #11, #12 + NEW-1..NEW-6 + RACE-1 + PORT-2) |
| `proxy/customize.sh` | + backup/restore in `[8b]`/`[9c]` |
| `proxy/functions.sh` | + `fuser` PID parsing fix |
| `proxy/watchdog.sh` | + section header with comment + DNS backoff |
| `web/index.html` | + PORT-2 dynamic links |
| `web/dashboard.html` | + PORT-2 dynamic links |
| `web/offline.html` | + ports info box |
| `web/manifest.json` | + version + port notes |
| `web/sw.js` | + PNG icons in precache |
| `.pre-commit-config.yaml` | golangci-lint v2 |
| `.gitignore` | `proxy/run/*` instead of `proxy/run/` |
| `.gitattributes` | `merge=union` for `CHANGELOG.md` + `VERSION` |
| `.github/workflows/ci.yml` | + `develop` in triggers |
| `.github/workflows/codeql.yml` | + `develop` in triggers |
| `.github/workflows/release.yml` | + `Sync main → develop` step |
| `scripts/release.sh` | 🆕 New file |
| `scripts/release-patch.sh` | 🆕 New file |
| `.github/PULL_REQUEST_TEMPLATE.md` | + `🎯 Target Branch` section |
| `.github/PULL_REQUEST_TEMPLATE/release.md` | 🆕 New file |
| `.github/CODEOWNERS` | + `docs/adr/`, `release-patch.sh`, `PULL_REQUEST_TEMPLATE/` |
| `docs/BRANCHING.md` | 🆕 New file |
| `docs/RELEASE_PROCESS.md` | 🆕 New file |
| `docs/adr/README.md` | 🆕 New file |
| `docs/adr/0001-two-branch-model.md` | 🆕 New ADR |
| `docs/adr/0002-automated-releases.md` | 🆕 New ADR |
| `docs/adr/0003-post-release-sync.md` | 🆕 New ADR |
| `docs/adr/0004-unified-pr-template.md` | 🆕 New ADR (⚠️ Superseded) |
| `docs/adr/0005-release-specific-pr-template.md` | 🆕 New ADR |
| `docs/adr/0006-rename-hotfix-to-release-patch.md` | 🆕 New ADR |

---

## 5. Daily Workflow

### 5.1 Start from `develop`

```bash
git checkout develop
git pull origin develop
```

**Rule**: Always branch from `develop`, never from `main`. See [`docs/BRANCHING.md`](BRANCHING.md) §4.

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
```

### 5.4 Commit

```bash
git add proxy/main.go
git commit -m "feat(proxy): add new endpoint"
```

**v1.0.0 commit patterns**:

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

# Security fix (Login POST-only)
git commit -m "security(auth): enforce POST-only on login/logout

GET /api/auth/login?username=X&password=Y was accepted, creating
CSRF vector via <img src=...> and leaking credentials to browser
history + server logs.

Audit Correction #28
Refs: docs/SECURITY.md"
```

**Rule**: Any security/architectural fix must:
1. Mention `Audit Correction #XX` in the footer.
2. Reference `docs/SECURITY.md#...`.
3. Explain **why** (not just what).

### 5.5 Push and Open a PR

```bash
git push -u origin feature/my-feature
# Then open a Pull Request on GitHub — TARGET: develop
```

**⚠️ Critical**: Select `develop` as the **base branch** for your PR. Opening a PR against `main` for a feature will be closed.

**See** [`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md).

### 5.6 After Merge

```bash
git checkout develop
git pull origin develop
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

**Note**: GitHub can auto-delete the remote branch if `Settings → General → Automatically delete head branches` is enabled.

### 5.7 Architecture Decisions

For **non-trivial** architectural or process decisions, document them as an **ADR**:

| When | Action |
|---|---|
| New architectural decision | Create `docs/adr/NNNN-title.md` |
| Reversing a previous decision | Create a new ADR that supersedes the old one (never edit the old ADR) |
| Simple bug fix / refactor | Regular PR (no ADR) |

**Full methodology**: [`docs/adr/README.md`](adr/README.md) §3 and §7.

**Current ADRs**: 6 (see [`docs/adr/README.md`](adr/README.md) §6).

---

## 6. Release

> **📖 The full step-by-step process is documented in [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md).**
>
> This section is a **summary**.

### 6.1 Overview

Releases are triggered by pushing a version tag. Two scripts are available:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `scripts/release.sh` | Stable, Prerelease | `develop` or `release/*` | Any |
| `scripts/release-patch.sh` | Hotfix (PATCH only) | **`main`** | PATCH only |

**Stable release** (from `develop`):

```bash
./scripts/release.sh v1.1.0
```

**PATCH-only release** (from `main`):

```bash
./scripts/release-patch.sh v1.0.1
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

v1.0.0        ← current stable
v1.0.1        ← next patch (hotfix)
v1.1.0        ← next minor (feature)
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

PRs targeting `main` (from `release/*` or `hotfix/*`) use the release-specific template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.1.0?template=release.md
```

**Full decision**: [ADR-0005](adr/0005-release-specific-pr-template.md).

### 6.6 Manual Release (Fallback)

If `release.sh` is unavailable:

```bash
# 1. Ensure you are on develop
git checkout develop
git pull origin develop

# 2. Update VERSION
echo "v1.1.0" > VERSION

# 3. Update module.prop
sed -i 's/^version=.*/version=v1.1.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1010000/' module.prop

# 4. Update update.json
$EDITOR update.json

# 5. Update CHANGELOG.md
$EDITOR CHANGELOG.md

# 6. Commit + tag + push
git add VERSION module.prop update.json CHANGELOG.md
git commit -m "release: v1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin develop
git push origin v1.1.0
```

### 6.7 Full Details

See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for:
- Release types (Stable, Prerelease, Hotfix).
- `release.sh` + `release-patch.sh` options.
- GitHub Actions pipeline (11 steps).
- Post-release verification (Cosign, SBOM, SHA256).
- Rollback procedures.
- Back-merge after hotfixes.

---

## 7. CI/CD

### 7.1 `.github/workflows/ci.yml`

Runs on **push / PR to `main` or `develop`**:

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

**Total**: 12+ steps.

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

### 7.3 `.github/workflows/codeql.yml`

- Full analysis (SAST).
- `queries: security-extended`.
- **Triggers**: push/PR to `main` or `develop` + weekly.

### 7.4 Local CI Simulation

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
```

### 7.5 CI Troubleshooting

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
- Ensure you're on `v1.0.0` (has `getSystemShell` fallback).
- Verify: `grep -q 'func getSystemShell' proxy/main.go`.
- Verify `runShell`: `grep -n 'getSystemShell()' proxy/main.go`.

### 7.6 Branch Protection

Recommended settings for the repository:

- **`main`**: Require PR + 1 approval + passing CI + CodeQL.
- **`develop`**: Require passing CI + CodeQL.
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

# runtime_info (PORT-2)
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

---

## 9. Make Targets

### 9.1 Available Targets

| Target | Description |
|--------|-------------|
| `make all` | Alias for `make build` |
| `make help` | Show help |
| `make version` | Show current version |
| `make build` | Build all 4 architectures |
| `make package` | Build all architectures |
| `make clean` | Remove `proxy/build/` and `dist/` |
| `make release VERSION=vX.Y.Z` | Stable / Prerelease release |
| `make release-patch VERSION=vX.Y.Z` | PATCH-only release |
| `make sync` | Sync `develop` with `main` |

### 9.2 Examples

```bash
# Show version
make version
# Expected: v1.0.0

# Show help
make help
# Expected:
#   DNSCrypt Smart Filter
#
#     VERSION: v1.0.0
#
#     make build                          - Build all architectures
#     make package                        - Build + ZIP
#     make clean                          - Clean outputs
#     make version                        - Show current version
#
#     make release VERSION=vX.Y.Z         - Stable release (from develop)
#     make release-patch VERSION=vX.Y.Z   - PATCH release (from main)
#     make sync                           - Sync develop with main

# Build
make build

# Package
make package

# Clean
make clean

# Stable release
make release VERSION=v1.1.0

# PATCH release
make release-patch VERSION=v1.0.1

# Sync after PATCH release
make sync
```

---

## 10. v1.0.0 — Contributor Notes

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

### 10.3 When Fixing a Bug

1. ✅ Verify the fix with `make build`.
2. ✅ Add `Audit Correction #XX` in commit footer.
3. ✅ Update `docs/SECURITY.md` (if security-related).
4. ✅ Update `docs/TROUBLESHOOTING.md` (if a common issue).
5. ✅ Add HTML anchor `<a name="XXX"></a>` (if you created a new section).
6. ✅ If the fix is concurrency-related → add `defer rebuildMu.Unlock()` and verify.
7. ✅ If the fix is port-related → verify `runtime_info` output.
8. ✅ **Target `develop` in your PR**.

### 10.4 When Editing Shell Scripts

1. ✅ Use `_MONITORING_UI_PORT="8080"` (Port Guard).
2. ✅ Do not write `STATUS_FILE` from a read-only function.
3. ✅ Use `pgrep -x` instead of `pgrep -f`.
4. ✅ Use `fuser -n tcp` with `tr ' ' '\n' | grep -E '^[0-9]+$' | head -1`.
5. ✅ Use `in_section` boolean when parsing TOML.
6. ✅ Test on both Android + Linux (via devcontainer).

### 10.5 When Editing Concurrency

1. ✅ Any operation touching `BLOCKLIST`/`ALLOWLIST`/`DENYLIST` uses `rebuildMu`.
2. ✅ Use `defer unlock()` always.
3. ✅ Avoid deadlock (do not call a function that locks the same mutex).
4. ✅ Verify with `go run -race main.go`.

### 10.6 When Editing Frontend

1. ✅ Use `window.location.hostname` instead of `127.0.0.1` (PORT-2).
2. ✅ Use `PORTS.webui` / `PORTS.dashboard` (updated from `runtime_info`).
3. ✅ Fallback to 9090/9091 before `runtime_info` loads.
4. ✅ Use `escapeHtml()` for all user input.
5. ✅ Use `textContent` instead of `innerHTML` where possible.

### 10.7 When Publishing a Release

1. ✅ **Stable / Prerelease** → `./scripts/release.sh vX.Y.Z` from `develop`.
2. ✅ **PATCH-only** → `./scripts/release-patch.sh vX.Y.Z` from `main`.
3. ✅ Use the release PR template (`?template=release.md`).
4. ✅ After PATCH release → `make sync`.
5. ✅ See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for details.

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

### 10.9 Reference Map

| Topic | File |
|---------|------|
| v1.0.0 fixes | `CHANGELOG.md` |
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
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide |
| [`docs/FAQ.md`](FAQ.md) | Common questions |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
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
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — Full architecture
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections
- [docs/BRANCHING.md](BRANCHING.md) — Branching strategy
- [docs/RELEASE_PROCESS.md](RELEASE_PROCESS.md) — Release process
- [docs/adr/README.md](adr/README.md) — ADR system
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guide
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting

---

<div align="center">

**Last updated**: 2026-09-24
**Version**: v1.0.0
**Author**: gasciljh

</div>