# Contributing to DNSCrypt Smart Filter

Thank you for your interest in contributing! This guide explains how
to contribute effectively.

**Version**: v1.4.0
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (7 total)**:
>   • HARD-CON-01 (`Last updated` correction — v1.4.0)
>   • HARD-CON-02 (v1.3.0 block extended with server-side
>     refinements — v1.4.0)
>   • HARD-CON-03 (§7.2 Shell rotation-sorting text corrected —
>     v1.4.0)
>   • HARD-CON-04 (§7.3 JavaScript v1.3.0 block updated for the
>     v1.4.0 `<a download>` change — v1.4.0)
>   • HARD-CON-05 (§8.14 rotation invariants added — v1.4.0)
>   • HARD-CON-06 (§13.3 checklist extended with v1.3.0 rotation
>     rows — v1.4.0)
>   • HARD-CON-07 (header + footer sync — v1.4.0)
>
> **Cross-references**:
>   • [docs/BRANCHING.md](BRANCHING.md) — Git workflow
>   • [docs/RELEASE_PROCESS.md](RELEASE_PROCESS.md) — release guide
>   • [docs/adr/README.md](adr/README.md) — ADR index
>   • [docs/UPGRADE.md](UPGRADE.md) — version upgrade guide
>   • [docs/BACKUP.md](BACKUP.md) — backup system reference
>   • [docs/EMERGENCY.md](EMERGENCY.md) — emergency recovery
>   • [docs/ARCHITECTURE.md §4.13](ARCHITECTURE.md) — v1.3.0
>     server-side refinements (authoritative)
>   • [docs/COMPATIBILITY.md §10.3.5](COMPATIBILITY.md) — on-device
>     SNAP-*/ROT-* verification
>   • [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) — contributors
>   • [CHANGELOG.md](../CHANGELOG.md) — version history

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date
>     (2026-10-08).
>   • **Companion Android app integration** — the module ZIP may
>     now include `web/app-debug.apk`. The WebUI install button
>     is a direct `<a download>` link (no `beforeinstallprompt`).
>   • **CodeQL `go/path-injection` closed** in `removeModule` via
>     `filepath.Base()` + `filepath.Join()` sanitization.
>   • **iOS PWA logic removed** — Android-only project.
>   • New section **§8.15 — Companion App Testing (v1.4.0)**.
>   • New section **§4.8 — Companion App String/Script Contribution**.
>   • §5.5 gained 2 new commit examples: `feat(app): bundle
>     companion APK` and `fix(api): close CodeQL path-injection in
>     removeModule`.
>   • §10 release examples updated from `v1.3.0` to `v1.4.0`
>     (stable) and `v1.4.1` (PATCH), since v1.4.0 is now the
>     current release.
>   • §12.2 Badges gained **Companion App Tester (v1.4.0)**.
>   • §13.1 Golden Rules gained **Rule #24** — companion APK
>     safety requirement.
>   • §13.3/§13.4 checklists extended with v1.4.0 runtime
>     additions and fix patterns.
>   • Global edition — English-only documentation; WebUI remains
>     bilingual (English default + Arabic toggle).

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • **Client-side changes** (WebUI):
>       - Smart dynamic PWA install button that adapts to the
>         browser: native `beforeinstallprompt` dialog on
>         Chromium-based browsers, or a friendly unsupported-
>         browser modal with Play Store links for Chrome/Edge/Brave.
>         (This chain was later **replaced in v1.4.0** with a
>         direct `<a download>` link — see the v1.4.0 block.)
>       - Live status LED on the Today counter — pulses green
>         when the DNS engine is running, solid red when stopped.
>   • **Boot-path fix** (`service.sh §[19]`): DNS auto-start after
>     boot via a direct API call. Root cause: `watchdog.sh` waits
>     30 s before its first API call, by which time the WebUI may
>     not have finished binding. Fix: `service.sh` performs a
>     bounded wait for the WebUI ready state (up to 60 s,
>     watchdog token + TCP port), then calls
>     `POST /api/ensure_running_service` itself.
>   • **Server-side refinements to the backup layer** — the
>     v1.3.0 release ALSO refined the snapshot-detection and
>     rotation semantics that underpin the persistent backup
>     directory. Three identifiers document the change (also
>     used in `CHANGELOG.md` [v1.3.0] and
>     `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by the presence of a
>         `.manifest.json` file, not by the v1.2.0 name pattern
>         (`^[0-9]{8}-[0-9]{6}-`).
>
>       🔧 **SNAP-MTIME** — `last_backup_name` is now selected
>         by **mtime** (descending), with a name-based fallback.
>         This supersedes the v1.2.0 BUG-3 lexicographic-name
>         rule.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with the
>         same manifest-based detection, the same mtime sort,
>         and two additional protected targets on top of the
>         21-newest window:
>           • the `.last_stable` recovery pointer;
>           • the newest install snapshot (name matching
>             `-v<digit>`).
>
>   • **Parallel application** — the same SNAP-* / ROT-*
>     semantics were applied to `watchdog.sh` (§[5b] snapshot
>     counter), `status.sh` (`_list_snapshots`),
>     `customize.sh` (`rotate_backups`), `action.sh`
>     (`_inline_list_snapshots` + `_inline_rotate_backups` +
>     `_inline_backup_summary`), and `uninstall.sh` (§[5b]
>     `BACKUP_COUNT` / `BACKUP_LAST_NAME`).
>   • No new audit corrections.
>   • No breaking changes.

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
>   • **§8.11 (new)** — Bilingual WebUI testing.
>   • §9.1 (When to Update Documentation) gained rows for
>     backup/restore, recovery mode, `runtime_info.backups`, and
>     the WebUI language toggle.
>   • **§9.5 (new)** — v1.2.0 Backup documentation pattern.
>   • **§9.6 (new)** — WebUI language documentation pattern.
>   • §12.2 (Badges) gained **Data Guardian** (v1.2.0).
>   • §13.1 (Golden Rules) gained **Rule #22** — backup
>     observability requirement — and **Rule #23** — bilingual
>     WebUI string requirement.
>   • §13.3/§13.4 checklists extended.
>   • §13.6/§13.7 references extended.

> **v1.4.0 — Corrections in this revision**:
>   • 🔧 **HARD-CON-01** — `Last updated` corrected. The header
>     and footer previously said `2026-10-06` (the v1.4.0
>     release date, not the v1.4.0 file-editing date). Both now
>     read `2026-10-08`, matching every other file in the v1.4.0
>     module.
>   • 🔧 **HARD-CON-02** — `v1.3.0` block extended. It previously
>     listed only the client-side changes (PWA install button,
>     live status LED) and the boot-path fix, but **omitted**
>     the server-side rotation refinements (SNAP-MANIFEST,
>     SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) that
>     touched 8 files in v1.3.0. The block above now documents
>     them, and explains why no branching-strategy change was
>     required.
>   • 🔧 **HARD-CON-03** — §7.2 (Shell Standards) corrected.
>     The v1.2.0-specific bullet on rotation sorting said
>     "sort by directory name, not mtime" — this was the
>     v1.2.0 behavior, and it was **reversed in v1.3.0**. The
>     bullet now states the v1.3.0 semantics (manifest-based
>     detection + mtime sort + protected targets) and points at
>     `docs/ARCHITECTURE.md` §4.13.2.
>   • 🔧 **HARD-CON-04** — §7.3 (JavaScript Standards) v1.3.0
>     block updated. The PWA install button is no longer a
>     `beforeinstallprompt` chain — it was replaced by a direct
>     `<a href="/app-debug.apk" download>` link in v1.4.0. The
>     section now reflects the v1.4.0 reality and cross-refers
>     to the v1.4.0-specific bullet.
>   • 🟡 **HARD-CON-05** — §8.14 (Backup Debugging) extended
>     with the v1.3.0 rotation invariants (SNAP-MANIFEST,
>     SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) and a
>     reference to `docs/COMPATIBILITY.md` §10.3.5 for on-device
>     verification.
>   • 🟡 **HARD-CON-06** — §13.3 (When Adding a New Feature)
>     checklist extended with rows for the v1.3.0 rotation
>     refinements.
>   • 🟢 **HARD-CON-07** — Header and footer `Last updated`
>     synchronized.

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
13. [v1.4.0 — Contributors Reference](#13-v140--contributors-reference)

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

The WebUI ships with:

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
  RU, ZH, ...) are deferred to **v1.5.0** — see
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
| **Rotation-semantics verification (v1.3.0)** | **Verify SNAP-*/ROT-* on device — see §8.14 and `docs/COMPATIBILITY.md` §10.3.5** |
| **Companion app testing (v1.4.0)** | **Verify the APK bundles correctly and installs — see §8.15 and §12.2** |

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
- **v1.3.0**: Rotation-semantics verification reports (SNAP-*/ROT-*
  on real devices — see §8.14).
- **v1.4.0**: Companion app testing reports (see §8.15).

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
- **v1.3.0**: Changing the rotation semantics without keeping
  `main.go`, `functions.sh`, and the 5 mirroring shell scripts in
  sync (see `docs/ARCHITECTURE.md` §4.13.2).
- **v1.4.0**: Changing the APK fetch/stage logic without updating
  `scripts/fetch_app_apk.sh`, `proxy/app-apk.version`, and the
  release workflow in lockstep.

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
| **curl** or **wget** | — | Download DNS binaries + companion APK | Yes |
| **zip/unzip** | — | Packaging | Yes |

"Recommended" means "not required for local development, but required
for full CI".

**v1.2.0 note**: No new tools were added for the data-preservation
release. The 10 defensive layers use only tools already present in
the dev environment.

**v1.3.0 note**: The rotation refinements (SNAP-*/ROT-*) do not
introduce any new tool. They rely on `stat`, `sort`, and `awk`,
which are already required.

**v1.4.0 note**: The companion APK fetcher (`scripts/fetch_app_apk.sh`)
uses `curl` and `sha256sum` (already required). No new tool was
introduced.

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

# Expected: v1.4.0

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
| **v1.3.0**: PWA install button + live status LED | Regular PR (no ADR) |
| **v1.3.0**: server-side rotation refinements (SNAP-*/ROT-*) | Regular PR (no ADR — functional change to existing mechanisms) |
| **v1.4.0**: companion APK integration | Regular PR (no ADR — the file shape is additive) |

**v1.2.0 example**: The 10 data-preservation layers and 4 runtime
additions (BAK-1..BAK-4) did **not** warrant an ADR — they modify
the values and behavior of existing mechanisms without changing the
architecture.

**v1.3.0 example**: The rotation refinements (SNAP-MANIFEST,
SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) are **functional
changes** to existing mechanisms. They are documented in
`CHANGELOG.md` §[v1.3.0] and `docs/ARCHITECTURE.md` §4.13 — not in
an ADR.

**v1.4.0 example**: The companion APK is an **additive** asset — it
does not change the module architecture, the API contract, or the
install pipeline. It is documented in `docs/ARCHITECTURE.md`,
`docs/API.md`, and `README.md`, not in an ADR.

**Full guide**: [`docs/adr/README.md`](adr/README.md) §3 and §7.

**Current ADRs**: 6 (see [`docs/adr/README.md`](adr/README.md) §6).

### 4.8 Companion App String/Script Contribution

The companion Android app lives in a **separate repository**
([`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)).

