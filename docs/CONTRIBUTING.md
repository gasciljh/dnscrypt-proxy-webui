# Contributing to DNSCrypt Smart Filter

Thank you for your interest in contributing! This guide explains how
to contribute effectively.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • `Last updated` reflects the v1.1.0 release date.
>   • Commit example section (§5.5) extended with 3 new examples
>     for the v1.1.0 runtime improvements (MEM-1, MEM-2, MEM-3).
>   • `§9.1 When to Update Documentation` gained 2 rows for
>     MEM-1 (dynamic memory limit) and v1.1.0 runtime_info fields.
>   • `§13.1 Golden Rules` gained Rule #21 — v1.1.0 memory
>     observability requirement.
>   • `§13.3 When Adding a New Feature` gained 3 checkboxes for
>     v1.1.0 runtime additions (memory limit, profile_key,
>     MONITORING_UI_PORT).
>   • `§13.6 Quick References` and `§13.7 Full References`
>     extended with `docs/UPGRADE.md` and v1.1.0 runtime items.
>   • Release examples in §10 updated from `v1.1.0` to `v1.2.0`
>     (release) and `v1.0.1` to `v1.1.1` (PATCH).
>   • Related documents box now includes `docs/UPGRADE.md`.

> **📖 Branching, Release & Decisions**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Publishing a release → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)

---

## Table of Contents

