<!-- ============================================================
     DNSCrypt Smart Filter – Release PR Template
     Version: v1.0.0
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template applies to PRs from `release/*` or `hotfix/*`
     branches targeting `main`.

     ⚠️ HOW TO USE IT:
       GitHub only auto-applies the DEFAULT template
       (.github/PULL_REQUEST_TEMPLATE.md). To use this one, append
       `?template=release.md` to the PR-creation URL:

         https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.1.0?template=release.md

       Full details: docs/BRANCHING.md §4.4
                     docs/RELEASE_PROCESS.md §5
     ============================================================ -->

## 🚀 Release: `vX.Y.Z`

> **Target branch**: `main`
> **Source branch**: `release/vX.Y.Z` or `hotfix/vX.Y.Z`

---

## 📋 Pre-Flight Checklist

<!--
  All boxes must be checked before opening this PR.
  If a box cannot be checked, do not open the PR yet.
-->

- [ ] **Branch**: source is `release/vX.Y.Z` or `hotfix/vX.Y.Z`
- [ ] **Target**: base is `main` (not `develop`)
- [ ] **Working tree clean**: `git status` shows no uncommitted changes
- [ ] **CI green on source branch**: latest commit passed `ci.yml` + `codeql.yml`
- [ ] **`VERSION`** updated to the target version
- [ ] **`module.prop`** `version` + `versionCode` updated
- [ ] **`update.json`** `version` + `versionCode` + `zipUrl` updated
- [ ] **`CHANGELOG.md`** has a `## [vX.Y.Z] - YYYY-MM-DD` section
- [ ] **Version files in sync** (verified by command below)

### Version files verification

<!--
  Paste the output of this command:
    bash -c 'echo "VERSION: $(cat VERSION)"; \
             grep -E "^(version|versionCode)=" module.prop; \
             jq -r "\\"update.json: \\(.version) \\(.versionCode)\\"" update.json'
-->

```text
VERSION: vX.Y.Z
version=vX.Y.Z
versionCode=NNNNNNN
update.json: vX.Y.Z NNNNNNN
```

---

## 🔢 Version Summary

| Field | Value |
|---|---|
| **Version** | `vX.Y.Z` |
| **versionCode** | `NNNNNNN` |
| **Previous version** | `vX.Y.(Z-1)` |
| **SemVer bump** | PATCH / MINOR / MAJOR |
| **Release type** | Stable / Prerelease / Hotfix |

---

## 📦 What's in this release

<!--
  A short list of what this release contains.
  Not a full changelog — the CHANGELOG.md has that.
  Just a scannable summary for the reviewer.
-->

- Feature:
- Fix:
- Security:
- Documentation:

---

## ✅ Post-Merge Plan

<!--
  Steps performed AFTER this PR is merged.
  These are critical — a mistake here can leave the release broken.
-->

- [ ] **Tag push**: `git push origin vX.Y.Z` (or via `./scripts/release.sh vX.Y.Z` from `main`)
- [ ] **`release.yml` triggers**: GitHub Actions publishes the release (5-10 min)
- [ ] **Verify release**: 6 artifacts attached
- [ ] **Back-merge**: sync `develop` with `main`
  - For `release/*`: automatic via `release.yml`
  - For `hotfix/*`: manual — run `make sync` or the equivalent `git` commands

### Post-merge commands (for reference)

```bash
# If not already tagged:
git checkout main
git pull origin main
./scripts/release.sh vX.Y.Z

# For hotfix only — back-merge after the release publishes:
make sync
```

---

## 🛟 Rollback Plan

<!--
  What to do if the release is broken after publishing.
  Fill this in BEFORE merging, so the plan exists.
-->

- [ ] If the **release was just published** and no user has updated yet:
  - Delete the GitHub Release
  - Delete the tag: `git push origin :refs/tags/vX.Y.Z`
  - Fix on `main` → tag again
- [ ] If **users have already updated**:
  - Publish a follow-up PATCH release (`./scripts/release-patch.sh vX.Y.(Z+1)`)
  - Do NOT delete or modify the existing tag

**Rollback decision**: <!-- fill: delete-tag OR publish-follow-up -->

---

## 👀 Reviewer Checklist

<!--
  Reviewers: use this as your review guide.
  Releases have different failure modes than features.
-->

- [ ] **Version integrity**: `VERSION` = `module.prop` = `update.json`
- [ ] **versionCode formula**: `MAJOR × 1M + MINOR × 10K + PATCH × 100`
- [ ] **SemVer bump**: matches the highest-severity change in the release
- [ ] **CHANGELOG completeness**: all user-facing changes are listed
- [ ] **CHANGELOG ordering**: newest section at the top (after `[Unreleased]`)
- [ ] **`zipUrl` in `update.json`**: matches the tag name (e.g. `v1.1.0`)
- [ ] **No untracked changes**: `git status` is clean
- [ ] **Tag name**: `vX.Y.Z` (no typos, no `-v` prefix, no double `v`)
- [ ] **Post-merge plan**: the author confirmed the tag push and back-merge
- [ ] **Rollback plan**: documented above

---

## 📌 Additional Notes

<!--
  Anything the reviewer should know about the release.
  Examples:
    - Why this release is being cut now
    - Any known issues being shipped
    - Any deferred changes
    - Any compatibility notes
-->



---

<!-- ============================================================
     ⚠️  Final reminder before merging:

     ┌────────────────────────────────────────────────────────┐
     │  🚀  Release PR — Different rules apply               │
     ├────────────────────────────────────────────────────────┤
     │  1. This PR targets `main` — that is correct here.     │
     │  2. The tag does NOT exist yet — it is created after   │
     │     the merge (or already pushed via release.sh).      │
     │  3. `release.yml` will publish the release.            │
     │  4. `develop` must be synced after the release:        │
     │       • release/* → automatic via release.yml          │
     │       • hotfix/*  → manual (make sync)                 │
     └────────────────────────────────────────────────────────┘

     📖 Full details:
       docs/BRANCHING.md §4.4 (Release Workflow)
       docs/RELEASE_PROCESS.md §5 (PR Steps)

     Current version line: v1.0.0
     Last updated: 2026-09-24
     ============================================================ -->