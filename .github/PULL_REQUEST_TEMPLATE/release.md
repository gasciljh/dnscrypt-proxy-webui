<!-- ============================================================
     DNSCrypt Smart Filter – Release PR Template
     Version: v1.5.0 (Global Edition)
     Last updated: 2026-10-18
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template applies to PRs from `release/*` or `hotfix/*`
     branches targeting `main`.

     ⚠️ HOW TO USE IT:
       GitHub only auto-applies the DEFAULT template
       (.github/PULL_REQUEST_TEMPLATE.md). To use this one, append
       `?template=release.md` to the PR-creation URL:

         https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.5.0?template=release.md

       Full details:
         docs/CONTRIBUTING.md §5 (Branch Strategy)
         docs/CONTRIBUTING.md §11 (Release Process)
         docs/adr/0001-release-workflow.md §4 (PR template split)

     Cross-references:
       • docs/CONTRIBUTING.md §5, §11          — branch, release
       • docs/REFERENCE.md §1.4                — Layered Bootstrap
       • docs/REFERENCE.md §3.12               — install_app.sh contract
       • docs/REFERENCE.md §4.6                — rotation semantics
       • docs/REFERENCE.md §5.2.4              — SNAP-*/ROT-* verification
       • docs/REFERENCE.md §7                  — manifest technical notes
       • SECURITY.md §5.31–§5.36               — security model
       • SECURITY.md §15                       — audit corrections registry
       • docs/GUIDE.md §5, §8                  — upgrade, recovery
       • docs/adr/0001-release-workflow.md §4, §5
       • docs/adr/0002-external-dependency.md
       • docs/adr/0003-layered-bootstrap.md
     ============================================================ -->

## 🚀 Release: `vX.Y.Z`

> **Target branch**: `main`
> **Source branch**: `release/vX.Y.Z` or `hotfix/vX.Y.Z`

---

## 📋 Pre-Flight Checklist

- [ ] **Branch**: source is `release/vX.Y.Z` or `hotfix/vX.Y.Z`
- [ ] **Target**: base is `main` (not `develop`)
- [ ] **Working tree clean**: `git status` shows no uncommitted changes
- [ ] **CI green on source branch**: latest commit passed `ci.yml` + `codeql.yml`
- [ ] **`VERSION`** updated to the target version
- [ ] **`module.prop`** `version` + `versionCode` updated
- [ ] **`update.json`** `version` + `versionCode` + `zipUrl` updated
- [ ] **`CHANGELOG.md`** has a `## [vX.Y.Z] - YYYY-MM-DD` section

### Version files verification — 9 places (v1.5.0)

<!--
  Since v1.1.0 the project requires version-string consistency
  across 5 places. v1.5.0 extends this to 9 places:

    1. VERSION
    2. module.prop (version + versionCode)
    3. update.json (version + versionCode + zipUrl)
    4. web/manifest.json (no 'v' prefix — PWA spec)
    5. web/sw.js (CACHE_VERSION)
    6. web/index.html (var VERSION)
    7. web/dashboard.html (var VERSION)
    8. proxy/app-apk.version (companion app version, no 'v')
    9. proxy/go.mod (external dependency pin — ADR-0002)
-->

Run and paste output:

```bash
V=$(cat VERSION)
echo "VERSION:              $V"
echo "module.prop:          $(grep '^version=' module.prop | cut -d= -f2)"
echo "update.json:          $(jq -r .version update.json)"
echo "manifest.json:        $(jq -r .version web/manifest.json)      (no 'v')"
echo "sw.js:                $(grep -oE "CACHE_VERSION = '[^']+'" web/sw.js | cut -d"'" -f2)"
echo "index.html:           $(grep -oE "var VERSION = '[^']+'" web/index.html | cut -d"'" -f2)"
echo "dashboard.html:       $(grep -oE "var VERSION = '[^']+'" web/dashboard.html | cut -d"'" -f2)"
echo "app-apk.version:      $(cat proxy/app-apk.version)             (no 'v')"
echo "go.mod (ADR-0002):    $(grep 'filepath-securejoin' proxy/go.mod)"
```