**In this repository**, changes related to the companion app are
limited to:

| File | Role | Change policy |
|---|---|---|
| `proxy/app-apk.version` | Single Source of Truth for the APK version | Manual bump when the companion repo releases a new APK |
| `scripts/fetch_app_apk.sh` | Fetches the APK at release time | Changes require a matching change in the release workflow |
| `.github/workflows/release.yml` | Stages the APK into the module ZIP | Any change here must be verified with a dry-run |
| `web/index.html` | Install button (`<a download>`) | Keep the link stable across releases |

**Rules**:

- ❌ Do **not** commit `web/app-debug.apk` — it is a build artifact
  (see `.gitignore` §[20]).
- ✅ Do commit updates to `proxy/app-apk.version` (a new version).
- ✅ Do update `scripts/fetch_app_apk.sh` if the companion repo's
  asset naming changes.
- ❌ Do **not** modify the companion app's Kotlin/Android code in
  this repository — open a PR in the companion repo instead.

**Companion app version vs module version**:

| Version | Source | Example |
|---|---|---|
| Module version | `VERSION` | `v1.4.0` |
| Companion app version | `proxy/app-apk.version` | `1.0.0` (no `v` prefix) |
| Upstream DNS engine version | `proxy/dnscrypt-proxy.version` | `2.1.18` |

These three versions are **independent**. A module release does not
require a companion app release, and vice versa.

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

### 5.5 Examples for v1.0.0 / v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0 Fixes

When fixing similar issues to those addressed in earlier releases,
follow these patterns.

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

#### v1.2.0 examples (kept for reference)

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
fields. This is an additive change.

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

# FIX-1 — Recovery-mode correctness via snapshot-and-reapply (v1.2.0)
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

#### v1.3.0 examples

```bash
# PWA install button + live status LED (v1.3.0)
git commit -m "feat(webui): add PWA install button and live status LED

PWA install button:
  - Always visible (except when already installed / standalone).
  - Chromium-based: opens the native beforeinstallprompt dialog.
  - Unsupported browsers: friendly modal with Play Store links
    for Chrome / Edge / Brave.

Live status LED:
  - 12x12 LED on the Today counter.
  - Pulses green when the DNS engine is running.
  - Solid red when the service is stopped.

NOTE: the beforeinstallprompt chain was replaced in v1.4.0 by
a direct <a download> link.

Refs: docs/ARCHITECTURE.md §6.4
Refs: CHANGELOG.md §[v1.3.0]"

# service.sh — DNS auto-start after boot (v1.3.0 critical fix)
git commit -m "fix(service): ensure DNS starts after boot

Root cause: watchdog.sh waits a fixed 30s before its first API
call. By the time it fires POST /api/ensure_running_service, the
WebUI may not have finished binding to its port. The watchdog
retries with exponential backoff, leaving DNS unavailable for
minutes after boot.

Fix: service.sh now performs a direct, bounded wait for the WebUI
to become ready (up to 60s, checking the watchdog token file +
the WebUI TCP port), then calls POST /api/ensure_running_service
itself.

Verified on-device: DNS engine reaches ON within 5s of service.sh
startup, with 3 processes running (webui + proxy + watchdog).

Refs: service.sh §[19]
Refs: CHANGELOG.md §[v1.3.0] → Fixed"

# Rotation refinements (v1.3.0 server-side)
git commit -m "refactor(backup): use SNAP-MANIFEST + ROT-MTIME for rotation

Rewrote snapshot detection and rotation across 8 files:

  main.go:buildBackupInfo
    - SNAP-MANIFEST: detect snapshots by .manifest.json presence
      (not by name pattern).
    - SNAP-MTIME: sort by mtime descending for last_backup_name.

  functions.sh:rotate_backups
    - ROT-MANIFEST: same detection rule.
    - ROT-MTIME: same sort order.
    - ROT-PROTECT: preserve .last_stable + newest install
      snapshot on top of the 21-newest window.

  Mirrored in 5 shell scripts:
    - watchdog.sh §[5b] snapshot counter
    - status.sh _list_snapshots
    - customize.sh rotate_backups
    - action.sh _inline_list_snapshots + _inline_rotate_backups
    - uninstall.sh §[5b] BACKUP_COUNT / BACKUP_LAST_NAME

Refs: docs/ARCHITECTURE.md §4.13.2
Refs: CHANGELOG.md §[v1.3.0]"
```

#### v1.4.0 examples

