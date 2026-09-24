# Release Process — DNSCrypt Smart Filter

Step-by-step guide to publishing a new release: from version bump to post-release verification.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **📖 Related documents**:
> - Git branching strategy → [`docs/BRANCHING.md`](BRANCHING.md)
> - Architecture Decision Records → [`docs/adr/README.md`](adr/README.md)
> - Contribution guide → [`docs/CONTRIBUTING.md`](CONTRIBUTING.md)

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

Publish a **signed, reproducible, verifiable** release that users can download and install with confidence.

### 1.2 What a Release Includes

Every release publishes **6 artifacts**:

| # | Artifact | Size | Purpose |
|:-:|---|---|---|
| 1 | `dnscrypt-webui-<ver>-module.zip` | ~12 MB | Magisk module (all-in-one) |
| 2 | `dnscrypt-webui-<ver>-module.zip.sha256` | ~100 B | Integrity check |
| 3 | `dnscrypt-webui-arm64` | ~8 MB | Standalone WebUI binary |
| 4 | `dnscrypt-webui-arm` | ~7 MB | Standalone WebUI binary |
| 5 | `dnscrypt-webui-amd64` | ~7.5 MB | Standalone WebUI binary |
| 6 | `dnscrypt-webui-386` | ~7 MB | Standalone WebUI binary |

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
Create signed tag vX.Y.Z
        │
        ▼
Push branch + tag to origin
        │
        ▼
GitHub Actions (release.yml) triggers on tag
        │
        ├── Setup Go + NDK
        ├── Build 4 architectures
        ├── Verify ELF + PIE
        ├── Package Magisk ZIP
        ├── Compute SHA-256
        ├── Generate SBOM (SPDX + CycloneDX)
        ├── Sign with Cosign (keyless)
        ├── Create GitHub Release
        └── Sync main → develop
        │
        ▼
