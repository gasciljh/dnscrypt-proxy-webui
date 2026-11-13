# Contributing to DNSCrypt Smart Filter

Guidance for contributing effectively to the project.

**Version**: v1.6.0 (Global Edition)
**Last updated**: 2026-11-13
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

This file consolidates the former `CONTRIBUTING.md`,
`DEVELOPMENT.md`, `BRANCHING.md`, `RELEASE_PROCESS.md`, and
`HALL_OF_FAME.md` into one guide. It replaces all five as of
v1.5.0, and was extended in v1.6.0 with the modular shell
architecture (`lib/`) and the timezone-fix notes (§18).

**Companion documents**:

| Topic | File |
|---|---|
| End-user install, upgrade, troubleshoot | `docs/GUIDE.md` |
| Technical reference (architecture, API, backup) | `docs/REFERENCE.md` |
| Security model + audit registry | `SECURITY.md` |
| Documentation map (structure, ceilings) | `docs/MAP.md` |
| Version history (v1.0.0 → v1.6.0) | `CHANGELOG.md` |
| ADR index | `docs/adr/README.md` |
| Future plans | `docs/ROADMAP.md` |

---

## Table of Contents

1. [Welcome](#1-welcome)
2. [How to Contribute](#2-how-to-contribute)
3. [Development Setup](#3-development-setup)
4. [Project Structure](#4-project-structure)
5. [Branch Strategy](#5-branch-strategy)
6. [Commit Convention](#6-commit-convention)
7. [Pull Request Process](#7-pull-request-process)
8. [Coding Standards](#8-coding-standards)
9. [Testing Requirements](#9-testing-requirements)
10. [Documentation](#10-documentation)
11. [Release Process](#11-release-process)
12. [Branch Protection](#12-branch-protection)
13. [Hotfix Flow](#13-hotfix-flow)
14. [Recognition](#14-recognition)
15. [Where to Ask for Help](#15-where-to-ask-for-help)
16. [Quick Reference](#16-quick-reference)
17. [v1.5.0-Specific Notes](#17-v150-specific-notes)
18. [v1.6.0-Specific Notes](#18-v160-specific-notes)

---

## 1. Welcome

We pledge to make participation in this project a
**harassment-free experience** for everyone. Full standards,
scope, and enforcement are in
[`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md).

**Language policy**:
- **WebUI**: bilingual — English default + Arabic toggle
  (`localStorage['dnscrypt-lang']`). Every new user-facing string
  needs **both** `translations.en` and `translations.ar`.
- **Documentation**: English-only by convention. Community
  translations are welcome as separate files
  (`docs/*.<lang>.md`).

**Security reports**: see `SECURITY.md` §1 — do **not** open a
public issue for vulnerabilities.

---

## 2. How to Contribute

### 2.1 Contribution types

| Type | Path |
|---|---|
| Bug report | Issue (bug_report.yml) |
| Feature request | Issue (feature_request.yml) — discuss first |
| Documentation | Direct PR — no prior issue |
| Bug fix | PR with a linked issue |
| Feature | Issue first, then PR after approval |
| Translation (docs) | PR to `docs/*.<lang>.md` |
| WebUI string (EN + AR) | PR updating both languages (§5.8) |
| Security fix | Contact via `SECURITY.md` §1 |
| Architectural decision | Propose an ADR (§5.9) |

### 2.2 Before starting

- **Large features**: open an issue, explain the idea, wait for
  approval.
- **Small fixes** (typos, obvious bugs): PR directly against
  `develop`.

### 2.3 What we welcome

- Bug fixes and performance improvements (with numbers).
- Documentation improvements and translations.
- WebUI string improvements (with both EN + AR entries).
- Platform tests (Linux / macOS / WSL2).
- Dashboard JSON reports across browsers.
- ADRs for non-trivial decisions.
- Runtime-test reports: memory behavior per RAM tier, backup
  restore across devices, rotation semantics (SNAP-*/ROT-*),
  companion app install across ROMs.
- **v1.6.0**: modular `lib/*.sh` improvements, timezone rendering
  validation across devices/timezones.

### 2.4 What we reject

- Complete rewrites without discussion.
- Structural changes without compelling reason.
- External dependencies without an ADR (see ADR-0002).
- "Formatting-only" PRs.
- Changes to the 10 defensive layers without updating
  `docs/REFERENCE.md` §4 and `docs/GUIDE.md` §8.
- Adding an English WebUI string without the Arabic entry.
- Changing rotation semantics without keeping all 8 consumers in
  sync (`docs/REFERENCE.md` §4.6.5).
- Changing the companion APK fetch/stage logic without updating
  `scripts/fetch_app_apk.sh`, `proxy/app-apk.version`, and the
  release workflow in lockstep.
- **v1.6.0**: adding a `lib/*.sh` module without updating
  `boot-mini.sh`, `ci.yml` Step 9, and `docs/REFERENCE.md` §1.4.

---

## 3. Development Setup

### 3.1 Requirements

| Tool | Minimum | Required? |
|---|:---:|:---:|
| **Go** | 1.22+ | ✅ |
| **Android NDK** | r26b+ | Recommended |
| **Make** | 4.0+ | ✅ |
| **Git** | 2.30+ | ✅ |
| **ShellCheck** | 0.10+ | Recommended (local-only since 2026-09-30) |
| **shfmt** | 3.8+ | Recommended |
| **golangci-lint** | v2.5.0+ | Recommended |
| **jq** | 1.6+ | ⚠️ Strongly recommended (`release.sh` / `package_module.sh` degrade gracefully; the `x-note-v<XYZ>` check and `update.json` rewrite are skipped without it) |
| **sha256sum** | coreutils | ✅ (required for backup integrity + `make package` SHA256 sidecar) |
| **curl** | — | ✅ |
| **zip / unzip** | — | ✅ |

**ShellCheck note**: removed from CI on 2026-09-30. It runs
locally via `make check-backup` / `make check-all`. CI enforces
shell safety through `bash -n` and the integration checks (Step 8
`install_app.sh`, Step 9 Layer-0/1/2 (v1.6.0), Step 10 port sync).

### 3.2 Quick install

**Ubuntu / Debian**:

```bash
sudo apt install -y git make curl jq coreutils golang-1.22 shellcheck \
                    python3 zip unzip
curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64" \
    -o /tmp/shfmt && sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | \
    sudo sh -s -- -b /usr/local/bin v2.5.0
```

**macOS**:

```bash
brew install go make jq coreutils shellcheck shfmt golangci-lint
```

**DevContainer (recommended)**:

```bash
code .
# F1 → "Dev Containers: Reopen in Container"
```

### 3.3 Clone & verify

```bash
git clone https://github.com/gasciljh/dnscrypt-proxy-webui.git
cd dnscrypt-proxy-webui
git checkout develop
git pull origin develop
make version
# Expected: v1.6.0
```

---

## 4. Project Structure

### 4.1 Layout (83 tracked files + 0-11 build artifacts)

```text
dnscrypt-proxy-webui/
├── Root files (15)           VERSION, module.prop, update.json,
│                             README.md, CHANGELOG.md, SECURITY.md,
│                             CODE_OF_CONDUCT.md, LICENSE, Makefile,
│                             .editorconfig, .gitattributes, .gitignore,
│                             .pre-commit-config.yaml, .secrets.baseline,
│                             .shellcheckrc
├── Root shell scripts (10)   customize.sh, install_app.sh, post-fs-data.sh,
│                             service.sh, action.sh, status.sh, uninstall.sh,
│                             functions.sh, boot-mini.sh, watchdog.sh
├── .github/ (12 tracked)     CODEOWNERS, dependabot.yml,
│                             PULL_REQUEST_TEMPLATE.md,
│                             PULL_REQUEST_TEMPLATE/release.md,
│                             ISSUE_TEMPLATE/{bug_report,config,feature_request}.yml,
│                             codeql/codeql-config.yml,
│                             workflows/{ci,codeql,release,upgrade-test}.yml
├── scripts/ (6)              fetch_dns_binaries.sh, fetch_app_apk.sh,
│                             generate-icons.sh, package_module.sh,
│                             release.sh, release-patch.sh
├── lib/ (6) — Layer 0        constants.sh, fallbacks.sh, process.sh,
│  (v1.6.0)                   http.sh, backup.sh, firewall.sh
├── proxy/ (8)                main.go, go.mod, go.sum, build.sh,
│                             dnscrypt-proxy.toml, dnscrypt-proxy.version,
│                             webui.conf, app-apk.version
├── web/ (13 tracked + 2)     index.html, dashboard.html, offline.html,
│                             manifest.json, sw.js, icon-{192,512}.{svg,png},
│                             apple-touch-icon.png, favicon-{16,32}.png,
│                             favicon.ico
│                             (+ app-debug.apk, + app-debug.apk.sha256 — artifacts)
├── docs/ (9 after v1.5.0)    GUIDE.md, REFERENCE.md, CONTRIBUTING.md,
│                             MAP.md, ROADMAP.md,
│                             adr/{README,0001-release-workflow,
│                                  0002-external-dependency,
│                                  0003-layered-bootstrap}.md
└── dist/                     (gitignored — build output)
```

**Canonical file counts**:

| State | Tracked | Artifacts | Total | Dirs |
|---|:---:|:---:|:---:|:---:|
| Fresh clone | 83 | 0 | 83 | 16 |
| After package | 83 | 4 | 87 | 18 |
| After full build | 83 | 11 | 94 | 19 |

**Verification**:

```bash
git ls-files | wc -l                    # → 83
find . -type d -not -path './.git/*' -not -name '.git' | wc -l   # → 16
```

### 4.2 Key files

| File | Size | Role |
|---|---:|---|
| `proxy/main.go` | ~4,900 lines | HTTP server + 4 companion-install endpoints + timezone fix (v1.6.0) |
| `install_app.sh` | ~680 lines | 5-level `pm install` cascade (v1.5.0) |
| `lib/constants.sh` | ~130 lines | Layer 0: SSOT (paths, ports, TOML parsers) (v1.6.0) |
| `lib/fallbacks.sh` | ~150 lines | Layer 0: standalone primitives (v1.6.0) |
| `lib/process.sh` | ~280 lines | Layer 0: `/proc`-based process management (v1.6.0) |
| `lib/http.sh` | ~280 lines | Layer 0: HTTP client cascade (v1.6.0) |
| `lib/backup.sh` | ~550 lines | Layer 0: user-data preservation + rotation (v1.6.0) |
| `lib/firewall.sh` | ~350 lines | Layer 0: nftables/iptables management (v1.6.0) |
| `boot-mini.sh` | ~330 lines | Layer 1: aggregator (sources `lib/*.sh`) (v1.6.0) |
| `functions.sh` | ~300 lines | Layer 2: orchestrator (sources `boot-mini.sh`) (v1.6.0) |
| `customize.sh` | ~900 lines | Installer (10 defensive layers + APK mirror) |
| `proxy/go.mod` + `go.sum` | ~1 KB | One external dep (`filepath-securejoin`) |
| `web/index.html` | ~150 KB | Main UI (bilingual EN/AR + install modal + timezone fix) |

---

## 5. Branch Strategy

### 5.1 The model

A simplified GitHub Flow with a `develop` branch:

| Property | Benefit |
|---|---|
| Stable `main` | Users always download a tested release |
| Integration preview (`develop`) | Catches issues before release |
| Isolated features | Broken feature never blocks other work |
| Squash merges | Clean, readable history |
| Automated CI | Every branch is checked |

**Core principles**:
1. `main` is sacred — always via PR.
2. `develop` is the daily driver.
3. One branch = one purpose.
4. Everything through a PR.
5. Every PR passes CI (`ci.yml` + `codeql.yml`).

### 5.2 The two permanent branches

| Branch | Purpose | Direct push |
|---|---|---|
| `main` | Production-ready code (only release commits) | ❌ Forbidden |
| `develop` | Daily integration, features land here | ⚠️ Maintainer only |

**Current state**: `main` = `v1.6.0` (released 2026-11-12). `develop` in sync via auto-sync (ADR-0001).

### 5.3 Short-lived branch types

| Prefix | Purpose | Base | Target |
|---|---|---|---|
| `feature/*` | New functionality | `develop` | `develop` |
| `fix/*` | Non-critical bug fix | `develop` | `develop` |
| `docs/*` | Documentation only | `develop` | `develop` |
| `chore/*` | Maintenance, tooling | `develop` | `develop` |
| `refactor/*` | Code refactor | `develop` | `develop` |
| `test/*` | Tests | `develop` | `develop` |
| `release/*` | Release preparation | `develop` | `main` |
| `hotfix/*` | Emergency fix | `main` | `main` + `develop` |

**Note**: WebUI string changes, companion APK changes, and
`lib/*.sh` modular changes are **not** separate branch types —
they use `feature/*` or `fix/*` or `refactor/*`.

### 5.4 Naming rules

- **Lowercase only**: `feature/webui-dark-mode` ✅
- **Hyphens, not underscores**: `fix/port-cache` ✅
- **Short and specific**: `feature/editor-fsm` ✅
- **English only** (avoids CI encoding issues).
- **No issue numbers alone**: `fix/issue-123-csrf` ✅ (not `fix/123`).

**Release branches**: version must match `VERSION` exactly —
`release/v1.6.0` ✅, `release/1.6.0` ❌, `release/v1.6` ❌.

### 5.5 The golden rule

> **Never open a PR against `main` for a feature, fix, or docs
> change.**
>
> `main` accepts PRs **only** from `release/*` and `hotfix/*`.

### 5.6 Standard workflows

**Feature / fix / docs** (identical flow, different prefix):

```bash
git checkout develop && git pull
git checkout -b feature/my-feature
# ... develop ...
make build && make check-all
git add . && git commit -m "feat(scope): add my feature"
git push -u origin feature/my-feature
# → Open PR against develop
# → Squash merge
```

**Release** (see §11 for full step-by-step):

```bash
git checkout develop && git pull
git checkout -b release/v1.6.0
./scripts/release.sh v1.6.0 --no-push
$EDITOR CHANGELOG.md
git commit -m "release: v1.6.0"
git push -u origin release/v1.6.0
# → Open PR against main using ?template=release.md
# → Merge, then publish: git checkout main && ./scripts/release.sh v1.6.0
```

**Hotfix** (see §13 for full step-by-step):

```bash
git checkout main && git pull
git checkout -b hotfix/v1.6.1-critical
# ... fix ...
git push -u origin hotfix/v1.6.1-critical
# → Open PR against main using ?template=release.md (fast-track)
# → After merge: ./scripts/release-patch.sh v1.6.1
# → Back-merge: make sync
```

### 5.7 The full release chain

| From | To | Type |
|---|---|---|
| `v1.0.0` | `v1.1.0` | MINOR |
| `v1.1.0` | `v1.2.0` | MINOR |
| `v1.2.0` | `v1.3.0` | MINOR |
| `v1.3.0` | `v1.4.0` | MINOR |
| `v1.4.0` | `v1.5.0` | MINOR |
| `v1.5.0` | **`v1.6.0`** | **MINOR (current)** |
| `v1.6.0` | `v1.6.1` | PATCH (if needed) |
| `v1.6.1` | `v1.7.0` | MINOR (planned) |

### 5.8 WebUI translation flow

The WebUI is bilingual. Every new user-facing string needs
**both** an English and an Arabic entry:

```bash
git checkout develop && git pull
git checkout -b feature/webui-string-x
# Edit web/index.html, web/dashboard.html, web/offline.html
#   → add key to translations.en AND translations.ar
#   → verify RTL layout with the toggle
git commit -m "feat(webui): add string X in EN + AR"
```

**Checklist for WebUI string PRs**:
- [ ] `translations.en` has the new key.
- [ ] `translations.ar` has the new key.
- [ ] Renders correctly in English (LTR).
- [ ] Renders correctly in Arabic (RTL).
- [ ] No `console.log` or debug text left behind.
- [ ] Default language remains English.

**Documentation translations** (`docs/*.<lang>.md`) use the
`docs/*` branch type — CI is skipped and the change is text-only.

### 5.9 ADR workflow

For non-trivial architectural or process decisions, document
them as an **ADR**.

| When | Action |
|---|---|
| New architectural decision | Create `docs/adr/NNNN-title.md` |
| Reversing a previous decision | Create a new ADR that supersedes the old one |
| Simple bug fix / refactor | Regular PR (no ADR) |
| Runtime improvement (no arch change) | Regular PR + `SECURITY.md` note |
| Adding an external Go dependency | **Must have its own ADR** (ADR-0002 policy) |
| Changing the Layered Bootstrap | **Must have its own ADR** (ADR-0003 policy) |
| Adding a `lib/*.sh` module (v1.6.0) | Extend ADR-0003 (do not create a new ADR) |

**Current ADRs** — 3 (see `docs/adr/README.md`):

| ADR | Decision |
|---|---|
| `ADR-0001` | Release workflow (two-branch model, automated releases, post-release sync, PR templates, release-patch) |
| `ADR-0002` | External dependency — `filepath-securejoin v0.7.0` |
| `ADR-0003` | Layered Bootstrap (3-layer split, extended in v1.6.0 to include `lib/*.sh` as Layer 0) |

**Full methodology**: `docs/adr/README.md`.

---

## 6. Commit Convention

Conventional Commits format:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types**:

| Type | Purpose | Version bump |
|---|---|---|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `security` | Security fix | PATCH |
| `perf` | Performance | PATCH |
| `refactor` | Refactor | PATCH |
| `docs` | Documentation | — |
| `chore` | Routine | — |
| `build` | Build system | — |
| `ci` | CI workflows | — |
| `revert` | Revert | — |
| `release` | Release | — |

**Examples**:

```bash
# ✅ Correct
feat(webui): add dark mode toggle
fix(watchdog): reset backoff on STATUS_FILE change
security(auth): enforce POST-only on login/logout
docs(api): update authentication section
refactor(shell): split primitives into 6 lib/ modules (v1.6.0)
feat(timezone): emit last_update_unix for local-time rendering (v1.6.0)

# ❌ Wrong
updated files
fix bug
WIP
```

**Breaking changes**:

```text
feat(api)!: remove legacy /v1 endpoints

BREAKING CHANGE: /v1/* endpoints removed. Use /api/* instead.
```

**Scope convention**:

| Scope | Area |
|---|---|
| `proxy` | `main.go` |
| `installer` | `customize.sh`, `uninstall.sh` |
| `service` | `service.sh`, `watchdog.sh` |
| `status` | `status.sh` |
| `action` | `action.sh` |
| `functions` | `functions.sh` |
| `lib` | `lib/*.sh` (v1.6.0) |
| `backup` | Data-preservation layers, rotation semantics |
| `app` | Companion APK integration |
| `webui` | `web/index.html` |
| `dashboard` | `web/dashboard.html` |
| `pwa` | `manifest.json`, `sw.js`, `offline.html` |
| `api` | HTTP endpoints |
| `auth` | Authentication / sessions |
| `timezone` | v1.6.0 local-time rendering fix |
| `ci` | `.github/workflows/` |
| `docs` | `docs/*.md`, `README.md` |
| `adr` | `docs/adr/` |

---

## 7. Pull Request Process

### 7.1 Target rules

| Source branch | Target branch | Template | How to select |
|---|---|---|---|
| `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` | `develop` | `.github/PULL_REQUEST_TEMPLATE.md` (default) | Automatic |
| `release/*`, `hotfix/*` | `main` | `.github/PULL_REQUEST_TEMPLATE/release.md` | Append `?template=release.md` |
| `develop` directly | ❌ Never | — | — |

### 7.2 Required checks

Every PR must pass:
- `CI / Build arm64`, `arm`, `amd64`, `386` (4 architectures).
- `CodeQL / Analyze Go`.
- `CI / Backup Smoke Test` (validates the 10 data-preservation layers).
- No merge conflicts with the target branch.
- PR template completed.
- `CHANGELOG.md` updated (if user-facing).
- Documentation updated (if applicable).

**v1.5.0 additions** (enforced by `ci.yml`):
- **Step 8** — `install_app.sh` markers, three-way trap split,
  75-second deadline, no `setenforce 0`, SELinux staging path,
  `_VERIFIER_ORIG` restore.
- **Step 9** — Layer 0 / Layer 1 / Layer 2 split integrity.
- **Step 10** — Reserved-port constant sync
  (`lib/constants.sh:_MONITORING_UI_PORT` ↔ `main.go:MONITORING_UI_PORT`).

**v1.6.0 additions** (enforced by `ci.yml`):
- **Step 9 (extended)** — verifies **all 6** `lib/*.sh` modules
  are present, that `boot-mini.sh` sources them, and that
  `functions.sh` does not redefine any Layer-0 primitive.
- **Step 10 (moved)** — `_MONITORING_UI_PORT` moved from
  `boot-mini.sh` to `lib/constants.sh`. Step 10 now checks
  `lib/constants.sh` ↔ `main.go`.

### 7.3 PR title convention

Use Conventional Commits — same types as §6.

**Examples**:

```text
feat(webui): add dark mode toggle
fix(watchdog): reset backoff on STATUS_FILE change
security(auth): enforce rate limit on Basic Auth
feat(app): add one-tap root install via 5-level pm install cascade
refactor(lib): split primitives into 6 modules (v1.6.0)
feat(timezone): emit last_update_unix in get_profile (v1.6.0)
feat(deps): add filepath-securejoin for path-injection hardening
```

### 7.4 Merge strategy

| Merge into | Strategy |
|---|---|
| `develop` | Squash |
| `main` (from `release/*`) | Squash |
| `main` (from `hotfix/*`) | Squash |

**Never use**: merge commits, rebase merges.

### 7.5 PR templates

The project uses **two** PR templates. The audience split is
deliberate:

| Branch prefix | Base | Template | How to select |
|---|---|---|---|
| `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` | `develop` | `.github/PULL_REQUEST_TEMPLATE.md` (default) | Automatic |
| `release/*`, `hotfix/*` | `main` | `.github/PULL_REQUEST_TEMPLATE/release.md` | Append `?template=release.md` |

Releases targeting `main` use the **separate** release-specific
template at `.github/PULL_REQUEST_TEMPLATE/release.md` (documented
in ADR-0001). Because GitHub only auto-applies the default
`.github/PULL_REQUEST_TEMPLATE.md`, release PRs are opened with the
query string `?template=release.md`:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/vX.Y.Z?template=release.md
```

**Why a separate file**: releases have a different lifecycle —
version correctness, `CHANGELOG` completeness, tag planning, and
rollback preparedness are the primary concerns. The reversal
history is recorded in `docs/adr/0001-release-workflow.md` §Decision → §4.

### 7.6 After merge

Always delete the source branch (GitHub can auto-delete after
merge — enabled in Repository Settings).

```bash
git checkout develop
git pull origin develop
git branch -d feature/my-feature
```

---

## 8. Coding Standards

### 8.1 Go

**Format**: `gofmt -w proxy/` + `goimports -w proxy/`

**Rules**:
- Clear variable names (`userCount` not `uc`).
- Comment every exported function.
- Handle every error (`if err != nil`).
- Use `context` on every I/O operation.
- Use `defer unlock()` on every mutex.
- No `panic()` inside libraries.
- No `fmt.Println` in production — use `logWithLevel`.
- No global variables without proper locking.

**Project-specific helpers**:
- `getSystemShell()` — any new shell execution.
- `hasEndpoint()` — any new endpoint.
- `parsePrometheus` + `buildDashboardJSON` — for metrics.
- `isPortOpenCached(port)` — per-port map.
- `shellQuote()` — any dynamic path in a shell command.
- `readConfPort()` — any port read from config.
- `rebuildMu` — any operation touching `rebuildBlocklist` (RACE-1).
- `runtime_info` — any endpoint needing actual ports (PORT-2).
- `sync.Once` — one-time initialization.
- `memoryLimitForProfile()` — any new profile.
- `applyMemoryLimit()` — only from `main()` and `updateProfile()`.
- `createAutoBackup(reason)` — before any destructive op.
- `backupMu` — serializes pre-critical backups.
- `buildBackupInfo()` — returns 7 fields (must match `status.sh --json`).
- `net.IP.IsLoopback()` — any loopback check (accepts IPv4-mapped IPv6).
- `installTokens` / `installAttempts` / `companionStateCache` — install-family state.
- `lastUpdateMu` / `lastUpdateUnixCache` — v1.6.0 timezone fix (both `last_update` and `last_update_unix` derived from same `modTime`).

### 8.2 Shell

**Format**: `shfmt -w -i 4 -ci boot-mini.sh functions.sh customize.sh install_app.sh service.sh watchdog.sh status.sh action.sh uninstall.sh post-fs-data.sh lib/*.sh scripts/*.sh`

**Rules**:
- `#!/system/bin/sh` for Android compatibility.
- **No `set -e`**. Error handling is explicit per command. `install_app.sh` relies on non-zero exit codes to fall through the 5-level cascade.
- Quote all variables: `"$var"`.
- Use `[[ ]]` where `sh` supports it (Korn shell features are available via `/system/bin/sh`).
- Use `local` for internal variables.
- Avoid `eval`.
- Avoid unquoted `$(...)`.

**Project-specific rules**:
- `_MONITORING_UI_PORT` defined in **`lib/constants.sh`** only (Layer 0). Any other redeclaration fails CI Step 10.
- The sole documented fallback: `boot-mini.sh §[4]` sets `_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because `lib/constants.sh` may fail to source during a partial extraction.
- Section tracking (`in_section` boolean) when parsing TOML.
- `STATUS_FILE` written only from `startService` / `stopService`.
- Custom Chains — never pollute `OUTPUT` / `INPUT` / `FORWARD`.
- Rotation sorts by **mtime** (`sort -rn -k1,1`), not by directory name.
- Snapshot detection requires `.manifest.json` (SNAP-MANIFEST / ROT-MANIFEST).
- Protected rotation targets: `.last_stable` + newest install snapshot (ROT-PROTECT).
- `install_app.sh` — preserve the 5-level cascade order, 75-second deadline, three-way trap split, and SELinux staging invariant.
- **Never** `setenforce 0` — staging to `/data/local/tmp/` only.
- **v1.6.0**: new `lib/*.sh` modules must have single responsibility, zero dependencies on other `lib/` modules except through documented sourcing order (constants → fallbacks → process → http → backup → firewall).
- **v1.6.0**: `boot-mini.sh` must remain an **aggregator only** — no business logic, no `case` chains for domain logic, only PATH setup + log rotation + sourcing `lib/*.sh`.
- **v1.6.0**: `functions.sh` must **not** redefine any Layer-0 primitive. CI Step 9 enforces this. Exception: the historical `log_msg` → `log_fn` alias.

### 8.3 JavaScript

**Rules**:
- `'use strict'`; `const`/`let`, not `var`; `===`, not `==`.
- Use `window.location.hostname` instead of `127.0.0.1` (LAN support).
- Use `PORTS.webui` / `PORTS.dashboard` (updated from `runtime_info`).
- Use `getDashboardUrl()` / `getWebUIUrl()` for links.
- Avoid `innerHTML` with user data — use `textContent`.
- Avoid global scope pollution.

**v1.5.0-specific**:
- The install button opens the **install-method modal (IDX-24)** via `handleCompanionInstall()`. Do **not** reintroduce `<a download>` or a `beforeinstallprompt` listener.
- Keep `renderCompanionButton()` (pure render) separate from `refreshCompanionState()` (state writer).
- All state that must survive a language toggle is re-rendered via `renderAllDynamic()`.
- For the SW update banner, send `SKIP_WAITING` to `swRegistration.waiting`.

**v1.6.0-specific**:
- `formatUnixTimestamp(unix)` is the **only** way to render a Unix timestamp. Do not use `new Date(...)` directly in render functions — always route through the helper so the fallback path (`null` return) is consistent.
- `renderProfileData()` must prefer `last_update_unix` over `last_update`. When the backend is on v1.6.0+, both are always present. When it is not (mixed-version upgrade), the fallback path keeps the UI functional.
- The `toLocaleString()` locale argument must use `currentLang === 'ar' ? 'ar-EG' : 'en-US'` — matching the rest of the UI. Do not hardcode `en-US`.

### 8.4 YAML, Markdown, EditorConfig

- YAML: 2 spaces, no tabs.
- Markdown: line length 200, `-` for lists.
- New file types: update `.gitattributes`, `.editorconfig`, `.gitignore` as needed.

### 8.5 Golden Rules (all 26)

| # | Rule |
|:-:|---|
| 1 | Never pollute `OUTPUT` with dynamic rules — use Custom Chains. |
| 2 | Never write `STATUS_FILE` from read-only functions. |
| 3 | Never use `strings.Contains` for paths — use `hasEndpoint`. |
| 4 | Never use hardcoded `/system/bin/sh` — use `getSystemShell()`. |
| 5 | Never skip rate limiting on new auth endpoints. |
| 6 | Never embed the DNS version — use `proxy/dnscrypt-proxy.version`. |
| 7 | Preserve user settings on upgrade (backup/restore). |
| 8 | Any new metric → Prometheus → JSON. |
| 9 | Never allow GET on `/api/auth/login` or `/api/auth/logout`. |
| 10 | Never allow `/readyz` from outside localhost. |
| 11 | Use `shellQuote()` for any dynamic path in shell commands. |
| 12 | Use `readConfPort()` for any port read (range check 1-65535). |
| 13 | Use `rebuildMu` for any operation touching `rebuildBlocklist`. |
| 14 | Use `runtime_info` for ports — never hardcode in HTML. |
| 15 | Use `defer unlock()` on every mutex. |
| 16 | Use `sync.Once` for one-time operations. |
| 17 | Use `window.location.hostname` in JS instead of `127.0.0.1`. |
| 18 | Open PRs against `develop` — never against `main`. |
| 19 | Document non-trivial decisions as ADRs — reversals require a new ADR. |
| 20 | Use `release-patch.sh` for PATCH-only releases — never `release.sh` directly from `main`. |
| 21 | Never hardcode the memory limit — use `memoryLimitForProfile(key)`; any new profile goes in **5** places. |
| 22 | Never remove a user data file without a backup — call `createAutoBackup(reason)`; any change to the 10 layers updates `docs/REFERENCE.md` §4, `docs/GUIDE.md` §8, `SECURITY.md` §5.32. |
| 23 | Never add a user-facing string without the matching Arabic entry; preference lives in `localStorage['dnscrypt-lang']`, never sent to server. |
| 24 | Never commit `web/app-debug.apk` or its `.sha256` to git; never change fetch/stage logic without updating `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`, and `release.yml`. |
| 25 | Never change rotation semantics (SNAP-*/ROT-*) in only one file — keep all 8 consumers in sync (`docs/REFERENCE.md` §4.6.5). |
| 26 | Never disable SELinux (`setenforce 0`); never change `CASCADE_DEADLINE_SECONDS` (75 s) without re-checking `INSTALL_TIMEOUT` (90 s); never add an external Go dependency without its own ADR; never add a Layer-0 primitive without updating `lib/<module>.sh`, `boot-mini.sh` (aggregator), and `ci.yml` Step 9. Never add a `lib/*.sh` module without updating `ci.yml` Step 9 (module presence check). |

**Note on Rule 26 (v1.6.0)**: the rule was updated to reflect the
3-layer model. Layer 0 primitives live in `lib/<module>.sh`, not
in `boot-mini.sh`. `boot-mini.sh` is only an aggregator (Layer 1).
A new Layer-0 primitive requires:
1. Adding it to the appropriate `lib/<module>.sh`.
2. Verifying `boot-mini.sh` sources the module (it already does).
3. Verifying `ci.yml` Step 9 passes (module presence + no
   redefinition in `functions.sh`).

---

## 9. Testing Requirements

### 9.1 Minimum verification by change type

| Change | Required verification |
|---|---|
| Backend Go | `make build` succeeds without warnings |
| Shell functions | `bash -n` on all modified scripts |
| API endpoints | Manual verification with `curl` |
| UI | Manual verification in browser |
| CI/CD | Full CI on GitHub Actions |
| Security fix | Static verification via `grep` |
| Firewall change | Manual verification via `iptables -L` |
| Concurrency change | Manual test: 2 simultaneous operations |
| Memory-limit change | Test all 5 profiles |
| Backup-layer change | Run all 7 steps of `docs/REFERENCE.md` §4.9 |
| WebUI string change | Verify both EN and AR render correctly |
| Install-flow change | See §9.4 |
| Rotation-semantics change | Verify SNAP-*/ROT-* on-device (`docs/REFERENCE.md` §4.6.5) |
| Companion APK change | `make check-app-version` + release dry-run |
| **`lib/*.sh` module change (v1.6.0)** | **`make check-boot-mini` + `bash -n lib/*.sh` + verify `boot-mini.sh` sources it** |
| **Timezone rendering change (v1.6.0)** | **Verify local time on 2+ devices/timezones (see §18.1)** |

### 9.2 Local verification

```bash
# Go build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..

# Shell syntax (includes lib/*.sh)
for f in lib/*.sh *.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# Format
gofmt -l proxy/
shfmt -d -i 4 -ci lib/*.sh *.sh scripts/*.sh

# Full build
make build

# All local validations
make check-all

# v1.5.0-specific
make check-install-app
make check-app-version

# v1.6.0-specific — modular shell verification
make check-boot-mini
# Expected:
#   ✅ present (Layer 1 aggregator: boot-mini.sh)
#   ✅ all 6 lib/*.sh modules present
#   ✅ functions.sh sources boot-mini.sh
#   ✅ functions.sh does not redefine Layer-0 primitives
```

### 9.3 Manual API testing

```bash
# Health endpoints
curl -s http://127.0.0.1:9090/healthz                    # → ok
curl -s http://127.0.0.1:9090/readyz                     # → JSON

# Status (requires auth)
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api?action=status

# Login POST-only
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 + Allow: POST

# Unknown action
curl -i "http://127.0.0.1:9090/api?action=unknown_xyz"   # → 404

# runtime_info backups (7 fields)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'

# v1.6.0 — profile response must include last_update_unix
curl -s http://127.0.0.1:9090/api?action=get_profile | \
    jq '{last_update, last_update_unix}'
# Expected: both fields present; last_update_unix is an integer

# Companion APK route
curl -sI http://127.0.0.1:9090/app-debug.apk | head -3
```

### 9.4 On-device install-flow testing (v1.5.0)

After any change touching `install_app.sh` or the companion-install endpoints:

```bash
# 1. Static checks
for p in 'pm install -r --user 0' \
         'pm install -r --user 0 -i com.android.shell' \
         'pm install-create' \
         'magisk su' \
         'cmd package install'; do
    grep -q "$p" install_app.sh && echo "✅ $p"
done
grep -q 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && echo "✅ 75s deadline"
grep -q '_VERIFIER_ORIG' install_app.sh && echo "✅ Play Protect restore"
! grep -v '^[[:space:]]*#' install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce 0"

# 2. Runtime — full install cycle
TOKEN=$(curl -s -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
curl -s -b /tmp/cookies.txt \
    -X POST http://127.0.0.1:9090/api/install_companion_app \
    -d "token=$TOKEN" | jq

# 3. Cleanup verification
su -c "ls -la /data/local/tmp/dnscrypt-companion.apk 2>&1"
# → No such file or directory

# 4. Play Protect restored
su -c "settings get global package_verifier_enable"
# → 1 (or original value)

# 5. SELinux enforcing
su -c "getenforce"
# → Enforcing
```

**Full procedure**: `docs/REFERENCE.md` §3.13.

### 9.5 On-device modular shell testing (v1.6.0)

After any change touching `lib/*.sh`, `boot-mini.sh`, or `functions.sh`:

```bash
# 1. All 6 lib/ modules present
for M in constants fallbacks process http backup firewall; do
    su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/lib/$M.sh" && \
        echo "  ✅ lib/$M.sh" || echo "  ❌ lib/$M.sh"
done

# 2. Layer chain works end-to-end
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; \
       type init_runtime_paths >/dev/null 2>&1 && \
       echo '✅ Layer chain 0→1→2 OK'"

# 3. No Layer-0 primitive redefined
for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
    su -c "grep -qE '^${fn}[[:space:]]*\(\)' \
        /data/adb/modules/dnscrypt-proxy-webui/functions.sh" && \
        echo "❌ $fn redefined in functions.sh" || \
        echo "✅ $fn lives only in Layer 0"
done

# 4. _MONITORING_UI_PORT single source of truth
su -c "grep -c '_MONITORING_UI_PORT=' \
    /data/adb/modules/dnscrypt-proxy-webui/lib/constants.sh"
# Expected: 1 (the definition)

su -c "grep -c '_MONITORING_UI_PORT=' \
    /data/adb/modules/dnscrypt-proxy-webui/boot-mini.sh"
# Expected: 1 (the fallback — sole documented exception)
```

**Full procedure**: `docs/REFERENCE.md` §1.4 + §5.9.1.

### 9.6 On-device timezone testing (v1.6.0)

After any change touching `last_update_unix` (backend) or
`formatUnixTimestamp` (frontend):

```bash
# 1. Backend returns both fields
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=get_profile" | \
    jq '{last_update, last_update_unix}'

# 2. Convert unix timestamp to local time (should match WebUI display)
su -c "curl -s -u '$CREDS' http://127.0.0.1:9090/api?action=get_profile" | \
    jq -r '.last_update_unix' | xargs -I {} date -d @{}

# 3. Compare with device clock
date

# 4. In-browser verification
#   Open the WebUI → check "Last update:" text
#   Must match `date` output (device timezone)
```

**Test across timezones**: change the device timezone (or use
emulator) to verify `toLocaleString()` respects the new zone.

**Test across languages**: toggle the WebUI language to Arabic
and verify the timestamp still renders correctly (with Arabic
numerals in `ar-EG` locale).

### 9.7 Pre-PR checklist

```bash
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..
for f in lib/*.sh *.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done
gofmt -l proxy/
shfmt -d -i 4 -ci lib/*.sh *.sh scripts/*.sh
make build
make check-all
make check-boot-mini   # v1.6.0
```

**Device smoke test** (before pushing any PR):
- [ ] WebUI opens, login works (POST-only).
- [ ] Toggle / restart service.
- [ ] Apply blocklist.
- [ ] Save custom rules (both allowlist + denylist).
- [ ] SSE progress updates.
- [ ] Dashboard shows JSON metrics.
- [ ] `runtime_info.backups` returns 7 fields.
- [ ] Both English (default) and Arabic (toggle) render.
- [ ] In-place upgrade preserves all 5 files.
- [ ] Recovery mode restores all 5 files.
- [ ] Rotation preserves `.last_stable` + newest install.
- [ ] Install-method modal opens; install locally succeeds (if testing v1.5.0).
- [ ] **`last_update` renders in device local timezone (v1.6.0)**.
- [ ] **All 6 `lib/*.sh` modules load on boot (v1.6.0)**.

---

## 10. Documentation

### 10.1 When to update docs

| Change | Document |
|---|---|
| New API endpoint | `docs/REFERENCE.md` §2 |
| Architectural change | `docs/REFERENCE.md` §1, §3 |
| New feature | `README.md` + `CHANGELOG.md` |
| New config option | `docs/GUIDE.md` §3 |
| Bug fix | `CHANGELOG.md` |
| New common question | `docs/GUIDE.md` §10 |
| Security procedure | `SECURITY.md` |
| Security fix | `SECURITY.md` + `docs/REFERENCE.md` |
| Behavioral change | `docs/REFERENCE.md` §2 + §3 |
| Shell fix | `docs/GUIDE.md` §7 + `docs/CONTRIBUTING.md` §8 |
| CI change | `docs/CONTRIBUTING.md` §7 + `CHANGELOG.md` |
| Concurrency change | `docs/REFERENCE.md` §3.15 |
| Ports change | `docs/REFERENCE.md` §2.1 + §3.9 |
| Memory-limit change | `SECURITY.md` §5.31.1 + `docs/REFERENCE.md` §1.9 |
| Backup-layer change | `docs/REFERENCE.md` §4 + `docs/GUIDE.md` §8 + `SECURITY.md` §5.32 |
| Rotation-semantics change | `docs/REFERENCE.md` §4.6.5 |
| WebUI language change | All three HTML files + `docs/REFERENCE.md` §7.6 |
| Install-flow change | `SECURITY.md` §5.36 + `docs/REFERENCE.md` §3.13 |
| **`lib/*.sh` module change (v1.6.0)** | **`docs/REFERENCE.md` §1.4, §1.6, §1.8** |
| **Timezone change (v1.6.0)** | **`docs/REFERENCE.md` §2.6.2, §3.10** |
| Architectural decision | `docs/adr/` (new ADR) |

### 10.2 Documentation standards

- Clear, concise, with practical examples.
- Valid Markdown; working relative links.
- Updated with the latest code.
- No `TODO` markers; no duplication across files.
- English-only by convention. Translations: `docs/*.<lang>.md`.

### 10.3 The 12-file model

`docs/MAP.md` §1 defines the 12 user-facing documents. Every new file requires a PR that amends `MAP.md` §1 and `MAP.md` §3. **The friction is the point** — it forces a decision.

**v1.6.0 note**: `docs/MAP.md` was itself updated in v1.6.0 to
reflect the 3-layer model and the ~8,606-line `REFERENCE.md`. No
new documentation files were added — the v1.6.0 changes were
accommodated within the existing 13-document model.

---

## 11. Release Process

### 11.1 Overview

Releases are triggered by pushing an **annotated** version tag. Two scripts are available:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `scripts/release.sh` | Stable, Prerelease | `develop` or `release/*` | Any |
| `scripts/release-patch.sh` | Hotfix (PATCH only) | **`main`** | PATCH only (delegates to `release.sh`) |

**Signing status**: artifacts are **NOT signed** (no GPG, no Cosign). The tag is annotated (`git tag -a`), not signed (`git tag -s`). Only the `.sha256` sidecar is attached. See `release.yml` §Non-goals.

### 11.2 The `x-note-v<XYZ>` requirement (v1.5.0)

`release.sh` performs a **hard check**: it verifies that `update.json` contains an entry named `x-note-v<XYZ>` (dots stripped from the version — e.g. `v1.6.0` → `x-note-v160`). If missing → **exit code 3**.

**Manual workflow** — add it **before** running `release.sh`:

```bash
# 1. Add the field to update.json
$EDITOR update.json
# Add: "x-note-v160": "v1.6.0 — <short release note>",

# 2. Verify
jq -e --arg k "x-note-v160" '.[$k]' update.json >/dev/null && echo "✅ ready"

# 3. Run release.sh
./scripts/release.sh v1.6.0
```

**Bypass**: `--skip-xnote` exists but is documented as **not recommended**. End users will see a **stale** release note in their root-manager update UI.

### 11.3 Versioning rules

**SemVer**: `v<MAJOR>.<MINOR>.<PATCH>[-prerelease]`

**versionCode formula**:
```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100
```

Constraints: `MINOR ≤ 99`, `PATCH ≤ 99`. Prerelease suffix is **ignored**.

| Version | versionCode |
|---|:---:|
| `v1.0.0` | `1000000` |
| `v1.5.0` | `1050000` |
| `v1.5.1` | `1050100` |
| `v1.6.0` | `1060000` |
| `v1.6.1` | `1060100` |
| `v2.0.0` | `2000000` |

**Two version schemes exist for a reason**:
- **SemVer** — for GitHub Releases, docs, humans.
- **versionCode** — for Magisk/KernelSU/APatch update detection.

`versionCode` must **strictly increase**. Never reuse.

### 11.4 Files updated per release

| File | Automated? | Notes |
|---|:---:|---|
| `VERSION` | ✅ `release.sh` | Single line |
| `module.prop` | ✅ `release.sh` | `version` + `versionCode` |
| `update.json` | ✅ `release.sh` (requires `jq`) | 6 fields; `x-note-v<XYZ>` must already be present |
| `CHANGELOG.md` | ❌ Manual | Human-edited |
| `proxy/app-apk.version` | ❌ Manual | Only when companion app changes |
| `proxy/dnscrypt-proxy.version` | ❌ Manual | Only when DNS engine changes (v1.6.0 bumped 2.1.18 → 2.1.20) |
| `proxy/go.mod` + `go.sum` | ❌ Manual | Pinned to `filepath-securejoin v0.7.0` (ADR-0002 compliance) |
| **`web/sw.js` `CACHE_VERSION`** | **❌ Manual (v1.6.0)** | **Must be bumped to match module version so PWA clients re-fetch** |

### 11.5 Standard release (recommended)

```bash
# 1. Add x-note-v<XYZ> to update.json (v1.5.0 HARD requirement)
$EDITOR update.json

# 2. Update CHANGELOG.md
$EDITOR CHANGELOG.md
git add CHANGELOG.md update.json
git commit -m "docs(changelog): prepare vX.Y.Z"

# 3. Bump sw.js CACHE_VERSION (v1.6.0 requirement)
$EDITOR web/sw.js
# Change: const CACHE_VERSION = 'vX.Y.Z';
git add web/sw.js
git commit -m "chore(pwa): bump CACHE_VERSION to vX.Y.Z"

# 4. Preview
./scripts/release.sh vX.Y.Z --dry-run

# 5. Execute (interactive)
./scripts/release.sh vX.Y.Z

# 6. Wait ~5 min → Release is live
```

`release.sh` performs:
1. SemVer format validation.
2. `versionCode` computation.
3. Branch + working tree + tag availability check.
4. **`x-note-v<XYZ>` presence check** (v1.5.0 — exit 3 if missing).
5. Update `VERSION` + `module.prop` + `update.json` (with rollback on failure).
6. Create commit + annotated tag.
7. Push to origin (unless `--no-push`).

**Note (v1.6.0)**: `release.sh` does **not** verify
`CACHE_VERSION` — that is a manual step. A future release may add
an automated check.

### 11.6 PATCH release (hotfix)

```bash
git checkout main && git pull origin main
$EDITOR update.json                                    # add x-note-v<XYZ>
$EDITOR web/sw.js                                      # bump CACHE_VERSION
./scripts/release-patch.sh v1.6.1
make sync                                              # back-merge main → develop
```

**3 safety rules enforced**:
1. Branch **must** be `main`.
2. `MAJOR` and `MINOR` must **not** change.
3. `PATCH` must be exactly `current + 1`.

### 11.7 Script options

| Option | Effect |
|---|---|
| `--dry-run` | Show what would happen, change nothing |
| `--no-push` | Create commit + tag locally, skip push |
| `--yes` / `-y` | Skip confirmation prompts |
| `--skip-xnote` | Bypass `x-note-v<XYZ>` check (not recommended) |
| `--help` / `-h` | Show usage |

### 11.8 Exit codes (both scripts)

| Code | Meaning |
|:---:|---|
| `0` | Success |
| `1` | Invalid arguments or missing tools |
| `2` | Repository state invalid (dirty, wrong branch, tag exists) |
| `3` | Version files inconsistent OR missing `x-note-v<XYZ>` |
| `4` | User aborted |

### 11.9 GitHub Actions pipeline (17 steps)

Triggered on `vX.Y.Z` tag push. Full step table in `release.yml` header. Key v1.5.0+ changes:
- **Step 6 "Verify metadata consistency"** — enforces `VERSION == module.prop.version == update.json.version`, `releaseDate == x-note-last-updated`, and the `versionCode` formula. Aborts **before** packaging.
- **Step 11 "Stage APK + `.sha256`"** — copies both files to `web/app-debug.apk` + `.sha256`. Sidecar content must reference `app-debug.apk` (final staged name).
- **Step 12 packaging** — ZIP now also bundles `install_app.sh`, `boot-mini.sh`, `go.sum`, **and all `lib/*.sh` modules (v1.6.0)**.
- **Step 17 "Sync `main → develop`"** — `continue-on-error: true`; failure never fails the release.

**Total time**: ~4-6 minutes.

### 11.10 Manual fallback

If `release.sh` is unavailable:

```bash
echo "vX.Y.Z" > VERSION
sed -i 's/^version=.*/version=vX.Y.Z/' module.prop
sed -i 's/^versionCode=.*/versionCode=NNNNNNN/' module.prop
$EDITOR update.json  # must include x-note-v<XYZ> AND releaseDate == x-note-last-updated
$EDITOR CHANGELOG.md
$EDITOR web/sw.js    # bump CACHE_VERSION
git add -A && git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin develop && git push origin vX.Y.Z
```

**Manual `update.json` checklist**:
- [ ] `version` = `vX.Y.Z`
- [ ] `versionCode` = computed
- [ ] `versionName` = `vX.Y.Z (Global Edition)`
- [ ] `releaseDate` = UTC today
- [ ] `zipUrl` = `.../download/vX.Y.Z/dnscrypt-webui-X.Y.Z-module.zip`
- [ ] `x-note-last-updated` = **same** as `releaseDate`
- [ ] **`x-note-v<XYZ>`** = the release note

### 11.11 Rollback

| Scenario | Action |
|---|---|
| Wrong versionCode | Delete tag + fix + retry |
| Broken binary | Delete tag + fix + retry |
| GitHub Actions failure | Re-run workflow (`gh run rerun <id>`) |
| Missing companion APK | Re-run workflow (fetch is best-effort) |
| Missing `install_app.sh` / `boot-mini.sh` / `lib/*.sh` in ZIP | Re-run workflow (packaging bug) |
| Bad `x-note-v<XYZ>` (only) | **No re-tag** — follow-up commit on `main`; root manager reads `update.json` from `main` |

**Delete a tag**:

```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
gh release delete vX.Y.Z --yes
```

### 11.12 Full details

The complete step-by-step release process (16 sections, 30-point device verification checklist, 42-scenario upgrade matrix) lives in `release.yml`'s header and `docs/REFERENCE.md` §3.13. This section covers the **workflow** you need as a contributor; the exhaustive operator reference is in the workflow file itself.

---

## 12. Branch Protection

### 12.1 `main` (strict)

| Setting | Value |
|---|---|
| Require a pull request before merging | Yes |
| Require approvals | Yes, **1** |
| Dismiss stale PR approvals | Yes |
| Require review from Code Owners | Yes (`.github/CODEOWNERS`) |
| Require status checks to pass | Yes |
| Require branches up to date | Yes |
| Require conversation resolution | Yes |
| Require linear history | Yes |
| Do not allow bypassing | Yes |
| Restrict who can push | Yes (maintainer + `github-actions[bot]`) |
| Allow force pushes | **No** |
| Allow deletions | **No** |

**Required status checks**:
- `CI / Build arm64`, `arm`, `amd64`, `386`
- `CI / Backup Smoke Test`
- `CodeQL / Analyze Go`

**`github-actions[bot]` must be in the allowlist** so the auto-sync (ADR-0001) can push to `develop`.

### 12.2 `develop` (relaxed)

| Setting | Value |
|---|---|
| Require a pull request before merging | Recommended, optional |
| Require status checks to pass | Yes (same as `main`) |
| Require branches up to date | Yes |
| Require linear history | Yes |
| Allow force pushes | **No** (even for owner) |
| Allow deletions | No |

Sync `develop` with `main` after a release via a **regular merge** (see §13.4) — not `--force`.

### 12.3 Tags ruleset — **the bypass trap**

> **This was discovered during the v1.1.0 release cycle (PR #6).**

GitHub's tag protection moved from the deprecated **Classic Branch Protection** page to **Rulesets** (`Settings → Rules → Rulesets`).

**Recommended ruleset**:

| Setting | Value |
|---|---|
| **Name** | `Protect release tags` |
| **Target tags** | `v*` |
| **Restrict creations** | Yes |
| **Restrict updates** | Yes |
| **Restrict deletions** | Yes |
| **Block force pushes** | Yes |
| **Bypass list** | **`Repository admin`** — **mandatory** |

> ⚠️ **Critical**: If `Restrict creations` is enabled, the `Repository admin` role **MUST** be in the Bypass list. Without it, the rule blocks **all** tag creation — including by the repository owner.
>
> **Symptom** when the bypass is missing:
>
> ```text
> remote: error: GH013: Repository rule violations found
> remote: - Cannot create ref due to creations being restricted.
> ```
>
> **Fix**: add `Repository admin` to the Bypass list in the Ruleset.

**Alternative (simpler, less strict)**: disable `Restrict creations`, keep only `Restrict updates` + `Restrict deletions`. Any user with push access can create tags; tags remain immutable once created.

### 12.4 Repository settings

`Settings → General`:

| Setting | Value |
|---|---|
| Allow merge commits | No |
| Allow squash merging | Yes |
| Allow rebase merging | No |
| Automatically delete head branches | Yes |
| Default branch | `main` |

**Full rationale**: `docs/adr/0001-release-workflow.md`.

---

## 13. Hotfix Flow

### 13.1 When to use

Only when a **critical** bug exists in a **released** version:
- Login bypass on `/api/auth/login`.
- Crash loop from a specific config.
- Data corruption in `blocklist.txt`.
- Rate limit bypass on `/readyz`.

The first realistic hotfix scenario from v1.6.0 would be `v1.6.0 → v1.6.1`.

### 13.2 Steps

```bash
git checkout main && git pull origin main
git checkout -b hotfix/v1.6.1-critical
# ... minimal fix ...
git commit -m "fix(critical): patch login bypass"
git push -u origin hotfix/v1.6.1-critical
# → Open PR against main using ?template=release.md
# → Fast-track review
# → Squash merge
./scripts/release-patch.sh v1.6.1
make sync
```

**PR template**: `release/*` and `hotfix/*` PRs both target `main` and use the **separate** release template at `.github/PULL_REQUEST_TEMPLATE/release.md`, opened via the query string `?template=release.md`. See §7.5 for the full rationale.

### 13.3 PATCH versioning

| Released | Hotfix | New Version |
|---|---|---|
| `v1.4.0` | Fix critical bug | `v1.4.1` |
| `v1.5.0` | Fix critical bug | `v1.5.1` |
| `v1.6.0` | Fix critical bug | `v1.6.1` |
| `v1.6.1` | Fix critical bug | `v1.6.2` |

Hotfix versions are **never** used for features.

### 13.4 Back-merge requirement

**Critical**: after a hotfix lands on `main`, `develop` must be synced:

```bash
make sync
# or manually:
git checkout develop && git pull origin develop
git merge origin/main --no-edit
git push origin develop
```

**Why**: without it, `develop` will be missing the hotfix, and the next `release/*` PR will reintroduce the bug.

`release.yml` performs the sync **automatically** for regular `release/*` pushes. For `hotfix/*` releases, GitHub Actions cannot distinguish a hotfix tag from a regular tag — the sync is **manual**.

### 13.5 Hotfix touching v1.6.0 subsystems

Additional considerations per subsystem:

| Subsystem | Must preserve |
|---|---|
| Backup layer | Do **not** edit `txn-*` / `orphan-txn-*` manually. Preserve `.last_stable` pointer. Verify recovery mode. Keep SNAP-*/ROT-* invariants. Keep the `apk/` mirror's two independent protections. |
| Companion install flow | Preserve 5-level cascade order, 75-second deadline, three-way trap split (130/143), SELinux staging path, `$_VERIFIER_ORIG` restore value, localhost gate on all 3 surfaces. |
| Layered Bootstrap (v1.6.0) | Preserve `lib/*.sh` module boundaries, `boot-mini.sh` aggregator-only role, `functions.sh` sourcing `boot-mini.sh` without redefinition, `_MONITORING_UI_PORT` in `lib/constants.sh`. |
| Timezone fix (v1.6.0) | Preserve `lastUpdateUnixCache`, `last_update_unix` field in `get_profile`, `formatUnixTimestamp()` helper in `index.html`, `toLocaleString()` locale argument. |
| PWA cache (v1.6.0) | Preserve `CACHE_VERSION = 'v1.6.x'` in `sw.js`. Hotfix releases must bump it. |

`ci.yml` Steps 8, 9, 10 catch regressions automatically. `make check-install-app` and `make check-boot-mini` run the same checks locally.

---

## 14. Recognition

We recognize contributions through badges maintained in `docs/CONTRIBUTING.md` §14.1. All badges are updated **manually** at each major release, and immediately when a specific acceptance criterion is met.

### 14.1 The 21 badges

| Badge | Condition |
|---|---|
| 🏆 Founder | Created the project |
| 🥇 Top Contributor | 5+ merged PRs (20+ = co-maintainer invite) |
| 🛡️ Security Researcher | Accepted responsible disclosure |
| 📖 Documentation | 5+ documentation PRs |
| 🌐 Translator | Full doc translation (`docs/*.<lang>.md`) OR significant `translations.ar` contribution |
| 🧪 Testing Heroes | Tested on 3+ devices with detailed reports |
| 💎 Compatibility Champion | Tested on 3+ devices with logs + behavior |
| 🎨 UI/UX | Design / accessibility improvements |
| 🔧 PWA Champion | Tested the PWA install across 3+ browsers |
| 🎯 Rotation Guardian | Verified SNAP-*/ROT-* on 3+ devices/root solutions |
| 📱 Companion App Champion | Tested the companion APK on 3+ devices/ROMs |
| 🧪 Install Test Engineer (v1.5.0) | Tested the 5-level install cascade on 3+ ROMs; reported strategy used per ROM |
| 🔍 Auditor | One accepted Audit Correction |
| 🔧 Platform Fixer | Fixed a platform-specific issue |
| 📐 Metrics Wizard | Improved the metrics/Dashboard system |
| ⚡ Concurrency Guardian | Fixed a real race condition (`rebuildMu` or `backupMu`) |
| 🔌 Port Architect | Fixed dynamic-ports issue |
| 🧠 Memory Architect | Tested MEM-1 across 3+ RAM tiers |
| 🛡️ Data Guardian | Tested the 10 defensive layers on 3+ devices / root solutions |
| **🏗️ Modular Architect (v1.6.0)** | **Contributed a `lib/*.sh` module or improved the Layered Bootstrap** |
| **🕐 Timezone Validator (v1.6.0)** | **Verified local timezone rendering on 2+ devices/timezones** |

### 14.2 The v1.6.0 badges

#### 🏗️ Modular Architect (v1.6.0)

Granted for contributing a new `lib/*.sh` module **or** improving
the Layered Bootstrap (e.g., refactoring a `functions.sh` helper
into a dedicated `lib/` module).

**Acceptance criteria**:
- ✅ Added a new `lib/*.sh` module with a single responsibility.
- ✅ Updated `boot-mini.sh` to source it (or confirmed it is
  already sourced).
- ✅ Updated `ci.yml` Step 9 (module presence check).
- ✅ Updated `docs/REFERENCE.md` §1.4, §1.6, §1.8.
- ✅ PR passed `make check-boot-mini`.

#### 🕐 Timezone Validator (v1.6.0)

Granted for verifying the WebUI "Last update" rendering matches
the device clock across 2+ timezones.

**Acceptance criteria**:
- ✅ Verified the WebUI "Last update" text matches `date` output.
- ✅ Tested on 2+ timezones (e.g., UTC, UTC+3, UTC-5, UTC+9).
- ✅ Tested with the Arabic toggle enabled (verify `ar-EG`
  locale).
- ✅ Reported device timezone + `date` output + WebUI screenshot.
- ✅ Reported the `last_update_unix` value from
  `/api?action=get_profile` and confirmed it matches the expected
  epoch time.

### 14.3 The v1.5.0 badge (retained)

#### 🧪 Install Test Engineer (v1.5.0)

Granted for verifying the 5-level `pm install` cascade on **3+
devices or 3+ ROMs**.

**Acceptance criteria**:
- ✅ Installed the companion app via the WebUI install-method modal on 3+ ROMs.
- ✅ Reported which cascade level (1-5) succeeded on each ROM.
- ✅ Verified the staged APK was removed from `/data/local/tmp/dnscrypt-companion.apk` after install.
- ✅ Verified `settings get global package_verifier_enable` returned the original value.
- ✅ Verified `getenforce` returned `Enforcing`.
- ✅ Reported `dnscrypt_main.log` excerpts.
- ✅ If a cascade level failed, documented the exact `INSTALL_FAILED_*` error string.

**Example report**:

```text
Devices tested:
  1. Pixel 6a     / Android 14 / Magisk 27.0    → strategy 1 ✅
  2. Xiaomi 13    / MIUI 14    / KernelSU 0.9.5 → strategy 2 ✅
  3. OnePlus 11   / OxygenOS 13 / APatch        → strategy 1 ✅

Cleanup verified:
  - /data/local/tmp/dnscrypt-companion.apk removed ✅
  - package_verifier_enable restored to 1 ✅
  - getenforce = Enforcing ✅
```

### 14.4 Audit Corrections Registry

The full registry (33 entries from v1.0.0) lives in `SECURITY.md` §15. **No new corrections in v1.1.0 through v1.6.0** — those releases added runtime improvements, correctness fixes, feature additions, and architectural modularization, not audit-correction entries.

**Next expected**: #34 (future release).

### 14.5 Full badge list

See §14.1 for the complete 21-badge table (18 from v1.0.0–v1.4.0, plus the v1.5.0 badge in §14.3, plus the two v1.6.0 badges in §14.2). Detailed acceptance criteria per badge and current holders are maintained in this section as contributions are verified.

---

## 15. Where to Ask for Help

| Channel | Purpose |
|---|---|
| GitHub Discussions | General questions |
| GitHub Issues | Bug reports / feature requests |
| Private Vulnerability Reporting | Security disclosure (`SECURITY.md` §1) |
| `@gasciljh` | Direct contact |

**Before asking**:
- Read `README.md`, `docs/GUIDE.md`, `docs/REFERENCE.md`.
- Search existing Issues.
- Try the latest version.

**A good question includes**:
- Module version (`v1.6.0`).
- Android version, device, ROM, kernel, architecture.
- Root solution + version.
- Clear reproduction steps.
- `status.sh --diagnose` output.
- `status.sh --json` output.
- `runtime_info` output (7-field `backups` if relevant).
- `dnscrypt_main.log` tail (~200 lines).
- If the issue is about language: browser version + screenshots in both EN and AR.
- If the issue is about install: which cascade level succeeded/failed + the `INSTALL_FAILED_*` error.
- **If the issue is about timezone (v1.6.0)**: device timezone, `date` output, screenshot of WebUI "Last update", and `/api?action=get_profile` output.
- **If the issue is about `lib/` modules (v1.6.0)**: `ls $MODDIR/lib/` output + `make check-boot-mini` result.
- Steps already attempted.

---

## 16. Quick Reference

### 16.1 Cheat sheet

```bash
# Feature
git checkout develop && git pull
git checkout -b feature/my-feature
# ... work ...
make build && make check-all && make check-boot-mini
git push -u origin feature/my-feature
# → Open PR against develop

# Release
git checkout develop && git pull
$EDITOR update.json && $EDITOR CHANGELOG.md      # add x-note-v<XYZ>
$EDITOR web/sw.js                                # bump CACHE_VERSION
git commit -m "docs(changelog): prepare vX.Y.Z"
./scripts/release.sh vX.Y.Z

# Hotfix
git checkout main && git pull
git checkout -b hotfix/v1.6.1-critical
# ... fix ...
git push -u origin hotfix/v1.6.1-critical
# → Open PR against main using ?template=release.md
git checkout main && ./scripts/release-patch.sh v1.6.1
make sync
```

### 16.2 Branch comparison

| Branch | From | To | Lifetime | Direct push |
|---|---|---|---|---|
| `main` | — | — | Permanent | No |
| `develop` | `main` (init) | `release/*` | Permanent | Maintainer |
| `feature/*` | `develop` | `develop` | Days-weeks | Yes |
| `fix/*` | `develop` | `develop` | Hours-days | Yes |
| `docs/*` | `develop` | `develop` | Hours | Yes |
| `release/*` | `develop` | `main` | Days | Version only |
| `hotfix/*` | `main` | `main` + `develop` | Hours | Yes |

### 16.3 Common mistakes

| Don't | Do |
|---|---|
| Push directly to `main` | Use `release/*` + PR |
| Branch from `main` for features | Branch from `develop` |
| Mix features in one branch | One branch = one purpose |
| Skip the CHANGELOG | Update `CHANGELOG.md` |
| Force-push a shared branch | Only force-push your own `feature/*` |
| Merge `develop` → `main` directly | Use `release/*` or `release.sh` |
| Forget to back-merge hotfixes | Run `make sync` after PATCH releases |
| Use merge commits | Squash merge only |
| Enable `Restrict creations` without a Bypass entry | Add `Repository admin` to the Bypass list (§12.3) |
| Edit a `txn-*` directory manually | Let `main.go` + `service.sh` handle cleanup |
| Add an English string without the Arabic entry | Add both `translations.en` and `translations.ar` |
| Prune the `.last_stable` target manually | Let `rotate_backups` handle rotation (ROT-PROTECT) |
| Create a snapshot without `.manifest.json` | Every snapshot must have a manifest |
| Delete the `apk/` mirror to "clean up" | Leave it alone — never rotated, survives uninstall |
| Add a 6th cascade level without an ADR | Preserve the 5-level order (§17.1) |
| Redefine a Layer-0 primitive in `functions.sh` | Layer 0 lives in `lib/*.sh` (v1.6.0) |
| Add an external Go dependency without an ADR | ADR-0002 policy: one ADR per new dependency |
| Open a release PR without `?template=release.md` | Use the query string (§7.5) |
| Hardcode timezone in `toLocaleString()` | Use `currentLang === 'ar' ? 'ar-EG' : 'en-US'` (v1.6.0) |
| Forget to bump `CACHE_VERSION` after changing an asset | Bump it every release (v1.6.0) |

### 16.4 Common commands

```bash
make version            # → v1.6.0
make build              # build 4 architectures
make package            # build + package Magisk ZIP
make check-all          # all local validations (includes 6 lib/*.sh)
make check-backup       # validate 16 shell scripts (10 root + 6 lib/)
make check-install-app  # install_app.sh validation (v1.5.0)
make check-boot-mini    # Layer 0/1/2 split validation (v1.6.0)
make check-app-version  # companion APK version validation
make fetch-apk          # fetch companion APK to dist/
make release VERSION=vX.Y.Z          # standard release
make release-patch VERSION=vX.Y.Z    # PATCH release
make sync               # back-merge main → develop
```

---

## 17. v1.5.0-Specific Notes

### 17.1 Companion install cascade

The WebUI install button opens an **install-method modal (IDX-24)** offering three actions:

| Category | Action | Implementation |
|---|---|---|
| **Local** | Install locally | `POST /api/install_companion_app` → `install_app.sh` (5-level cascade) |
| **GitHub** | Open GitHub page | `window.open(APP_GITHUB_PAGE_URL)` |
| **GitHub** | Direct download | `window.open(getCompanionApkUrl())` |

**The 5-level cascade** (first success wins):

| Level | Command |
|:-:|---|
| 1 | `pm install -r --user 0 <apk>` |
| 2 | `pm install -r --user 0 -i com.android.shell <apk>` |
| 3 | Session-based (`install-create` + `install-write` + `install-commit`) |
| 4 | `magisk su -c "pm install -r <apk>"` (Magisk-only; skipped on KernelSU/APatch) |
| 5 | `cmd package install -r <apk>` (Android 8.0+ only) |

**Bounded by**:
- `CASCADE_DEADLINE_SECONDS = 75` — strictly less than `main.go`'s 90-second `INSTALL_TIMEOUT`.
- Three-way trap split (`EXIT` / `INT` exit 130 / `TERM` exit 143) with `_CLEANED_UP` re-entry guard.
- SELinux staging to `/data/local/tmp/dnscrypt-companion.apk` (never `setenforce 0`).
- Play Protect trap restoring `$_VERIFIER_ORIG`.

**Full security model**: `SECURITY.md` §5.36. **Full cascade reference**: `docs/REFERENCE.md` §3.13.

### 17.2 Layered Bootstrap (ADR-0003) — v1.5.0 model

> **v1.6.0 note**: The v1.5.0 two-layer model was **extended** to
> three layers in v1.6.0. See §18.2 for the current model. This
> section is preserved for historical context.

The v1.5.0 shell library was split into two files:

| Layer | File | Contents |
|---|---|---|
| **Layer 0** | `boot-mini.sh` | 5 primitives (`log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`) + `_MONITORING_UI_PORT` |
| **Layer 1** | `functions.sh` | Every other shell helper. Sources Layer 0 at load time. |

**Single legitimate fallback**: `boot-mini.sh §[4]` sets `_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because `lib/constants.sh` may fail to source during a partial extraction. `customize.sh` inherits the value by sourcing `boot-mini.sh`.

**CI enforcement**: `ci.yml` Step 9. **Local check**: `make check-boot-mini`.

**Full rationale**: `docs/adr/0003-layered-bootstrap.md`.

### 17.3 External Go dependency (ADR-0002)

The project has **exactly one** external Go dependency:

```text
github.com/cyphar/filepath-securejoin v0.7.0
```

**Scope**: exactly one call site — `removeModule` in `proxy/main.go`, closing two CodeQL `go/path-injection` alerts.

**Pinned in**: `proxy/go.mod` + `proxy/go.sum`.

**Compliance rule**: any future external dependency requires its own ADR.

**Full policy**: `docs/adr/0002-external-dependency.md`.

### 17.4 ADR renumbering (applied in this consolidated file)

The pre-consolidation tree had **8 ADRs**. They are consolidated into **3**:

| Old ADR(s) | New ADR |
|---|---|
| 0001 (two-branch-model), 0002 (automated-releases), 0003 (post-release-sync), 0004 (unified-pr-template — superseded), 0005 (release-specific-pr-template), 0006 (rename-hotfix-to-release-patch) | **`ADR-0001` — Release Workflow** |
| 0007 (external-dependency-securejoin) | **`ADR-0002` — External Dependency** |
| 0008 (layered-bootstrap) | **`ADR-0003` — Layered Bootstrap** |

**All cross-references in this file use the new 3-ADR numbering.**

### 17.5 New backend endpoints

Four companion-install endpoints added in v1.5.0:

| Endpoint | Purpose | Auth |
|---|---|---|
| `POST /api/install_companion_app` | Root install via cascade | Session + one-shot CSRF token (60 s TTL) + localhost |
| `POST /api/uninstall_companion_app` | Uninstall (not exposed in UI yet) | Session + localhost |
| `GET /api?action=install_token` | Issue one-shot CSRF token | Session + localhost |
| `GET /api?action=companion_app_state` | Cached install state (30 s TTL) | Session |

**All four are localhost-only** via `isLocalRequest()` on all three surfaces. **Full reference**: `docs/REFERENCE.md` §2.7.14.

### 17.6 Notable v1.5.0 fixes

The v1.5.0 release includes 9 backend code-review corrections + 12 frontend state fixes + 4 post-build bug fixes:

| ID | Area | Description |
|---|---|---|
| `BUG-1` | Frontend | `installModalActive` stuck flag after session expiry |
| `BUG-2` | Frontend | `installTokenError` shown for 401 from install endpoint |
| `BUG-3` | Frontend | `companionInstallInFlight` stuck flag after modal replacement |
| `BUG-4` | Frontend | `isInstallFamilyUrl` incorrectly matched `install_token` |
| `M-1` | Backend | `isLocalRequest` uses `net.IP.IsLoopback()` (IPv4-mapped IPv6) |
| `CSH-22` | Shell | `install_app.sh` was packaged but not extracted |
| `MAIN-REENT-01` | Backend | Logger three-layer split (no reentrancy deadlock) |
| `MAIN-PORTCACHE-01` | Backend | 30 s TTL port cache |
| `MAIN-DEADLOCALHOST-01` | Backend | Removed dead branch |
| `MAIN-APPENDHASH-01` | Backend | `appendDenylist` hash source aligned |
| `L-1` | Shell | `_VERIFIER_ORIG` comment swap (code was correct) |
| `L-5` | Frontend | `applyProfile` warns on unsaved changes |
| `V15-CODE-01..04` | Backend | Companion state read, shell resolution, install attempts GC, cache invalidation |

**Full changelog**: `CHANGELOG.md` §[v1.5.0].

---

## 18. v1.6.0-Specific Notes

### 18.1 Local timezone rendering

The WebUI previously displayed "Last Update" as raw UTC
(`2026-11-12 04:03:46`), confusing users in non-UTC timezones.
v1.6.0 fixes this by having the backend emit `last_update_unix`
(integer epoch seconds) and the frontend render via
`toLocaleString()`.

**Backend changes** (`main.go`):
- `buildProfileResponse()` returns both `last_update` (RFC3339 UTC,
  fallback) and `last_update_unix` (integer, preferred).
- `lastUpdateUnixCache` field added to the global cache struct.
- The 5-second `LAST_UPDATE_CACHE_TTL` is preserved — no disk I/O
  regression.

**Frontend changes** (`index.html`):
- `formatUnixTimestamp(unix)` helper added.
- `renderProfileData()` prefers `last_update_unix`, falls back to
  `last_update` when absent.

**Contract invariant**: both fields are derived from the same
`modTime` — they cannot disagree.

**Full flow diagram**: `docs/REFERENCE.md` §3.10.

### 18.2 Modular shell architecture (`lib/`)

The v1.5.0 two-file shell library (`boot-mini.sh` +
`functions.sh`) was **extended** to a three-layer model:

| Layer | Files | Role |
|---|---|---|
| **Layer 0** | `lib/constants.sh`, `lib/fallbacks.sh`, `lib/process.sh`, `lib/http.sh`, `lib/backup.sh`, `lib/firewall.sh` | Single-purpose modules, zero dependencies |
| **Layer 1** | `boot-mini.sh` | Aggregator — sources `lib/*.sh`, sets up PATH + log rotation |
| **Layer 2** | `functions.sh` | Orchestrator — sources `boot-mini.sh`, exposes runtime helpers |

**Why**: before v1.6.0, the 5 primitives were duplicated across
7+ shell scripts. A single change required a manual sweep of every
copy. The `lib/` extraction separates "constants" from "primitives"
from "orchestration" — matching the Unix philosophy of small,
single-purpose modules.

**CI enforcement** (`ci.yml` Step 9):
- All 6 `lib/*.sh` modules present.
- `functions.sh` sources `boot-mini.sh`.
- `functions.sh` does not redefine any Layer-0 primitive.
- `_MONITORING_UI_PORT` remains the single source of truth in
  `lib/constants.sh` (except `boot-mini.sh §[4]`'s documented
  fallback).

**Local check**: `make check-boot-mini`.

**Full rationale**: `docs/adr/0003-layered-bootstrap.md`
(extended in v1.6.0 to document the 3-layer model).

### 18.3 PWA cache version bump

`web/sw.js` `CACHE_VERSION` was bumped from `v1.5.0` to `v1.6.0`.
This forces clients to:
1. Discard the v1.5.0 static + runtime caches.
2. Re-fetch the v1.6.0 assets (including the timezone-fixed
   `index.html` and `dashboard.html`).

**Consequence**: existing PWA installs will see the "Update
available" banner on their next visit. Without this bump, the
timezone fix would not reach existing clients.

**When to bump**: every release that changes any file in
`PRECACHE_ASSETS` (11 files) or any HTML file.

**Automation**: manual step (documented in §11.5). A future
release may add an automated check.

### 18.4 DNS version bump

`proxy/dnscrypt-proxy.version` was bumped from `2.1.18` to
`2.1.20`. This is **independent** of the module version —
see `docs/REFERENCE.md` §6.10.3 for the three-version
distinction.

**Cache impact**: the DNS-binaries GitHub Actions cache uses
`dns_version` as part of its key. v1.6.0 will trigger a fresh
fetch; subsequent v1.6.x builds reuse the new cache.

**Full DNS-binaries pipeline**: `docs/REFERENCE.md` §6.

### 18.5 Badges added in v1.6.0

Two badges added to §14.1:

| Badge | Condition |
|---|---|
| 🏗️ **Modular Architect** | Contributed a `lib/*.sh` module or improved the Layered Bootstrap |
| 🕐 **Timezone Validator** | Verified local timezone rendering on 2+ devices/timezones |

**Acceptance criteria**: see §14.2.

### 18.6 Verification changes for reviewers

Reviewers of v1.6.0 PRs should verify:
- **`lib/*.sh` changes**: single responsibility, no cross-module
  dependency, `boot-mini.sh` still sources it, `ci.yml` Step 9
  passes.
- **`main.go` changes touching `last_update`**: both
  `last_update` and `last_update_unix` still emitted, both
  derived from the same `modTime`.
- **`index.html` changes**: `formatUnixTimestamp()` used for any
  timestamp rendering, `toLocaleString()` locale follows
  `currentLang`.
- **`sw.js` changes**: `CACHE_VERSION` bumped if any precached
  asset changed.
- **`Makefile` changes**: `check-backup` still includes all 6
  `lib/*.sh` modules.

---

## Footer

**Last updated**: 2026-11-13
**Version**: v1.6.0 (Global Edition)
**Author**: gasciljh

This file consolidates 5 pre-consolidation documents into one,
and was extended in v1.6.0 with §18 for the modular shell
architecture (`lib/`) and the local-timezone fix. See
`docs/MAP.md` for the full 15-file documentation model and
`CHANGELOG.md` §[v1.5.0] and §[v1.6.0] for the consolidation
scope.

**References**:
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Effective Go](https://go.dev/doc/effective_go)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitHub Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)
- [MDN — Date.prototype.toLocaleString()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toLocaleString)