```text
VERSION:              vX.Y.Z
module.prop:          vX.Y.Z
update.json:          vX.Y.Z
manifest.json:        X.Y.Z
sw.js:                vX.Y.Z
index.html:           vX.Y.Z
dashboard.html:       vX.Y.Z
app-apk.version:      X.Y.Z
go.mod (ADR-0002):    require github.com/cyphar/filepath-securejoin v0.7.0
```

- [ ] All version fields consistent (7 version strings + 1 dep pin)
- [ ] **`versionCode`** = `MAJOR × 1M + MINOR × 10K + PATCH × 100`

---

## ✅ Pre-Flight — v1.5.0 Additions

### v1.5.0 — companion install flow (4 endpoints)

<!--
  The v1.5.0 feature: a WebUI install button that opens an
  install-method modal (3 actions across 2 categories), the
  primary action being a root-level install via install_app.sh
  (5-level pm install cascade).

  Security model: SECURITY.md §5.36.
  install_app.sh contract: docs/REFERENCE.md §3.12.
-->

- [ ] **`install_app.sh`** present at the module root (repo: `proxy/install_app.sh`)
  ```bash
  test -f proxy/install_app.sh && echo "✅ present"
  wc -l proxy/install_app.sh  # expected ~1,101 lines
  ```
- [ ] **5 cascade levels present**
  ```bash
  for pattern in 'pm install -r --user 0' \
                 'pm install -r --user 0 -i com.android.shell' \
                 'pm install-create' \
                 'magisk su' \
                 'cmd package install'; do
      grep -q "$pattern" proxy/install_app.sh && echo "✅ $pattern" || echo "❌ $pattern"
  done
  ```
- [ ] **Three-way trap split** (EXIT / INT / TERM with `_CLEANED_UP` guard)
  ```bash
  grep -q "trap '_cleanup_app' EXIT" proxy/install_app.sh && echo "✅ EXIT trap"
  grep -q "trap '_cleanup_app; exit 130' INT" proxy/install_app.sh && echo "✅ INT trap (exit 130)"
  grep -q "trap '_cleanup_app; exit 143' TERM" proxy/install_app.sh && echo "✅ TERM trap (exit 143)"
  grep -q '_CLEANED_UP=1' proxy/install_app.sh && echo "✅ re-entry guard"
  ```
- [ ] **Cascade deadline** (75 s) is present and < `INSTALL_TIMEOUT` (90 s)
  ```bash
  grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75 s deadline"
  grep -q 'INSTALL_TIMEOUT.*90' proxy/main.go && echo "✅ 90 s handler timeout"
  ```
- [ ] **SELinux staging** (never `setenforce 0`)
  ```bash
  grep -q '/data/local/tmp/dnscrypt-companion.apk' proxy/install_app.sh && echo "✅ staging path"
  ! grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' && echo "✅ SELinux never disabled"
  ```
- [ ] **Play Protect trap** restores the captured value
  ```bash
  grep -q 'package_verifier_enable' proxy/install_app.sh && echo "✅ Play Protect disable"
  grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ restores captured value"
  ```
- [ ] **4 endpoints registered** in `main.go`
  ```bash
  grep -q 'install_companion_app' proxy/main.go && echo "✅ /api/install_companion_app"
  grep -q 'uninstall_companion_app' proxy/main.go && echo "✅ /api/uninstall_companion_app"
  grep -q 'install_token' proxy/main.go && echo "✅ /api?action=install_token"
  grep -q 'companion_app_state' proxy/main.go && echo "✅ /api?action=companion_app_state"
  ```
- [ ] **One-shot CSRF token** (60 s TTL, constant-time compare)
  ```bash
  grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s TTL"
  grep -q 'installTokens' proxy/main.go && echo "✅ token store"
  grep -q 'validateAndConsumeInstallToken' proxy/main.go && echo "✅ one-shot consume"
  grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
  ```