```bash
# Companion APK bundle (v1.4.0)
git commit -m "feat(app): bundle companion Android app in module ZIP

Added an OPTIONAL companion app asset to the module ZIP:

  - proxy/app-apk.version       — Single Source of Truth (1.0.0)
  - scripts/fetch_app_apk.sh    — fetcher (cache + SHA256 + JSON)
  - GET /app-debug.apk          — new static route in main.go
  - web/index.html              — install button uses <a download>
  - .github/workflows/release.yml — fetch + stage APK steps
  - .github/workflows/ci.yml      — verify companion app metadata
  - scripts/package_module.sh     — optional APK bundling

The APK is best-effort: a missing APK is a warning, not a failure,
so local developer builds work without a network fetch.

Refs: docs/ARCHITECTURE.md
Refs: docs/API.md §1.3
Refs: CHANGELOG.md §[v1.4.0]"

# CodeQL path-injection fix (v1.4.0)
git commit -m "fix(api): close CodeQL path-injection in removeModule

Two alerts (go/path-injection #1, #2) closed by routing the
caller-provided path through filepath.Base() and rebuilding the
final path from the trusted MODULES_DIR constant + the sanitized
basename.

Before: os.RemoveAll(modulePath)
After:  name := filepath.Base(modulePath)
        cleanPath := filepath.Join(MODULES_DIR, name)
        os.RemoveAll(cleanPath)

Defence-in-depth prefix check kept as a second layer.

Refs: docs/SECURITY.md
Refs: CHANGELOG.md §[v1.4.0] → Fixed"

# iOS PWA removal (v1.4.0)
git commit -m "refactor(webui): remove iOS PWA logic (Android-only)

The project is Android-only. Removed ~35 lines of iOS-specific
logic from web/index.html:

  - isIOSDevice() helper
  - pwaStepIos1/2/3 translations (EN + AR)
  - iOS branches in getBrowserName(), isBrowserSupported(),
    getPWAInstallSteps(), showPWAInstructionsModal()

Browsers that never fire beforeinstallprompt (Firefox, legacy
Samsung Internet) now fall through to the unified unsupported
modal that lists Chrome / Edge / Brave with Play Store links.

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
  relevant `docs/ARCHITECTURE.md` section (§4.13 for server-side
  refinements, §6.4 for client-side features).
- **v1.4.0 features**: Reference `CHANGELOG.md §[v1.4.0]`,
  `docs/ARCHITECTURE.md`, and `docs/API.md`.
- **WebUI language changes**: Always mention **both** languages
  were updated.

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
| `backup` | (v1.2.0+) anything touching the 10 defensive layers or the v1.3.0 rotation semantics |
| `app` | **(v1.4.0)** companion APK integration |
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

# 7. (v1.4.0) Verify companion app metadata
make check-app-version
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
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.5.0?template=release.md
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
  PR that touches the 10 defensive layers.
- New "Global edition (English default + Arabic toggle)" checklist
  item — any PR that adds user-facing text must supply both EN and
  AR strings, with English as the default.
- New "Backup shell verification" grep block.
- New "runtime_info.backups" verification.
- New "Test on a real device" checklist for backup/restore cycles.

**v1.3.0 additions**:

- New "Rotation-semantics checklist" — mandatory for any PR that
  touches `buildBackupInfo`, `rotate_backups`, or their 5 mirrored
  implementations.
- Verification that SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST,
  ROT-MTIME, and ROT-PROTECT remain in sync across
  `main.go`, `functions.sh`, and the 5 shell scripts.

**v1.4.0 additions**:

- Companion app checklist — verify `proxy/app-apk.version` format
  and `scripts/fetch_app_apk.sh` presence (`make check-app-version`).
- CI is expected to run the `Verify companion app metadata` smoke
  test.

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
- **v1.3.0**: Changes to the rotation semantics that do not keep
  `main.go`, `functions.sh`, and the 5 mirroring scripts in sync.
- **v1.4.0**: Committing `web/app-debug.apk` to git (it is a build
  artifact and must remain in `.gitignore`).
- **v1.4.0**: Changing the APK fetch logic without updating
  `scripts/fetch_app_apk.sh`, `proxy/app-apk.version`, and the
  release workflow in lockstep.

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
- `hasEndpoint()` — any new endpoint must use it.
- `parsePrometheus` + `buildDashboardJSON` — for new metrics.
- `isPortOpenCached(port)` — with per-port map.
- Rate limiting — any new auth must record in `loginAttempts`.
- `shellQuote()` — for any dynamic path in a shell command.
- `readConfPort` — for any port read from config.
- `rebuildMu` — for any operation touching `rebuildBlocklist` (RACE-1).
- `runtime_info` — for any endpoint needing actual ports (PORT-2).
- `sync.Once` — for one-time initialization (shell detection).

**v1.1.0-specific:**
- `memoryLimitForProfile(key string) int64` — any new profile
  must be added here.
- `applyMemoryLimit(key string)` — call this only from `main()`
  and `updateProfile()`.
- `MEMORY_LIMIT_*` constants — any new profile needs a constant.
- `readSelectedProfile()` — use it whenever you need the active
  profile; do NOT read `selected_profile.txt` directly elsewhere.
- `MONITORING_UI_PORT` — always reference the constant; never
  hardcode `"8080"` again.
- `memLimitMu` — access `currentMemLimit` / `currentProfile`
  only while holding this mutex.

**v1.2.0-specific:**
- `createAutoBackup(reason string)` — call this before any
  destructive operation on user data.
- `backupMu` — the mutex that serializes pre-critical backups.
- `checkPendingNotifications()` — called once at startup.
- `cleanupOldTransactions()` — called once at startup.
- `buildBackupInfo()` — returns **7 fields**. Any change to the
  schema must be matched by an identical change in
  `status.sh --json`.

**v1.3.0-specific:**
- `buildBackupInfo()` — snapshot detection is **manifest-based**
  (SNAP-MANIFEST), not name-pattern-based. `last_backup_name` is
  chosen by mtime (SNAP-MTIME). Do NOT revert to name-based
  detection or lexicographic sort.
- Any change to `buildBackupInfo` must be mirrored in
  `functions.sh:rotate_backups` and the 5 shell scripts that
  implement the same semantics.

**v1.4.0-specific:**
- `APK_FILE` — the constant pointing to `web/app-debug.apk`. Use
  it for any new route; do not hardcode the filename.
- `serveStaticAssets` — new static routes must go through this
  helper so the security headers + per-extension Cache-Control
  are applied consistently.
- `removeModule` — any change to the path handling must keep the
  `filepath.Base()` + `filepath.Join()` sanitization to keep the
  CodeQL path-injection alerts closed.

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
- `getSystemShell()` — for shell commands (safe fallback).

**v1.1.0-specific:**
- `get_profile_memory_hint()` — read-only helper; use it for
  user-facing display in `service.sh`, `action.sh`, `status.sh`.
- `_inline_get_profile_memory_hint()` — inline fallback in each
  of the four scripts when `functions.sh` is unavailable.
- `SELECTED_PROFILE_FILE` — use the global; do NOT hardcode
  `$MODDIR/proxy/selected_profile.txt` elsewhere.

**v1.2.0-specific:**
- `PERSISTENT_BACKUP` — the canonical backup directory path
  (`/sdcard/dnscrypt-webui-backup`). Reference the global; never
  hardcode the path.
- `USER_FILES` — the canonical list of the 5 preserved files.
  Any change to this list must be matched in all 5 scripts that
  define it.
- `copy_with_context(src, dst)` — use this instead of a bare
  `cp -f` for any user file.
- Transaction state files — any transaction directory must contain
  a `.state` file with `START`, `COMMIT`, or `ROLLBACK`.

**v1.3.0-specific:**
- **Rotation sorting** — `rotate_backups` now sorts candidates by
  **mtime** (`sort -rn -k1,1`), not by directory name. This
  reverses the v1.2.0 behavior. Robust against clock drift and
  manual renames. See `docs/ARCHITECTURE.md` §4.13.2.
- **Snapshot detection** — a directory is treated as a snapshot
  iff it contains a `.manifest.json` file (SNAP-MANIFEST /
  ROT-MANIFEST), not by matching the name pattern
  `^[0-9]{8}-[0-9]{6}-`.
- **Protected rotation targets** — `rotate_backups` preserves
  two additional targets on top of the 21-newest window:
  the `.last_stable` target (recovery pointer) and the newest
  install snapshot (name matching `-v<digit>`). See ROT-PROTECT
  in `docs/ARCHITECTURE.md` §4.13.2.
- `service.sh §[19]` — the DNS auto-start fix. Any change to the
  startup flow must preserve the bounded wait + direct API call.
- The `WATCHDOG_TOKEN_FILE` guard in `service.sh §[19]` must
  remain in place (it allows the script to run even if
  `functions.sh` failed to load).

**v1.4.0-specific:**
- `scripts/fetch_app_apk.sh` — the APK fetcher. Changes must
  preserve the cache-first + SHA256 + JSON output behavior.
- `proxy/app-apk.version` — the Single Source of Truth for the
  APK version. Do NOT read the version from anywhere else.
- Release workflow — any change to the APK fetch/stage steps must
  be verified with a full dry-run of `release.yml`.

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
- `data.profile_key` and `data.memory_limit_mb` — new fields in
  `runtime_info`. Display them in System Info panels; fall back
  to `"unknown"` if missing.

**v1.2.0-specific:**
- `data.backups` — new object in `runtime_info` with 7 fields.
  Display the 6 user-facing fields in System Info panels; fall
  back to "none yet" or "not initialized" if missing.
- Bilingual (EN + AR) — do **not** add a user-facing string
  without an entry in both `translations.en` and `translations.ar`.
- Default language — always English on first load.
- Language preference — persist only in
  `localStorage['dnscrypt-lang']`. Never send it to the server.
- RTL rules — any new layout element must respect `[dir="rtl"]`.
- SW update banner — when handling the update banner, send
  `SKIP_WAITING` to `swRegistration.waiting` (the NEW worker).

**v1.3.0-specific:**
- The `langToggle` header button must remain in the top-right
  corner (LTR) / top-left (RTL).
- Live status LED — the LED is bound to `currentStatus`. Any
  change to the status flow must keep the LED in sync (see
  `updateStatsDisplay()`).
- ⚠️ The v1.3.0 PWA install button used a smart dynamic chain
  with `beforeinstallprompt`. **This chain was removed in v1.4.0**
  in favour of a direct `<a download>` link — see the
  v1.4.0-specific block below for the current behavior.

**v1.4.0-specific:**
- **Install button** — the `pwaInstallBtn` element is now an
  `<a href="/app-debug.apk" download>` link. Do **not** reintroduce
  a JavaScript click handler or a `beforeinstallprompt` listener
  for installation.
- **iOS detection removed** — `isIOSDevice()`, `pwaStepIos1/2/3`,
  and all iOS branches have been removed. The project is
  Android-only. If you need to re-add iOS support, open an Issue
  first.
- **Unsupported-browser fallback** — the modal still exists for
  browsers that never fire `beforeinstallprompt`. Keep the Play
  Store link building logic as-is.
- **Caching** — the install button does not require Service Worker
  involvement; `web/app-debug.apk` is served by `main.go` with a
  long-lived `Cache-Control` header (see `docs/ARCHITECTURE.md`
  §6.2 and §4.12.1).

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

**v1.3.0 note**: `proxy/run/.watchdog_token` and any
`.manifest.json` file inside `/sdcard/dnscrypt-webui-backup/`
never appear in the repository — they live on the device.

**v1.4.0 note**: `web/app-debug.apk` and `proxy/app-apk.version`
are already covered:
- `web/app-debug.apk` — in `.gitignore` §[20].
- `proxy/app-apk.version` — enforced `text eol=lf` in
  `.gitattributes`.

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
| Shell execution | Build on Linux + Android |
| Auth change | Manual rate-limit test |
| Endpoint matching | `curl` for the endpoint + fake variations |
| Concurrency change | Manual test: run 2 operations simultaneously |
| Runtime info change | `curl` `/api?action=runtime_info` |
| Memory-limit change (v1.1.0) | Test all 5 profiles — see §8.8 |
| Backup-layer change (v1.2.0) | Run all 7 steps of §8.9 |
| WebUI string change (v1.2.0) | Verify both EN and AR render correctly — see §8.11 |
| **PWA install button change (v1.3.0 → v1.4.0)** | **Verify the download link works — see §8.11 and §8.15** |
| **DNS auto-start change (v1.3.0)** | **Test with a fresh reboot — see §8.9 / §8.13** |
| **Rotation semantics change (v1.3.0)** | **Verify SNAP-*/ROT-* on-device — see §8.14** |
| **Companion APK change (v1.4.0)** | **Run `make check-app-version` and the release dry-run — see §8.15** |

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

# 7. (v1.4.0) companion APK route
curl -sI http://127.0.0.1:9090/app-debug.apk | grep -i content-type
# → application/vnd.android.package-archive (or 404 if the APK is absent)
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

# SNAP-MANIFEST + SNAP-MTIME (v1.3.0)
grep -A40 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
grep -A40 'func buildBackupInfo' proxy/main.go | grep -q 'ModTime().Before' && echo "✅ SNAP-MTIME"

# ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (v1.3.0)
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q '_d/.manifest.json' && echo "✅ ROT-MANIFEST"
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q '_last_stable\|_protected' && echo "✅ ROT-PROTECT"

# Bilingual WebUI (v1.2.0)
for f in web/index.html web/dashboard.html web/offline.html; do
    grep -q 'id="langToggle"' "$f" && echo "✅ $f toggle"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "✅ $f en+ar"
    grep -q "dnscrypt-lang" "$f" && echo "✅ $f localStorage"
    grep -q '\[dir="rtl"\]' "$f" && echo "✅ $f RTL"
done

# Direct download link (v1.4.0)
grep -q 'href="/app-debug.apk"' web/index.html && echo "✅ direct download link"
grep -q 'download="DNS-Proxy.apk"' web/index.html && echo "✅ download attribute"
grep -q 'led-on\|led-off' web/index.html && echo "✅ status LED"

# DNS auto-start fix (v1.3.0)
grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ service.sh fix"
grep -q 'ensure_running_service' proxy/service.sh && echo "✅ direct API call"

# Companion APK (v1.4.0)
grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
grep -q '/app-debug.apk' proxy/main.go && echo "✅ APK route"
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ CodeQL fix"
test -f scripts/fetch_app_apk.sh && echo "✅ APK fetcher"
test -f proxy/app-apk.version && echo "✅ APK version file"
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
- [ ] `runtime_info.backups` returns 7 fields (v1.2.0).
- [ ] WebUI/Dashboard System Info shows backup state (v1.2.0).
- [ ] Both English (default) and Arabic (toggle) render correctly (v1.2.0).
- [ ] In-place upgrade preserves all 5 files (v1.2.0).
- [ ] Recovery mode restores all 5 files (v1.2.0).
- [ ] Snapshot detection is manifest-based (SNAP-MANIFEST, v1.3.0).
- [ ] Rotation preserves `.last_stable` + newest install (ROT-PROTECT, v1.3.0).
- [ ] DNS auto-starts within ~5 s of boot (v1.3.0).
- [ ] Direct download link works (`<a download>`, v1.4.0).
- [ ] Companion APK download works when the file is present (v1.4.0).
- [ ] Companion APK route returns 404 when the file is absent (v1.4.0).

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

# 7. (v1.4.0) Companion app metadata
make check-app-version
```

