<!-- ============================================================
     DNSCrypt Smart Filter – Release PR Template
     Version: v1.6.0 (Global Edition)
     Last updated: 2026-11-13
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template applies to PRs from `release/*` or `hotfix/*`
     branches targeting `main`.

     ⚠️ HOW TO USE IT:
       GitHub only auto-applies the DEFAULT template
       (.github/PULL_REQUEST_TEMPLATE.md). To use this one, append
       `?template=release.md` to the PR-creation URL:

         https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.6.0?template=release.md

       Full details:
         docs/CONTRIBUTING.md §5 (Branch Strategy)
         docs/CONTRIBUTING.md §11 (Release Process)
         docs/adr/0001-release-workflow.md §4 (PR template split)

     Layout note (v1.6.0):
       Shell scripts live at the REPOSITORY ROOT, not under proxy/.
       • Root shell scripts (10): customize.sh, install_app.sh,
         boot-mini.sh, functions.sh, service.sh, watchdog.sh,
         status.sh, action.sh, uninstall.sh, post-fs-data.sh
       • lib/*.sh (Layer 0, 6 modules): constants, fallbacks,
         process, http, backup, firewall
       • proxy/ (8 files): main.go, go.mod, go.sum, build.sh,
         dnscrypt-proxy.toml, dnscrypt-proxy.version,
         webui.conf, app-apk.version

     Cross-references:
       • docs/CONTRIBUTING.md §5, §11          — branch, release
       • docs/REFERENCE.md §1.4                — Layered Bootstrap (3-layer, v1.6.0)
       • docs/REFERENCE.md §2.6.2              — get_profile (timezone, v1.6.0)
       • docs/REFERENCE.md §3.10               — timezone flow (v1.6.0)
       • docs/REFERENCE.md §3.13               — install_app.sh flow (v1.5.0)
       • docs/REFERENCE.md §4.6                — rotation semantics
       • docs/REFERENCE.md §4.6.5              — SNAP-*/ROT-* rules
       • docs/REFERENCE.md §5.9.1              — on-device SNAP-*/ROT-* verification
       • docs/REFERENCE.md §7                  — manifest technical notes
       • SECURITY.md §5.31–§5.37               — security model
       • SECURITY.md §15                       — audit corrections registry
       • docs/GUIDE.md §5, §8                  — upgrade, recovery
       • docs/adr/0001-release-workflow.md §4, §5
       • docs/adr/0002-external-dependency.md
       • docs/adr/0003-layered-bootstrap.md    — 3-layer model (v1.6.0)
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
- [ ] **`update.json`** `version` + `versionCode` + `zipUrl` + `x-note-v<XYZ>` updated
- [ ] **`CHANGELOG.md`** has a `## [vX.Y.Z] - YYYY-MM-DD` section
- [ ] **`web/sw.js`** `CACHE_VERSION` matches `VERSION` (v1.6.0 requirement)

### Version files verification — 11 places (v1.6.0)

