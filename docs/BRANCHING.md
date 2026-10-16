# Branching Strategy — DNSCrypt Smart Filter

Complete guide to the project's Git workflow: branches, naming
conventions, merge rules, and protection policies.

**Version**: v1.4.0
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (5 total)**:
>   • HARD-BRN-01 (`Last updated` correction — v1.4.0)
>   • HARD-BRN-02 (v1.3.0 block added — v1.4.0)
>   • HARD-BRN-03 (§1.3 ADR-count note extended — v1.4.0)
>   • HARD-BRN-04 (§7.3 + §10.1/§10.3 v1.3.0 rotation refs — v1.4.0)
>   • HARD-BRN-05 (§9.4 rotation-related mistakes — v1.4.0)
>
> **Cross-references**:
>   • [docs/RELEASE_PROCESS.md](RELEASE_PROCESS.md) — step-by-step release guide
>   • [docs/adr/README.md](adr/README.md) — ADR index + methodology
>   • [docs/CONTRIBUTING.md](CONTRIBUTING.md) — contribution guide
>   • [docs/UPGRADE.md](UPGRADE.md) — version upgrade paths (§3.0–§3.2)
>   • [docs/BACKUP.md](BACKUP.md) — backup system reference (v1.2.0 + v1.3.0 rotation)
>   • [docs/EMERGENCY.md](EMERGENCY.md) — emergency recovery (v1.2.0)
>   • [docs/ARCHITECTURE.md §4.13](ARCHITECTURE.md) — v1.3.0 server-side refinements (authoritative)
>   • [docs/COMPATIBILITY.md §10.3.5](COMPATIBILITY.md) — on-device SNAP-*/ROT-* verification
>   • [CHANGELOG.md](../CHANGELOG.md) — version history (v1.0.0 → v1.4.0)

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date
>     (2026-10-08).
>   • **Companion Android app** — the module ZIP may now contain
>     `web/app-debug.apk` (optional). No branching-strategy change
>     is required; the APK is treated as an optional asset.
>   • Release examples updated from `v1.4.0` (now the current
>     release) to `v1.5.0` (the next planned release).
>   • Hotfix examples updated from `v1.2.1` to `v1.4.1` — the
>     first realistic PATCH release from `v1.4.0`.
>   • §1.4 (Repository Map) — the `main` release marker now
>     reflects `v1.4.0`.
>   • §5.5 (Release PR Template) — example URL updated to
>     `release/v1.5.0`.
>   • §6.1 (Required status checks) — the v1.2.0 addition
>     `Backup Smoke Test` is reaffirmed as required.
>   • §8.1 (Hotfix versioning) — the release chain table now
>     includes v1.3.0 and v1.4.0.
>   • §9.1 (Cheat Sheet) — all release examples updated to
>     `v1.5.0` (stable) and `v1.4.1` (PATCH).
>   • §10.1 (References) — updated to reference the v1.4.0
>     documentation set and the companion app repository.
>   • No changes to the branching strategy itself. The two-branch
>     model (`main` + `develop`), naming rules, merge rules, and
>     protection policies are unchanged.
>   • Documentation text is English-only by project convention.

> **v1.3.0 changes**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • `Last updated` reflected the v1.3.0 release date.
>   • Client-side changes (WebUI): PWA install button (later
>     replaced in v1.4.0) + live status LED on the Today
>     counter.
>   • Boot-path fix: DNS auto-start after boot via a direct API
>     call in `service.sh` §[19].
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
>
>   • **No branching-strategy change** was required for v1.3.0.
>     The two-branch model (`main` + `develop`), naming rules,
>     merge rules, and protection policies are unchanged from
>     v1.2.0. All affected files (`main.go`, `functions.sh`,
>     `service.sh`, `watchdog.sh`, `status.sh`, `customize.sh`,
>     `action.sh`, `uninstall.sh`) follow the standard
>     `feature/*` / `fix/*` PR flow — no new branch type was
>     introduced.
>
>   • **Version chain** — the release chain table in §8.1 now
>     includes v1.3.0 between v1.2.0 and v1.4.0.

> **v1.2.0 changes (historical)**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • Introduced the `backup-smoke-test` job as a required status
>     check on `main` and `develop`.
>   • §6.3 (Tags protection) — reaffirmed the v1.1.0 fix that
>     documents the GitHub Rulesets UI (not the deprecated Classic
>     Branch Protection UI).
>   • Introduced the v1.2.0 data-preservation release. See
>     [`docs/BACKUP.md`](BACKUP.md) for the full model.

> **v1.4.0 — POST-AUDIT FIXES (this revision)**:
>   A post-audit review of this file against the v1.3.0 / v1.4.0
>   code identified the following documentation gaps. All are
>   addressed in-place; no version bump.
>
>   🔧 **HARD-BRN-01** — `Last updated` corrected. The header
>     and footer previously said `2026-10-06` (the v1.4.0
>     release date, not the v1.4.0 file-editing date). Both now
>     read `2026-10-08`, matching every other file in the v1.4.0
>     module.
>
>   🔧 **HARD-BRN-02** — `v1.3.0` block added. The file
>     previously jumped directly from the v1.4.0 block to the
>     v1.2.0 (historical) block, with **no mention at all** of
>     the v1.3.0 release. The block above now documents the
>     client-side changes, the boot-path fix, and the
>     server-side rotation refinements (SNAP-MANIFEST,
>     SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT), and
>     explains why no branching-strategy change was required.
>
>   🔧 **HARD-BRN-03** — §1.3 (Architecture Decisions) extended
>     with a v1.3.0 note confirming that the ADR count remains
>     at 6 (no new ADR was added by v1.3.0 or v1.4.0). The
>     rotation refinements are functional changes, not
>     architectural decisions.
>
>   🟡 **HARD-BRN-04** — §7.3 (Release Automation) and §10.1 /
>     §10.3 (References / Project Files) extended with the
>     v1.3.0 server-side refinements and the v1.4.0 companion
>     APK files. `docs/ARCHITECTURE.md` §4.13 and
>     `docs/COMPATIBILITY.md` §10.3.5 are now cited.
>
>   🟡 **HARD-BRN-05** — §9.4 (Common Mistakes) extended with
>     two rotation-related entries:
>       • Editing a `txn-*` directory manually.
>       • Adding an English string without the matching Arabic
>         entry (this was already in the previous version — kept
>         for clarity).
>     The rotation-related entry references `BACKUP.md` §10.5
>     and `ARCHITECTURE.md` §4.13.2 for the correct handling
>     of in-flight transactions.

