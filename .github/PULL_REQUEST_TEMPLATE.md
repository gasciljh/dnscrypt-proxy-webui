<!-- ============================================================
     DNSCrypt Smart Filter – Pull Request Template
     Version: v1.5.0 (Global Edition)
     Last updated: 2026-10-18
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template appears automatically when a new PR is opened
     against `develop`.

     For release/hotfix PRs targeting `main`, use the release
     template instead (see "Before You Start" below).

     Cross-references:
       • docs/CONTRIBUTING.md §5, §7, §11 — branch, PR, release
       • docs/REFERENCE.md §1, §3     — architecture, data flow
       • docs/REFERENCE.md §2         — HTTP API
       • docs/REFERENCE.md §5         — compatibility
       • SECURITY.md §5.31–§5.36      — security model
       • SECURITY.md §15              — audit corrections registry
       • docs/GUIDE.md §5, §7, §8     — upgrade, troubleshoot, recovery
       • docs/adr/0002-external-dependency.md
       • docs/adr/0003-layered-bootstrap.md
     ============================================================ -->

> ## 🚨 Before You Start
>
> **This is the DEFAULT template** — for features, fixes, docs, chores,
> refactors, and tests targeting `develop`.
>
> **If your PR is a RELEASE** (`release/*` → `main` or `hotfix/*` → `main`),
> please **use the release template instead**:
>
> ```text
> https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...<your-branch>?template=release.md
> ```
>
> **See:** [`docs/CONTRIBUTING.md`](../docs/CONTRIBUTING.md) §5 (Branch Strategy)
> and §11 (Release Process).

---

## 🎯 Target Branch

> ⚠️ **Read this first — it prevents your PR from being closed.**
>
> This project uses a **two-branch strategy** (`main` + `develop`).
> Choosing the wrong base branch will block your PR.

**Choose exactly one:**

- [ ] **Target: `develop`** — for `feature/*`, `fix/*`, `docs/*`, `chore/*`, `refactor/*`, `test/*`
  *(This is the correct choice for 99% of PRs.)*
- [ ] **Target: `main`** — **only** for `release/*` or `hotfix/*` branches
  *(If you check this, switch to the release template — see the callout above.)*

**Quick rule:**

| Your branch starts with… | Open the PR against… | Template |
|---|---|---|
| `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/` | `develop` | **This one** (default) |
| `release/`, `hotfix/` | `main` | **Release** (`?template=release.md`) |

📖 Full details: [`docs/CONTRIBUTING.md`](../docs/CONTRIBUTING.md) §5.

---

## 📝 Description

<!--
  Brief and clear description of what this PR does.
  Explain "what" and "why" — not just "how".

  Good example:
    "Fixes versionCode inconsistency between module.prop and update.json.
     Before: 1040000 (correct).
     After:  1040000 (unchanged — but doc comment now matches).
     Impact: Magisk Manager update detection stays correct."

  Bad example:
    "Fix bugs and various improvements" ← says nothing!
-->



---

## 🔗 Related Issue

<!--
  Reference the Issue this PR resolves.
  GitHub links it automatically and closes the Issue on merge.
  Examples:
    Closes #123
    Fixes #456
    Resolves #789
    Refs #101  ← (does not close, just a reference)
-->

Closes #

---

## 🏷️ Change Type

<!--
  Select applicable types. Choose at least one.
  Helps determine the next version number (SemVer).
  See docs/CONTRIBUTING.md §5 for which branch to use.
-->

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
- [ ] 📋 **ADR** — Architecture Decision Record (see §📖 Documentation)
- [ ] 💾 **Data preservation** — touches the 10 defensive layers (see §🔒)
- [ ] 🔄 **Rotation semantics (v1.3.0)** — touches SNAP-MANIFEST,
      SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, or ROT-PROTECT
- [ ] 📱 **Companion app (v1.4.0)** — touches `proxy/app-apk.version`,
      `scripts/fetch_app_apk.sh`, or the `/app-debug.apk` route
- [ ] 🆕 **Companion install flow (v1.5.0)** — touches
      `proxy/install_app.sh`, the 4 install endpoints, the install
      token store, or the install-method modal (IDX-24)
- [ ] 🧩 **Layered Bootstrap (v1.5.0)** — touches `proxy/boot-mini.sh`,
      `proxy/functions.sh`, or the Layer-0 primitive ownership

---

## 🔍 Audit Correction (for security/architecture fixes)