<!--
  v1.1.0 required 5 places. v1.5.0 extended to 9. v1.6.0
  extends to 11:

    1. VERSION
    2. module.prop (version + versionCode)
    3. update.json (version + versionCode + zipUrl + x-note-v<XYZ>)
    4. web/manifest.json (no 'v' prefix — PWA spec)
    5. web/sw.js (CACHE_VERSION)
    6. web/index.html (var VERSION)
    7. web/dashboard.html (var VERSION)
    8. proxy/app-apk.version (companion app version, no 'v')
    9. proxy/dnscrypt-proxy.version (DNS engine, no 'v')     ← v1.6.0
   10. proxy/main.go BuildVersion default                    ← v1.6.0
   11. proxy/go.mod (external dependency pin — ADR-0002)
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
echo "dnscrypt-proxy.ver:   $(cat proxy/dnscrypt-proxy.version)      (no 'v')"
echo "main.go BuildVersion: $(grep 'BuildVersion =' proxy/main.go | sed -E 's/.*"([^"]+)".*/\1/')"
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
dnscrypt-proxy.ver:   2.1.20
main.go BuildVersion: vX.Y.Z
go.mod (ADR-0002):    require github.com/cyphar/filepath-securejoin v0.7.0
```

- [ ] All version fields consistent (9 version strings + 1 dep pin)
- [ ] **`versionCode`** = `MAJOR × 1M + MINOR × 10K + PATCH × 100`

---

## ✅ Pre-Flight — v1.6.0 Additions

### v1.6.0 — Modular shell (`lib/`) + 3-layer Layered Bootstrap

<!--
  v1.5.0 shipped a 2-layer model: boot-mini.sh (Layer 0) +
  functions.sh (Layer 1).

  v1.6.0 EXTENDS it to 3 layers (ADR-0003 §Extension):
    Layer 0: lib/*.sh (6 modules)
    Layer 1: boot-mini.sh (aggregator)
    Layer 2: functions.sh (orchestrator)

  The 5 primitives and _MONITORING_UI_PORT moved from
  boot-mini.sh to lib/constants.sh (canonical) — boot-mini.sh
  §[4] carries the sole documented fallback.
-->

- [ ] **All 6 `lib/*.sh` modules present**
  ```bash
  for M in constants fallbacks process http backup firewall; do
      test -s "lib/$M.sh" && echo "✅ lib/$M.sh" || echo "❌ lib/$M.sh"
  done
  ```

- [ ] **`boot-mini.sh` sources `lib/*.sh` via `_LIB_BASE`**
  ```bash
  grep -q '_LIB_BASE' boot-mini.sh && echo "✅ _LIB_BASE discovery"
  ```

- [ ] **`boot-mini.sh` defines the 5 primitives**
  ```bash
  for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}\(\)" boot-mini.sh && echo "✅ $fn" || echo "❌ $fn"
  done
  ```

- [ ] **`functions.sh` sources `boot-mini.sh` and does NOT redefine Layer-0 primitives**
  ```bash
  grep -q 'boot-mini.sh' functions.sh && echo "✅ Layer 2 → Layer 1"
  for fn in get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}[[:space:]]*\(\)" functions.sh && echo "❌ redefines: $fn" || echo "✅ $fn not redefined"
  done
  ```

- [ ] **`_MONITORING_UI_PORT` canonical + fallback**
  ```bash
  grep -qE '^_MONITORING_UI_PORT="8080"' lib/constants.sh && echo "✅ canonical in lib/constants.sh"
  grep -qE '^_MONITORING_UI_PORT="\$\{_MONITORING_UI_PORT:-' boot-mini.sh && echo "✅ fallback in boot-mini.sh §[4]"
  ! grep -q '_MONITORING_UI_PORT=' customize.sh && echo "✅ customize.sh does not set directly"
  ```

- [ ] **CI Step 9 verifies lib/*.sh + Layer chain**
  ```bash
  grep -q 'Layered Bootstrap (lib/ + boot-mini + functions)' .github/workflows/ci.yml && echo "✅ CI Step 9 (3-layer)"
  ```

- [ ] **`customize.sh §[16]` verifies all 6 `lib/*.sh` files individually**
  ```bash
  grep -q 'lib/constants.sh lib/fallbacks.sh' customize.sh && echo "✅ lib/*.sh in critical check"
  ```

- [ ] **`customize.sh` credential rewrite is section-aware**
  ```bash
  grep -q 'monitoring_ui' customize.sh && echo "✅ monitoring_ui reference"
  ! grep -qE 'sed -i "s\|^\[\[:space:\]\]\*username.*=' customize.sh && echo "✅ no blind sed rewrite"
  ```

- [ ] **`customize.sh` version arithmetic is prerelease-safe**
  ```bash
  grep -q "tr -dc '0-9'" customize.sh && echo "✅ non-numeric stripped"
  ```

### v1.6.0 — Timezone rendering (`last_update_unix` + `formatUnixTimestamp`)

- [ ] **Backend emits `last_update_unix`**
  ```bash
  awk '/func buildProfileResponse/,/^}/' proxy/main.go | grep -q 'last_update_unix' && echo "✅ backend field"
  grep -q 'lastUpdateUnixCache' proxy/main.go && echo "✅ cache field"
  ```

- [ ] **Frontend uses `formatUnixTimestamp()`**
  ```bash
  grep -q 'formatUnixTimestamp' web/index.html && echo "✅ helper present"
  awk '/function renderProfileData/,/^}/' web/index.html | grep -q 'last_update_unix' && echo "✅ prefers Unix field"
  awk '/function renderProfileData/,/^}/' web/index.html | grep -q 'last_update' && echo "✅ falls back to RFC3339"
  ```

- [ ] **`toLocaleString` uses `currentLang` for locale**
  ```bash
  grep -q "currentLang === 'ar' ? 'ar-EG' : 'en-US'" web/index.html && echo "✅ locale argument"
  ```

### v1.6.0 — `buildBackupInfo` mtime sort

<!--
  v1.6.0 fixes a v1.5.0 regression: buildBackupInfo sorted by
  directory name, but rotate_backups and status.sh sorted by
  mtime. The mismatch could produce a stale "latest backup"
  in the API when two snapshots shared a name-prefix but had
  different mtimes.
-->

- [ ] **`buildBackupInfo` sorts by `ModTime()`**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime().Before' && echo "✅ ModTime sort"
  ```

- [ ] **`buildBackupInfo` agrees with `rotate_backups` and `status.sh`**
  ```bash
  # Manually compare after install:
  #   curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name'
  #   su -c "sh status.sh --json" | jq -r '.backups.last_backup_name'
  # Both must be identical.
  ```

### v1.6.0 — PWA cache bump

- [ ] **`CACHE_VERSION` matches `VERSION`**
  ```bash
  V=$(cat VERSION)
  grep -q "const CACHE_VERSION = '$V'" web/sw.js && echo "✅ CACHE_VERSION=$V"
  ```

- [ ] **`PRECACHE_ASSETS` count unchanged (11 files)**
  ```bash
  grep -cE "^\s+'/.*',\s*$" web/sw.js
  # Expected: 11
  ```

### v1.6.0 — DNS version bump

<!--
  v1.6.0 bumped proxy/dnscrypt-proxy.version from 2.1.18 to
  2.1.20. This is a build-visible change (new upstream engine
  binaries ship in the ZIP), independent of the module
  version.
-->

- [ ] **`proxy/dnscrypt-proxy.version` = 2.1.20**
  ```bash
  grep -qE '^2\.1\.20$' proxy/dnscrypt-proxy.version && echo "✅ DNS version 2.1.20"
  ```

- [ ] **`CHANGELOG.md §[v1.6.0]` documents the bump**
  ```bash
  awk '/^## \[v1.6.0\]/,/^## \[v1.5.0\]/' CHANGELOG.md | grep -qi '2\.1\.18.*2\.1\.20\|2\.1\.20' && echo "✅ bump documented"
  ```

- [ ] **`update.json` `x-note-v160` mentions the DNS bump**
  ```bash
  jq -r '."x-note-v160" // empty' update.json | grep -qi '2\.1\.20' && echo "✅ x-note-v160 documents bump"
  ```

### v1.6.0 — ADR-0003 extended (2-layer → 3-layer)

- [ ] **`docs/adr/0003-layered-bootstrap.md` has the `## Extension (v1.6.0)` section**
  ```bash
  grep -q '^## Extension (v1.6.0)' docs/adr/0003-layered-bootstrap.md && echo "✅ Extension section present"
  ```

- [ ] **`docs/adr/0003-layered-bootstrap.md` Status line reflects the extension**
  ```bash
  grep -q '✅ Accepted (extended in v1.6.0' docs/adr/0003-layered-bootstrap.md && echo "✅ Status line updated"
  ```

- [ ] **ADR-0001 and ADR-0002 carry `**Verified in**:` notes**
  ```bash
  grep -q 'Verified in.*v1.6.0' docs/adr/0001-release-workflow.md && echo "✅ ADR-0001 verified"
  grep -q 'Verified in.*v1.6.0' docs/adr/0002-external-dependency.md && echo "✅ ADR-0002 verified"
  ```

---

## ✅ Pre-Flight — v1.5.0 Additions (still required)

### v1.5.0 — Companion install flow (4 endpoints)

- [ ] **`install_app.sh` present at repo root with 5 cascade levels**
  ```bash
  test -s install_app.sh && echo "✅ present"
  wc -l install_app.sh  # expected ~680 lines
  for pattern in 'pm install -r --user 0' \
                 'pm install -r --user 0 -i com.android.shell' \
                 'pm install-create' \
                 'magisk su' \
                 'cmd package install'; do
      grep -q "$pattern" install_app.sh && echo "✅ $pattern" || echo "❌ $pattern"
  done
  ```

- [ ] **Three-way trap split** (EXIT / INT / TERM with `_CLEANED_UP` guard)
  ```bash
  grep -q "trap '_cleanup_app' EXIT" install_app.sh && echo "✅ EXIT trap"
  grep -q "trap '_cleanup_app; exit 130' INT" install_app.sh && echo "✅ INT trap (exit 130)"
  grep -q "trap '_cleanup_app; exit 143' TERM" install_app.sh && echo "✅ TERM trap (exit 143)"
  grep -q '_CLEANED_UP=1' install_app.sh && echo "✅ re-entry guard"
  ```

- [ ] **Cascade deadline** (75 s) present and < `INSTALL_TIMEOUT` (90 s)
  ```bash
  grep -q 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && echo "✅ 75 s deadline"
  grep -q 'INSTALL_TIMEOUT.*90' proxy/main.go && echo "✅ 90 s handler timeout"
  ```

- [ ] **SELinux staging** (never `setenforce 0`)
  ```bash
  grep -q '/data/local/tmp/dnscrypt-companion.apk' install_app.sh && echo "✅ staging path"
  ! grep -v '^[[:space:]]*#' install_app.sh | grep -q 'setenforce 0' && echo "✅ SELinux never disabled"
  ```

- [ ] **Play Protect trap** restores the captured value
  ```bash
  grep -q 'package_verifier_enable' install_app.sh && echo "✅ Play Protect disable"
  grep -q '_VERIFIER_ORIG' install_app.sh && echo "✅ restores captured value"
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

### v1.5.0 — ADR compliance

- [ ] **ADR-0002 (external dependency — filepath-securejoin)**
  ```bash
  grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ pinned"
  test -f proxy/go.sum && echo "✅ go.sum present"
  grep -q 'filepath-securejoin' proxy/main.go && echo "✅ used in main.go"
  ```

- [ ] **No new external Go dependency** beyond `filepath-securejoin`
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
| **DNS engine version** | `2.1.20` (from `proxy/dnscrypt-proxy.version`) |
| **Go external dependencies** | `1` (filepath-securejoin v0.7.0 — ADR-0002) |
| **Tracked files** | `83` (v1.6.0) |
| **Shell modules** | `10` root scripts + `6` lib modules |

---

## 📝 What's in this release

- Feature:
- Fix:
- Security:
- Documentation:

### v1.6.0 highlights (if applicable)

- [ ] **Modular shell (`lib/`)** — 6 single-purpose modules extracted (constants, fallbacks, process, http, backup, firewall)
- [ ] **3-layer Layered Bootstrap** — `lib/*.sh` → `boot-mini.sh` → `functions.sh` (ADR-0003 extended)
- [ ] **WebUI timezone fix** — `last_update_unix` (backend) + `formatUnixTimestamp` (frontend) → local device time instead of UTC
- [ ] **PWA cache bump** — `CACHE_VERSION = 'v1.6.0'` forces existing clients to re-fetch assets
- [ ] **`buildBackupInfo` mtime sort** — aligns `main.go` with `rotate_backups` and `status.sh` (SNAP-MTIME consistency)
- [ ] **DNS version bump** — `proxy/dnscrypt-proxy.version` 2.1.18 → 2.1.20
- [ ] **`customize.sh` hardening** — section-aware credential rewrite (only `[monitoring_ui]`), prerelease-safe version arithmetic, individual `lib/*.sh` validation
- [ ] **`main.go` line count**: `~4,900` (v1.6.0)
- [ ] **CI Step 9 extended** — verifies all 6 `lib/*.sh` modules + 3-layer chain
- [ ] **CI Step 10 moved** — `_MONITORING_UI_PORT` now canonical in `lib/constants.sh`
- [ ] **CI Step 11 added** — verifies timezone fields, mtime sort, `make check-consistency`
- [ ] **Tracked files**: `83` (v1.6.0) — +6 `lib/*.sh` modules since v1.5.0

### v1.5.0 highlights (if applicable)

- [ ] **One-tap companion app install** — WebUI install button opens the install-method modal (IDX-24): 3 actions across 2 categories
- [ ] **5-level pm install cascade** in `install_app.sh` (~680 lines)
- [ ] **One-shot CSRF token** (60 s TTL) — new `/api?action=install_token`
- [ ] **Per-IP install rate limit** (5 / 15 min) — separate from `loginAttempts`
- [ ] **SELinux staging** — `/data/local/tmp/dnscrypt-companion.apk` (never `setenforce 0`)
- [ ] **Play Protect temporary disable** + trap restore of `$_VERIFIER_ORIG`
- [ ] **75-second cascade deadline** < 90-second `INSTALL_TIMEOUT`
- [ ] **4 new endpoints** (install_companion_app, uninstall_companion_app, install_token, companion_app_state)
- [ ] **Layered Bootstrap (Phase 0, v1.5.0 model)** — Layer 0 `boot-mini.sh` + Layer 1 `functions.sh` (superseded by v1.6.0 3-layer model in ADR-0003 §Extension)
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
- [ ] **Tracked files**: 80 → **97** (v1.5.0)

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
  # Expected for v1.6.0: 8 (module ZIP + .sha256 + 4 binaries + APK + APK.sha256)
  ```
- [ ] **Back-merge**: sync `develop` with `main`
  - For `release/*`: **automatic** via `release.yml` (ADR-0001 §3)
  - For `hotfix/*`: **manual** — `make sync`
- [ ] **v1.6.0 post-release verification**:
  ```bash
  # 1. Install the ZIP on a fresh device
  # 2. Verify the WebUI starts on 9090
  # 3. Verify all 6 lib/*.sh modules load on boot:
  #    su -c "ls /data/adb/modules/dnscrypt-proxy-webui/lib/*.sh | wc -l"
  #    Expected: 6
  # 4. Verify the 3-layer chain works:
  #    su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; type init_runtime_paths >/dev/null && echo OK"
  # 5. Verify timezone rendering:
  #    Open the WebUI → "Last update:" must match `date` output
  # 6. Verify the API field:
  #    curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
  #        jq '{last_update, last_update_unix}'
  #    Both present; last_update_unix is an integer
  # 7. Verify mtime sort (all three agree):
  #    curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name'
  #    su -c "sh status.sh --json" | jq -r '.backups.last_backup_name'
  #    Both must be identical
  # 8. Verify DNS version:
  #    cat /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.version
  #    Expected: 2.1.20
  # 9. Verify the PWA cache bump:
  #    Open the WebUI in a browser → "Update available" banner → Reload
  #    Reload → check the "Last update:" line reflects local time
  # 10. Verify the 3.12/3.13 section numbers in the API:
  #     docs/REFERENCE.md §3.13 covers install_app.sh flow
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

### v1.5.0 — Layered Bootstrap rollback context (v1.6.0 update)

- [ ] Confirmed that `boot-mini.sh` and `functions.sh` are both in the module ZIP
- [ ] Confirmed that `lib/*.sh` (6 modules) are in the module ZIP
- [ ] If rolling back to a pre-v1.5.0 release, `boot-mini.sh` and `lib/` will not exist — that is expected
- [ ] If rolling back to v1.5.0, `lib/` will not exist (v1.5.0 had a 2-layer model) — expected
- [ ] Confirmed that rolling back does NOT require regenerating `go.sum`

### v1.6.0 — rollback context

- [ ] Confirmed the timezone fix degrades gracefully if the backend is reverted to v1.5.0:
      the frontend's `formatUnixTimestamp()` returns `null`, and `renderProfileData` falls back to the RFC3339 string
- [ ] Confirmed the mtime sort is a read-only change (no user data impact)
- [ ] Confirmed `CACHE_VERSION` bump is reversible (bumping it to a lower value is allowed; clients will re-fetch)

### v1.6.0 — pending reconciliation

- [ ] `update.json`: `releaseDate` and `x-note-last-updated` are
      pre-populated with the **planned** release date (currently
      `2026-11-12`). `scripts/release.sh` overwrites **both** from a
      single `$NEW_RELEASE_DATE` source at release time, preventing
      drift if the release date slips. Verify both fields are
      **identical** after `scripts/release.sh` completes.

---

## 👀 Reviewer Checklist

- [ ] **Version integrity**: `VERSION` = `module.prop` = `update.json` = `sw.js` = `index.html` = `dashboard.html` = `main.go BuildVersion`
- [ ] **versionCode formula**: `MAJOR × 1M + MINOR × 10K + PATCH × 100`
- [ ] **SemVer bump**: matches the highest-severity change
- [ ] **CHANGELOG completeness**: all user-facing changes listed
- [ ] **`zipUrl`** in `update.json` matches the tag name
- [ ] **`x-note-v<XYZ>`** present in `update.json`
- [ ] **No untracked changes**: `git status` is clean
- [ ] **Tag name**: `vX.Y.Z` (no typos)
- [ ] **Post-merge plan** confirmed
- [ ] **Rollback plan** documented (Plan A or Plan B chosen)

### v1.1.0-specific

- [ ] `runtime_info` returns `profile_key` + `memory_limit_mb`
- [ ] Memory limit works for all 5 profiles

### v1.2.0-specific

- [ ] **10 defensive layers** present in `customize.sh`
- [ ] **Backup helpers** present in `functions.sh` (via `lib/backup.sh`)
- [ ] **7-field `runtime_info.backups`** object
- [ ] **`backupMu`** present in `main.go`
- [ ] **Watchdog token** file exists with mode `0600`
- [ ] **FIX-1** present in `customize.sh` (`RECOVERY_SNAPSHOT_DIR`)
- [ ] **FIX-2** present in both HTML pages
- [ ] **Bilingual WebUI** — toggle present in all three pages
- [ ] **Breaking change** documented in `CHANGELOG.md` and `docs/REFERENCE.md` §2.7.7
- [ ] **`upgrade-test.yml`** green (42 scenarios)
- [ ] **`make check-backup`** passes (all 16 shell scripts)

### v1.3.0-specific

- [ ] **DNS auto-start-after-boot fix** in `service.sh` §[18]
- [ ] **Live status LED** markup in `index.html`
- [ ] **SNAP-MANIFEST + SNAP-MTIME** present in `main.go:buildBackupInfo`
- [ ] **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** present in `lib/backup.sh:rotate_backups`
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

- [ ] **`install_app.sh`** present at root with 5 cascade levels
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
- [ ] **Package-name candidates** include the legacy `com.gasciljh.dnscrypt_proxy`:
  ```bash
  grep -q 'com.gasciljh.dnscrypt_proxy' install_app.sh && echo "✅ legacy candidate present"
  ```

#### Server-side corrections

- [ ] **MAIN-REENT-01**: `logWithLevel` split into three layers (`logLocked`, `writeLocked`)
- [ ] **MAIN-PORTCACHE-01**: `portConfMu` + `readConfPortCached`
- [ ] **MAIN-DEADLOCALHOST-01**: `isLocalRequest` has no unreachable `"localhost"` branch
- [ ] **MAIN-APPENDHASH-01**: `appendDenylist` uses `getRulesState().DenylistHash`
- [ ] **MAIN-CACHE-01**: `invalidateCompanionStateCache` called after install/uninstall

### v1.6.0-specific

#### Modular shell (`lib/`)

- [ ] **All 6 `lib/*.sh` modules present** (constants, fallbacks, process, http, backup, firewall)
- [ ] **`boot-mini.sh` sources them via `_LIB_BASE`**
- [ ] **`functions.sh` sources `boot-mini.sh`** without redefining any Layer-0 primitive
- [ ] **`_MONITORING_UI_PORT` canonical** in `lib/constants.sh`; fallback in `boot-mini.sh §[4]`
- [ ] **CI Step 9 (v1.6.0 extended)** verifies all 6 modules + 3-layer chain
- [ ] **`customize.sh §[16]`** verifies all 6 `lib/*.sh` individually
- [ ] **`customize.sh` credential rewrite** is section-aware (only `[monitoring_ui]`)
- [ ] **`customize.sh` version arithmetic** is prerelease-safe

#### Timezone

- [ ] **`last_update_unix`** emitted by `buildProfileResponse()`
- [ ] **`formatUnixTimestamp()`** used by `renderProfileData()`
- [ ] **`toLocaleString()` locale** respects `currentLang` (`ar-EG` / `en-US`)
- [ ] **Fallback to RFC3339** when `last_update_unix` is absent

#### mtime sort

- [ ] **`buildBackupInfo()`** sorts by `ModTime()`
- [ ] **Agreement** between API, `status.sh --json`, and `rotate_backups`

#### PWA cache

- [ ] **`CACHE_VERSION`** matches `VERSION`
- [ ] **`PRECACHE_ASSETS`** count unchanged (11 files)

#### DNS version

- [ ] **`proxy/dnscrypt-proxy.version`** = `2.1.20`
- [ ] **`CHANGELOG.md §[v1.6.0]`** documents the bump
- [ ] **`update.json` `x-note-v160`** mentions the bump

#### ADR-0003 extension

- [ ] **`docs/adr/0003-layered-bootstrap.md`** has `## Extension (v1.6.0)`
- [ ] **Status line** reflects `✅ Accepted (extended in v1.6.0)`
- [ ] **ADR-0001 / ADR-0002** carry `**Verified in**:` v1.6.0 notes

#### Total tracked files

- [ ] **`git ls-files | wc -l`** = `84`

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
       docs/CONTRIBUTING.md §5               (Branch Strategy)
       docs/CONTRIBUTING.md §11              (Release Process)
       docs/adr/0001-release-workflow.md §4  (Why a separate template)
       docs/adr/0001-release-workflow.md §5  (Why release-patch.sh)
       docs/adr/0002-external-dependency.md  (External dependency — v1.5.0)
       docs/adr/0003-layered-bootstrap.md    (Layered Bootstrap — v1.5.0, extended v1.6.0)
       docs/REFERENCE.md §1.4                (Layered Bootstrap — 3-layer)
       docs/REFERENCE.md §2.6.2              (get_profile — timezone)
       docs/REFERENCE.md §3.10               (Timezone flow — v1.6.0)
       docs/REFERENCE.md §3.13               (install_app.sh flow — v1.5.0)
       docs/REFERENCE.md §4                  (Backup system)
       docs/REFERENCE.md §4.6                (Rotation semantics — v1.3.0)
       docs/REFERENCE.md §4.6.5              (SNAP-*/ROT-* rules)
       docs/REFERENCE.md §5.9.1              (On-device SNAP-*/ROT-* verification)
       docs/REFERENCE.md §7                  (Manifest technical notes)
       docs/GUIDE.md §5                      (Upgrade guide)
       docs/GUIDE.md §8                      (Emergency recovery)

     🎯 Quick verification before opening the PR:

       # 11-place version consistency (v1.6.0)
       V=$(cat VERSION)
       grep -q "^version=$V" module.prop && echo "✅ module.prop"
       grep -qE "\"version\"[[:space:]]*:[[:space:]]*\"${V#v}\"" web/manifest.json && echo "✅ manifest.json"
       grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
       grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
       grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"
       test -f proxy/app-apk.version && echo "✅ app-apk.version"
       test -f proxy/dnscrypt-proxy.version && echo "✅ dnscrypt-proxy.version"
       grep -q "BuildVersion = \"$V\"" proxy/main.go && echo "✅ main.go BuildVersion"
       grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ go.mod pin (ADR-0002)"
       grep -q "^## \[${V#v}\]" CHANGELOG.md && echo "✅ CHANGELOG section"
       jq -e ".version == \"$V\"" update.json >/dev/null && echo "✅ update.json"

     🎯 v1.6.0 specific checks:

       # Modular shell (lib/)
       for M in constants fallbacks process http backup firewall; do
           test -s "lib/$M.sh" && echo "✅ lib/$M.sh"
       done
       grep -q '_LIB_BASE' boot-mini.sh && echo "✅ boot-mini.sh sources lib/*.sh"
       grep -q 'boot-mini.sh' functions.sh && echo "✅ functions.sh sources boot-mini.sh"
       grep -qE '^_MONITORING_UI_PORT="8080"' lib/constants.sh && echo "✅ canonical in lib/constants.sh"
       grep -qE '^_MONITORING_UI_PORT="\$\{_MONITORING_UI_PORT:-' boot-mini.sh && echo "✅ fallback in boot-mini.sh §[4]"

       # Timezone
       awk '/func buildProfileResponse/,/^}/' proxy/main.go | grep -q 'last_update_unix' && echo "✅ backend field"
       grep -q 'formatUnixTimestamp' web/index.html && echo "✅ frontend helper"
       grep -q "currentLang === 'ar' ? 'ar-EG' : 'en-US'" web/index.html && echo "✅ locale argument"

       # mtime sort
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime().Before' && echo "✅ mtime sort"

       # PWA cache
       grep -q "const CACHE_VERSION = '$V'" web/sw.js && echo "✅ CACHE_VERSION=$V"

       # DNS version bump
       grep -qE '^2\.1\.20$' proxy/dnscrypt-proxy.version && echo "✅ DNS 2.1.20"
       awk '/^## \[v1.6.0\]/,/^## \[v1.5.0\]/' CHANGELOG.md | grep -q '2\.1\.20' && echo "✅ CHANGELOG documents bump"
       jq -r '."x-note-v160" // empty' update.json | grep -qi '2\.1\.20' && echo "✅ x-note-v160 documents bump"

     🎯 v1.5.0 specific checks:

       # Companion install
       test -s install_app.sh && echo "✅ install_app.sh (root)"
       grep -q 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && echo "✅ 75 s deadline"
       grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s token TTL"
       ! grep -v '^[[:space:]]*#' install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce"
       grep -q "trap '_cleanup_app; exit 130' INT" install_app.sh && echo "✅ INT trap exits 130"
       grep -q "trap '_cleanup_app; exit 143' TERM" install_app.sh && echo "✅ TERM trap exits 143"
       grep -q '_VERIFIER_ORIG' install_app.sh && echo "✅ trap restores verifier state"
       grep -q 'com.gasciljh.dnscrypt_proxy' install_app.sh && echo "✅ legacy candidate present"

       # ADR compliance
       grep -q 'filepath-securejoin' proxy/go.mod && echo "✅ ADR-0002 pin"
       test -f proxy/go.sum && echo "✅ go.sum present"

     📖 Documentation references:

       docs/CONTRIBUTING.md §5                - Branch strategy
       docs/CONTRIBUTING.md §11               - Release process
       docs/adr/README.md                     - Architecture Decision Records
       docs/adr/0001-release-workflow.md      - Release workflow (ADR-0001)
       docs/adr/0002-external-dependency.md   - External dependency (ADR-0002)
       docs/adr/0003-layered-bootstrap.md     - Layered Bootstrap (ADR-0003, extended v1.6.0)
       SECURITY.md                            - Security policy (§5.31–§5.37)
       SECURITY.md §15                        - Audit Corrections Registry
       docs/REFERENCE.md §1.4                 - Layered Bootstrap (3-layer)
       docs/REFERENCE.md §2.6.2               - get_profile (timezone)
       docs/REFERENCE.md §3.10                - Timezone flow
       docs/REFERENCE.md §3.13                - install_app.sh flow
       docs/REFERENCE.md §4                   - Backup system reference
       docs/REFERENCE.md §4.6                 - Rotation semantics
       docs/REFERENCE.md §4.6.5               - SNAP-*/ROT-* rules
       docs/REFERENCE.md §5.9.1               - On-device SNAP-*/ROT-* verification
       docs/REFERENCE.md §7                   - Manifest technical notes
       docs/GUIDE.md §5                       - Upgrade guide
       docs/GUIDE.md §8                       - Emergency recovery

     Current version line: v1.6.0
     Last updated: 2026-11-12

     🎉 This is a RELEASE PR — the reviewer should approve quickly
     if the checklists above pass. Nothing else blocks the merge.
     ============================================================ -->