> **📖 Related documents**:
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Contribution guide → [`docs/CONTRIBUTING.md`](CONTRIBUTING.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)
> - Architecture (v1.3.0 rotation semantics) → [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13
> - Compatibility matrix → [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §10.3.5

---

## Table of Contents

1. [Overview](#1-overview)
2. [Branch Types](#2-branch-types)
3. [Naming Conventions](#3-naming-conventions)
4. [Workflows](#4-workflows)
5. [Pull Request Rules](#5-pull-request-rules)
6. [Branch Protection](#6-branch-protection)
7. [CI/CD Integration](#7-cicd-integration)
8. [Hotfix Flow](#8-hotfix-flow)
9. [Quick Reference](#9-quick-reference)
10. [References](#10-references)

---

## 1. Overview

### 1.1 Philosophy

The project uses a **simplified GitHub Flow with a `develop` branch**:

- **`main`** is always stable and deployable — every commit is a release.
- **`develop`** is the integration branch — features land here first.
- **`feature/*`** branches are short-lived — one feature, one branch.
- **`release/*`** branches are the bridge from `develop` to `main`.

This model gives us:

| Property | Benefit |
|---|---|
| **Stable `main`** | Users always download a tested release. |
| **Integration preview** | `develop` catches issues before the release. |
| **Isolated features** | A broken feature never blocks other work. |
| **Clean history** | Squash merges keep logs readable. |
| **Automated CI** | Every branch is checked automatically. |

### 1.2 Core Principles

1. **`main` is sacred** — never push directly, always via PR.
2. **`develop` is the daily driver** — commit here, not to `main`.
3. **One branch = one purpose** — features, fixes, docs are separate.
4. **Everything goes through a PR** — even `develop → main` releases.
5. **Every PR must pass CI** — `ci.yml` and `codeql.yml` are gates.

### 1.3 Architecture Decisions

The decisions that shaped this strategy are documented as **ADRs**:

| ADR | Decision |
|---|---|
| [ADR-0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) |
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0004](adr/0004-unified-pr-template.md) | Unified PR template (⚠️ Superseded) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

**Current ADR count**: 6 (5 accepted + 1 superseded).

The `release-patch.sh` script named in ADR-0006 is now in active
use — for example, `v1.4.0 → v1.4.1` would be a PATCH release
processed by that script (see §8).

**v1.3.0 note**: The v1.3.0 release cycle did **not** add any new
ADR. The client-side features (PWA install button, live status
LED), the boot-path fix (DNS auto-start in `service.sh`), and the
server-side rotation refinements (SNAP-MANIFEST + SNAP-MTIME in
`main.go:buildBackupInfo`; ROT-MANIFEST + ROT-MTIME + ROT-PROTECT
in `functions.sh:rotate_backups`) are all documented as functional
changes in [`CHANGELOG.md`](../CHANGELOG.md) §[v1.3.0] and
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13 — not as
architectural decisions. The ADR count remains at 6.

**v1.4.0 note**: The v1.4.0 release cycle did **not** add any new
ADR. The companion APK integration, the CodeQL path-injection
fix, and the iOS PWA removal are documented as functional
changes in [`CHANGELOG.md`](../CHANGELOG.md) §[v1.4.0] — not as
architectural decisions. The ADR count remains at 6.

### 1.4 Repository Map

```text
main ─────●──────────────────●───────────────●──── (releases)
          ↑                  ↑               ↑
       [release/*]        [release/*]     [hotfix/*]
          │                  │               │
develop ──●──●──●──●──●──●───●──●──●──●──●───●──── (integration)
           ↑         ↑         ↑         ↑
        [feat]    [docs]    [chore]    [fix]
```

**Current state**:

- `main` → **`v1.4.0`** (released 2026-10-06).
- `develop` → in sync with `main` after the automated post-release
  sync (see [ADR-0003](adr/0003-post-release-sync.md)).

**Next planned releases**:

- **`v1.4.1`** — first realistic PATCH release from v1.4.0 (via
  `hotfix/*` + `release-patch.sh`), if needed.
- **`v1.5.0`** — next MINOR release (via `release.sh`) — see
  [`docs/ROADMAP.md`](ROADMAP.md) §5.

### 1.5 Language Policy Note

The branching strategy is **independent** of the WebUI's language
feature:

- The WebUI ships with **English as the default** language and an
  in-page **Arabic toggle** (`langToggle`).
- The language preference is stored **client-side only** in
  `localStorage['dnscrypt-lang']`.
- It has **no** impact on branches, PRs, tags, or releases.
- Documentation is **English-only** by project convention.
- Documentation translations are welcome as separate files
  (`docs/*.<lang>.md`) — they follow the normal `docs/*` branch
  flow (see §2.5).

Contributors working on the WebUI's translation strings should
follow the standard `feature/*` or `fix/*` flow (see §4.1).

---

## 2. Branch Types

### 2.1 `main` — Stable Releases

| Aspect | Value |
|---|---|
| **Purpose** | Production-ready code, released to users. |
| **Lifetime** | Permanent. |
| **Created from** | — (exists from project start). |
| **Merges into** | — (target of `release/*` merges). |
| **Direct push** | ❌ Forbidden (Branch Protection). |
| **Requires PR** | ✅ Yes, with 1 approval + CI pass. |

**Every commit on `main` corresponds to a released version.**

Current state: `v1.4.0` (released 2026-10-06).

### 2.2 `develop` — Integration Branch

| Aspect | Value |
|---|---|
| **Purpose** | Daily development, feature integration, pre-release testing. |
| **Lifetime** | Permanent. |
| **Created from** | `main` (initial) — kept in sync after each release. |
| **Merges into** | `release/*` (to prepare releases). |
| **Direct push** | ⚠️ Allowed by maintainer (Branch Protection is lighter). |
| **Requires PR** | ⚠️ Recommended for contributors, optional for maintainer. |

**`develop` should always build successfully.** If `ci.yml` fails on
`develop`, it must be fixed before opening a release PR.

### 2.3 `feature/*` — New Features

| Aspect | Value |
|---|---|
| **Purpose** | Develop a single feature in isolation. |
| **Lifetime** | Short — days to weeks. |
| **Created from** | `develop`. |
| **Merges into** | `develop` (via PR). |
| **Direct push** | ✅ Yes (own branch). |
| **Requires PR** | ✅ Yes, to merge into `develop`. |

**Example**: `feature/webui-dark-mode`, `feature/dashboard-resolver-health`.

### 2.4 `fix/*` — Non-Critical Bug Fixes

| Aspect | Value |
|---|---|
| **Purpose** | Fix a bug that is not release-blocking. |
| **Lifetime** | Short — hours to days. |
| **Created from** | `develop`. |
| **Merges into** | `develop` (via PR). |
| **Direct push** | ✅ Yes. |
| **Requires PR** | ✅ Yes. |

**Example**: `fix/toggle-service-race`, `fix/dashboard-json-empty`.

### 2.5 `docs/*` — Documentation Changes

| Aspect | Value |
|---|---|
| **Purpose** | Documentation-only changes (no code impact). |
| **Lifetime** | Very short — hours. |
| **Created from** | `develop`. |
| **Merges into** | `develop` (via PR). |
| **Direct push** | ✅ Yes. |
| **Requires PR** | ✅ Yes (CI is skipped via `paths-ignore`). |

**Example**: `docs/update-install-guide`, `docs/api-endpoint-examples`.

**Note**: This branch type also covers **documentation
translations** (`docs/*.<lang>.md`). WebUI translation changes
are not a separate branch type — they use `feature/*` or
`fix/*` (see §4.1).

### 2.6 `release/*` — Release Preparation

| Aspect | Value |
|---|---|
| **Purpose** | Freeze `develop`, bump version, prepare a release. |
| **Lifetime** | Days (until release is published). |
| **Created from** | `develop`. |
| **Merges into** | `main` (via PR). |
| **Direct push** | ⚠️ Only version bumps allowed. |
| **Requires PR** | ✅ Yes, with 1 approval + CI pass. |

**Example**: `release/v1.5.0`, `release/v2.0.0`.

**Rule**: Only version bumps, changelog updates, and critical fixes
are allowed on `release/*`. No new features.

**Automation**: The PATCH release variant uses
[`scripts/release-patch.sh`](../scripts/release-patch.sh) — see
[ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

### 2.7 `hotfix/*` — Emergency Fixes

| Aspect | Value |
|---|---|
| **Purpose** | Fix a critical bug in a released version. |
| **Lifetime** | Hours. |
| **Created from** | `main`. |
| **Merges into** | `main` (via PR) **and** `develop`. |
| **Direct push** | ✅ Yes. |
| **Requires PR** | ✅ Yes, fast-tracked. |

**Example**: `hotfix/v1.4.1-login-bypass`.

**Note**: The `hotfix/*` **branch prefix** remains (it aligns with
the widely-recognized Git Flow terminology). Only the **script
name** was renamed — see
[ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

**Automation**: After a hotfix is merged into `main`, the PATCH
release is prepared via
[`scripts/release-patch.sh`](../scripts/release-patch.sh). The
back-merge into `develop` is **manual** (via `make sync`).

---

## 3. Naming Conventions

### 3.1 Branch Name Format

```text
<type>/<short-description>
```

Where `<type>` is one of:

| Type | Use for | Example |
|---|---|---|
| `feature/` | New functionality | `feature/webui-2fa` |
| `fix/` | Non-critical bug fix | `fix/watchdog-backoff-reset` |
| `docs/` | Documentation | `docs/api-jwt-auth` |
| `release/` | Release preparation | `release/v1.5.0` |
| `hotfix/` | Emergency fix | `hotfix/v1.4.1-login-bypass` |
| `chore/` | Maintenance, tooling | `chore/bump-dnscrypt-2.1.19` |
| `refactor/` | Code refactoring | `refactor/split-main-go` |
| `test/` | Adding/updating tests | `test/hasEndpoint-coverage` |

### 3.2 Description Rules

- **Lowercase only**: `feature/webui-dark-mode` ✅ — `feature/WebUI-Dark-Mode` ❌
- **Hyphens, not underscores**: `fix/port-cache` ✅ — `fix/port_cache` ❌
- **Short and specific**: `feature/editor-fsm` ✅ — `feature/some-new-stuff` ❌
- **English only**: avoids encoding issues in CI logs.
- **No issue numbers alone**: `fix/123` ❌ — use `fix/issue-123-csrf`

### 3.3 Version Branches

For release branches only, the version must match `VERSION` exactly:

```text
release/v1.5.0          ✅
release/v1.5.0-beta1    ✅
release/1.5.0           ❌ (missing 'v')
release/v1.5            ❌ (incomplete)
```

---

## 4. Workflows

### 4.1 Feature Development

```text
1. git checkout develop
2. git pull origin develop
3. git checkout -b feature/my-feature
4. ... develop ...
5. git add . && git commit -m "feat(scope): add my feature"
6. git push -u origin feature/my-feature
7. Open PR → develop
8. Review + CI pass
9. Squash merge
10. Delete feature/my-feature
```

**Rule**: Always branch from an up-to-date `develop`.

### 4.2 Bug Fix (Non-Critical)

Same as feature, but with `fix/` prefix:

```text
git checkout -b fix/watchdog-backoff-reset
git commit -m "fix(watchdog): reset backoff on STATUS_FILE change"
```

### 4.3 Documentation Update

```text
git checkout -b docs/update-faq
git commit -m "docs(faq): add section about IPv6 rate limits"
```

**Note**: CI `paths-ignore` will skip the build matrix for docs-only
changes, saving CI minutes.

### 4.4 Preparing a Release

```text
1. git checkout develop
2. git pull origin develop
3. git checkout -b release/v1.5.0
4. ./scripts/release.sh v1.5.0 --no-push     # updates VERSION + module.prop + update.json
5. Verify: git diff
6. Update CHANGELOG.md: add ## [1.5.0] - YYYY-MM-DD section
7. git commit -m "release: v1.5.0"
8. git push -u origin release/v1.5.0
9. Open PR → main using ?template=release.md
10. Wait for CI + CodeQL to pass
11. Approve + merge
12. git checkout main && git pull origin main
13. ./scripts/release.sh v1.5.0                # now push: creates tag
14. GitHub Actions publishes the release
15. It auto-syncs main → develop
```

**Simpler alternative**: skip the `release/*` branch, and run
`release.sh` directly from `develop`:

```text
1. git checkout develop
2. git pull origin develop
3. ./scripts/release.sh v1.5.0                # interactive, with confirmation
4. Wait for GitHub Actions
```

Use the `release/*` flow when you need a **stabilization window**.

### 4.5 Hotfix (Emergency)

```text
1. git checkout main
2. git pull origin main
3. git checkout -b hotfix/v1.4.1-critical-fix
4. ... fix ...
5. git commit -m "fix(critical): patch login bypass"
6. git push -u origin hotfix/v1.4.1-critical-fix
7. Open PR → main using ?template=release.md (fast-track review)
8. Squash merge
9. Tag + push:
   ./scripts/release-patch.sh v1.4.1
10. After release publishes: back-merge main → develop
    make sync
```

**Fast-track**: hotfix PRs can be merged with a single review, and
CI failures can be waived by the maintainer if the fix is critical.

**Full details**: [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) §2.3
and §9.

### 4.6 WebUI Translation Contribution (v1.2.0+)

The WebUI ships with **English as the default** and an in-page
**Arabic toggle**. Adding or changing a WebUI string is a normal
code change — it follows the standard `feature/*` or `fix/*`
flow (not a separate `translation/*` type):

```text
1. git checkout develop
2. git pull origin develop
3. git checkout -b feature/webui-string-fix
4. Edit web/index.html, web/dashboard.html, web/offline.html
   → add or update BOTH translations.en and translations.ar entries
5. git commit -m "feat(webui): add string X in EN + AR"
6. git push -u origin feature/webui-string-fix
7. Open PR → develop
```

**Requirements**:

- Every new user-facing string needs **both** an English and an
  Arabic entry.
- Arabic strings must be verified in RTL layout.
- The default language must remain English.

For **documentation translations** (`docs/*.<lang>.md`), use
`docs/*` (see §2.5) — CI is skipped and the change is
text-only.

---

## 5. Pull Request Rules

### 5.1 PR Target Rules

| Source branch | Target branch | Notes |
|---|---|---|
| `feature/*` | `develop` | Always. |
| `fix/*` | `develop` | Always. |
| `docs/*` | `develop` | Always. |
| `chore/*` | `develop` | Always. |
| `refactor/*` | `develop` | Always. |
| `test/*` | `develop` | Always. |
| `release/*` | `main` | Only for releases. |
| `hotfix/*` | `main` | Only for emergency fixes. |
| `develop` | `main` | ❌ Never directly. Use `release/*` or `release.sh`. |

### 5.2 Required Checks

Every PR must pass:

- ✅ **`ci.yml`** — Build for all 4 architectures (arm64, arm, amd64, 386).
- ✅ **`codeql.yml`** — Security analysis (SAST).
- ✅ **`backup-smoke-test`** (v1.2.0+, part of `ci.yml`) — validates
  the 10 data-preservation layers.
- ✅ **No merge conflicts** with the target branch.
- ✅ **PR template completed** (`.github/PULL_REQUEST_TEMPLATE.md`).
- ✅ **CHANGELOG.md** updated (if user-facing).
- ✅ **Documentation** updated (if applicable).

**v1.4.0 addition**: `ci.yml` also runs a `Verify companion app
metadata` step that validates `proxy/app-apk.version` (format
`X.Y.Z`) and confirms `scripts/fetch_app_apk.sh` is present. This
step is **non-blocking** — the companion app is OPTIONAL.

**v1.3.0 addition**: any PR that touches the rotation semantics
(SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT)
must keep the invariants in sync across `main.go`,
`functions.sh`, and the five shell scripts that mirror them. See
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.2 for the full
reference. This is not a new CI check — it is a review guideline.

**v1.2.0 language check**: Any PR that adds a **new user-facing
string** to the WebUI must supply **both** an English and an
Arabic entry. The default language must remain English.

### 5.3 PR Title Convention

Use **Conventional Commits** for the PR title:

```text
<type>(<scope>): <subject>
```

| Type | Use for | Triggers version bump |
|---|---|---|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `security` | Security fix | PATCH |
| `perf` | Performance | PATCH |
| `refactor` | Code refactor | PATCH |
| `docs` | Documentation | — |
| `chore` | Maintenance | — |
| `build` | Build system | — |
| `ci` | CI workflows | — |

**Examples**:

- `feat(webui): add dark mode toggle`
- `fix(watchdog): reset backoff on STATUS_FILE change`
- `security(auth): enforce rate limit on Basic Auth`
- `docs(api): add runtime_info schema`
- `feat(backup): add multi-source detection` (v1.2.0 example)
- `feat(webui): add Arabic translation for X` (v1.2.0 example)
- `refactor(backup): use SNAP-MANIFEST + ROT-MTIME for rotation` (v1.3.0 example)
- `feat(service): boot-path DNS auto-start via direct API call` (v1.3.0 example)
- `feat(app): integrate companion Android app` (v1.4.0 example)

### 5.4 Merge Strategy

| Merge into | Strategy | Reason |
|---|---|---|
| `develop` | **Squash** | Clean history, one commit per PR. |
| `main` (from `release/*`) | **Squash** | Release = single commit. |
| `main` (from `hotfix/*`) | **Squash** | Same. |

**Never use**:
- ❌ Merge commits (pollute history).
- ❌ Rebase merges (rewrite shared history).

### 5.5 Release PR Template

PRs targeting `main` (from `release/*` or `hotfix/*`) should use the
dedicated template:

```text
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.5.0?template=release.md
```

**Why a separate template?**

Releases have a **different lifecycle** than features — version
correctness, `CHANGELOG` completeness, tag planning, and rollback
preparedness are the primary concerns. The unified template is
optimized for feature PRs.

**Full decision**: [ADR-0005](adr/0005-release-specific-pr-template.md).

### 5.6 After Merge

**Always delete the source branch** (GitHub can do this
automatically after merge):

- ✅ Auto-delete enabled in Repository Settings.
- ✅ If not, delete manually: `git push origin --delete <branch>`.

---

## 6. Branch Protection

### 6.1 `main` (Strict)

Configure at **Settings → Branches → Add rule**:

| Setting | Value |
|---|---|
| **Branch name pattern** | `main` |
| Require a pull request before merging | ✅ |
| Require approvals | ✅ 1 |
| Dismiss stale PR approvals | ✅ |
| Require review from Code Owners | ✅ (see `.github/CODEOWNERS`) |
| Require status checks to pass | ✅ |
| Require branches up to date | ✅ |
| Require conversation resolution | ✅ |
| Require linear history | ✅ |
| Do not allow bypassing | ✅ |
| Restrict who can push | ✅ (only maintainer + `github-actions[bot]`) |
| Allow force pushes | ❌ |
| Allow deletions | ❌ |

**Required status checks**:

- `CI / Build arm64`
- `CI / Build arm`
- `CI / Build amd64`
- `CI / Build 386`
- `CI / Backup Smoke Test` (v1.2.0 addition)
- `CodeQL / Analyze Go`

**Note**: `github-actions[bot]` must be in the "Restrict who can
push" allowlist so the post-release sync
([ADR-0003](adr/0003-post-release-sync.md)) can push to `develop`.

### 6.2 `develop` (Relaxed)

| Setting | Value |
|---|---|
| **Branch name pattern** | `develop` |
| Require a pull request before merging | ⚠️ Recommended, optional |
| Require status checks to pass | ✅ |
| Require branches up to date | ✅ |
| Require conversation resolution | ⚠️ Optional |
| Require linear history | ✅ |
| Allow force pushes | ❌ |
| Allow deletions | ❌ |

**Required status checks** (same as `main`, including the v1.2.0
`Backup Smoke Test`).

**Note on force-push**: `develop` does not allow force-push even
for the owner. To sync `develop` with `main` after a release,
use a regular `git merge` (see §8.4), not `--force`.

### 6.3 Tags

> **⚠️ Important — this section was rewritten in v1.1.0 and
> verified in v1.2.0, v1.3.0, and v1.4.0.**
>
> The previous version of this document described the deprecated
> "Protected tags" page (Classic Branch Protection). GitHub now
> uses **Rulesets**, which behave differently — most notably
> around the "Restrict creations" rule.

Configure at **Settings → Rules → Rulesets** (not the legacy
"Protected tags" page, which is deprecated).

**Recommended Ruleset**:

| Setting | Value |
|---|---|
| **Name** | `Protect release tags` |
| **Enforcement status** | Active |
| **Target tags** | `v*` (pattern match) |
| **Restrict creations** | ✅ (requires Bypass — see below) |
| **Restrict updates** | ✅ |
| **Restrict deletions** | ✅ |
| **Block force pushes** | ✅ |
| **Bypass list** | **`Repository admin`** ⚠️ MANDATORY |

> **⚠️ Critical requirement**:
>
> If `Restrict creations` is enabled, the `Repository admin`
> role **MUST** be present in the Bypass list.
>
> Without this entry, the rule blocks **all** tag creation —
> including by the repository owner. This was discovered
> during the v1.1.0 release cycle (see PR #6). Attempting to
> push a tag or create one via the GitHub Releases UI will
> fail with:
>
> ```text
> remote: error: GH013: Repository rule violations found
> remote: - Cannot create ref due to creations being restricted.
> ```
>
> **Fix**: Add `Repository admin` to the Bypass list in the
> Ruleset.

**Why**: prevents accidental deletion or modification of release
tags while allowing maintainers to create new tags without
friction.

**Alternative** (simpler, less strict): disable `Restrict
creations` and keep only `Restrict updates` + `Restrict
deletions`. This allows any user with push access to create tags,
but tags remain immutable once created.

**Verify**:

```bash
# On GitHub: Settings → Rules → Rulesets
# Expected:
#   Target: v*
#   Restrict creations: ✅
#   Restrict updates: ✅
#   Restrict deletions: ✅
#   Bypass list: Repository admin  ← MUST be present
```

### 6.4 Repository Settings

At **Settings → General**:

| Setting | Value |
|---|---|
| Allow merge commits | ❌ |
| Allow squash merging | ✅ |
| Allow rebase merging | ❌ |
| Automatically delete head branches | ✅ |
| Default branch | `main` |

### 6.5 Branch Protection Policy

The rationale for these rules is documented in:

- [ADR-0001](adr/0001-two-branch-model.md) — Why two branches.
- [ADR-0003](adr/0003-post-release-sync.md) — Why the sync exists.
- [ADR-0005](adr/0005-release-specific-pr-template.md) — Why two PR templates.

---

## 7. CI/CD Integration

### 7.1 Workflow Triggers

| Workflow | Triggered on |
|---|---|
| `.github/workflows/ci.yml` | Push to `main` / `develop`; PR to `main` / `develop` |
| `.github/workflows/codeql.yml` | Push to `main` / `develop`; PR; weekly (Mon 06:00 UTC) |
| `.github/workflows/release.yml` | Tag push `v*.*.*` (with or without prerelease) |
| `.github/workflows/upgrade-test.yml` | Manual (`workflow_dispatch`) + weekly schedule |

### 7.2 What Runs on Each Branch

| Branch | CI | CodeQL | Release | Backup Smoke |
|---|:---:|:---:|:---:|:---:|
| `feature/*` | ✅ (via PR) | ✅ (via PR) | ❌ | ✅ (via PR) |
| `fix/*` | ✅ (via PR) | ✅ (via PR) | ❌ | ✅ (via PR) |
| `docs/*` | ⏭️ Skipped (`paths-ignore`) | ✅ | ❌ | ⏭️ Skipped |
| `develop` | ✅ | ✅ | ❌ | ✅ |
| `release/*` | ✅ | ✅ | ❌ | ✅ |
| `main` | ✅ | ✅ | ✅ (on tag) | ✅ |
| `hotfix/*` | ✅ (via PR) | ✅ | ❌ | ✅ (via PR) |

### 7.3 Release Automation

When you run:

```bash
./scripts/release.sh v1.5.0
```

The script pushes a tag → `release.yml` triggers → publishes the
release → **automatically syncs `main → develop`**.

For PATCH releases:

```bash
./scripts/release-patch.sh v1.4.1
```

Same pipeline, but with 3 safety rules enforced (see
[ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)).

**Note on auto-sync**: The sync step has `continue-on-error: true`
— a failed sync **never fails the release**. The release is
already published at this point.

**Verification history**: The auto-sync succeeded for v1.1.0,
v1.2.0, v1.3.0, and v1.4.0 (fast-forward merge in all cases, no
manual intervention). See
[ADR-0003](adr/0003-post-release-sync.md) for details.

If the auto-sync fails (e.g. due to branch protection on
`develop`), sync manually:

```bash
git checkout develop
git pull origin develop
git merge origin/main --no-edit -m "chore: sync develop with main"
git push origin develop
```

Or, to allow the bot to sync automatically in future releases, add
`Repository admin` or `github-actions[bot]` to the Bypass list of
the Ruleset that protects `develop`.

Full process: [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md).

### 7.3.1 Server-Side Rotation Refinements (v1.3.0)

The v1.3.0 release did **not** change the CI/CD pipeline itself.
However, it did change the internal semantics of eight files that
are covered by the pipeline's `backup-smoke-test` job:

| File | Change |
|---|---|
| `proxy/main.go` | SNAP-MANIFEST + SNAP-MTIME in `buildBackupInfo` |
| `proxy/functions.sh` | ROT-MANIFEST + ROT-MTIME + ROT-PROTECT in `rotate_backups` |
| `proxy/service.sh` | Boot-path DNS auto-start (§[19]) |
| `proxy/watchdog.sh` | §[5b] snapshot counter uses manifest detection |
| `proxy/status.sh` | `_list_snapshots` uses manifest detection |
| `proxy/customize.sh` | `rotate_backups` uses ROT-* semantics |
| `proxy/action.sh` | `_inline_list_snapshots` + `_inline_rotate_backups` |
| `proxy/uninstall.sh` | §[5b] `BACKUP_COUNT` / `BACKUP_LAST_NAME` |

**No CI configuration change was required** for v1.3.0:
- The `backup-smoke-test` job in `ci.yml` verifies **function
  presence** (via grep), not internal semantics. The v1.3.0
  refinements kept the same function names, so the smoke test
  passed unchanged.
- The `42-scenario matrix` in `upgrade-test.yml` was updated
  separately (see its own file header for the L9-02/L9-03 fix).
- The semantic verification of SNAP-*/ROT-* is deferred to
  on-device testing — see
  [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §10.3.5.

**Full reference**: [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.2.

### 7.4 Language Policy in CI (v1.2.0+)

The WebUI is **bilingual (English default + Arabic toggle)**. This
does **not** affect the release or CI pipelines:

- The build matrix (`ci.yml`) treats `web/*.html` as static
  assets. Both language objects live in the same HTML file.
- The Service Worker (`sw.js`) caches the HTML **once** —
  language-neutral.
- The release pipeline (`release.yml`) does **not** run any
  language-specific validation. The artifacts are identical
  regardless of the user's language choice.
- The `backup-smoke-test` job in `ci.yml` verifies the **data
  preservation layers**, not the WebUI language strings.

Contributors adding or modifying WebUI strings follow the standard
flow (see §4.6). No CI configuration changes are required.

### 7.5 Companion APK in CI (v1.4.0)

The companion Android app is integrated as an **optional** asset:

- `release.yml` fetches the APK into `dist/` via
  `scripts/fetch_app_apk.sh` (best-effort: a failed fetch does
  not fail the release).
- `release.yml` stages the APK at `web/app-debug.apk` before
  packaging (best-effort: a warning is logged if the APK is
  missing).
- `ci.yml` runs a `Verify companion app metadata` step that
  validates `proxy/app-apk.version` and confirms
  `scripts/fetch_app_apk.sh` is present.

**No branching-strategy change is required** for the companion
APK. It is treated as a build artifact, not as a versioned
component of the module.

---

## 8. Hotfix Flow

### 8.1 When to Use Hotfix

Use a `hotfix/*` branch only when:

- ✅ A **critical** bug exists in a **released** version.
- ✅ The fix cannot wait for the next scheduled release.
- ✅ The bug affects **all users** or is **security-related**.

**Examples**:

- Login bypass on `/api/auth/login`.
- Crash loop caused by a specific configuration.
- Data corruption in `blocklist.txt`.
- Rate limit bypass on `/readyz`.

**Current context (v1.4.0)**: The first realistic hotfix scenario
would be `v1.4.0 → v1.4.1`. The chain of releases is:

| From | To | Type |
|---|---|---|
| `v1.0.0` | `v1.1.0` | MINOR (features) |
| `v1.1.0` | `v1.2.0` | MINOR (data preservation) |
| `v1.2.0` | `v1.3.0` | MINOR (PWA install button + live LED + rotation refinements) |
| `v1.3.0` | `v1.4.0` | MINOR (companion APK + CodeQL cleanup) |
| `v1.4.0` | `v1.4.1` | PATCH (hotfix, if needed) |
| `v1.4.1` | `v1.5.0` | MINOR (features) |

### 8.2 Hotfix Steps

```text
1. git checkout main
2. git pull origin main
3. git checkout -b hotfix/v1.4.1-login-bypass
4. ... minimal fix ...
5. git commit -m "fix(auth): patch login bypass"
6. git push -u origin hotfix/v1.4.1-login-bypass
7. Open PR → main using ?template=release.md
8. Fast-track review + merge
9. Prepare the PATCH release:
   ./scripts/release-patch.sh v1.4.1
10. Back-merge to develop:
    make sync
```

**Note**: The `scripts/release-patch.sh` script enforces 3 safety
rules:

1. Must be run from `main` (not `develop`).
2. `MAJOR` and `MINOR` components must not change.
3. `PATCH` must be exactly `current + 1`.

**Full rationale**: [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

### 8.3 Hotfix Versioning

A hotfix increments the **PATCH** component:

| Released | Hotfix | New Version |
|---|---|---|
| `v1.0.0` | Fix critical bug | `v1.0.1` |
| `v1.1.0` | Fix critical bug | `v1.1.1` |
| `v1.2.0` | Fix critical bug | `v1.2.1` |
| `v1.3.0` | Fix critical bug | `v1.3.1` |
| **`v1.4.0`** | **Fix critical bug** | **`v1.4.1`** |
| `v1.4.1` | Fix critical bug | `v1.4.2` |

**Rule**: hotfix versions are **never** used for features. If a
feature is needed, wait for the next MINOR release.

### 8.4 Back-Merge Requirement

**Critical**: after a hotfix lands on `main`, `develop` must be
synced:

```bash
# Recommended:
make sync

# Manual equivalent:
git checkout develop
git pull origin develop
git merge origin/main --no-edit
git push origin develop
```

**Why**: without this, `develop` will be missing the hotfix, and the
next `release/*` PR will reintroduce the bug.

For **regular releases** (`release/*`), `release.yml` performs this
automatically. For **hotfixes** (`hotfix/*`), it is manual because
GitHub Actions cannot distinguish a hotfix tag from a regular tag.

**Note**: If `release.yml`'s auto-sync fails (e.g. due to
protected-branch rules on `develop`), the same manual command
above works for both regular and hotfix releases.

### 8.5 PATCH-Release Script

| Aspect | Value |
|---|---|
| **Script** | `scripts/release-patch.sh` |
| **Usage** | `./scripts/release-patch.sh v1.4.1` |
| **Branch** | Must be `main` |
| **Bump** | `PATCH` only (delegates to `release.sh`) |
| **Safety rules** | 3 (branch, MAJOR equal, MINOR equal) |
| **Modes** | `--dry-run`, `--no-push`, `--yes`, `--help` |
| **ADR** | [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) |

**Relationship to `release.sh`**:

```text
scripts/release.sh                 ← Full release logic (any bump)
        ↑
        │ delegates to
        │
scripts/release-patch.sh           ← Wraps with 3 PATCH-only rules
```

`release-patch.sh` **does not duplicate** the version bump logic —
it delegates to `release.sh`. This keeps the two scripts perfectly
in sync.

### 8.6 Hotfix and the Language Toggle

A hotfix that touches the WebUI's language toggle follows the
standard hotfix flow. Additional considerations:

- **Always update both languages**: any string changed by the
  hotfix must be changed in **both** `translations.en` and
  `translations.ar`.
- **Test in both directions**: verify LTR (English) and RTL
  (Arabic) after the hotfix.
- **Client-side only**: the language preference
  (`localStorage['dnscrypt-lang']`) must **not** be sent to the
  server by a hotfix.
- **No SW cache invalidation needed**: the Service Worker caches
  the HTML **once** — the toggle operates on the DOM. No cache
  bump is required for language changes.

### 8.7 Hotfix and the Backup Layer (v1.2.0+)

A hotfix that touches the backup layer (data-preservation layers)
or the rotation semantics follows the standard hotfix flow.
Additional considerations:

- **Do NOT edit `txn-*` / `orphan-txn-*` directories manually**.
  These are managed automatically by `main.go` and `service.sh`.
  See [`docs/BACKUP.md`](BACKUP.md) §10.5.
- **Preserve the `.last_stable` pointer**. If the hotfix changes
  snapshot detection, it must not break the ROT-PROTECT guarantee.
- **Test recovery mode**. After the hotfix, verify that the
  recovery trigger (`touch recovery && reboot`) still works.
- **Verify the rotation invariants**:
  - SNAP-MANIFEST (`.manifest.json` presence)
  - SNAP-MTIME (mtime sort)
  - ROT-MANIFEST + ROT-MTIME + ROT-PROTECT
- **Full reference**: [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.2
  and [`docs/BACKUP.md`](BACKUP.md) §6.5.

---

## 9. Quick Reference

### 9.1 Cheat Sheet

```bash
# Start a feature
git checkout develop && git pull
git checkout -b feature/my-feature
# ... work ...
git push -u origin feature/my-feature
# → Open PR against develop

# Start a fix
git checkout develop && git pull
git checkout -b fix/my-fix
# → Open PR against develop

# Start a release
git checkout develop && git pull
git checkout -b release/v1.5.0
./scripts/release.sh v1.5.0 --no-push
# ... update CHANGELOG.md ...
git commit -m "release: v1.5.0"
git push -u origin release/v1.5.0
# → Open PR against main using ?template=release.md

# Publish (from main after merge)
git checkout main && git pull
./scripts/release.sh v1.5.0

# Hotfix
git checkout main && git pull
git checkout -b hotfix/v1.4.1-critical
# ... fix ...
git push -u origin hotfix/v1.4.1-critical
# → Open PR against main using ?template=release.md

# Prepare the PATCH release (after merge)
./scripts/release-patch.sh v1.4.1

# Sync develop after PATCH release
make sync
```

### 9.2 Branch Comparison

| Branch | From | To | Lifetime | Direct push |
|---|---|---|---|---|
| `main` | — | — | Permanent | ❌ |
| `develop` | `main` (init) | `release/*` | Permanent | ⚠️ Maintainer |
| `feature/*` | `develop` | `develop` | Days-weeks | ✅ |
| `fix/*` | `develop` | `develop` | Hours-days | ✅ |
| `docs/*` | `develop` | `develop` | Hours | ✅ |
| `chore/*` | `develop` | `develop` | Hours-days | ✅ |
| `refactor/*` | `develop` | `develop` | Days | ✅ |
| `test/*` | `develop` | `develop` | Days | ✅ |
| `release/*` | `develop` | `main` | Days | ⚠️ Version only |
| `hotfix/*` | `main` | `main` + `develop` | Hours | ✅ |

### 9.3 PR Template Selection

| Source branch | Base | Template |
|---|---|---|
| `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*` | `develop` | Default (`.github/PULL_REQUEST_TEMPLATE.md`) |
| `release/*`, `hotfix/*` | `main` | Release (`?template=release.md`) |

### 9.4 Common Mistakes

| ❌ Don't | ✅ Do |
|---|---|
| Push directly to `main` | Use a `release/*` branch + PR |
| Branch from `main` for features | Branch from `develop` |
| Mix features in one branch | One branch = one purpose |
| Skip the CHANGELOG | Update `CHANGELOG.md` |
| Force-push a shared branch | Only force-push your own `feature/*` |
| Merge `develop` into `main` directly | Use `release/*` or `release.sh` |
| Forget to back-merge hotfixes | Run `make sync` after PATCH releases |
| Use `merge commits` | Squash merge only |
| Use the default template for releases | Use `?template=release.md` |
| Enable `Restrict creations` without a Bypass entry | Add `Repository admin` to the Bypass list (see §6.3) |
| Edit a `txn-*` directory manually | Let `main.go` + `service.sh` handle cleanup (see [`BACKUP.md`](BACKUP.md) §10.5) |
| Add an English string without the matching Arabic entry | Add both `en` and `ar` entries in the `translations` object |
| Prune the `.last_stable` target manually | Let `rotate_backups` handle rotation — ROT-PROTECT keeps this target alive (see [`ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.2) |
| Create a snapshot without `.manifest.json` | Every snapshot must have a manifest — SNAP-MANIFEST / ROT-MANIFEST requires it (see [`ARCHITECTURE.md`](ARCHITECTURE.md) §4.13.1) |

---

## 10. References

### 10.1 Related Documentation

| Document | Content |
|---|---|
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Full contribution guide |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer setup and daily workflow |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Step-by-step release process |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide (§3.0, §3.1, §3.2) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections (§5.31–§5.35) |
| [`docs/BACKUP.md`](BACKUP.md) | **Backup system reference (v1.2.0 + v1.3.0 rotation semantics)** |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | **Emergency recovery (v1.2.0)** |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture (§3.10, §4.10) |
| **[`docs/ARCHITECTURE.md` §4.13](ARCHITECTURE.md)** | **v1.3.0 server-side refinements (SNAP-* / ROT-* — authoritative)** |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Device matrix + on-device SNAP-*/ROT-* verification (§10.3.5) |
| [`docs/API.md`](API.md) | HTTP API reference (§6.1.7) |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (v1.0.0 → v1.4.0) |
| [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) | Community guidelines |
| [`docs/ROADMAP.md`](ROADMAP.md) | Future plans |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Terms and abbreviations |

### 10.2 ADRs Referenced

| ADR | Title |
|---|---|
| [ADR-0001](adr/0001-two-branch-model.md) | Two-branch model (`main` + `develop`) |
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `scripts/release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0004](adr/0004-unified-pr-template.md) | Unified PR template (⚠️ Superseded) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

### 10.3 Project Files

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Build matrix + linting + backup smoke test + companion app metadata |
| `.github/workflows/codeql.yml` | SAST security scanning |
| `.github/workflows/release.yml` | Release automation + sync + APK fetch/stage |
| `.github/workflows/upgrade-test.yml` | 42-scenario data-preservation matrix |
| `.github/CODEOWNERS` | Auto-assign reviewers |
| `.github/PULL_REQUEST_TEMPLATE.md` | Default PR template |
| `.github/PULL_REQUEST_TEMPLATE/release.md` | Release PR template |
| `.github/dependabot.yml` | Dependency updates |
| `scripts/release.sh` | Full release automation |
| `scripts/release-patch.sh` | PATCH-release automation (3 safety rules) |
| `scripts/fetch_app_apk.sh` | **Companion APK fetcher (v1.4.0)** |
| `scripts/package_module.sh` | Module packaging (with optional APK) |
| `Makefile` | `make release`, `make release-patch`, `make sync`, `make fetch-apk`, `make check-app-version` |
| `VERSION` | Single source of truth (module version) |
| `proxy/app-apk.version` | **Single source of truth (companion app version, v1.4.0)** |
| `proxy/main.go` | **SNAP-MANIFEST + SNAP-MTIME in `buildBackupInfo` (v1.3.0)** |
| `proxy/functions.sh` | **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT in `rotate_backups` (v1.3.0)** |
| `proxy/service.sh` | **Boot-path DNS auto-start (§[19], v1.3.0)** |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |
| `docs/UPGRADE.md` | Version upgrade guide |
| `docs/BACKUP.md` | Backup system reference (v1.2.0 + v1.3.0 rotation) |
| `docs/EMERGENCY.md` | Emergency recovery (v1.2.0) |
| `docs/ARCHITECTURE.md` §4.13 | v1.3.0 server-side refinements (authoritative) |
| `docs/COMPATIBILITY.md` §10.3.5 | On-device SNAP-*/ROT-* verification procedure |

### 10.4 External Resources

- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Git Flow (Vincent Driessen)](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [GitHub Rulesets — Bypass list](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-ruleset)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Companion app repository — gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)

---

*Last updated: 2026-10-08*
*Version: v1.4.0*
*Author: gasciljh*
