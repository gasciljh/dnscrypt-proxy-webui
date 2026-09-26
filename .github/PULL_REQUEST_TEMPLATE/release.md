<!-- ============================================================
     DNSCrypt Smart Filter – Release PR Template
     Version: v1.1.0
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template applies to PRs from `release/*` or `hotfix/*`
     branches targeting `main`.

     ⚠️ HOW TO USE IT:
       GitHub only auto-applies the DEFAULT template
       (.github/PULL_REQUEST_TEMPLATE.md). To use this one, append
       `?template=release.md` to the PR-creation URL:

         https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.2.0?template=release.md

       Full details: docs/BRANCHING.md §4.4
                     docs/RELEASE_PROCESS.md §5
                     docs/adr/0005-release-specific-pr-template.md
     ============================================================
     v1.1.0 additions:
       • New "v1.1.0 — version consistency" checklist covering the
         5 places the version string appears (VERSION, module.prop,
         manifest.json, sw.js, index.html/dashboard.html).
       • New "v1.1.0 — runtime_info fields" check for the two new
         fields added in v1.1.0 (profile_key, memory_limit_mb).
       • New "v1.1.0 — memory limit per profile" check confirming
         the dynamic limit works for each profile.
       • Version examples in this template now reference v1.2.0 as
         the next release (the template ships with v1.1.0).
       • The release-patch.sh flow is now documented in the
         "Post-Merge Plan" section, since PATCH releases were
         formalized in ADR-0006 during the v1.0.0 cycle.
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
  Run this command and paste the output below:

    bash -c 'echo "VERSION: $(cat VERSION)"; \
             grep -E "^(version|versionCode)=" module.prop; \
             jq -r "\"update.json: \\(.version) \\(.versionCode)\"" update.json'
-->

```text
VERSION: vX.Y.Z
version=vX.Y.Z
versionCode=NNNNNNN
update.json: vX.Y.Z NNNNNNN
```

### v1.1.0 — version consistency (5 files)

<!--
  v1.1.0 introduced a stricter version-consistency requirement.
  The version string appears in 5 places that MUST all agree
  before a release is cut. Run this and paste the output:

    V=$(cat VERSION)
    echo "VERSION:             $V"
    echo "module.prop:         $(grep '^version=' module.prop | cut -d= -f2)"
    echo "manifest.json:       $(jq -r .version web/manifest.json)"
    echo "sw.js:               $(grep -oE "CACHE_VERSION = '[^']+'" web/sw.js | cut -d"'" -f2)"
    echo "index.html:          $(grep -oE "var VERSION = '[^']+'" web/index.html | cut -d"'" -f2)"
    echo "dashboard.html:      $(grep -oE "var VERSION = '[^']+'" web/dashboard.html | cut -d"'" -f2)"
-->

```text
VERSION:             vX.Y.Z
module.prop:         vX.Y.Z
manifest.json:       X.Y.Z            (note: no 'v' prefix — PWA spec)
sw.js:               vX.Y.Z           (CACHE_VERSION)
index.html:          vX.Y.Z           (var VERSION)
dashboard.html:      vX.Y.Z           (var VERSION)
```

- [ ] **`VERSION`** = `module.prop.version` = `update.json.version`
- [ ] **`VERSION`** = `sw.js` CACHE_VERSION
- [ ] **`VERSION`** = `index.html` `var VERSION`
- [ ] **`VERSION`** = `dashboard.html` `var VERSION`
- [ ] **`manifest.json.version`** matches (without the `v` prefix)
- [ ] **`versionCode`** = `MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100`

### v1.1.0 — runtime_info fields

<!--
  v1.1.0 added two fields to /api?action=runtime_info:
    • profile_key      — the active blocklist profile
    • memory_limit_mb  — the Go soft memory limit for that profile

  These MUST be present in the runtime_info response of the
  released binary. Run this after installing the release:

    curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
-->