- [ ] **Per-IP rate limit** (5 / 15 min)
  ```bash
  grep -q 'MAX_INSTALL_ATTEMPTS.*5' proxy/main.go && echo "✅ 5 attempts"
  grep -q 'INSTALL_LOCKOUT_PERIOD' proxy/main.go && echo "✅ lockout period"
  grep -q 'isInstallLockedOut' proxy/main.go && echo "✅ enforcement"
  ```
- [ ] **Localhost gate** on all three install surfaces
  ```bash
  grep -q 'isLocalRequest' proxy/main.go && echo "✅ localhost gate applied"
  ```
- [ ] **`HTTP_WRITE_TIMEOUT = 150 s`** > `INSTALL_TIMEOUT = 90 s`
  ```bash
  grep -q 'HTTP_WRITE_TIMEOUT.*150' proxy/main.go && echo "✅ 150 s"
  ```

### v1.5.0 — Layered Bootstrap (Layer 0 / Layer 1)

<!--
  Phase 0 of the v1.5.0 Global Edition: the shell library is split
  into Layer 0 (proxy/boot-mini.sh) and Layer 1 (proxy/functions.sh).
  Enforced by ADR-0003 and by CI Step 9.
-->

- [ ] **`proxy/boot-mini.sh`** present and contains the 5 primitives + constant
  ```bash
  test -s proxy/boot-mini.sh && echo "✅ present"
  for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}\(\)" proxy/boot-mini.sh && echo "✅ primitive: $fn" || echo "❌ missing: $fn"
  done
  grep -q '^_MONITORING_UI_PORT=' proxy/boot-mini.sh && echo "✅ _MONITORING_UI_PORT"
  ```
- [ ] **`proxy/functions.sh` sources Layer 0**
  ```bash
  grep -q 'boot-mini.sh' proxy/functions.sh && echo "✅ sources boot-mini.sh"
  ```
- [ ] **`functions.sh` does NOT redefine Layer-0 primitives**
  ```bash
  for fn in get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}[[:space:]]*\(\)" proxy/functions.sh && echo "❌ redefines: $fn" || echo "✅ $fn not redefined"
  done
  ! grep -qE '^_MONITORING_UI_PORT=' proxy/functions.sh && echo "✅ _MONITORING_UI_PORT not redefined"
  ```
- [ ] **`package_module.sh` bundles `boot-mini.sh` and `install_app.sh`**
  ```bash
  grep -q 'boot-mini.sh' scripts/package_module.sh && echo "✅ boot-mini.sh in package"
  grep -q 'install_app.sh' scripts/package_module.sh && echo "✅ install_app.sh in package"
  ```
- [ ] **`customize.sh` extracts both files (§[9])**
  ```bash
  grep -q "'boot-mini.sh'" proxy/customize.sh && echo "✅ boot-mini.sh in unzip list"
  grep -q "'install_app.sh'" proxy/customize.sh && echo "✅ install_app.sh in unzip list"
  ```
- [ ] **`customize.sh §[10]` verifies both files as critical**
  ```bash
  grep -q 'MISSING.*boot-mini.sh' proxy/customize.sh && echo "✅ boot-mini.sh critical check"
  grep -q 'MISSING.*install_app.sh' proxy/customize.sh && echo "✅ install_app.sh critical check"
  ```
- [ ] **CI guard Step 9 active**
  ```bash
  grep -q 'Verify boot-mini.sh integration' .github/workflows/ci.yml && echo "✅ Step 9 present"
  ```

### v1.5.0 — ADR compliance

- [ ] **ADR-0002 (external dependency — filepath-securejoin)**
  ```bash
  grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ pinned"
  test -f proxy/go.sum && echo "✅ go.sum present"
  grep -q 'filepath-securejoin' proxy/main.go && echo "✅ used in main.go"
  ```
