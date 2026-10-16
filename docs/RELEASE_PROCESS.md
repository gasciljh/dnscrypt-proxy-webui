# Release Process — DNSCrypt Smart Filter

Step-by-step guide to publishing a new release: from version bump
to post-release verification.

**Version**: v1.4.0
**Last updated**: 2026-10-08
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **Identifier inventory in this file (5 total)**:
>   • HARD-RPR-01 (v1.3.0 block extended with server-side
>     rotation refinements — v1.4.0)
>   • HARD-RPR-02 (§2.5 v1.3.0 row extended with rotation
>     refinements — v1.4.0)
>   • HARD-RPR-03 (§1.6 Runtime additions table extended —
>     v1.4.0)
>   • HARD-RPR-04 (§12.1 References extended with §4.13 +
>     §10.3.5 — v1.4.0)
>   • HARD-RPR-05 (Header + footer `Last updated` sync to
>     2026-10-08 — v1.4.0)
>
> **Cross-references**:
>   • [docs/ARCHITECTURE.md §4.13](ARCHITECTURE.md) — v1.3.0
>     server-side refinements (authoritative)
>   • [docs/COMPATIBILITY.md §10.3.5](COMPATIBILITY.md) — on-device
>     SNAP-*/ROT-* verification procedure
>   • [docs/GLOSSARY.md](GLOSSARY.md) — SNAP-*/ROT-* terms,
>     Rotation Guardian badge
>   • [docs/BACKUP.md](BACKUP.md) — backup system reference
>   • [docs/EMERGENCY.md](EMERGENCY.md) — emergency recovery
>   • [docs/BRANCHING.md](BRANCHING.md) — Git branching strategy
>   • [docs/adr/README.md](adr/README.md) — Architecture Decision
>     Records
>   • [CHANGELOG.md](../CHANGELOG.md) — version history

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • `Last updated` reflects the v1.4.0 file-editing date
>     (2026-10-08).
>   • Release examples updated from `v1.3.0` (now the previous
>     release) to `v1.4.0` (the current stable release).
>   • PATCH-release examples updated from `v1.2.1` to `v1.4.1`.
>   • `versionCode` table extended with `v1.4.0` (`1040000`).
>   • **§1.2** — Release artifacts corrected: 6 → **8 files**
>     (the two companion APK entries were missing).
>   • **§1.3** — The behind-the-scenes flow chart was rewritten:
>     the previous version listed "Generate SBOM" and "Sign with
>     Cosign" steps that **do not exist**. Both were removed and
>     replaced with the actual v1.4.0 steps ("Fetch companion
>     APK" + "Stage APK for module ZIP"). The
>     `git tag -s` ("signed tag") description was corrected to
>     `git tag -a` (**annotated** tag).
>   • **§7.2** — Pipeline step count corrected: 11 → **16 steps**
>     (was outdated since v1.2.0). Added the four missing steps:
>     "Verify tag exists", "Fetch companion APK", "Stage APK for
>     module ZIP", "Extract CHANGELOG section".
>   • **§7.3** — `dist/` contents updated: added
>     `DNS-Proxy-v1.0.0.apk` + `.sha256`.
>   • **§8.4** — "Verify Cosign Signature" section **removed**
>     (the release is NOT signed). Replaced with an explicit note
>     that no signature exists yet, pointing to the `release.yml`
>     Non-goals section.
>   • **§8.5** — "Verify SBOM" section **removed** (no SBOM is
>     produced). Replaced with an explicit note.
>   • **§8.3** — Added verification steps for the watchdog token
>     (§[15]) and the companion APK route (§[16]).
>   • **§11.7** — Post-release checklist corrected: removed
>     Cosign + SBOM entries, added companion APK verification.
>   • **§12.1** — CHANGELOG.md version range corrected from
>     "v1.0.0 → v1.2.0" to "v1.0.0 → v1.4.0".
>   • **§12.3** — Added `scripts/fetch_app_apk.sh` to the project
>     files table.
>   • **§12.4** — Removed Cosign / SPDX / CycloneDX from the
>     external resources list (none are used). Added the
>     companion app repository.

> **v1.3.0 changes** (historical):
>   • Version bumped from v1.2.0 to v1.3.0.
>   • Release examples updated from `v1.2.0` to `v1.3.0`.
>   • PATCH-release examples updated from `v1.2.1` to `v1.3.1`.
>   • `versionCode` table extended with `v1.3.0` (`1030000`).
>   • No structural changes to the release pipeline.
>   • **Client-side additions**:
>       - **PWA install button** — dynamic, always-visible,
>         browser-aware (client-side only; see `web/index.html`).
>         *(Repurposed in v1.4.0 — the button now points at
>         `/app-debug.apk`.)*
>       - **Live status LED** on the Today counter (client-side).
>   • **Boot-path correctness fix** — `service.sh` now calls
>     `POST /api/ensure_running_service` directly after boot,
>     bounded by a wait for the WebUI port. No install-time
>     change.
>   • **Server-side rotation refinements** — the v1.3.0 release
>     ALSO refined the snapshot-detection and rotation semantics
>     that underpin the persistent backup directory. Five
>     identifiers document the change (also used in
>     `CHANGELOG.md` [v1.3.0] and `docs/ARCHITECTURE.md` §4.13):
>
>       🔧 **SNAP-MANIFEST** — `main.go:buildBackupInfo()` now
>         detects a snapshot by the presence of a
>         `.manifest.json` file, not by the v1.2.0 name pattern.
>
>       🔧 **SNAP-MTIME** — `last_backup_name` is now selected
>         by **mtime** (descending). This supersedes the v1.2.0
>         BUG-3 lexicographic-name rule.
>
>       🔧 **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** —
>         `functions.sh:rotate_backups()` was rewritten with the
>         same manifest-based detection, the same mtime sort, and
>         **two additional protected targets** on top of the
>         21-newest window: the `.last_stable` recovery pointer
>         and the newest install snapshot (name matching
>         `-v<digit>`).
>
>     The same SNAP-*/ROT-* semantics were mirrored in 5 shell
>     scripts (`service.sh`, `watchdog.sh`, `status.sh`,
>     `customize.sh`, `action.sh`) and in `uninstall.sh`.
>   • **No release-pipeline change** — the v1.3.0 rotation
>     refinements touched `.go` and `.sh` files only; the
>     pipeline does not inspect their internal semantics. The
>     workflow still builds the same 4 architectures, packages
>     the same ZIP, and publishes the same 6 assets. (The
>     companion APK was added in v1.4.0 as the 7th and 8th
>     assets.)

> **v1.2.0 changes** (historical):
>   • Version bumped from v1.1.0 to v1.2.0.
>   • Release examples updated from `v1.2.0` (now the current
>     release) to `v1.3.0` (the next planned stable release).
>   • PATCH-release examples updated from `v1.1.1` to `v1.2.1` —
>     the first realistic PATCH release from `v1.2.0`.
>   • `versionCode` table extended with `v1.2.0`, `v1.2.1`, and
>     `v1.3.0` for easy reference during the current cycle.
>   • `Related documents` box now includes `docs/BACKUP.md`,
>     `docs/EMERGENCY.md`, and `docs/UPGRADE.md`.
>   • `§1.6` renamed from "v1.1.0 Reference" to
>     "v1.2.0 Reference".
>   • `§2.5 Current and Next Versions` updated.
>   • `§8.3 Verify on Device` extended with the v1.2.0 checks
>     (backup layer, 7-field `runtime_info.backups`).
>   • `§10.5` renamed to "v1.2.0 Sync Note".
>   • No structural changes to the release pipeline.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.

> **📖 Related documents**:
> - Git branching strategy → [`docs/BRANCHING.md`](BRANCHING.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Contribution guide → [`docs/CONTRIBUTING.md`](CONTRIBUTING.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Release Types](#2-release-types)
3. [Versioning Rules](#3-versioning-rules)
4. [Files to Update](#4-files-to-update)
5. [Using release.sh](#5-using-releasesh)
6. [Manual Release (Fallback)](#6-manual-release-fallback)
7. [GitHub Actions Flow](#7-github-actions-flow)
8. [Post-Release Verification](#8-post-release-verification)
9. [Rollback & Emergency](#9-rollback--emergency)
10. [Post-Release Sync](#10-post-release-sync)
11. [Quick Reference](#11-quick-reference)
12. [References](#12-references)

---

## 1. Overview

### 1.1 Goal

Publish a **reproducible, verifiable, annotated** release that
users can download and install with confidence.

> **Note on signing**: As of v1.4.0 the release artifacts are
> **NOT signed** (neither GPG nor Cosign). The tag is created
> **annotated** (`git tag -a`) — not signed (`git tag -s`). See
> `release.yml` §Non-goals for the full statement.

### 1.2 What a Release Includes

Every release publishes **8 artifacts** (v1.4.0):

| # | Artifact | Size | Purpose |
|:-:|---|---|---|
| 1 | `dnscrypt-webui-<ver>-module.zip` | ~15 MB | Magisk module (all-in-one, includes companion APK) |
| 2 | `dnscrypt-webui-<ver>-module.zip.sha256` | ~100 B | Integrity check |
| 3 | `dnscrypt-webui-arm64` | ~8 MB | Standalone WebUI binary |
| 4 | `dnscrypt-webui-arm` | ~7 MB | Standalone WebUI binary |
| 5 | `dnscrypt-webui-amd64` | ~7.5 MB | Standalone WebUI binary |
| 6 | `dnscrypt-webui-386` | ~7 MB | Standalone WebUI binary |
| 7 | `DNS-Proxy-v<app-ver>.apk` | ~3 MB | Companion Android app (**optional**, v1.4.0) |
| 8 | `DNS-Proxy-v<app-ver>.apk.sha256` | ~100 B | Companion APK checksum (**optional**, v1.4.0) |

**Optional artifacts** (#7 and #8): only attached when the
companion APK was successfully fetched by
`scripts/fetch_app_apk.sh`. A failed fetch logs a warning and
does **not** fail the release.

### 1.3 What Happens Behind the Scenes

```text
Developer runs release.sh (or release-patch.sh)
        │
        ▼
Update VERSION + module.prop + update.json
        │
        ▼
Commit "release: vX.Y.Z"
        │
        ▼
Create ANNOTATED tag vX.Y.Z   (git tag -a)
        │
        ▼
Push branch + tag to origin
        │
        ▼
GitHub Actions (release.yml) triggers on tag
        │
        ├── Setup Go + NDK
        ├── Determine + validate version
        ├── Verify tag exists (dispatch only)
        ├── Fetch companion Android app APK   ← v1.4.0
        ├── Build 4 architectures
        ├── Verify ELF + PIE
        ├── Stage APK for module ZIP          ← v1.4.0
        ├── Package Magisk ZIP
        ├── List final artifacts
        ├── Upload artifacts (backup)
        ├── Extract CHANGELOG section
        ├── Create GitHub Release
        └── Sync main → develop
        │
        ▼
Release is live ✅
```

**Total time**: ~3-5 minutes.

> **What is NOT done** (see `release.yml` §Non-goals):
> - ❌ No GPG signing
> - ❌ No Cosign signature
> - ❌ No SBOM
> - ❌ No `update.json` modification (that is done locally by
>   `release.sh` before the tag is pushed)

### 1.4 Prerequisites

Before releasing, ensure:

- ✅ You are on `develop` or a `release/*` branch (see
  [`docs/BRANCHING.md`](BRANCHING.md)).
- ✅ Working tree is clean (`git status`).
- ✅ `CHANGELOG.md` has an entry for the new version.
- ✅ CI is green on the current branch.
- ✅ All PRs for this release are merged.
- ✅ `proxy/app-apk.version` is up to date (v1.4.0).

**Tools required**:

| Tool | Purpose | Install |
|---|---|---|
| `git` | Version control | Pre-installed |
| `sed` | Text manipulation | Pre-installed |
| `awk` | Parsing | Pre-installed |
| `jq` | JSON manipulation | `apt install jq` / `brew install jq` |
| `curl` | Fetch companion APK | Pre-installed |

### 1.5 Architecture Decisions

The decisions that shaped the release process are documented as
**ADRs**:

| ADR | Decision |
|---|---|
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

Full index: [`docs/adr/README.md`](adr/README.md).

### 1.6 v1.4.0 Reference

The v1.4.0 release (2026-10-06) serves as the most recent concrete
example of this process. Key facts:

| Aspect | Value |
|---|---|
| Version | `v1.4.0` |
| `versionCode` | `1040000` |
| Type | MINOR (companion app + CodeQL) |
| Branch | `release/v1.4.0` → `main` |
| Audit Corrections | None (registry remains at #33) |
| Runtime additions | Companion APK route (v1.4.0), watchdog token (v1.2.0) |
| Carried forward from v1.3.0 | Server-side rotation refinements (SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT) |
| Correctness fixes | CodeQL `go/path-injection` in `removeModule` (v1.4.0), iOS PWA removal (v1.4.0) |
| Data-preservation layers | 10 (unchanged since v1.2.0) |
| Release assets | **8 files** (2 optional) |

**Upgrade guide**: [`docs/UPGRADE.md`](UPGRADE.md) §3.2 — full
`v1.3.0 → v1.4.0` upgrade path.

**Companion app**: [`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app).

**Next planned release**: `v1.5.0` (see `docs/ROADMAP.md` §5).

---

## 2. Release Types

### 2.1 Stable Release

**Format**: `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v1.2.0`, `v1.4.0`)

| Aspect | Value |
|---|---|
| **When** | After a successful stabilization period. |
| **Branch** | `release/*` or directly from `develop`. |
| **Script** | `scripts/release.sh` |
| **Tag** | `v1.4.0` (no suffix). |
| **GitHub Release** | Marked as **latest**. |
| **Cadence** | Every 4-8 weeks. |

### 2.2 Prerelease

**Format**: `vMAJOR.MINOR.PATCH-<label>` (e.g. `v1.5.0-beta1`,
`v2.0.0-rc1`)

| Aspect | Value |
|---|---|
| **When** | For beta testing before a stable release. |
| **Branch** | `develop`. |
| **Script** | `scripts/release.sh` |
| **Tag** | `v1.5.0-beta1`. |
| **GitHub Release** | Marked as **pre-release**. |
| **Cadence** | As needed. |

**Note**: `versionCode` ignores the prerelease suffix (see §3.2).

### 2.3 Hotfix (PATCH Release)

**Format**: `vMAJOR.MINOR.PATCH+1` (e.g. `v1.4.1` after `v1.4.0`)

| Aspect | Value |
|---|---|
| **When** | Critical bug in a released version. |
| **Branch** | `hotfix/*` (from `main`). |
| **Script** | `scripts/release-patch.sh` ← **enforces 3 safety rules** |
| **Tag** | `v1.4.1`. |
| **GitHub Release** | Marked as **latest**. |
| **Cadence** | Immediate. |

**Safety rules enforced by `release-patch.sh`**:

1. **Branch must be `main`** — refuses to run from `develop`.
2. **`MAJOR` and `MINOR` must not change** — rejects non-PATCH bumps.
3. **`PATCH` must be exactly `current + 1`** — rejects skipping
   versions.

**Full rationale**: [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

See [`docs/BRANCHING.md`](BRANCHING.md) §8 for the full hotfix
workflow.

### 2.4 Comparison

| Type | Example | `versionCode` | Script | Latest? | Requires `release/*`? |
|---|---|:---:|:---:|:---:|:---:|
| Stable | `v1.4.0` | `1040000` | `release.sh` | ✅ | ⚠️ Recommended |
| Prerelease | `v1.5.0-beta1` | `1050000` | `release.sh` | ❌ | ❌ (from `develop`) |
| Hotfix (PATCH) | `v1.4.1` | `1040100` | `release-patch.sh` | ✅ | ❌ (from `main`) |

### 2.5 Current and Next Versions

| Version | Status | Notes |
|---|---|---|
| `v1.0.0` | Released (2026-09-24) | First stable release |
| `v1.1.0` | Released (2026-09-26) | Polish + MEM-1/2/3 |
| `v1.2.0` | Released (2026-09-29) | Data-preservation (10 layers) |
| `v1.3.0` | Released (2026-10-02) | PWA button + LED + DNS auto-start + rotation refinements (SNAP-*/ROT-*) |
| **`v1.4.0`** | **Released (2026-10-06)** | **Current — companion app + CodeQL + iOS removal** |
| `v1.4.1` | Planned (PATCH) | If a hotfix is needed |
| `v1.5.0` | Planned (MINOR) | Next feature release |

---

## 3. Versioning Rules

### 3.1 SemVer

The project follows
[Semantic Versioning 2.0.0](https://semver.org/):

```text
v<MAJOR>.<MINOR>.<PATCH>[-<prerelease>]

• MAJOR → breaking changes (rare)
• MINOR → new features (backward compatible)
• PATCH → bug fixes (backward compatible)
```

### 3.2 versionCode Formula

```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX
```

**Constraints**:
- `PATCH` must be **≤ 99** (2-digit reservation).
- `HOTFIX` must be **≤ 99**.
- Prerelease suffix is **ignored** (uses the same code as stable).

**Examples**:

| Version | versionCode | Notes |
|---|:---:|---|
| `v1.0.0` | `1000000` | First stable |
| `v1.0.1` | `1000100` | First hotfix |
| `v1.1.0` | `1010000` | Second stable (polish) |
| `v1.2.0` | `1020000` | Data-preservation |
| `v1.2.1` | `1020100` | (PATCH, never used) |
| `v1.3.0` | `1030000` | PWA + LED + DNS auto-start + rotation refinements |
| **`v1.4.0`** | **`1040000`** | **Current — companion app** |
| `v1.4.1` | `1040100` | Next PATCH (if needed) |
| `v1.5.0` | `1050000` | Next MINOR |
| `v1.5.0-beta1` | `1050000` | Same code (prerelease) |
| `v2.0.0` | `2000000` | Breaking change |
| `v10.5.3` | `10050300` | Double-digit MAJOR |

### 3.3 Why Two Version Schemes?

- **SemVer** (`v1.4.0`) — for GitHub Releases, docs, humans.
- **versionCode** (`1040000`) — for Magisk/KernelSU/APatch to detect
  updates.

**Rule**: `versionCode` must **strictly increase** with each release.
Never reuse.

### 3.4 Sanity Checks

Run these before tagging:

```bash
# 1. Format is valid
echo "v1.4.0" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$' && echo "✅ valid"

# 2. versionCode is greater than previous
grep '^versionCode=' module.prop

# 3. Version is not already tagged
git tag --list "v1.4.0"

# 4. VERSION matches the intended release
cat VERSION

# 5. Companion app version is well-formed (v1.4.0)
grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' proxy/app-apk.version && echo "✅ app-apk.version valid"
```

`scripts/release.sh` (and `scripts/release-patch.sh`) perform all
five automatically.

---

## 4. Files to Update

Every release updates **4 files** (plus an optional companion
version file for v1.4.0+):

### 4.1 `VERSION`

Single-line file, LF-only.

```text
v1.4.0
```

**Purpose**: Single Source of Truth for the module version.

### 4.2 `module.prop`

Magisk module definition.

```text
id=dnscrypt-proxy-webui
name=DNSCrypt Proxy (Smart Filter)
version=v1.4.0
versionCode=1040000
author=gasciljh
description=...
updateJson=https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/update.json
```

**Updated fields**: `version`, `versionCode`.

### 4.3 `update.json`

Auto-update metadata.

```json
{
  "version": "v1.4.0",
  "versionCode": 1040000,
  "zipUrl": "https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.4.0/dnscrypt-webui-1.4.0-module.zip",
  "changelog": "https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/CHANGELOG.md"
}
```

**Updated fields**: `version`, `versionCode`, `zipUrl`.

**Note**: `zipUrl` uses the tag as-is (`v1.4.0` in the URL path).
Magisk resolves the redirect.

### 4.4 `CHANGELOG.md`

Human-readable history.

```markdown
## [v1.4.0] - 2026-10-06

### Added
- ...

### Fixed
- ...

### Removed
- ...
```

**Manual update** — this file is not touched by `release.sh`.

### 4.5 `proxy/app-apk.version` (v1.4.0)

Single-line file, LF-only. Contains the version of the companion
Android app (e.g. `1.0.0`, **no `v` prefix**).

```text
1.0.0
```

**Purpose**: Single Source of Truth for the companion app version.
Read by `scripts/fetch_app_apk.sh` and verified by `ci.yml`
("Verify companion app metadata").

**Updated when**: the companion app in
[`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)
publishes a new release.

### 4.6 Summary Table

| File | Automated? | Notes |
|---|:---:|---|
| `VERSION` | ✅ `release.sh` / `release-patch.sh` | Single line |
| `module.prop` | ✅ Both scripts | `version` + `versionCode` |
| `update.json` | ✅ Both scripts (requires `jq`) | 3 fields |
| `CHANGELOG.md` | ❌ Manual | Human-edited |
| `proxy/app-apk.version` | ❌ Manual (v1.4.0) | Update only when the companion app changes |

---

## 5. Using release.sh

### 5.1 Overview

`scripts/release.sh` automates the mechanical parts of a release:

- ✅ Validates SemVer format.
- ✅ Computes `versionCode`.
- ✅ Checks branch + working tree + tag availability.
- ✅ Updates 3 files (with rollback on failure).
- ✅ Creates commit + tag.
- ✅ Pushes to `origin` (unless `--no-push`).

### 5.2 Standard Release (Recommended)

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Ensure CHANGELOG.md is updated
$EDITOR CHANGELOG.md

# 3. Run the script (interactive)
./scripts/release.sh v1.4.0

# 4. Confirm at the prompt
# → Script commits, tags, pushes
# → GitHub Actions publishes the release
```

**Behind the scenes**:

```text
✓ Checked environment (git, sed, awk, jq)
✓ Validated version: v1.4.0
✓ versionCode = 1040000
✓ On branch: develop
✓ Working tree is clean
✓ Tag v1.4.0 is available
✓ CHANGELOG.md contains [1.4.0] or [Unreleased]
✓ Updated VERSION
✓ Updated module.prop
✓ Updated update.json
✓ Commit created: release: v1.4.0
✓ Tag created: v1.4.0
✓ Pushed branch: develop
✓ Pushed tag: v1.4.0
```

### 5.3 Dry-Run (Preview)

```bash
./scripts/release.sh v1.4.0 --dry-run
```

**What it does**: prints what would happen, changes nothing.

**When to use**: before committing to a release, to double-check
`versionCode` and branch state.

### 5.4 Local-Only (No Push)

```bash
./scripts/release.sh v1.4.0 --no-push
```

**What it does**: creates the commit + tag locally, but does not push.

**When to use**: if you want to review before pushing:

```bash
# Review the change
git show HEAD
git tag -l v1.4.0

# Push manually when ready
git push origin develop
git push origin v1.4.0
```

### 5.5 Non-Interactive (CI/Scripts)

```bash
./scripts/release.sh v1.4.0 --yes
```

**What it does**: skips all confirmation prompts.

**When to use**: in automation scripts (rare — usually you want the
confirmation).

### 5.6 Prerelease

```bash
./scripts/release.sh v1.5.0-beta1
```

**Result**:
- `VERSION` = `v1.5.0-beta1`
- `versionCode` = `1050000` (prerelease suffix ignored)
- Tag = `v1.5.0-beta1`
- GitHub Release marked as **pre-release**

### 5.7 Using release-patch.sh

For **PATCH-only** releases (hotfixes) from `main`:

```bash
# 1. Start from main
git checkout main
git pull origin main

# 2. Run the script (interactive)
./scripts/release-patch.sh v1.4.1

# 3. Confirm at the prompt
# → Script enforces 3 safety rules
# → Delegates to release.sh for the actual bump
# → Reminds you to back-merge main → develop
```

**Safety rules** (from
[ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)):

1. **Branch must be `main`** — refuses to run from `develop`.
2. **`MAJOR` and `MINOR` must not change** — rejects non-PATCH bumps.
3. **`PATCH` must be exactly `current + 1`** — rejects skipping
   versions.

**Relationship to `release.sh`**:

```text
scripts/release.sh                 ← Full release logic
        ↑
        │ delegates to
        │
scripts/release-patch.sh           ← Wraps with 3 PATCH-only rules
```

`release-patch.sh` does **not** duplicate logic — it delegates to
`release.sh`.

**Post-release**: run `make sync` to back-merge `main → develop`.

### 5.8 release.sh Options Summary

| Option | Effect |
|---|---|
| `--dry-run` | Show what would happen, change nothing |
| `--no-push` | Create commit + tag locally, skip push |
| `--yes` / `-y` | Skip confirmation prompts |
| `--help` / `-h` | Show usage |

### 5.9 release-patch.sh Options Summary

Same as `release.sh` (both wrap the same option set):

| Option | Effect |
|---|---|
| `--dry-run` | Show what would happen, change nothing |
| `--no-push` | Create commit + tag locally, skip push |
| `--yes` / `-y` | Skip confirmation prompts |
| `--help` / `-h` | Show usage |

### 5.10 Exit Codes

Both scripts use the same exit codes:

| Code | Meaning |
|:---:|---|
| `0` | Success |
| `1` | Invalid arguments or missing tools |
| `2` | Repository state invalid (dirty, wrong branch, tag exists) |
| `3` | Version files inconsistent |
| `4` | User aborted |

### 5.11 What the Scripts Do NOT Do

- ❌ Does not modify `CHANGELOG.md` (manual).
- ❌ Does not modify `proxy/app-apk.version` (manual, v1.4.0).
- ❌ Does not run tests locally (CI will).
- ❌ Does not build binaries (GitHub Actions will).
- ❌ Does not fetch the companion APK (GitHub Actions will).
- ❌ Does not create the GitHub Release (GitHub Actions will).

---

## 6. Manual Release (Fallback)

If `release.sh` is unavailable or fails, do it manually:

```bash
# 1. Ensure you are on develop
git checkout develop
git pull origin develop

# 2. Update VERSION
echo "v1.4.0" > VERSION

# 3. Update module.prop
sed -i 's/^version=.*/version=v1.4.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1040000/' module.prop

# 4. Update update.json (manual edit)
$EDITOR update.json

# 5. Update CHANGELOG.md
$EDITOR CHANGELOG.md

# 6. (v1.4.0) Verify companion app version if you bumped it
cat proxy/app-apk.version

# 7. Verify
grep '^version' VERSION module.prop
jq '.version, .versionCode' update.json

# 8. Commit
git add VERSION module.prop update.json CHANGELOG.md
git commit -m "release: v1.4.0"

# 9. Tag (annotated)
git tag -a v1.4.0 -m "Release v1.4.0"

# 10. Push
git push origin develop
git push origin v1.4.0
```

**Warning**: manual process is error-prone. Prefer `release.sh` (or
`release-patch.sh` for PATCH releases).

---

## 7. GitHub Actions Flow

### 7.1 Trigger

`release.yml` triggers on:

```yaml
on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'
      - 'v[0-9]+.[0-9]+.[0-9]+-*'
```

**Any tag matching `vX.Y.Z` or `vX.Y.Z-*` starts a release.**

### 7.2 Pipeline Steps (16 steps, v1.4.0)

| # | Step | Duration | Output |
|:-:|---|---|---|
| 1 | `actions/checkout@v4` (fetch-depth 0) | ~5 s | Full history |
| 2 | `actions/setup-go@v5` | ~10 s | Go 1.22 |
| 3 | `nttld/setup-ndk@v1` | ~30 s | NDK r26b |
| 4 | Determine + validate version | ~2 s | `value`, `no_v` |
| 5 | Verify tag exists (dispatch only) | ~2 s | HARD-REL-12 |
| 6 | Install packaging tools | ~15 s | zip, unzip, jq, curl |
| 7 | **Fetch companion APK** | ~10 s | `dist/DNS-Proxy-v*.apk` (**v1.4.0**) |
| 8 | Build WebUI binaries | ~60 s | 4 binaries |
| 9 | Verify WebUI binaries | ~5 s | PIE + ELF check |
| 10 | **Stage APK for module ZIP** | ~2 s | `web/app-debug.apk` (**v1.4.0**) |
| 11 | Package Magisk module | ~30 s | `.zip` + `.sha256` |
| 12 | List final artifacts | ~2 s | `dist/` listing |
| 13 | Upload artifacts (backup) | ~20 s | 30-day retention |
| 14 | Extract CHANGELOG section | ~2 s | `/tmp/release_notes.md` |
| 15 | Create GitHub Release | ~10 s | Published |
| 16 | Sync `main → develop` | ~15 s | Post-release |

**Total**: ~3-5 minutes (plus runner setup ~30 s).

### 7.3 Artifacts Produced

```text
dist/
├── dnscrypt-webui-1.4.0-module.zip
├── dnscrypt-webui-1.4.0-module.zip.sha256
├── DNS-Proxy-v1.0.0.apk                   ← v1.4.0 (optional)
└── DNS-Proxy-v1.0.0.apk.sha256            ← v1.4.0 (optional)

proxy/build/
├── dnscrypt-webui-arm64
├── dnscrypt-webui-arm
├── dnscrypt-webui-amd64
├── dnscrypt-webui-386
└── checksums.txt
```

### 7.4 Post-Release Sync

After the release is created, `release.yml` **automatically** runs:

```bash
git fetch origin main
git fetch origin develop
git checkout -B develop origin/develop
git merge origin/main --ff-only   # or fallback to regular merge
git push origin develop
```

**Effect**: `develop` is now identical to `main` at the release
commit.

**Safety**: If the merge fails (conflict), the step **does not fail**
the release — it prints a warning and exits with `0`. Manual
resolution is required if this happens.

**Full rationale**: [ADR-0003](adr/0003-post-release-sync.md).

### 7.5 Job Failure

If any step fails:

- ❌ The release is **not** published.
- ⚠️ The tag remains on `origin`.
- ⚠️ `develop` is **not** synced.

**To retry**:

```bash
# Option A: re-run the workflow
gh run rerun <run-id>

# Option B: delete tag + retry
git push origin :refs/tags/v1.4.0
git tag -d v1.4.0
./scripts/release.sh v1.4.0
```

**To debug**:

```bash
# View logs
gh run view <run-id> --log

# Or in browser
# https://github.com/gasciljh/dnscrypt-proxy-webui/actions
```

---

## 8. Post-Release Verification

### 8.1 Automated (GitHub Actions)

The pipeline already verifies:

- ✅ All 4 architectures built.
- ✅ All 4 binaries are ELF.
- ✅ All 4 binaries are PIE (Android 5+ compatible).
- ✅ ZIP structure (33 entries — 32 required + 1 optional APK).
- ✅ SHA-256 file is created.
- ✅ Companion APK metadata (v1.4.0 — format + script presence).

### 8.2 Manual Verification Checklist

After the release is published:

- [ ] **GitHub Releases page** shows the new version.
- [ ] **Pre-release** flag is correct (for prereleases).
- [ ] **`latest`** flag is on stable releases only.
- [ ] **8 artifacts** attached (module.zip + .sha256 + 4 binaries + APK + APK.sha256).
- [ ] **Release notes** match the CHANGELOG section.
- [ ] **`CHANGELOG.md`** link works.

### 8.3 Verify on Device

Download the ZIP to a device and verify:

```bash
# 1. Check SHA-256
sha256sum -c dnscrypt-webui-1.4.0-module.zip.sha256

# 2. Install via Magisk Manager

# 3. Verify version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: v1.4.0 / 1040000

# 4. Verify WebUI works
curl -s http://127.0.0.1:9090/healthz
# → ok

# 5. Verify Dashboard JSON (Fix #1)
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
# → application/json

# 6. Verify runtime_info ports (PORT-2)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# → {"webui_port": "9090", "dashboard_port": "9091"}

# 7. Verify memory limit (MEM-1, v1.1.0)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
# → {"profile_key": "pro", "memory_limit_mb": 120}

# 8. Verify firewall has no orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0

# 9. Verify Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 Method Not Allowed

# 10. v1.2.0 — Verify backup layer (7-field object)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'
# → ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

# 11. v1.2.0 — Backup directory exists
su -c "ls -d /sdcard/dnscrypt-webui-backup/" && echo "✅ present"

# 12. v1.2.0 — Diagnostic tool works (Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -10

# 13. v1.2.0 — Bilingual WebUI (toggle present in all three pages)
for f in index.html dashboard.html offline.html; do
    su -c "grep -q 'id=\"langToggle\"' /data/adb/modules/dnscrypt-proxy-webui/web/$f && echo '✅ $f'"
done

# 14. v1.2.0 — 10 defensive layers present
su -c "grep -q 'CANDIDATE_SOURCES' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 1'"
su -c "grep -q 'PERSISTENT_BACKUP' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 2'"
su -c "grep -q 'begin_transaction' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 4'"
su -c "grep -q 'detect_root_solution' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 5'"
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 6'"
su -c "grep -q 'RECOVERY_MODE' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && echo '✅ Layer 7'"

# 15. v1.2.0 — Verify watchdog token (BUG-B)
su -c "test -s /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token && echo '✅ token present'"
curl -s -o /dev/null -w 'POST ensure_running (no token) → %{http_code}\n' \
  -X POST http://127.0.0.1:9090/api/ensure_running_service
# → 401 (without token and without user auth)

# 16. v1.4.0 — Verify companion APK route
curl -s -o /dev/null -w 'GET /app-debug.apk → %{http_code}\n' \
  http://127.0.0.1:9090/app-debug.apk
# → 200 (release build) or 404 (dev build)
su -c "test -s /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk && echo '✅ APK bundled'"

# 17. v1.4.0 — iOS PWA logic removed
su -c "grep -q 'isIOSDevice' /data/adb/modules/dnscrypt-proxy-webui/web/index.html \
  && echo '❌ still present' || echo '✅ removed'"

# 18. v1.4.0 — Install button direct link
su -c "grep -q 'href=\"/app-debug.apk\"' /data/adb/modules/dnscrypt-proxy-webui/web/index.html \
  && echo '✅ direct <a download> link'"
```

### 8.4 Signature / Attestation (status)

> ⚠️ **No signature is attached to the release artifacts as of
> v1.4.0.**
>
> An earlier revision of this document described a Cosign keyless
> verification flow (`cosign verify-blob` with a `.sig` and
> `.pem` pair). **That flow does NOT exist.** The release
> workflow (`.github/workflows/release.yml`) explicitly documents
> this in its **Non-goals** section:
>
> ```text
> • No GPG signing of the tag or the artifacts.
>   The tag is created ANNOTATED by release.sh (git tag -a),
>   not signed (git tag -s).
>
> • No Cosign signature. `cosign` is not invoked anywhere.
>
> • No SBOM. A software bill of materials is not generated.
>   The SHA256 file is the only integrity artifact attached
>   to the release.
> ```
>
> **What you CAN verify today**:
>
> 1. **SHA-256** — the `.sha256` release asset (§3.2 / §8.3).
>    This is the ONLY integrity check published with the
>    release.
> 2. **Source** — clone the repository and build the ZIP
>    yourself (see [`docs/DEVELOPMENT.md`](DEVELOPMENT.md)),
>    then compare the SHA-256 of your build with the release
>    asset. The build is reproducible when
>    `SOURCE_DATE_EPOCH` is set to the tag's commit time.
> 3. **Tag integrity** — the tag is created **annotated**
>    (`git tag -a`) by `scripts/release.sh`, not **signed**
>    (`git tag -s`). You can inspect the tag on GitHub.
>
> **If you need a signed release**, please open an issue to
> discuss the addition of Sigstore / Cosign. It is on the
> roadmap for a future release; it is NOT available now.

### 8.5 SBOM (status)

> ⚠️ **No SBOM is generated as of v1.4.0.**
>
> An earlier revision of this document described downloading
> `sbom.spdx.json` from the release assets. **That file does not
> exist.** The release workflow does not generate a Software
> Bill of Materials.
>
> **What you CAN verify instead**:
>
> 1. **`go.mod`** — the Go module dependencies are declared in
>    `proxy/go.mod`. Inspect it directly:
>
>    ```bash
>    cat proxy/go.mod
>    ```
>
> 2. **`go.sum`** — if present, contains the cryptographic
>    hashes of every Go module dependency:
>
>    ```bash
>    cat proxy/go.sum 2>/dev/null || echo "(no go.sum)"
>    ```
>
> 3. **`scripts/fetch_dns_binaries.sh`** — the dnscrypt-proxy
>    binaries are fetched from `DNSCrypt/dnscrypt-proxy`
>    releases with SHA-256 verification (`.manifest.json` in the
>    cache directory). The `dns-binaries.version` file pins the
>    version.
>
> 4. **`proxy/app-apk.version`** (v1.4.0) — pins the companion
>    app version, which is fetched from a separate repository.
>
> **If you need an SBOM**, please open an issue to discuss the
> addition of SPDX / CycloneDX generation. It is on the roadmap
> for a future release; it is NOT available now.

### 8.6 Verify update.json

```bash
curl -s https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/update.json | jq
```

**Expected**:

```json
{
  "version": "v1.4.0",
  "versionCode": 1040000,
  "zipUrl": "https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.4.0/dnscrypt-webui-1.4.0-module.zip",
  "changelog": "https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/CHANGELOG.md"
}
```

---

## 9. Rollback & Emergency

### 9.1 Rollback Scenarios

| Scenario | Action |
|---|---|
| Wrong versionCode | Delete tag + retry |
| Broken binary | Delete tag + fix + retry |
| Missing artifact | Re-run workflow |
| Wrong `VERSION` | Delete tag + retry |
| Bad CHANGELOG | Amend + force-push tag |
| GitHub Actions failure | Re-run workflow |
| **Missing companion APK** | **Re-run workflow (fetch is best-effort)** |

### 9.2 Delete a Tag

**Local + remote**:

```bash
# Local
git tag -d v1.4.0

# Remote
git push origin :refs/tags/v1.4.0
```

**Then delete the GitHub Release** (if created):

```bash
gh release delete v1.4.0 --yes
```

### 9.3 Amend a Release

If the release is published but has a minor issue:

**Option A — Add a fixup release** (recommended):

```bash
# Regular release:
./scripts/release.sh v1.4.1

# Or PATCH-only release from main:
git checkout main
./scripts/release-patch.sh v1.4.1
```

**Option B — Force-update the tag** (dangerous):

```bash
# Amend the commit
git commit --amend

# Force-update the tag
git tag -f v1.4.0 -m "Release v1.4.0"

# Force-push
git push origin :refs/tags/v1.4.0
git push origin v1.4.0
```

**Warning**: force-updating a tag breaks everyone who already
downloaded the release.

### 9.4 Revert a Release

If a release introduces a critical bug:

```bash
# 1. Revert the release commit on develop
git checkout develop
git revert <release-commit-sha>

# 2. Or manually reset
git revert --no-commit <release-commit-sha>
git commit -m "revert: rollback v1.4.0"

# 3. Publish a PATCH release from main
git checkout main
git checkout -b hotfix/v1.4.1-revert
# ... cherry-pick the revert ...
git commit -m "fix: revert v1.4.0 regression"
git push -u origin hotfix/v1.4.1-revert

# 4. Merge + prepare PATCH release
./scripts/release-patch.sh v1.4.1
```

### 9.5 Emergency Contacts

| Situation | Action |
|---|---|
| CI is broken | Fix + re-run workflow |
| Tag is protected | Update protection rules |
| Users report critical bug | PATCH release within 24 hours |
| Security vulnerability | Follow `docs/SECURITY.md` |
| Companion APK fetch fails | Re-run workflow (best-effort) |

### 9.6 What NOT to Do

- ❌ **Do not** delete `main`.
- ❌ **Do not** force-push `main` or `develop`.
- ❌ **Do not** edit `module.prop` manually after tagging.
- ❌ **Do not** republish the same tag.
- ❌ **Do not** skip CHANGELOG updates.
- ❌ **Do not** add signing steps to `release.yml` without
  updating this document (see §8.4).

---

## 10. Post-Release Sync

### 10.1 Automatic Sync (release.yml)

After every release, GitHub Actions runs:

```bash
git fetch origin main
git fetch origin develop
git checkout -B develop origin/develop
git merge origin/main --ff-only
git push origin develop
```

**Result**: `develop` now points to the release commit.

**Full rationale**: [ADR-0003](adr/0003-post-release-sync.md).

### 10.2 What if Sync Fails?

The sync step has `continue-on-error: true` — the release is **not**
failed.

**Common causes**:

| Cause | Solution |
|---|---|
| `develop` does not exist | Create it: `git checkout -b develop && git push -u origin develop` |
| Merge conflict | Resolve manually and push |
| Branch protection blocks bot | Adjust protection to allow `github-actions[bot]` |

### 10.3 Manual Sync (PATCH Releases)

For PATCH releases (`hotfix/*` branches), the sync is **manual**
because GitHub Actions cannot distinguish a hotfix tag from a regular
tag.

**Use the `make sync` target**:

```bash
make sync
```

**Or do it manually**:

```bash
git checkout develop
git pull origin develop
git merge origin/main --no-edit
git push origin develop
```

**Why this matters**: without syncing, `develop` will be missing the
hotfix, and the next `release/*` PR will reintroduce the bug.

### 10.4 Verify Sync

```bash
# Both should point to the same commit
git rev-parse origin/main
git rev-parse origin/develop

# Compare CHANGELOG
git log --oneline -1 origin/main
git log --oneline -1 origin/develop
```

### 10.5 v1.4.0 Sync Note

For the v1.4.0 release:

- **Automatic** via `release.yml` (since it went through
  `release/v1.4.0` → `main`).
- No manual `make sync` was needed.

For a **PATCH release from v1.4.0** (e.g. `v1.4.1` via `hotfix/*`):

- **Manual** `make sync` **is** required after the release publishes.

### 10.6 Historical Sync Notes

| Version | Sync type | Note |
|---|---|---|
| v1.2.0 | Automatic | Standard release path |
| v1.3.0 | Automatic | Standard release path |
| v1.4.0 | Automatic | Standard release path |

---

## 11. Quick Reference

### 11.1 Full Release Flow (Recommended)

```bash
# 1. Prepare
git checkout develop
git pull origin develop

# 2. Update CHANGELOG
$EDITOR CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs(changelog): prepare v1.4.0"

# 3. Preview
./scripts/release.sh v1.4.0 --dry-run

# 4. Execute
./scripts/release.sh v1.4.0

# 5. Wait (~5 min) → Release is live ✅
```

**Alternative flow with a `release/*` branch** (stabilization
window):

```bash
# 1. Create release branch
git checkout develop
git checkout -b release/v1.4.0

# 2. Prepare version bump locally
./scripts/release.sh v1.4.0 --no-push

# 3. Update CHANGELOG
$EDITOR CHANGELOG.md
git add -A
git commit -m "release: v1.4.0"

# 4. Push and open PR against main
git push -u origin release/v1.4.0
# → Open PR using ?template=release.md

# 5. After merge → tag + publish
git checkout main && git pull
./scripts/release.sh v1.4.0
```

### 11.2 PATCH Release Flow (Hotfix)

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/v1.4.1-critical

# 2. Fix
# ...

# 3. Commit + push
git commit -m "fix(critical): patch login bypass"
git push -u origin hotfix/v1.4.1-critical

# 4. Open PR against main using ?template=release.md
# 5. Merge

# 6. Prepare PATCH release
./scripts/release-patch.sh v1.4.1

# 7. Back-merge
make sync
```

### 11.3 Manual Release (Emergency)

```bash
echo "v1.4.0" > VERSION
sed -i 's/^version=.*/version=v1.4.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1040000/' module.prop
$EDITOR update.json
$EDITOR CHANGELOG.md
git add -A && git commit -m "release: v1.4.0"
git tag -a v1.4.0 -m "Release v1.4.0"
git push origin develop
git push origin v1.4.0
```

### 11.4 Rollback

```bash
# Delete tag
git push origin :refs/tags/v1.4.0
git tag -d v1.4.0

# Delete release
gh release delete v1.4.0 --yes

# Retry
./scripts/release.sh v1.4.0
```

### 11.5 Version Reference

| Action | MAJOR | MINOR | PATCH |
|---|:---:|:---:|:---:|
| Breaking change | +1 | → 0 | → 0 |
| New feature | — | +1 | → 0 |
| Bug fix | — | — | +1 |
| Hotfix (PATCH) | — | — | +1 |
| Prerelease | — | +1 | → 0 (with `-betaN`) |

**Current cycle reference**:

| From | To | Type | `versionCode` |
|---|---|---|:---:|
| `v1.0.0` | `v1.1.0` | MINOR | `1010000` |
| `v1.1.0` | `v1.2.0` | MINOR | `1020000` |
| `v1.2.0` | `v1.3.0` | MINOR | `1030000` |
| `v1.3.0` | `v1.4.0` | MINOR | `1040000` |
| `v1.4.0` | `v1.4.1` | PATCH | `1040100` |
| `v1.4.1` | `v1.5.0` | MINOR | `1050000` |

### 11.6 Files Checklist

- [ ] `VERSION` → `v1.4.0`
- [ ] `module.prop` → `version=v1.4.0`, `versionCode=1040000`
- [ ] `update.json` → 3 fields
- [ ] `CHANGELOG.md` → new section
- [ ] `proxy/app-apk.version` → `1.0.0` (v1.4.0, if companion bumped)

### 11.7 Post-Release Checklist

- [ ] GitHub Release published
- [ ] **8 artifacts** attached (2 optional: APK + APK.sha256)
- [ ] `develop` synced with `main`
- [ ] `update.json` deployed on `main`
- [ ] Device test passed
- [ ] Backup layer verified (7-field object)
- [ ] Watchdog token verified (§8.3 step 15)
- [ ] Companion APK route verified (§8.3 step 16)
- [ ] CHANGELOG section matches release notes
- [ ] (optional) Re-run workflow if companion APK fetch failed

### 11.8 Script Comparison

| Aspect | `release.sh` | `release-patch.sh` |
|---|---|---|
| **Purpose** | Stable / Prerelease | Hotfix (PATCH only) |
| **Branch** | `develop` or `release/*` | **`main`** (enforced) |
| **MAJOR** | Allowed | ❌ Rejected |
| **MINOR** | Allowed | ❌ Rejected |
| **PATCH** | Allowed | ✅ Required (exact +1) |
| **Delegates to** | — | `release.sh` |
| **ADR** | [ADR-0002](adr/0002-automated-releases.md) | [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) |

---

## 12. References

### 12.1 Related Documentation

| Document | Content |
|---|---|
| [`docs/BRANCHING.md`](BRANCHING.md) | Git branching strategy |
| [`docs/adr/README.md`](adr/README.md) | Architecture Decision Records index |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) | Developer setup |
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide (§3.0, §3.1, §3.2) |
| [`docs/BACKUP.md`](BACKUP.md) | Backup system reference (v1.2.0) |
| [`docs/EMERGENCY.md`](EMERGENCY.md) | Emergency recovery (v1.2.0) |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy (§5.31, §5.32) |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture (§3.10, §4.10, §4.12, **§4.13 — v1.3.0 rotation refinements**, §6.8) |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix (**§10.3.5 — on-device SNAP-*/ROT-* verification**) |
| [`docs/API.md`](API.md) | HTTP API reference (§6.1.7, §6.1.15, §2.8) |
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide (§8.6 companion app) |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions (Q121–Q130) |
| [`docs/ROADMAP.md`](ROADMAP.md) | Future plans |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Terms and abbreviations (SNAP-*/ROT-*, Rotation Guardian) |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history (v1.0.0 → v1.4.0) |
| [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) | Community guidelines |

### 12.2 ADRs Referenced

| ADR | Title |
|---|---|
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `scripts/release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

### 12.3 Project Files

| File | Purpose |
|---|---|
| `VERSION` | Single source of truth (module version) |
| `module.prop` | Magisk module definition |
| `update.json` | Auto-update metadata |
| `CHANGELOG.md` | Version history |
| `proxy/app-apk.version` | **Companion app version (v1.4.0)** |
| `proxy/dnscrypt-proxy.version` | DNS engine version |
| `scripts/release.sh` | Full release automation |
| `scripts/release-patch.sh` | PATCH-release automation (3 safety rules) |
| `scripts/package_module.sh` | Build Magisk ZIP |
| `scripts/fetch_dns_binaries.sh` | Fetch dnscrypt-proxy binaries |
| `scripts/fetch_app_apk.sh` | **Fetch companion APK (v1.4.0)** |
| `scripts/generate-icons.sh` | Generate PNG/ICO icons |
| `proxy/build.sh` | Cross-compile WebUI binaries |
| `proxy/functions.sh` | **rotate_backups — ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (v1.3.0)** |
| `proxy/main.go` | **buildBackupInfo — SNAP-MANIFEST + SNAP-MTIME (v1.3.0)** |
| `proxy/service.sh` | Boot-path DNS auto-start (v1.3.0) |
| `proxy/watchdog.sh` | **Snapshot counter — manifest-based (v1.4.0 WD-V14-03)** |
| `proxy/status.sh` | **`_list_snapshots` — SNAP-MANIFEST + SNAP-MTIME (v1.3.0)** |
| `proxy/action.sh` | **`_inline_list_snapshots` — v1.3.0 semantics** |
| `proxy/customize.sh` | **`rotate_backups` — v1.3.0 semantics** |
| `proxy/uninstall.sh` | **`§[5b]` snapshot count — SNAP-MANIFEST** |
| `Makefile` | `make release`, `make release-patch`, `make sync`, `make fetch-apk` |
| `.github/workflows/ci.yml` | Build + lint CI |
| `.github/workflows/codeql.yml` | SAST security scanning |
| `.github/workflows/release.yml` | Release automation + sync |
| `.github/workflows/upgrade-test.yml` | 42-scenario data-preservation matrix (v1.2.0) |

### 12.4 External Resources

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Magisk Module Structure](https://topjohnwu.github.io/Magisk/guides.html)
- [KernelSU Documentation](https://kernelsu.org/)
- [APatch](https://github.com/bmax121/APatch)
- [gasciljh/dnscrypt-proxy-app (companion app)](https://github.com/gasciljh/dnscrypt-proxy-app)

> **Note**: Cosign, SPDX, and CycloneDX are **NOT** used by this
> project. See §8.4 and §8.5 for the current status of signing
> and SBOM generation.

---

*Last updated: 2026-10-08*
*Version: v1.4.0*
*Author: gasciljh*