```json
{
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

- [ ] `profile_key` is one of: `light`, `normal`, `pro`, `proplus`, `ultimate`
- [ ] `memory_limit_mb` matches the profile's expected value:
  - `light` → 80
  - `normal` → 100
  - `pro` → 120 (default)
  - `proplus` → 160
  - `ultimate` → 220
- [ ] The two fields are also displayed in `web/index.html` (System Info panel)
- [ ] The two fields are also displayed in `web/dashboard.html` (System Info panel)

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

### v1.1.0 highlights (if applicable)

<!--
  If this release IS v1.1.0, confirm each item below. Otherwise
  leave empty or delete.
-->

- [ ] Dynamic memory limit per profile (main.go: `memoryLimitForProfile`)
- [ ] Extended `shellQuote` character set (`{`, `}`, `\n`, `\t`)
- [ ] `MONITORING_UI_PORT` constant used in `metricsProxyHandler`
- [ ] `runtime_info` returns `profile_key` + `memory_limit_mb`
- [ ] Memory hint helper in `functions.sh` + 4 shell scripts fallback
- [ ] Version bumped in 5 places (VERSION, module.prop, manifest, sw, HTML)

---

## ✅ Post-Merge Plan

<!--
  Steps performed AFTER this PR is merged.
  These are critical — a mistake here can leave the release broken.

  Two flows are possible depending on the release type:
    • Stable / Prerelease  → release.sh
    • PATCH-only (hotfix)  → release-patch.sh (see ADR-0006)
-->

- [ ] **Identify the correct release script**:
  - [ ] **Stable / Prerelease**: use `./scripts/release.sh vX.Y.Z`
  - [ ] **PATCH-only**: use `./scripts/release-patch.sh vX.Y.Z`
    (this script enforces the 3 safety rules from ADR-0006)

- [ ] **Tag push**: `git push origin vX.Y.Z`
  (usually triggered automatically by the chosen script)

- [ ] **`release.yml` triggers**: GitHub Actions publishes the release (5–10 min)
- [ ] **Verify release**: 6 artifacts attached to the GitHub Release
- [ ] **Back-merge**: sync `develop` with `main`
  - For `release/*`: **automatic** via `release.yml` (see ADR-0003)
  - For `hotfix/*`: **manual** — run `make sync`

### Post-merge commands (for reference)

```bash
# Stable / Prerelease:
git checkout develop
git pull origin develop
./scripts/release.sh vX.Y.Z

# PATCH-only (from main):
git checkout main
git pull origin main
./scripts/release-patch.sh vX.Y.Z

# Back-merge after PATCH-only release:
make sync

# Verify the release is complete:
gh release view vX.Y.Z
```

---

## 🛟 Rollback Plan

<!--
  What to do if the release is broken after publishing.
  Fill this in BEFORE merging, so the plan exists.

  ⚠️ Rollback is expensive. Prefer forward-fix when possible.
-->

**Choose exactly one strategy before merging:**

- [ ] **Plan A — Delete tag + re-tag** (only if no user has updated yet)
  - Delete the GitHub Release
  - Delete the tag: `git push origin :refs/tags/vX.Y.Z`
  - Fix the issue on `main` → re-tag
  - Appropriate when: the release is minutes old and unadvertised

- [ ] **Plan B — Publish a follow-up PATCH** (preferred for user-facing bugs)
  - Do NOT delete or modify the existing tag
  - Cut a new PATCH release: `./scripts/release-patch.sh vX.Y.(Z+1)`
  - Document the incident in `CHANGELOG.md`
  - Appropriate when: users have already downloaded the release

**Rollback decision**: <!-- fill: Plan A (delete-tag) OR Plan B (follow-up) -->

**Rationale**: <!-- why this plan was chosen over the other -->

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
- [ ] **`zipUrl` in `update.json`**: matches the tag name (e.g. `v1.2.0`)
- [ ] **No untracked changes**: `git status` is clean
- [ ] **Tag name**: `vX.Y.Z` (no typos, no `-v` prefix, no double `v`)
- [ ] **Post-merge plan**: the author confirmed the tag push and back-merge
- [ ] **Rollback plan**: documented above (Plan A or Plan B chosen)

### v1.1.0-specific (if applicable)

- [ ] `runtime_info` returns `profile_key` + `memory_limit_mb` (see pre-flight)
- [ ] Memory limit works for all 5 profiles (light / normal / pro / proplus / ultimate)
- [ ] Version consistent across all 5 files (see pre-flight)
- [ ] `web/sw.js` CACHE_VERSION matches `VERSION`
- [ ] `web/manifest.json` version has no `v` prefix (PWA spec requirement)

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

     ┌───────────────────────────────────────────────┐
     │  🚀  Release PR — Different rules apply               │
     ├───────────────────────────────────────────────┤
     │  1. This PR targets `main` — that is correct here.    │
     │  2. The tag does NOT exist yet — it is created after  │
     │     the merge (or already pushed via release.sh /     │
     │     release-patch.sh).                                │
     │  3. `release.yml` will publish the release.           │
     │  4. `develop` must be synced after the release:       │
     │       • release/* → automatic via release.yml        │
     │       • hotfix/*  → manual (make sync)               │
     └───────────────────────────────────────────────┘

     📖 Full details:
       docs/BRANCHING.md §4.4       (Release Workflow)
       docs/RELEASE_PROCESS.md §5   (PR Steps)
       docs/adr/0005                (Why a separate template)
       docs/adr/0006                (Why release-patch.sh)

     🎯 Quick verification before opening the PR:

       # 5-way version consistency
       V=$(cat VERSION)
       grep -q "^version=$V" module.prop && echo "✅ module.prop"
       grep -q "\"version\": \"${V#v}\"" web/manifest.json && echo "✅ manifest.json"
       grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
       grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
       grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"

       # CHANGELOG section
       grep -q "^## \[${V#v}\]" CHANGELOG.md && echo "✅ CHANGELOG section"

       # update.json fields
       jq -e ".version == \"$V\"" update.json >/dev/null && echo "✅ update.json version"

     Current version line: v1.1.0
     Last updated: 2026-09-26
     ============================================================ -->