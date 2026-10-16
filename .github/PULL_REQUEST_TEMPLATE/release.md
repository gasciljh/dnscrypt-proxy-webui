<!-- ============================================================
     DNSCrypt Smart Filter – Release PR Template
     Version: v1.4.0 (Global Edition)
     Last updated: 2026-10-08
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template applies to PRs from `release/*` or `hotfix/*`
     branches targeting `main`.

     ⚠️ HOW TO USE IT:
       GitHub only auto-applies the DEFAULT template
       (.github/PULL_REQUEST_TEMPLATE.md). To use this one, append
       `?template=release.md` to the PR-creation URL:

         https://github.com/gasciljh/dnscrypt-proxy-webui/compare/main...release/v1.4.0?template=release.md

       Full details: docs/BRANCHING.md §4.4
                     docs/RELEASE_PROCESS.md §5
                     docs/adr/0005-release-specific-pr-template.md
     ============================================================
     Identifier inventory in this file (5 total):
       • HARD-RPR-01 (Last updated correction — v1.4.0)
       • HARD-RPR-02 (v1.3.0 block extended with SNAP-* / ROT-* — v1.4.0)
       • HARD-RPR-03 (v1.3.0 checklist extended — v1.4.0)
       • HARD-RPR-04 (Reviewer Checklist — v1.3.0 rotation — v1.4.0)
       • HARD-RPR-05 (Encoding correction — mojibake fixed — v1.4.0)

     Cross-references:
       • docs/BRANCHING.md §4.4               — release workflow
       • docs/RELEASE_PROCESS.md §5           — release PR steps
       • docs/adr/0005, docs/adr/0006         — why separate template + release-patch.sh
       • docs/SECURITY.md §5.31–§5.35         — security model
       • docs/ARCHITECTURE.md §4.13           — v1.3.0 server-side refinements (authoritative)
       • docs/BACKUP.md §6.5                  — v1.3.0 rotation semantics
       • docs/EMERGENCY.md                    — recovery guide
       • docs/UPGRADE.md §3.x                 — upgrade paths
       • docs/COMPATIBILITY.md §10.3.5        — on-device SNAP-*/ROT-* verification
       • CHANGELOG.md §[v1.3.0], §[v1.4.0]    — version history

     v1.4.0 additions:
       • New "v1.4.0 — companion app integration" checklist
         covering the APK fetcher, the `/app-debug.apk` route, the
         WebUI install button, and the CodeQL `removeModule` fix.
       • New "v1.4.0 — CodeQL hardening" verification block.
       • Updated version examples from v1.3.0 to v1.4.0.

     v1.3.0 additions (extended in this revision):
       • New "v1.3.0 — feature + boot fix" checklist covering the
         PWA install button, live status LED, the DNS
         auto-start-after-boot fix in `service.sh`, and the
         server-side rotation refinements (SNAP-MANIFEST,
         SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT).
       • New grep verifications for the rotation semantics
         (main.go + functions.sh + parallel helpers).
       • Updated Reviewer Checklist with the v1.3.0 rotation
         verification block.

     v1.2.0 additions (kept):
       • "v1.2.0 — data preservation" checklist covering the
         10 defensive layers, `backupMu`, the 7-field
         `runtime_info.backups` object, and the watchdog token.
       • "v1.2.0 — backup layer verification" block with
         commands to confirm snapshots are created and the
         persistent backup directory exists.
       • "v1.2.0 — watchdog token" check confirming the
         `.watchdog_token` file exists with mode `0600`.
       • "v1.2.0 — bilingual WebUI (EN + AR)" check.
       • "v1.2.0 — 42-scenario matrix" verification via
         `upgrade-test.yml`.

     v1.4.0 — POST-AUDIT FIXES (this revision):
       A post-audit review of this file against the v1.3.0 / v1.4.0
       code identified the following documentation gaps. All are
       addressed in-place; no version bump.

       🔧 HARD-RPR-01 — `Last updated` corrected. The footer
         previously said `2026-10-06` (the v1.4.0 release date,
         not the v1.4.0 file-editing date). It now reads
         `2026-10-08`, matching every other file in the v1.4.0
         module.

       🔧 HARD-RPR-02 — The `v1.3.0 additions` block at the top
         of this file (the HTML comment header) was extended with
         the server-side rotation refinements (SNAP-MANIFEST,
         SNAP-MTIME, ROT-MANIFEST, ROT-MTIME, ROT-PROTECT). The
         previous version mentioned only the client-side changes
         (PWA install button, live status LED, DNS auto-start
         fix).

       🔧 HARD-RPR-03 — The "v1.3.0 — feature + boot fix" checklist
         was extended with a new subsection for the rotation
         semantics, including the on-device verification procedure.

       🔧 HARD-RPR-04 — The "Reviewer Checklist — v1.3.0-specific"
         block was extended with the rotation verification
         commands.

       🟢 HARD-RPR-05 — Encoding correction. The previous version
         of this file contained corrupted UTF-8 sequences
         (mojibake) throughout:
           • `ÔÇô` → `–`   (en-dash)
           • `ÔÜá´ŞĆ` → `⚠️` (warning + emoji)
           • `ÔÇó` → `•`    (bullet)
           • `├Ś` → `×`     (multiplication sign)
           • `Ôćĺ` → `→`    (right arrow)
           • `Ôťů` → `✅`   (white heavy check mark)
           • `ÔŁî` → `❌`   (cross mark)
           • `ÔöîÔöÇ...` → `┌─...` (box-drawing characters)
         All mojibake sequences have been replaced with the
         correct UTF-8 characters. This is a documentation-only
         correction — the visible text (as rendered by GitHub)
         is unchanged.
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
             jq -r "\"update.json: \(.version) \(.versionCode)\"" update.json'
