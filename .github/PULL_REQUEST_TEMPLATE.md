<!-- ============================================================
     DNSCrypt Smart Filter – Pull Request Template
     Version: v1.6.0 (Global Edition)
     Last updated: 2026-11-13
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template appears automatically when a new PR is opened
     against `develop`.

     For release/hotfix PRs targeting `main`, use the release
     template instead (see "Before You Start" below).

     Layout note (v1.6.0): shell scripts live at the repository
     root, not under proxy/. Only Go sources, the WebUI, and
     version/config files reside under proxy/:
       • Shell scripts (root): customize.sh, install_app.sh,
         boot-mini.sh, functions.sh, service.sh, watchdog.sh,
         status.sh, action.sh, uninstall.sh, post-fs-data.sh
       • lib/*.sh (Layer 0): constants, fallbacks, process,
         http, backup, firewall
       • proxy/ (8 files): main.go, go.mod, go.sum, build.sh,
         dnscrypt-proxy.toml, dnscrypt-proxy.version,
         webui.conf, app-apk.version
     ============================================================ -->

> ## 🚨 Before You Start
>
> **This is the DEFAULT template** — for features, fixes, docs, chores,
> refactors, and tests targeting `develop`.
>
> **If your PR is a RELEASE** (`release/*` → `main` or `hotfix/*` → `main`),
> use the release template instead:
>
> ```text
> https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...<your-branch>?template=release.md
> ```

---

## 🎯 Target Branch

> ⚠️ Choosing the wrong base branch will block your PR.

**Choose exactly one:**

- [ ] **Target: `develop`** — for `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*`
  *(Correct for 99% of PRs.)*
- [ ] **Target: `main`** — **only** for `release/*` or `hotfix/*` branches
  *(If you check this, switch to the release template.)*

| Your branch starts with… | PR base | Template |
|---|---|---|
| `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/` | `develop` | **This one** |
| `release/`, `hotfix/` | `main` | **Release** (`?template=release.md`) |

📖 Full details: [`docs/CONTRIBUTING.md`](../docs/CONTRIBUTING.md) §5.

---

## 📝 Description

<!-- Brief and clear description: what and why — not just how. -->



---

## 🔗 Related Issue

<!-- Examples: Closes #123, Fixes #456, Resolves #789, Refs #101 -->

Closes #

---

## 🏷️ Change Type

- [ ] 🐛 **Bug fix** — fixes an error (PATCH)
- [ ] ✨ **Feature** — new feature (MINOR)
- [ ] 💥 **Breaking change** — breaks compatibility (MAJOR)
- [ ] 🔒 **Security fix** — security fix (PATCH)
- [ ] ⚡ **Performance** — performance improvement (PATCH)
- [ ] ♻️ **Refactor** — restructuring without behavior change (PATCH)
- [ ] 📖 **Documentation** — documentation only
- [ ] 🎨 **Style/UI** — style or interface
- [ ] 🔧 **Chore/Build** — routine tasks or build system
- [ ] ⚙️ **CI/CD** — CI workflows
- [ ] 🌐 **Translation** — translation (EN/AR)
- [ ] 📋 **ADR** — Architecture Decision Record
- [ ] 💾 **Data preservation** — touches the 10 defensive layers
- [ ] 🔄 **Rotation semantics** — touches SNAP-MANIFEST, SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, or ROT-PROTECT
- [ ] 📱 **Companion app** — touches `proxy/app-apk.version`, `scripts/fetch_app_apk.sh`, or the `/app-debug.apk` route
- [ ] 🆕 **Companion install flow** — touches `install_app.sh`, the 4 install endpoints, the install token store, or the install-method modal (IDX-24)
- [ ] 🧩 **Layered Bootstrap** — touches `lib/*.sh`, `boot-mini.sh`, or `functions.sh`
- [ ] 🕐 **Timezone rendering (v1.6.0)** — touches `last_update_unix` (backend) or `formatUnixTimestamp` (frontend)

---

## 🔍 Audit Correction (for security/architecture fixes)

<!--
  Fill only if the PR fixes an architectural or security issue.

  ┌─────────────────────────────────────────────────┐
  │  Audit Corrections Registry (v1.0.0)                    │
  ├─────────────────────────────────────────────────┤
  │  #13  CSRF-GET → POST-only                v1.0.0        │
  │  #14  pgrep -x (no false positives)       v1.0.0        │
  │  #15-a Remove token from login response   v1.0.0        │
  │  #15-b Allow: POST header for 405         v1.0.0        │
  │  #16-a/b IPv4/IPv6 firewall separation    v1.0.0        │
  │  #17  Custom Chains (Orphan Fix)          v1.0.0        │
  │  #18  STATUS_FILE Semantics               v1.0.0        │
  │  #19  IPv6 Rate Limit Bypass              v1.0.0        │
  │  #20  Port Collision 8080                 v1.0.0        │
  │  #21  Section-Restricted TOML             v1.0.0        │
  │  #22  Basic Auth Rate Limit               v1.0.0        │
  │  #23  Section header with comment         v1.0.0        │
  │  #24  Exact endpoint matching             v1.0.0        │
  │  #25  Dashboard JSON Conversion           v1.0.0        │
  │  #26  Preserve Settings on Upgrade        v1.0.0        │
  │  #27  fuser PID parsing                   v1.0.0        │
  │  #28  Login POST-only (CSRF)              v1.0.0        │
  │  #29  readConfPort range check            v1.0.0        │
  │  #30  /readyz localhost-only              v1.0.0        │
  │  #31  shellQuote injection protection     v1.0.0        │
  │  #32  rebuildMu mutex (RACE-1)            v1.0.0        │
  │  #33  runtime_info dynamic ports          v1.0.0        │
  └─────────────────────────────────────────────────┘

  ℹ️  Full registry (#1–#33): see `SECURITY.md` §15.1.
  ⚠️ v1.1.0 through v1.6.0 do NOT add new audit corrections —
     they are runtime, data-preservation, feature, integration,
     modularization, and polish releases. See SECURITY.md §15.2.
  If your PR fixes a new security issue, add entry #34.
-->

- **Audit Correction number**: #
- **Title**:
- **Documentation reference**: `SECURITY.md`

**Problem summary**:



**Solution summary**:

---

## 🧪 Testing

### Mandatory checks

- [ ] `make build` passed (Go build for all 4 architectures)
- [ ] `bash -n` clean on all modified shell scripts (root `*.sh`, `lib/*.sh`, `scripts/*.sh`)
- [ ] `gofmt -l proxy/` is empty (no unformatted files)
- [ ] `shellcheck --severity=warning *.sh lib/*.sh scripts/*.sh` is clean
- [ ] No hardcoded secrets (`detect-secrets` clean)
- [ ] **v1.2.0**: `make check-backup` passes (if `customize.sh` or `functions.sh` changed)
- [ ] **v1.4.0**: `make check-app-version` passes (if `proxy/app-apk.version` changed)
- [ ] **v1.5.0**: `make check-install-app` passes (if `install_app.sh` changed)
- [ ] **v1.6.0**: `make check-boot-mini` passes (if `lib/*.sh`, `boot-mini.sh`, or `functions.sh` changed)
- [ ] **v1.6.0**: `make check-consistency` passes (no `proxy/*.sh` refs in docs; no `customize.sh §[2]` for `_MONITORING_UI_PORT`)

### 🆕 Core fix verifications (v1.0.0)

> ⚠️ "Fix #N" labels are internal dev references — NOT Audit Correction IDs:
>
> | Dev fix | Audit Correction |
> |---|---|
> | Fix #1 (Dashboard JSON) | #25 |
> | Fix #2 (Shell fallback) | *(pre-registry)* |
> | Fix #8 (Basic Auth rate limit) | #22 |
> | Fix #12 (Exact endpoint matching) | #24 |

- [ ] **Fix #1 — Dashboard JSON conversion**
  ```bash
  grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅"
  grep -q 'func parsePrometheus' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #2 — Shell fallback**
  ```bash
  grep -q 'func getSystemShell' proxy/main.go && echo "✅"
  ! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #8 — Basic Auth rate limit**
  ```bash
  grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅"
  ```
- [ ] **Fix #12 — Exact endpoint matching**
  ```bash
  grep -q 'func hasEndpoint' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-1 — Login POST-only**
  ```bash
  grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-3 — readConfPort range check**
  ```bash
  awk '/func readConfPort/,/^}/' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅"
  ```
- [ ] **NEW-4 — /readyz localhost-only**
  ```bash
  awk '/func handleReadyz/,/^}/' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅"
  ```
- [ ] **NEW-5 — shellQuote**
  ```bash
  grep -q 'func shellQuote' proxy/main.go && echo "✅"
  ```
- [ ] **NEW-6 — Auth cache**
  ```bash
  grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅"
  ```
- [ ] **RACE-1 — rebuildMu mutex**
  ```bash
  grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅"
  ```
- [ ] **PORT-2 — runtime_info ports**
  ```bash
  awk '/func buildRuntimeInfo/,/^}/' proxy/main.go | grep -q '"webui_port"' && echo "✅"
  ```

### 🆕 v1.1.0 additions

- [ ] **MEM-1 — Dynamic memory limit**
  ```bash
  grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅"
  grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅"
  grep -q 'MEMORY_LIMIT_ULTIMATE' proxy/main.go && echo "✅"
  ! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded limit"
  ```

- [ ] **MEM-2 — Extended shellQuote**
  ```bash
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "'{'" && echo "✅ braces"
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
  ```

- [ ] **MEM-3 — MONITORING_UI_PORT**
  ```bash
  grep -q 'MONITORING_UI_PORT = "8080"' proxy/main.go && echo "✅ const"
  awk '/func metricsProxyHandler/,/^}/' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ used"
  ! grep -q '"http://127.0.0.1:8080/api/metrics"' proxy/main.go && echo "✅ no hardcoded URL"
  ```

- [ ] **v1.1.0 — runtime_info new fields**
  ```bash
  awk '/func buildRuntimeInfo/,/^}/' proxy/main.go | grep -q '"memory_limit_mb"' && echo "✅ backend"
  awk '/func buildRuntimeInfo/,/^}/' proxy/main.go | grep -q '"profile_key"' && echo "✅ backend"
  grep -q "riMemoryLimit" web/index.html && echo "✅ index.html"
  grep -q "riMemoryLimit" web/dashboard.html && echo "✅ dashboard.html"
  ```

### 🆕 v1.2.0 additions — Data Preservation

- [ ] **v1.2.0 — 10 defensive layers present in customize.sh**
  ```bash
  for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
           transaction_begin detect_root_solution copy_with_context \
           RECOVERY_TRIGGER migrate_config; do
      grep -q "$L" customize.sh && echo "✅ $L" || echo "❌ $L"
  done
  ```

- [ ] **v1.2.0 — Backup helpers present in functions.sh**
  ```bash
  for H in auto_backup_if_needed rotate_backups backup_user_files \
           restore_user_files cleanup_old_transactions get_backup_dir \
           ensure_backup_dir get_last_backup_time copy_with_context \
           verify_backup_integrity write_manifest get_watchdog_token; do
      grep -q "$H" functions.sh && echo "✅ $H" || echo "❌ $H"
  done
  ```

- [ ] **v1.2.0 — main.go backup additions**
  ```bash
  grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2 createAutoBackup"
  grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 backupMu"
  grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"
  grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"
  grep -q 'func buildBackupInfo' proxy/main.go && echo "✅ BAK-1 function"
  ```

- [ ] **v1.2.0 — 7-field backups schema**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'in_flight_txn' && echo "✅"
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'orphan_txn' && echo "✅"
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```

- [ ] **v1.2.0 — Watchdog token (WD-TOKEN)**
  ```bash
  grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ loader"
  grep -q 'verifyWatchdogToken' proxy/main.go && echo "✅ verify"
  grep -q 'X-Watchdog-Token' proxy/main.go && echo "✅ header"
  grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
  grep -q 'watchdog_token' watchdog.sh && echo "✅ watchdog reads"
  grep -q 'X-Watchdog-Token' watchdog.sh && echo "✅ watchdog sends"
  ```

- [ ] **v1.2.0 — FIX-1 (recovery-mode snapshot-and-reapply)**
  ```bash
  grep -q 'RECOVERY_SNAPSHOT_DIR' customize.sh && echo "✅ snapshot dir"
  grep -q 'Re-applying recovery snapshot' customize.sh && echo "✅ §[13] re-apply block"
  ```

- [ ] **v1.2.0 — FIX-2 (Service Worker update-banner)**
  ```bash
  grep -q 'swRegistration.waiting' web/index.html && echo "✅ index.html"
  grep -q 'swRegistration.waiting' web/dashboard.html && echo "✅ dashboard.html"
  grep -q 'id="swUpdateBanner"' web/dashboard.html && echo "✅ banner in dashboard.html"
  ```

- [ ] **v1.2.0 — Bilingual WebUI (EN + AR)**
  ```bash
  for f in index.html dashboard.html offline.html; do
      grep -q 'id="langToggle"' web/$f && echo "✅ $f toggle"
      grep -q 'en:' web/$f && grep -q 'ar:' web/$f && echo "✅ $f en+ar"
      grep -q "dnscrypt-lang" web/$f && echo "✅ $f localStorage"
      grep -q '\[dir="rtl"\]' web/$f && echo "✅ $f RTL"
  done
  ```

### 🆕 v1.3.0 additions — PWA install button + LED + DNS auto-start + rotation

- [ ] **v1.3.0 — DNS auto-start-after-boot fix (service.sh)**
  ```bash
  grep -q 'v1.3.0 FIX' service.sh && echo "✅ §[18] block present"
  grep -q 'ensure_running_service' service.sh && echo "✅ API call present"
  grep -q 'X-Watchdog-Token' service.sh && echo "✅ uses token"
  ```

- [ ] **v1.3.0 — Live status LED (index.html)**
  ```bash
  grep -q 'led-on' web/index.html && echo "✅ led-on class"
  grep -q 'led-off' web/index.html && echo "✅ led-off class"
  grep -q 'updateStatsDisplay' web/index.html && echo "✅ LED rendered by updateStatsDisplay"
  ```

- [ ] **v1.3.0 — SNAP-MANIFEST (main.go:buildBackupInfo)**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
  ```

- [ ] **v1.3.0 — SNAP-MTIME (main.go:buildBackupInfo)**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
  ```

- [ ] **v1.3.0 — ROT-MANIFEST + ROT-MTIME + ROT-PROTECT (functions.sh)**
  ```bash
  awk '/rotate_backups\(\)/,/^}/' functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
  awk '/rotate_backups\(\)/,/^}/' functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
  awk '/rotate_backups\(\)/,/^}/' functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"
  ```

- [ ] **v1.3.0 — Parallel application in shell scripts**
  ```bash
  # Note: `list_snapshots` / `count_snapshots` are defined in lib/backup.sh §[5]
  # and sourced via functions.sh. `_list_snapshots` (with underscore) does not
  # exist — that was a pre-v1.6.0 historical name.
  grep -q 'list_snapshots' status.sh && echo "✅ status.sh helper"
  grep -qE 'read_last_stable|count_snapshots' watchdog.sh && echo "✅ watchdog.sh helpers"
  grep -qE '\.manifest\.json|write_manifest_to' customize.sh && echo "✅ customize.sh manifest write"
  grep -q 'count_snapshots' action.sh && echo "✅ action.sh helper"
  grep -qE 'list_snapshots|count_snapshots' uninstall.sh && echo "✅ uninstall.sh helper"
  ```

### 🆕 v1.4.0 additions — Companion APK + CodeQL + iOS removal

- [ ] **v1.4.0 — Companion APK route + constant (main.go)**
  ```bash
  grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
  grep -q '/app-debug.apk' proxy/main.go && echo "✅ route registered"
  grep -q 'application/vnd.android.package-archive' proxy/main.go && echo "✅ mime type"
  ```

- [ ] **v1.4.0 — CodeQL path-injection fix in removeModule**
  ```bash
  grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ filepath.Base"
  grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ SecureJoin (ADR-0002)"
  awk '/func removeModule/,/^}/' proxy/main.go | grep -q 'expectedPrefix' && echo "✅ prefix guard"
  ```

- [ ] **v1.4.0 — Companion APK fetcher + version file**
  ```bash
  test -f scripts/fetch_app_apk.sh && echo "✅ fetch_app_apk.sh"
  test -f proxy/app-apk.version && echo "✅ app-apk.version"
  grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' proxy/app-apk.version && echo "✅ version format"
  ```

- [ ] **v1.4.0 — Release workflow fetches + stages APK**
  ```bash
  grep -q 'Fetch companion Android app APK' .github/workflows/release.yml && echo "✅ fetch step"
  grep -q 'Stage APK + .sha256 for module ZIP' .github/workflows/release.yml && echo "✅ stage step"
  grep -q 'dist/DNS-Proxy-v\*.apk' .github/workflows/release.yml && echo "✅ APK attached"
  ```

- [ ] **v1.4.0 — CI verifies companion app metadata**
  ```bash
  grep -q 'Verify companion app metadata' .github/workflows/ci.yml && echo "✅ CI step"
  grep -q 'app-apk.version' .github/workflows/ci.yml && echo "✅ version file checked"
  ```

- [ ] **v1.4.0 — iOS PWA logic removed**
  ```bash
  ! grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' web/index.html \
    && echo "✅ isIOSDevice removed"
  ! grep -q 'pwaStepIos' web/index.html && echo "✅ iOS step translations removed"
  ```

### 🆕 v1.5.0 additions — Companion install flow + Layered Bootstrap (2-layer baseline)

#### Companion install flow

- [ ] **v1.5.0 — install_app.sh present with 5 cascade levels**
  ```bash
  test -f install_app.sh && echo "✅ present"
  wc -l install_app.sh  # expected ~680 lines
  for pattern in 'pm install -r --user 0' 'pm install -r --user 0 -i com.android.shell' \
                 'pm install-create' 'magisk su' 'cmd package install'; do
      grep -q "$pattern" install_app.sh && echo "✅ $pattern" || echo "❌ $pattern"
  done
  ```

- [ ] **v1.5.0 — Three-way trap split with `_CLEANED_UP` guard**
  ```bash
  grep -q "trap '_cleanup_app' EXIT" install_app.sh && echo "✅ EXIT trap"
  grep -q "trap '_cleanup_app; exit 130' INT" install_app.sh && echo "✅ INT trap (exit 130)"
  grep -q "trap '_cleanup_app; exit 143' TERM" install_app.sh && echo "✅ TERM trap (exit 143)"
  grep -q '_CLEANED_UP=1' install_app.sh && echo "✅ re-entry guard"
  ```

- [ ] **v1.5.0 — Cascade deadline 75 s < INSTALL_TIMEOUT 90 s**
  ```bash
  grep -q 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && echo "✅ 75 s deadline"
  grep -q 'INSTALL_TIMEOUT.*90' proxy/main.go && echo "✅ 90 s handler timeout"
  ```

- [ ] **v1.5.0 — SELinux staging (never `setenforce 0`)**
  ```bash
  grep -q '/data/local/tmp/dnscrypt-companion.apk' install_app.sh && echo "✅ staging path"
  ! grep -v '^[[:space:]]*#' install_app.sh | grep -q 'setenforce 0' && echo "✅ SELinux never disabled"
  ```

- [ ] **v1.5.0 — Play Protect trap restores captured value**
  ```bash
  grep -q 'package_verifier_enable' install_app.sh && echo "✅ Play Protect disable"
  grep -q '_VERIFIER_ORIG' install_app.sh && echo "✅ restores captured value"
  ```

- [ ] **v1.5.0 — 4 endpoints registered in main.go**
  ```bash
  grep -q 'install_companion_app' proxy/main.go && echo "✅ /api/install_companion_app"
  grep -q 'uninstall_companion_app' proxy/main.go && echo "✅ /api/uninstall_companion_app"
  grep -q 'install_token' proxy/main.go && echo "✅ /api?action=install_token"
  grep -q 'companion_app_state' proxy/main.go && echo "✅ /api?action=companion_app_state"
  ```

- [ ] **v1.5.0 — One-shot CSRF token (60 s TTL, constant-time)**
  ```bash
  grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s TTL"
  grep -q 'installTokens' proxy/main.go && echo "✅ token store"
  grep -q 'validateAndConsumeInstallToken' proxy/main.go && echo "✅ one-shot consume"
  grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
  ```

- [ ] **v1.5.0 — Per-IP rate limit (5 / 15 min)**
  ```bash
  grep -q 'MAX_INSTALL_ATTEMPTS.*5' proxy/main.go && echo "✅ 5 attempts"
  grep -q 'INSTALL_LOCKOUT_PERIOD' proxy/main.go && echo "✅ lockout period"
  grep -q 'isInstallLockedOut' proxy/main.go && echo "✅ enforcement"
  ```

- [ ] **v1.5.0 — Localhost gate covers all three install surfaces**
  ```bash
  grep -q 'isLocalRequest' proxy/main.go && echo "✅ localhost gate applied"
  ```

- [ ] **v1.5.0 — HTTP_WRITE_TIMEOUT = 150 s > INSTALL_TIMEOUT = 90 s**
  ```bash
  grep -q 'HTTP_WRITE_TIMEOUT.*150' proxy/main.go && echo "✅ 150 s"
  ```

- [ ] **v1.5.0 — install_app.sh and boot-mini.sh extracted by customize.sh**
  ```bash
  grep -q "'install_app.sh'" customize.sh && echo "✅ install_app.sh in unzip list"
  grep -q "'boot-mini.sh'" customize.sh && echo "✅ boot-mini.sh in unzip list"
  grep -q 'MISSING.*install_app.sh' customize.sh && echo "✅ install_app.sh critical check"
  grep -q 'MISSING.*boot-mini.sh' customize.sh && echo "✅ boot-mini.sh critical check"
  ```

- [ ] **v1.5.0 — package_module.sh bundles both new scripts**
  ```bash
  grep -q 'install_app.sh' scripts/package_module.sh && echo "✅ install_app.sh in package"
  grep -q 'boot-mini.sh' scripts/package_module.sh && echo "✅ boot-mini.sh in package"
  ```

#### ADR compliance

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

#### Frontend state fixes (IDX-*)

- [ ] **IDX-23 — Companion button state survives language toggles**
  ```bash
  grep -q 'renderAllDynamic' web/index.html && echo "✅ renderAllDynamic present"
  grep -q 'renderCompanionButton' web/index.html && echo "✅ renderCompanionButton present"
  ```

- [ ] **IDX-24 — Install-method modal present**
  ```bash
  grep -q 'showInstallModal' web/index.html && echo "✅ showInstallModal present"
  grep -q '_resetModalLayout' web/index.html && echo "✅ _resetModalLayout present"
  grep -q 'handleCompanionInstall' web/index.html && echo "✅ handleCompanionInstall present"
  ```

- [ ] **IDX-25 — Dashboard section-nav uses real card IDs**
  ```bash
  grep -q 'runtimeInfoCard' web/dashboard.html && echo "✅ runtimeInfoCard"
  grep -q 'diagFilesCard' web/dashboard.html && echo "✅ diagFilesCard"
  ```

- [ ] **IDX-429 — Install rate-limit message rendered distinctly**
  ```bash
  grep -q "isInstallFamilyUrl" web/index.html && echo "✅ isInstallFamilyUrl present"
  grep -q "installRateLimited" web/index.html && echo "✅ installRateLimited string"
  ```

- [ ] **IDX-401-DISTINCT — Install-family 401 suppresses session modal**
  ```bash
  awk '/function isInstallFamilyUrl/,/^}/' web/index.html | grep -q 'install_companion_app' && echo "✅ detects install-family URLs"
  ```

- [ ] **DASH-REFRESH-01 / DASH-SESSION-RETRY-01 / DASH-HINT-01/02**
  ```bash
  grep -q 'isRefreshing = false' web/dashboard.html && echo "✅ isRefreshing reset"
  grep -q 'sessionExpiredTitle' web/dashboard.html && echo "✅ session-expired retry"
  grep -q 'cardHintRemoveTimer' web/dashboard.html && echo "✅ dual-timer lifecycle"
  grep -q "'onscrollend' in window" web/dashboard.html && echo "✅ window scrollend detection"
  ```

- [ ] **ICON-512-SAFEZONE-01 — Shield fits W3C 80% safe circle**
  ```bash
  grep -q 'M 256 60' web/icon-512.svg && echo "✅ top vertex"
  grep -q 'M 416 142' web/icon-512.svg && echo "✅ right shoulder"
  ```

- [ ] **Version consistency across 9 places**
  ```bash
  V=$(cat VERSION)
  echo "VERSION:        $V"
  grep -q "^version=$V" module.prop && echo "✅ module.prop"
  grep -q "\"version\": *\"$V\"" update.json && echo "✅ update.json"
  grep -q "\"version\": *\"${V#v}\"" web/manifest.json && echo "✅ manifest.json (no v)"
  grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
  grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
  grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"
  test -f proxy/app-apk.version && echo "✅ app-apk.version present"
  grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ go.mod pin (ADR-0002)"
  ```

### 🆕 v1.6.0 additions — Modular shell + Timezone + mtime sort

<!--
  v1.6.0 introduced:
    • lib/*.sh — Layer 0 (6 single-purpose modules)
    • 3-layer Layered Bootstrap (lib/*.sh → boot-mini.sh → functions.sh)
    • last_update_unix — timezone-agnostic backend field
    • formatUnixTimestamp() — frontend local-timezone rendering
    • buildBackupInfo mtime sort — aligns main.go with rotate_backups
    • CACHE_VERSION bump — forces PWA client cache refresh
  Verify these if the PR touches any of the corresponding subsystems.
-->

#### Modular shell (`lib/`) — 3-layer model

- [ ] **v1.6.0 — All 6 `lib/*.sh` modules present**
  ```bash
  for M in constants fallbacks process http backup firewall; do
      test -f lib/$M.sh && echo "✅ lib/$M.sh" || echo "❌ lib/$M.sh"
  done
  ```

- [ ] **v1.6.0 — `boot-mini.sh` sources all `lib/*.sh` modules**
  ```bash
  for M in constants fallbacks process http backup firewall; do
      grep -qE "$M\.sh|_LIB_BASE" boot-mini.sh && echo "✅ boot-mini sources $M" || echo "❌ missing $M"
  done
  ```

- [ ] **v1.6.0 — `functions.sh` sources `boot-mini.sh` and does not redefine Layer-0 primitives**
  ```bash
  grep -q 'boot-mini.sh' functions.sh && echo "✅ Layer 2 → Layer 1"
  for fn in get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}[[:space:]]*\(\)" functions.sh && \
        echo "❌ functions.sh redefines $fn" || \
        echo "✅ $fn lives only in Layer 0/1"
  done
  ```

- [ ] **v1.6.0 — `_MONITORING_UI_PORT` canonical source of truth**
  ```bash
  grep -qE '^_MONITORING_UI_PORT="8080"' lib/constants.sh && echo "✅ canonical in lib/constants.sh"
  grep -qE '^_MONITORING_UI_PORT="\$\{_MONITORING_UI_PORT:-' boot-mini.sh && echo "✅ fallback in boot-mini.sh §[4]"
  ! grep -qE '^_MONITORING_UI_PORT=' functions.sh && echo "✅ not redefined in functions.sh"
  ! grep -q '_MONITORING_UI_PORT=' customize.sh && echo "✅ not in customize.sh"
  ```

- [ ] **v1.6.0 — CI Step 9 verifies `lib/*.sh` and Layer chain**
  ```bash
  grep -q 'boot-mini.sh' .github/workflows/ci.yml && echo "✅ CI Step 9 present"
  grep -q 'lib/constants.sh\|lib/\*.sh' .github/workflows/ci.yml && echo "✅ CI checks lib/"
  ```

- [ ] **v1.6.0 — `customize.sh §[16]` verifies all 6 `lib/*.sh` files**
  ```bash
  grep -q 'lib/constants.sh lib/fallbacks.sh' customize.sh && echo "✅ lib/*.sh in critical check"
  ```

- [ ] **v1.6.0 — `customize.sh` credential rewrite is section-aware**
  ```bash
  # Should use awk section tracking, not sed
  grep -q 'monitoring_ui' customize.sh && echo "✅ monitoring_ui reference present"
  ! grep -qE 'sed -i "s\|^\[\[:space:\]\]\*username.*=.*' customize.sh && echo "✅ no blind sed rewrite"
  ```

- [ ] **v1.6.0 — `customize.sh` version arithmetic is prerelease-safe**
  ```bash
  grep -q "tr -dc '0-9'" customize.sh && echo "✅ non-numeric stripped"
  ! grep -q 'cut -d. -f3)$' customize.sh && echo "✅ no raw -beta arithmetic"
  ```

#### Timezone rendering (`last_update_unix` + `formatUnixTimestamp`)

- [ ] **v1.6.0 — Backend emits `last_update_unix`**
  ```bash
  awk '/func buildProfileResponse/,/^}/' proxy/main.go | grep -q 'last_update_unix' && echo "✅ backend field"
  grep -q 'lastUpdateUnixCache' proxy/main.go && echo "✅ cache field"
  ```

- [ ] **v1.6.0 — Frontend uses `formatUnixTimestamp()`**
  ```bash
  grep -q 'formatUnixTimestamp' web/index.html && echo "✅ helper present"
  awk '/function renderProfileData/,/^}/' web/index.html | grep -q 'last_update_unix' && echo "✅ prefers Unix field"
  awk '/function renderProfileData/,/^}/' web/index.html | grep -q 'last_update' && echo "✅ falls back to RFC3339"
  ```

- [ ] **v1.6.0 — `toLocaleString` uses `currentLang` for locale**
  ```bash
  grep -q "currentLang === 'ar' ? 'ar-EG' : 'en-US'" web/index.html && echo "✅ locale argument"
  ! grep -q "toLocaleString('en-US'" web/index.html && echo "✅ no hardcoded locale"
  ```

#### `buildBackupInfo` mtime sort

- [ ] **v1.6.0 — `buildBackupInfo` sorts by `ModTime()`, not name**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'Info()' && echo "✅ Info() called"
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime().Before' && echo "✅ ModTime sort"
  ```

- [ ] **v1.6.0 — `buildBackupInfo` agrees with `rotate_backups` and `status.sh`**
  ```bash
  # Manually compare after running:
  #   curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.backups.last_backup_name'
  #   su -c "sh status.sh --json" | jq -r '.backups.last_backup_name'
  # Both should be identical
  ```

#### PWA cache bump

- [ ] **v1.6.0 — `CACHE_VERSION` matches module version**
  ```bash
  V=$(cat VERSION)
  grep -q "const CACHE_VERSION = '$V'" web/sw.js && echo "✅ CACHE_VERSION=$V"
  ```

- [ ] **v1.6.0 — `PRECACHE_ASSETS` count unchanged (11 files)**
  ```bash
  # grep -c in the PRECACHE_ASSETS array
  grep -cE "^\s+'/.*',\s*$" web/sw.js
  # Expected: 11
  ```

#### ADR-0003 extended to 3-layer

- [ ] **v1.6.0 — ADR-0003 documents the 3-layer model**
  ```bash
  grep -q 'Extension (v1.6.0)' docs/adr/0003-layered-bootstrap.md && echo "✅ Extension section present"
  grep -q '3-layer\|three layers' docs/adr/0003-layered-bootstrap.md && echo "✅ 3-layer described"
  ```

- [ ] **v1.6.0 — ADR-0001 / ADR-0002 carry "Verified in" note**
  ```bash
  grep -q 'Verified in' docs/adr/0001-release-workflow.md && echo "✅ ADR-0001 verified"
  grep -q 'Verified in' docs/adr/0002-external-dependency.md && echo "✅ ADR-0002 verified"
  ```

---

### Custom tests (as applicable)

- [ ] Added new static verification steps (grep-based) for new security fixes
- [ ] Manually tested the change on a real device

### Manual test on a real device

- [ ] Tested on a real Android device or emulator
- [ ] **Android version**: <!-- e.g. Android 14 -->
- [ ] **Device**: <!-- e.g. Pixel 6 Pro -->
- [ ] **ROM**: <!-- e.g. LineageOS 21 -->
- [ ] **Root**: <!-- e.g. Magisk 27.0 / KernelSU 0.9.5 -->

### Change-specific tests

**WebUI:**
- [ ] Opened WebUI and confirmed no JS errors
- [ ] Tested in both Arabic and English (bilingual)
- [ ] Tested PWA install / reload
- [ ] Tested SSE live updates
- [ ] Tested dynamic links (custom PORT / DASHBOARD_PORT)
- [ ] Tested SW update-banner (`index.html` and `dashboard.html`)
- [ ] Verified live status LED turns green when DNS is ON and red when OFF
- [ ] Verified install button opens the install-method modal (not a direct `<a download>` link)
- [ ] Verified the modal offers 3 actions: local install + GitHub page + direct download
- [ ] **v1.6.0**: Verified "Last update:" matches device clock (not UTC) in both EN and AR

**Shell scripts:**
- [ ] Confirmed no new `shellcheck` warnings
- [ ] Tested on a real device (if possible)
- [ ] Ran `make check-backup`
- [ ] Verified the DNS auto-start-after-boot fix (log line `[v1.3.0 FIX]` in `dnscrypt_main.log`)
- [ ] If `functions.sh:rotate_backups` touched: verified SNAP-* / ROT-* semantics via `docs/REFERENCE.md` §4.6
- [ ] **v1.6.0**: If `lib/*.sh`, `boot-mini.sh`, or `functions.sh` touched: `make check-boot-mini` passes with all 6 modules + layer chain + no redefinition

**`install_app.sh` (v1.5.0):**
- [ ] Verified all 5 cascade levels present
- [ ] Verified three-way trap (EXIT / INT / TERM) with exit codes 130 / 143
- [ ] Verified 75-second cascade deadline is enforced
- [ ] Verified `setenforce 0` is never called
- [ ] Verified Play Protect trap restores `$_VERIFIER_ORIG`
- [ ] Tested CLI invocation: `su -c "sh install_app.sh"` — Ctrl+C returns 130, SIGTERM returns 143
- [ ] Verified `/data/local/tmp/dnscrypt-companion.apk` removed on every exit path

**Firewalls:**
- [ ] Checked `iptables -t nat -L DNSCRYPT_OUT -n`
- [ ] Checked `ip6tables -t nat -L DNSCRYPT_OUT6 -n`
- [ ] Confirmed `OUTPUT` has no orphans:
  ```bash
  su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
  # Expected: 0
  ```
- [ ] Tested `stopService` and `startService` cleanly

**STATUS_FILE semantics:**
- [ ] Confirmed `getStatusUncached` does not write `STATUS_FILE`
  ```bash
  awk '/func getStatusUncached/,/^}/' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ writes!" || echo "✅ read-only"
  ```
- [ ] Tested crash recovery:
  ```bash
  su -c "pkill -9 dnscrypt-proxy"
  sleep 60
  su -c "sh status.sh --json | jq .dns_engine.running"
  # Expected: true
  ```

**Authentication:**
- [ ] Tested login / logout / session expiry
- [ ] Tested rate limiting (5 attempts / 15 minutes)
- [ ] Tested from IPv4 and IPv6 (`[::1]`)
- [ ] Tested Login POST-only:
  ```bash
  curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
  # Expected: 405 Method Not Allowed + Allow: POST
  ```
- [ ] Tested Basic Auth rate limit:
  ```bash
  for i in 1 2 3 4 5 6; do
    curl -u "wrong:wrong" http://127.0.0.1:9090/api?action=status \
      -o /dev/null -w "%{http_code}\n"
  done
  # Expected: 401 × 5 then 401 (locked)
  ```
- [ ] Tested install token lifecycle: `GET /api?action=install_token` returns `{token, ttl: 60}`
- [ ] Verified token is one-shot: second use returns 401 `invalid_token`
- [ ] Verified install rate limit: 6 rapid attempts → 429 on the 6th

**`rebuildBlocklist` / `updateProfile` (RACE-1):**
- [ ] Confirmed `rebuildMu.Lock()` present + `defer rebuildMu.Unlock()`
- [ ] Tested concurrency manually (update + save simultaneously)
- [ ] Confirmed no deadlock (30 s timeout is enough)

**`buildRuntimeInfo` / `runtime_info` (PORT-2 + MEM-1 + BAK-1):**
- [ ] Confirmed `webui_port` + `dashboard_port` present in JSON
- [ ] Confirmed `memory_limit_mb` + `profile_key` present
- [ ] Confirmed `backups` object with 7 fields:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```
- [ ] Confirmed `backups.available` counts manifest-carrying directories only (SNAP-MANIFEST)
- [ ] Confirmed `backups.last_backup_name` follows mtime (SNAP-MTIME)
- [ ] Confirmed `index.html` uses `data.dashboard_port`
- [ ] Confirmed `dashboard.html` uses `data.webui_port`

**`/api/metrics` / `parsePrometheus` (Fix #1 + MEM-3):**
- [ ] Confirmed Content-Type:
  ```bash
  curl -s -I "http://127.0.0.1:9091/api/metrics" | grep Content-Type
  # Expected: application/json; charset=utf-8
  ```
- [ ] Confirmed JSON structure:
  ```bash
  curl -s "http://127.0.0.1:9091/api/metrics" | jq
  # Expected: {total_queries, blocked_queries, cache_stats, ...}
  ```
- [ ] Tested Dashboard in browser (no "Cannot fetch data")

**Memory limit (MEM-1):**
- [ ] Confirmed the limit adjusts when profile changes:
  ```bash
  echo "light" > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  sleep 5
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
  # Expected: 80
  ```

**Backup layer (v1.2.0 — 10 defensive layers):**
- [ ] Ran the backup flow end-to-end:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'"
  # Expected: >= 1
  ```
- [ ] Verified the persistent backup directory survives uninstall
- [ ] Verified `status.sh --diagnose` produces a complete report
- [ ] Verified the watchdog token file exists with mode `0600`

**Recovery mode (v1.2.0 — Layer 7):**
- [ ] Tested recovery trigger on a test device
- [ ] Confirmed the trigger file is consumed after a successful restore
- [ ] Verified the FIX-1 snapshot-and-reapply flow (`§[8]` + `§[12]` + `§[13]`)

**DNS auto-start-after-boot (v1.3.0):**
- [ ] Verified the fix on a test device:
  ```bash
  su -c "echo 'ON' > /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
  su -c "reboot"
  sleep 30
  su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log | tail -5"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
  # Expected: DNS=UP
  ```

**Rotation semantics (v1.3.0 — SNAP-* / ROT-*):**
- [ ] Verified SNAP-MANIFEST (manifest-less dir excluded)
- [ ] Verified ROT-PROTECT (`.last_stable` preserved)
- [ ] Verified parallel application (all consumers agree)
- [ ] Cross-referenced `docs/REFERENCE.md` §4.6 for the authoritative semantics

**Companion APK integration (v1.4.0):**
- [ ] Verified the APK is fetched and bundled
- [ ] Verified the route serves the APK
- [ ] Verified the route returns 404 when the APK is absent

**Companion Install Flow (v1.5.0):**
- [ ] Verified the full install flow on a test device:
  ```bash
  TOKEN=$(curl -s -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api?action=install_token" | jq -r '.token')
  curl -s -b /tmp/cookies.txt \
    -X POST http://127.0.0.1:9090/api/install_companion_app \
    -d "token=$TOKEN" | jq
  curl -s -b /tmp/cookies.txt \
    "http://127.0.0.1:9090/api?action=companion_app_state" | jq
  ```
- [ ] Verified `/data/local/tmp/dnscrypt-companion.apk` appears during the install and is removed afterwards
- [ ] Verified Play Protect verifier was restored
- [ ] Verified SELinux is still enforcing

**CodeQL hardening (v1.4.0):**
- [ ] Confirmed CodeQL analysis passes with no `go/path-injection` alerts
- [ ] Tested `POST /api/remove_module` with various inputs

**Timezone rendering (v1.6.0):**
- [ ] Backend returns both fields:
  ```bash
  curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
      jq '{last_update, last_update_unix}'
  # Expected: both present; last_update_unix is an integer
  ```
- [ ] Unix converts to device local time:
  ```bash
  curl -s -u "$CREDS" http://127.0.0.1:9090/api?action=get_profile | \
      jq -r '.last_update_unix' | xargs -I {} date -d @{}
  date
  # Both should match (same timezone)
  ```
- [ ] Tested across 2+ timezones (e.g., UTC, UTC+3, UTC-5, UTC+9)
- [ ] Tested with Arabic toggle enabled (verify `ar-EG` renders Arabic numerals correctly)

**Modular shell (v1.6.0):**
- [ ] All 6 `lib/*.sh` modules load on boot
- [ ] `boot-mini.sh` sources them in order
- [ ] `functions.sh` sources `boot-mini.sh` without redefining Layer-0 primitives
- [ ] `make check-boot-mini` passes
- [ ] `make check-consistency` passes

---

## 🔒 Security Checklist

### Basics

- [ ] No hardcoded secrets (passwords, tokens, keys)
- [ ] No `console.log` or `fmt.Println` with sensitive data
- [ ] Used `subtle.ConstantTimeCompare` for secret comparison (if applicable)
- [ ] Applied `MaxBytesReader` on new POST bodies (if applicable)
- [ ] Used `atomicWriteFile` / `atomicWriteStream` for writes (if applicable)

### Authentication and endpoints

- [ ] Verified `checkAuth(r)` on every new endpoint (if applicable)
- [ ] Used `hasEndpoint(path, name)` instead of `strings.Contains` / `strings.HasSuffix`
- [ ] Used `getClientIP(r)` to extract IP (not `strings.Split`)
- [ ] Made `/api/auth/login` and `/api/auth/logout` POST-only (if applicable)
- [ ] If a new rate limit was added, registered attempts in `loginAttempts`
- [ ] If adding an endpoint that needs watchdog auth, used `X-Watchdog-Token` + `verifyWatchdogToken()`
- [ ] If adding an install-family endpoint, applied the localhost gate (`isLocalRequest`) and the one-shot CSRF token (`validateAndConsumeInstallToken`)

### Input Validation

- [ ] If adding a port read, used `readConfPort` (range check 1–65535)
- [ ] If using a dynamic shell command, used `shellQuote()`
- [ ] If adding a new health endpoint, considered `isLocalRequest` (local-only)
- [ ] If routing a caller-provided path into any filesystem operation, used `filepath.Base()` + rebuilt from a trusted base (see `removeModule`)
- [ ] If running an install, verified `install_app.sh` uses a hardcoded APK path and `shellQuote()` on every argument

### Firewall

- [ ] Did not pollute `OUTPUT` / `INPUT` / `FORWARD` with dynamic rules
- [ ] Used `DNSCRYPT_OUT` / `DNSCRYPT_OUT6`
- [ ] Confirmed `--wait` on every `iptables` / `ip6tables` invocation
- [ ] Tested legacy cleanup after upgrade from an older version

### Concurrency (RACE-1 + BAK-2)

- [ ] Any operation modifying `ALLOWLIST` / `DENYLIST` / `BLOCKLIST` calls `rebuildBlocklist`
- [ ] `rebuildBlocklist` is protected by `rebuildMu.Lock()` + `defer Unlock()`
- [ ] No nested deadlock (never calls a function that locks the same mutex)
- [ ] Any new destructive operation on user data calls `createAutoBackup(reason)` first
- [ ] `backupMu` is used only via `createAutoBackup` — no second mutex
- [ ] `backupMu` is held for at most `AUTO_BACKUP_TIMEOUT = 15 s`
- [ ] Any change to `buildBackupInfo` (main.go) or `rotate_backups` (functions.sh) keeps the SNAP-* / ROT-* semantics in sync — see `docs/REFERENCE.md` §4.6
- [ ] If a new mutex is added for install-family state, documented its ordering relative to `installTokensMu`, `installAttemptsMu`, and `companionStateMutex`

### Memory (v1.1.0)

- [ ] If adding a new profile, updated `MEMORY_LIMIT_*` in `main.go`
- [ ] If adding a new profile, updated the inline fallback in all four shell scripts (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`)
- [ ] If adding a new profile, updated `webui.conf` template in `customize.sh`
- [ ] If adding a new profile, updated `web/index.html` `<select id="profileSelect">`

### Data Preservation (v1.2.0)

- [ ] If adding a new preserved file:
  - [ ] Updated the `USER_FILES` list in **all 5** scripts: `customize.sh`, `functions.sh`, `service.sh`, `status.sh`, `uninstall.sh`
  - [ ] Updated `README.md` "5 Preserved Files" table
  - [ ] Updated `docs/REFERENCE.md` §4.2
- [ ] If changing the rotation policy:
  - [ ] Updated the constant in **all 4** scripts: `customize.sh`, `functions.sh`, `service.sh`, `action.sh`
  - [ ] Updated `docs/REFERENCE.md` §4.6
  - [ ] Aligned with SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT
- [ ] If changing the `runtime_info.backups` schema:
  - [ ] Updated `buildBackupInfo()` in `proxy/main.go`
  - [ ] Kept `status.sh --json` in sync
  - [ ] Updated `docs/REFERENCE.md` §2.6.7
- [ ] If adding a config migration:
  - [ ] Added it to `migrate_config()` in `customize.sh`
  - [ ] Updated `docs/GUIDE.md` §5
- [ ] Confirmed the 10 defensive layers are still orthogonal to the firewall (see `docs/REFERENCE.md` §5.6.3)

### Companion Install Flow (v1.5.0)

- [ ] If changing `install_app.sh`:
  - [ ] Verified the 5-level cascade order is unchanged
  - [ ] Verified `CASCADE_DEADLINE_SECONDS = 75` remains < `INSTALL_TIMEOUT`
  - [ ] Verified the three-way trap (EXIT / INT / TERM) is intact
  - [ ] Verified `_CLEANED_UP` re-entry guard is present
  - [ ] Verified the trap removes `/data/local/tmp/dnscrypt-companion.apk`
  - [ ] Verified SELinux is still not disabled (`setenforce 0` absent)
  - [ ] Verified the Play Protect trap restores `$_VERIFIER_ORIG`
- [ ] If changing the 4 install endpoints:
  - [ ] Verified the localhost gate applies to all three surfaces
  - [ ] Verified the one-shot CSRF token has a 60 s TTL
  - [ ] Verified the per-IP rate limit is enforced (5 / 15 min)
  - [ ] Verified tokens are compared with `subtle.ConstantTimeCompare`
  - [ ] Verified `invalidateCompanionStateCache()` is called after every install/uninstall attempt (success or failure)
- [ ] If changing the install-method modal (IDX-24):
  - [ ] Verified the three actions remain: local install / open GitHub page / direct download
  - [ ] Verified all GitHub URLs point at `gasciljh/dnscrypt-proxy-app`
  - [ ] Verified `_resetModalLayout()` is idempotent

### Modular shell (v1.6.0)

- [ ] If adding a new `lib/*.sh` module:
  - [ ] Single responsibility per module
  - [ ] No cross-module dependency (except documented sourcing order)
  - [ ] `boot-mini.sh` sources it in the correct order
  - [ ] `ci.yml` Step 9 updated to verify presence
  - [ ] `customize.sh §[16]` critical-file check updated
  - [ ] `docs/REFERENCE.md` §1.4, §1.6, §1.8 updated
  - [ ] `docs/adr/0003-layered-bootstrap.md` §Extension updated
- [ ] If changing `boot-mini.sh`:
  - [ ] Remains an **aggregator only** — no business logic, no `case` chains
  - [ ] `_MONITORING_UI_PORT` fallback (§[4]) preserved
  - [ ] All 6 `lib/*.sh` modules still sourced
- [ ] If changing `functions.sh`:
  - [ ] Still sources `boot-mini.sh`
  - [ ] Does not redefine any Layer-0 primitive
  - [ ] No `_MONITORING_UI_PORT` assignment

### Timezone rendering (v1.6.0)

- [ ] If changing `buildProfileResponse` / `updateProfileBody`:
  - [ ] Both `last_update` (RFC3339) and `last_update_unix` (int64) still emitted
  - [ ] Both derived from the same `modTime`
  - [ ] `lastUpdateUnixCache` updated alongside `lastUpdateCache`
- [ ] If changing `index.html` / `dashboard.html`:
  - [ ] `formatUnixTimestamp()` used for any timestamp rendering
  - [ ] `toLocaleString()` locale follows `currentLang` (`ar-EG` / `en-US`)
  - [ ] Fallback to `last_update` string when Unix field absent

### For security fixes

- [ ] Updated `SECURITY.md` (Attack Vectors section + §5.X)
- [ ] Updated `docs/REFERENCE.md` (Trade-offs, §1.12)
- [ ] Updated `docs/GUIDE.md` (Diagnostics, §7)
- [ ] Added the Audit Correction #XX in the commit footer
- [ ] Added HTML anchor `<a name="XXX"></a>` (if a new section was created)
- [ ] Updated the Audit Corrections Registry in `SECURITY.md` §15

### Global Edition (EN + AR)

- [ ] Any new user-facing string in the WebUI is present in **both** `translations.en` and `translations.ar`
- [ ] The default language on first load is still **English**
- [ ] The language preference is stored only in `localStorage['dnscrypt-lang']` — never sent to the server
- [ ] RTL layout verified (Chrome 88+, Firefox 92+, Samsung Internet 16+)
- [ ] No API endpoint accepts or returns a language identifier

---

## 📖 Documentation

- [ ] Updated `CHANGELOG.md` (auto-generated at release, but note it if relevant)
- [ ] Updated `README.md` (if a new user-facing feature)
- [ ] Updated `docs/REFERENCE.md` §2 (if an API change)
- [ ] Updated `docs/REFERENCE.md` §1, §3 (if an architectural change)
- [ ] Updated `SECURITY.md` (if a security fix)
- [ ] Updated `docs/GUIDE.md` §7 (if a common issue)
- [ ] Updated `docs/GUIDE.md` §10 (if a common question)
- [ ] Updated `docs/CONTRIBUTING.md` §5 or §11 (if a workflow change)
- [ ] Added or updated an ADR in `docs/adr/` (if a non-trivial decision)
- [ ] If reversing an ADR, created a new one that supersedes it (never edit the old)
- [ ] If a new field was added to `runtime_info`, updated both `web/index.html` and `web/dashboard.html` translation tables (en + ar)
- [ ] If a backup-layer change, updated `docs/REFERENCE.md` §4 **and** `docs/GUIDE.md` §8
- [ ] If a language-toggle change, updated `docs/REFERENCE.md` §7.6
- [ ] If a DNS auto-start-after-boot change, updated `docs/REFERENCE.md` §3.3 and `docs/GUIDE.md` §7
- [ ] If a rotation-semantics change (SNAP-* / ROT-*), updated `docs/REFERENCE.md` §4.6 and `CHANGELOG.md` §[v1.3.0]
- [ ] If a companion APK change, updated `README.md` §Optional Android App and `docs/REFERENCE.md` §7.8
- [ ] If a `removeModule` change, updated `SECURITY.md` §5.34
- [ ] If an iOS PWA removal change, updated `CHANGELOG.md` §[v1.4.0] Removed section
- [ ] If a companion install flow change, updated `SECURITY.md` §5.36, `docs/REFERENCE.md` §3.13, and `docs/REFERENCE.md` §2.7.14–§2.7.15
- [ ] If a Layered Bootstrap change, updated `docs/REFERENCE.md` §1.4, `docs/adr/0003-layered-bootstrap.md`, and `CHANGELOG.md`
- [ ] If a `manifest.json` `x-note-*` change, updated `docs/REFERENCE.md` §7 and `CHANGELOG.md`
- [ ] **v1.6.0**: If a modular-shell change, updated `docs/REFERENCE.md` §1.4, §1.6, §1.8, and `docs/adr/0003-layered-bootstrap.md` §Extension
- [ ] **v1.6.0**: If a timezone change, updated `docs/REFERENCE.md` §2.6.2 and §3.10
- [ ] **v1.6.0**: If `buildBackupInfo` mtime sort changed, updated `docs/REFERENCE.md` §4.6.5
- [ ] **v1.6.0**: If a PWA precache change, bumped `CACHE_VERSION` in `web/sw.js` and updated `docs/REFERENCE.md` §7.6

---

## ✅ Final Checklist

### Branch policy

- [ ] PR target is `develop` (or `main` **only** for `release/*` / `hotfix/*`)
- [ ] If targeting `main`, using the **release template** (`?template=release.md`)
- [ ] No direct push was made to `main` or `develop`
- [ ] Read [`docs/CONTRIBUTING.md`](../docs/CONTRIBUTING.md) §5 if unsure

### General commitments

- [ ] Followed [Conventional Commits](https://www.conventionalcommits.org/) on every commit
- [ ] Commit messages are clear and useful (no "WIP" or "fix stuff")
- [ ] Reasonable number of commits
- [ ] No merge commits (`Merge branch 'main'`) — used `rebase` instead

### Code quality

- [ ] No dead code
- [ ] No unjustified `TODO` or `FIXME`
- [ ] No `fmt.Println` or `console.log` in production code
- [ ] Names are clear
- [ ] Comments on exported functions
- [ ] Every error is handled (`if err != nil`) correctly
- [ ] Used `defer unlock()` on every mutex

### Build verification

- [ ] `make build` passes
- [ ] `bash -n` clean on modified shell scripts
- [ ] No hardcoded `/system/bin/sh` (use `getSystemShell()`)
- [ ] No hardcoded `127.0.0.1` in HTML (use `window.location.hostname`)
- [ ] `make check-backup` passes (if backup layer touched)
- [ ] `make check-app-version` passes (if `proxy/app-apk.version` touched)
- [ ] `make check-install-app` passes (if `install_app.sh` touched)
- [ ] `make check-boot-mini` passes (if `lib/*.sh`, `boot-mini.sh`, or `functions.sh` touched)
- [ ] `make check-consistency` passes (no `proxy/*.sh` in docs; no `customize.sh §[2]` for `_MONITORING_UI_PORT`)

### Documentation

- [ ] Reviewed every item in the "📖 Documentation" section
- [ ] No broken links in the updated documentation
- [ ] Code examples in the documentation are correct (actually tested)

### Cleanliness

- [ ] Removed all temporary files (`*.tmp`, `*.bak`, `scratch.*`)
- [ ] No binary files uploaded without justification
- [ ] No `.DS_Store` or `Thumbs.db`
- [ ] Reviewed `git diff` before pushing
- [ ] Confirmed no leftover `*.tmp_*` from `atomicWriteFile`
- [ ] No leftover `txn-*` / `orphan-txn-*` in the committed backup directory
- [ ] No leftover `dist/DNS-Proxy-v*.apk` committed
- [ ] No leftover `web/app-debug.apk*` committed

---

## 🖼️ Screenshots / Recordings

<!--
  If the PR relates to the UI, attach images or GIFs.
  For bug fixes: before / after.
  For bilingual UI: BOTH English and Arabic screenshots.
  For companion APK/install modal: screenshot of the header button and the install-method modal (3 actions).
-->



---

## 📌 Additional Notes

<!--
  Anything else the reviewer needs to know:
  - Architectural decisions made
  - Trade-offs considered
  - Known limitations
  - Questions for the reviewer
-->



---

## 🎯 Reviewer Suggestion

<!--
  If you want a specific review, mention it here.

  • Data-preservation changes → Data Guardian badge holder (docs/CONTRIBUTING.md §14)
  • Rotation-semantics changes (SNAP-* / ROT-*) → contributor familiar with the v1.3.0 refinements
  • Companion APK integration → a maintainer of gasciljh/dnscrypt-proxy-app
  • Companion install flow → a contributor who verified SELinux staging + Play Protect on a real device
  • Modular shell (lib/) changes (v1.6.0) → a Modular Architect badge holder (docs/CONTRIBUTING.md §14.2)
  • Timezone rendering changes (v1.6.0) → a Timezone Validator badge holder
-->



---

<!-- ============================================================
     ⚠️ Final reminder:

     ┌─────────────────────────────────────────────────┐
     │  🎯 Branch policy reminder                              │
     ├─────────────────────────────────────────────────┤
     │  feature/*, fix/*, docs/*, chore/*, refactor/*, test/*  │
     │      → PR base: develop                                │
     │      → Template: this one (default)                    │
     │                                                         │
     │  release/*, hotfix/*                                    │
     │      → PR base: main                                   │
     │      → Template: ?template=release.md                  │
     │                                                         │
     │  Never open a PR directly against main for features.    │
     │  Read docs/CONTRIBUTING.md §5 for the full explanation. │
     └─────────────────────────────────────────────────┘

     🎯 Quick verification commands (before pushing):

       make build                          # Go build for all 4 architectures
       bash -n *.sh lib/*.sh scripts/*.sh  # shell syntax check
       gofmt -l proxy/                     # Go format check
       shellcheck --severity=warning *.sh lib/*.sh scripts/*.sh
       make check-backup                   # shell validation (all 16 scripts)
       make check-app-version              # companion APK version check
       make check-install-app              # install_app.sh validation
       make check-boot-mini                # Layer 0/1/2 validation (v1.6.0)
       make check-consistency              # docs path/version consistency (v1.6.0)
       make check-all                      # full local validation suite

     🎯 Quick subsystem checks (only if you touched that area):

       # v1.1.0 (main.go)
       grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
       awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2"
       awk '/func metricsProxyHandler/,/^}/' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

       # v1.2.0 (backup layer)
       grep -q 'CANDIDATE_SOURCES' customize.sh && echo "✅ Layer 1"
       grep -q 'begin_transaction' customize.sh && echo "✅ Layer 4"
       grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2"
       grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ WD-TOKEN"

       # v1.3.0 (boot/UI/rotation)
       grep -q 'v1.3.0 FIX' service.sh && echo "✅ DNS auto-start"
       grep -q 'led-on' web/index.html && echo "✅ LED markup"
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"

       # v1.4.0 (companion APK / CodeQL / iOS)
       grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE"
       grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ CodeQL"
       grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ SecureJoin"
       ! grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' web/index.html && echo "✅ iOS removed"

       # v1.5.0 (companion install flow)
       grep -q 'CASCADE_DEADLINE_SECONDS=75' install_app.sh && echo "✅ 75 s deadline"
       grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s token TTL"
       ! grep -v '^[[:space:]]*#' install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce"
       grep -q '_VERIFIER_ORIG' install_app.sh && echo "✅ verifier restore"

       # v1.6.0 (modular shell + timezone + mtime sort)
       for M in constants fallbacks process http backup firewall; do
           test -f lib/$M.sh && echo "✅ lib/$M.sh"
       done
       grep -q 'boot-mini.sh' functions.sh && echo "✅ Layer 2 → Layer 1"
       grep -qE '^_MONITORING_UI_PORT="8080"' lib/constants.sh && echo "✅ SSOT"
       awk '/func buildProfileResponse/,/^}/' proxy/main.go | grep -q 'last_update_unix' && echo "✅ backend timezone"
       grep -q 'formatUnixTimestamp' web/index.html && echo "✅ frontend timezone"
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime().Before' && echo "✅ mtime sort"
       V=$(cat VERSION); grep -q "const CACHE_VERSION = '$V'" web/sw.js && echo "✅ CACHE_VERSION=$V"

     📖 Documentation references:

       docs/CONTRIBUTING.md §5   - Branch strategy
       docs/CONTRIBUTING.md §7   - PR process
       docs/CONTRIBUTING.md §11  - Release process
       docs/adr/README.md        - Architecture Decision Records index
       docs/adr/0002-external-dependency.md - filepath-securejoin policy
       docs/adr/0003-layered-bootstrap.md   - Layered Bootstrap (3-layer, v1.6.0)
       SECURITY.md §5.31–§5.37   - Security-relevant changes per version
       SECURITY.md §15           - Audit Corrections Registry
       docs/REFERENCE.md §1.4    - Layered Bootstrap
       docs/REFERENCE.md §2.6.2  - get_profile response (timezone)
       docs/REFERENCE.md §2.6.7  - runtime_info (backups schema)
       docs/REFERENCE.md §3.10   - Timezone flow (v1.6.0)
       docs/REFERENCE.md §3.13   - Companion install flow (v1.5.0)
       docs/REFERENCE.md §4.6    - Rotation semantics (SNAP-* / ROT-*)
       docs/REFERENCE.md §5.2.4  - On-device SNAP-*/ROT-* verification
       docs/REFERENCE.md §7      - Manifest x-note fields
       docs/GUIDE.md §5          - Upgrade
       docs/GUIDE.md §7          - Troubleshooting
       docs/GUIDE.md §8          - Emergency recovery
       docs/GUIDE.md §9          - Companion app
       docs/MAP.md §1            - Documentation map (12 files)

     Current version: v1.6.0
     Last updated: 2026-11-12

     🎉 Thanks for your contribution! Every PR improves the project.
     ============================================================ -->