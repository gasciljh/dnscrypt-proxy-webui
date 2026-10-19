# Contributing to DNSCrypt Smart Filter

Guidance for contributing effectively to the project.

**Version**: v1.5.0 (Global Edition)
**Last updated**: 2026-10-19
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

This file consolidates the former `CONTRIBUTING.md`,
`DEVELOPMENT.md`, `BRANCHING.md`, `RELEASE_PROCESS.md`, and
`HALL_OF_FAME.md` into one guide. It replaces all five as of
v1.5.0.

**Companion documents**:

| Topic | File |
|---|---|
| End-user install, upgrade, troubleshoot | `docs/GUIDE.md` |
| Technical reference (architecture, API, backup) | `docs/REFERENCE.md` |
| Security model + audit registry | `SECURITY.md` |
| Documentation map (structure, ceilings) | `docs/MAP.md` |
| Version history (v1.0.0 → v1.5.0) | `CHANGELOG.md` |
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
| **jq** | 1.6+ | ✅ (required by `release.sh` for `x-note-v<XYZ>` check since v1.5.0) |
| **curl** | — | ✅ |
| **zip / unzip** | — | ✅ |

**ShellCheck note**: removed from CI on 2026-09-30. It runs
locally via `make check-backup` / `make check-all`. CI enforces
shell safety through `bash -n` and the integration checks (Step 8
`install_app.sh`, Step 9 Layer-0/1, Step 10 port sync).

### 3.2 Quick install

**Ubuntu / Debian**:

```bash
sudo apt install -y git make curl jq golang-1.22 shellcheck \
                    python3 zip unzip
curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64" \
    -o /tmp/shfmt && sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | \
    sudo sh -s -- -b /usr/local/bin v2.5.0
```

**macOS**:

```bash
brew install go make jq shellcheck shfmt golangci-lint
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
# Expected: v1.5.0
```

---

## 4. Project Structure

### 4.1 Layout (97 tracked files + 0-11 build artifacts)