-->

```text
VERSION: vX.Y.Z
version=vX.Y.Z
versionCode=NNNNNNN
update.json: vX.Y.Z NNNNNNN
```

### v1.4.0 — version consistency (6 files + APK version)

<!--
  Since v1.1.0, the project requires version-string consistency
  across 5 places. v1.2.0 keeps this requirement. v1.4.0 adds a
  6th place: `proxy/app-apk.version` (the companion app's own
  version, independent of the module version).

  Run this and paste the output:

    V=$(cat VERSION)
    echo "VERSION:             $V"
    echo "module.prop:         $(grep '^version=' module.prop | cut -d= -f2)"
    echo "manifest.json:       $(jq -r .version web/manifest.json)"
    echo "sw.js:               $(grep -oE "CACHE_VERSION = '[^']+'" web/sw.js | cut -d"'" -f2)"
    echo "index.html:          $(grep -oE "var VERSION = '[^']+'" web/index.html | cut -d"'" -f2)"
    echo "dashboard.html:      $(grep -oE "var VERSION = '[^']+'" web/dashboard.html | cut -d"'" -f2)"
    echo "app-apk.version:     $(cat proxy/app-apk.version 2>/dev/null || echo 'missing')"
-->

```text
VERSION:             vX.Y.Z
module.prop:         vX.Y.Z
manifest.json:       X.Y.Z            (note: no 'v' prefix — PWA spec)
sw.js:               vX.Y.Z           (CACHE_VERSION)
index.html:          vX.Y.Z           (var VERSION)
dashboard.html:      vX.Y.Z           (var VERSION)
app-apk.version:     X.Y.Z            (companion app, no 'v' prefix — v1.4.0)
```

- [ ] **`VERSION`** = `module.prop.version` = `update.json.version`
- [ ] **`VERSION`** = `sw.js` CACHE_VERSION
- [ ] **`VERSION`** = `index.html` `var VERSION`
- [ ] **`VERSION`** = `dashboard.html` `var VERSION`
- [ ] **`manifest.json.version`** matches (without the `v` prefix)
- [ ] **`versionCode`** = `MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100`
- [ ] **(v1.4.0)** `proxy/app-apk.version` exists and has format `X.Y.Z` (no `v` prefix)

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

### v1.2.0 — data preservation (10 defensive layers)

<!--
  v1.2.0 introduces the Data-Preservation Release. Every in-place
  upgrade now runs inside the 10 defensive layers. This block
  confirms the layer functions are present in the released files.

  See:
    docs/BACKUP.md         — full reference
    docs/SECURITY.md §5.31 — security model
    docs/ARCHITECTURE.md §3.10 — flow diagram
-->

- [ ] **10 defensive layers present in `customize.sh`**
  ```bash
  for L in CANDIDATE_SOURCES PERSISTENT_BACKUP verify_backup_integrity \
           begin_transaction detect_root_solution copy_with_context \
           RECOVERY_TRIGGER migrate_config; do
      grep -q "$L" proxy/customize.sh && echo "✅ $L" || echo "❌ $L"
  done
  ```
- [ ] **Backup helpers present in `functions.sh`**
  ```bash
  for H in auto_backup_if_needed rotate_backups backup_user_files \
           restore_user_files cleanup_old_transactions get_backup_dir \
           ensure_backup_dir get_last_backup_time copy_with_context \
           verify_backup_integrity write_manifest get_watchdog_token; do
      grep -q "$H" proxy/functions.sh && echo "✅ $H" || echo "❌ $H"
  done
  ```
- [ ] **`main.go` backup additions (BAK-1..BAK-4)**
  ```bash
  grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2 createAutoBackup"
  grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 backupMu"
  grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"
  grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"
  grep -q 'func buildBackupInfo' proxy/main.go && echo "✅ BAK-1 function"
  ```

### v1.2.0 — backup layer verification

<!--
  Confirms the persistent backup directory exists and that a
  snapshot has been created. Run these commands after the release
  is published and installed on a test device.
-->