1. [Code of Conduct](#1-code-of-conduct)
2. [How to Contribute](#2-how-to-contribute)
3. [Development Setup](#3-development-setup)
4. [Branch Strategy](#4-branch-strategy)
5. [Commit Convention](#5-commit-convention)
6. [Pull Request Process](#6-pull-request-process)
7. [Coding Standards](#7-coding-standards)
8. [Testing Requirements](#8-testing-requirements)
9. [Documentation Requirements](#9-documentation-requirements)
10. [Release Process](#10-release-process)
11. [Where to Ask for Help](#11-where-to-ask-for-help)
12. [Recognition](#12-recognition)
13. [v1.1.0 — Contributors Reference](#13-v110--contributors-reference)

---

## 1. Code of Conduct

### 1.1 Pledge

We pledge to make participation in this project a **harassment-free
experience** for everyone, regardless of:

- Age
- Body size
- Disability
- Ethnicity
- Gender identity
- Level of experience
- Nationality
- Personal appearance
- Race
- Religion
- Sexual identity and orientation

See [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) for full details.

### 1.2 Standards

**Positive behavior**:
- Using welcoming and inclusive language.
- Respecting different viewpoints.
- Accepting constructive criticism gracefully.
- Focusing on what is best for the community.
- Showing empathy toward other community members.

**Unacceptable behavior**:
- Sexual language or imagery.
- Insulting or derogatory comments.
- Personal or political harassment.
- Publishing private information without permission.
- Other unprofessional conduct.

### 1.3 Enforcement

Maintainers have the right to:
- Remove / edit / reject comments and commits.
- Temporarily or permanently ban contributors.

**To report** unacceptable behavior:
- [GitHub Private Report](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new)
- Or contact the maintainer directly via [@gasciljh](https://github.com/gasciljh)

---

## 2. How to Contribute

### 2.1 Contribution Types

| Type | How |
|---|---|
| Bug reports | Open an Issue using the template |
| Feature requests | Open an Issue with `[Feature]` in the title |
| Documentation | Direct PR — no prior Issue needed |
| Bug fixes | PR with a linked Issue |
| Features | Issue first, then PR after discussion |
| Translation | Direct PR to `docs/*.<lang>.md` |
| Security fixes | Read [SECURITY.md](SECURITY.md) first |
| Architecture decisions | Propose an ADR — see §4.7 |
| **Memory tests (v1.1.0)** | **Report GC behavior per RAM tier — see §12.2** |

### 2.2 Before Starting

**For large features**:
1. Open an Issue first.
2. Explain the idea + benefits.
3. Wait for approval (do not start work before).
4. This saves your time and ours.

**For small fixes** (typos, obvious bugs):
- No prior Issue needed.
- Open a PR directly against `develop`.

### 2.3 What We Are Looking For

**We welcome**:
- Bug fixes.
- Performance improvements (with numbers).
- Better documentation (clear, illustrated).
- Translations.
- Security improvements (see [SECURITY.md](SECURITY.md)).
- **Platform tests** (Linux/macOS/WSL2).
- **Dashboard JSON reports** on different browsers.
- **Architecture Decision Records (ADRs)** for non-trivial decisions.
- **v1.1.0**: Memory-behavior reports across device RAM tiers.

**Not accepted**:
- Complete rewrite without discussion.
- Structural changes without a compelling reason.
- Adding external dependencies without strong justification.
- "Formatting-only" PRs with no added value.

---

## 3. Development Setup

### 3.1 Requirements

| Tool | Minimum version | Purpose | Required? |
|---|:---:|---|:---:|
| **Go** | 1.22+ | Backend (`main.go`) | Yes |
| **Android NDK** | r26b+ | Cross-compilation | Recommended |
| **Make** | 4.0+ | Build orchestration | Yes |
| **Git** | 2.30+ | Version control | Yes |
| **ShellCheck** | 0.10+ | Shell linting | Recommended |
| **shfmt** | 3.8+ | Shell formatting | Recommended |
| **golangci-lint** | **v2.5.0+** | Go linting | Recommended |
| **markdownlint** | latest | Markdown linting | Recommended |
| **yamllint** | latest | YAML linting | Recommended |
| **actionlint** | latest | GitHub Actions linting | Recommended |
| **python3** | 3.8+ | JSON/YAML validation | Recommended |
| **jq** | 1.6+ | JSON manipulation | Recommended |
| **curl** or **wget** | — | Download DNS binaries | Yes |
| **zip/unzip** | — | Packaging | Yes |

"Recommended" means "not required for local development, but required
for full CI".

### 3.2 Quick Install

#### Ubuntu / Debian

```bash
# 1. Basics
sudo apt update
sudo apt install -y \
    git make curl jq \
    golang-1.22 \
    shellcheck \
    python3 python3-pip \
    zip unzip

# 2. shfmt
curl -fsSL "https://github.com/mvdan/sh/releases/download/v3.10.0/shfmt_v3.10.0_linux_amd64" \
    -o /tmp/shfmt
sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt

# 3. golangci-lint v2.5.0 (schema v2)
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | \
    sudo sh -s -- -b /usr/local/bin v2.5.0

# 4. actionlint
go install github.com/rhysd/actionlint/cmd/actionlint@latest

# 5. markdownlint
sudo npm install -g markdownlint-cli

# 6. yamllint + pre-commit
pip3 install --user yamllint pre-commit

# 7. Verify
go version
make version
```

#### macOS

```bash
brew install go make jq shellcheck shfmt golangci-lint
brew install markdownlint-cli yamllint actionlint pre-commit
make version
```

#### Termux (Android)

```bash
pkg update
pkg install git make golang shellcheck jq python
pip install yamllint pre-commit
make version
```

### 3.3 DevContainer (easiest)

```bash
# 1. Open the project in VS Code
code .

# 2. F1 → "Dev Containers: Reopen in Container"
# 3. Wait ~2-4 minutes
```

All tools are installed automatically via `.devcontainer/setup.sh`.

### 3.4 Verify Your Environment

```bash
# Show the project version
make version

# Expected: v1.1.0

# Show available targets
make help
```

### 3.5 Clone and Configure Git

```bash
# 1. Clone the repository
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

**Important**: Always work on `develop`, never on `main`. See §4 below.

---

## 4. Branch Strategy

> **📖 The full strategy is documented in [`docs/BRANCHING.md`](BRANCHING.md).**
>
> This section is a **summary**. Read `BRANCHING.md` before your first PR.

### 4.1 Two Permanent Branches

| Branch | Purpose | Direct push |
|---|---|---|
| `main` | Stable releases only | ❌ Forbidden (Branch Protection) |
| `develop` | Integration — features land here first | ⚠️ Maintainer only |

### 4.2 Short-Lived Branches

| Prefix | Purpose | Base | Target |
|---|---|---|---|
| `feature/*` | New functionality | `develop` | `develop` |
| `fix/*` | Non-critical bug fix | `develop` | `develop` |
| `docs/*` | Documentation only | `develop` | `develop` |
| `chore/*` | Maintenance, tooling | `develop` | `develop` |
| `refactor/*` | Code refactor | `develop` | `develop` |
| `test/*` | Adding tests | `develop` | `develop` |
| `release/*` | Release preparation | `develop` | `main` |
| `hotfix/*` | Emergency fix | `main` | `main` + `develop` |

### 4.3 Naming Rules

- **Lowercase only**: `feature/webui-dark-mode` ✅
- **Hyphens, not underscores**: `fix/port-cache` ✅
- **Short and specific**: `feature/editor-fsm` ✅
- **English only**: avoids CI encoding issues.

Full rules: [`docs/BRANCHING.md`](BRANCHING.md) §3.

### 4.4 The Golden Rule

> **Never open a PR against `main` for a feature, fix, or docs change.**
>
> `main` accepts PRs **only** from `release/*` and `hotfix/*` branches.

If you accidentally open a PR against `main`, the maintainer will ask
you to reopen it against `develop`.

### 4.5 Typical Workflow

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create a branch
git checkout -b feature/my-feature

# 3. Develop
# ...

# 4. Build check
make build

# 5. Commit
git add .
git commit -m "feat(proxy): add new endpoint"

# 6. Push
git push -u origin feature/my-feature

# 7. Open a PR against develop (not main!)
```

### 4.6 Cleanup After Merge

```bash
# Delete local branch
git checkout develop
git pull origin develop
git branch -d feature/my-feature

# The remote branch is auto-deleted by GitHub
# (Settings → General → Automatically delete head branches)
```

### 4.7 Architecture Decision Records (ADRs)

For **non-trivial architectural or process decisions**, propose an ADR
instead of (or alongside) a regular PR.

| When | Where |
|---|---|
| New architectural decision | `docs/adr/` (new file) |
| Reversing a previous decision | `docs/adr/` (new file that supersedes the old one) |
| Simple bug fix | Regular PR (no ADR) |
| Small refactor | Regular PR (no ADR) |

**Full guide**: [`docs/adr/README.md`](adr/README.md) §3 and §7.

**Current ADRs**: 6 (see [`docs/adr/README.md`](adr/README.md) §6).

---

## 5. Commit Convention

We use `Conventional Commits`.

### 5.1 Format

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### 5.2 Types

| Type | Purpose | Bump |
|---|---|---|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `security` | Security fix | PATCH |
| `perf` | Performance improvement | PATCH |
| `refactor` | Refactor | PATCH |
| `docs` | Documentation | — |
| `chore` | Routine tasks | — |
| `build` | Build system | — |
| `ci` | CI workflows | — |
| `revert` | Revert | — |
| `release` | Release | — |

### 5.3 Examples

```bash
# ✅ Correct
feat(webui): add dark mode toggle
fix(proxy): resolve race condition in save
docs(api): update authentication section
security(auth): use constant-time comparison
perf(blocklist): switch to streaming I/O

# ❌ Wrong
updated files
fix bug
WIP
changes
```

### 5.4 Breaking Changes

```text
feat(api)!: remove legacy /v1 endpoints

BREAKING CHANGE: /v1/* endpoints removed.
Use /api/* instead.
```

### 5.5 Examples for v1.0.0 / v1.1.0 Fixes

When fixing similar issues to those addressed in v1.0.0 and v1.1.0,
follow these patterns:

```bash
# Fix #1 — Dashboard JSON conversion (Critical)
git commit -m "fix(dashboard): convert Prometheus metrics to JSON

metricsProxyHandler was returning Prometheus text with
Content-Type: application/json, breaking dashboard.html JSON.parse().

Added parsePrometheus() and buildDashboardJSON() to convert on the fly.

Audit Correction #25
Refs: docs/SECURITY.md"

# Fix #2 — Shell fallback (Critical)
git commit -m "fix(ci): add getSystemShell() fallback for Linux

runShell hardcoded /system/bin/sh, which doesn't exist on Linux/macOS,
breaking CI Go builds.

Added getSystemShell() that probes /system/bin/sh, /bin/sh, /usr/bin/sh.

Refs: docs/ARCHITECTURE.md"

# Fix #3 — Preserve settings on upgrade (Critical)
git commit -m "fix(installer): preserve user settings on upgrade

customize.sh relied on [ ! -f ] which always fails because unzip -o
extracts defaults first. Result: webui.conf + dnscrypt-proxy.toml lost
on every upgrade.

Added backup/restore around unzip for 5 config files.

Audit Correction #26
Refs: docs/SECURITY.md"

# Fix #8 — Basic Auth rate limit (High)
git commit -m "security(auth): enforce rate limiting on Basic Auth

checkAuth did not record failed Basic Auth attempts, allowing
unlimited brute force on LAN.

Now uses loginAttempts with same 5/15min policy as handleLogin.

Audit Correction #22
Refs: docs/SECURITY.md"

# Fix #12 — Exact endpoint matching (Medium)
git commit -m "fix(api): use exact endpoint matching

strings.Contains matched /api/update_profile_evil as update_profile.

Added hasEndpoint(path, name) that requires exact match.

Audit Correction #24
Refs: docs/SECURITY.md"

# NEW-1 — Login POST-only (Critical)
git commit -m "security(auth): enforce POST-only on login/logout

GET /api/auth/login?username=X&password=Y was accepted, creating
CSRF vector via <img src=...> and leaking credentials to browser
history + server logs.

Audit Correction #28
Refs: docs/SECURITY.md"

# NEW-3 — readConfPort range check (High)
git commit -m "fix(config): validate port range in readConfPort

PORT=0 caused random port selection; PORT=99999 failed silently
with exit code 0.

Now validates range [1, 65535] and falls back to default.

Audit Correction #29
Refs: docs/SECURITY.md"

# NEW-4 — /readyz localhost-only (High)
git commit -m "security(api): restrict /readyz to localhost

/readyz exposed system details (config, run_dir, version) to any
client on LAN when BIND_ADDR=0.0.0.0.

/healthz remains public for load balancers.

Audit Correction #30
Refs: docs/SECURITY.md"

# NEW-5 — shellQuote (High)
git commit -m "security(shell): add shellQuote for dynamic paths

runShell('. ' + MODDIR + '/functions.sh; ...') allowed shell
injection if MODDIR contained shell metacharacters.

Added shellQuote() and applied to 4 call sites.

Audit Correction #31
Refs: docs/SECURITY.md"

# RACE-1 — rebuildMu mutex (Critical)
git commit -m "fix(concurrency): serialize rebuildBlocklist calls

Two callers (updateProfile + atomicSaveRulesInternal) could run
rebuildBlocklist concurrently, corrupting BLOCKLIST.

Added rebuildMu sync.Mutex with coarse-grained locking.

Audit Correction #32
Refs: docs/SECURITY.md"

# PORT-2 — runtime_info ports (High)
git commit -m "feat(api): return webui_port + dashboard_port in runtime_info

index.html and dashboard.html had hardcoded ports, breaking links
when PORT or DASHBOARD_PORT were customized.

Added dynamic port discovery via runtime_info; frontend now builds
URLs using window.location.hostname.

Audit Correction #33
Refs: docs/SECURITY.md"

# MEM-1 — Dynamic memory limit per profile (v1.1.0)
git commit -m "feat(proxy): add dynamic memory limit per profile

debug.SetMemoryLimit was hardcoded to 80MB for all profiles. On
'ultimate', actual working set approaches 200MB → GC thrashing.

Added memoryLimitForProfile() + applyMemoryLimit():
  light=80, normal=100, pro=120, proplus=160, ultimate=220 (MB)

Applied at startup and on every profile change. Exposed via
runtime_info.memory_limit_mb.

Refs: docs/SECURITY.md §5.30.1
Refs: docs/ARCHITECTURE.md §3.9, §4.9.1"

# MEM-2 — Extended shellQuote charset (v1.1.0)
git commit -m "security(shell): extend shellQuote character set

shellQuote() escaped 20 shell metacharacters. Added {, }, \\n, \\t
for brace expansion and word-splitting defense-in-depth.

No known exploit existed — this is defense-in-depth.

Refs: docs/SECURITY.md §5.30.2"

# MEM-3 — MONITORING_UI_PORT in metrics handler (v1.1.0)
git commit -m "refactor(proxy): use MONITORING_UI_PORT constant in metrics handler

metricsProxyHandler contained a hardcoded 'http://127.0.0.1:8080/api/metrics'.

Now uses the MONITORING_UI_PORT constant — single source of truth
for the reserved port.

Behavior is unchanged.

Refs: docs/SECURITY.md §5.30.3"
```

**Rule**: Every "Audit Correction" commit must:
1. Mention the number in the footer: `Audit Correction #XX`.
2. Reference the document: `Refs: docs/SECURITY.md`.
3. Explain **why** (not just what).

**Rule for v1.1.0 runtime improvements**: MEM-1 / MEM-2 / MEM-3 are
**not** audit corrections. Use `Refs: docs/SECURITY.md §5.30.N`
instead of `Audit Correction #XX`.

### 5.6 ADR Commits

For ADR-related commits, follow this pattern:

```bash
# New ADR
git commit -m "docs(adr): add ADR-0007 for webhook notifications

Documents the decision to add webhook notifications for release events,
with alternatives (email, Matrix, ntfy).

Refs: docs/adr/0007-webhook-notifications.md"

# Superseding an ADR
git commit -m "docs(adr): supersede ADR-0004 with ADR-0005

ADR-0004 (unified PR template) was reversed during the same
[Unreleased] cycle. ADR-0005 introduces a release-specific template.

Refs: docs/adr/0005-release-specific-pr-template.md"
```

---

## 6. Pull Request Process

### 6.1 Before Opening a PR

```bash
# 1. Ensure develop is up to date
git checkout develop
git pull origin develop

# 2. Rebase your branch
git checkout feature/my-feature
git rebase develop

# 3. Verify the build
make build

# 4. Verify shell syntax
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# 5. Format check
gofmt -l proxy/
shfmt -d -i 4 -ci proxy/*.sh scripts/*.sh
```

### 6.2 Choose the Correct Base Branch

> **🎯 This is the most common mistake first-time contributors make.**
>
> Please read [`docs/BRANCHING.md`](BRANCHING.md) §5.1 before opening a PR.

| Your branch starts with… | Open the PR against… | Template |
|---|---|---|
| `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/` | **`develop`** | Default (`PULL_REQUEST_TEMPLATE.md`) |
| `release/`, `hotfix/` | **`main`** | Release (`?template=release.md`) |
| `develop` (directly) | ❌ Never — use `release/*` or `release.sh` | — |

**Quick check**:

```bash
# If unsure, verify the base on the GitHub PR page:
# The "base:" dropdown should say "develop" (or "main" for releases).
```

**Release PRs**: When opening a release PR (`release/*` → `main` or
`hotfix/*` → `main`), use the release-specific template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.2.0?template=release.md
```

See [ADR-0005](adr/0005-release-specific-pr-template.md) for why.

### 6.3 PR Templates

| Template | When to use | Location |
|---|---|---|
| **Default** | `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` → `develop` | `.github/PULL_REQUEST_TEMPLATE.md` |
| **Release** | `release/*`, `hotfix/*` → `main` | `.github/PULL_REQUEST_TEMPLATE/release.md` |

See [`docs/BRANCHING.md`](BRANCHING.md) §5.5 for the release template URL pattern.

### 6.4 Review

**What we look for:**
- Clean, readable code.
- Comprehensive documentation updates.
- Meaningful commits.

**What we reject:**
- Untested code.
- Large changes without prior discussion (Issue).
- CI check failures.
- Silent breaking changes.
- PRs targeting `main` for non-release content.

### 6.5 Merge Strategy

The project uses **squash merges only**:

| Merge into | Strategy |
|---|---|
| `develop` | Squash |
| `main` (from `release/*`) | Squash |
| `main` (from `hotfix/*`) | Squash |

**Never** use:
- ❌ Merge commits.
- ❌ Rebase merges.

### 6.6 After Merge

```bash
git checkout develop
git pull origin develop
git branch -d feature/my-feature
# The remote branch is auto-deleted by GitHub
```

---

## 7. Coding Standards

### 7.1 Go

**Format:**

```bash
gofmt -w proxy/
goimports -w proxy/
```

**Rules:**
- Always use `gofmt`.
- Clear variable names (`userCount` not `uc`).
- Comment on every exported function.
- Handle every error (`if err != nil`).
- Use `context` on every I/O operation.
- Use `defer unlock()` on every mutex.
- No `panic()` inside libraries.
- No `fmt.Println` in production (use `logWithLevel`).
- No global variables without proper locking.

**v1.0.0-specific:**
- `getSystemShell()` — any new shell execution must use it.
- `hasEndpoint()` — any new endpoint must use it (no `strings.Contains`).
- `parsePrometheus` + `buildDashboardJSON` — for new metrics.
- `isPortOpenCached(port)` — with per-port map.
- Rate limiting — any new auth must record in `loginAttempts`.
- `shellQuote()` — for any dynamic path in a shell command.
- `readConfPort` — for any port read from config.
- **`rebuildMu`** — for any operation touching `rebuildBlocklist` (RACE-1).
- **`runtime_info`** — for any endpoint needing actual ports (PORT-2).
- **`sync.Once`** — for one-time initialization (shell detection).

**v1.1.0-specific:**
- **`memoryLimitForProfile(key string) int64`** — any new profile
  must be added here.
- **`applyMemoryLimit(key string)`** — call this only from `main()`
  and `updateProfile()`.
- **`MEMORY_LIMIT_*` constants** — any new profile needs a constant.
- **`readSelectedProfile()`** — use it whenever you need the active
  profile; do NOT read `selected_profile.txt` directly elsewhere.
- **`MONITORING_UI_PORT`** — always reference the constant; never
  hardcode `"8080"` again.
- **`memLimitMu`** — access `currentMemLimit` / `currentProfile`
  only while holding this mutex.

### 7.2 Shell

**Format:**

```bash
shfmt -w -i 4 -ci proxy/*.sh scripts/*.sh
```

**Rules:**
- Use `#!/system/bin/sh` for compatibility (POSIX).
- Use `set -euo pipefail` in bash scripts.
- Quote all variables: `"$var"`.
- Use `[[ ]]` instead of `[ ]` where bash is available.
- Use `local` for internal variables.
- Avoid `eval`.
- Avoid unquoted `$(...)`.
- Avoid dangerous commands like `rm -rf $var` without guards.

**v1.0.0-specific:**
- `_MONITORING_UI_PORT="8080"` — in every `get_*_port` function.
- Section tracking — use the `inSection` boolean when parsing TOML.
- `fuser -n tcp ... | tr ' ' '\n' | head -1` — correct parsing (Fix #9).
- `STATUS_FILE` — write only from `startService` / `stopService`.
- Custom Chains — never pollute `OUTPUT` / `INPUT` / `FORWARD`.
- **`getSystemShell()`** — for shell commands (safe fallback).

**v1.1.0-specific:**
- **`get_profile_memory_hint()`** — read-only helper; use it for
  user-facing display in `service.sh`, `action.sh`, `status.sh`.
- **`_inline_get_profile_memory_hint()`** — inline fallback in each
  of the four scripts when `functions.sh` is unavailable.
- **`SELECTED_PROFILE_FILE`** — use the global; do NOT hardcode
  `$MODDIR/proxy/selected_profile.txt` elsewhere.

### 7.3 JavaScript

**Rules:**
- Use `'use strict'`.
- Use `const`/`let`, not `var`.
- Use `===`, not `==`.
- Use consistent quotes (`'`).
- Use `currentStatus` variable — no `indexOf` on `textContent`.
- Use `window.location.hostname` instead of `127.0.0.1` (LAN support).
- Use **`PORTS.webui` / `PORTS.dashboard`** for ports (PORT-2).
- Use **`getDashboardUrl()` / `getWebUIUrl()`** for links (PORT-2).
- Avoid `innerHTML` with user data (use `textContent`).
- Avoid global scope pollution.

**v1.1.0-specific:**
- **`data.profile_key`** and **`data.memory_limit_mb`** — new fields
  in `runtime_info`. Display them in System Info panels; fall back
  to `"unknown"` if missing (for older servers).

### 7.4 YAML

- `indent`: 2 spaces.
- No tabs.
- Quote strings only when necessary.

### 7.5 Markdown

- `line_length`: 200 characters.
- `MD013`: allowed.
- `MD033`: allowed limited inline HTML.
- Use `-` (dash) for lists (not `*`).

---

## 8. Testing Requirements

### 8.1 Minimum

Since the project has no automated test suite, all contributions must
include:

| Feature | Required verification |
|---|---|
| Backend Go | `make build` succeeds without warnings |
| Shell functions | `bash -n` on all modified scripts |
| API endpoints | Manual verification with `curl` |
| UI | Manual verification in browser (both English + Arabic) |
| CI/CD | Full CI test on GitHub Actions |
| Security fix (Audit) | Static verification via `grep` |
| Firewall change | Manual verification via `iptables -L` |
| **Shell execution** | **Build on Linux + Android** |
| **Auth change** | **Manual rate-limit test** |
| **Endpoint matching** | **`curl` for the endpoint + fake variations** |
| **Concurrency change** | **Manual test: run 2 operations simultaneously** |
| **Runtime info change** | **`curl` `/api?action=runtime_info`** |
| **Memory-limit change (v1.1.0)** | **Test all 5 profiles — see §8.8** |

### 8.2 Go Build Check

```bash
cd proxy
go build -buildvcs=false -trimpath -o /tmp/test-main main.go
echo "Exit code: $?"
```

### 8.3 Shell Syntax Check

```bash
for f in proxy/*.sh scripts/*.sh; do
    bash -n "$f" || echo "❌ $f"
done
```

### 8.4 Manual API Testing

```bash
# 1. Health endpoints
curl -s http://127.0.0.1:9090/healthz
# → "ok"

curl -s http://127.0.0.1:9090/readyz
# → JSON (200 or 503)

# 2. Status (requires auth)
curl -b /tmp/cookies.txt http://127.0.0.1:9090/api?action=status
# → {"status":"ON"} or {"status":"OFF"}

# 3. Login POST-only
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 + Allow: POST

# 4. Login POST
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"..."}' \
    -c /tmp/cookies.txt

# 5. Unknown action
curl -i "http://127.0.0.1:9090/api?action=unknown_xyz"
# → 404 Not Found
```

### 8.5 Manual Verification with `grep`

```bash
# Fix #1 — Dashboard JSON
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix #1 (JSON)"
grep -q 'func parsePrometheus' proxy/main.go && echo "✅ Fix #1 (parser)"

# Fix #2 — Shell fallback
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix #2 (shell)"

# Fix #8 — Basic Auth rate limit
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Fix #8 (rate)"

# Fix #12 — Exact endpoint matching
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12 (endpoint)"

# NEW-1 — Login POST-only
grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅ NEW-1"

# NEW-3 — readConfPort range
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅ NEW-3"

# NEW-4 — /readyz localhost
grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅ NEW-4"

# NEW-5 — shellQuote
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5"

# NEW-6 — Auth cache
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6"

# RACE-1 — rebuildMu
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# PORT-2 — runtime_info ports
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# MEM-1 — Dynamic memory limit
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ MEM-1 (apply)"

# MEM-2 — Extended shellQuote
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2 (braces)"

# MEM-3 — MONITORING_UI_PORT in metrics handler
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"
```

### 8.6 Manual Testing on Device

Before pushing any PR, test manually on a real device:

- [ ] WebUI opens without issues.
- [ ] Login works smoothly (POST-only).
- [ ] Toggle service (start/stop).
- [ ] Apply blocklist.
- [ ] Save custom rules.
- [ ] SSE progress updates.
- [ ] PWA install (optional).
- [ ] **Dashboard shows JSON metrics** (Fix #1).
- [ ] **Basic Auth locked after 5 attempts** (Fix #8).
- [ ] **404 for unknown action** (Fix #12).
- [ ] **Login GET → 405** (NEW-1).
- [ ] **`/readyz` from LAN → 403** (NEW-4).
- [ ] **`runtime_info` returns ports** (PORT-2).
- [ ] **BLOCKLIST consistent after concurrent rebuilds** (RACE-1).
- [ ] **`runtime_info.memory_limit_mb` matches active profile** (MEM-1, v1.1.0).
- [ ] **`runtime_info.profile_key` matches `selected_profile.txt`** (MEM-1, v1.1.0).

### 8.7 Pre-PR Checklist

```bash
# 1. Build check
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go && cd ..

# 2. Shell syntax
for f in proxy/*.sh scripts/*.sh; do bash -n "$f" || echo "❌ $f"; done

# 3. Format check
gofmt -l proxy/
shfmt -d -i 4 -ci proxy/*.sh scripts/*.sh

# 4. Full build
make build
```

### 8.8 v1.1.0 — Memory-Limit Testing

If your PR touches the memory-limit logic (`main.go`, `functions.sh`,
`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`), you **must**
test all 5 profiles:

```bash
# For each profile in: light, normal, pro, proplus, ultimate
PROFILE="pro"  # ← change this to test each

echo "=== Testing profile: $PROFILE ==="

# 1. Set the profile
su -c "echo '$PROFILE' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
sleep 5

# 2. Verify runtime_info reflects it
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

# Expected:
#   light    → {"profile_key": "light",    "memory_limit_mb": 80}
#   normal   → {"profile_key": "normal",   "memory_limit_mb": 100}
#   pro      → {"profile_key": "pro",      "memory_limit_mb": 120}
#   proplus  → {"profile_key": "proplus",  "memory_limit_mb": 160}
#   ultimate → {"profile_key": "ultimate", "memory_limit_mb": 220}

# 3. Verify the startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=$PROFILE, limit=<N> MB

# 4. Verify System Info panel shows the profile + limit
# (Open http://127.0.0.1:9090 → System Info → expand)
```

**What to look for:**
- ✅ Each profile sets the correct `memory_limit_mb`.
- ✅ `profile_key` matches `selected_profile.txt`.
- ✅ Startup log reports the transition.
- ✅ System Info panel displays both fields.
- ❌ If `memory_limit_mb` is `80` for every profile → MEM-1 is broken.

---

## 9. Documentation Requirements

### 9.1 When to Update Documentation?

| Change | Document |
|---|---|
| New API endpoint | `docs/API.md` |
| Architectural change | `docs/ARCHITECTURE.md` |
| New feature | `README.md` + `CHANGELOG.md` |
| New config option | `docs/INSTALL.md` |
| Bug fix | `CHANGELOG.md` |
| New common question | `docs/FAQ.md` |
| Security procedure | `docs/SECURITY.md` |
| Security fix (Audit) | `docs/SECURITY.md` + `docs/ARCHITECTURE.md` + `docs/TROUBLESHOOTING.md` |
| **Behavioral change** | `docs/API.md` + `docs/ARCHITECTURE.md` |
| **Shell fix** | `docs/TROUBLESHOOTING.md` + `docs/DEVELOPMENT.md` |
| **CI change** | `docs/DEVELOPMENT.md` + `CHANGELOG.md` |
| **Concurrency change** | `docs/ARCHITECTURE.md` (Concurrency section) |
| **Ports change** | `docs/API.md` (runtime_info) + `docs/ARCHITECTURE.md` |
| **RACE fix** | `docs/SECURITY.md` + `docs/ARCHITECTURE.md` (Concurrency) |
| **PORT fix** | `docs/SECURITY.md` + `docs/API.md` + `docs/ARCHITECTURE.md` |
| **Branch/release policy** | `docs/BRANCHING.md` + `docs/RELEASE_PROCESS.md` |
| **Architectural decision** | `docs/adr/` (new ADR) |
| **Memory-limit change (v1.1.0)** | **`docs/SECURITY.md` §5.30.1 + `docs/ARCHITECTURE.md` §3.9 + `docs/COMPATIBILITY.md` §5.4 + `docs/API.md` §2.1** |
| **New runtime_info field (v1.1.0)** | **`docs/API.md` §6.1.7 + `docs/ARCHITECTURE.md` §16.7 + `web/index.html` + `web/dashboard.html`** |
| **Upgrade path change (v1.1.0)** | **`docs/UPGRADE.md` (add a §3.X section)** |

### 9.2 Documentation Standards

- Clear and concise.
- Practical examples.
- Valid Markdown syntax.
- Working links.
- Updated with the latest code.
- No leftover `TODO` markers.
- No content duplicated elsewhere.

### 9.3 Documentation Language

- `README.md`: English.
- `docs/*.md`: English.
- Code comments: English.

### 9.4 Audit Correction Documentation Pattern

When adding a security/architecture fix, follow this pattern:

```markdown
<a name="5XX"></a>
### 5.XX — Fix title — v1.0.0 (Audit Correction #XX)

**Background**:
[description of the state before the fix]

**Problem**:
[the catastrophic scenario + code example]

**Impact**:
- 🔴 [Impact 1]
- 🔴 [Impact 2]

**Solution (detailed)**:
```go
// Before:
[old code]

// After:
[new code]
```

**Contract**:

| Question | Answer |
|---|---|
| [question] | [answer] |

*(Reference: docs/SECURITY.md)*
```

**Anchor pattern** (important for docs/SECURITY.md):

```markdown
<a name="5XX"></a>
### 5.XX — Title — v1.0.0
```

### 9.5 v1.1.0 Runtime Improvement Pattern

For v1.1.0 runtime improvements (MEM-1 / MEM-2 / MEM-3), use this
pattern instead — they are **not** audit corrections:

```markdown
#### 5.30.X — <Title> (MEM-X)

**Background**:
[code before the change]

**Problem**:
[why the previous behavior was suboptimal]

**Solution**:
[code after the change]

**Impact**:

| Metric | Before | After |
|---|---|---|
| ... | ... | ... |

**Security rationale**:
[why this is defensive; explicitly state "no known exploit" if none]

*(Reference: docs/SECURITY.md §5.30.X)*
```

### 9.6 ADR Documentation Pattern

When proposing a new ADR, follow the template in
[`docs/adr/README.md`](adr/README.md) §7:

```markdown
# ADR-NNNN: <Short Title>

**Status**: Proposed
**Date**: YYYY-MM-DD
**Authors**: @username

## Context
## Decision
## Consequences
## Alternatives Considered
## Related Decisions
## References
```

**Numbering**: sequential, never reused.

**Superseding**: never edit an accepted ADR — create a new one that
supersedes it and update the old one's `Status:` line.

**Full methodology**: [`docs/adr/README.md`](adr/README.md).

---

## 10. Release Process

> **📖 The full step-by-step process is documented in [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md).**
>
> This section is a **summary**. Read `RELEASE_PROCESS.md` before
> publishing a release.

### 10.1 Overview

A release is triggered by pushing a version tag:

```bash
# Stable / Prerelease (from develop)
./scripts/release.sh v1.2.0

# PATCH-only (from main)
./scripts/release-patch.sh v1.1.1
```

Both scripts:

1. Validate the SemVer format.
2. Compute `versionCode`.
3. Update `VERSION`, `module.prop`, `update.json`.
4. Create a commit + tag.
5. Push to `origin`.

**Difference**:

| Script | Use for | Branch | Bump |
|---|---|---|---|
| `release.sh` | Stable, Prerelease | `develop` or `release/*` | Any |
| `release-patch.sh` | Hotfix (PATCH only) | **`main`** | PATCH only |

GitHub Actions (`.github/workflows/release.yml`) then:

1. Builds 4 architectures.
2. Packages the Magisk ZIP.
3. Generates SBOM + Cosign signature.
4. Creates the GitHub Release.
5. **Auto-syncs `main → develop`**.

**Total time**: ~5-10 minutes.

### 10.2 SemVer

```text
v<MAJOR>.<MINOR>.<PATCH>[-prerelease]

v1.0.0        ← first stable release
v1.1.0        ← second stable (current)
v1.1.1        ← next patch (hotfix)
v1.2.0        ← next minor (feature)
v2.0.0        ← next major (breaking)
```

### 10.3 versionCode Format

```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX
```

| Version | versionCode |
|---|:---:|
| v1.0.0 | 1000000 |
| v1.0.1 | 1000001 |
| v1.1.0 | 1010000 |
| v1.1.1 | 1010001 |
| v2.0.0 | 2000000 |

**Constraints**:
- `PATCH` ≤ 99.
- `HOTFIX` ≤ 99.
- Prerelease suffix is **ignored** for `versionCode`.

### 10.4 Release Checklist

- [ ] Working on `develop` (or `release/*`).
- [ ] Working tree is clean.
- [ ] `CHANGELOG.md` has an entry for the new version.
- [ ] CI is green.
- [ ] `./scripts/release.sh vX.Y.Z --dry-run` shows the expected result.
- [ ] `./scripts/release.sh vX.Y.Z` executed.
- [ ] GitHub Actions run succeeds.
- [ ] Release is published with 6 artifacts.
- [ ] `develop` is synced with `main`.
- [ ] `update.json` reflects the new version.

### 10.5 PATCH Releases (Hotfix)

For PATCH-only releases, use `scripts/release-patch.sh`:

```bash
# 1. From main
git checkout main
git pull origin main

# 2. Prepare the PATCH release
./scripts/release-patch.sh v1.1.1

# 3. After the release publishes: back-merge
make sync
```

**Safety rules** (enforced by the script):

1. Branch **must** be `main`.
2. `MAJOR` and `MINOR` **must not** change.
3. `PATCH` **must** be exactly `current + 1`.

**Full rationale**: [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

### 10.6 Full Details

See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for:
- Release types (Stable, Prerelease, Hotfix).
- `release.sh` + `release-patch.sh` options.
- GitHub Actions pipeline (11 steps).
- Post-release verification (Cosign, SBOM, SHA256).
- Rollback procedures.
- Manual release fallback.
- Back-merge after hotfixes.

**Upgrade guide**: [`docs/UPGRADE.md`](UPGRADE.md) — for users
upgrading between versions (including the full `v1.0.0 → v1.1.0`
guide).

---

## 11. Where to Ask for Help

### 11.1 Communication Channels

| Channel | Purpose |
|---|---|
| **GitHub Discussions** | General questions and discussions |
| **GitHub Issues** | Bug reports / feature requests |
| **Security Report** | Private vulnerability disclosure |
| **@gasciljh** | Direct contact via GitHub |

### 11.2 Before Asking

- [ ] Read `README.md`.
- [ ] Read `docs/FAQ.md`.
- [ ] Read `docs/TROUBLESHOOTING.md`.
- [ ] Read `docs/DEVELOPMENT.md` — for development questions.
- [ ] Read `docs/BRANCHING.md` — for workflow questions.
- [ ] Read `docs/RELEASE_PROCESS.md` — for release questions.
- [ ] Read `docs/UPGRADE.md` — for version-upgrade questions.
- [ ] Read `docs/adr/README.md` — for architectural decisions.
- [ ] Search existing Issues.
- [ ] Try the latest version.

### 11.3 A Good Question

Should include:
- Module version (`v1.1.0`).
- Android version and device.
- Clear reproduction steps.
- Attached logs.
- Dashboard state (see `docs/TROUBLESHOOTING.md`).
- `runtime_info` output (with `profile_key` + `memory_limit_mb`).
- Steps already attempted.

### 11.4 v1.1.0 Debug Information

When reporting an issue, attach:

```bash
# 1. Basic info
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" > status.json

# 2. iptables state
su -c "iptables -t nat -L DNSCRYPT_OUT -n" > firewall.txt
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'" >> firewall.txt

# 3. Dashboard state
su -c "curl -s http://127.0.0.1:9091/api/metrics" > metrics.json

# 4. Runtime Info (PORT-2 + MEM-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" > runtime_info.json

# 5. Memory profile (v1.1.0)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'" >> memory.json

# 6. Logs
tail -100 /data/local/tmp/dnscrypt_main.log > logs.txt
```

---

## 12. Recognition

### 12.1 Hall of Fame

Every contributor is added to `docs/HALL_OF_FAME.md` after:
- 5+ merged pull requests.
- Or a distinguished contribution.

### 12.2 Badges

| Badge | Condition |
|---|---|
| Founder | Created the project |
| Top Contributor | 10+ PRs |
| Security Researcher | Accepted vulnerability |
| Documentation | 5+ documentation PRs |
| Translator | Complete translation |
| Compatibility Champ | 3+ tested devices |
| UI/UX | Design improvements |
| Auditor | New Audit Correction |
| Platform Fixer | Platform-agnostic fixes (Linux/macOS/Android) |
| Metrics Wizard | Improvements in metrics/Dashboard |
| Concurrency Guardian | RACE-1 fixes (mutex/concurrency) |
| Port Architect | PORT-2 fixes (dynamic ports) |
| Decision Architect | Proposing an accepted ADR |
| **Memory Architect (v1.1.0)** | **Test dynamic memory limit across RAM tiers + report GC behavior** |

**Detailed conditions**: see [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md).

### 12.3 Contributors Image

https://contrib.rocks/image?repo=gasciljh/dnscrypt-proxy-webui

---

## 13. v1.1.0 — Contributors Reference

### 13.1 Golden Rules

> **1.** Never pollute `OUTPUT` with dynamic rules — use Custom Chains.
>
> **2.** Never write `STATUS_FILE` from read-only functions.
>
> **3.** Never use `strings.Contains` for paths — use `hasEndpoint`.
>
> **4.** Never use a hardcoded `/system/bin/sh` — use `getSystemShell()`.
>
> **5.** Never skip rate limiting on auth endpoints.
>
> **6.** Never embed the DNS version — use `proxy/dnscrypt-proxy.version`.
>
> **7.** Preserve user settings on upgrade (backup/restore).
>
> **8.** Any new metric → Prometheus → JSON.
>
> **9.** Never allow GET on `/api/auth/login` or `/api/auth/logout` (CSRF).
>
> **10.** Never allow `/readyz` from outside localhost (info leak).
>
> **11.** Use `shellQuote()` for any dynamic path in a shell command.
>
> **12.** Use `readConfPort()` for any port read (range check 1-65535).
>
> **13.** Use `rebuildMu` for any operation touching `rebuildBlocklist` (RACE-1).
>
> **14.** Use `runtime_info` for ports — never hardcode in HTML (PORT-2).
>
> **15.** Use `defer unlock()` on every mutex — never forget.
>
> **16.** Use `sync.Once` for any caching operation that runs once.
>
> **17.** Use `window.location.hostname` in JS instead of `127.0.0.1` (LAN support).
>
> **18.** Open PRs against `develop` — never against `main` (see `docs/BRANCHING.md`).
>
> **19.** Document non-trivial decisions as ADRs — reversals require a new ADR, never an edit (see `docs/adr/README.md`).
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

### 13.2 Branch Policy Reminder

| Situation | Branch | PR target | Template |
|---|---|---|---|
| New feature | `feature/*` | `develop` | Default |
| Non-critical fix | `fix/*` | `develop` | Default |
| Documentation | `docs/*` | `develop` | Default |
| Maintenance | `chore/*` | `develop` | Default |
| Refactor | `refactor/*` | `develop` | Default |
| Tests | `test/*` | `develop` | Default |
| Release prep | `release/*` | `main` | `?template=release.md` |
| Emergency fix (PATCH) | `hotfix/*` | `main` | `?template=release.md` |

**Full details**: [`docs/BRANCHING.md`](BRANCHING.md).

### 13.3 When Adding a New Feature

**Checklist**:
- [ ] Use `hasEndpoint` for endpoints.
- [ ] Use `getSystemShell()` for any shell exec.
- [ ] Add rate limiting for any auth.
- [ ] Use `parsePrometheus` + `buildDashboardJSON` for metrics.
- [ ] Use `shellQuote()` for dynamic paths.
- [ ] Use `readConfPort()` for any port read.
- [ ] Use `rebuildMu` for any operation touching BLOCKLIST.
- [ ] Use `runtime_info` for any endpoint needing ports (PORT-2).
- [ ] Use `sync.Once` for one-time operations.
- [ ] Update `docs/API.md` if you added an endpoint.
- [ ] Update `docs/ARCHITECTURE.md` if you changed concurrency.
- [ ] Update `CHANGELOG.md`.
- [ ] Target `develop` in your PR.
- [ ] Consider an ADR for non-trivial decisions.
- [ ] **(v1.1.0)** If adding a new blocklist profile: update
      `MEMORY_LIMIT_*`, `memoryLimitForProfile()`, the 5 inline
      fallbacks, and the profile table in `customize.sh`.
- [ ] **(v1.1.0)** If adding a `runtime_info` field: update
      `buildRuntimeInfo()`, `web/index.html`, and `web/dashboard.html`
      (with `en` + `ar` translations).
- [ ] **(v1.1.0)** If adding a new port or changing `MONITORING_UI_PORT`:
      update the constant, `customize.sh`, `functions.sh`, and
      `docs/API.md` §1.2.

### 13.4 When Fixing a Bug

- [ ] Verify with `make build`.
- [ ] Add `Audit Correction` in the commit footer (if security-related).
- [ ] Update `docs/SECURITY.md` (if security).
- [ ] Update `docs/TROUBLESHOOTING.md` (if a common issue).
- [ ] Add HTML anchor `<a name="XXX"></a>` (if a new section).
- [ ] If the fix is concurrency-related → add `defer rebuildMu.Unlock()`.
- [ ] If the fix is port-related → verify `runtime_info` output.
- [ ] If the fix is memory-limit-related (v1.1.0) → test all 5 profiles.
- [ ] Target `develop` in your PR.

### 13.5 When Publishing a Release

- [ ] For **Stable/Prerelease** → use `./scripts/release.sh vX.Y.Z` from `develop`.
- [ ] For **PATCH-only** → use `./scripts/release-patch.sh vX.Y.Z` from `main`.
- [ ] Use the release PR template (`?template=release.md`).
- [ ] After PATCH release → run `make sync`.
- [ ] See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for the full flow.

### 13.6 Quick References

| Topic | File |
|---------|------|
| v1.0.0 fixes | `CHANGELOG.md` §[v1.0.0] |
| v1.1.0 features | `CHANGELOG.md` §[v1.1.0] |
| Branch workflow | `docs/BRANCHING.md` |
| Release process | `docs/RELEASE_PROCESS.md` |
| ADR system | `docs/adr/README.md` |
| Dashboard JSON | `docs/API.md` |
| Exact matching | `docs/API.md` |
| Shell fallback | `docs/ARCHITECTURE.md` |
| Basic Auth rate limit | `docs/SECURITY.md` |
| Platform abstraction | `docs/ARCHITECTURE.md` |
| Login POST-only | `docs/SECURITY.md` |
| `readConfPort` range | `docs/SECURITY.md` |
| `/readyz` localhost | `docs/SECURITY.md` |
| `shellQuote` injection | `docs/SECURITY.md` |
| Auth cache | `docs/SECURITY.md` |
| `rebuildMu` (RACE-1) | `docs/SECURITY.md` |
| `runtime_info` (PORT-2) | `docs/SECURITY.md` |
| Preserve settings | `docs/SECURITY.md` |
| Audit Registry | `docs/SECURITY.md` |
| Concurrency context | `docs/ARCHITECTURE.md` |
| Ports context | `docs/ARCHITECTURE.md` |
| **v1.1.0 Memory limit (MEM-1)** | **`docs/SECURITY.md` §5.30.1 + `docs/ARCHITECTURE.md` §3.9** |
| **v1.1.0 shellQuote (MEM-2)** | **`docs/SECURITY.md` §5.30.2** |
| **v1.1.0 Monitoring port (MEM-3)** | **`docs/SECURITY.md` §5.30.3** |
| **v1.0.0 → v1.1.0 upgrade** | **`docs/UPGRADE.md` §3.0** |
| Release scripts | `scripts/release.sh`, `scripts/release-patch.sh` |

### 13.7 Full References

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture + Trade-offs |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry |
| [`docs/API.md`](API.md) | HTTP API Reference |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide (v1.0.0 → v1.1.0 + future) |
| [`docs/FAQ.md`](FAQ.md) | Common questions (Q111–Q120 = v1.1.0) |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (v1.0.0 + v1.1.0) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/ROADMAP.md`](ROADMAP.md) | Roadmap |
| [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) | Community guidelines |
| [`docs/BRANCHING.md`](BRANCHING.md) | Branching strategy |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Release process |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records |

---

## Thank You

Thank you to everyone who contributes to this project — whether
through code, documentation, testing, or simply reporting an issue.

**Every contribution counts.**

---

📚 **References**

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [Effective Go](https://go.dev/doc/effective_go)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Netfilter iptables Custom Chains](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Go runtime/debug — SetMemoryLimit](https://pkg.go.dev/runtime/debug#SetMemoryLimit)

---

**Last updated**: 2026-09-26
**Version**: v1.1.0