```text
dnscrypt-proxy-webui/
├── Root files (15)           VERSION, module.prop, update.json,
│                             README.md, CHANGELOG.md, SECURITY.md,
│                             CODE_OF_CONDUCT.md, LICENSE, Makefile,
│                             .editorconfig, .gitattributes, .gitignore,
│                             .pre-commit-config.yaml, .secrets.baseline,
│                             .shellcheckrc
├── .github/ (13 tracked)     CODEOWNERS, dependabot.yml,
│                             PULL_REQUEST_TEMPLATE.md,
│                             PULL_REQUEST_TEMPLATE/release.md,
│                             ISSUE_TEMPLATE/{bug_report,config,feature_request}.yml,
│                             codeql/codeql-config.yml,
│                             workflows/{ci,codeql,release,upgrade-test}.yml
├── scripts/ (6)              fetch_dns_binaries.sh, fetch_app_apk.sh,
│                             generate-icons.sh, package_module.sh,
│                             release.sh, release-patch.sh
├── proxy/ (18)               main.go, go.mod, go.sum, build.sh,
│                             boot-mini.sh (Layer 0), functions.sh (Layer 1),
│                             install_app.sh, customize.sh, service.sh,
│                             watchdog.sh, status.sh, action.sh,
│                             post-fs-data.sh, uninstall.sh,
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
| Fresh clone | 97 | 0 | 97 | 15 |
| After package | 97 | 4 | 101 | 17 |
| After full build | 97 | 11 | 108 | 18 |

### 4.2 Key files

| File | Size | Role |
|---|---:|---|
| `proxy/main.go` | ~5,731 lines | HTTP server + 4 companion-install endpoints |
| `proxy/install_app.sh` | ~1,101 lines | 5-level `pm install` cascade (v1.5.0) |
| `proxy/boot-mini.sh` | ~291 lines | Layer 0 primitives (v1.5.0) |
| `proxy/functions.sh` | ~2,059 lines | Layer 1 library (sources Layer 0) |
| `proxy/customize.sh` | ~2,718 lines | Installer (10 defensive layers + APK mirror) |
| `proxy/go.mod` + `go.sum` | ~1 KB | One external dep (`filepath-securejoin`) |
| `web/index.html` | ~150 KB | Main UI (bilingual EN/AR + install modal) |

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

**Current state**: `main` = `v1.5.0` (released 2026-10-13). `develop` in sync via auto-sync (ADR-0001).

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

**Note**: WebUI string changes and companion APK changes are
**not** separate branch types — they use `feature/*` or `fix/*`.

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
git checkout -b hotfix/v1.5.1-critical
# ... fix ...
git push -u origin hotfix/v1.5.1-critical
# → Open PR against main using ?template=release.md (fast-track)
# → After merge: ./scripts/release-patch.sh v1.5.1
# → Back-merge: make sync
```

### 5.7 The full release chain

| From | To | Type |
|---|---|---|
| `v1.0.0` | `v1.1.0` | MINOR |
| `v1.1.0` | `v1.2.0` | MINOR |
| `v1.2.0` | `v1.3.0` | MINOR |
| `v1.3.0` | `v1.4.0` | MINOR |
| `v1.4.0` | **`v1.5.0`** | **MINOR (current)** |
| `v1.5.0` | `v1.5.1` | PATCH (if needed) |
| `v1.5.1` | `v1.6.0` | MINOR (planned) |

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

**Current ADRs** — 3 (see `docs/adr/README.md`):

| ADR | Decision |
|---|---|
| `ADR-0001` | Release workflow (two-branch model, automated releases, post-release sync, PR templates, release-patch) |
| `ADR-0002` | External dependency — `filepath-securejoin v0.7.0` |
| `ADR-0003` | Layered Bootstrap (Layer 0 / Layer 1 split) |

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
refactor(shell): split primitives into Layer 0 (boot-mini.sh)

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
| `backup` | Data-preservation layers, rotation semantics |
| `app` | Companion APK integration |
| `webui` | `web/index.html` |
| `dashboard` | `web/dashboard.html` |
| `pwa` | `manifest.json`, `sw.js`, `offline.html` |
| `api` | HTTP endpoints |
| `auth` | Authentication / sessions |
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
- **Step 9** — Layer 0 / Layer 1 split integrity.
- **Step 10** — Reserved-port constant sync
  (`boot-mini.sh:_MONITORING_UI_PORT` ↔ `main.go:MONITORING_UI_PORT`).

### 7.3 PR title convention

Use Conventional Commits — same types as §6.

**Examples**:

```text
feat(webui): add dark mode toggle
fix(watchdog): reset backoff on STATUS_FILE change
security(auth): enforce rate limit on Basic Auth
feat(app): add one-tap root install via 5-level pm install cascade
refactor(shell): split primitives into Layer 0 (boot-mini.sh)
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
rollback preparedness are the primary concerns. The default
template remains unified for all feature/fix/docs PRs targeting
`develop`; the release template is used exclusively for
`release/*` and `hotfix/*` PRs targeting `main`. The reversal
history (why the default template was **not** modified to include
release concerns) is recorded in
`docs/adr/0001-release-workflow.md` §Decision → §4.

**Discoverability**: `docs/adr/0001-release-workflow.md` and the
release template itself both document the `?template=release.md`
query string. No contributor has asked which template to use
across six release cycles.

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

### 8.2 Shell

**Format**: `shfmt -w -i 4 -ci proxy/*.sh scripts/*.sh`

**Rules**:

- `#!/system/bin/sh` for Android compatibility.
- `set -euo pipefail` in bash scripts — **exception**: `install_app.sh` deliberately omits `set -e` because the 5-level cascade relies on non-zero exit codes to fall through strategies.
- Quote all variables: `"$var"`.
- Use `[[ ]]` where bash is available.
- Use `local` for internal variables.
- Avoid `eval`.
- Avoid unquoted `$(...)`.

**Project-specific rules**:

- `_MONITORING_UI_PORT` defined in `boot-mini.sh` only (Layer 0).
- Section tracking (`in_section` boolean) when parsing TOML.
- `STATUS_FILE` written only from `startService` / `stopService`.
- Custom Chains — never pollute `OUTPUT` / `INPUT` / `FORWARD`.
- Rotation sorts by **mtime** (`sort -rn -k1,1`), not by directory name.
- Snapshot detection requires `.manifest.json` (SNAP-MANIFEST / ROT-MANIFEST).
- Protected rotation targets: `.last_stable` + newest install snapshot (ROT-PROTECT).
- `install_app.sh` — preserve the 5-level cascade order, 75-second deadline, three-way trap split, and SELinux staging invariant.
- **Never** `setenforce 0` — staging to `/data/local/tmp/` only.

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
| 26 | Never disable SELinux (`setenforce 0`); never change `CASCADE_DEADLINE_SECONDS` (75 s) without re-checking `INSTALL_TIMEOUT` (90 s); never add an external Go dependency without its own ADR; never add a Layer-0 primitive without updating `boot-mini.sh`, `functions.sh`, and `ci.yml` Step 9. |

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

### 9.2 Local verification

```bash
# Go build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..

# Shell syntax
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# Format
gofmt -l proxy/
shfmt -d -i 4 -ci proxy/*.sh scripts/*.sh

# Full build
make build

# All local validations
make check-all

# v1.5.0-specific
make check-install-app
make check-boot-mini
make check-app-version
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
    grep -q "$p" proxy/install_app.sh && echo "✅ $p"
done
grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75s deadline"
grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ Play Protect restore"
! grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce 0"

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

**Full procedure**: `docs/REFERENCE.md` §3.12.

### 9.5 Pre-PR checklist

```bash
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done
gofmt -l proxy/
shfmt -d -i 4 -ci proxy/*.sh scripts/*.sh
make build
make check-all
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
| Concurrency change | `docs/REFERENCE.md` §3.14 |
| Ports change | `docs/REFERENCE.md` §2.1 + §3.9 |
| Memory-limit change | `SECURITY.md` §5.31.1 + `docs/REFERENCE.md` §1.9 |
| Backup-layer change | `docs/REFERENCE.md` §4 + `docs/GUIDE.md` §8 + `SECURITY.md` §5.32 |
| Rotation-semantics change | `docs/REFERENCE.md` §4.6.5 |
| WebUI language change | All three HTML files + `docs/REFERENCE.md` §7.6 |
| Install-flow change | `SECURITY.md` §5.36 + `docs/REFERENCE.md` §3.12 |
| Architectural decision | `docs/adr/` (new ADR) |

### 10.2 Documentation standards

- Clear, concise, with practical examples.
- Valid Markdown; working relative links.
- Updated with the latest code.
- No `TODO` markers; no duplication across files.
- English-only by convention. Translations: `docs/*.<lang>.md`.

### 10.3 The 12-file model

`docs/MAP.md` §1 defines the 12 user-facing documents. Every new file requires a PR that amends `MAP.md` §1 and `MAP.md` §3. **The friction is the point** — it forces a decision.

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

`release.sh` performs a **hard check**: it verifies that `update.json` contains an entry named `x-note-v<XYZ>` (dots stripped from the version — e.g. `v1.5.0` → `x-note-v150`). If missing → **exit code 3**.

**Manual workflow** — add it **before** running `release.sh`:

```bash
# 1. Add the field to update.json
$EDITOR update.json
# Add: "x-note-v150": "v1.5.0 — <short release note>",

# 2. Verify
jq -e --arg k "x-note-v150" '.[$k]' update.json >/dev/null && echo "✅ ready"

# 3. Run release.sh
./scripts/release.sh v1.5.0
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
| `proxy/go.mod` + `go.sum` | ❌ Manual | Pinned to `filepath-securejoin v0.7.0` (ADR-0002 compliance) |

### 11.5 Standard release (recommended)

```bash
# 1. Add x-note-v<XYZ> to update.json (v1.5.0 HARD requirement)
$EDITOR update.json

# 2. Update CHANGELOG.md
$EDITOR CHANGELOG.md
git add CHANGELOG.md update.json
git commit -m "docs(changelog): prepare vX.Y.Z"

# 3. Preview
./scripts/release.sh vX.Y.Z --dry-run

# 4. Execute (interactive)
./scripts/release.sh vX.Y.Z

# 5. Wait ~5 min → Release is live
```

`release.sh` performs:
1. SemVer format validation.
2. `versionCode` computation.
3. Branch + working tree + tag availability check.
4. **`x-note-v<XYZ>` presence check** (v1.5.0 — exit 3 if missing).
5. Update `VERSION` + `module.prop` + `update.json` (with rollback on failure).
6. Create commit + annotated tag.
7. Push to origin (unless `--no-push`).

### 11.6 PATCH release (hotfix)

```bash
git checkout main && git pull origin main
$EDITOR update.json                                    # add x-note-v<XYZ>
./scripts/release-patch.sh v1.5.1
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

Triggered on `vX.Y.Z` tag push. Full step table in `release.yml` header. Key v1.5.0 changes:

- **Step 6 "Verify metadata consistency"** — enforces `VERSION == module.prop.version == update.json.version`, `releaseDate == x-note-last-updated`, and the `versionCode` formula. Aborts **before** packaging.
- **Step 11 "Stage APK + `.sha256`"** — copies both files to `web/app-debug.apk` + `.sha256`. Sidecar content must reference `app-debug.apk` (final staged name).
- **Step 12 packaging** — ZIP now also bundles `proxy/install_app.sh`, `proxy/boot-mini.sh`, `proxy/go.sum`.
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
| Missing `install_app.sh` / `boot-mini.sh` in ZIP | Re-run workflow (packaging bug) |
| Bad `x-note-v<XYZ>` (only) | **No re-tag** — follow-up commit on `main`; root manager reads `update.json` from `main` |

**Delete a tag**:

```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
gh release delete vX.Y.Z --yes
```

### 11.12 Full details

The complete step-by-step release process (16 sections, 30-point device verification checklist, 42-scenario upgrade matrix) lives in `release.yml`'s header and `docs/REFERENCE.md` §3.12. This section covers the **workflow** you need as a contributor; the exhaustive operator reference is in the workflow file itself.

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

The first realistic hotfix scenario from v1.5.0 would be `v1.5.0 → v1.5.1`.

### 13.2 Steps

```bash
git checkout main && git pull origin main
git checkout -b hotfix/v1.5.1-critical
# ... minimal fix ...
git commit -m "fix(critical): patch login bypass"
git push -u origin hotfix/v1.5.1-critical
# → Open PR against main using ?template=release.md
# → Fast-track review
# → Squash merge
./scripts/release-patch.sh v1.5.1
make sync
```

**PR template**: `release/*` and `hotfix/*` PRs both target `main` and use the **separate** release template at `.github/PULL_REQUEST_TEMPLATE/release.md`, opened via the query string `?template=release.md`. See §7.5 for the full rationale.

### 13.3 PATCH versioning

| Released | Hotfix | New Version |
|---|---|---|
| `v1.4.0` | Fix critical bug | `v1.4.1` |
| `v1.5.0` | Fix critical bug | `v1.5.1` |
| `v1.5.1` | Fix critical bug | `v1.5.2` |

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

### 13.5 Hotfix touching v1.5.0 subsystems

Additional considerations per subsystem:

| Subsystem | Must preserve |
|---|---|
| Backup layer | Do **not** edit `txn-*` / `orphan-txn-*` manually. Preserve `.last_stable` pointer. Verify recovery mode. Keep SNAP-*/ROT-* invariants. Keep the `apk/` mirror's two independent protections. |
| Companion install flow | Preserve 5-level cascade order, 75-second deadline, three-way trap split (130/143), SELinux staging path, `$_VERIFIER_ORIG` restore value, localhost gate on all 3 surfaces. |
| Layered Bootstrap | Preserve `boot-mini.sh`'s 5 primitives + `_MONITORING_UI_PORT`; keep `functions.sh` sourcing `boot-mini.sh` without redefinition. |