<!--
  Fill this section only if the PR fixes an architectural or security issue.
  See SECURITY.md and docs/REFERENCE.md.

  ┌─────────────────────────────────────────────────┐
  │  Audit Corrections Registry (v1.0.0)                    │
  ├─────────────────────────────────────────────────┤
  │  #13     CSRF-GET → POST-only                v1.0.0     │
  │  #14     pgrep -x (no false positives)       v1.0.0     │
  │  #15-a   Remove token from login response    v1.0.0     │
  │  #15-b   Allow: POST header for 405          v1.0.0     │
  │  #16-a/b IPv4/IPv6 firewall separation       v1.0.0     │
  │  #17     Custom Chains (Orphan Fix)          v1.0.0     │
  │  #18     STATUS_FILE Semantics               v1.0.0     │
  │  #19     IPv6 Rate Limit Bypass              v1.0.0     │
  │  #20     Port Collision 8080                 v1.0.0     │
  │  #21     Section-Restricted TOML             v1.0.0     │
  │  #22     Basic Auth Rate Limit               v1.0.0     │
  │  #23     Section header with comment         v1.0.0     │
  │  #24     Exact endpoint matching             v1.0.0     │
  │  #25     Dashboard JSON Conversion           v1.0.0     │
  │  #26     Preserve Settings on Upgrade        v1.0.0     │
  │  #27     fuser PID parsing                   v1.0.0     │
  │  #28     Login POST-only (CSRF)              v1.0.0     │
  │  #29     readConfPort range check            v1.0.0     │
  │  #30     /readyz localhost-only              v1.0.0     │
  │  #31     shellQuote injection protection     v1.0.0     │
  │  #32     rebuildMu mutex (RACE-1)            v1.0.0     │
  │  #33     runtime_info dynamic ports          v1.0.0     │
  └─────────────────────────────────────────────────┘

  ℹ️  This box shows corrections **#13–#33** (security-focused,
     v1.0.0). For the full registry (**#1–#33**, including the
     absorbed-range rows), see `SECURITY.md` §15.1.

  ⚠️ v1.1.0 through v1.5.0 do NOT add new audit corrections —
     they are runtime-improvement, data-preservation, feature,
     integration, and polish releases. See SECURITY.md §15.2
     for the per-version breakdown.

  The registry above remains the authoritative record through
  v1.0.0. If your PR fixes a new security/architecture issue,
  this PR should be the FIRST to add a new entry (starting at #34).

  Example:
    Number: #34
    Title: <fix title>
    Reference: SECURITY.md
-->

- **Audit Correction number**: #
- **Title**:
- **Documentation reference**: `SECURITY.md`

**Problem summary**:
<!-- Brief description: what was wrong? What was its impact? -->



**Solution summary**:
<!-- Brief description: how was it fixed? Why this approach? -->

---

## 🧪 Testing

### Mandatory checks

<!--
  All of these must pass before requesting review.
-->

- [ ] `make build` passed (Go build for all 4 architectures)
- [ ] `bash -n` clean on all modified shell scripts (`proxy/*.sh`, `scripts/*.sh`)
- [ ] `gofmt -l proxy/` is empty (no unformatted files)
- [ ] `shellcheck --severity=warning proxy/*.sh scripts/*.sh` is clean
- [ ] No hardcoded secrets (`detect-secrets` clean)
- [ ] **v1.2.0**: `make check-backup` passes (if `customize.sh` or
      `functions.sh` changed)
- [ ] **v1.4.0**: `make check-app-version` passes (if
      `proxy/app-apk.version` changed)
- [ ] **v1.5.0**: `make check-install-app` passes (if
      `proxy/install_app.sh` changed)
- [ ] **v1.5.0**: `make check-boot-mini` passes (if
      `proxy/boot-mini.sh` or `proxy/functions.sh` changed)

### 🆕 Core fix verifications (v1.0.0)

> ⚠️ The "Fix #N" labels below are **internal development reference
> numbers** — NOT Audit Correction IDs. Mapping to `SECURITY.md §15`:
>
> | Dev fix | Audit Correction |
> |---|---|
> | Fix #1 (Dashboard JSON) | #25 |
> | Fix #2 (Shell fallback) | *(pre-registry)* |
> | Fix #8 (Basic Auth rate limit) | #22 |
> | Fix #12 (Exact endpoint matching) | #24 |

<!--
  Run these if the PR touches main.go or web/*.html.
  Fast (< 5 seconds total) — grep-based.
-->

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

<!--
  Run these if the PR touches main.go, functions.sh, service.sh,
  action.sh, status.sh, or watchdog.sh. All are grep-based.

  v1.1.0 introduced three runtime features that must be verified
  by any PR that could affect them:
    • MEM-1 — dynamic memory limit per profile
    • MEM-2 — extended shellQuote character set
    • MEM-3 — MONITORING_UI_PORT constant used everywhere
-->

- [ ] **MEM-1 — Dynamic memory limit (main.go)**
  ```bash
  grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅"
  grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅"
  grep -q 'MEMORY_LIMIT_ULTIMATE' proxy/main.go && echo "✅"
  ! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded limit"
  ```

- [ ] **MEM-2 — Extended shellQuote (main.go)**
  ```bash
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "'{'" && echo "✅ braces"
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
  awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
  ```

- [ ] **MEM-3 — MONITORING_UI_PORT used in metrics handler (main.go)**
  ```bash
  grep -q 'MONITORING_UI_PORT = "8080"' proxy/main.go && echo "✅ const"
  awk '/func metricsProxyHandler/,/^}/' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ used"
  ! grep -q '"http://127.0.0.1:8080/api/metrics"' proxy/main.go && echo "✅ no hardcoded URL"
  ```

- [ ] **v1.1.0 — runtime_info new fields (main.go + web/*.html)**
  ```bash
  awk '/func buildRuntimeInfo/,/^}/' proxy/main.go | grep -q '"memory_limit_mb"' && echo "✅ backend memory_limit_mb"
  awk '/func buildRuntimeInfo/,/^}/' proxy/main.go | grep -q '"profile_key"' && echo "✅ backend profile_key"
  grep -q "riMemoryLimit" web/index.html && echo "✅ index.html"
  grep -q "riMemoryLimit" web/dashboard.html && echo "✅ dashboard.html"
  ```

### 🆕 v1.2.0 additions — Data Preservation

<!--
  Run these if the PR touches customize.sh, functions.sh,
  service.sh, status.sh, uninstall.sh, action.sh, watchdog.sh,
  main.go (backup helpers only), docs/REFERENCE.md §4, or
  docs/GUIDE.md §8.

  ⚠️ v1.3.0 note: rotation logic in functions.sh:rotate_backups
     was rewritten in v1.3.0 with SNAP-* / ROT-* semantics. The
     v1.2.0 greps below still pass — they check for FUNCTION
     PRESENCE, not semantics — but any PR touching rotation
     must ALSO run the v1.3.0 greps in the next section.
-->

- [ ] **v1.2.0 — 10 defensive layers present in customize.sh**
  ```bash
  for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
           begin_transaction detect_root_solution copy_with_context \
           RECOVERY_TRIGGER migrate_config; do
      grep -q "$L" proxy/customize.sh && echo "✅ $L" || echo "❌ $L"
  done
  ```

- [ ] **v1.2.0 — Backup helpers present in functions.sh**
  ```bash
  for H in auto_backup_if_needed rotate_backups backup_user_files \
           restore_user_files cleanup_old_transactions get_backup_dir \
           ensure_backup_dir get_last_backup_time copy_with_context \
           verify_backup_integrity write_manifest get_watchdog_token; do
      grep -q "$H" proxy/functions.sh && echo "✅ $H" || echo "❌ $H"
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

- [ ] **v1.2.0 — 7-field backups schema (BAK-1)**
  ```bash
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ in_flight_txn"
  awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'orphan_txn' && echo "✅ orphan_txn"
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```

- [ ] **v1.2.0 — Watchdog token (WD-TOKEN)**
  ```bash
  grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ token loader"
  grep -q 'verifyWatchdogToken' proxy/main.go && echo "✅ verify"
  grep -q 'X-Watchdog-Token' proxy/main.go && echo "✅ header name"
  grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
  grep -q 'watchdog_token' proxy/watchdog.sh && echo "✅ watchdog reads"
  grep -q 'X-Watchdog-Token' proxy/watchdog.sh && echo "✅ watchdog sends"
  ```

- [ ] **v1.2.0 — FIX-1 (recovery-mode snapshot-and-reapply)**
  ```bash
  grep -q 'RECOVERY_SNAPSHOT_DIR' proxy/customize.sh && echo "✅ snapshot dir"
  grep -q 'Re-applying recovery snapshot' proxy/customize.sh && echo "✅ §[9b2] re-apply block"
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

- [ ] **v1.2.0 — Data-preservation test artifacts (`.gitignore` §[19])**
  ```bash
  grep -qE 'txn-\*/|orphan-txn-\*/|manifest\.json\.tmp' .gitignore && \
    echo "✅ backup test patterns present"
  ```

### 🆕 v1.3.0 additions — PWA install button + LED + DNS auto-start + rotation

<!--
  Run these if the PR touches:
    • web/index.html (PWA install button / LED markup)
    • proxy/service.sh (§[19] DNS auto-start block)
    • web/dashboard.html, web/offline.html
    • proxy/main.go (buildBackupInfo)
    • proxy/functions.sh (rotate_backups)
    • proxy/status.sh (_list_snapshots)
    • proxy/watchdog.sh (§[5b] snapshot counter)
    • proxy/customize.sh (rotate_backups)
    • proxy/action.sh (_inline_rotate_backups + _inline_backup_summary)
    • proxy/uninstall.sh (§[5b] BACKUP_COUNT / BACKUP_LAST_NAME)
    • docs/REFERENCE.md §4.6, docs/REFERENCE.md §3.2
-->

- [ ] **v1.3.0 — DNS auto-start-after-boot fix (service.sh)**
  ```bash
  grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ §[19] block present"
  grep -q 'ensure_running_service' proxy/service.sh && echo "✅ API call present"
  grep -q 'X-Watchdog-Token' proxy/service.sh && echo "✅ uses token"
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
  awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
  awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
  awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"
  ```

- [ ] **v1.3.0 — Parallel application in shell scripts**
  ```bash
  grep -q '_list_snapshots' proxy/status.sh && echo "✅ status.sh helper"
  grep -q 'manifest.json' proxy/watchdog.sh && echo "✅ watchdog.sh manifest check"
  grep -q 'manifest.json' proxy/customize.sh && echo "✅ customize.sh manifest check"
  grep -q '_inline_list_snapshots' proxy/action.sh && echo "✅ action.sh helper"
  grep -q '_uninstall_list_snapshots' proxy/uninstall.sh && echo "✅ uninstall.sh helper"
  ```

### 🆕 v1.4.0 additions — Companion APK + CodeQL + iOS removal

<!--
  Run these if the PR touches:
    • proxy/main.go (removeModule, serveStaticAssets, APK_FILE)
    • web/index.html (install button markup — v1.4.0 state)
    • scripts/fetch_app_apk.sh, proxy/app-apk.version
    • .github/workflows/release.yml (Fetch/Stage APK steps)
    • .github/workflows/ci.yml (Verify companion app metadata)

  ⚠️ v1.5.0 note: the v1.4.0 install button was a plain
     `<a download href="/app-debug.apk">` link. In v1.5.0 it was
     replaced by `handleCompanionInstall()` (IDX-24). The checks
     below describe the v1.4.0 state; for a v1.5.0-aware PR, use
     the v1.5.0 block instead.
-->

- [ ] **v1.4.0 — Companion APK route + constant (main.go)**
  ```bash
  grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
  grep -q '/app-debug.apk' proxy/main.go && echo "✅ route registered"
  grep -q 'application/vnd.android.package-archive' proxy/main.go && echo "✅ mime type"
  ```

- [ ] **v1.4.0 — CodeQL path-injection fix in removeModule (main.go)**
  ```bash
  grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ filepath.Base sanitization"
  grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ path rebuilt via SecureJoin (ADR-0002)"
  awk '/func removeModule/,/^}/' proxy/main.go | grep -q 'expectedPrefix' && echo "✅ prefix guard present"
  ```

- [ ] **v1.4.0 — Companion APK fetcher + version file**
  ```bash
  test -f scripts/fetch_app_apk.sh && echo "✅ fetch_app_apk.sh present"
  test -f proxy/app-apk.version && echo "✅ app-apk.version present"
  grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' proxy/app-apk.version && echo "✅ version format valid"
  ```

- [ ] **v1.4.0 — Release workflow fetches + stages APK**
  ```bash
  grep -q 'Fetch companion Android app APK' .github/workflows/release.yml && echo "✅ fetch step"
  grep -q 'Stage APK + .sha256 for module ZIP' .github/workflows/release.yml && echo "✅ stage step"
  grep -q 'dist/DNS-Proxy-v\*.apk' .github/workflows/release.yml && echo "✅ APK attached to release"
  ```

- [ ] **v1.4.0 — CI verifies companion app metadata**
  ```bash
  grep -q 'Verify companion app metadata' .github/workflows/ci.yml && echo "✅ CI step present"
  grep -q 'app-apk.version' .github/workflows/ci.yml && echo "✅ version file checked"
  ```

- [ ] **v1.4.0 — iOS PWA logic removed (web/index.html)**
  ```bash
  ! grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' web/index.html \
    && echo "✅ isIOSDevice removed"
  ! grep -q 'pwaStepIos' web/index.html && echo "✅ iOS step translations removed"
  ```

### 🆕 v1.5.0 additions — Companion install flow + Layered Bootstrap

<!--
  Run these if the PR touches:
    • proxy/install_app.sh (any change)
    • proxy/main.go (4 install endpoints + 10 helpers)
    • proxy/boot-mini.sh, proxy/functions.sh (Layer 0 / Layer 1)
    • web/index.html (install-method modal — IDX-24)
    • .github/workflows/ci.yml (Step 8 + Step 9)
    • .github/workflows/release.yml (Stage .sha256)
    • proxy/customize.sh (§[10c] APK mirror)
    • scripts/package_module.sh (install_app.sh bundling)
    • SECURITY.md §5.36, docs/REFERENCE.md §3.12, docs/REFERENCE.md §1.4
-->

#### Companion install flow

- [ ] **v1.5.0 — install_app.sh present with 5 cascade levels**
  ```bash
  test -f proxy/install_app.sh && echo "✅ present"
  wc -l proxy/install_app.sh  # expected ~1,101 lines
  for pattern in 'pm install -r --user 0' 'pm install -r --user 0 -i com.android.shell' \
                 'pm install-create' 'magisk su' 'cmd package install'; do
      grep -q "$pattern" proxy/install_app.sh && echo "✅ $pattern" || echo "❌ $pattern"
  done
  ```

- [ ] **v1.5.0 — Three-way trap split (EXIT / INT / TERM) with `_CLEANED_UP` guard**
  ```bash
  grep -q "trap '_cleanup_app' EXIT" proxy/install_app.sh && echo "✅ EXIT trap"
  grep -q "trap '_cleanup_app; exit 130' INT" proxy/install_app.sh && echo "✅ INT trap (exit 130)"
  grep -q "trap '_cleanup_app; exit 143' TERM" proxy/install_app.sh && echo "✅ TERM trap (exit 143)"
  grep -q '_CLEANED_UP=1' proxy/install_app.sh && echo "✅ re-entry guard"
  ```

- [ ] **v1.5.0 — Cascade deadline 75 s < INSTALL_TIMEOUT 90 s**
  ```bash
  grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75 s deadline"
  grep -q 'INSTALL_TIMEOUT.*90' proxy/main.go && echo "✅ 90 s handler timeout"
  ```

- [ ] **v1.5.0 — SELinux staging (never `setenforce 0`)**
  ```bash
  grep -q '/data/local/tmp/dnscrypt-companion.apk' proxy/install_app.sh && echo "✅ staging path"
  ! grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' && echo "✅ SELinux never disabled"
  ```

- [ ] **v1.5.0 — Play Protect trap restores captured value**
  ```bash
  grep -q 'package_verifier_enable' proxy/install_app.sh && echo "✅ Play Protect disable"
  grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ restores captured value"
  ```

- [ ] **v1.5.0 — 4 endpoints registered in main.go**
  ```bash
  grep -q 'install_companion_app' proxy/main.go && echo "✅ /api/install_companion_app"
  grep -q 'uninstall_companion_app' proxy/main.go && echo "✅ /api/uninstall_companion_app"
  grep -q 'install_token' proxy/main.go && echo "✅ /api?action=install_token"
  grep -q 'companion_app_state' proxy/main.go && echo "✅ /api?action=companion_app_state"
  ```

- [ ] **v1.5.0 — One-shot CSRF token (60 s TTL, constant-time compare)**
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
  grep -q "'install_app.sh'" proxy/customize.sh && echo "✅ install_app.sh in unzip list"
  grep -q "'boot-mini.sh'" proxy/customize.sh && echo "✅ boot-mini.sh in unzip list"
  grep -q 'MISSING.*install_app.sh' proxy/customize.sh && echo "✅ install_app.sh critical check"
  grep -q 'MISSING.*boot-mini.sh' proxy/customize.sh && echo "✅ boot-mini.sh critical check"
  ```

- [ ] **v1.5.0 — package_module.sh bundles both new scripts**
  ```bash
  grep -q 'install_app.sh' scripts/package_module.sh && echo "✅ install_app.sh in package"
  grep -q 'boot-mini.sh' scripts/package_module.sh && echo "✅ boot-mini.sh in package"
  ```

#### Layered Bootstrap (Phase 0)

- [ ] **v1.5.0 — boot-mini.sh present with 5 primitives + constant**
  ```bash
  test -s proxy/boot-mini.sh && echo "✅ present"
  for fn in log_msg get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}\(\)" proxy/boot-mini.sh && echo "✅ primitive: $fn" || echo "❌ missing: $fn"
  done
  grep -q '^_MONITORING_UI_PORT=' proxy/boot-mini.sh && echo "✅ _MONITORING_UI_PORT"
  ```

- [ ] **v1.5.0 — functions.sh sources Layer 0**
  ```bash
  grep -q 'boot-mini.sh' proxy/functions.sh && echo "✅ sources boot-mini.sh"
  ```

- [ ] **v1.5.0 — functions.sh does NOT redefine Layer-0 primitives**
  ```bash
  for fn in get_run_dir read_conf is_port_open get_webui_port; do
      grep -qE "^${fn}[[:space:]]*\(\)" proxy/functions.sh && echo "❌ redefines: $fn" || echo "✅ $fn not redefined"
  done
  ! grep -qE '^_MONITORING_UI_PORT=' proxy/functions.sh && echo "✅ _MONITORING_UI_PORT not redefined"
  ```

- [ ] **v1.5.0 — CI guard Step 9 active**
  ```bash
  grep -q 'Verify boot-mini.sh integration' .github/workflows/ci.yml && echo "✅ Step 9 present"
  ```

#### ADR compliance

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

#### Frontend state fixes (IDX-*)

- [ ] **IDX-23 — Companion button state survives language toggles**
  ```bash
  grep -q 'renderAllDynamic' web/index.html && echo "✅ renderAllDynamic present"
  grep -q 'renderCompanionButton' web/index.html && echo "✅ renderCompanionButton present"
  ```

- [ ] **IDX-23b — Status card updates instantly on language toggle**
  ```bash
  awk '/function renderAllDynamic/,/^}/' web/index.html | grep -q 'updateStatusUI\|setNetworkDownUI' && echo "✅ status area hooked"
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

- [ ] **IDX-25a — Centered card-expand hint**
  ```bash
  grep -q 'card-hint' web/dashboard.html && echo "✅ card-hint class"
  grep -q 'cardHintRemoveTimer' web/dashboard.html && echo "✅ dual-timer lifecycle"
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

- [ ] **DASH-REFRESH-01 — Dashboard `isRefreshing` reset on 401**
  ```bash
  grep -q 'isRefreshing = false' web/dashboard.html && echo "✅ isRefreshing reset"
  ```

- [ ] **DASH-SESSION-RETRY-01 — Dashboard session-expired retry**
  ```bash
  grep -q 'showSessionExpired\|sessionExpiredTitle' web/dashboard.html && echo "✅ session-expired retry"
  ```

- [ ] **DASH-HINT-01 — Dashboard dual-timer hint**
  ```bash
  grep -q 'cardHintTimer\|cardHintRemoveTimer' web/dashboard.html && echo "✅ dual-timer lifecycle"
  ```

- [ ] **DASH-HINT-02 — Dashboard `scrollend` scheduling**
  ```bash
  grep -q "'onscrollend' in window" web/dashboard.html && echo "✅ window scrollend detection"
  ```

- [ ] **ICON-512-SAFEZONE-01 — Shield fits W3C 80% safe circle**
  ```bash
  grep -q 'M 256 60' web/icon-512.svg && echo "✅ top vertex"
  grep -q 'M 416 142' web/icon-512.svg && echo "✅ right shoulder"
  ```

#### Version consistency (9 places)

- [ ] **v1.5.0 — Version consistency across 9 places**
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

### Custom tests (as applicable)

- [ ] Added new static verification steps (grep-based) for new security fixes
- [ ] Manually tested the change on a real device

### Manual test on a real device

<!--
  Very important! Automated tests are not enough for the Android environment.
  Test on a real device (or emulator) if possible.
-->

- [ ] Tested on a real Android device or emulator
- [ ] **Android version**: <!-- e.g. Android 14 -->
- [ ] **Device**: <!-- e.g. Pixel 6 Pro -->
- [ ] **ROM**: <!-- e.g. LineageOS 21 -->
- [ ] **Root**: <!-- e.g. Magisk 27.0 / KernelSU 0.9.5 -->

### Change-specific tests

**If the change is in the WebUI:**
- [ ] Opened WebUI and confirmed no JS errors
- [ ] Tested in both Arabic and English (bilingual)
- [ ] Tested PWA install / reload
- [ ] Tested SSE live updates
- [ ] Tested dynamic links (with custom PORT / DASHBOARD_PORT)
- [ ] Tested SW update-banner (both `index.html` and `dashboard.html`)
- [ ] **(v1.3.0)** Verified the live status LED turns green when the DNS engine is ON and red when OFF
- [ ] **(v1.4.0 → v1.5.0)** Verified the install button opens the install-method modal (not a direct `<a download>` link)
- [ ] **(v1.5.0)** Verified the modal offers 3 actions: "Install locally" + "Open GitHub page" + "Direct download"
- [ ] **(v1.5.0)** Verified `renderAllDynamic()` calls `renderCompanionButton()` and status area hooks

**If the change is in shell scripts:**
- [ ] Confirmed no new `shellcheck` warnings
- [ ] Tested on a real device (if possible)
- [ ] **v1.2.0**: Ran `make check-backup`
- [ ] **(v1.3.0)** Verified the DNS auto-start-after-boot fix (log line `[v1.3.0 FIX]` in `dnscrypt_main.log`)
- [ ] **(v1.3.0)** If the change touches `functions.sh:rotate_backups`, verified the SNAP-* / ROT-* semantics via `docs/REFERENCE.md` §5.2.4

**If the change is in `install_app.sh` (v1.5.0):**
- [ ] Verified the 5 cascade levels are all present
- [ ] Verified the three-way trap (EXIT / INT / TERM) with exit codes 130 / 143
- [ ] Verified the 75-second cascade deadline is enforced
- [ ] Verified `setenforce 0` is never called
- [ ] Verified the Play Protect trap restores `$_VERIFIER_ORIG`
- [ ] Tested direct CLI invocation: `su -c "sh install_app.sh"` — Ctrl+C returns 130, SIGTERM returns 143
- [ ] Verified `/data/local/tmp/dnscrypt-companion.apk` is removed on every exit path

**If the change is in the firewalls:**
- [ ] Checked `iptables -t nat -L DNSCRYPT_OUT -n`
- [ ] Checked `ip6tables -t nat -L DNSCRYPT_OUT6 -n`
- [ ] Confirmed `OUTPUT` has no orphans:
  ```bash
  su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
  # Expected: 0
  ```
- [ ] Tested `stopService` and `startService` cleanly

**If the change is in `STATUS_FILE` semantics:**
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

**If the change is in authentication:**
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
- [ ] **(v1.5.0)** Tested install token lifecycle: `GET /api?action=install_token` returns `{token, ttl: 60}`
- [ ] **(v1.5.0)** Verified the token is one-shot: second use returns 401 `invalid_token`
- [ ] **(v1.5.0)** Verified install rate limit: 6 rapid attempts → 429 on the 6th

**If the change is in `rebuildBlocklist` or `updateProfile` (RACE-1):**
- [ ] Confirmed `rebuildMu.Lock()` present + `defer rebuildMu.Unlock()`
- [ ] Tested concurrency manually (update + save simultaneously)
- [ ] Confirmed no deadlock (30 s timeout is enough)

**If the change is in `buildRuntimeInfo` or `runtime_info` (PORT-2 + MEM-1 + BAK-1):**
- [ ] Confirmed `webui_port` + `dashboard_port` present in JSON response
- [ ] Confirmed `memory_limit_mb` + `profile_key` present
- [ ] **v1.2.0**: Confirmed `backups` object with 7 fields:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```
- [ ] **(v1.3.0)** Confirmed `backups.available` counts manifest-carrying directories only (SNAP-MANIFEST)
- [ ] **(v1.3.0)** Confirmed `backups.last_backup_name` follows mtime (SNAP-MTIME)
- [ ] Confirmed `index.html` uses `data.dashboard_port`
- [ ] Confirmed `dashboard.html` uses `data.webui_port`

**If the change is in `/api/metrics` or `parsePrometheus` (Fix #1 + MEM-3):**
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

**If the change is in the memory limit logic (MEM-1):**
- [ ] Confirmed the limit adjusts when profile changes:
  ```bash
  echo "light" > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  sleep 5
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
  # Expected: 80
  ```

**If the change is in the backup layer (v1.2.0 — 10 defensive layers):**
- [ ] Ran the backup flow end-to-end on a test device:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'"
  # Expected: >= 1
  ```
- [ ] Verified the persistent backup directory survives uninstall
- [ ] Verified `status.sh --diagnose` produces a complete report
- [ ] Verified the watchdog token file exists with mode `0600`

**If the change is in the recovery mode (v1.2.0 — Layer 7):**
- [ ] Tested recovery trigger on a test device
- [ ] Confirmed the trigger file is consumed after a successful restore
- [ ] Verified the FIX-1 snapshot-and-reapply flow (`§[8a]` + `§[9]` + `§[9b2]`)

**If the change is in the DNS auto-start-after-boot (v1.3.0):**
- [ ] Verified the fix on a test device:
  ```bash
  su -c "echo 'ON' > /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
  su -c "reboot"
  sleep 30
  su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log | tail -5"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
  # Expected: DNS=UP
  ```

**If the change is in the rotation semantics (v1.3.0 — SNAP-* / ROT-*):**
- [ ] Verified SNAP-MANIFEST (manifest-less dir excluded)
- [ ] Verified ROT-PROTECT (`.last_stable` preserved)
- [ ] Verified parallel application (all consumers agree)
- [ ] Cross-referenced `docs/REFERENCE.md` §4.6 for the authoritative semantics

**If the change is in the Companion APK integration (v1.4.0):**
- [ ] Verified the APK is fetched and bundled
- [ ] Verified the route serves the APK
- [ ] Verified the route returns 404 when the APK is absent

**If the change is in the Companion Install Flow (v1.5.0):**
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

**If the change is in the CodeQL hardening (v1.4.0):**
- [ ] Confirmed CodeQL analysis passes with no `go/path-injection` alerts
- [ ] Tested `POST /api/remove_module` with various inputs

---

## 🔒 Security Checklist

<!--
  Fill this section if the PR relates to security.
  See SECURITY.md for full standards.
-->

### Basics

- [ ] Code contains no hardcoded secrets (passwords, tokens, keys)
- [ ] Contains no `console.log` or `fmt.Println` with sensitive data
- [ ] Used `subtle.ConstantTimeCompare` for secret comparison (if applicable)
- [ ] Applied `MaxBytesReader` on new POST bodies (if applicable)
- [ ] Used `atomicWriteFile` / `atomicWriteStream` for writes (if applicable)

### Authentication and endpoints

- [ ] Verified `checkAuth(r)` on every new endpoint (if applicable)
- [ ] Used `hasEndpoint(path, name)` instead of `strings.Contains` / `strings.HasSuffix`
- [ ] Used `getClientIP(r)` to extract IP (not `strings.Split`)
- [ ] Made `/api/auth/login` and `/api/auth/logout` POST-only (if applicable)
- [ ] If a new rate limit was added, registered attempts in `loginAttempts`
- [ ] **v1.2.0**: If adding an endpoint that needs watchdog auth, used `X-Watchdog-Token` + `verifyWatchdogToken()`
- [ ] **v1.5.0**: If adding an install-family endpoint, applied the localhost gate (`isLocalRequest`) and either the one-shot CSRF token (`validateAndConsumeInstallToken`) or an explicit decision to require only the session

### Input Validation

- [ ] If adding a port read, used `readConfPort` (with range check 1–65535)
- [ ] If using a dynamic shell command, used `shellQuote()`
- [ ] If adding a new health endpoint, considered `isLocalRequest` (local-only)
- [ ] **(v1.4.0)** If the PR routes a caller-provided path into any filesystem operation, used `filepath.Base()` sanitization + rebuilt the path from a trusted base (see `removeModule` for the canonical pattern)
- [ ] **(v1.5.0)** If the PR runs an install, verified that `install_app.sh` uses a hardcoded APK path and `shellQuote()` on every argument

### Firewall

- [ ] Did not pollute `OUTPUT` / `INPUT` / `FORWARD` with dynamic rules
- [ ] Used `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` for the firewall
- [ ] Confirmed `--wait` on every `iptables` / `ip6tables` invocation
- [ ] Tested `_legacy_cleanup_*` after upgrade from an older version

### Concurrency (RACE-1 + BAK-2)

- [ ] Any operation modifying `ALLOWLIST` / `DENYLIST` / `BLOCKLIST` calls `rebuildBlocklist`
- [ ] `rebuildBlocklist` is protected by `rebuildMu.Lock()` + `defer Unlock()`
- [ ] No nested deadlock (never calls a function that locks the same mutex)
- [ ] **v1.2.0**: Any new destructive operation on user data calls `createAutoBackup(reason)` first
- [ ] **v1.2.0**: `backupMu` is used only via `createAutoBackup` — do NOT add a second mutex
- [ ] **v1.2.0**: `backupMu` is held for at most `AUTO_BACKUP_TIMEOUT = 15 s`
- [ ] **(v1.3.0)**: Any change to `buildBackupInfo` (main.go) or `rotate_backups` (functions.sh) keeps the SNAP-* / ROT-* semantics in sync across the module — see `docs/REFERENCE.md` §4.6
- [ ] **(v1.5.0)**: If a new mutex is added for install-family state, documented its ordering relative to `installTokensMu`, `installAttemptsMu`, and `companionStateMutex`

### Memory (v1.1.0)

- [ ] If adding a new profile, updated `MEMORY_LIMIT_*` in main.go
- [ ] If adding a new profile, updated the inline fallback in all four shell scripts (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`)
- [ ] If adding a new profile, updated `webui.conf` template in `customize.sh`
- [ ] If adding a new profile, updated `web/index.html` `<select id="profileSelect">`

### Data Preservation (v1.2.0)

- [ ] If adding a new preserved file:
  - [ ] Updated the `USER_FILES` list in **all 5** scripts: `customize.sh`, `functions.sh`, `service.sh`, `status.sh`, `uninstall.sh`
  - [ ] Updated the "5 Preserved Files" table in `README.md`
  - [ ] Updated `docs/REFERENCE.md` §4.2
- [ ] If changing the rotation policy:
  - [ ] Updated the constant in **all 4** scripts: `customize.sh`, `functions.sh`, `service.sh`, `action.sh`
  - [ ] Updated `docs/REFERENCE.md` §4.6
  - [ ] **(v1.3.0)** Aligned with the SNAP-MANIFEST + SNAP-MTIME + ROT-MANIFEST + ROT-MTIME + ROT-PROTECT semantics — see `docs/REFERENCE.md` §4.6
- [ ] If changing the `runtime_info.backups` schema:
  - [ ] Updated `buildBackupInfo()` in `main.go`
  - [ ] Kept `status.sh --json` in sync
  - [ ] Updated `docs/REFERENCE.md` §2.6.7
- [ ] If adding a config migration:
  - [ ] Added it to `migrate_config()` in `customize.sh`
  - [ ] Updated `docs/GUIDE.md` §5
- [ ] Confirmed the 10 defensive layers are still orthogonal to the firewall (see `docs/REFERENCE.md` §5.6.3)

### Rotation semantics (v1.3.0)

- [ ] If the PR touches `buildBackupInfo` (main.go):
  - [ ] Verified SNAP-MANIFEST (`.manifest.json` presence)
  - [ ] Verified SNAP-MTIME (`ModTime()` for newest selection)
  - [ ] Cross-checked `functions.sh:rotate_backups` still agrees
- [ ] If the PR touches `rotate_backups` (functions.sh):
  - [ ] Verified ROT-MANIFEST (manifest-based detection)
  - [ ] Verified ROT-MTIME (`sort -rn -k1,1`)
  - [ ] Verified ROT-PROTECT (`.last_stable` + newest install preserved)
  - [ ] Cross-checked the parallel helpers in `status.sh`, `watchdog.sh`, `customize.sh`, `action.sh`, `uninstall.sh`
- [ ] If the PR touches `docs/REFERENCE.md` §4.6:
  - [ ] Cross-checked `docs/REFERENCE.md` §4.6.5
  - [ ] Cross-checked `CHANGELOG.md` §[v1.3.0]

### Companion APK (v1.4.0)

- [ ] If changing `proxy/app-apk.version`:
  - [ ] Verified the format is `X.Y.Z` (no `v` prefix)
  - [ ] Verified `make check-app-version` passes
  - [ ] Verified the corresponding release exists in the sister repo [`gasciljh/dnscrypt-proxy-app`](https://github.com/gasciljh/dnscrypt-proxy-app)
- [ ] If changing `scripts/fetch_app_apk.sh`:
  - [ ] Verified it remains idempotent (cache hit on re-run)
  - [ ] Verified the `--offline`, `--json`, `--force`, and `--version` flags still work
  - [ ] Verified the SHA256 output is written next to the APK
- [ ] If changing the `/app-debug.apk` route in `main.go`:
  - [ ] Verified the 404 path (file absent) still works
  - [ ] Verified the mime type is `application/vnd.android.package-archive`
  - [ ] Verified the per-extension Cache-Control is applied

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
  - [ ] Verified the localhost gate applies to all three surfaces (install, uninstall, install_token)
  - [ ] Verified the one-shot CSRF token has a 60 s TTL
  - [ ] Verified the per-IP rate limit is enforced (5 / 15 min)
  - [ ] Verified tokens are compared with `subtle.ConstantTimeCompare`
  - [ ] Verified `invalidateCompanionStateCache()` is called after every install/uninstall attempt (success or failure)
- [ ] If changing the install-method modal (IDX-24):
  - [ ] Verified the three actions remain: local install / open GitHub page / direct GitHub download
  - [ ] Verified all GitHub URLs point at `gasciljh/dnscrypt-proxy-app`
  - [ ] Verified `_resetModalLayout()` is idempotent

### For security fixes

- [ ] Updated `SECURITY.md` (Attack Vectors section + §5.X)
- [ ] Updated `docs/REFERENCE.md` (Trade-offs, §1.12)
- [ ] Updated `docs/GUIDE.md` (Diagnostics, §7)
- [ ] Added the Audit Correction #XX in the commit footer
- [ ] Added HTML anchor `<a name="XXX"></a>` (if a new section was created)
- [ ] Updated the Audit Corrections Registry in `SECURITY.md` §15

### Global Edition (v1.2.0 — EN + AR)

- [ ] Any new user-facing string in the WebUI is present in **both** `translations.en` and `translations.ar`
- [ ] The default language on first load is still **English**
- [ ] The language preference is stored only in `localStorage['dnscrypt-lang']` — never sent to the server
- [ ] RTL layout verified (Chrome 88+, Firefox 92+, Samsung Internet 16+)
- [ ] No API endpoint accepts or returns a language identifier

---

## 📖 Documentation

<!--
  Do not forget to update documentation — it is part of PR quality.
  See docs/CONTRIBUTING.md §10.
-->

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
- [ ] Added / updated code comments (Go docstrings, shell comments)
- [ ] If a new field was added to `runtime_info`, updated both `web/index.html` and `web/dashboard.html` translation tables (en + ar)
- [ ] **v1.2.0**: If a backup-layer change, updated `docs/REFERENCE.md` §4 **and** `docs/GUIDE.md` §8
- [ ] **v1.2.0**: If a language-toggle change, updated `docs/REFERENCE.md` §7.6
- [ ] **(v1.3.0)** If a DNS auto-start-after-boot change, updated `docs/REFERENCE.md` §3.3 and `docs/GUIDE.md` §7
- [ ] **(v1.3.0)** If a rotation-semantics change (SNAP-* / ROT-*), updated `docs/REFERENCE.md` §4.6 and `CHANGELOG.md` §[v1.3.0]
- [ ] **(v1.4.0)** If a companion APK change, updated `README.md` §Optional Android App and `docs/REFERENCE.md` §7.8
- [ ] **(v1.4.0)** If a `removeModule` change, updated `SECURITY.md` §5.34
- [ ] **(v1.4.0)** If an iOS PWA removal change, updated `CHANGELOG.md` §[v1.4.0] Removed section
- [ ] **(v1.5.0)** If a companion install flow change, updated `SECURITY.md` §5.36, `docs/REFERENCE.md` §3.12, `docs/REFERENCE.md` §2.7.14–§2.7.15, and `CHANGELOG.md` §[v1.5.0]
- [ ] **(v1.5.0)** If a Layered Bootstrap change, updated `docs/REFERENCE.md` §1.4, `docs/adr/0003-layered-bootstrap.md`, and `CHANGELOG.md` §[v1.5.0]
- [ ] **(v1.5.0)** If a `manifest.json` `x-note-*` change, updated `docs/REFERENCE.md` §7 and `CHANGELOG.md` §[v1.5.0]

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
- [ ] Reasonable number of commits (no 50 commits for a small PR)
- [ ] No merge commits (`Merge branch 'main'`) — used `rebase` instead

### Code quality

- [ ] No dead code
- [ ] No unjustified `TODO` or `FIXME`
- [ ] No `fmt.Println` or `console.log` in production code
- [ ] Names are clear (`userCount` not `uc`)
- [ ] Comments on exported functions
- [ ] Every error is handled (`if err != nil`) correctly
- [ ] Used `defer unlock()` on every mutex (no forgotten unlock)

### Build verification

- [ ] `make build` passes
- [ ] `bash -n` clean on modified shell scripts
- [ ] No hardcoded `/system/bin/sh` (use `getSystemShell()`)
- [ ] No hardcoded `127.0.0.1` in HTML (use `window.location.hostname`)
- [ ] **v1.2.0**: `make check-backup` passes (if backup layer touched)
- [ ] **(v1.4.0)**: `make check-app-version` passes (if `app-apk.version` touched)
- [ ] **(v1.5.0)**: `make check-install-app` passes (if `install_app.sh` touched)
- [ ] **(v1.5.0)**: `make check-boot-mini` passes (if `boot-mini.sh` or `functions.sh` touched)

### Documentation

- [ ] Reviewed every item in the "📖 Documentation" section above
- [ ] No broken links in the updated documentation
- [ ] Code examples in the documentation are correct (actually tested)

### Cleanliness

- [ ] Removed all temporary files (`*.tmp`, `*.bak`, `scratch.*`)
- [ ] No binary files uploaded without justification (exception: `web/app-debug.apk` in v1.4.0+, which is intentionally bundled)
- [ ] No `.DS_Store` or `Thumbs.db` files
- [ ] Reviewed `git diff` before pushing (no unintended changes)
- [ ] Confirmed no leftover `*.tmp_*` from `atomicWriteFile`
- [ ] **v1.2.0**: No leftover `txn-*` / `orphan-txn-*` in the committed backup directory (those belong to runtime)
- [ ] **(v1.4.0+)**: No leftover `dist/DNS-Proxy-v*.apk` committed (it is a build artifact)
- [ ] **(v1.5.0)**: No leftover `web/app-debug.apk*` committed (they are gitignored via `.gitignore` §[20])

---

## 🖼️ Screenshots / Recordings

<!--
  If the PR relates to the UI, attach images or GIFs.
  For bug fixes: attach "before" and "after" images if possible.
  For logic changes: no images needed.

  v1.2.0: If the change touches the bilingual UI, attach BOTH
  English and Arabic screenshots.

  v1.4.0: If the change touches the companion APK integration, attach
  a screenshot of the install button in the WebUI header.

  v1.5.0: If the change touches the install-method modal (IDX-24),
  attach a screenshot of all three actions across both categories.
-->



---

## 📌 Additional Notes

<!--
  Anything else the reviewer needs to know:
  - Architectural decisions made
  - Trade-offs considered
  - Known limitations
  - Questions for the reviewer
  - References (RFCs, OWASP, Netfilter docs, ...)
-->



---

## 🎯 Reviewer Suggestion

<!--
  Optional: if you want a specific review, mention it here.

  v1.2.0: If the change touches the backup layer, consider requesting
  a review from a Data Guardian badge holder (see docs/CONTRIBUTING.md §14).

  v1.3.0: If the change touches rotation semantics (SNAP-* / ROT-*),
  consider requesting a review from a contributor familiar with the
  v1.3.0 refinements. See docs/REFERENCE.md §4.6 and §5.2.4 for the
  verification procedure.

  v1.4.0: If the change touches the companion APK integration,
  consider requesting a review from a maintainer of the sister repo
  gasciljh/dnscrypt-proxy-app.

  v1.5.0: If the change touches the companion install flow, consider
  requesting a review from a contributor who has verified the SELinux
  staging + Play Protect trap path on a real device. See
  SECURITY.md §5.36 and docs/REFERENCE.md §3.12.
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

     • Ensure the PR references an Issue (if one exists)
     • Review the diff one last time before pushing
     • Test locally if possible
     • Be ready to respond and adjust

     🎯 Quick verification commands (before pushing):

       make build                          # Go build for all 4 architectures
       bash -n proxy/*.sh scripts/*.sh     # shell syntax check
       gofmt -l proxy/                     # Go format check
       shellcheck --severity=warning proxy/*.sh scripts/*.sh
       make check-backup                   # v1.2.0: backup shell validation
       make check-app-version              # v1.4.0: companion APK version check
       make check-install-app              # v1.5.0: install_app.sh validation
       make check-boot-mini                # v1.5.0: Layer 0 / Layer 1 validation

     🎯 v1.1.0 extra checks (if main.go changed):

       grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
       awk '/func shellQuote/,/^}/' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2"
       awk '/func metricsProxyHandler/,/^}/' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

     🎯 v1.2.0 extra checks (if backup layer changed):

       grep -q 'CANDIDATE_SOURCES' proxy/customize.sh && echo "✅ Layer 1"
       grep -q 'PERSISTENT_BACKUP' proxy/customize.sh && echo "✅ Layer 2"
       grep -q 'begin_transaction' proxy/customize.sh && echo "✅ Layer 4"
       grep -q 'copy_with_context' proxy/customize.sh && echo "✅ Layer 6"
       grep -q 'RECOVERY_TRIGGER' proxy/customize.sh && echo "✅ Layer 7"
       grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2"
       grep -q 'func buildBackupInfo' proxy/main.go && echo "✅ BAK-1"
       grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ WD-TOKEN"
       grep -q 'swRegistration.waiting' web/index.html && echo "✅ FIX-2"

     🎯 v1.3.0 extra checks (if service.sh / index.html / rotation changed):

       grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ DNS auto-start"
       grep -q 'led-on' web/index.html && echo "✅ LED markup"
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
       awk '/func buildBackupInfo/,/^}/' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
       awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
       awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
       awk '/rotate_backups\(\)/,/^}/' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"

     🎯 v1.4.0 extra checks (if companion APK / CodeQL / iOS changes):

       grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE"
       grep -q '/app-debug.apk' proxy/main.go && echo "✅ APK route"
       grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ CodeQL sanitizer"
       grep -q 'securejoin.SecureJoin' proxy/main.go && echo "✅ SecureJoin (ADR-0002)"
       ! grep -qE '^\s*(function isIOSDevice|isIOSDevice\s*=)' web/index.html && echo "✅ iOS/JS removed"
       test -f scripts/fetch_app_apk.sh && echo "✅ APK fetcher"
       test -f proxy/app-apk.version && echo "✅ APK version file"

     🎯 v1.5.0 extra checks (if companion install / Layered Bootstrap changed):

       test -f proxy/install_app.sh && echo "✅ install_app.sh present"
       test -f proxy/boot-mini.sh && echo "✅ boot-mini.sh present"
       grep -q 'CASCADE_DEADLINE_SECONDS=75' proxy/install_app.sh && echo "✅ 75 s deadline"
       grep -q 'INSTALL_TOKEN_TTL.*60' proxy/main.go && echo "✅ 60 s token TTL"
       ! grep -v '^[[:space:]]*#' proxy/install_app.sh | grep -q 'setenforce 0' && echo "✅ no setenforce"
       grep -q "trap '_cleanup_app; exit 130' INT" proxy/install_app.sh && echo "✅ INT trap exits 130"
       grep -q "trap '_cleanup_app; exit 143' TERM" proxy/install_app.sh && echo "✅ TERM trap exits 143"
       grep -q '_VERIFIER_ORIG' proxy/install_app.sh && echo "✅ trap restores verifier state"
       grep -q 'boot-mini.sh' proxy/functions.sh && echo "✅ Layer 1 sources Layer 0"
       grep -q 'Verify boot-mini.sh integration' .github/workflows/ci.yml && echo "✅ CI Step 9"
       grep -q 'filepath-securejoin v0.7.0' proxy/go.mod && echo "✅ ADR-0002 pin"

     📖 Documentation references:

       docs/CONTRIBUTING.md §5   - Branch strategy
       docs/CONTRIBUTING.md §7   - PR process
       docs/CONTRIBUTING.md §11  - Release process
       docs/adr/README.md        - Architecture Decision Records
       docs/adr/0002-external-dependency.md - External dependency — filepath-securejoin
       docs/adr/0003-layered-bootstrap.md   - Layered Bootstrap
       docs/CONTRIBUTING.md      - Contribution guide
       SECURITY.md               - Security policy (§5.30–§5.36)
       SECURITY.md §15           - Audit Corrections Registry
       docs/REFERENCE.md §4.6    - v1.3.0 rotation semantics (authoritative)
       docs/REFERENCE.md §3.12   - v1.5.0 backend additions
       docs/REFERENCE.md §1.4    - Layered Bootstrap (v1.5.0)
       docs/REFERENCE.md §3.12   - install_app.sh contract (v1.5.0)
       docs/REFERENCE.md §4      - Backup system reference
       docs/GUIDE.md §8          - Emergency recovery
       docs/GUIDE.md §5          - Upgrade guide
       docs/REFERENCE.md §5.2.4  - On-device SNAP-*/ROT-* verification
       docs/REFERENCE.md §7      - Manifest technical notes (v1.5.0)

     Current version: v1.5.0
     Last updated: 2026-10-18

     🎉 Thanks for your contribution! Every PR improves the project.
     ============================================================ -->