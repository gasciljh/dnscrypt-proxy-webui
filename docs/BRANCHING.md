# Branching Strategy — DNSCrypt Smart Filter

Complete guide to the project's Git workflow: branches, naming
conventions, merge rules, and protection policies.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • `Last updated` reflects the v1.1.0 release date.
>   • Release examples updated from `v1.1.0` (which is now the
>     current release) to `v1.2.0` (the next planned release).
>   • Hotfix examples updated from `v1.0.1` to `v1.1.1` — the
>     first realistic PATCH release from `v1.1.0`.
>   • `Related Documentation` now includes `docs/UPGRADE.md`
>     (added as a first-class reference in v1.1.0).
>   • `Project Files` table extended with `docs/UPGRADE.md`.
>   • No changes to the core branching strategy — the two-branch
>     model, naming rules, and protection policy are unchanged.

> **📖 Related documents**:
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Contribution guide → [`docs/CONTRIBUTING.md`](CONTRIBUTING.md)
> - Upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)

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
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

**Current ADR count**: 6 (5 accepted + 1 superseded).

The `release-patch.sh` script named in ADR-0006 is now in active
use — for example, `v1.1.0 → v1.1.1` would be a PATCH release
processed by that script (see §8).

Full index: [`docs/adr/README.md`](adr/README.md).

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

Current state: `v1.1.0` (released 2026-09-26).

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

### 2.6 `release/*` — Release Preparation

| Aspect | Value |
|---|---|
| **Purpose** | Freeze `develop`, bump version, prepare a release. |
| **Lifetime** | Days (until release is published). |
| **Created from** | `develop`. |
| **Merges into** | `main` (via PR). |
| **Direct push** | ⚠️ Only version bumps allowed. |
| **Requires PR** | ✅ Yes, with 1 approval + CI pass. |

**Example**: `release/v1.2.0`, `release/v2.0.0`.

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

