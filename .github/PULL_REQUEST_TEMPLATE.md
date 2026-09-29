<!-- ============================================================
     DNSCrypt Smart Filter – Pull Request Template
     Version: v1.2.0 (Global Edition)
     Author: gasciljh
     Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
     ============================================================
     This template appears automatically when a new PR is opened.
     Fill every section — delete what does not apply.
     Reference: docs/CONTRIBUTING.md#6 and docs/BRANCHING.md
     ============================================================
     v1.2.0 additions:
       • New v1.2.0 grep verifications for the data-preservation
         release (10 defensive layers, BAK-1..BAK-4, FIX-1/FIX-2,
         WD-TOKEN).
       • New "Data-preservation checklist" section — mandatory for
         any PR that touches customize.sh, functions.sh,
         service.sh, status.sh, uninstall.sh, or main.go backup
         helpers.
       • New "Global edition (EN + AR)" checklist item — any PR that
         adds a user-facing string must supply both `en` and `ar`
         entries.
       • New "Backup shell verification" grep block.
       • New "runtime_info.backups" verification.
       • Audit Corrections Registry below remains at #33 (the v1.0.0
         record). v1.1.0 and v1.2.0 do not add new audit
         corrections.
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
> **See:** [`docs/BRANCHING.md`](../docs/BRANCHING.md) §4.4 and
> [`docs/RELEASE_PROCESS.md`](../docs/RELEASE_PROCESS.md) §5.

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

📖 Full details: [`docs/BRANCHING.md`](../docs/BRANCHING.md) §5.1.

---

## 📝 Description

<!--
  Brief and clear description of what this PR does.
  Explain "what" and "why" — not just "how".

  Good example:
    "Fixes versionCode inconsistency between module.prop and update.json.
     Before: 3030801 (incorrect hotfix calculation).
     After:  1000000 (major*1M + minor*10K + patch*100 + hotfix).
     Impact: Magisk Manager detects updates correctly."

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
  See docs/BRANCHING.md §2 for which branch to use.
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

---

## 🔍 Audit Correction (for security/architecture fixes)