Release is live ✅
```

**Total time**: ~5-10 minutes.

### 1.4 Prerequisites

Before releasing, ensure:

- ✅ You are on `develop` or a `release/*` branch (see [`docs/BRANCHING.md`](BRANCHING.md)).
- ✅ Working tree is clean (`git status`).
- ✅ `CHANGELOG.md` has an entry for the new version.
- ✅ CI is green on the current branch.
- ✅ All PRs for this release are merged.

**Tools required**:

| Tool | Purpose | Install |
|---|---|---|
| `git` | Version control | Pre-installed |
| `sed` | Text manipulation | Pre-installed |
| `awk` | Parsing | Pre-installed |
| `jq` | JSON manipulation | `apt install jq` / `brew install jq` |

### 1.5 Architecture Decisions

The decisions that shaped the release process are documented as **ADRs**:

| ADR | Decision |
|---|---|
| [ADR-0002](adr/0002-automated-releases.md) | Automated releases via `release.sh` + `release.yml` |
| [ADR-0003](adr/0003-post-release-sync.md) | Post-release sync (`main → develop`) |
| [ADR-0005](adr/0005-release-specific-pr-template.md) | Release-specific PR template |
| [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md) | Rename `hotfix.sh` → `release-patch.sh` |

Full index: [`docs/adr/README.md`](adr/README.md).

---

## 2. Release Types

### 2.1 Stable Release

**Format**: `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v1.1.0`, `v2.0.0`)

| Aspect | Value |
|---|---|
| **When** | After a successful stabilization period. |
| **Branch** | `release/*` or directly from `develop`. |
| **Script** | `scripts/release.sh` |
| **Tag** | `v1.1.0` (no suffix). |
| **GitHub Release** | Marked as **latest**. |
| **Cadence** | Every 4-8 weeks. |

### 2.2 Prerelease

**Format**: `vMAJOR.MINOR.PATCH-<label>` (e.g. `v1.1.0-beta1`, `v2.0.0-rc1`)

| Aspect | Value |
|---|---|
| **When** | For beta testing before a stable release. |
| **Branch** | `develop`. |
| **Script** | `scripts/release.sh` |
| **Tag** | `v1.1.0-beta1`. |
| **GitHub Release** | Marked as **pre-release**. |
| **Cadence** | As needed. |

**Note**: `versionCode` ignores the prerelease suffix (see §3.2).

### 2.3 Hotfix (PATCH Release)

**Format**: `vMAJOR.MINOR.PATCH+1` (e.g. `v1.0.1` after `v1.0.0`)

| Aspect | Value |
|---|---|
| **When** | Critical bug in a released version. |
| **Branch** | `hotfix/*` (from `main`). |
| **Script** | `scripts/release-patch.sh` ← **enforces 3 safety rules** |
| **Tag** | `v1.0.1`. |
| **GitHub Release** | Marked as **latest**. |
| **Cadence** | Immediate. |

**Safety rules enforced by `release-patch.sh`**:

1. **Branch must be `main`** — refuses to run from `develop`.
2. **`MAJOR` and `MINOR` must not change** — rejects non-PATCH bumps.
3. **`PATCH` must be exactly `current + 1`** — rejects skipping versions.

**Full rationale**: [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md).

See [`docs/BRANCHING.md`](BRANCHING.md) §8 for the full hotfix workflow.

### 2.4 Comparison

| Type | Example | `versionCode` | Script | Latest? | Requires `release/*`? |
|---|---|:---:|:---:|:---:|:---:|
| Stable | `v1.1.0` | `1010000` | `release.sh` | ✅ | ⚠️ Recommended |
| Prerelease | `v1.1.0-beta1` | `1010000` | `release.sh` | ❌ | ❌ (from `develop`) |
| Hotfix (PATCH) | `v1.0.1` | `1000001` | `release-patch.sh` | ✅ | ❌ (from `main`) |

---

## 3. Versioning Rules

### 3.1 SemVer

The project follows [Semantic Versioning 2.0.0](https://semver.org/):

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
| `v1.0.0` | `1000000` | Current release |
| `v1.0.1` | `1000001` | Hotfix |
| `v1.1.0` | `1010000` | New feature |
| `v1.1.0-beta1` | `1010000` | Same code (prerelease) |
| `v2.0.0` | `2000000` | Breaking change |
| `v10.5.3` | `10050300` | Double-digit MAJOR |

### 3.3 Why Two Version Schemes?

- **SemVer** (`v1.1.0`) — for GitHub Releases, docs, humans.
- **versionCode** (`1010000`) — for Magisk/KernelSU/APatch to detect updates.

**Rule**: `versionCode` must **strictly increase** with each release. Never reuse.

### 3.4 Sanity Checks

Run these before tagging:

```bash
# 1. Format is valid
echo "v1.1.0" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$' && echo "✅ valid"

# 2. versionCode is greater than previous
grep '^versionCode=' module.prop

# 3. Version is not already tagged
git tag --list "v1.1.0"

# 4. VERSION matches the intended release
cat VERSION
```

`scripts/release.sh` (and `scripts/release-patch.sh`) perform all four automatically.

---

## 4. Files to Update

Every release updates **4 files**:

### 4.1 `VERSION`

Single-line file, LF-only.

```text
v1.1.0
```

**Purpose**: Single Source of Truth for the module version.

### 4.2 `module.prop`

Magisk module definition.

```text
id=dnscrypt-proxy-webui
name=DNSCrypt Proxy (Smart Filter)
version=v1.1.0
versionCode=1010000
author=gasciljh
description=...
updateJson=https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/update.json
```

**Updated fields**: `version`, `versionCode`.

### 4.3 `update.json`

Auto-update metadata.

```json
{
  "version": "v1.1.0",
  "versionCode": 1010000,
  "zipUrl": "https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip",
  "changelog": "https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/CHANGELOG.md"
}
```

**Updated fields**: `version`, `versionCode`, `zipUrl`.

**Note**: `zipUrl` uses the tag as-is (`v1.1.0` in the URL path). Magisk resolves the redirect.

### 4.4 `CHANGELOG.md`

Human-readable history.

```markdown
## [v1.1.0] - 2026-XX-XX

### Added
- ...

### Fixed
- ...

### Security
- ...
```

**Manual update** — this file is not touched by `release.sh`.

### 4.5 Summary Table

| File | Automated? | Notes |
|---|:---:|---|
| `VERSION` | ✅ `release.sh` / `release-patch.sh` | Single line |
| `module.prop` | ✅ Both scripts | `version` + `versionCode` |
| `update.json` | ✅ Both scripts (requires `jq`) | 3 fields |
| `CHANGELOG.md` | ❌ Manual | Human-edited |

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
./scripts/release.sh v1.1.0

# 4. Confirm at the prompt
# → Script commits, tags, pushes
# → GitHub Actions publishes the release
```

**Behind the scenes**:

```text
✓ Checked environment (git, sed, awk, jq)
✓ Validated version: v1.1.0
✓ versionCode = 1010000
✓ On branch: develop
✓ Working tree is clean
✓ Tag v1.1.0 is available
✓ CHANGELOG.md contains [1.1.0] or [Unreleased]
✓ Updated VERSION
✓ Updated module.prop
✓ Updated update.json
✓ Commit created: release: v1.1.0
✓ Tag created: v1.1.0
✓ Pushed branch: develop
✓ Pushed tag: v1.1.0
```

### 5.3 Dry-Run (Preview)

```bash
./scripts/release.sh v1.1.0 --dry-run
```

**What it does**: prints what would happen, changes nothing.

**When to use**: before committing to a release, to double-check `versionCode` and branch state.

### 5.4 Local-Only (No Push)

```bash
./scripts/release.sh v1.1.0 --no-push
```

**What it does**: creates the commit + tag locally, but does not push.

**When to use**: if you want to review before pushing:

```bash
# Review the change
git show HEAD
git tag -l v1.1.0

# Push manually when ready
git push origin develop
git push origin v1.1.0
```

### 5.5 Non-Interactive (CI/Scripts)

```bash
./scripts/release.sh v1.1.0 --yes
```

**What it does**: skips all confirmation prompts.

**When to use**: in automation scripts (rare — usually you want the confirmation).

### 5.6 Prerelease

```bash
./scripts/release.sh v1.1.0-beta1
```

**Result**:
- `VERSION` = `v1.1.0-beta1`
- `versionCode` = `1010000` (prerelease suffix ignored)
- Tag = `v1.1.0-beta1`
- GitHub Release marked as **pre-release**

### 5.7 Using release-patch.sh

For **PATCH-only** releases (hotfixes) from `main`:

```bash
# 1. Start from main
git checkout main
git pull origin main

# 2. Run the script (interactive)
./scripts/release-patch.sh v1.0.1

# 3. Confirm at the prompt
# → Script enforces 3 safety rules
# → Delegates to release.sh for the actual bump
# → Reminds you to back-merge main → develop
```

**Safety rules** (from [ADR-0006](adr/0006-rename-hotfix-to-release-patch.md)):

1. **Branch must be `main`** — refuses to run from `develop`.
2. **`MAJOR` and `MINOR` must not change** — rejects non-PATCH bumps.
3. **`PATCH` must be exactly `current + 1`** — rejects skipping versions.

**Relationship to `release.sh`**:

```text
scripts/release.sh                 ← Full release logic
        ↑
        │ delegates to
        │
scripts/release-patch.sh           ← Wraps with 3 PATCH-only rules
```

`release-patch.sh` does **not** duplicate logic — it delegates to `release.sh`.

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
- ❌ Does not run tests locally (CI will).
- ❌ Does not build binaries (GitHub Actions will).
- ❌ Does not create the GitHub Release (GitHub Actions will).

---

## 6. Manual Release (Fallback)

If `release.sh` is unavailable or fails, do it manually:

```bash
# 1. Ensure you are on develop
git checkout develop
git pull origin develop

# 2. Update VERSION
echo "v1.1.0" > VERSION

# 3. Update module.prop
sed -i 's/^version=.*/version=v1.1.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1010000/' module.prop