### 8.8 v1.1.0 — Memory-Limit Testing

If your PR touches the memory-limit logic (`main.go`,
`functions.sh`, `service.sh`, `action.sh`, `status.sh`,
`watchdog.sh`), you **must** test all 5 profiles:

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
5 preserved files).

**Cross-reference (v1.3.0)**: The `selected_profile.txt` file is
one of the 5 preserved files. Its preservation is unchanged by the
rotation refinements.

**Cross-reference (v1.4.0)**: The companion APK is independent of the
memory limit — its presence or absence does not affect the WebUI
process's memory profile.

### 8.9 v1.2.0 — Backup/Restore Testing

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
# Manually delete extra snapshots if desired:
su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
       grep -vE '/(current|txn-|orphan-txn-)' | \
       tail -n +22 | xargs -r rm -rf"
```

### 8.10 v1.2.0 — Testing the `upgrade-test.yml` Matrix

The `.github/workflows/upgrade-test.yml` file defines a
**42-scenario matrix** that validates the 9 tested data-preservation
layers (Layer 10 — Observability — is not exercised by this
workflow; see the file's header for details).

**Matrix definition**:

| Layer | Scenarios | Count |
|---|:---:|:---:|
| Layer 1 — Multi-source detection | L1-01 .. L1-10 | 10 |
| Layer 2 — Persistent backup | L2-01 .. L2-07 | 7 |
| Layer 3 — Integrity (SHA256) | L3-01 .. L3-05 | 5 |
| Layer 4 — Transactional upgrades | L4-01 .. L4-07 | 7 |
| Layer 5 — Root-solution compat | L5-01 .. L5-03 | 3 |
| Layer 6 — SELinux preservation | L6-01 .. L6-02 | 2 |
| Layer 7 — Recovery mode | L7-01 .. L7-03 | 3 |
| Layer 8 — Config migrations | L8-01 .. L8-02 | 2 |
| Layer 9 — Automation + rotation | L9-01 .. L9-03 | 3 |
| **Total** | | **42** |

**v1.3.0 update**: L9-02 and L9-03 were updated to write
`.manifest.json` files into each synthetic snapshot directory, so
that the v1.3.0 SNAP-MANIFEST detection rule sees them.

**Running locally**:

```bash
# 1. Trigger it via GitHub CLI
gh workflow run upgrade-test.yml