```bash
# 1. Backup state (7-field object)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

```json
{
  "available": 3,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-10-06 15:00:00",
  "last_backup_name": "20261006-150000-manual-12345",
  "last_stable": "20261006-095826-v1.4.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

- [ ] The `backups` object has **exactly 7 keys**:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```
- [ ] `available >= 1` (at least one snapshot exists)
- [ ] `in_flight_txn == 0` (no stuck transactions)
- [ ] `orphan_txn == 0` (no preserved interrupted installs)
- [ ] `path == "/sdcard/dnscrypt-webui-backup"`
- [ ] Backup directory exists with mode `0700`:
  ```bash
  su -c "stat -c '%a %U:%G %n' /sdcard/dnscrypt-webui-backup/"
  # Expected: 700 root:root
  ```
- [ ] The 5 preserved files are present in `current/`:
  ```bash
  su -c "ls /sdcard/dnscrypt-webui-backup/current/"
  # Expected: webui.conf, dnscrypt-proxy.toml, selected_profile.txt,
  #           allowlist.txt, denylist.txt, .manifest.json
  ```
- [ ] Cross-check with `status.sh --json`:
  ```bash
  diff <(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups') \
       <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | \
         jq -S '.backups | del(.status, .last_backup_age_seconds)'")
  # Expected: no diff
  ```
- [ ] `status.sh --diagnose` produces a complete report:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -30
  ```

### v1.2.0 — watchdog token (WD-TOKEN)

<!--
  v1.2.0 replaces the previous implicit "localhost bypass" on
  POST /api/ensure_running_service with an explicit token.

  See docs/SECURITY.md §5.33 for the design.
-->

- [ ] Token file exists with mode `0600`:
  ```bash
  su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
  # Expected: -rw------- root root

  su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
  # Expected: 600
  ```
- [ ] Token is not empty:
  ```bash
  su -c "wc -c /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
  # Expected: ~64 (hex token) or ~65 (with newline)
  ```
- [ ] Static verification in `main.go`:
  ```bash
  grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ loader"
  grep -q 'verifyWatchdogToken' proxy/main.go && echo "✅ verify"
  grep -q 'X-Watchdog-Token' proxy/main.go && echo "✅ header name"
  grep -q 'subtle.ConstantTimeCompare' proxy/main.go && echo "✅ constant-time"
  ```
- [ ] Static verification in `watchdog.sh`:
  ```bash
  grep -q 'watchdog_token' proxy/watchdog.sh && echo "✅ reads"
  grep -q 'X-Watchdog-Token' proxy/watchdog.sh && echo "✅ sends"
  ```
- [ ] Runtime test — the watchdog recovers a crashed DNS engine:
  ```bash
  # Ensure the service is running
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
  # Expected: DNS=UP

  # Kill the DNS engine
  su -c "pkill -9 dnscrypt-proxy"

  # Wait for the watchdog (up to 60s)
  sleep 60

  # Verify the engine was restarted
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
  # Expected: DNS=UP
  ```

### v1.2.0 — bilingual WebUI (EN + AR)

<!--
  v1.2.0 ships the WebUI with English as the default language and
  an in-page toggle (`langToggle`) to switch to Arabic. The API is
  language-neutral.

  See docs/ARCHITECTURE.md §6.7 and docs/API.md §10.8.
-->

- [ ] Toggle present in all three HTML pages:
  ```bash
  for f in index.html dashboard.html offline.html; do
      grep -q 'id="langToggle"' web/$f && echo "✅ $f toggle"
      grep -q 'en:' web/$f && grep -q 'ar:' web/$f && echo "✅ $f en+ar"
      grep -q "dnscrypt-lang" web/$f && echo "✅ $f localStorage"
      grep -q '\[dir="rtl"\]' web/$f && echo "✅ $f RTL"
  done
  ```
- [ ] Manual browser test:
  - [ ] Page loads in **English** by default
  - [ ] Clicking `langToggle` switches to **Arabic** (RTL layout)
  - [ ] Preference persists across reloads
  - [ ] No network requests triggered by the toggle
- [ ] API is language-neutral:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq | grep -i lang
  # Expected: no output
  ```

### v1.2.0 — 42-scenario matrix

<!--
  v1.2.0 adds a CI matrix that validates the 10 defensive layers
  across 42 combinations (3 root solutions × 2 source versions ×
  7 scenarios). See .github/workflows/upgrade-test.yml.
-->

- [ ] The workflow file exists:
  ```bash
  test -f .github/workflows/upgrade-test.yml && echo "✅ present"
  ```
- [ ] The workflow is green for the release commit:
  ```bash
  gh run list --workflow=upgrade-test.yml --limit 5
  ```
- [ ] `backup-smoke-test` job in `ci.yml` passed:
  ```bash
  grep -q 'backup-smoke-test' .github/workflows/ci.yml && echo "✅ job defined"
  ```
- [ ] `make check-backup` passes locally:
  ```bash
  make check-backup
  # Expected: ✅ Backup shell validation complete
  ```

### v1.2.0 — breaking change check

- [ ] `POST /api/append_denylist` now requires a `content` parameter:
  ```bash
  curl -X POST -b /tmp/cookies.txt \
      http://127.0.0.1:9090/api/append_denylist | jq
  # Expected: {"status": "error", "message": "Missing or empty 'content' parameter"}
  ```
- [ ] Sending `content` works:
  ```bash
  curl -X POST -b /tmp/cookies.txt \
      --data-urlencode "content=facebook.com" \
      http://127.0.0.1:9090/api/append_denylist | jq '.changed'
  # Expected: true (or false if no change)
  ```
- [ ] Documented in `CHANGELOG.md` §Breaking Changes and
      `docs/API.md` §6.2.7

### v1.3.0 — feature + boot fix + rotation

<!--
  v1.3.0 introduced three feature/correctness improvements plus
  the server-side rotation refinements. All must be intact in the
  release candidate.

  See:
    docs/ARCHITECTURE.md §6.7, §9, §4.13.2
    docs/SECURITY.md v1.3.0 section
    docs/BACKUP.md §6.5
-->

#### v1.3.0 — DNS auto-start-after-boot fix

- [ ] **`service.sh` §[19] block present**
  ```bash
  grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ §[19] block present"
  grep -q 'ensure_running_service' proxy/service.sh && echo "✅ API call present"
  grep -q 'X-Watchdog-Token' proxy/service.sh && echo "✅ uses watchdog token"
  ```
- [ ] **DNS engine starts automatically after reboot**
  ```bash
  # 1. Ensure the status file says ON
  su -c "echo 'ON' > /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"

  # 2. Reboot
  su -c "reboot"

  # 3. After boot
  sleep 30
  su -c "grep 'v1.3.0 FIX' /data/local/tmp/dnscrypt_main.log | tail -5"
  # Expected: "✅ [v1.3.0 FIX] DNS start requested successfully"

  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
  # Expected: DNS=UP
  ```

#### v1.3.0 — live status LED + PWA install button

- [ ] **Live status LED present in WebUI**
  ```bash
  grep -q 'led-on' web/index.html && echo "✅ led-on"
  grep -q 'led-off' web/index.html && echo "✅ led-off"
  ```
- [ ] **PWA install button markup present** (still a `<button>` in v1.3.0;
      converted to `<a download>` in v1.4.0)
  ```bash
  grep -q 'id="pwaInstallBtn"' web/index.html && echo "✅ button present"
  ```

#### v1.3.0 — server-side rotation refinements (SNAP-* / ROT-*)

- [ ] **SNAP-MANIFEST present in `main.go:buildBackupInfo`**
  ```bash
  grep -A15 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
  ```
- [ ] **SNAP-MTIME present in `main.go:buildBackupInfo`**
  ```bash
  grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
  ```
- [ ] **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT present in `functions.sh:rotate_backups`**
  ```bash
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"
  ```
- [ ] **Parallel application in the other 5 shell scripts**
  ```bash
  grep -q '_list_snapshots' proxy/status.sh && echo "✅ status.sh helper"
  grep -q 'manifest.json' proxy/watchdog.sh && echo "✅ watchdog.sh manifest check"
  grep -q 'manifest.json' proxy/customize.sh && echo "✅ customize.sh manifest check"
  grep -q '_inline_list_snapshots' proxy/action.sh && echo "✅ action.sh helper"
  grep -q '_uninstall_list_snapshots' proxy/uninstall.sh && echo "✅ uninstall.sh helper"
  ```
- [ ] **On-device verification (see docs/COMPATIBILITY.md §10.3.5)**
  ```bash
  # SNAP-MANIFEST: manifest-less dir must be ignored by the API count
  su -c "mkdir -p /sdcard/dnscrypt-webui-backup/29991231-235959-test"
  su -c "echo 'x' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/webui.conf"
  BEFORE=$(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
  su -c "echo '{}' > /sdcard/dnscrypt-webui-backup/29991231-235959-test/.manifest.json"
  AFTER=$(curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available')
  [ "$AFTER" -gt "$BEFORE" ] && echo "✅ SNAP-MANIFEST active"
  su -c "rm -rf /sdcard/dnscrypt-webui-backup/29991231-235959-test"

  # ROT-PROTECT: .last_stable target survives rotation
  STABLE=$(su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable 2>/dev/null")
  su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; rotate_backups 5"
  [ -d "/sdcard/dnscrypt-webui-backup/$STABLE" ] && echo "✅ ROT-PROTECT active"
  ```
- [ ] **Documentation updated for v1.3.0 rotation semantics**
  - [ ] `docs/ARCHITECTURE.md` §4.13.2 present
  - [ ] `docs/BACKUP.md` §6.5 describes ROT-MTIME (not name sort)
  - [ ] `docs/COMPATIBILITY.md` §10.3.5 present
  - [ ] `CHANGELOG.md` §[v1.3.0] lists SNAP-* / ROT-* identifiers

### v1.4.0 — companion app integration

<!--
  v1.4.0 bundles a companion Android app into the module ZIP as an
  OPTIONAL asset. This block confirms the integration is complete.

  See:
    README.md §Optional Android App
    docs/ARCHITECTURE.md §8.2
    docs/SECURITY.md v1.4.0 section
-->

- [ ] **Companion APK fetcher and version file present**
  ```bash
  test -f scripts/fetch_app_apk.sh && echo "✅ fetch_app_apk.sh"
  test -f proxy/app-apk.version && echo "✅ app-apk.version"
  grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' proxy/app-apk.version && echo "✅ format valid"
  ```
- [ ] **`/app-debug.apk` route registered in `main.go`**
  ```bash
  grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
  grep -q '/app-debug.apk' proxy/main.go && echo "✅ route"
  grep -q 'application/vnd.android.package-archive' proxy/main.go && echo "✅ mime type"
  ```
- [ ] **WebUI install button is a direct `<a download>` link**
  ```bash
  grep -q 'href="/app-debug.apk"' web/index.html && echo "✅ download link"
  grep -q 'download="DNS-Proxy.apk"' web/index.html && echo "✅ download attr"
  ! grep -q 'initPWABeforeInstallPrompt' web/index.html && echo "✅ old JS handler removed"
  ```
- [ ] **iOS PWA logic removed**
  ```bash
  ! grep -q 'isIOSDevice' web/index.html && echo "✅ isIOSDevice removed"
  ! grep -q 'pwaStepIos' web/index.html && echo "✅ iOS step strings removed"
  ```
- [ ] **Release workflow fetches + stages the APK**
  ```bash
  grep -q 'Fetch companion Android app APK' .github/workflows/release.yml && echo "✅ fetch step"
  grep -q 'Stage APK for module ZIP' .github/workflows/release.yml && echo "✅ stage step"
  grep -q 'dist/DNS-Proxy-v\*.apk' .github/workflows/release.yml && echo "✅ APK attached"
  ```
- [ ] **CI verifies companion app metadata**
  ```bash
  grep -q 'Verify companion app metadata' .github/workflows/ci.yml && echo "✅ CI step"
  ```
- [ ] **After release: verify the APK is attached to the GitHub Release**
  ```bash
  gh release view vX.Y.Z --json assets --jq '.assets[].name' | \
      grep -E 'DNS-Proxy-v|app-debug'
  # Expected: 1 or 2 lines (APK + .sha256)
  ```
- [ ] **Route returns the APK when present**
  ```bash
  curl -I http://127.0.0.1:9090/app-debug.apk | grep -E 'Content-Type|Cache-Control'
  # Expected:
  #   Content-Type: application/vnd.android.package-archive
  #   Cache-Control: public, max-age=3600, immutable
  ```

### v1.4.0 — CodeQL hardening

<!--
  v1.4.0 closes two CodeQL `go/path-injection` alerts in the
  `removeModule` handler. This is not an audit correction — it is
  static-analysis hardening.
-->

- [ ] **`removeModule` uses `filepath.Base()` sanitization**
  ```bash
  grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ sanitization"
  grep -q 'filepath.Join(MODULES_DIR, name)' proxy/main.go && echo "✅ path rebuild"
  ```
- [ ] **CodeQL analysis passes with no `go/path-injection` alerts**
  ```bash
  gh run list --workflow=codeql.yml --limit 5
  # Expected: latest run green
  ```
- [ ] **Path traversal attempts are rejected at runtime**
  ```bash
  curl -b /tmp/cookies.txt -X POST \
      --data-urlencode "path=../../../etc/passwd" \
      http://127.0.0.1:9090/api/remove_module | jq
  # Expected: {"status": "error", "message": "Invalid path"} or similar
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
| **Companion app version** | `X.Y.Z` (from `proxy/app-apk.version`) |
| **DNS engine version** | `2.1.18` (from `proxy/dnscrypt-proxy.version`) |

---

## 📝 What's in this release

<!--
  A short list of what this release contains.
  Not a full changelog — the CHANGELOG.md has that.
  Just a scannable summary for the reviewer.
-->

- Feature:
- Fix:
- Security:
- Documentation:

### v1.4.0 highlights (if applicable)

<!--
  If this release IS v1.4.0, confirm each item below. Otherwise
  leave empty or delete.
-->

- [ ] **Companion Android app** bundled as OPTIONAL asset at
      `web/app-debug.apk`
- [ ] **`scripts/fetch_app_apk.sh`** — new fetcher with cache,
      SHA256, JSON, offline mode
- [ ] **`proxy/app-apk.version`** — Single Source of Truth for the
      companion app version
- [ ] **`GET /app-debug.apk`** route in `main.go` (per-extension
      Cache-Control)
- [ ] **WebUI install button** → direct `<a download>` link (no
      JS-driven flow)
- [ ] **iOS PWA logic removed** (~35 lines)
- [ ] **CodeQL `go/path-injection` fix** in `removeModule` (2 alerts
      closed)
- [ ] **`release.yml`** — fetch + stage APK steps
- [ ] **`ci.yml`** — verify companion app metadata step
- [ ] **`Makefile`** — `fetch-apk` + `check-app-version` targets
- [ ] Version bumped in **6 places** (VERSION, module.prop,
      update.json, manifest, sw, HTML)

### v1.3.0 highlights (if applicable)

<!--
  If this release IS v1.3.0, confirm each item below. Otherwise
  leave empty or delete.
-->

- [ ] **PWA install button (WebUI)** — dynamic per-browser behavior
- [ ] **Live status LED** on the Today counter (green = ON, red = OFF)
- [ ] **DNS auto-start after boot** — critical fix in `service.sh`
      (§[19] `[v1.3.0 FIX]` block)
- [ ] **Server-side rotation refinements** — SNAP-MANIFEST +
      SNAP-MTIME in `main.go:buildBackupInfo`; ROT-MANIFEST +
      ROT-MTIME + ROT-PROTECT in `functions.sh:rotate_backups`;
      parallel application in `status.sh`, `watchdog.sh`,
      `customize.sh`, `action.sh`, `uninstall.sh`
- [ ] Version bumped in **5 places** (VERSION, module.prop, manifest,
      sw, HTML)

### v1.2.0 highlights (if applicable)

<!--
  If this release IS v1.2.0, confirm each item below. Otherwise
  leave empty or delete.
-->

- [ ] **10 defensive layers** in `customize.sh` (multi-source,
      persistent backup, integrity, transactions, root detection,
      SELinux, recovery, migrations, rotation, observability)
- [ ] **Persistent backup directory** at
      `/sdcard/dnscrypt-webui-backup/`
- [ ] **7-field `runtime_info.backups`** object (BAK-1)
- [ ] **`createAutoBackup` + `backupMu`** — pre-critical backups
      on 5 destructive endpoints (BAK-2)
- [ ] **`cleanupOldTransactions`** at startup (BAK-3)
- [ ] **`checkPendingNotifications`** at startup (BAK-4)
- [ ] **FIX-1** — recovery-mode snapshot-and-reapply
- [ ] **FIX-2** — Service Worker update-banner
- [ ] **Watchdog token (WD-TOKEN)** — `X-Watchdog-Token` on
      `POST /api/ensure_running_service`
- [ ] **Bilingual WebUI** — English default + Arabic toggle
- [ ] **New CLI tools** — `action.sh --backup`,
      `status.sh --diagnose`
- [ ] **Breaking change** — `POST /api/append_denylist` requires
      `content`
- [ ] **42-scenario CI matrix** — `upgrade-test.yml`
- [ ] Version bumped in 5 places (VERSION, module.prop, manifest,
      sw, HTML)

### v1.1.0 highlights (if applicable)

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

- [ ] **`release.yml` triggers**: GitHub Actions publishes the release
- [ ] **v1.4.0**: Verify the pipeline fetches + stages the APK before
      packaging:
  ```bash
  gh run view --workflow=release.yml --log | grep -E 'Fetch companion|Stage APK'
  ```
- [ ] **v1.4.0**: Verify the release has **8 artifacts** attached:
  ```bash
  gh release view vX.Y.Z --json assets --jq '.assets | length'
  # Expected: 8 (module ZIP + sha256 + 4 binaries + APK + APK.sha256)
  ```
- [ ] **v1.3.0**: Verify the release has **6 artifacts** (no APK)
- [ ] **v1.2.0**: Verify the release has **6 artifacts** (module ZIP + sha256 + 4 binaries)
- [ ] **Back-merge**: sync `develop` with `main`
  - For `release/*`: **automatic** via `release.yml` (see ADR-0003)
  - For `hotfix/*`: **manual** — run `make sync`

- [ ] **v1.2.0**: Verify the backup layer survives the published release:
  ```bash
  gh release view vX.Y.Z
  # Download and install the ZIP on a test device
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" | head -30
  ```
- [ ] **v1.3.0**: Verify the DNS auto-start-after-boot fix on a test device
      (reboot + check log for `[v1.3.0 FIX]`)
- [ ] **v1.3.0**: Verify the SNAP-* / ROT-* semantics on a test device
      (see `docs/COMPATIBILITY.md` §10.3.5)
- [ ] **v1.4.0**: Verify the companion APK is downloadable via the
      WebUI install button on a fresh device

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

## 🔙 Rollback Plan

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

### v1.2.0 — data-preservation safety net

<!--
  v1.2.0 ships with the 10 defensive layers. Even if a rollback
  is needed, the user's 5 config files are preserved in the
  persistent backup directory.
-->

- [ ] Confirmed the persistent backup directory will survive
      rollback:
  ```bash
  su -c "ls -la /sdcard/dnscrypt-webui-backup/"
  # Expected: current/, <ts>-<version>/…, .last_stable, …
  ```
- [ ] Confirmed that rolling back to a previous version does not
      delete the backup directory (it is preserved by design —
      see `docs/BACKUP.md` §5.6)

### v1.4.0 — companion app rollback

<!--
  The companion APK is an OPTIONAL asset. Rolling back the module
  does NOT affect a user's separately-installed companion app
  (it lives in the sister repository).
-->

- [ ] Confirmed that rolling back the module does NOT uninstall
      the companion app on users' devices
- [ ] Confirmed that a user who installed the companion app can
      still use it after the module rollback (it connects to
      `127.0.0.1:9090` like any browser)

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
- [ ] **`zipUrl` in `update.json`**: matches the tag name (e.g. `v1.4.0`)
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

### v1.2.0-specific (if applicable)

- [ ] **10 defensive layers** are present in `customize.sh` (see pre-flight)
- [ ] **Backup helpers** are present in `functions.sh` (see pre-flight)
- [ ] **`runtime_info.backups`** returns exactly 7 fields (see pre-flight)
- [ ] **`backupMu`** present in `main.go`:
  ```bash
  grep -q 'backupMu' proxy/main.go && echo "✅"
  ```
- [ ] **Watchdog token** file exists with mode `0600` (see pre-flight)
- [ ] **FIX-1** present in `customize.sh`:
  ```bash
  grep -q 'RECOVERY_SNAPSHOT_DIR' proxy/customize.sh && echo "✅ FIX-1 snapshot dir"
  grep -q 'Re-applying recovery snapshot' proxy/customize.sh && echo "✅ FIX-1 re-apply block"
  ```
- [ ] **FIX-2** present in both HTML pages:
  ```bash
  grep -q 'swRegistration.waiting' web/index.html && echo "✅ index.html"
  grep -q 'swRegistration.waiting' web/dashboard.html && echo "✅ dashboard.html"
  ```
- [ ] **Bilingual WebUI** — toggle present in all three pages (see pre-flight)
- [ ] **Breaking change** documented in `CHANGELOG.md` and
      `docs/API.md` §6.2.7
- [ ] **`upgrade-test.yml`** is green for the release commit
- [ ] **`make check-backup`** passes locally
- [ ] **Data-preservation docs updated**: `docs/BACKUP.md` and
      `docs/EMERGENCY.md` reflect the shipped behavior

### v1.3.0-specific (if applicable)

- [ ] **DNS auto-start-after-boot fix** in `service.sh` §[19]:
  ```bash
  grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅"
  ```
- [ ] **Live status LED markup** in `index.html`:
  ```bash
  grep -q 'led-on' web/index.html && echo "✅"
  ```
- [ ] **PWA install button** present in `index.html`
- [ ] **No regression** in the DNS engine's normal restart cycle
      (i.e. the watchdog still works for crash recovery during
      runtime, not just at boot)
- [ ] **SNAP-MANIFEST** present in `main.go:buildBackupInfo`:
  ```bash
  grep -A15 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
  ```
- [ ] **SNAP-MTIME** present in `main.go:buildBackupInfo`:
  ```bash
  grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
  ```
- [ ] **ROT-MANIFEST + ROT-MTIME + ROT-PROTECT** present in
      `functions.sh:rotate_backups`:
  ```bash
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
  grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"
  ```
- [ ] **Parallel application** in the other 5 shell scripts:
  ```bash
  grep -q '_list_snapshots' proxy/status.sh && echo "✅ status.sh"
  grep -q 'manifest.json' proxy/watchdog.sh && echo "✅ watchdog.sh"
  grep -q 'manifest.json' proxy/customize.sh && echo "✅ customize.sh"
  grep -q '_inline_list_snapshots' proxy/action.sh && echo "✅ action.sh"
  grep -q '_uninstall_list_snapshots' proxy/uninstall.sh && echo "✅ uninstall.sh"
  ```
- [ ] **Rotation docs updated**:
  - [ ] `docs/ARCHITECTURE.md` §4.13.2 present
  - [ ] `docs/BACKUP.md` §6.5 describes ROT-MTIME (not name sort)
  - [ ] `docs/COMPATIBILITY.md` §10.3.5 present
  - [ ] `CHANGELOG.md` §[v1.3.0] lists SNAP-* / ROT-* identifiers

### v1.4.0-specific (if applicable)

- [ ] **`scripts/fetch_app_apk.sh`** present and executable
- [ ] **`proxy/app-apk.version`** present with valid `X.Y.Z` format
- [ ] **`APK_FILE` constant** in `main.go`:
  ```bash
  grep -q 'APK_FILE' proxy/main.go && echo "✅"
  ```
- [ ] **`/app-debug.apk` route** in `main.go` with correct mime type
- [ ] **WebUI install button** is a direct `<a download>` link
      (no `initPWABeforeInstallPrompt`):
  ```bash
  grep -q 'href="/app-debug.apk"' web/index.html && echo "✅"
  ! grep -q 'initPWABeforeInstallPrompt' web/index.html && echo "✅"
  ```
- [ ] **iOS PWA logic removed**:
  ```bash
  ! grep -q 'isIOSDevice' web/index.html && echo "✅"
  ```
- [ ] **CodeQL fix** in `removeModule` uses `filepath.Base()`:
  ```bash
  grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅"
  ```
- [ ] **CodeQL analysis** is green (no `go/path-injection` alerts)
- [ ] **`release.yml`** has both Fetch + Stage APK steps
- [ ] **`ci.yml`** has the Verify companion app metadata step
- [ ] **`Makefile`** has `fetch-apk` and `check-app-version` targets
- [ ] **Release artifacts**: 8 files attached (including the APK)

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

     ┌────────────────────────────────────────────────┐
     │  🚀  Release PR — Different rules apply                  │
     ├────────────────────────────────────────────────┤
     │  1. This PR targets `main` — that is correct here.       │
     │  2. The tag does NOT exist yet — it is created after     │
     │     the merge (or already pushed via release.sh /        │
     │     release-patch.sh).                                   │
     │  3. `release.yml` will publish the release.              │
     │  4. `develop` must be synced after the release:          │
     │       • release/* → automatic via release.yml            │
     │       • hotfix/*  → manual (make sync)                   │
     └────────────────────────────────────────────────┘

     📖 Full details:
       docs/BRANCHING.md §4.4       (Release Workflow)
       docs/RELEASE_PROCESS.md §5   (PR Steps)
       docs/adr/0005                (Why a separate template)
       docs/adr/0006                (Why release-patch.sh)
       docs/BACKUP.md               (Backup system — v1.2.0)
       docs/EMERGENCY.md            (Recovery — v1.2.0)
       docs/ARCHITECTURE.md §4.13   (v1.3.0 rotation semantics — authoritative)

     🎯 Quick verification before opening the PR:

       # 7-way version consistency (v1.4.0)
       V=$(cat VERSION)
       grep -q "^version=$V" module.prop && echo "✅ module.prop"
       grep -q "\"version\": \"${V#v}\"" web/manifest.json && echo "✅ manifest.json"
       grep -q "CACHE_VERSION = '$V'" web/sw.js && echo "✅ sw.js"
       grep -q "var VERSION = '$V'" web/index.html && echo "✅ index.html"
       grep -q "var VERSION = '$V'" web/dashboard.html && echo "✅ dashboard.html"
       test -f proxy/app-apk.version && echo "✅ app-apk.version present"

       # CHANGELOG section
       grep -q "^## \[${V#v}\]" CHANGELOG.md && echo "✅ CHANGELOG section"

       # update.json fields
       jq -e ".version == \"$V\"" update.json >/dev/null && echo "✅ update.json version"

     🎯 v1.2.0 extra checks (if releasing v1.2.0 or later):

       grep -q 'CANDIDATE_SOURCES' proxy/customize.sh && echo "✅ Layer 1"
       grep -q 'PERSISTENT_BACKUP' proxy/customize.sh && echo "✅ Layer 2"
       grep -q 'begin_transaction' proxy/customize.sh && echo "✅ Layer 4"
       grep -q 'copy_with_context' proxy/customize.sh && echo "✅ Layer 6"
       grep -q 'RECOVERY_TRIGGER' proxy/customize.sh && echo "✅ Layer 7"
       grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2"
       grep -q 'func buildBackupInfo' proxy/main.go && echo "✅ BAK-1"
       grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ WD-TOKEN"
       grep -q 'swRegistration.waiting' web/index.html && echo "✅ FIX-2"
       make check-backup && echo "✅ backup shell validation"

     🎯 v1.3.0 extra checks (if releasing v1.3.0 or later):

       grep -q 'v1.3.0 FIX' proxy/service.sh && echo "✅ DNS auto-start"
       grep -q 'led-on' web/index.html && echo "✅ LED markup"
       grep -A15 'func buildBackupInfo' proxy/main.go | grep -q '.manifest.json' && echo "✅ SNAP-MANIFEST"
       grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'ModTime()' && echo "✅ SNAP-MTIME"
       grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '.manifest.json' && echo "✅ ROT-MANIFEST"
       grep -A40 'rotate_backups()' proxy/functions.sh | grep -q 'sort -rn -k1,1' && echo "✅ ROT-MTIME"
       grep -A40 'rotate_backups()' proxy/functions.sh | grep -q '_protected' && echo "✅ ROT-PROTECT"

     🎯 v1.4.0 extra checks (if releasing v1.4.0 or later):

       test -f scripts/fetch_app_apk.sh && echo "✅ APK fetcher"
       test -f proxy/app-apk.version && echo "✅ APK version"
       grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE"
       grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ CodeQL fix"
       ! grep -q 'initPWABeforeInstallPrompt' web/index.html && echo "✅ iOS/JS removed"
       make check-app-version && echo "✅ companion APK version check"

     Current version line: v1.4.0
     Last updated: 2026-10-08
     ============================================================ -->