# 4. Update update.json (manual edit)
$EDITOR update.json

# 5. Update CHANGELOG.md
$EDITOR CHANGELOG.md

# 6. Verify
grep '^version' VERSION module.prop
jq '.version, .versionCode' update.json

# 7. Commit
git add VERSION module.prop update.json CHANGELOG.md
git commit -m "release: v1.1.0"

# 8. Tag
git tag -a v1.1.0 -m "Release v1.1.0"

# 9. Push
git push origin develop
git push origin v1.1.0
```

**Warning**: manual process is error-prone. Prefer `release.sh` (or `release-patch.sh` for PATCH releases).

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

### 7.2 Pipeline Steps (11 steps)

| # | Step | Duration | Output |
|:-:|---|---|---|
| 1 | `actions/checkout@v4` (fetch-depth 0) | ~5 s | Full history |
| 2 | `actions/setup-go@v5` | ~10 s | Go 1.22 |
| 3 | `nttld/setup-ndk@v1` | ~30 s | NDK r26b |
| 4 | Determine version | ~2 s | `value`, `no_v` |
| 5 | Install packaging tools | ~15 s | zip, unzip, jq, curl |
| 6 | Build WebUI binaries | ~60 s | 4 binaries |
| 7 | Verify WebUI binaries | ~5 s | PIE + ELF check |
| 8 | Package Magisk module | ~30 s | `.zip` + `.sha256` |
| 9 | Upload artifacts (backup) | ~20 s | 30-day retention |
| 10 | Create GitHub Release | ~10 s | Published |
| 11 | Sync `main → develop` | ~15 s | Post-release |

**Total**: ~3-4 minutes (plus runner setup ~30 s).

### 7.3 Artifacts Produced

```text
dist/
├── dnscrypt-webui-1.1.0-module.zip
└── dnscrypt-webui-1.1.0-module.zip.sha256

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