- [ ] **ADR-0003 (Layered Bootstrap)** — verified by the block above
- [ ] **No new external Go dependency** was added beyond `filepath-securejoin`
  ```bash
  grep -E '^\s+[a-z]' proxy/go.mod | grep -v filepath-securejoin | grep -v '^go ' | \
      grep -q '.' && echo "❌ new dependency!" || echo "✅ only filepath-securejoin"
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
| **Companion app version** | `1.0.0` (from `proxy/app-apk.version`) |
| **DNS engine version** | `2.1.18` (from `proxy/dnscrypt-proxy.version`) |
| **Go external dependencies** | `1` (filepath-securejoin v0.7.0 — ADR-0002) |

---

## 📝 What's in this release

- Feature:
- Fix:
- Security:
- Documentation:

### v1.5.0 highlights (if applicable)

- [ ] **One-tap companion app install** — WebUI install button opens the install-method modal (IDX-24): 3 actions across 2 categories
- [ ] **5-level pm install cascade** in `install_app.sh` (1,101 lines)
- [ ] **One-shot CSRF token** (60 s TTL) — new `/api?action=install_token`
- [ ] **Per-IP install rate limit** (5 / 15 min) — separate from `loginAttempts`
- [ ] **SELinux staging** — `/data/local/tmp/dnscrypt-companion.apk` (never `setenforce 0`)
- [ ] **Play Protect temporary disable** + trap restore of `$_VERIFIER_ORIG`
- [ ] **75-second cascade deadline** < 90-second `INSTALL_TIMEOUT`
- [ ] **4 new endpoints** (install_companion_app, uninstall_companion_app, install_token, companion_app_state)
- [ ] **Layered Bootstrap (Phase 0)** — Layer 0 `boot-mini.sh` + Layer 1 `functions.sh` (ADR-0003)
- [ ] **First external Go dependency** — `filepath-securejoin v0.7.0` (ADR-0002, scoped to `removeModule`)
- [ ] **HTTP_WRITE_TIMEOUT raised** from 60 s to 150 s
- [ ] **12 frontend state fixes** (IDX-23, IDX-23b, IDX-24, IDX-25, IDX-25a, IDX-429, IDX-401-DISTINCT, DASH-REFRESH-01, DASH-SESSION-RETRY-01, DASH-HINT-01, DASH-HINT-02, ICON-512-SAFEZONE-01)
- [ ] **9 server-side code-review corrections**:
      - `MAIN-REENT-01` (logger three-layer split)
      - `MAIN-PORTCACHE-01` (30 s port cache)
      - `MAIN-DEADLOCALHOST-01` (removed dead branch)
      - `MAIN-APPENDHASH-01` (hash source aligned)
      - `V15-CODE-01` (companion state three-phase read)
      - `V15-CODE-03` (`callInstallScript` uses `getSystemShell`)
      - `M-1` (`isLocalRequest` uses `net.IP.IsLoopback`)
      - `installAttempts` added to session GC
      - `companionStateCache` invalidated after install/uninstall
- [ ] **Tracked files**: 90 (v1.4.0) → **97** (v1.5.0) — +7 files

### v1.4.0 highlights (if applicable)

- [ ] Companion Android app bundled as OPTIONAL asset at `web/app-debug.apk`
- [ ] `scripts/fetch_app_apk.sh` — new fetcher with cache, SHA256, JSON, offline mode
- [ ] `proxy/app-apk.version` — SSOT for companion app version
- [ ] `GET /app-debug.apk` route in `main.go`
- [ ] iOS PWA logic removed (~35 lines)
- [ ] CodeQL `go/path-injection` fix in `removeModule` (2 alerts closed)

### v1.3.0 highlights (if applicable)

- [ ] PWA install button (WebUI)
- [ ] Live status LED on the Today counter
- [ ] DNS auto-start after boot — critical fix in `service.sh`
- [ ] Server-side rotation refinements — SNAP-MANIFEST + SNAP-MTIME (main.go) + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (functions.sh)

### v1.2.0 highlights (if applicable)

- [ ] 10 defensive layers in `customize.sh`
- [ ] Persistent backup directory at `/sdcard/dnscrypt-webui-backup/`
- [ ] 7-field `runtime_info.backups` object
- [ ] `createAutoBackup` + `backupMu` on 5 destructive endpoints
- [ ] FIX-1 (recovery-mode snapshot-and-reapply)
- [ ] FIX-2 (Service Worker update-banner)
- [ ] Watchdog token (WD-TOKEN)
- [ ] Bilingual WebUI (EN + AR)
- [ ] **Breaking change**: `POST /api/append_denylist` requires `content`
- [ ] 42-scenario CI matrix (`upgrade-test.yml`)

---

## ✅ Post-Merge Plan

- [ ] **Identify the correct release script**:
  - [ ] **Stable / Prerelease**: `./scripts/release.sh vX.Y.Z`
  - [ ] **PATCH-only**: `./scripts/release-patch.sh vX.Y.Z`
- [ ] **Tag push**: `git push origin vX.Y.Z`
- [ ] **`release.yml` triggers**: GitHub Actions publishes the release
- [ ] **Verify artifacts count**:
  ```bash
  gh release view vX.Y.Z --json assets --jq '.assets | length'
  # Expected for v1.5.0: 8 (module ZIP + .sha256 + 4 binaries + APK + APK.sha256)
  ```
- [ ] **Back-merge**: sync `develop` with `main`
  - For `release/*`: **automatic** via `release.yml` (ADR-0001 §3)
  - For `hotfix/*`: **manual** — `make sync`
- [ ] **v1.5.0 post-release verification**:
  ```bash
  # 1. Install the ZIP on a fresh device
  # 2. Verify the WebUI starts on 9090
  # 3. Click "Install App" → install-method modal opens
  # 4. Choose "Install locally"
  # 5. Verify the companion app is installed
  # 6. Verify /data/local/tmp/dnscrypt-companion.apk is removed
  # 7. Verify Play Protect verifier is restored:
  #    adb shell settings get global package_verifier_enable
  # 8. Verify Layer 0/1:
  #    su -c "test -f /data/adb/modules/dnscrypt-proxy-webui/boot-mini.sh && echo present"
  # 9. Verify install_token is localhost-only:
  #    curl -i "http://192.168.1.5:9090/api?action=install_token" → 403
  # 10. Verify the package-name candidates are present:
  #     grep -q 'com.gasciljh.dnscrypt_proxy' proxy/install_app.sh && echo "✅ legacy candidate present"
  ```

### Post-merge commands

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

## 🔙 Rollback Plan

**Choose exactly one strategy before merging:**

- [ ] **Plan A — Delete tag + re-tag** (only if no user has updated yet)
- [ ] **Plan B — Publish a follow-up PATCH** (preferred for user-facing bugs)

**Rollback decision**: <!-- fill: Plan A OR Plan B -->

**Rationale**: <!-- why this plan was chosen -->

### v1.2.0 — data-preservation safety net

- [ ] Confirmed the persistent backup directory will survive rollback
  ```bash
  su -c "ls -la /sdcard/dnscrypt-webui-backup/"
  ```

### v1.4.0 — companion app rollback context

- [ ] Confirmed that rolling back the module does NOT uninstall the companion app
- [ ] Confirmed that a user who installed the companion app can still use it after the module rollback

### v1.5.0 — companion install rollback context

<!--
  The v1.5.0 install flow is best-effort and does not break the
  module. A failed install leaves the module fully functional:

    • No state is written to the module directory.
    • The staging file is removed by the trap.
    • The Play Protect verifier is restored by the trap.
    • The install token expires after 60 s (in-memory only).
    • The rate limiter is in-memory and cleared on restart.

  Rolling back the release therefore has ZERO companion-install
  impact.
-->

- [ ] Confirmed that a failed companion install does not corrupt module state
- [ ] Confirmed that the install token store is ephemeral (in-memory only, 60 s TTL)
- [ ] Confirmed that `installAttempts` (rate limiter) is ephemeral (in-memory, cleared on restart)
- [ ] Confirmed that the companion APK mirror in `/sdcard/dnscrypt-webui-backup/apk/` survives a rollback
- [ ] Confirmed that `/data/local/tmp/dnscrypt-companion.apk` is never left behind (three-way trap)

### v1.5.0 — Layered Bootstrap rollback context

- [ ] Confirmed that `boot-mini.sh` and `functions.sh` are both in the module ZIP
- [ ] If rolling back to a pre-v1.5.0 release, `boot-mini.sh` will not exist — that is expected
- [ ] Confirmed that rolling back does NOT require regenerating `go.sum`

### v1.5.0+ — pending reconciliation

- [ ] `update.json`: `releaseDate` and `x-note-last-updated` are
      pre-populated with the **planned** release date (currently
      `2026-10-13`). `release.sh §[16]` overwrites **both** from a
      single `$NEW_RELEASE_DATE` source at release time, preventing
      drift if the release date slips. Verify both fields are
      **identical** after `release.sh` completes. This does **not**
      block the current release.

---

## 👀 Reviewer Checklist

- [ ] **Version integrity**: `VERSION` = `module.prop` = `update.json` = `sw.js` = `index.html` = `dashboard.html`
- [ ] **versionCode formula**: `MAJOR × 1M + MINOR × 10K + PATCH × 100`
- [ ] **SemVer bump**: matches the highest-severity change
- [ ] **CHANGELOG completeness**: all user-facing changes listed
- [ ] **`zipUrl`** in `update.json` matches the tag name
- [ ] **No untracked changes**: `git status` is clean
- [ ] **Tag name**: `vX.Y.Z` (no typos)
- [ ] **Post-merge plan** confirmed
- [ ] **Rollback plan** documented (Plan A or Plan B chosen)

### v1.1.0-specific

- [ ] `runtime_info` returns `profile_key` + `memory_limit_mb`
- [ ] Memory limit works for all 5 profiles

### v1.2.0-specific

- [ ] **10 defensive layers** present in `customize.sh`
- [ ] **Backup helpers** present in `functions.sh`
- [ ] **7-field `runtime_info.backups`** object
- [ ] **`backupMu`** present in `main.go`
- [ ] **Watchdog token** file exists with mode `0600`
- [ ] **FIX-1** present in `customize.sh` (`RECOVERY_SNAPSHOT_DIR`)
- [ ] **FIX-2** present in both HTML pages
- [ ] **Bilingual WebUI** — toggle present in all three pages
- [ ] **Breaking change** documented in `CHANGELOG.md` and `docs/REFERENCE.md` §2.7.7
- [ ] **`upgrade-test.yml`** green
- [ ] **`make check-backup`** passes

### v1.3.0-specific

- [ ] **DNS auto-start-after-boot fix** in `service.sh` §[19]
- [ ] **Live status LED** markup in `index.html`
- [ ] **SNAP-MANIFEST + SNAP-MTIME** present in `main.go:buildBackupInfo`
- [ ] **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** present in `functions.sh:rotate_backups`
- [ ] **Parallel application** in the other 5 shell scripts
- [ ] **Rotation docs updated** (`docs/REFERENCE.md §4.6`)

### v1.4.0-specific

- [ ] **`scripts/fetch_app_apk.sh`** present and executable
- [ ] **`proxy/app-apk.version`** present with valid `X.Y.Z`
- [ ] **`APK_FILE` constant** in `main.go`
- [ ] **`/app-debug.apk` route** with correct mime type
- [ ] **iOS PWA logic removed**
- [ ] **CodeQL fix** in `removeModule` uses `filepath.Base()` + `securejoin.SecureJoin`
- [ ] **CodeQL analysis** green
- [ ] **8 release artifacts** attached (including the APK)

### v1.5.0-specific

#### Companion install flow

- [ ] **`install_app.sh`** present with 5 cascade levels
- [ ] **Three-way trap split** (EXIT / INT / TERM) with `_CLEANED_UP`
- [ ] **`CASCADE_DEADLINE_SECONDS=75`** < `INSTALL_TIMEOUT=90`
- [ ] **SELinux staging path** present (`/data/local/tmp/dnscrypt-companion.apk`)
- [ ] **No `setenforce 0`** in executable code
- [ ] **Play Protect trap** restores `$_VERIFIER_ORIG`
- [ ] **4 new endpoints** registered in `main.go`
- [ ] **One-shot CSRF token** (60 s TTL) + constant-time compare
- [ ] **Per-IP rate limit** (5 / 15 min) using `installAttempts`
- [ ] **Localhost gate** applied to all three install surfaces
- [ ] **HTTP_WRITE_TIMEOUT=150 s** > `INSTALL_TIMEOUT=90 s`
- [ ] **Cache invalidation**: `invalidateCompanionStateCache()` called after every install/uninstall
- [ ] **Package-name candidates** include the legacy `com.gasciljh.dnsproxy_proxy`:
  ```bash
  grep -q 'com.gasciljh.dnsproxy_proxy' proxy/install_app.sh && echo "✅ legacy candidate present"
  ```

#### Layered Bootstrap

- [ ] **`proxy/boot-mini.sh`** present with 5 primitives + `_MONITORING_UI_PORT`
- [ ] **`proxy/functions.sh`** sources `boot-mini.sh`
- [ ] **`functions.sh` does NOT redefine** any Layer-0 primitive
- [ ] **`package_module.sh`** bundles both `boot-mini.sh` and `install_app.sh`
- [ ] **`customize.sh §[9]`** extracts both files
- [ ] **`customize.sh §[10]`** verifies both files as critical
- [ ] **CI guard Step 9** active (`.github/workflows/ci.yml`)

#### ADR compliance

- [ ] **ADR-0002**: `filepath-securejoin v0.7.0` pinned in `go.mod`, `go.sum` present
- [ ] **ADR-0002**: no other external Go dependency added
- [ ] **ADR-0003**: Layer 0 / Layer 1 split verified (see above)

#### Server-side corrections

- [ ] **MAIN-REENT-01**: `logWithLevel` split into three layers (`logLocked`, `writeLocked`)
- [ ] **MAIN-PORTCACHE-01**: `portConfMu` + `readConfPortCached`
- [ ] **MAIN-DEADLOCALHOST-01**: `isLocalRequest` has no unreachable `"localhost"` branch
- [ ] **MAIN-APPENDHASH-01**: `appendDenylist` uses `getRulesState().DenylistHash`
- [ ] **MAIN-CACHE-01**: `invalidateCompanionStateCache` called after install/uninstall

---

## 📌 Additional Notes

<!--
  Anything the reviewer should know about the release.
-->



---

<!-- ============================================================
     ⚠️  Final reminder before merging:

     ┌─────────────────────────────────────────────────┐
     │  🚀  Release PR — Different rules apply                  │
     ├─────────────────────────────────────────────────┤
     │  1. This PR targets `main` — that is correct here.       │
     │  2. The tag does NOT exist yet — it is created after     │
     │     the merge (or already pushed via release.sh /        │
     │     release-patch.sh).                                   │
     │  3. `release.yml` will publish the release.              │
     │  4. `develop` must be synced after the release:          │
     │       • release/* → automatic via release.yml            │
     │       • hotfix/*  → manual (make sync)                   │
     └─────────────────────────────────────────────────┘

     📖 Full details:
       docs/CONTRIBUTING.md §5      (Branch Strategy)
       docs/CONTRIBUTING.md §11     (Release Process)
       docs/adr/0001-release-workflow.md §4  (Why a separate template)
       docs/adr/0001-release-workflow.md §5  (Why release-patch.sh)
       docs/adr/0002-external-dependency.md  (External dependency — v1.5.0)
       docs/adr/0003-layered-bootstrap.md    (Layered Bootstrap — v1.5.0)
       docs/REFERENCE.md §4         (Backup system)
       docs/GUIDE.md §8             (Emergency recovery)
       docs/REFERENCE.md §4.6       (v1.3.0 rotation semantics)
       docs/REFERENCE.md §3.12      (v1.5.0 backend additions)
       docs/REFERENCE.md §1.4       (v1.5.0 Layered Bootstrap)
       docs/REFERENCE.md §3.12      (install_app.sh contract)

     🎯 Quick verification before opening the PR:

       # 9-place version consistency
       V=$(cat VERSION)
       grep -q "^version=$V" module.prop && echo "✅ module.prop"
       grep -qE "\"version\"[[:space:]]*:[[:space:]]*\"${V#v}\"" web/manifest.json && echo "✅ manifest.json"
       grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
       grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
       grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"
       test -f proxy/app-apk.version && echo "✅ app-apk.version"
       grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ go.mod pin (ADR-0002)"
       grep -q "^## \[${V#v}\]" CHANGELOG.md && echo "✅ CHANGELOG section"
       jq -e ".version == \"$V\"" update.json >/dev/null && echo "✅ update.json"

     🎯 v1.5.0 specific checks:

       # Companion install
       test -f proxy/install_app.sh && echo "✅ install_app.sh"
       grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75 s deadline"
       grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s token TTL"
       ! grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce"
       grep -q "trap '_cleanup_app; exit 130' INT" proxy/install_app.sh && echo "✅ INT trap exits 130"
       grep -q "trap '_cleanup_app; exit 143' TERM" proxy/install_app.sh && echo "✅ TERM trap exits 143"
       grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ trap restores verifier state"
       grep -q 'com.gasciljh.dnscrypt_proxy' proxy/install_app.sh && echo "✅ legacy candidate present"

       # Layered Bootstrap
       test -f proxy/boot-mini.sh && echo "✅ Layer 0 present"
       grep -q 'boot-mini.sh' proxy/functions.sh && echo "✅ Layer 1 sources Layer 0"
       grep -q 'Verify boot-mini.sh integration' .github/workflows/ci.yml && echo "✅ CI Step 9"

       # ADR compliance
       grep -q 'filepath-securejoin' proxy/go.mod && echo "✅ ADR-0002 pin"
       test -f proxy/go.sum && echo "✅ go.sum present"

     📖 Documentation references:

       docs/CONTRIBUTING.md §5                - Branch strategy
       docs/CONTRIBUTING.md §11               - Release process
       docs/adr/README.md                     - Architecture Decision Records
       docs/adr/0001-release-workflow.md      - Release workflow (ADR-0001)
       docs/adr/0002-external-dependency.md   - External dependency (ADR-0002)
       docs/adr/0003-layered-bootstrap.md     - Layered Bootstrap (ADR-0003)
       SECURITY.md                            - Security policy (§5.30–§5.36)
       SECURITY.md §15                        - Audit Corrections Registry
       docs/REFERENCE.md §4.6                 - v1.3.0 rotation semantics
       docs/REFERENCE.md §3.12                - v1.5.0 backend additions
       docs/REFERENCE.md §1.4                 - Layered Bootstrap (v1.5.0)
       docs/REFERENCE.md §3.12                - install_app.sh contract
       docs/REFERENCE.md §4                   - Backup system reference
       docs/REFERENCE.md §7                   - Manifest technical notes
       docs/REFERENCE.md §5.2.4               - On-device SNAP-*/ROT-* verification
       docs/GUIDE.md §5                       - Upgrade guide
       docs/GUIDE.md §8                       - Emergency recovery

     Current version line: v1.5.0
     Last updated: 2026-10-18

     🎉 This is a RELEASE PR — the reviewer should approve quickly
     if the checklists above pass. Nothing else blocks the merge.
     ============================================================ -->