**Example**: `hotfix/v1.1.1-login-bypass`.

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
| `release/` | Release preparation | `release/v1.2.0` |
| `hotfix/` | Emergency fix | `hotfix/v1.1.1-login-bypass` |
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
release/v1.2.0          ✅
release/v1.2.0-beta1    ✅
release/1.2.0           ❌ (missing 'v')
release/v1.2            ❌ (incomplete)
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
3. git checkout -b release/v1.2.0
4. ./scripts/release.sh v1.2.0 --no-push     # updates VERSION + module.prop + update.json
5. Verify: git diff
6. Update CHANGELOG.md: add ## [1.2.0] - YYYY-MM-DD section
7. git commit -m "release: v1.2.0"
8. git push -u origin release/v1.2.0
9. Open PR → main using ?template=release.md
10. Wait for CI + CodeQL to pass
11. Approve + merge
12. git checkout main && git pull origin main
13. ./scripts/release.sh v1.2.0                # now push: creates tag
14. GitHub Actions publishes the release
15. It auto-syncs main → develop
```

**Simpler alternative**: skip the `release/*` branch, and run
`release.sh` directly from `develop`:

```text
1. git checkout develop
2. git pull origin develop
3. ./scripts/release.sh v1.2.0                # interactive, with confirmation
4. Wait for GitHub Actions
```

Use the `release/*` flow when you need a **stabilization window**.

### 4.5 Hotfix (Emergency)

```text
1. git checkout main
2. git pull origin main
3. git checkout -b hotfix/v1.1.1-critical-fix
4. ... fix ...
5. git commit -m "fix(critical): patch login bypass"
6. git push -u origin hotfix/v1.1.1-critical-fix
7. Open PR → main using ?template=release.md (fast-track review)
8. Squash merge
9. Tag + push:
   ./scripts/release-patch.sh v1.1.1
10. After release publishes: back-merge main → develop
    make sync
```

**Fast-track**: hotfix PRs can be merged with a single review, and
CI failures can be waived by the maintainer if the fix is critical.

**Full details**: [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) §2.3
and §9.

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
- ✅ **No merge conflicts** with the target branch.
- ✅ **PR template completed** (`.github/PULL_REQUEST_TEMPLATE.md`).
- ✅ **CHANGELOG.md** updated (if user-facing).
- ✅ **Documentation** updated (if applicable).

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
https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.2.0?template=release.md
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

**Required status checks** (same as `main`).

### 6.3 Tags

Configure at **Settings → Tags → Protected tags**:

| Setting | Value |
|---|---|
| **Tag name pattern** | `v*` |
| Restrict who can create | Maintainer only |
| Restrict who can delete | ❌ Nobody |

**Why**: prevents accidental deletion of release tags.

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

### 7.2 What Runs on Each Branch

| Branch | CI | CodeQL | Release |
|---|:---:|:---:|:---:|
| `feature/*` | ✅ (via PR) | ✅ (via PR) | ❌ |
| `fix/*` | ✅ (via PR) | ✅ (via PR) | ❌ |
| `docs/*` | ⏭️ Skipped (`paths-ignore`) | ✅ | ❌ |
| `develop` | ✅ | ✅ | ❌ |
| `release/*` | ✅ | ✅ | ❌ |
| `main` | ✅ | ✅ | ✅ (on tag) |
| `hotfix/*` | ✅ (via PR) | ✅ | ❌ |

### 7.3 Release Automation

When you run:

```bash
./scripts/release.sh v1.2.0
```

The script pushes a tag → `release.yml` triggers → publishes the
release → **automatically syncs `main → develop`**.

For PATCH releases:

```bash
./scripts/release-patch.sh v1.1.1
```

Same pipeline, but with 3 safety rules enforced (see
[ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)).

Full process: [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md).

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

**Current context (v1.1.0)**: The first realistic hotfix scenario
would be `v1.1.0 → v1.1.1`. The chain of releases is:

| From | To | Type |
|---|---|---|
| `v1.0.0` | `v1.1.0` | MINOR (features) |
| `v1.1.0` | `v1.1.1` | PATCH (hotfix) |
| `v1.1.1` | `v1.2.0` | MINOR (features) |

### 8.2 Hotfix Steps

```text
1. git checkout main
2. git pull origin main
3. git checkout -b hotfix/v1.1.1-login-bypass
4. ... minimal fix ...
5. git commit -m "fix(auth): patch login bypass"
6. git push -u origin hotfix/v1.1.1-login-bypass
7. Open PR → main using ?template=release.md
8. Fast-track review + merge
9. Prepare the PATCH release:
   ./scripts/release-patch.sh v1.1.1
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
| `v1.1.2` | Fix critical bug | `v1.1.3` |

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

### 8.5 PATCH-Release Script

| Aspect | Value |
|---|---|
| **Script** | `scripts/release-patch.sh` |
| **Usage** | `./scripts/release-patch.sh v1.1.1` |
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
git checkout -b release/v1.2.0
./scripts/release.sh v1.2.0 --no-push
# ... update CHANGELOG.md ...
git commit -m "release: v1.2.0"
git push -u origin release/v1.2.0
# → Open PR against main using ?template=release.md

# Publish (from main after merge)
git checkout main && git pull
./scripts/release.sh v1.2.0

# Hotfix
git checkout main && git pull
git checkout -b hotfix/v1.1.1-critical
# ... fix ...
git push -u origin hotfix/v1.1.1-critical
# → Open PR against main using ?template=release.md

# Prepare the PATCH release (after merge)
./scripts/release-patch.sh v1.1.1

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

---

## 10. References

### 10.1 Related Documentation

| Document | Content |
|---|---|
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Full contribution guide |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer setup and daily workflow |
| [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) | Step-by-step release process |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy + Audit Corrections |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture |
| [`docs/API.md`](API.md) | HTTP API reference |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting guide |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (including v1.1.0) |
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
| `.github/workflows/ci.yml` | Build matrix + linting |
| `.github/workflows/codeql.yml` | SAST security scanning |
| `.github/workflows/release.yml` | Release automation + sync |
| `.github/CODEOWNERS` | Auto-assign reviewers |
| `.github/PULL_REQUEST_TEMPLATE.md` | Default PR template |
| `.github/PULL_REQUEST_TEMPLATE/release.md` | Release PR template |
| `.github/dependabot.yml` | Dependency updates |
| `scripts/release.sh` | Full release automation |
| `scripts/release-patch.sh` | PATCH-release automation (3 safety rules) |
| `Makefile` | `make release`, `make release-patch`, `make sync` |
| `VERSION` | Single source of truth (version) |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |
| `docs/UPGRADE.md` | Version upgrade guide |

### 10.4 External Resources

- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Git Flow (Vincent Driessen)](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

---

*Last updated: 2026-09-26*
*Version: v1.1.0*
*Author: gasciljh*