# 2. Watch the run
gh run list --workflow=upgrade-test.yml --limit 1
gh run watch

# 3. Read the results
gh run view
```

**When to trigger**:
- ✅ Before any release.
- ✅ After any change to the 10 defensive layers.
- ✅ After any change to `upgrade-test.yml` itself.
- ✅ After any change to the v1.3.0 rotation semantics.
- ✅ Weekly / monthly, as a regression sweep (manual only).

**Emulation limitation**: The matrix runs in a container, not on a
real device. It cannot fully emulate SELinux contexts, the
Magisk/KernelSU/APatch module folder lifecycle, or real FUSE mount
behavior on `/sdcard/`.

For the FULL test, use a real device — see §8.9.

### 8.11 v1.2.0 + v1.3.0 + v1.4.0 — WebUI Testing

If your PR touches any **user-facing string** in the WebUI, or the
install button, or the live status LED, verify both languages and
the relevant browser families.

**Affected files**:
- `web/index.html`
- `web/dashboard.html`
- `web/offline.html`
- `web/manifest.json` (if `lang`/`dir` defaults change)

#### Static verification

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

#### Browser matrix (v1.2.0+)

| Browser | Default EN | Toggle to AR | RTL layout | Preference persists |
|---|:---:|:---:|:---:|:---:|
| Chrome 88+ | [ ] | [ ] | [ ] | [ ] |
| Firefox 92+ | [ ] | [ ] | [ ] | [ ] |
| Samsung Internet 16+ | [ ] | [ ] | [ ] | [ ] |

#### First-load default check

```bash
# 1. Clear the localStorage key (browser DevTools console)
localStorage.removeItem('dnscrypt-lang');

# 2. Reload the page
# → Verify the page loads in ENGLISH.
```

#### Toggle and persistence check

```bash
# 1. Click the langToggle button in the header
# → Verify the page switches to ARABIC and the layout is RTL.

# 2. Reload the page
# → Verify the page STILL shows Arabic (preference persisted).

# 3. Verify localStorage (browser DevTools console)
localStorage.getItem('dnscrypt-lang')  // → "ar"
```

#### No server impact

```bash
# 1. Open DevTools → Network tab.
# 2. Click langToggle.
# → Verify NO new network request is made.

# 3. Verify the API is language-neutral:
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
# → The response does NOT contain a "lang" or "language" field.
```

#### Install button (v1.4.0 — direct download)

```bash
# 1. Chromium-based browser (Chrome / Edge / Brave)
# 2. Firefox
# 3. Samsung Internet
#    → In ALL browsers, verify:
#      a. The install button is visible.
#      b. Clicking it starts a direct download of
#         `DNS-Proxy.apk`.
#      → NO modal, NO beforeinstallprompt dependency.

# 4. If the APK is absent (developer build without a network fetch)
#    → Verify the click leads to a 404 (browser "file not found")
#      and the rest of the WebUI continues to work normally.
```

#### Live status LED (v1.3.0)

```bash
# 1. Start the service
#    → Verify the LED pulses green.
# 2. Stop the service
#    → Verify the LED turns solid red.
```

#### DNS auto-start after boot (v1.3.0)

```bash
# 1. Ensure the service is ON
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# 2. Reboot
su -c "reboot"

# 3. After boot completes, check
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: DNS=UP

# 4. Check the log for the fix marker
su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log | tail -3"
# Expected: 2-3 lines describing the WebUI wait + API call
```

### 8.12 Pre-PR Checklist (v1.4.0)

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

# 7. Companion app metadata
make check-app-version

# 8. Bilingual WebUI check (only if web/*.html changed)
for f in web/index.html web/dashboard.html web/offline.html; do
    grep -q 'id="langToggle"' "$f" && echo "✅ $f toggle"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "✅ $f en+ar"
done

# 9. Rotation-semantics check (only if backup code changed)
grep -A40 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q '_d/.manifest.json' && echo "✅ ROT-MANIFEST"
```

### 8.13 v1.3.0 — DNS Auto-Start Testing