`ci.yml` Steps 8, 9, 10 catch regressions automatically. `make check-install-app` and `make check-boot-mini` run the same checks locally.

---

## 14. Recognition

We recognize contributions through badges maintained in `docs/CONTRIBUTING.md` §14.1. All badges are updated **manually** at each major release, and immediately when a specific acceptance criterion is met.

### 14.1 The 19 badges

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
| 🧪 **Install Test Engineer (v1.5.0)** | **Tested the 5-level install cascade on 3+ ROMs; reported strategy used per ROM** |
| 🔍 Auditor | One accepted Audit Correction |
| 🔧 Platform Fixer | Fixed a platform-specific issue |
| 📐 Metrics Wizard | Improved the metrics/Dashboard system |
| ⚡ Concurrency Guardian | Fixed a real race condition (`rebuildMu` or `backupMu`) |
| 🔌 Port Architect | Fixed dynamic-ports issue |
| 🧠 Memory Architect | Tested MEM-1 across 3+ RAM tiers |
| 🛡️ Data Guardian | Tested the 10 defensive layers on 3+ devices / root solutions |

### 14.2 The new v1.5.0 badge

**🧪 Install Test Engineer (v1.5.0)** — granted for verifying the 5-level `pm install` cascade on **3+ devices or 3+ ROMs**.

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