<!--
  Fill this section only if the PR fixes an architectural or security issue.
  See docs/SECURITY.md and docs/ARCHITECTURE.md.

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

  ⚠️ v1.1.0 does NOT add new audit corrections (polish release).
  ⚠️ v1.2.0 does NOT add new audit corrections (data-preservation
     release). Its additions (BAK-1..BAK-4, FIX-1, FIX-2, WD-TOKEN)
     are runtime additions + correctness fixes, documented in
     docs/SECURITY.md §5.31, §5.32, §5.33 — not audit corrections.

  The registry above remains the authoritative record through
  v1.0.0. If your PR fixes a new security/architecture issue, this
  PR should be the FIRST to add a new entry (starting at #34).

  Example:
    Number: #34
    Title: <fix title>
    Reference: docs/SECURITY.md
-->

- **Audit Correction number**: #
- **Title**:
- **Documentation reference**: `docs/SECURITY.md`

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

### 🆕 Core fix verifications (v1.0.0)

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
  grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅"
  ```
- [ ] **NEW-4 — /readyz localhost-only**
  ```bash
  grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅"
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
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅"
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
  # Verify main() no longer uses the hardcoded 80MB call
  ! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ no hardcoded limit"
  ```

- [ ] **MEM-2 — Extended shellQuote (main.go)**
  ```bash
  grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
  grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
  grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
  ```

- [ ] **MEM-3 — MONITORING_UI_PORT used in metrics handler (main.go)**
  ```bash
  grep -q 'MONITORING_UI_PORT = "8080"' proxy/main.go && echo "✅ const"
  grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ used"
  ! grep -q '"http://127.0.0.1:8080/api/metrics"' proxy/main.go && echo "✅ no hardcoded URL"
  ```

- [ ] **v1.1.0 — runtime_info new fields (main.go + web/*.html)**
  ```bash
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"memory_limit_mb"' && echo "✅ backend memory_limit_mb"
  grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"profile_key"' && echo "✅ backend profile_key"
  grep -q "riMemoryLimit" web/index.html && echo "✅ index.html"
  grep -q "riMemoryLimit" web/dashboard.html && echo "✅ dashboard.html"
  ```

### 🆕 v1.2.0 additions — Data Preservation

<!--
  Run these if the PR touches:
    • customize.sh, functions.sh, service.sh, status.sh, uninstall.sh,
      action.sh, watchdog.sh
    • main.go (backup helpers only)
    • docs/BACKUP.md, docs/EMERGENCY.md

  v1.2.0 introduced the 10 defensive layers. Any change to them must
  be verified by this block.
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
  grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ in_flight_txn"
  grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'orphan_txn' && echo "✅ orphan_txn"
  # Runtime check (if service is running):
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

- [ ] **v1.2.0 — FIX-1 (recovery-mode reorder)**
  ```bash
  grep -A5 'RECOVERY_MODE" = "1"' proxy/customize.sh | \
    grep -qE 'webui.conf|dnscrypt-proxy.toml' && echo "✅ FIX-1 present"
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
  grep -q 'dnscrypt-webui-backup' .gitignore && echo "✅ backup patterns"
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

**If the change is in shell scripts:**
- [ ] Confirmed no new `shellcheck` warnings
- [ ] Tested on a real device (if possible)
- [ ] **v1.2.0**: Ran `make check-backup`

**If the change is in the firewall:**
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
  grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ writes!" || echo "✅ read-only"
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

**If the change is in `rebuildBlocklist` or `updateProfile` (RACE-1):**
- [ ] Confirmed `rebuildMu.Lock()` present + `defer rebuildMu.Unlock()`
- [ ] Tested concurrency manually (update + save simultaneously)
- [ ] Confirmed no deadlock (30 s timeout is enough)

**If the change is in `buildRuntimeInfo` or `runtime_info` (PORT-2 + MEM-1 + BAK-1):**
- [ ] Confirmed `webui_port` + `dashboard_port` present in JSON response:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
  # Expected: contains "webui_port" and "dashboard_port"
  ```
- [ ] Confirmed `memory_limit_mb` + `profile_key` present:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb, .profile_key'
  # Expected: a number, and a profile key string
  ```
- [ ] **v1.2.0**: Confirmed `backups` object with 7 fields:
  ```bash
  curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys | length'
  # Expected: 7
  ```
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
  # 1. Take a manual snapshot
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"

  # 2. Verify the snapshot was created
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'"
  # Expected: >= 1

  # 3. Simulate damage — change the profile
  su -c "echo 'light' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

  # 4. Restore from the newest snapshot
  SNAP=$(su -c "ls -1dt /sdcard/dnscrypt-webui-backup/*/ | \
         grep -vE '/(current|txn-|orphan-txn-)' | head -1" | tr -d '\r')
  su -c "cp $SNAP/selected_profile.txt /data/adb/modules/dnscrypt-proxy-webui/proxy/"
  su -c "restorecon /data/adb/modules/dnscrypt-proxy-webui/proxy/"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

  # 5. Verify the profile was restored
  su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
  # Expected: original profile
  ```
- [ ] Verified the persistent backup directory survives uninstall:
  ```bash
  su -c "ls -la /sdcard/dnscrypt-webui-backup/"
  ```
- [ ] Verified `status.sh --diagnose` produces a complete report
- [ ] Verified the watchdog token file exists with mode `0600`:
  ```bash
  su -c "stat -c '%a' /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
  # Expected: 600
  ```

**If the change is in the recovery mode (v1.2.0 — Layer 7):**
- [ ] Tested recovery trigger on a test device:
  ```bash
  # 1. Note the original profile
  ORIG=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")

  # 2. Change the profile
  su -c "echo 'light' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

  # 3. Trigger recovery
  su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
  su -c "reboot"

  # 4. After boot (~60s), verify
  sleep 60
  NEW=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt")
  [ "$NEW" = "$ORIG" ] && echo "✅ Recovery restored"
  ```
- [ ] Confirmed the trigger file is consumed after a successful restore
- [ ] Verified the FIX-1 reorder (`webui.conf` and
      `dnscrypt-proxy.toml` are not overwritten by the ZIP extraction)

---

## 🔒 Security Checklist

<!--
  Fill this section if the PR relates to security.
  See docs/SECURITY.md for full standards.
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
- [ ] **v1.2.0**: If adding an endpoint that needs watchdog auth,
      used `X-Watchdog-Token` + `verifyWatchdogToken()`

### Input Validation

- [ ] If adding a port read, used `readConfPort` (with range check 1–65535)
- [ ] If using a dynamic shell command, used `shellQuote()`
- [ ] If adding a new health endpoint, considered `isLocalRequest` (local-only)

### Firewall

- [ ] Did not pollute `OUTPUT` / `INPUT` / `FORWARD` with dynamic rules
- [ ] Used `DNSCRYPT_OUT` / `DNSCRYPT_OUT6` for the firewall
- [ ] Confirmed `--wait` on every `iptables` / `ip6tables` invocation
- [ ] Tested `_legacy_cleanup_*` after upgrade from an older version

### Concurrency (RACE-1 + BAK-2)

- [ ] Any operation modifying `ALLOWLIST` / `DENYLIST` / `BLOCKLIST` calls `rebuildBlocklist`
- [ ] `rebuildBlocklist` is protected by `rebuildMu.Lock()` + `defer Unlock()`
- [ ] No nested deadlock (never calls a function that locks the same mutex)
- [ ] **v1.2.0**: Any new destructive operation on user data calls
      `createAutoBackup(reason)` first
- [ ] **v1.2.0**: `backupMu` is used only via `createAutoBackup` —
      do NOT add a second mutex
- [ ] **v1.2.0**: `backupMu` is held for at most
      `AUTO_BACKUP_TIMEOUT = 15 s`

### Memory (v1.1.0)

- [ ] If adding a new profile, updated `MEMORY_LIMIT_*` in main.go
- [ ] If adding a new profile, updated the inline fallback in all four shell scripts
  (`service.sh`, `action.sh`, `status.sh`, `watchdog.sh`)
- [ ] If adding a new profile, updated `webui.conf` template in `customize.sh`
- [ ] If adding a new profile, updated `web/index.html` `<select id="profileSelect">`

### Data Preservation (v1.2.0)

- [ ] If adding a new preserved file:
  - [ ] Updated the `USER_FILES` list in **all 5** scripts:
        `customize.sh`, `functions.sh`, `service.sh`, `status.sh`,
        `uninstall.sh`
  - [ ] Updated the "5 Preserved Files" table in `README.md`
  - [ ] Updated `docs/BACKUP.md` §2
- [ ] If changing the rotation policy:
  - [ ] Updated the constant in **all 4** scripts:
        `customize.sh`, `functions.sh`, `service.sh`, `action.sh`
  - [ ] Updated `docs/BACKUP.md` §6
- [ ] If changing the `runtime_info.backups` schema:
  - [ ] Updated `buildBackupInfo()` in `main.go`
  - [ ] Kept `status.sh --json` in sync
  - [ ] Updated `docs/API.md` §6.1.7
- [ ] If adding a config migration:
  - [ ] Added it to `migrate_config()` in `customize.sh`
  - [ ] Updated `docs/UPGRADE.md`
- [ ] Confirmed the 10 defensive layers are still orthogonal to the
      firewall (see `docs/COMPATIBILITY.md` §6.6)

### For security fixes

- [ ] Updated `docs/SECURITY.md` (Attack Vectors section + §5.X)
- [ ] Updated `docs/ARCHITECTURE.md` (Trade-offs)
- [ ] Updated `docs/TROUBLESHOOTING.md` (Diagnostics)
- [ ] Added the Audit Correction #XX in the commit footer
- [ ] Added HTML anchor `<a name="XXX"></a>` (if a new section was created)
- [ ] Updated the Audit Corrections Registry in `docs/SECURITY.md`

### Global Edition (v1.2.0 — EN + AR)

- [ ] Any new user-facing string in the WebUI is present in **both**
      `translations.en` and `translations.ar`
- [ ] The default language on first load is still **English**
- [ ] The language preference is stored only in
      `localStorage['dnscrypt-lang']` — never sent to the server
- [ ] RTL layout verified (Chrome 88+, Firefox 92+, Samsung Internet 16+)
- [ ] No API endpoint accepts or returns a language identifier

---

## 📖 Documentation

<!--
  Do not forget to update documentation — it is part of PR quality.
  See docs/CONTRIBUTING.md#9.
-->

- [ ] Updated `CHANGELOG.md` (auto-generated at release, but note it if relevant)
- [ ] Updated `README.md` (if a new user-facing feature)
- [ ] Updated `docs/API.md` (if an API change)
- [ ] Updated `docs/ARCHITECTURE.md` (if an architectural change)
- [ ] Updated `docs/SECURITY.md` (if a security fix)
- [ ] Updated `docs/TROUBLESHOOTING.md` (if a common issue)
- [ ] Updated `docs/FAQ.md` (if a common question)
- [ ] Updated `docs/BRANCHING.md` or `docs/RELEASE_PROCESS.md` (if a workflow change)
- [ ] Added or updated an ADR in `docs/adr/` (if a non-trivial decision)
- [ ] If reversing an ADR, created a new one that supersedes it (never edit the old)
- [ ] Added / updated code comments (Go docstrings, shell comments)
- [ ] If a new field was added to `runtime_info`, updated both
      `web/index.html` and `web/dashboard.html` translation tables (en + ar)
- [ ] **v1.2.0**: If a backup-layer change, updated `docs/BACKUP.md`
      **and** `docs/EMERGENCY.md`
- [ ] **v1.2.0**: If a language-toggle change, updated
      `docs/ARCHITECTURE.md` §6.7 and `docs/API.md` §10.8

---

## ✅ Final Checklist

<!--
  Ensure every item is complete before requesting review.
-->

### Branch policy

- [ ] PR target is `develop` (or `main` **only** for `release/*` / `hotfix/*`)
- [ ] If targeting `main`, using the **release template** (`?template=release.md`)
- [ ] No direct push was made to `main` or `develop`
- [ ] Read [`docs/BRANCHING.md`](../docs/BRANCHING.md) if unsure

### General commitments

- [ ] Followed [Conventional Commits](https://www.conventionalcommits.org/) on every commit
  - Examples: `feat(webui): add dark mode`, `fix(proxy): resolve race condition`
  - For security fixes: `security(iptables): implement Custom Chains`
  - For ADRs: `docs(adr): add ADR-0007 for webhook notifications`
  - For v1.2.0 data preservation: `feat(backup): add pre-critical auto-backup before destructive ops`
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

### Documentation

- [ ] Reviewed every item in the "📖 Documentation" section above
- [ ] No broken links in the updated documentation
- [ ] Code examples in the documentation are correct (actually tested)

### Cleanliness

- [ ] Removed all temporary files (`*.tmp`, `*.bak`, `scratch.*`)
- [ ] No binary files uploaded without justification
- [ ] No `.DS_Store` or `Thumbs.db` files
- [ ] Reviewed `git diff` before pushing (no unintended changes)
- [ ] Confirmed no leftover `*.tmp_*` from `atomicWriteFile`
- [ ] **v1.2.0**: No leftover `txn-*` / `orphan-txn-*` in the
      committed backup directory (those belong to runtime)

---

## 🖼️ Screenshots / Recordings

<!--
  If the PR relates to the UI, attach images or GIFs.
  For bug fixes: attach "before" and "after" images if possible.
  For logic changes: no images needed.

  v1.2.0: If the change touches the bilingual UI, attach BOTH
  English and Arabic screenshots.
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
  Example:
    - @gasciljh: review the Custom Chains logic in functions.sh
    - @reviewer: check the queries in main.go

  v1.2.0: If the change touches the backup layer, consider requesting
  a review from a Data Guardian badge holder (see docs/HALL_OF_FAME.md).
-->



---

<!-- ============================================================
     ⚠️ Final reminder:

     ┌────────────────────────────────────────────────┐
     │  🎯 Branch policy reminder                              │
     ├────────────────────────────────────────────────┤
     │  feature/*, fix/*, docs/*, chore/*, refactor/*, test/*  │
     │      → PR base: develop                                │
     │      → Template: this one (default)                    │
     │                                                         │
     │  release/*, hotfix/*                                    │
     │      → PR base: main                                   │
     │      → Template: ?template=release.md                  │
     │                                                         │
     │  Never open a PR directly against main for features.    │
     │  Read docs/BRANCHING.md for the full explanation.       │
     └────────────────────────────────────────────────┘

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

     🎯 v1.1.0 extra checks (if main.go changed):

       grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"
       grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2"
       grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

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

     📖 Documentation references:

       docs/BRANCHING.md        - Branch strategy
       docs/RELEASE_PROCESS.md  - Release process
       docs/adr/README.md       - Architecture Decision Records
       docs/CONTRIBUTING.md     - Contribution guide
       docs/SECURITY.md         - Security policy (§5.31, §5.32, §5.33)
       docs/BACKUP.md           - Backup system reference (v1.2.0)
       docs/EMERGENCY.md        - Emergency recovery (v1.2.0)

     Current version: v1.2.0
     Last updated: 2026-09-29

     🎉 Thanks for your contribution! Every PR improves the project.
     ============================================================ -->