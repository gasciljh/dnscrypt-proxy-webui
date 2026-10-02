# Contributing to DNSCrypt Smart Filter

Thank you for your interest in contributing! This guide explains how
to contribute effectively.

**Version**: v1.3.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • `Last updated` reflects the v1.2.0 release date.
>   • Commit example section (§5.5) extended with 4 new examples
>     for the v1.2.0 data-preservation additions (BAK-1, BAK-2,
>     BAK-3, BAK-4) and 2 correctness fixes (FIX-1, FIX-2).
>   • §8.8 (Memory-Limit Testing, v1.1.0) — kept and
>     cross-referenced to the v1.2.0 backup layer.
>   • **§8.9 (new)** — Backup/restore testing (v1.2.0). A
>     7-step verification of the 10 defensive layers, with the
>     commands to reproduce each layer.
>   • **§8.10 (new)** — Testing the `upgrade-test.yml` matrix.
>     Documents the 42-scenario CI matrix introduced in v1.2.0
>     and how to reproduce it locally.
>   • **§8.11 (new)** — Bilingual WebUI testing (English default
>     + Arabic toggle). A browser-and-layout verification
>     checklist.
>   • §9.1 (When to Update Documentation) gained rows for:
>       - Backup/restore changes (v1.2.0).
>       - Recovery mode changes (v1.2.0).
>       - `runtime_info.backups` schema changes.
>       - WebUI language toggle changes (v1.2.0).
>   • **§9.5 (new)** — v1.2.0 Backup documentation pattern.
>     A template for documenting any change that touches the
>     10 defensive layers.
>   • **§9.6 (new)** — WebUI language documentation pattern.
>     A template for documenting any change that adds or modifies
>     user-facing strings in the bilingual interface.
>   • §12.2 (Badges) gained:
>       - **Data Guardian** (v1.2.0) — for contributors who
>         test the backup/restore system across devices, root
>         solutions, and upgrade scenarios.
>   • §13.1 (Golden Rules) gained **Rule #22** — v1.2.0 backup
>     observability requirement.
>   • §13.3 (When Adding a New Feature) gained 4 checkboxes
>     for v1.2.0 runtime additions (backup events, recovery
>     mode, config migrations, rotation policy) and 1 checkbox
>     for bilingual string additions.
>   • §13.4 (When Fixing a Bug) gained 2 checkboxes for
>     v1.2.0 correctness fixes (recovery reorder, SW update
>     banner) and 1 checkbox for language toggle fixes.
>   • §13.6 (Quick References) and §13.7 (Full References)
>     extended with the three new v1.2.0 docs:
>       - [`docs/BACKUP.md`](BACKUP.md)
>       - [`docs/EMERGENCY.md`](EMERGENCY.md)
>       - [`docs/UPGRADE.md`](UPGRADE.md) §3.1
>   • Release examples in §10 updated from `v1.2.0` to `v1.3.0`
>     (release) and `v1.1.1` to `v1.2.1` (PATCH), since v1.2.0
>     is now the current release.
>   • **Global edition note**: the WebUI ships with English as
>     the default language and an in-page Arabic toggle. Any PR
>     that adds a user-facing string must supply both `en` and
>     `ar` entries. Documentation remains English-only.

> **v1.2.0 — Corrections in this revision**:
>   • 🔧 **FIX-1 (snapshot-and-reapply)** — The example commit for
>     FIX-1 in §5.5 was corrected to match the actual implementation
>     in `customize.sh` (`§[8a]` + `§[9]` + `§[9b2]`). The previous
>     text described a "reorder + exclude" strategy that was
>     **never shipped**. See the updated example below and the
>     authoritative description in `docs/ARCHITECTURE.md` §3.10
>     and `docs/SECURITY.md` §5.32.1.
>   • 🔧 **Reason string correction** — The BAK-2 example in §5.5
>     previously listed `pre-append-denylist` as the reason string
>     for the `appendDenylist` call site. The actual reason string
>     recorded by `main.go` is `pre-denylist-save`, because
>     `appendDenylist` delegates to `saveDenylist` (which is where
>     the pre-critical backup is triggered). See the corrected
>     example below and `docs/BACKUP.md` §4.3.