**Effect**: `develop` is now identical to `main` at the release commit.

**Safety**: If the merge fails (conflict), the step **does not fail** the release — it prints a warning and exits with `0`. Manual resolution is required if this happens.

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
git push origin :refs/tags/v1.1.0
git tag -d v1.1.0
./scripts/release.sh v1.1.0
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
- ✅ ZIP contains 32 expected files.
- ✅ SHA-256 file is created.

### 8.2 Manual Verification Checklist

After the release is published:

- [ ] **GitHub Releases page** shows the new version.
- [ ] **Pre-release** flag is correct (for prereleases).
- [ ] **`latest`** flag is on stable releases only.
- [ ] **6 artifacts** are attached (module.zip, .sha256, 4 binaries).
- [ ] **Auto-generated release notes** look reasonable.
- [ ] **`CHANGELOG.md`** link works.

### 8.3 Verify on Device

Download the ZIP to a device and verify:

```bash
# 1. Check SHA-256
sha256sum -c dnscrypt-webui-1.1.0-module.zip.sha256

# 2. Install via Magisk Manager

# 3. Verify version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
su -c "grep '^versionCode=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"

# 4. Verify WebUI works
curl -s http://127.0.0.1:9090/healthz
# → ok

# 5. Verify Dashboard JSON (Fix #1)
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
# → application/json

# 6. Verify runtime_info ports (PORT-2)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# → {"webui_port": "9090", "dashboard_port": "9091"}

# 7. Verify firewall has no orphans
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0

# 8. Verify Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 Method Not Allowed
```

### 8.4 Verify Cosign Signature (Optional)

```bash
# Download signature + certificate
curl -LO https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip.sig
curl -LO https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip.pem

# Verify (requires cosign)
cosign verify-blob \
    --signature dnscrypt-webui-1.1.0-module.zip.sig \
    --certificate dnscrypt-webui-1.1.0-module.zip.pem \
    --certificate-identity-regexp "https://github.com/gasciljh/dnscrypt-proxy-webui/.*" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    dnscrypt-webui-1.1.0-module.zip
```

**Expected**: `Verified OK`.

### 8.5 Verify SBOM (Optional)