### 14.3 Audit Corrections Registry

The full registry (33 entries from v1.0.0) lives in `SECURITY.md` §15. **No new corrections in v1.1.0 through v1.5.0** — those releases added runtime improvements, correctness fixes, and feature additions, not audit-correction entries.

**Next expected**: #34 (future release).

### 14.4 Full badge list

See §14.1 for the complete 19-badge table (18 from v1.0.0–v1.4.0, plus the new v1.5.0 badge in §14.2). Detailed acceptance criteria per badge and current holders are maintained in this section as contributions are verified.

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

- Module version (`v1.5.0`).
- Android version, device, ROM, kernel, architecture.
- Root solution + version.
- Clear reproduction steps.
- `status.sh --diagnose` output.
- `status.sh --json` output.
- `runtime_info` output (7-field `backups` if relevant).
- `dnscrypt_main.log` tail (~200 lines).
- If the issue is about language: browser version + screenshots in both EN and AR.
- If the issue is about install: which cascade level succeeded/failed + the `INSTALL_FAILED_*` error.
- Steps already attempted.

---

## 16. Quick Reference

### 16.1 Cheat sheet

```bash
# Feature
git checkout develop && git pull
git checkout -b feature/my-feature
# ... work ...
make build && make check-all
git push -u origin feature/my-feature
# → Open PR against develop

# Release
git checkout develop && git pull
$EDITOR update.json && $EDITOR CHANGELOG.md      # add x-note-v<XYZ>
git commit -m "docs(changelog): prepare vX.Y.Z"
./scripts/release.sh vX.Y.Z

# Hotfix
git checkout main && git pull
git checkout -b hotfix/v1.5.1-critical
# ... fix ...
git push -u origin hotfix/v1.5.1-critical
# → Open PR against main using ?template=release.md
git checkout main && ./scripts/release-patch.sh v1.5.1
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
| Redefine a Layer-0 primitive in `functions.sh` | Layer 0 lives in `boot-mini.sh` only |
| Add an external Go dependency without an ADR | ADR-0002 policy: one ADR per new dependency |
| Open a release PR without `?template=release.md` | Use the query string (§7.5) |

### 16.4 Common commands

```bash
make version            # → v1.5.0
make build              # build 4 architectures
make package            # build + package Magisk ZIP
make check-all          # all local validations
make check-install-app  # install_app.sh validation (v1.5.0)
make check-boot-mini    # Layer 0/1 split validation (v1.5.0)
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

**Full security model**: `SECURITY.md` §5.36. **Full cascade reference**: `docs/REFERENCE.md` §3.12.

### 17.2 Layered Bootstrap (ADR-0003)

The shell library is split into two files:

| Layer | File | Contents |
|---|---|---|
| **Layer 0** | `proxy/boot-mini.sh` | 5 primitives (`log_msg`, `get_run_dir`, `read_conf`, `is_port_open`, `get_webui_port`) + `_MONITORING_UI_PORT` |
| **Layer 1** | `proxy/functions.sh` | Every other shell helper. Sources Layer 0 at load time. |

**Single legitimate duplicate**: `customize.sh §[2]` uses `_MONITORING_UI_PORT="${_MONITORING_UI_PORT:-8080}"` because it runs **before** `boot-mini.sh` is extracted. CI Step 10 rejects any other redeclare.

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

## Footer

**Last updated**: 2026-10-19
**Version**: v1.5.0 (Global Edition)
**Author**: gasciljh

This file consolidates 5 pre-consolidation documents into one.
See `docs/MAP.md` for the full 15-file documentation model and
`CHANGELOG.md` §[v1.5.0] for the consolidation scope.

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