> **📖 Branching, Release & Decisions**:
> - Git workflow → [`docs/BRANCHING.md`](BRANCHING.md)
> - Publishing a release → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)

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
13. [v1.2.0 — Contributors Reference](#13-v120--contributors-reference)

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

### 1.4 Language Policy

**WebUI (bilingual: English default + Arabic toggle)**:

As of v1.2.0, the WebUI ships with:

- **English as the default language** (on first load).
- **An in-page toggle** (`langToggle` button) to switch to Arabic.
- The user's choice is stored **client-side only** in
  `localStorage['dnscrypt-lang']`.

**Every new user-facing string** added to the WebUI must supply
**both** an English entry (`translations.en`) and an Arabic entry
(`translations.ar`). The default must remain English.

**Documentation (English-only by convention)**:

- All documentation under `docs/` is **English-only**.
- Community-contributed **documentation translations** are welcome
  as **separate files** (`docs/*.<lang>.md`).
- Additional WebUI languages beyond English + Arabic (FR, DE, ES,
  RU, ZH, ...) are deferred to **v1.4.0** — see
  [`docs/ROADMAP.md`](ROADMAP.md) §6.

See [CODE_OF_CONDUCT.md §FAQ Q9](../CODE_OF_CONDUCT.md) for the full
rationale.

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
| Translation (docs) | Direct PR to `docs/*.<lang>.md` |
| **WebUI string changes (EN + AR)** | **PR with both languages updated (see §4.6 and §8.11)** |
| Security fixes | Read [SECURITY.md](SECURITY.md) first |
| Architecture decisions | Propose an ADR — see §4.7 |
| **Memory tests (v1.1.0)** | **Report GC behavior per RAM tier — see §12.2** |
| **Backup tests (v1.2.0)** | **Verify the 10 defensive layers on a real device — see §8.9 and §12.2** |

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
- Documentation translations (as separate files).
- **WebUI string improvements** (with both EN and AR entries).
- Security improvements (see [SECURITY.md](SECURITY.md)).
- **Platform tests** (Linux/macOS/WSL2).
- **Dashboard JSON reports** on different browsers.
- **Architecture Decision Records (ADRs)** for non-trivial decisions.
- **v1.1.0**: Memory-behavior reports across device RAM tiers.
- **v1.2.0**: Backup/restore reports across devices, root
  solutions, and upgrade scenarios (see §8.9).
- **v1.2.0**: Bilingual WebUI reports across browsers (see §8.11).

**Not accepted**:
- Complete rewrite without discussion.
- Structural changes without a compelling reason.
- Adding external dependencies without strong justification.
- "Formatting-only" PRs with no added value.
- **v1.2.0**: Changes to the 10 defensive layers without a
  corresponding update to [`docs/BACKUP.md`](BACKUP.md) and
  [`docs/EMERGENCY.md`](EMERGENCY.md).
- **v1.2.0**: Adding an English string to the WebUI **without**
  the matching Arabic entry.

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

**v1.2.0 note**: No new tools were added for the data-preservation
release. The 10 defensive layers use only tools already present in
the dev environment (`bash`, `coreutils`, `sha256sum`, `jq`,
`restorecon`/`chcon` on device). See §8.9 for the local testing
procedure.

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

# Expected: v1.2.0

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

**Note**: WebUI string changes are **not** a separate branch type —
they use `feature/*` or `fix/*` (see §4.6). Documentation
translations use `docs/*`.

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

### 4.6 WebUI String Contribution

Any change that adds or modifies a **user-facing string** in the
WebUI must update **both** language objects in all three HTML pages:

| File | Objects to update |
|---|---|
| `web/index.html` | `translations.en` and `translations.ar` |
| `web/dashboard.html` | `translations.en` and `translations.ar` |
| `web/offline.html` | `translations.en` and `translations.ar` |

**Recommended workflow**:

```bash
git checkout develop && git pull
git checkout -b feature/webui-string-x
# Edit all three HTML files
#   → add the EN string to translations.en
#   → add the AR string to translations.ar
#   → verify RTL layout with the toggle
git commit -m "feat(webui): add string X in EN + AR"
git push -u origin feature/webui-string-x
# → Open PR against develop
```

**Checklist for WebUI string PRs**:

- [ ] `translations.en` has the new key.
- [ ] `translations.ar` has the new key.
- [ ] The string renders correctly in English.
- [ ] The string renders correctly in Arabic (RTL).
- [ ] No `console.log` or debug text was left behind.
- [ ] The default language remains English.

### 4.7 Architecture Decision Records (ADRs)

For **non-trivial architectural or process decisions**, propose an ADR
instead of (or alongside) a regular PR.

| When | Where |
|---|---|
| New architectural decision | `docs/adr/` (new file) |
| Reversing a previous decision | `docs/adr/` (new file that supersedes the old one) |
| Simple bug fix | Regular PR (no ADR) |
| Small refactor | Regular PR (no ADR) |
| **v1.2.0**: runtime improvement that does NOT change architecture | Regular PR + SECURITY.md note (no ADR) |
| **v1.2.0**: adding an EN/AR string pair | Regular PR (no ADR) |

**v1.2.0 example**: The 10 data-preservation layers and 4 runtime
additions (BAK-1..BAK-4) did **not** warrant an ADR — they modify
the values and behavior of existing mechanisms (backup, restore,
`runtime_info`) without changing the architecture. See
[`docs/adr/README.md`](adr/README.md) §3.3 for the criteria.

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

### 5.5 Examples for v1.0.0 / v1.1.0 / v1.2.0 Fixes

When fixing similar issues to those addressed in v1.0.0, v1.1.0,
or v1.2.0, follow these patterns:

#### v1.0.0 examples (kept for reference)

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
```

#### v1.1.0 examples (kept for reference)

```bash
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

#### v1.2.0 examples (new)

```bash
# BAK-1 — 7-field backups schema (v1.2.0)
git commit -m "feat(api): extend runtime_info.backups to 7 fields

runtime_info.backups returned 5 fields:
  available, last_backup, last_backup_name, last_stable, path

The status.sh --json tool has always returned 7 fields. This
asymmetry forced API clients to special-case the two endpoints.

Added:
  in_flight_txn  — count of txn-* directories
  orphan_txn     — count of orphan-txn-* directories

The two endpoints now produce identical JSON on the 7 shared
fields. This is an additive change — clients that read only the
original 5 fields continue to work.

Refs: docs/SECURITY.md §5.31
Refs: docs/API.md §6.1.7
Refs: docs/BACKUP.md §8.1
Refs: docs/ARCHITECTURE.md §4.10.1"

# BAK-2 — createAutoBackup + backupMu (v1.2.0)
git commit -m "feat(backup): add pre-critical auto-backup before destructive ops

The 5 user config files (webui.conf, dnscrypt-proxy.toml,
selected_profile.txt, allowlist.txt, denylist.txt) were only
snapshotted at install time. A user who edited their allowlist
after install had no way to roll back a mistake.

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

Serialized by a new sync.Mutex (backupMu) so two rapid user
actions cannot race the backup system into a corrupted snapshot.

Best-effort: a failed backup logs a warning but never blocks
the user's action.

Refs: docs/SECURITY.md §5.31.3
Refs: docs/BACKUP.md §4.3, §12.5
Refs: docs/ARCHITECTURE.md §4.10.2"

# BAK-3 — cleanupOldTransactions() (v1.2.0)
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

# BAK-4 — checkPendingNotifications() (v1.2.0)
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

# FIX-1 — Recovery mode correctness via snapshot-and-reapply (v1.2.0)
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

# FIX-2 — Service Worker update banner (v1.2.0 correctness)
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

# Language — Add an EN/AR string pair (v1.2.0)
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

**Rule for v1.0.0 fixes**: Every "Audit Correction" commit must:
1. Mention the number in the footer: `Audit Correction #XX`.
2. Reference the document: `Refs: docs/SECURITY.md`.
3. Explain **why** (not just what).

**Rule for v1.1.0 runtime improvements**: MEM-1 / MEM-2 / MEM-3 are
**not** audit corrections. Use `Refs: docs/SECURITY.md §5.30.N`
instead of `Audit Correction #XX`.

**Rule for v1.2.0 data-preservation additions**: BAK-1..BAK-4 and
FIX-1 / FIX-2 are **not** audit corrections. Use
`Refs: docs/SECURITY.md §5.31` (for BAK-*) or
`Refs: docs/SECURITY.md §5.32` (for FIX-*) instead of an audit
correction number.

**Rule for WebUI language changes**: Always reference
`docs/ARCHITECTURE.md §6.7` and ensure the commit mentions that
**both** languages were updated.

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

### 5.7 Scope Convention

Use a short, lowercase scope that names the affected area:

| Scope | Meaning |
|---|---|
| `proxy` | `proxy/main.go` |
| `installer` | `proxy/customize.sh`, `proxy/uninstall.sh` |
| `service` | `proxy/service.sh`, `proxy/watchdog.sh` |
| `status` | `proxy/status.sh` |
| `action` | `proxy/action.sh` |
| `functions` | `proxy/functions.sh` |
| `backup` | **(v1.2.0)** anything touching the 10 defensive layers |
| `webui` | `web/index.html` |
| `dashboard` | `web/dashboard.html` |
| `pwa` | `web/manifest.json`, `web/sw.js`, `web/offline.html` |
| `api` | `main.go` HTTP endpoints |
| `auth` | authentication / sessions |
| `ci` | `.github/workflows/` |
| `docs` | `docs/*.md`, `README.md` |
| `adr` | `docs/adr/` |

**Choosing the right scope helps reviewers and `git log --grep`.**

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

# 6. (v1.2.0) Verify the backup shell functions
make check-backup
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
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.3.0?template=release.md
```

See [ADR-0005](adr/0005-release-specific-pr-template.md) for why.

### 6.3 PR Templates

| Template | When to use | Location |
|---|---|---|
| **Default** | `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` → `develop` | `.github/PULL_REQUEST_TEMPLATE.md` |
| **Release** | `release/*`, `hotfix/*` → `main` | `.github/PULL_REQUEST_TEMPLATE/release.md` |

See [`docs/BRANCHING.md`](BRANCHING.md) §5.5 for the release template URL pattern.

**v1.2.0 additions to the default template**:

- New "Data-preservation checklist" section — mandatory for any
  PR that touches:
  - `proxy/customize.sh`
  - `proxy/functions.sh`
  - `proxy/service.sh`
  - `proxy/status.sh`
  - `proxy/uninstall.sh`
  - `proxy/main.go` (backup helpers only)
  - `docs/BACKUP.md`
  - `docs/EMERGENCY.md`
- New "Global edition (English default + Arabic toggle)" checklist
  item — any PR that adds user-facing text must supply both EN and
  AR strings, with English as the default.
- New "Backup shell verification" grep block.
- New "runtime_info.backups" verification.
- New "Test on a real device" checklist for backup/restore cycles.

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
- **v1.2.0**: Changes to the backup layer that do not update
  `docs/BACKUP.md` and `docs/EMERGENCY.md`.
- **v1.2.0**: Adding a user-facing string without the matching
  Arabic entry.

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

**v1.2.0-specific:**
- **`createAutoBackup(reason string)`** — call this before any
  destructive operation on user data. It is best-effort; never
  block the user's action on a backup failure.
- **`backupMu`** — the mutex that serializes pre-critical backups.
  Any new auto-backup call site is automatically covered; do NOT
  add a second mutex.
- **`checkPendingNotifications()`** — called once at startup. If
  you add a new notification producer, write to
  `PENDING_NOTIFY_FILE` and let this function handle it.
- **`cleanupOldTransactions()`** — called once at startup. Any
  change to the transaction cleanup policy must respect the
  preservation of `START`, `ROLLBACK`, and `orphan-txn-*`.
- **`buildBackupInfo()`** — returns **7 fields**. Any change to
  the schema must be matched by an identical change in
  `status.sh --json` (see [`docs/API.md`](API.md) §6.1.7).

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

**v1.2.0-specific:**
- **`PERSISTENT_BACKUP`** — the canonical backup directory path
  (`/sdcard/dnscrypt-webui-backup`). Reference the global; never
  hardcode the path.
- **`USER_FILES`** — the canonical list of the 5 preserved files.
  Any change to this list must be matched in all 5 scripts that
  define it (`customize.sh`, `functions.sh`, `service.sh`,
  `status.sh`, `uninstall.sh`).
- **`copy_with_context(src, dst)`** — use this instead of a bare
  `cp -f` for any user file. It restores the SELinux context and
  sets `chmod 0600` automatically.
- **Rotation sorting** — `rotate_backups` sorts by **directory
  name**, not mtime, for stability across `rsync` copies. Any
  change must preserve this.
- **Transaction state files** — any transaction directory must
  contain a `.state` file with `START`, `COMMIT`, or `ROLLBACK`.
  The `.pid` file is optional but recommended.

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
  to `"unknown"` if missing.

**v1.2.0-specific:**
- **`data.backups`** — new object in `runtime_info` with 7 fields.
  Display the 6 user-facing fields (`available`,
  `last_backup_name`, `last_stable`, `in_flight_txn`, `orphan_txn`,
  `path`) in System Info panels; fall back to "none yet" or
  "not initialized" if missing.
- **Bilingual (EN + AR)** — do **not** add a user-facing string
  without an entry in both `translations.en` and `translations.ar`.
  Both objects must have the same keys.
- **Default language** — always English on first load.
- **Language preference** — persist only in
  `localStorage['dnscrypt-lang']`. Never send it to the server.
- **RTL rules** — any new layout element must respect `[dir="rtl"]`.
- **SW update banner** — when handling the update banner, send
  `SKIP_WAITING` to `swRegistration.waiting` (the NEW worker), not
  to `navigator.serviceWorker.controller`. Reload on the
  `controllerchange` event.

### 7.4 YAML

- `indent`: 2 spaces.
- No tabs.
- Quote strings only when necessary.

### 7.5 Markdown

- `line_length`: 200 characters.
- `MD013`: allowed.
- `MD033`: allowed limited inline HTML.
- Use `-` (dash) for lists (not `*`).

### 7.6 Git Attributes and EditorConfig

Any new file type must be added to:
- `.gitattributes` — if binary or needs specific line endings.
- `.editorconfig` — if it has specific formatting rules.
- `.gitignore` — if it can be generated at build/run time.

See [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) §4.3 for the current
file inventory.

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
| UI | Manual verification in browser |
| CI/CD | Full CI test on GitHub Actions |
| Security fix (Audit) | Static verification via `grep` |
| Firewall change | Manual verification via `iptables -L` |
| **Shell execution** | **Build on Linux + Android** |
| **Auth change** | **Manual rate-limit test** |
| **Endpoint matching** | **`curl` for the endpoint + fake variations** |
| **Concurrency change** | **Manual test: run 2 operations simultaneously** |
| **Runtime info change** | **`curl` `/api?action=runtime_info`** |
| **Memory-limit change (v1.1.0)** | **Test all 5 profiles — see §8.8** |
| **Backup-layer change (v1.2.0)** | **Run all 7 steps of §8.9** |
| **WebUI string change (v1.2.0)** | **Verify both EN and AR render correctly — see §8.11** |

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

# 6. (v1.2.0) runtime_info.backups — 7 fields
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'
# → ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]
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

# MEM-1 — Dynamic memory limit (v1.1.0)
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ MEM-1 (apply)"

# MEM-2 — Extended shellQuote
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2 (braces)"

# MEM-3 — MONITORING_UI_PORT in metrics handler
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

# BAK-1 — 7-field backups schema (v1.2.0)
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ BAK-1 in_flight_txn"
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'orphan_txn' && echo "✅ BAK-1 orphan_txn"

# BAK-2 — createAutoBackup + backupMu (v1.2.0)
grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2 createAutoBackup"
grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 backupMu"

# BAK-3 — cleanupOldTransactions (v1.2.0)
grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"

# BAK-4 — checkPendingNotifications (v1.2.0)
grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"

# Bilingual WebUI (v1.2.0)
for f in web/index.html web/dashboard.html web/offline.html; do
    grep -q 'id="langToggle"' "$f" && echo "✅ $f toggle"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "✅ $f en+ar"
    grep -q "dnscrypt-lang" "$f" && echo "✅ $f localStorage"
    grep -q '\[dir="rtl"\]' "$f" && echo "✅ $f RTL"
done
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
- [ ] Dashboard shows JSON metrics (Fix #1).
- [ ] Basic Auth locked after 5 attempts (Fix #8).
- [ ] 404 for unknown action (Fix #12).
- [ ] Login GET → 405 (NEW-1).
- [ ] `/readyz` from LAN → 403 (NEW-4).
- [ ] `runtime_info` returns ports (PORT-2).
- [ ] BLOCKLIST consistent after concurrent rebuilds (RACE-1).
- [ ] `runtime_info.memory_limit_mb` matches active profile (MEM-1, v1.1.0).
- [ ] `runtime_info.profile_key` matches `selected_profile.txt` (MEM-1, v1.1.0).
- [ ] **(v1.2.0)** `runtime_info.backups` returns 7 fields.
- [ ] **(v1.2.0)** WebUI/Dashboard System Info shows backup state.
- [ ] **(v1.2.0)** Both English (default) and Arabic (toggle) render correctly.
- [ ] **(v1.2.0)** In-place upgrade preserves all 5 files.
- [ ] **(v1.2.0)** Recovery mode restores all 5 files.

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

# 5. (v1.2.0) Backup shell functions
make check-backup

# 6. (v1.2.0) All local validations
make check-all
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
```

**What to look for:**
- ✅ Each profile sets the correct `memory_limit_mb`.
- ✅ `profile_key` matches `selected_profile.txt`.
- ✅ Startup log reports the transition.
- ✅ System Info panel displays both fields.

**Cross-reference (v1.2.0)**: The chosen profile is preserved by the
10 defensive layers (it lives in `selected_profile.txt`, one of the
5 preserved files). If your PR changes the profile list, also check
that the backup layer still restores the new profile correctly.

### 8.9 v1.2.0 — Backup/Restore Testing (new)

If your PR touches **any** of the 10 defensive layers, you **must**
run the following 7-step test on a real device.

**Affected files** (any change here triggers this test):
- `proxy/customize.sh`
- `proxy/functions.sh`
- `proxy/service.sh`
- `proxy/status.sh`
- `proxy/uninstall.sh`
- `proxy/action.sh`
- `proxy/main.go` (backup helpers only)
- `docs/BACKUP.md`
- `docs/EMERGENCY.md`

#### Step 1 — Baseline snapshot

```bash
# 1. Record the current profile
ORIGINAL_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
echo "Original profile: $ORIGINAL_PROFILE"

# 2. Record the current ports
ORIGINAL_PORTS=$(su -c "grep -E '^(PORT|DASHBOARD_PORT)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf")
echo "Original ports:"
echo "$ORIGINAL_PORTS"

# 3. Record the current rules count
ORIGINAL_RULES=$(su -c "wc -l < /data/adb/modules/dnscrypt-proxy-webui/proxy/allowlist.txt")
echo "Original allowlist lines: $ORIGINAL_RULES"

# 4. Take a manual backup via CLI
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

#### Step 2 — Verify the snapshot was created

```bash
# List the backup directory
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# Check the newest snapshot
SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')
echo "Newest snapshot: $SNAP"

# Verify it contains the 5 files + manifest
su -c "ls -la $SNAP"
su -c "cat $SNAP/.manifest.json | jq"
```

**Expected**:
- ✅ 5 files (`webui.conf`, `dnscrypt-proxy.toml`,
  `selected_profile.txt`, `allowlist.txt`, `denylist.txt`).
- ✅ `.manifest.json` with SHA256 per file.
- ✅ All file modes `0600`.

#### Step 3 — Simulate a data-loss scenario

```bash
# 1. Delete the 5 files from the module directory
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "rm -f /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"

# 2. Verify they are gone
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf 2>&1"
# Expected: No such file or directory

# 3. Trigger recovery mode
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"
```

#### Step 4 — Verify recovery restored the files

```bash
# Wait for boot
sleep 60

# 1. Verify the 5 files are back
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"

# 2. Verify the profile is the original one
RECOVERED_PROFILE=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
[ "$RECOVERED_PROFILE" = "$ORIGINAL_PROFILE" ] && echo "✅ Profile restored" || echo "❌ Profile mismatch"

# 3. Verify the ports are the original ones
su -c "grep -E '^(PORT|DASHBOARD_PORT)=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 4. Verify the trigger file is gone
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
# Expected: No such file or directory
```

#### Step 5 — Verify the runtime_info state

```bash
# 1. Service status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# 2. runtime_info.backups — 7 fields
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

# 3. Verify the two sources agree (main.go vs status.sh)
diff <(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups'") \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff
```

#### Step 6 — Verify the diagnose tool

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**Expected output includes**:
- ✅ System Information
- ✅ Module Information
- ✅ Service Status
- ✅ Recovery & Notifications
- ✅ User Data Files (all 5 present)
- ✅ Backups (with count and latest)
- ✅ Health Checks
- ✅ Diagnosis (✅ All systems operational)

#### Step 7 — Verify rotation

```bash
# Create more than 21 snapshots (test only)
for i in $(seq 1 25); do
    su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup" >/dev/null 2>&1
    sleep 1
done

# Count snapshots
su -c "ls -1d /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | wc -l"

# Expected: 21 (rotation keeps at most 21)
```

**Cleanup after testing**:

```bash
# Restore the original number of snapshots (if desired)
# Simply let the next rotation handle it, or manually delete extras:
su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | \
       tail -n +22 | xargs -r rm -rf"
```

### 8.10 v1.2.0 — Testing the `upgrade-test.yml` Matrix (new)

The `.github/workflows/upgrade-test.yml` file defines a
**42-scenario matrix** (3 root solutions × 2 source versions ×
7 scenarios) that runs on-demand and on a schedule. This section
explains how to reproduce it locally.

**Matrix definition**:

| Dimension | Values |
|---|---|
| Root solution | Magisk, KernelSU, APatch |
| Source version | v1.0.0, v1.1.0 |
| Scenario | fresh-install, in-place-upgrade, rename-folder, reinstall-after-uninstall, recovery-mode, interrupted-install, custom-ports |

**Total**: 3 × 2 × 7 = **42 combinations**.

**Running locally** (Linux/macOS dev machine):

```bash
# 1. Pull the workflow definition
cat .github/workflows/upgrade-test.yml

# 2. Trigger it via GitHub CLI
gh workflow run upgrade-test.yml

# 3. Watch the run
gh run list --workflow=upgrade-test.yml --limit 1
gh run watch

# 4. Read the results
gh run view
```

**Triggering manually from GitHub UI**:
1. Open the **Actions** tab.
2. Select **Upgrade Test**.
3. Click **Run workflow**.
4. Choose the branch (usually `develop`).
5. Click the green **Run workflow** button.

**When to trigger**:
- ✅ Before any release.
- ✅ After any change to the 10 defensive layers.
- ✅ After any change to `upgrade-test.yml` itself.
- ✅ Weekly (the workflow has a `schedule:` trigger).

**Emulation limitation**: The matrix runs in a container, not on a
real device. It cannot fully emulate:
- SELinux contexts (`restorecon` / `chcon` are stubbed).
- The Magisk/KernelSU/APatch module folder lifecycle.
- Real FUSE mount behavior on `/sdcard/`.

For the FULL test, use a real device — see §8.9.

### 8.11 v1.2.0 — Bilingual WebUI Testing (new)

If your PR touches any **user-facing string** in the WebUI, or the
language toggle mechanism itself, you must verify both languages.

**Affected files**:
- `web/index.html`
- `web/dashboard.html`
- `web/offline.html`
- `web/manifest.json` (if `lang`/`dir` defaults change)

#### Step 1 — Static verification

```bash
# Verify both language objects exist in all three pages
for f in web/index.html web/dashboard.html web/offline.html; do
    echo "=== $f ==="
    grep -q 'en:' "$f" && echo "  ✅ en:" || echo "  ❌ en: missing"
    grep -q 'ar:' "$f" && echo "  ✅ ar:" || echo "  ❌ ar: missing"
    grep -q 'id="langToggle"' "$f" && echo "  ✅ toggle" || echo "  ❌ toggle missing"
    grep -q "dnscrypt-lang" "$f" && echo "  ✅ localStorage key" || echo "  ❌ localStorage key missing"
    grep -q '\[dir="rtl"\]' "$f" && echo "  ✅ RTL rules" || echo "  ❌ RTL rules missing"
done
```

#### Step 2 — Browser matrix

Test on the following browsers (at minimum):

| Browser | Default EN | Toggle to AR | RTL layout | Preference persists |
|---|:---:|:---:|:---:|:---:|
| Chrome 88+ | [ ] | [ ] | [ ] | [ ] |
| Firefox 92+ | [ ] | [ ] | [ ] | [ ] |
| Samsung Internet 16+ | [ ] | [ ] | [ ] | [ ] |

#### Step 3 — First-load default check

```bash
# 1. Clear the localStorage key
#    (browser DevTools console)
localStorage.removeItem('dnscrypt-lang');

# 2. Reload the page
# → Verify the page loads in ENGLISH.
```

#### Step 4 — Toggle and persistence check

```bash
# 1. Click the langToggle button in the header
# → Verify the page switches to ARABIC.
# → Verify the layout is RTL (right-to-left).

# 2. Reload the page
# → Verify the page STILL shows Arabic (preference persisted).

# 3. Verify localStorage (browser DevTools console)
localStorage.getItem('dnscrypt-lang')  // → "ar"
```

#### Step 5 — Both directions

```bash
# 1. Click the langToggle button again (from AR to EN)
# → Verify the page switches back to ENGLISH.
# → Verify the layout is LTR (left-to-right).

# 2. Reload the page
# → Verify the page STILL shows English.
```

#### Step 6 — No server impact

```bash
# 1. Open the browser DevTools → Network tab.

# 2. Click the langToggle button.
# → Verify NO new network request is made.

# 3. Verify the API is language-neutral:
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
# → The response does NOT contain a "lang" or "language" field.
```

#### What to look for

- ✅ English is always the default on first load (after clearing
  `localStorage`).
- ✅ The toggle switches both ways (EN → AR → EN).
- ✅ The layout flips correctly (LTR ↔ RTL).
- ✅ The preference persists across page reloads.
- ✅ No new network requests are made when toggling.
- ✅ The API responses are identical regardless of language.

**If a new string is missing in one language**:
- The `t()` helper falls back to the raw key name.
- This should be caught before merge — see the static check in
  Step 1.

### 8.12 Pre-PR Checklist (v1.2.0)

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

# 5. Backup shell functions
make check-backup

# 6. All local validations
make check-all

# 7. Bilingual WebUI check (only if web/*.html changed)
for f in web/index.html web/dashboard.html web/offline.html; do
    grep -q 'id="langToggle"' "$f" && echo "✅ $f toggle"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "✅ $f en+ar"
done
```

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
| **RACE fix** | `docs/SECURITY.md` + `docs/ARCHITECTURE.md` |
| **PORT fix** | `docs/SECURITY.md` + `docs/API.md` + `docs/ARCHITECTURE.md` |
| **Branch/release policy** | `docs/BRANCHING.md` + `docs/RELEASE_PROCESS.md` |
| **Architectural decision** | `docs/adr/` (new ADR) |
| **Memory-limit change (v1.1.0)** | `docs/SECURITY.md` §5.30.1 + `docs/ARCHITECTURE.md` §3.9 + `docs/COMPATIBILITY.md` §5.4 + `docs/API.md` §2.1 |
| **New runtime_info field (v1.1.0)** | `docs/API.md` §6.1.7 + `docs/ARCHITECTURE.md` §16.7 + `web/index.html` + `web/dashboard.html` |
| **Upgrade path change (v1.1.0)** | `docs/UPGRADE.md` (add a §3.X section) |
| **Backup layer change (v1.2.0)** | `docs/BACKUP.md` + `docs/EMERGENCY.md` + `docs/SECURITY.md` §5.31 + `docs/ARCHITECTURE.md` §3.10, §4.10 |
| **Recovery mode change (v1.2.0)** | `docs/EMERGENCY.md` + `docs/SECURITY.md` §5.32 + `docs/ARCHITECTURE.md` §3.10 |
| **runtime_info.backups schema change (v1.2.0)** | `docs/API.md` §6.1.7 + `docs/ARCHITECTURE.md` §4.10.1 + `web/index.html` + `web/dashboard.html` + `status.sh` (keep both in sync) |
| **Rotation policy change (v1.2.0)** | `docs/BACKUP.md` §6 + the rotation constant in 4 scripts |
| **WebUI language toggle change (v1.2.0)** | `docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8 + `CODE_OF_CONDUCT.md` §FAQ Q9 + all three HTML files |

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
- **v1.2.0**: All documentation is English-only. Community
  translations are welcome as separate files
  (`docs/*.<lang>.md`) — see §1.4.
- **v1.2.0**: The WebUI itself is bilingual (English default +
  Arabic toggle), but this does not affect the documentation
  convention.

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

### 9.5 v1.2.0 — Backup Documentation Pattern (new)

For any change that touches the 10 defensive layers, use this
pattern. It is the same structure as §9.4 but with the v1.2.0
sections:

```markdown
<a name="531"></a>
### 5.31 — Data Preservation Security Model (v1.2.0)

**Background**:
[why the previous mechanism failed / was insufficient]

**The 10 defensive layers**:

| # | Layer | File(s) | Role |
|:-:|---|---|---|
| 1 | Multi-source detection | `customize.sh` | ... |
| ... | ... | ... | ... |

**Security rationale**:

| Concern | v1.2.0 mitigation |
|---|---|
| ... | ... |

*(Reference: docs/SECURITY.md §5.31; docs/BACKUP.md §1.3)*
```

**Companion documents** — any change to `docs/SECURITY.md` §5.31
must be mirrored in:
- `docs/BACKUP.md` (the runtime reference).
- `docs/EMERGENCY.md` (the recovery procedures).
- `docs/ARCHITECTURE.md` §3.10 (the flow diagram).

### 9.6 v1.2.0 — WebUI Language Documentation Pattern (new)

Any change that adds or modifies user-facing strings in the WebUI
must document both languages. Use this pattern in PR descriptions
and, if the change is significant, in the corresponding docs:

```markdown
### Change: <string-key> — v1.2.0

**English (default)**:
> <English text>

**Arabic**:
> <Arabic text>

**Files updated**:
- [ ] `web/index.html` — `translations.en` + `translations.ar`
- [ ] `web/dashboard.html` — `translations.en` + `translations.ar`
- [ ] `web/offline.html` — `translations.en` + `translations.ar`

**RTL verification**:
- [ ] Tested in Chrome 88+ (RTL layout correct)
- [ ] Tested in Firefox 92+ (RTL layout correct)
- [ ] Tested in Samsung Internet 16+ (RTL layout correct)

**Default on first load**: English

**Preference persistence**: `localStorage['dnscrypt-lang']`

**API impact**: None (the API is language-neutral).
```

### 9.7 v1.1.0 Runtime Improvement Pattern

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

The same pattern applies for the v1.2.0 additions, using `BAK-N`
identifiers instead of `MEM-N` and `§5.31` / `§17.2` instead of
`§5.30` / `§17.1`.

### 9.8 ADR Documentation Pattern

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
./scripts/release.sh v1.3.0

# PATCH-only (from main)
./scripts/release-patch.sh v1.2.1
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
v1.1.0        ← second stable (polish)
v1.2.0        ← third stable (current — data preservation)
v1.2.1        ← next patch (hotfix) if needed
v1.3.0        ← next minor (feature)
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
| v1.2.0 | 1020000 |
| v1.2.1 | 1020001 |
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
- [ ] **v1.2.0**: `make check-backup` passes.
- [ ] **v1.2.0**: The 10 defensive layers have not regressed (see §8.9).
- [ ] **v1.2.0**: The bilingual WebUI is intact in all three HTML files (see §8.11).
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
./scripts/release-patch.sh v1.2.1

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
upgrading between versions (including the full
`v1.0.0 → v1.1.0 → v1.2.0` path).

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
- [ ] Read `docs/BACKUP.md` — for backup/restore questions (v1.2.0).
- [ ] Read `docs/EMERGENCY.md` — for recovery scenarios (v1.2.0).
- [ ] Read `docs/adr/README.md` — for architectural decisions.
- [ ] Search existing Issues.
- [ ] Try the latest version.

### 11.3 A Good Question

Should include:
- Module version (`v1.2.0`).
- Android version and device.
- Clear reproduction steps.
- Attached logs.
- Dashboard state (see `docs/TROUBLESHOOTING.md`).
- `runtime_info` output (with `profile_key` + `memory_limit_mb`).
- **v1.2.0**: `runtime_info.backups` output (7 fields).
- **v1.2.0**: `status.sh --diagnose` output.
- **v1.2.0**: If the issue is about the language toggle, browser
  version + a screenshot in both English and Arabic.
- Steps already attempted.

### 11.4 v1.2.0 Debug Information

When reporting an issue, attach:

```bash
# 1. Basic info
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" > status.json

# 2. iptables state
su -c "iptables -t nat -L DNSCRYPT_OUT -n" > firewall.txt
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'" >> firewall.txt

# 3. Dashboard state
su -c "curl -s http://127.0.0.1:9091/api/metrics" > metrics.json

# 4. Runtime Info (PORT-2 + MEM-1 + BAK-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" > runtime_info.json

# 5. Memory profile (v1.1.0+)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'" >> memory.json

# 6. Backup state (v1.2.0)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'" > backups.json
su -c "ls -la /sdcard/dnscrypt-webui-backup/" >> backups.json 2>&1
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable" >> backups.json 2>&1
su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.json" >> backups.json 2>&1

# 7. Bilingual WebUI state (v1.2.0)
for f in /data/adb/modules/dnscrypt-proxy-webui/web/index.html \
         /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html \
         /data/adb/modules/dnscrypt-proxy-webui/web/offline.html; do
    echo "=== $f ==="
    grep -q 'id="langToggle"' "$f" && echo "toggle present"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "en+ar present"
done > webui_lang.txt

# 8. Full diagnostic report (v1.2.0)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" > diagnose.txt

# 9. Logs
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
| Translator | Complete translation (documentation only, or a full EN/AR WebUI string set) |
| Compatibility Champ | 3+ tested devices |
| UI/UX | Design improvements |
| Auditor | New Audit Correction |
| Platform Fixer | Platform-agnostic fixes (Linux/macOS/Android) |
| Metrics Wizard | Improvements in metrics/Dashboard |
| Concurrency Guardian | RACE-1 fixes (mutex/concurrency) — **v1.2.0: also covers `backupMu`** |
| Port Architect | PORT-2 fixes (dynamic ports) |
| Decision Architect | Proposing an accepted ADR |
| **Memory Architect (v1.1.0)** | **Test dynamic memory limit across RAM tiers + report GC behavior** |
| **Data Guardian (v1.2.0)** | **Test the backup/restore system across devices, root solutions, and upgrade scenarios** |

**Detailed conditions**: see [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md).

**v1.2.0 note on Concurrency Guardian**: The badge now recognizes
contributions to **both** the `rebuildMu` mutex (v1.0.0) and the
`backupMu` mutex (v1.2.0). If you fix or improve either, you can
qualify.

**v1.2.0 note on Data Guardian**: To earn this badge, follow the
testing procedure in §8.9 and report your findings. See
[`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) for the acceptance
criteria.

**v1.2.0 note on Translator**: With the bilingual WebUI (English
default + Arabic toggle), the Translator badge recognizes:

- Complete documentation translation (`docs/*.<lang>.md`).
- **OR** a significant contribution to the WebUI's `translations.ar`
  object (e.g. adding many new keys with correct Arabic strings and
  RTL verification).

### 12.3 Contributors Image

https://contrib.rocks/image?repo=gasciljh/dnscrypt-proxy-webui

---

## 13. v1.2.0 — Contributors Reference

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
>
> **22.** **(v1.2.0)** Never remove a user data file without a
> backup. Any destructive operation on user data must call
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

### 13.2 Branch Policy Reminder

| Situation | Branch | PR target | Template |
|---|---|---|---|
| New feature | `feature/*` | `develop` | Default |
| Non-critical fix | `fix/*` | `develop` | Default |
| Documentation | `docs/*` | `develop` | Default |
| Maintenance | `chore/*` | `develop` | Default |
| Refactor | `refactor/*` | `develop` | Default |
| Tests | `test/*` | `develop` | Default |
| WebUI string change (EN + AR) | `feature/*` or `fix/*` | `develop` | Default |
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
      `buildRuntimeInfo()`, `web/index.html`, and
      `web/dashboard.html`.
- [ ] **(v1.1.0)** If adding a new port or changing
      `MONITORING_UI_PORT`: update the constant, `customize.sh`,
      `functions.sh`, and `docs/API.md` §1.2.
- [ ] **(v1.2.0)** If adding a new destructive operation on user
      data: call `createAutoBackup(reason)` first, and document
      the new reason in `docs/BACKUP.md` §4.3.
- [ ] **(v1.2.0)** If adding a new preserved file: update the
      `USER_FILES` list in **all 5** scripts (`customize.sh`,
      `functions.sh`, `service.sh`, `status.sh`, `uninstall.sh`),
      the "5 Preserved Files" table in `README.md`, and
      `docs/BACKUP.md` §2.
- [ ] **(v1.2.0)** If adding a new config migration: add it to
      `migrate_config()` in `customize.sh` and document it in
      `docs/UPGRADE.md`.
- [ ] **(v1.2.0)** If changing the rotation policy: update the
      constant in **all 4** scripts (`customize.sh`,
      `functions.sh`, `service.sh`, `action.sh`) and
      `docs/BACKUP.md` §6.
- [ ] **(v1.2.0)** If adding a user-facing string: update
      `translations.en` **and** `translations.ar` in all three
      HTML files (`index.html`, `dashboard.html`, `offline.html`).
- [ ] **(v1.2.0)** If touching the language toggle: verify RTL
      layout in Chrome 88+, Firefox 92+, and Samsung Internet 16+.

### 13.4 When Fixing a Bug

- [ ] Verify with `make build`.
- [ ] Add `Audit Correction` in the commit footer (if security-related).
- [ ] Update `docs/SECURITY.md` (if security).
- [ ] Update `docs/TROUBLESHOOTING.md` (if a common issue).
- [ ] Add HTML anchor `<a name="XXX"></a>` (if a new section).
- [ ] If the fix is concurrency-related → add `defer rebuildMu.Unlock()`.
- [ ] If the fix is port-related → verify `runtime_info` output.
- [ ] If the fix is memory-limit-related (v1.1.0) → test all 5 profiles.
- [ ] **(v1.2.0)** If the fix is backup-related → run §8.9 in full.
- [ ] **(v1.2.0)** If the fix is recovery-mode-related → verify
      the `§[8a] → §[9] → §[9b2]` snapshot-and-reapply flow in
      `customize.sh` still preserves all 5 files.
- [ ] **(v1.2.0)** If the fix touches a user-facing string → verify
      both English and Arabic render correctly (§8.11).
- [ ] Target `develop` in your PR.

### 13.5 When Publishing a Release

- [ ] For **Stable/Prerelease** → use `./scripts/release.sh vX.Y.Z` from `develop`.
- [ ] For **PATCH-only** → use `./scripts/release-patch.sh vX.Y.Z` from `main`.
- [ ] Use the release PR template (`?template=release.md`).
- [ ] After PATCH release → run `make sync`.
- [ ] **(v1.2.0)** Run `make check-backup` before tagging.
- [ ] **(v1.2.0)** Verify the `upgrade-test.yml` matrix is green
      (see §8.10).
- [ ] **(v1.2.0)** Verify the bilingual WebUI is intact
      (§8.11, Step 1).
- [ ] See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for the full flow.

### 13.6 Quick References

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

### 13.7 Full References

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture + Trade-offs + §3.10, §4.10, §6.7 |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry + §5.31, §5.32 |
| [`docs/API.md`](API.md) | HTTP API Reference + §6.1.7, §10.8 |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting (§7.8–§7.11 for backups) |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix + §5.5 |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide (§3.0, §3.1) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/FAQ.md`](FAQ.md) | Common questions (Q121–Q130 = v1.2.0) |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (v1.0.0 + v1.1.0 + v1.2.0) |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary (BAK/MEM terms) |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition (Data Guardian) |
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

**Last updated**: 2026-10-02
**Version**: v1.3.0
**Author**: gasciljh