```bash
# Download SBOM
curl -LO https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/sbom.spdx.json

# Inspect
jq '.packages | length' sbom.spdx.json
jq '.packages[] | .name' sbom.spdx.json
```

### 8.6 Verify update.json

```bash
curl -s https://raw.githubusercontent.com/gasciljh/dnscrypt-proxy-webui/main/update.json | jq
```

**Expected**:

```json
{
  "version": "v1.1.0",
  "versionCode": 1010000,
  "zipUrl": "https://github.com/gasciljh/dnscrypt-proxy-webui/releases/download/v1.1.0/dnscrypt-webui-1.1.0-module.zip",
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

### 9.2 Delete a Tag

**Local + remote**:

```bash
# Local
git tag -d v1.1.0

# Remote
git push origin :refs/tags/v1.1.0
```

**Then delete the GitHub Release** (if created):

```bash
gh release delete v1.1.0 --yes
```

### 9.3 Amend a Release

If the release is published but has a minor issue:

**Option A — Add a fixup release** (recommended):

```bash
# Regular release:
./scripts/release.sh v1.1.1

# Or PATCH-only release from main:
git checkout main
./scripts/release-patch.sh v1.1.1
```

**Option B — Force-update the tag** (dangerous):

```bash
# Amend the commit
git commit --amend

# Force-update the tag
git tag -f v1.1.0 -m "Release v1.1.0"

# Force-push
git push origin :refs/tags/v1.1.0
git push origin v1.1.0
```

**Warning**: force-updating a tag breaks everyone who already downloaded the release.

### 9.4 Revert a Release

If a release introduces a critical bug:

```bash
# 1. Revert the release commit on develop
git checkout develop
git revert <release-commit-sha>

# 2. Or manually reset
git revert --no-commit <release-commit-sha>
git commit -m "revert: rollback v1.1.0"

# 3. Publish a PATCH release from main
git checkout main
git checkout -b hotfix/v1.1.1-revert
# ... cherry-pick the revert ...
git commit -m "fix: revert v1.1.0 regression"
git push -u origin hotfix/v1.1.1-revert

# 4. Merge + prepare PATCH release
./scripts/release-patch.sh v1.1.1
```

### 9.5 Emergency Contacts

| Situation | Action |
|---|---|
| CI is broken | Fix + re-run workflow |
| Tag is protected | Update protection rules |
| Users report critical bug | PATCH release within 24 hours |
| Security vulnerability | Follow `docs/SECURITY.md` |

### 9.6 What NOT to Do

- ❌ **Do not** delete `main`.
- ❌ **Do not** force-push `main` or `develop`.
- ❌ **Do not** edit `module.prop` manually after tagging.
- ❌ **Do not** republish the same tag.
- ❌ **Do not** skip CHANGELOG updates.

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

The sync step has `continue-on-error: true` — the release is **not** failed.

**Common causes**:

| Cause | Solution |
|---|---|
| `develop` does not exist | Create it: `git checkout -b develop && git push -u origin develop` |
| Merge conflict | Resolve manually and push |
| Branch protection blocks bot | Adjust protection to allow `github-actions[bot]` |

### 10.3 Manual Sync (PATCH Releases)

For PATCH releases (`hotfix/*` branches), the sync is **manual** because
GitHub Actions cannot distinguish a hotfix tag from a regular tag.

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

**Why this matters**: without syncing, `develop` will be missing the hotfix,
and the next `release/*` PR will reintroduce the bug.

### 10.4 Verify Sync

```bash
# Both should point to the same commit
git rev-parse origin/main
git rev-parse origin/develop

# Compare CHANGELOG
git log --oneline -1 origin/main
git log --oneline -1 origin/develop
```

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
git commit -m "docs(changelog): prepare v1.1.0"

# 3. Preview
./scripts/release.sh v1.1.0 --dry-run

# 4. Execute
./scripts/release.sh v1.1.0

# 5. Wait (~5 min) → Release is live ✅
```

**Alternative flow with a `release/*` branch** (stabilization window):

```bash
# 1. Create release branch
git checkout develop
git checkout -b release/v1.1.0

# 2. Prepare version bump locally
./scripts/release.sh v1.1.0 --no-push

# 3. Update CHANGELOG
$EDITOR CHANGELOG.md
git add -A
git commit -m "release: v1.1.0"

# 4. Push and open PR against main
git push -u origin release/v1.1.0
# → Open PR using ?template=release.md

# 5. After merge → tag + publish
git checkout main && git pull
./scripts/release.sh v1.1.0
```

### 11.2 PATCH Release Flow (Hotfix)

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/v1.0.1-critical

# 2. Fix
# ...

# 3. Commit + push
git commit -m "fix(critical): patch login bypass"
git push -u origin hotfix/v1.0.1-critical

# 4. Open PR against main using ?template=release.md
# 5. Merge

# 6. Prepare PATCH release
./scripts/release-patch.sh v1.0.1

# 7. Back-merge
make sync
```

### 11.3 Manual Release (Emergency)

```bash
echo "v1.1.0" > VERSION
sed -i 's/^version=.*/version=v1.1.0/' module.prop
sed -i 's/^versionCode=.*/versionCode=1010000/' module.prop
$EDITOR update.json
$EDITOR CHANGELOG.md
git add -A && git commit -m "release: v1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin develop
git push origin v1.1.0
```

### 11.4 Rollback

```bash
# Delete tag
git push origin :refs/tags/v1.1.0
git tag -d v1.1.0