If your PR touches the boot flow (`service.sh`, `watchdog.sh`, or
`main.go`'s service lifecycle), you must verify the v1.3.0 DNS
auto-start fix still works.

```bash
# 1. Set the user intent to ON (start the service)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"
sleep 5
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: DNS=UP

# 2. Reboot without changing the intent
su -c "reboot"

# 3. After boot, wait ~30s and check
sleep 30
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: DNS=UP (started automatically by service.sh)

# 4. Check the log for the [v1.3.0 FIX] markers
su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log"
# Expected:
#   🔧 [v1.3.0 FIX] Ensuring DNS starts after boot...
#   ✅ WebUI ready after Ns
#   Calling ensure_running_service API...
#   ✅ [v1.3.0 FIX] DNS start requested successfully
```

**What to look for**:
- ✅ DNS engine is running within ~5 s of service.sh startup.
- ✅ Log markers appear in order.
- ✅ The watchdog does **not** need to intervene (its backoff
  remains at 30 s).
- ✅ If the user intent is OFF, service.sh skips the auto-start.

### 8.14 v1.2.0 + v1.3.0 — Backup Debugging

```bash
# 1. Verify the layer functions are present
for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
         begin_transaction rollback_transaction commit_transaction \
         detect_root_solution copy_with_context RECOVERY_TRIGGER \
         migrate_config; do
    grep -q "$L" proxy/customize.sh && echo "✅ $L" || echo "❌ $L"
done

# 2. Verify the backup helpers in functions.sh
for H in auto_backup_if_needed rotate_backups backup_user_files \
         restore_user_files cleanup_old_transactions \
         get_backup_dir ensure_backup_dir get_last_backup_time \
         copy_with_context verify_backup_integrity write_manifest; do
    grep -q "$H" proxy/functions.sh && echo "✅ $H" || echo "❌ $H"
done

# 3. Verify the runtime_info.backups schema
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'
# Expected: ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

# 4. Verify the two sources agree
diff <(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups') \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff

# 5. (v1.3.0) Verify the rotation invariants across all consumers
#    SNAP-MANIFEST: detect snapshots by .manifest.json presence
grep -A40 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' \
    && echo "✅ main.go SNAP-MANIFEST"
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q '_d/.manifest.json' \
    && echo "✅ functions.sh ROT-MANIFEST"
grep -A60 '_inline_rotate_backups()' proxy/service.sh | grep -q '_d/.manifest.json' \
    && echo "✅ service.sh ROT-MANIFEST (inline)"
grep -A60 '_list_snapshots()' proxy/status.sh | grep -q '_d/.manifest.json' \
    && echo "✅ status.sh SNAP-MANIFEST"
grep -A60 'rotate_backups()' proxy/customize.sh | grep -q '_d/.manifest.json' \
    && echo "✅ customize.sh ROT-MANIFEST"
grep -A60 '_inline_list_snapshots()' proxy/action.sh | grep -q '_d/.manifest.json' \
    && echo "✅ action.sh ROT-MANIFEST (inline)"
grep -A60 '_uninstall_list_snapshots()' proxy/uninstall.sh | grep -q '_d/.manifest.json' \
    && echo "✅ uninstall.sh SNAP-MANIFEST"

# 6. (v1.3.0) Verify mtime sort (ROT-MTIME / SNAP-MTIME)
grep -A40 'func buildBackupInfo' proxy/main.go | grep -q 'ModTime().Before' \
    && echo "✅ main.go SNAP-MTIME"
grep -A60 'rotate_backups()' proxy/functions.sh | grep -q 'sort -rn -k1,1' \
    && echo "✅ functions.sh ROT-MTIME"

# 7. (v1.3.0) Verify protected targets (ROT-PROTECT)
grep -A80 'rotate_backups()' proxy/functions.sh | grep -q '_last_stable\|_protected' \
    && echo "✅ functions.sh ROT-PROTECT"

# 8. (v1.3.0) On-device SNAP-*/ROT-* verification
#    See docs/COMPATIBILITY.md §10.3.5 for the full procedure.
```

### 8.15 v1.4.0 — Companion App Testing

If your PR touches the companion APK integration, run all checks.

**Affected files**:
- `proxy/app-apk.version`
- `scripts/fetch_app_apk.sh`
- `proxy/main.go` (the `APK_FILE` constant + the
  `serveStaticAssets` entry)
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`
- `scripts/package_module.sh`
- `web/index.html` (the install button)
- `README.md` (the "Optional Android App" section)

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
```

#### Local fetcher test

```bash
# 1. Clear any cached APK
rm -rf ~/.cache/dnscrypt-proxy-webui/app
rm -rf dist/DNS-Proxy-*.apk dist/DNS-Proxy-*.apk.sha256

# 2. Run the fetcher
./scripts/fetch_app_apk.sh --output-dir ./dist --verbose
# Expected: downloads, verifies SHA256, writes .sha256 sidecar

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

#### Release dry-run test

```bash
# 1. Verify the release workflow can stage the APK
gh workflow run release.yml --ref develop
# (Or, for a local check, run the equivalent steps manually.)

# 2. Watch the run
gh run list --workflow=release.yml --limit 1
gh run watch
```

**What to look for**:
- ✅ The APK version file matches the companion repo's latest release.
- ✅ The fetcher downloads and verifies the APK correctly.
- ✅ The route serves the correct mime type + Cache-Control.
- ✅ The install button starts the download.
- ✅ A missing APK produces a warning (not a failure) in the
  release pipeline.
- ✅ `web/app-debug.apk` is **not** committed to git.

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
| Behavioral change | `docs/API.md` + `docs/ARCHITECTURE.md` |
| Shell fix | `docs/TROUBLESHOOTING.md` + `docs/DEVELOPMENT.md` |
| CI change | `docs/DEVELOPMENT.md` + `CHANGELOG.md` |
| Concurrency change | `docs/ARCHITECTURE.md` (Concurrency section) |
| Ports change | `docs/API.md` (runtime_info) + `docs/ARCHITECTURE.md` |
| RACE fix | `docs/SECURITY.md` + `docs/ARCHITECTURE.md` |
| PORT fix | `docs/SECURITY.md` + `docs/API.md` + `docs/ARCHITECTURE.md` |
| Branch/release policy | `docs/BRANCHING.md` + `docs/RELEASE_PROCESS.md` |
| Architectural decision | `docs/adr/` (new ADR) |
| Memory-limit change (v1.1.0) | `docs/SECURITY.md` §5.30.1 + `docs/ARCHITECTURE.md` §3.9 + `docs/COMPATIBILITY.md` §5.4 + `docs/API.md` §2.1 |
| New runtime_info field (v1.1.0) | `docs/API.md` §6.1.7 + `docs/ARCHITECTURE.md` §16.7 + `web/index.html` + `web/dashboard.html` |
| Upgrade path change (v1.1.0) | `docs/UPGRADE.md` (add a §3.X section) |
| Backup layer change (v1.2.0) | `docs/BACKUP.md` + `docs/EMERGENCY.md` + `docs/SECURITY.md` §5.31 + `docs/ARCHITECTURE.md` §3.10, §4.10 |
| Recovery mode change (v1.2.0) | `docs/EMERGENCY.md` + `docs/SECURITY.md` §5.32 + `docs/ARCHITECTURE.md` §3.10 |
| runtime_info.backups schema change (v1.2.0) | `docs/API.md` §6.1.7 + `docs/ARCHITECTURE.md` §4.10.1 + `web/index.html` + `web/dashboard.html` + `status.sh` (keep both in sync) |
| Rotation policy change (v1.2.0) | `docs/BACKUP.md` §6 + the rotation constant in 4 scripts |
| WebUI language toggle change (v1.2.0) | `docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8 + `CODE_OF_CONDUCT.md` §FAQ Q9 + all three HTML files |
| **Rotation semantics change (v1.3.0)** | **`docs/ARCHITECTURE.md` §4.13.2 + `docs/BACKUP.md` §6 + all 8 files that mirror the semantics + `CHANGELOG.md` §[v1.3.0]** |
| **Snapshot detection change (v1.3.0)** | **`docs/ARCHITECTURE.md` §4.13.1 + `docs/API.md` §6.1.7 + `manifest.json` x-note-backup-schema + `CHANGELOG.md` §[v1.3.0]** |
| **DNS auto-start change (v1.3.0)** | **`docs/ARCHITECTURE.md` §3.3, §9.3 + `docs/TROUBLESHOOTING.md` + `CHANGELOG.md` §[v1.3.0] + `service.sh` header** |
| **Companion APK integration (v1.4.0)** | **`docs/ARCHITECTURE.md` + `docs/API.md` §1.3 + `README.md` + `CHANGELOG.md` §[v1.4.0]** |
| **CodeQL path-injection fix (v1.4.0)** | **`docs/SECURITY.md` + `CHANGELOG.md` §[v1.4.0]** |
| **iOS PWA removal (v1.4.0)** | **`docs/ARCHITECTURE.md` §6.4 + `CHANGELOG.md` §[v1.4.0]** |

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
- All documentation is English-only. Community translations are
  welcome as separate files (`docs/*.<lang>.md`) — see §1.4.
- The WebUI itself is bilingual (English default + Arabic toggle),
  but this does not affect the documentation convention.

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

**Anchor pattern** (important for `docs/SECURITY.md`):

```markdown
<a name="5XX"></a>
### 5.XX — Title — v1.0.0
```

### 9.5 v1.2.0 — Backup Documentation Pattern

For any change that touches the 10 defensive layers, use this
pattern:

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

### 9.6 v1.2.0 — WebUI Language Documentation Pattern

Any change that adds or modifies user-facing strings in the WebUI
must document both languages.

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
pattern — they are **not** audit corrections:

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
identifiers instead of `MEM-N`.

### 9.8 v1.3.0 / v1.4.0 Feature Documentation Pattern

For feature releases (like v1.3.0's rotation refinements and v1.4.0's
companion app), use this pattern:

```markdown
### <Feature Name> — v1.4.0

**Purpose**: [one-sentence summary]

**Added files**:
- [ ] `<path>` — <role>

**Changed files**:
- [ ] `<path>` — <what changed>

**How it works**: [short description + diagram if helpful]

**Compatibility**: [breaking / additive / internal]

**Testing**: [reference §8.X]

**References**:
- `CHANGELOG.md` §[v1.4.0]
- `docs/ARCHITECTURE.md` §<section>
```

### 9.9 ADR Documentation Pattern

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
./scripts/release.sh v1.5.0

# PATCH-only (from main)
./scripts/release-patch.sh v1.4.1
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
2. Fetches the companion APK (v1.4.0+) and stages it for the ZIP.
3. Packages the Magisk ZIP.
4. Creates the GitHub Release.
5. Auto-syncs `main → develop`.

**Total time**: ~5-10 minutes.

### 10.2 SemVer

```text
v<MAJOR>.<MINOR>.<PATCH>[-prerelease]

v1.0.0        ← first stable release
v1.1.0        ← second stable (polish)
v1.2.0        ← third stable (data preservation)
v1.3.0        ← fourth stable (PWA + boot fix + rotation refinements)
v1.4.0        ← fifth stable (current — companion app)
v1.4.1        ← next patch (hotfix) if needed
v1.5.0        ← next minor (feature)
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
| v1.3.0 | 1030000 |
| v1.4.0 | 1040000 |
| v1.4.1 | 1040001 |
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
- [ ] `make check-backup` passes.
- [ ] `make check-app-version` passes (v1.4.0+).
- [ ] The 10 defensive layers have not regressed (see §8.9).
- [ ] The v1.3.0 rotation semantics are intact (see §8.14, Step 5).
- [ ] The bilingual WebUI is intact in all three HTML files (see §8.11).
- [ ] The install button works as a direct download (v1.4.0+, see §8.11).
- [ ] The live status LED works (v1.3.0+).
- [ ] The DNS auto-start fix still works (v1.3.0+, see §8.13).
- [ ] The companion APK integration is intact (v1.4.0+, see §8.15).
- [ ] `./scripts/release.sh vX.Y.Z --dry-run` shows the expected result.
- [ ] `./scripts/release.sh vX.Y.Z` executed.
- [ ] GitHub Actions run succeeds.
- [ ] Release is published with all artifacts.
- [ ] `develop` is synced with `main`.
- [ ] `update.json` reflects the new version.

### 10.5 PATCH Releases (Hotfix)

For PATCH-only releases, use `scripts/release-patch.sh`:

```bash
# 1. From main
git checkout main
git pull origin main

# 2. Prepare the PATCH release
./scripts/release-patch.sh v1.4.1

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
- GitHub Actions pipeline (16 steps, plus the v1.4.0 APK steps).
- Post-release verification.
- Rollback procedures.
- Manual release fallback.
- Back-merge after hotfixes.

**Upgrade guide**: [`docs/UPGRADE.md`](UPGRADE.md) — for users
upgrading between versions.

### 10.7 Companion App Release Integration (v1.4.0)

The companion APK is published from a **separate repository**
([`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)).
The release pipeline in **this** repository does **not** build the
APK — it only **fetches** it.

**The fetch flow**:

1. `release.yml` runs the `Fetch companion Android app APK` step,
   which calls `scripts/fetch_app_apk.sh`.
2. The script reads `proxy/app-apk.version` to determine which
   APK version to download.
3. The APK is placed in `dist/DNS-Proxy-v<version>.apk`.
4. The `Stage APK for module ZIP` step copies it to
   `web/app-debug.apk`.
5. `scripts/package_module.sh` bundles it into the ZIP
   (best-effort: a missing APK is a warning, not an error).

**Best-effort semantics**:

| Stage | If APK is missing |
|---|---|
| `scripts/fetch_app_apk.sh` | exits non-zero; the workflow logs `::warning::` |
| `release.yml` Fetch step | logs `::warning::`, release continues |
| `release.yml` Stage step | logs `::warning::`, packaging continues |
| `scripts/package_module.sh` | logs warning, ZIP built without APK |
| `proxy/main.go` route | returns 404 for `/app-debug.apk` |
| WebUI install button | click leads to 404 (browser "file not found") |

**When to bump `proxy/app-apk.version`**:

- When the companion repo publishes a **new APK release**.
- Not on every module release.

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
- [ ] Read `docs/BACKUP.md` — for backup/restore questions.
- [ ] Read `docs/EMERGENCY.md` — for recovery scenarios.
- [ ] Read `docs/adr/README.md` — for architectural decisions.
- [ ] Read `docs/COMPATIBILITY.md` §10.3.5 — for SNAP-*/ROT-*
  verification.
- [ ] Search existing Issues.
- [ ] Try the latest version.

### 11.3 A Good Question

Should include:
- Module version (`v1.4.0`).
- Android version and device.
- Clear reproduction steps.
- Attached logs.
- Dashboard state (see `docs/TROUBLESHOOTING.md`).
- `runtime_info` output (with `profile_key` + `memory_limit_mb`).
- `runtime_info.backups` output (7 fields).
- `status.sh --diagnose` output.
- If the issue is about the language toggle, browser version +
  a screenshot in both English and Arabic.
- If the issue is about rotation, `ls -la /sdcard/dnscrypt-webui-backup/`
  output.
- If the issue is about the companion APK, whether the APK was
  present in the module ZIP.
- Steps already attempted.

### 11.4 Debug Information

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

# 5. Memory profile
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'" >> memory.json

# 6. Backup state
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'" > backups.json
su -c "ls -la /sdcard/dnscrypt-webui-backup/" >> backups.json 2>&1
su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable" >> backups.json 2>&1
su -c "cat /sdcard/dnscrypt-webui-backup/.upgrade_history.json" >> backups.json 2>&1

# 6b. (v1.3.0) Rotation-state snapshot
su -c "ls -la /sdcard/dnscrypt-webui-backup/ | head -30" > rotation.txt
su -c "find /sdcard/dnscrypt-webui-backup -maxdepth 2 -name '.manifest.json' | wc -l" >> rotation.txt

# 7. Bilingual WebUI state
for f in /data/adb/modules/dnscrypt-proxy-webui/web/index.html \
         /data/adb/modules/dnscrypt-proxy-webui/web/dashboard.html \
         /data/adb/modules/dnscrypt-proxy-webui/web/offline.html; do
    echo "=== $f ==="
    grep -q 'id="langToggle"' "$f" && echo "toggle present"
    grep -q 'en:' "$f" && grep -q 'ar:' "$f" && echo "en+ar present"
done > webui_lang.txt

# 8. Companion APK state (v1.4.0)
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk 2>&1" > app-apk.txt
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/app-apk.version 2>&1" >> app-apk.txt 2>&1
curl -sI http://127.0.0.1:9090/app-debug.apk >> app-apk.txt 2>&1

# 9. Full diagnostic report
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" > diagnose.txt

# 10. Logs
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
| Concurrency Guardian | RACE-1 fixes (mutex/concurrency) — also covers `backupMu` |
| Port Architect | PORT-2 fixes (dynamic ports) |
| Decision Architect | Proposing an accepted ADR |
| Memory Architect (v1.1.0) | Test dynamic memory limit across RAM tiers + report GC behavior |
| Data Guardian (v1.2.0) | Test the backup/restore system across devices, root solutions, and upgrade scenarios |
| **Rotation Guardian (v1.3.0)** | **Verify SNAP-*/ROT-* on a real device and report the results — see `docs/COMPATIBILITY.md` §10.3.5** |
| **PWA Pioneer (v1.3.0)** | **Contributions to the PWA install flow or DNS auto-start flow** |
| **Companion App Tester (v1.4.0)** | **Test the companion APK integration across devices and browsers, report fetch/stage/install behavior** |

**Detailed conditions**: see [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md).

**v1.3.0 note on Rotation Guardian**: This badge is granted for
substantive testing of the v1.3.0 rotation refinements
(SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT)
across multiple devices and root solutions.

**v1.4.0 note on Concurrency Guardian**: The badge recognizes
contributions to **both** the `rebuildMu` mutex (v1.0.0) and the
`backupMu` mutex (v1.2.0).

**v1.4.0 note on Translator**: With the bilingual WebUI, the
Translator badge recognizes:
- Complete documentation translation (`docs/*.<lang>.md`).
- OR a significant contribution to the WebUI's `translations.ar`
  object.

**v1.4.0 note on Companion App Tester**: This badge is granted for
substantive testing of the v1.4.0 companion APK integration. See
[`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) for the acceptance
criteria.

### 12.3 Contributors Image

https://contrib.rocks/image?repo=gasciljh/dnscrypt-proxy-webui

---

## 13. v1.4.0 — Contributors Reference

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
> **18.** Open PRs against `develop` — never against `main`.
>
> **19.** Document non-trivial decisions as ADRs — reversals require a new ADR, never an edit.
>
> **20.** Use `release-patch.sh` for PATCH-only releases — never `release.sh` directly from `main`.
>
> **21.** Never hardcode the memory limit — always use
> `memoryLimitForProfile(key)` and expose the effective value via
> `runtime_info.memory_limit_mb`. Any new profile must be added to
> **five** places: `MEMORY_LIMIT_*`, `memoryLimitForProfile()`, the
> inline fallback in `functions.sh`, the inline fallback in
> `service.sh`/`action.sh`/`status.sh`/`watchdog.sh`, and the profile
> table in `customize.sh`.
>
> **22.** Never remove a user data file without a backup. Any
> destructive operation on user data must call
> `createAutoBackup(reason)` first (or be routed through
> `copy_with_context` for restore). Any change to the 10 defensive
> layers must update **all** of: `docs/BACKUP.md`,
> `docs/EMERGENCY.md`, `docs/SECURITY.md` §5.31, and
> `docs/ARCHITECTURE.md` §3.10.
>
> **23.** Never add a user-facing string to the WebUI without the
> matching **Arabic** entry. Every new key must appear in
> `translations.en` **and** `translations.ar` of `index.html`,
> `dashboard.html`, and `offline.html`. The default must remain
> English. The language preference lives in
> `localStorage['dnscrypt-lang']` and is **never** sent to the
> server.
>
> **24. (v1.4.0)** Never commit the companion APK
> (`web/app-debug.apk`) to git — it is a build artifact. Never
> change the APK fetch/stage logic without a matching update in
> `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`, and
> `.github/workflows/release.yml`. Always keep the install button
> as `<a href="/app-debug.apk" download>`; do not reintroduce a
> JavaScript click handler for installation.
>
> **25. (v1.4.0)** Never change the rotation semantics
> (SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT)
> in only one file. They must stay in sync across **all 8**
> consumers: `main.go:buildBackupInfo`, `functions.sh:rotate_backups`,
> `service.sh` (`_inline_rotate_backups`), `watchdog.sh` (§[5b]
> snapshot counter), `status.sh` (`_list_snapshots`),
> `customize.sh` (`rotate_backups`), `action.sh`
> (`_inline_list_snapshots` + `_inline_rotate_backups`), and
> `uninstall.sh` (§[5b] `BACKUP_COUNT` / `BACKUP_LAST_NAME`). See
> `docs/ARCHITECTURE.md` §4.13.2.

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
| Rotation-semantics change (v1.3.0) | `feature/*` or `fix/*` | `develop` | Default |
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
- [ ] **(v1.2.0)** If adding a new destructive operation on user
      data: call `createAutoBackup(reason)` first, and document
      the new reason in `docs/BACKUP.md` §4.3.
- [ ] **(v1.2.0)** If adding a new preserved file: update the
      `USER_FILES` list in **all 5** scripts, the "5 Preserved
      Files" table in `README.md`, and `docs/BACKUP.md` §2.
- [ ] **(v1.2.0)** If adding a new config migration: add it to
      `migrate_config()` in `customize.sh` and document it in
      `docs/UPGRADE.md`.
- [ ] **(v1.2.0)** If adding a user-facing string: update
      `translations.en` **and** `translations.ar` in all three
      HTML files.
- [ ] **(v1.2.0)** If touching the language toggle: verify RTL
      layout in Chrome 88+, Firefox 92+, and Samsung Internet 16+.
- [ ] **(v1.3.0)** If changing the rotation semantics (SNAP-* or
      ROT-*): update all **8** consumers in sync (see Golden Rule
      #25) and `docs/ARCHITECTURE.md` §4.13.2.
- [ ] **(v1.3.0)** If touching the boot flow: verify the DNS
      auto-start fix still works (see §8.13).
- [ ] **(v1.3.0)** If touching the PWA install flow: verify the
      download link works in all three browser families.
- [ ] **(v1.4.0)** If adding a new static route: use
      `serveStaticAssets` and follow the per-extension
      Cache-Control pattern.
- [ ] **(v1.4.0)** If touching the companion APK integration:
      update `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`,
      and the release workflow in lockstep.
- [ ] **(v1.4.0)** If touching `removeModule`: keep the
      `filepath.Base()` + `filepath.Join()` sanitization.

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
- [ ] **(v1.3.0)** If the fix touches the rotation semantics →
      verify all 8 consumers are in sync (§8.14, Step 5).
- [ ] **(v1.3.0)** If the fix is boot-flow-related → verify the DNS
      auto-start fix (see §8.13).
- [ ] **(v1.4.0)** If the fix is companion-APK-related → run the
      full §8.15 test suite.
- [ ] **(v1.4.0)** If the fix touches `removeModule` → verify the
      CodeQL path-injection fix is preserved.
- [ ] Target `develop` in your PR.

### 13.5 When Publishing a Release

- [ ] For **Stable/Prerelease** → use `./scripts/release.sh vX.Y.Z` from `develop`.
- [ ] For **PATCH-only** → use `./scripts/release-patch.sh vX.Y.Z` from `main`.
- [ ] Use the release PR template (`?template=release.md`).
- [ ] After PATCH release → run `make sync`.
- [ ] Run `make check-backup`.
- [ ] Run `make check-app-version` (v1.4.0+).
- [ ] Verify the `upgrade-test.yml` matrix is green (see §8.10).
- [ ] Verify the bilingual WebUI is intact (§8.11, Step 1).
- [ ] Verify the rotation semantics are intact (v1.3.0+, §8.14).
- [ ] Verify the install button works (v1.4.0+, §8.11).
- [ ] Verify the live status LED works (v1.3.0+).
- [ ] Verify the DNS auto-start fix (v1.3.0+, §8.13).
- [ ] Verify the companion APK integration (v1.4.0+, §8.15).
- [ ] See [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for the full flow.

### 13.6 Quick References

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
| v1.2.0 Backup system | `docs/BACKUP.md` |
| v1.2.0 Emergency recovery | `docs/EMERGENCY.md` |
| v1.2.0 Data-preservation model | `docs/SECURITY.md` §5.31 |
| v1.2.0 Recovery-mode fix | `docs/SECURITY.md` §5.32 |
| v1.2.0 Backup & restore flow | `docs/ARCHITECTURE.md` §3.10 |
| v1.2.0 BAK-1..BAK-4 | `docs/ARCHITECTURE.md` §4.10 |
| v1.2.0 7-field backups schema | `docs/API.md` §6.1.7 |
| v1.2.0 Bilingual WebUI | `docs/ARCHITECTURE.md` §6.7 + `docs/API.md` §10.8 |
| **v1.3.0 Rotation refinements (SNAP-*/ROT-*)** | **`docs/ARCHITECTURE.md` §4.13 (authoritative) + `docs/COMPATIBILITY.md` §10.3.5** |
| **v1.3.0 DNS auto-start fix** | **`proxy/service.sh` §[19] + `docs/ARCHITECTURE.md` §3.3, §9.3** |
| **v1.3.0 PWA install flow** | **`docs/ARCHITECTURE.md` §6.4** |
| **v1.4.0 Companion APK** | **`scripts/fetch_app_apk.sh` + `proxy/app-apk.version` + `docs/API.md` §1.3** |
| **v1.4.0 CodeQL fix** | **`docs/SECURITY.md` + `proxy/main.go` (`removeModule`)** |
| Release scripts | `scripts/release.sh`, `scripts/release-patch.sh` |

### 13.7 Full References

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture + Trade-offs + §3.10, §4.10, §4.13, §6.7 |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry + §5.31, §5.32 |
| [`docs/API.md`](API.md) | HTTP API Reference + §6.1.7, §10.8 |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer guide |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting (§7.8–§7.11 for backups) |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix + §10.3.5 (SNAP-*/ROT-* verification) |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide (§3.0, §3.1) |
| [`docs/BACKUP.md`](BACKUP.md) | Backup system reference (v1.2.0 + v1.3.0 rotation) |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | Emergency recovery (v1.2.0) |
| [`docs/FAQ.md`](FAQ.md) | Common questions |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary (BAK/MEM/ROT/SNAP terms) |
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

**Last updated**: 2026-10-08
**Version**: v1.4.0
**Author**: gasciljh