# Delete release
gh release delete v1.1.0 --yes

# Retry
./scripts/release.sh v1.1.0
```

### 11.5 Version Reference

| Action | MAJOR | MINOR | PATCH |
|---|:---:|:---:|:---:|
| Breaking change | +1 | → 0 | → 0 |
| New feature | — | +1 | → 0 |
| Bug fix | — | — | +1 |
| Hotfix (PATCH) | — | — | +1 |
| Prerelease | — | +1 | → 0 (with `-betaN`) |

### 11.6 Files Checklist

- [ ] `VERSION` → `v1.1.0`
- [ ] `module.prop` → `version=v1.1.0`, `versionCode=1010000`
- [ ] `update.json` → 3 fields
- [ ] `CHANGELOG.md` → new section

### 11.7 Post-Release Checklist

- [ ] GitHub Release published
- [ ] 6 artifacts attached
- [ ] `develop` synced with `main`
- [ ] `update.json` deployed on `main`
- [ ] Device test passed
- [ ] Cosign signature verifies (optional)
- [ ] SBOM attached (optional)

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
| [`docs/UPGRADE.md`](UPGRADE.md) | Version upgrade guide |
| [`docs/SECURITY.md`](SECURITY.md) | Security policy |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture |
| [`docs/API.md`](API.md) | HTTP API reference |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Troubleshooting |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions |
| [`docs/COMPATIBILITY.md`](COMPATIBILITY.md) | Compatibility matrix |
| [`docs/ROADMAP.md`](ROADMAP.md) | Future plans |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Terms and abbreviations |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |
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
| `scripts/release.sh` | Full release automation |
| `scripts/release-patch.sh` | PATCH-release automation (3 safety rules) |
| `scripts/package_module.sh` | Build Magisk ZIP |
| `scripts/fetch_dns_binaries.sh` | Fetch dnscrypt-proxy binaries |
| `scripts/generate-icons.sh` | Generate PNG/ICO icons |
| `proxy/build.sh` | Cross-compile WebUI binaries |
| `Makefile` | `make release`, `make release-patch`, `make sync` |
| `.github/workflows/ci.yml` | Build + lint CI |
| `.github/workflows/codeql.yml` | SAST security scanning |
| `.github/workflows/release.yml` | Release automation + sync |

### 12.4 External Resources

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)
- [SPDX](https://spdx.dev/)
- [CycloneDX](https://cyclonedx.org/)

---

*Last updated: 2026-09-24*
*Version: v1.0.0*
*Author: gasciljh*