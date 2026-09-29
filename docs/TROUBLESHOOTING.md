# Troubleshooting Guide — DNSCrypt Smart Filter

> Comprehensive diagnostic guide: from symptoms to solutions.

**Version**: v1.2.0
**Last updated**: 2026-09-29
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.2.0 changes**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • Added §4.13 (Backup directory missing) — covers the
>     v1.2.0 persistent backup directory
>     (`/sdcard/dnscrypt-webui-backup/`).
>   • Added §4.14 (Backup state issues) — how to read and
>     troubleshoot the 7-field `runtime_info.backups` object.
>   • Added §5.15 (Watchdog token issues) — the v1.2.0
>     `X-Watchdog-Token` auth on `/api/ensure_running_service`.
>   • Added §7.8 (append_denylist requires content) — BUG-A fix.
>   • Added §12.8 (Backup layer fails after upgrade).
>   • Added §12.9 (Recovery mode correctness — FIX-1).
>     **Corrected in this revision**: the actual FIX-1 mechanism
>     is **snapshot-and-reapply** (using
>     `$MODPATH/.recovery_snapshot/` + the new `§[9b2]` block),
>     NOT "reorder + exclude". The old description was incorrect
>     and has been fully replaced. See §12.9 for the verified
>     behavior and the corrected verify commands.
>   • Added §13.4 (Orphan-txn preserved on uninstall).
>   • Added §13.5 (Preserved backup directory after uninstall).
>     **Corrected in this revision**: the manual removal command
>     now uses the correct path
>     `/sdcard/dnscrypt-webui-backup` (previously written as
>     `/sdcrypt-webui-backup`).
>   • Added §14.5 (Recovery mode) — full procedure + verify.
>   • Added §15.14 (Backup diagnostics helper — v1.2.0).
>   • Added §15.15 (Recovery mode test helper — v1.2.0).
>   • Updated §16.2 (Issue template) with backup fields.
>   • Updated §12.7 (Settings lost after upgrade) — v1.2.0
>     supersedes the v1.1.0 mechanism with the 10 defensive
>     layers.
>   • All `v1.1.0` references in examples updated to `v1.2.0`.
>   • No structural changes to the diagnostic tree — all
>     v1.0.0 and v1.1.0 sections remain valid.
>   • **Global edition — English default + Arabic toggle**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.
>   • **Encoding correction (this revision)**: fixed mojibake in
>     section markers, arrows, checkmarks, warnings, and box
>     drawing characters. All symbols now render as proper UTF-8.

> **v1.2.0 (Global Edition) — Corrections in this revision**:
>   • 🔧 **N-4 (`$MODPATH` portability in §15.15)** — The
>     `recovery-mode-test.sh` helper previously relied on
>     `$MODPATH` inside the echoed "next steps" strings. When the
>     user copied those strings to a fresh shell (or read the
>     script source directly), `$MODPATH` was undefined and the
>     suggested commands became broken. The echoed commands now
>     use the **literal path**
>     (`/data/adb/modules/dnscrypt-proxy-webui`) instead. This
>     makes the strings self-contained and copy-paste-safe,
>     independent of any shell variable.
>   • 🔧 **Path typo (`/sdcrypt-webui-backup`)** — Verified that
>     every reference to the persistent backup directory uses the
>     correct path `/sdcard/dnscrypt-webui-backup`. The earlier
>     typo (missing `ard/`) is gone from this file.

> **📖 Related documents**:
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - API reference → [`docs/API.md`](API.md)

---

## Table of Contents

1. [Diagnostic Tree](#1-diagnostic-tree)
2. [Collecting Information](#2-collecting-information)
3. [Installation Issues](#3-installation-issues)
4. [WebUI Access Issues](#4-webui-access-issues)
5. [Authentication Issues](#5-authentication-issues)
6. [DNS Issues](#6-dns-issues)
7. [Blocklist Issues](#7-blocklist-issues)
8. [Performance and Battery Issues](#8-performance-and-battery-issues)
9. [Network Issues](#9-network-issues)
10. [Log Issues](#10-log-issues)
11. [Firewall Issues](#11-firewall-issues)
12. [Upgrade and CI Issues](#12-upgrade-and-ci-issues)
13. [Uninstall Issues](#13-uninstall-issues)
14. [Emergency Situations](#14-emergency-situations)
15. [Helper Tools](#15-helper-tools)
16. [When All Else Fails](#16-when-all-else-fails)

---

## 1. Diagnostic Tree

### 1.1 Start Here

```text
Problem?
│
├── Cannot install the module
│   └── § 3 (Installation)
│
├── Cannot access the WebUI
│   └── § 4 (Access)
│   ├── § 4.6 (Dashboard shows no metrics)
│   ├── § 4.7 (Port 8080 conflict)
│   ├── § 4.8 (Dashboard shows no data) ← Fix #1
│   ├── § 4.9 (/readyz rejected from LAN) ← NEW-4
│   ├── § 4.10 (Invalid port ignored) ← NEW-3
│   ├── § 4.11 (Broken Dashboard links) ← PORT-2
│   ├── § 4.12 (Memory limit issues) ← MEM-1 (v1.1.0)
│   ├── § 4.13 (Backup directory missing) ← v1.2.0
│   └── § 4.14 (Backup state issues) ← v1.2.0
│
├── Cannot log in
│   └── § 5 (Authentication)
│   ├── § 5.8 (IPv6 rate limit)
│   ├── § 5.9 (Credentials from wrong section)
│   ├── § 5.10 (404 for unknown action) ← Fix #12
│   ├── § 5.11 (Login GET rejected) ← NEW-1
│   ├── § 5.12 (Basic Auth locked) ← Fix #8
│   ├── § 5.13 (Credentials change delay) ← NEW-6
│   ├── § 5.14 (Profile key problems) ← MEM-1 (v1.1.0)
│   └── § 5.15 (Watchdog token issues) ← v1.2.0
│
├── DNS not working at all
│   └── § 6 (DNS)
│   └── § 6.9 (Watchdog does not restart)
│   └── § 6.10 (GC thrashing symptoms) ← MEM-1 (v1.1.0)
│
├── Some sites are not blocked
│   └── § 7 (Blocklist)
│   ├── § 7.7 (Blocklist inconsistent on concurrent edit) ← RACE-1
│   └── § 7.8 (append_denylist requires content) ← BUG-A (v1.2.0)
│
├── Battery drains quickly
│   └── § 8 (Performance)
│
├── Hotspot / Tethering not working
│   └── § 9 (Network)
│
├── Orphans in iptables / Custom Chain issues
│   └── § 11 (Firewall)
│   └── § 11.10 (Shell injection in MODDIR) ← NEW-5
│
├── CI issues on Linux
│   └── § 12.6 (CI Go tests fail) ← Fix #2
│
├── Settings lost after upgrade
│   └── § 12.7 (Upgrade loses settings) ← Fix #3 (superseded by v1.2.0)
│   └── § 12.8 (Backup layer fails) ← v1.2.0
│   └── § 12.9 (Recovery mode correctness) ← FIX-1 (v1.2.0)
│
├── Backup/orphan issues after uninstall
│   └── § 13.4 (Orphan-txn preserved) ← v1.2.0
│   └── § 13.5 (Preserved backup directory) ← v1.2.0
│
├── Module cannot boot / data corrupted
│   └── § 14.5 (Recovery mode) ← v1.2.0
│
└── Other issues
    └── § 2 (Collecting information) → then the relevant loop
```

### 1.2 Quick Commands

```bash
# Full status
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"

# JSON
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

# One-line
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"

# Firewall check (IPv4)
su -c "iptables -t nat -L OUTPUT -n --line-numbers"
su -c "iptables -t nat -L DNSCRYPT_OUT -n --line-numbers"

# Firewall check (IPv6)
su -c "ip6tables -t nat -L OUTPUT -n --line-numbers"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n --line-numbers"

# Port check
su -c "ss -tulnp | grep -E '9090|9091|5354|8080'"

# STATUS_FILE (user intent)
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"

# runtime_info (PORT-2 + MEM-1 + BAK-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port, profile_key, memory_limit_mb}'"

# Memory state (v1.1.0)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'"

# Backup state (v1.2.0 — 7 fields)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"

# Backup directory listing (v1.2.0)
su -c "ls -la /sdcard/dnscrypt-webui-backup/"

# Full diagnostic report (v1.2.0 — Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

---

## 2. Collecting Information

### 2.1 Before Asking

Collect this information:

```bash
# 1. System info
echo "=== System ==="
getprop ro.build.version.release
getprop ro.build.version.sdk
getprop ro.product.model
uname -r

# 2. Root info
echo ""
echo "=== Root ==="
which magisk 2>/dev/null && magisk -V
which ksud 2>/dev/null && ksud -V

# 3. Module status
echo ""
echo "=== Module ==="
cat /data/adb/modules/dnscrypt-proxy-webui/module.prop

# 4. Full status
echo ""
echo "=== Status ==="
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json

# 5. Firewall state
echo ""
echo "=== Firewall ==="
iptables -t nat -L OUTPUT -n 2>/dev/null | head -20
iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -20
ip6tables -t nat -L DNSCRYPT_OUT6 -n 2>/dev/null | head -20

# 6. Memory profile (v1.1.0)
echo ""
echo "=== Memory Profile (v1.1.0) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'

# 7. Backup state (v1.2.0)
echo ""
echo "=== Backup State (v1.2.0) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
ls -la /sdcard/dnscrypt-webui-backup/ 2>&1

# 8. Logs (last 50)
echo ""
echo "=== Logs ==="
tail -50 /data/local/tmp/dnscrypt_main.log
```

### 2.2 Information Required in a Report

| Information | Command |
|---|---|
| Android | `getprop ro.build.version.release` |
| API Level | `getprop ro.build.version.sdk` |
| Device | `getprop ro.product.model` |
| Kernel | `uname -r` |
| Root | Magisk / KernelSU / APatch version |
| SoC | `getprop ro.product.board` |
| Module | `cat module.prop` |
| Status | `status.sh --json` |
| STATUS_FILE | `cat proxy/run/dnscrypt.status` |
| Firewall | `iptables -t nat -L DNSCRYPT_OUT -n` |
| Dashboard | `curl -s http://127.0.0.1:9091/api/metrics` |
| Runtime Info | `curl -s http://127.0.0.1:9090/api?action=runtime_info` |
| **Profile (v1.1.0)** | **`curl -s .../runtime_info \| jq -r .profile_key`** |
| **Memory limit (v1.1.0)** | **`curl -s .../runtime_info \| jq .memory_limit_mb`** |
| **Backup state (v1.2.0)** | **`curl -s .../runtime_info \| jq .backups`** |
| **Backup directory (v1.2.0)** | **`ls -la /sdcard/dnscrypt-webui-backup/`** |
| **Diagnose report (v1.2.0)** | **`sh status.sh --diagnose`** |
| Logs | `tail -50 dnscrypt_main.log` |

---

## 3. Installation Issues

### 3.1 "Please install via Magisk Manager"

**Cause**: `MODPATH` is not set (manual install).

**Solution**:
1. Install from Magisk Manager (not manually).
2. Or install from KernelSU Manager.

### 3.2 "SECURITY: MODPATH outside /data/adb"

**Cause**: attempting to install to an unsafe path.

**Solution**:
- Ensure `MODPATH` starts with `/data/adb/modules/`.
- Use Magisk / KernelSU.

### 3.3 "Required tool 'X' not found"

**Solution**:
```bash
su -c "which unzip sed tr date grep head cut"
```

### 3.4 "Failed to extract module files"

**Causes**:
1. Corrupt ZIP.
2. Insufficient disk space.
3. Wrong permissions.

**Solution**:
```bash
# 1. verify ZIP
unzip -t /sdcard/dnscrypt-webui-1.2.0-module.zip

# 2. verify space
df -h /data
df -h /sdcard

# 3. re-download from GitHub Releases
```

### 3.5 "Missing critical files"

**Solution**:
- Download a fresh ZIP.
- Verify SHA256:
  ```bash
  sha256sum -c dnscrypt-webui-1.2.0-module.zip.sha256
  ```

### 3.6 "DNS binary missing for <arch>"

**Solution**:
```bash
getprop ro.product.cpu.abi
# → arm64-v8a, armeabi-v7a, x86_64, x86
```

### 3.7 PORT=8080 warning during install

**Symptom**:
```text
⚠️ PORT=8080 conflicts with [monitoring_ui], resetting to 9090
```

**Solution (automatic)**: `customize.sh` replaces it with `9090`. No action needed.

**To prevent recurrence**:
```bash
su -c "grep -E 'PORT|DASHBOARD' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Expected: PORT=9090, DASHBOARD_PORT=9091
```

### 3.8 Persistent backup created during install (v1.2.0)

**Symptom**:
- During install, `customize.sh` prints:
  ```text
  → Multi-source detection (Layer 1): 5 file(s) found
  → Transaction begun (Layer 4): txn-20260929-150000-12345
  → Persistent backup created (Layer 2): 20260929-150000-v1.2.0-12345
    → SHA256 manifest written (Layer 3)
  ```

**Is this normal?**
- ✅ Yes — on upgrades, the 10 defensive layers snapshot the 5
  user config files to `/sdcard/dnscrypt-webui-backup/`.
- ✅ On a fresh install (no source found), no snapshot is created.

**Verify after install**:
```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# Expected: current/, <ts>-<version>/, .last_stable, ...
```

**See**: §4.13 (if missing), §4.14 (state issues).

---

## 4. WebUI Access Issues

### 4.1 "Cannot open 127.0.0.1:9090"

**First loop**:
```bash
# 1. Is the port open?
su -c "ss -ltn | grep 9090"

# 2. Is the process running?
su -c "pgrep -x dnscrypt-webui"

# 3. Does the PID file exist?
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/webui.pid"

# 4. If the process is dead, start it
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"
```

### 4.2 "Port already in use"

**Solution**:
```bash
# 1. Find the app
su -c "ss -ltnp | grep 9090"

# 2. Change the port in webui.conf
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# → PORT=9191

# 3. Restart
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 4.3 "Connection refused"

**Loop**:
```bash
# 1. Test directly
su -c "curl -v http://127.0.0.1:9090/healthz"

# 2. If refused:
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

# 3. Check webui.conf
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf | grep -E 'PORT|BIND'"

# 4. If BIND_ADDR=0.0.0.0 and credentials are empty → refuses to start
# Solution: reinstall (customize.sh generates credentials)
```

### 4.4 WebUI works but shows a blank page

**Solution**:
```bash
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/"
# Expected: 13 files (index, dashboard, offline, manifest, sw, 3 SVG, 3 PNG, ICO)
```

### 4.5 "404 Not Found" on /icon-192.svg

**Solution**: confirm version `v1.2.0`.

```bash
su -c "curl -I http://127.0.0.1:9090/icon-192.svg"
# Expected: 200 OK + Content-Type: image/svg+xml
```

### 4.6 Dashboard shows no metrics

**Symptom**:
- Dashboard at `http://127.0.0.1:9091` opens.
- But the Metrics tables are empty.

**Solution**: update to `v1.2.0` (or v1.0.0+). `/api/metrics` returns proper JSON.

**Verify**:
```bash
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -5
# Expected: JSON (not Prometheus text)
```

### 4.7 Port 8080 conflict

**Symptom**:
```text
❌ FATAL: PORT=8080 conflicts with [monitoring_ui]
```

**Solution**:
```bash
su -c "sed -i 's/^PORT=8080/PORT=9090/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sed -i 's/^DASHBOARD_PORT=8080/DASHBOARD_PORT=9091/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 4.8 Dashboard shows no data (Fix #1)

**Symptom**:
- Dashboard at `http://127.0.0.1:9091` opens.
- **All** tables are empty (Overview, Cache, Query Types, Resolvers, ...).
- In the browser console: `JSON.parse()` error, or "Cannot fetch data".
- No error message in the log.

**Cause (before v1.0.0)**:
`metricsProxyHandler` was:
```go
w.Header().Set("Content-Type", "application/json")  // ← lies
resp, _ := dashboardProxyClient.Do(req)
io.Copy(w, resp.Body)  // ← raw Prometheus text (not JSON!)
```

`monitoring_ui` (dnscrypt-proxy) returns **Prometheus text format**:
```
# HELP dnscrypt_proxy_query_total Total queries
# TYPE dnscrypt_proxy_query_total counter
dnscrypt_proxy_query_total 15234
dnscrypt_proxy_blocked_query_total 1523
```

But `dashboard.html` expects JSON → `JSON.parse()` fails → no data.

**Verify**:

**Method 1 — Test main.go directly**:
```bash
# Query via the dashboard proxy
su -c "curl -s -b /tmp/cookies.txt http://127.0.0.1:9091/api/metrics" | head -5

# Before the fix: Prometheus text:
# # HELP dnscrypt_proxy_query_total Total queries
# # TYPE dnscrypt_proxy_query_total counter
# dnscrypt_proxy_query_total 15234

# After the fix: JSON:
# {
#   "generated_at": "2026-09-29T10:30:00Z",
#   "total_queries": 15234,
#   ...
# }
```

**Method 2 — Check Content-Type**:
```bash
su -c "curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type"
# Before: Content-Type: application/json (lies about Prometheus text)
# After: Content-Type: application/json; charset=utf-8 (correct)
```

**Method 3 — Test the upstream endpoint**:
```bash
# monitoring_ui uses the standard /api/metrics endpoint
su -c "curl -s -u \"user:pass\" http://127.0.0.1:8080/api/metrics | head -10"
# Expected: JSON (or Prometheus text as fallback)
```

**Solution**:

**Option 1 — Update (recommended)**:
- Update to `v1.2.0` (or v1.0.0+).
- Now `metricsProxyHandler` contains:
  ```go
  func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
      // ...
      body, _ := io.ReadAll(resp.Body)
      var upstream map[string]interface{}
      if err := json.Unmarshal(body, &upstream); err == nil {
          json.NewEncoder(w).Encode(upstream)
          return
      }
      prom := parsePrometheus(string(body))
      dashboardJSON := buildDashboardJSON(prom)
      json.NewEncoder(w).Encode(dashboardJSON)
  }
  ```

**Option 2 — Verify the fix**:
```bash
# static audit
grep -q 'func parsePrometheus' proxy/main.go && echo "✅ Fix present"
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix present"
```

**Effect after upgrade**:
- ✅ Dashboard shows: total_queries, blocked_queries, cache_stats.
- ✅ `JSON.parse()` succeeds.
- ✅ No console errors.
- ⚠️ Some fields are empty (`resolver_health`, `top_domains`) — they require `query_log` enabled in TOML.

**Enable the empty fields** (optional):
```toml
# in dnscrypt-proxy.toml
[monitoring_ui]
  enabled = true
  enable_query_log = true  # ← to populate recent_queries, top_domains
  privacy_level = 1        # ← 1 = log domains
```

Then:
```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Reference**: [API.md](API.md) — `/api/metrics` schema, [SECURITY.md](SECURITY.md) — Audit #25.

### 4.9 /readyz rejected from LAN (Fix NEW-4)

**Symptom**:
- From another device on the same LAN:
  ```bash
  curl http://192.168.1.5:9091/readyz
  ```
- Result: **403 Forbidden** with `{"error": "readyz is localhost-only"}`.

**Is this a bug?**
- No — intentional since v1.0.0.
- ✅ Reason: prevents reconnaissance on LAN.
- ✅ `/healthz` remains public (standard, lightweight, no details).

**Difference between endpoints**:

| Endpoint | Before | After |
|----------|:---:|:---:|
| `/healthz` | public | public (unchanged) |
| `/readyz` | public (leaks details) | localhost-only |

**What does `/readyz` reveal?**
- `config` — presence of TOML.
- `blocklist` — presence of blocklist.
- `run_dir` — writability.
- `dns_engine` — DNS state.
- `version` — build version.

With `BIND_ADDR=0.0.0.0`, any LAN attacker could use it for **fingerprinting**.

**Solution — for users**:
- Use `/healthz` instead of `/readyz`:
  ```bash
  curl http://192.168.1.5:9091/healthz
  # → "ok"
  ```

**Solution — for developers/monitoring**:
- If you need details from LAN, use:
  ```bash
  # runtime_info (with auth)
  curl -s -u "user:pass" http://192.168.1.5:9090/api?action=runtime_info
  ```

**Verify**:
```bash
# on localhost
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9091/readyz
# Expected: 200 or 503 (not 403)

# from LAN (after BIND_ADDR=0.0.0.0)
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.5:9091/readyz
# Expected: 403
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #30.

### 4.10 Invalid port ignored (Fix NEW-3)

**Symptom**:
- You set `PORT=0` in `webui.conf`.
- WebUI is running on a **random port** (unexpected).
- Or `PORT=99999` → silent failure (`exit code 0` with no message).

**Cause (before v1.0.0)**:
`readConfPort` was:
```go
func readConfPort(key, defaultPort string) string {
    val := readConfValue(key, defaultPort)
    if _, err := strconv.Atoi(val); err == nil && val != "" {
        return val  // ← accepts 0, 99999, -1
    }
    return defaultPort
}
```

**Solution**:
- Update to `v1.2.0` (or v1.0.0+).
- Now `readConfPort`:
  ```go
  func readConfPort(key, defaultPort string) string {
      defer func() { recover() }()
      val := readConfValue(key, defaultPort)
      n, err := strconv.Atoi(val)
      if err != nil || n < 1 || n > 65535 {
          return defaultPort  // fallback
      }
      return val
  }
  ```

**Behavior of values**:

| Value | Before | After |
|-------|:---:|:---:|
| `PORT=9090` | ✅ works | ✅ works |
| `PORT=1` | ✅ works | ✅ works |
| `PORT=65535` | ✅ works | ✅ works |
| `PORT=0` | random port | ✅ fallback (9090) |
| `PORT=99999` | silent failure | ✅ fallback (9090) |
| `PORT=-1` | silent failure | ✅ fallback (9090) |
| `PORT=abc` | ✅ fallback | ✅ fallback |

**How to verify?**
```bash
# 1. static audit
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' \
    && echo "✅ Range check present"

# 2. Manual test with invalid port
su -c "sed -i 's/^PORT=.*/PORT=99999/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
su -c "ss -ltn | grep 9090"
# Expected: listening on 9090 (fallback)

# Restore
su -c "sed -i 's/^PORT=.*/PORT=9090/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #29.

### 4.11 Broken Dashboard links (PORT-2)

**Symptom**:
- You set `PORT=8081` or `DASHBOARD_PORT=8082`.
- WebUI runs on the new port.
- But:
  - The "Dashboard" button in `index.html` → opens the **old port** (9091).
  - The "Back to Control Panel" button in `dashboard.html` → opens the **old port** (9090).

**Cause (before v1.0.0)**:
```html
<!-- index.html -->
<a href="http://127.0.0.1:9091">Dashboard</a>  <!-- hardcoded -->
```

**Solution**:
- Update to `v1.2.0` (or v1.0.0+).
- Now:
  - `runtime_info` returns `webui_port` + `dashboard_port`.
  - The frontend updates the links dynamically.

**How to verify?**
```bash
# 1. runtime_info returns ports
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. static audit
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html uses dynamic"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html uses dynamic"
```

**Effect**:
- ✅ Links work on any port.
- ✅ Support LAN access (`window.location.hostname`).
- ✅ Support IPv6 loopback (`[::1]`).
- ⚠️ PWA shortcuts (manifest.json) remain static (documented limitation).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #33.

### 4.12 Memory limit issues (v1.1.0 — MEM-1)

**Symptom (A)** — You switched to the `ultimate` profile, but the
WebUI is still laggy or freezes occasionally:

- Dashboard loads slowly.
- SSE progress updates stutter.
- `runtime_info.memory_limit_mb` shows an unexpected value.

**Symptom (B)** — You are on a low-RAM device (1 GB) and the
WebUI feels heavier than before the upgrade:

- `dumpsys meminfo` or `top` shows the WebUI process around
  80–110 MB RSS after upgrade (was ~25 MB before).
- Battery consumption increased slightly.

**Symptom (C)** — You manually edited `selected_profile.txt`
and the change did not take effect:

- `runtime_info.profile_key` still shows the old profile.

**Cause (A) and (C)**: Before v1.1.0, `main.go` set a **hardcoded**
soft memory limit of 80 MB:

```go
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← same value for every profile
```

On `ultimate`, actual usage approaches 200 MB. With an 80 MB soft
limit, the Go runtime runs GC continuously ("GC thrashing").
This manifests as a slow/unresponsive WebUI — not a crash.

Additionally, changing `selected_profile.txt` outside the WebUI
had no effect until the next full restart, because the limit was
set once at startup.

**Cause (B)**: This is expected behavior. `ultimate` sets the
soft limit to 220 MB, giving the runtime more headroom. The
WebUI process can now use up to ~220 MB under load without GC
pressure. On a 1 GB device this is still safe, but you may want
to use a lighter profile.

**Solution**:

**For (A)** — Update to `v1.2.0` (the fix was introduced in v1.1.0).
The limit is now computed per profile:

```go
MEMORY_LIMIT_LIGHT     = 80 MB
MEMORY_LIMIT_NORMAL    = 100 MB
MEMORY_LIMIT_PRO       = 120 MB
MEMORY_LIMIT_PROPLUS   = 160 MB
MEMORY_LIMIT_ULTIMATE  = 220 MB
```

**For (B)** — If the `ultimate` profile is too heavy for your
device, switch to a lighter one:

```bash
# Option 1: From the WebUI
#   Select "PRO" and press Apply.

# Option 2: From the terminal
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
sleep 5
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
# Expected: 120
```

**For (C)** — If you changed `selected_profile.txt` directly, restart
the WebUI so the new profile is picked up:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

The `applyMemoryLimit()` call runs at startup and reads the file
fresh. Changing the file while the WebUI is running does NOT
trigger a re-read — that is by design (avoids race conditions
with the WebUI's own profile-update flow).

**How to verify the limit**:

```bash
# 1. runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}

# 2. Startup log line
su -c "grep 'dynamic memory limit' /data/local/tmp/dnscrypt_main.log | tail -1"
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB
```

**Expected values per profile**:

| `profile_key` | `memory_limit_mb` |
|:---:|:---:|
| `light` | 80 |
| `normal` | 100 |
| `pro` | 120 |
| `proplus` | 160 |
| `ultimate` | 220 |

**Reference**: [SECURITY.md](SECURITY.md) §5.30.1, §14.22; [ARCHITECTURE.md](ARCHITECTURE.md) §3.9, §4.9.1, §11.22.

### 4.13 Backup directory missing (v1.2.0 — Layer 2)

**Symptom**:
- After upgrading to v1.2.0, the persistent backup directory
  `/sdcard/dnscrypt-webui-backup/` does not exist.
- `runtime_info.backups.available` is `0`.
- `backups.last_backup_name` is `null`.

**Possible causes**:

1. **`/sdcard/` not mounted at install time** — on some ROMs,
   the FUSE daemon is not ready when `customize.sh` runs.
2. **`/sdcard/` is read-only** — rare, but possible if the user
   mounted external storage with restrictive flags.
3. **Storage full** — if `/sdcard/` has less than ~10 MB free,
   the backup dir cannot be created.

**Diagnosis**:

```bash
# 1. Check /sdcard/ is mounted
su -c "ls /sdcard/"
# Expected: the standard Android directory list (DCIM, Download, ...)

# 2. Check the backup directory
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"
# Expected (v1.2.0+): current/, <ts>-<version>/, .last_stable, ...

# 3. Check storage
su -c "df -h /sdcard"
# Expected: at least 10 MB free

# 4. Check runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
```

**Solutions**:

- **Cause 1**: Reboot. On the next boot, `service.sh` runs
  `auto_backup_if_needed` and creates the directory.
- **Cause 2**: Check the ROM's FUSE configuration. This is rare;
  file an issue.
- **Cause 3**: Free up space and reboot. The auto-backup will
  run on the next boot.

**Manual trigger** (if the auto-backup does not run):

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Verify success**:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups.available'"
# Expected: >= 1
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §10.1;
[`docs/EMERGENCY.md`](EMERGENCY.md) §4.

### 4.14 Backup state issues (v1.2.0 — BAK-1)

**Symptom (A)** — `runtime_info.backups` returns 5 fields instead
of 7:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Before: ["available", "last_backup", "last_backup_name", "last_stable", "path"]
# After:  ["available", "in_flight_txn", "last_backup", "last_backup_name",
#          "last_stable", "orphan_txn", "path"]
```

**Symptom (B)** — `status.sh --json` and `runtime_info` disagree
on the shared fields.

**Symptom (C)** — `available` is greater than the actual number
of snapshot directories on disk.

**Symptom (D)** — `last_stable` is `null` even though snapshots
exist.

**Cause (A)** — Version mismatch between `main.go` and `status.sh`.
This should not occur on v1.2.0 — both were updated in the same
release.

**Cause (B)** — Same as (A): version mismatch.

**Cause (C)** — The counter includes `txn-*` or `orphan-txn-*`
directories. In v1.2.0, `available` should exclude them. If it
does not, `main.go` is out of date.

**Cause (D)** — `.last_stable` is updated only by
**install-time** snapshots (`customize.sh`). Runtime snapshots
(`main.go`, `service.sh`, `action.sh`) do not update it. This is
by design — the pointer must reference a version-tagged snapshot,
not a runtime one whose `version` field is `"unknown"`.

**Solution**:

1. Confirm the module version:

```bash
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → must be version=v1.2.0
```

2. If the binary is stale (older than the scripts), reinstall
   the module from the v1.2.0 ZIP.

3. After fixing, restart the WebUI and re-run:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 7 fields
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups | keys'"
# Expected: ["available", "in_flight_txn", "last_backup", "last_backup_name",
#            "last_stable", "orphan_txn", "path"]

# Cross-check with status.sh --json
diff <(su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -S '.backups'") \
     <(su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | jq -S '.backups | del(.status, .last_backup_age_seconds)'")
# Expected: no diff
```

**Note**: `status.sh --json` adds two diagnostic-only fields
(`status`, `last_backup_age_seconds`) that are **not** part of the
API surface. See [`docs/API.md`](API.md) §6.1.7.

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §10.6.

---

## 5. Authentication Issues

### 5.1 "Invalid credentials"

**Solution**:
```bash
# 1. Read credentials
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"

# 2. Or from the TOML directly
su -c "grep -E 'username|password' /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"
```
*Note: the values are between `'...'` — do not copy the quotes.*

**v1.2.0**: The credentials are also preserved in the persistent
backup at
`/sdcard/dnscrypt-webui-backup/current/dnscrypt-proxy.toml`.

### 5.2 Forgot password

**Solution**:
```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

### 5.3 "Too many attempts"

**Solution**:
```bash
# 1. Wait 15 minutes, or
# 2. Restart the WebUI
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 5.4 Session expires quickly

**Solution**: v1.2.0 relies on `HttpOnly cookie` — session lasts 24h.

### 5.5 "Session Expired" modal frequently

**Loop**:
```bash
# 1. Check system time
date

# 2. If time is wrong:
# Settings → Date & Time → Automatic

# 3. Clear browser cookies
# Chrome → Settings → Privacy → Clear browsing data

# 4. Log in again
```

### 5.6 "401 Unauthorized" after upgrade

**Solution**: clear browser cookies, log in again.

### 5.7 PWA shortcut asks for login every time

**Solution**: ensure `v1.0.0+` (`SameSite=Lax`).

### 5.8 Rate limit not working correctly for IPv6

**Cause (before v1.0.0)**:
```go
ip := strings.Split(r.RemoteAddr, ":")[0]
// RemoteAddr = "[::1]:12345" → ip = "["  ← wrong!
```

**Solution**: update to `v1.2.0` (or `v1.0.0+`).

**Verify**:
```bash
grep -q 'func getClientIP' proxy/main.go && echo "✅ present"
grep -A5 'func getClientIP' proxy/main.go | grep -q 'net.SplitHostPort' && echo "✅ IPv6-safe"
```

### 5.9 Credentials read from the wrong section

**Symptom**:
- `[monitoring_ui]` contains valid credentials, but login fails.

**Cause (before v1.0.0)**:
`getMonitoringAuth` read the first line containing `username=` regardless of the section.

**Solution**: update to `v1.2.0` (or `v1.0.0+`).

**Verify**:
```bash
grep -q 'inSection' proxy/main.go && echo "✅ section tracking"
```

### 5.10 404 for unknown action (Fix #12)

**Symptom**:
- An external client (curl, script) calls an old endpoint:
  ```bash
  curl "http://127.0.0.1:9090/api?action=toggle"  # ← old
  ```
- **Before v1.0.0**: returned `200 OK` with `{"status": "unknown"}`.
- **After v1.0.0**: returns `404 Not Found` with a clear message.

**New message**:
```json
{
  "status": "error",
  "message": "unknown action: \"toggle\""
}
```

**Is this a breaking change?**
- ✅ **Yes, for API consumers**. If you have a script depending on `200 + unknown`, update it.
- ✅ **For end users**: no impact (the UI does not use old endpoints).

**Solution for scripts**:

**Before** (incorrect):
```bash
# Relied on 200 to detect an old endpoint
curl -s "http://127.0.0.1:9090/api?action=toggle" | jq -r .status
# → "unknown"
```

**After** (correct):
```bash
# 1. Use the new endpoint (POST)
curl -s -X POST -b /tmp/cookies.txt \
  "http://127.0.0.1:9090/api/toggle_service" | jq -r .status
# → "ON" or "OFF"

# 2. Check the HTTP status
status_code=$(curl -s -o /dev/null -w "%{http_code}" \
  "http://127.0.0.1:9090/api?action=unknown_xyz")
if [ "$status_code" = "404" ]; then
  echo "endpoint not found"
fi
```

**Mapping table** (old → new):

| Old (GET + query) | New (POST + path) |
|---|---|
| `GET /api?action=toggle` | `POST /api/toggle_service` |
| `GET /api?action=restart` | `POST /api/restart_service` |
| `GET /api?action=ensure_running` | `POST /api/ensure_running_service` |
| `GET /api?action=save_allowlist` | `POST /api/save_allowlist` |
| `GET /api?action=save_denylist` | `POST /api/save_denylist` |
| `GET /api?action=save_custom_rules` | `POST /api/save_custom_rules` |

**Reference**: [API.md](API.md) — Path Matching.

### 5.11 Login GET rejected (Fix NEW-1)

**Symptom**:
- A script or integration that used:
  ```bash
  curl "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
  ```
- Result now: **405 Method Not Allowed**.

**Message**:
```json
{
  "status": "error",
  "message": "Login requires POST (CSRF protection)"
}
```

**Is this a bug?**
- No — intentional since v1.0.0.
- ✅ Reason: prevents a CSRF vector:
  ```html
  <!-- worked before v1.0.0! -->
  <img src="http://127.0.0.1:9090/api/auth/login?username=admin&password=X">
  ```
- ✅ Second reason: prevents credentials leaking into the URL (browser history + logs).

**Solution — use POST**:
```bash
# ✅ Correct
curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"your_password"}' \
    -c /tmp/cookies.txt
```

**Supported methods**:

| Method | Before | After |
|--------|:---:|:---:|
| POST | ✅ works | ✅ works |
| GET | ⚠️ **works** (CSRF risk) | ❌ 405 + `Allow: POST` |
| HEAD | ⚠️ **works** | ❌ 405 + `Allow: POST` |
| PUT | ⚠️ **works** | ❌ 405 + `Allow: POST` |
| DELETE | ⚠️ **works** | ❌ 405 + `Allow: POST` |

**Diagnose**:
```bash
# 1. GET must fail
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: HTTP/1.1 405 Method Not Allowed
#            Allow: POST

# 2. POST must succeed
curl -i -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"..."}'
# Expected: HTTP/1.1 200 OK + Set-Cookie
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #28.

### 5.12 Basic Auth locked after 5 attempts (Fix #8)

**Symptom**:
- You used Basic Auth from a script (e.g. cURL):
  ```bash
  curl -u "admin:wrong" http://127.0.0.1:9090/api?action=status
  ```
- After 5 failed attempts, even the **correct password** is rejected.

**Is this a bug?**
- No — intentional since v1.0.0.
- ✅ Reason: prevents brute force on LAN.

**How does it work?**
- 5 failed attempts → 15-minute lockout.
- Success → resets the counter.
- Lockout is per IP (supports IPv4 + IPv6).

**Before vs After**:

| Scenario | Before | After |
|---|---|---|
| 5 failed attempts | No lockout | 15-min lockout |
| 6 attempts | No lockout | 401 (locked) |
| Success after 3 failures | Success | Success (resets) |
| Brute force from a different IP | Unlimited | Limited (per IP) |

**Solution**:
1. **Wait 15 minutes** — the lockout clears automatically.
2. **Or restart the WebUI**:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
   ```

**Diagnose**:
```bash
# Test the lockout
for i in 1 2 3 4 5 6; do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "wrong:wrong" http://127.0.0.1:9090/api?action=status)
    echo "Attempt $i: $code"
done
# Expected: 401 × 5 then 401 (locked)
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #22.

### 5.13 Credentials change delay 60 s (Fix NEW-6)

**Symptom**:
- You edited credentials in `dnscrypt-proxy.toml`.
- You restarted the DNS Engine (not the WebUI).
- But login still fails with the **old** credentials.
- After ~60 seconds, the new credentials work.

**Is this a bug?**
- No — intentional since v1.0.0.
- ✅ Reason: `getMonitoringAuth()` caches credentials for 60 seconds.

**How does it work?**
```go
const AUTH_CACHE_TTL = 60 * time.Second

func getMonitoringAuth() (username, password string) {
    authCacheMu.RLock()
    if !authCacheTime.IsZero() && time.Since(authCacheTime) < AUTH_CACHE_TTL {
        u, p := authCacheUser, authCachePass
        authCacheMu.RUnlock()
        return u, p
    }
    // cache miss → read from TOML
    // ...
}
```

**Benefits**:
- ✅ Reduces file I/O on Android (~5-10 ms → ~0.05 ms per request).
- ✅ Saves battery.

**Solution**:

**Option 1 — Wait 60 seconds**:
- The new values take effect automatically after the TTL.

**Option 2 — Restart the WebUI** (invalidates the cache):
```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Why not immediate?**
- Credentials are changed very **rarely**.
- 60 seconds is acceptable for the performance gain.
- `invalidateAuthCache()` is available internally for immediate use.

**Diagnose**:
```bash
# 1. Change credentials
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"

# 2. Try immediately (will fail if the cache is stale)
sleep 5
curl -u "new_user:new_pass" http://127.0.0.1:9090/api?action=status

# 3. Wait 60 s
sleep 60
curl -u "new_user:new_pass" http://127.0.0.1:9090/api?action=status
# → 200 OK
```

**Reference**: [SECURITY.md](SECURITY.md).

### 5.14 Profile key problems (v1.1.0 — MEM-1)

**Symptom (A)** — The WebUI shows a different profile than
expected:

- You switched to `ultimate` in the WebUI, but `runtime_info`
  shows `profile_key: "pro"`.
- Or the blocklist file size suggests `pro` while the label says
  `ultimate`.

**Symptom (B)** — `memory_limit_mb` does not match the profile
you think is active:

- `profile_key` = `pro` but `memory_limit_mb` = 80.
- Or `profile_key` = `ultimate` but `memory_limit_mb` = 120.

**Symptom (C)** — After manually editing `selected_profile.txt`,
the WebUI still uses the old profile.

**Cause (A)** — The active profile is determined by
`proxy/selected_profile.txt`, not by the WebUI's dropdown state.
If the file contains an unknown value (e.g. a typo), `main.go`
falls back to `"pro"`:

```go
func readSelectedProfile() string {
    data, err := os.ReadFile(SELECTED_FILE)
    if err != nil {
        return "pro"
    }
    key := strings.TrimSpace(string(data))
    if _, ok := profiles[key]; !ok {
        return "pro"
    }
    return key
}
```

**Cause (B)** — The memory limit is set at startup and on every
profile change. If the two values disagree, either:
- The WebUI has not been restarted since a manual edit of
  `selected_profile.txt` (see cause C), or
- The startup log shows an error (check
  `/data/local/tmp/dnscrypt_main.log`).

**Cause (C)** — By design. `selected_profile.txt` is read once at
startup (in `main()`) and again after each successful
`POST /api/update_profile`. Direct file edits are not monitored
(no inotify — that would add a dependency and CPU overhead on
Android). You must restart the WebUI:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Solution**:

**Verify the file content**:

```bash
# What does the file actually say?
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: one of: light, normal, pro, proplus, ultimate
```

**Verify the runtime value**:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'
```

**Expected pairs**:

| `selected_profile.txt` | `profile_key` | `memory_limit_mb` |
|---|---|---|
| `light` | `light` | 80 |
| `normal` | `normal` | 100 |
| `pro` | `pro` | 120 |
| `proplus` | `proplus` | 160 |
| `ultimate` | `ultimate` | 220 |

**If they do not match**:

1. Fix `selected_profile.txt` to a known value.
2. Restart the WebUI:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
   ```
3. Wait ~5 s.
4. Re-check `runtime_info`.

**If `selected_profile.txt` contains a typo** (e.g. `prot` or
`Ultimate` with capital U):

- The value is case-sensitive and must match the exact keys.
- `main.go` falls back to `"pro"` for unknown keys.
- Fix the file and restart.

**If the file is missing**:

```bash
# Recreate it with the default
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Reference**: [SECURITY.md](SECURITY.md) §5.30.1; [ARCHITECTURE.md](ARCHITECTURE.md) §4.9.1.

### 5.15 Watchdog token issues (v1.2.0 — WD-TOKEN)

**Symptom (A)** — The watchdog no longer restarts the DNS engine
after a crash:

- `pgrep -x dnscrypt-proxy` returns nothing.
- `STATUS_FILE` is `ON` (user intent).
- The watchdog process is running.
- But the DNS engine stays down.

**Symptom (B)** — The log contains repeated messages:

```text
watchdog: ensure_running → 401 Unauthorized
watchdog: no auth header
```

**Symptom (C)** — A malicious webpage can silently restart the
DNS engine:

- You visit a webpage in a browser on the device.
- The DNS engine restarts unexpectedly.

**Cause (A)** — The token file
`/data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token`
is missing or unreadable. This can happen if:

- The install was interrupted before `customize.sh §[19b]` ran.
- A non-root user deleted the file.
- The file is on a filesystem that does not support `0600`.

**Cause (B)** — Same as (A). The watchdog is failing to
authenticate to `POST /api/ensure_running_service` because the
token file is missing.

**Cause (C)** — The watchdog token was **removed** by mistake, and
the WebUI fell back to normal user auth — except the WebUI
rejects requests with no auth. But if the request comes from
localhost **and** carries the correct credentials, the token
requirement is bypassed. This is not a vulnerability (the
credentials are still required), but a **downgrade** in the
defense-in-depth posture.

**What the token protects against**:

- CSRF from any page loaded in a browser on the same device
  (the browser can send a POST, but cannot set a custom header
  like `X-Watchdog-Token`).

**Solution**:

**Verify the token file exists**:

```bash
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: -rw------- root root
```

**If missing, regenerate it** by restarting the WebUI:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

`main.go` calls `loadOrCreateWatchdogToken()` at startup, which
generates a new 64-hex token and writes it atomically (tmp +
rename).

**Verify the token was created**:

```bash
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
su -c "wc -c /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
# Expected: ~64 (hex token) or ~65 (with newline)
```

**Verify the watchdog picks it up**:

```bash
su -c "grep -i 'watchdog token' /data/local/tmp/dnscrypt_main.log | tail -5"
```

**Test the recovery path**:

```bash
# 1. Ensure the DNS engine is running
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: "DNS=UP"

# 2. Kill the DNS engine
su -c "pkill -9 dnscrypt-proxy"

# 3. Wait for the watchdog (up to 60s)
sleep 60

# 4. Verify it was restarted
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: "DNS=UP" (Watchdog restarted it via token)
```

**Manual test of the token endpoint**:

```bash
# 1. Get the token
TOKEN=$(su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token")
echo "Token: $TOKEN"

# 2. Without the header → 401
curl -s -o /dev/null -w "Without token: %{http_code}\n" \
    -X POST http://127.0.0.1:9090/api/ensure_running_service
# Expected: 401

# 3. With the header → 200
curl -s -o /dev/null -w "With token: %{http_code}\n" \
    -X POST -H "X-Watchdog-Token: $TOKEN" \
    http://127.0.0.1:9090/api/ensure_running_service
# Expected: 200
```

**If the token is deleted repeatedly**:

- Check for a cron job, a root script, or a file manager app that
  cleans `/data/adb/modules/*/proxy/run/`.
- The token file is a **runtime secret**, not user config. It is
  not part of the 5 preserved files.

**Reference**: [`docs/SECURITY.md`](SECURITY.md) §5.33;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.5.1, §5.7.

---

## 6. DNS Issues

### 6.1 DNS not working after install

**Diagnostic tree**:
```text
DNS not working
│
├── 1. Is the DNS Engine running?
│   su -c "pgrep -x dnscrypt-proxy"
│   ├── No → start from WebUI
│   └── Yes → 2
│
├── 2. Is port 5354 open?
│   su -c "ss -uln | grep 5354"
│   ├── No → restart
│   └── Yes → 3
│
├── 3. Does iptables redirect?
│   su -c "iptables -t nat -L DNSCRYPT_OUT -n"
│   ├── No → manage_firewall 1
│   └── Yes → 4
│
├── 4. Does the query work?
│   su -c "nslookup google.com 127.0.0.1"
│   ├── No → see logs
│   └── Yes → 5
│
└── 5. Do the apps use DNS?
    → Some apps have their own DNS → § 6.6
```

### 6.2 "DNS does not work on Wi-Fi"

**Solution**:
```bash
# 1. Ensure the iptables rules exist
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"

# 2. Restart the service
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 3. If the problem persists:
su -c "settings put global private_dns_mode off"
```

### 6.3 "DNS does not work on 4G/5G"

**Solution**:
```bash
su -c "iptables -t nat -L OUTPUT -n -v | grep DNSCRYPT"
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"
```

### 6.4 "DNS is too slow"

**Solution**:
```bash
# 1. Try a smaller list (Light)
# WebUI → select "Light" → Apply

# 2. Clear the cache
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 6.5 "DNS leak"

**Test**: `https://www.dnsleaktest.com`

**If you see your ISP**:
```bash
su -c "iptables -t nat -L OUTPUT -n -v"
su -c "iptables -t nat -L DNSCRYPT_OUT -n -v"

# If rules are missing:
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"
```

### 6.6 "Some apps do not work"

**Solution**: add their domains to the allowlist:
```text
netflix.com
nflxvideo.net
```

### 6.7 "DNS over HTTPS (DoH) does not work"

This behavior is intentional — cannot be blocked transparently without a VPN.

### 6.8 Private DNS (Android 9+) conflicts

**Solution**:
```bash
su -c "settings delete global private_dns_mode"
```

### 6.9 Watchdog does not restart after crash (Fix A)

**Symptom**:
- DNS Engine crashes suddenly.
- `status.sh` shows DNS = "STOPPED".
- Watchdog runs (PID exists) but does nothing.
- STATUS_FILE = "OFF" even though you did not stop the service manually.

**Cause (before v1.0.0)**:
- WebUI calls `getStatus` every 10 seconds.
- On crash: `getStatusUncached` wrote `STATUS_FILE = "OFF"`.
- Watchdog reads "OFF" → ignores restart.

**Solution**: update to `v1.2.0` (or v1.0.0+).

**Verify after update**:
```bash
# 1. Start the service (STATUS_FILE = ON)
# 2. Kill DNS manually
su -c "pkill -9 dnscrypt-proxy"

# 3. Wait 60 seconds
sleep 60

# 4. What is the state?
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json | grep -A2 dns_engine"
# Expected: "running": true

# 5. Static verification
grep -q 'func getStatusUncached' proxy/main.go && echo "✅ function present"
grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'return "OFF"' && echo "✅ read-only"
grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ still writes!"
# Last check should NOT find atomicWriteFile
```

**v1.2.0 note**: If the restart does not work even after the fix,
see §5.15 (Watchdog token issues) — the v1.2.0 watchdog requires
the `X-Watchdog-Token` header.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #18.

### 6.10 GC thrashing symptoms (v1.1.0 — MEM-1)

**Symptom** — The WebUI is running but feels slow or unresponsive
after switching to a heavy profile:

- The Dashboard takes 10+ seconds to load (normally 1–2 s).
- Pressing buttons in the WebUI has a 2–5 second delay.
- SSE progress updates stutter (progress bar jumps by 20% at a
  time instead of 5%).
- `top` or `dumpsys` shows high CPU on the WebUI process
  (50–80%) even at idle.
- `runtime_info` shows a profile that expects high memory
  (e.g. `ultimate`) but the process is memory-constrained.
- Battery drains faster than usual.

**Distinguishing feature** — Unlike a crash, the WebUI **keeps
responding**, just slowly. It is not stuck; it is CPU-starved.

**Cause** — Before v1.1.0, the soft memory limit was hardcoded
to 80 MB regardless of profile. On `ultimate`, the actual
working set approaches 200 MB. The Go runtime reacted to the
80 MB limit by running GC continuously, consuming CPU that
should have been spent serving requests.

**Diagnostic**:

**Step 1 — Confirm the limit is the v1.0.0 hardcoded value**:

```bash
# Check the actual limit reported by runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '.memory_limit_mb'
```

- If you are running v1.0.0 (or older), the value will be `80`
  no matter which profile is active.
- If you are running v1.1.0+, it should match the profile
  (see §4.12).

**Step 2 — Confirm CPU is the bottleneck (not RAM)**:

```bash
# Get the WebUI PID
PID=$(su -c "pgrep -x dnscrypt-webui" | head -1)

# Sample CPU usage over 5 s
su -c "top -b -n 5 -d 1 -p $PID | tail -5"
```

If CPU usage is > 30% while idle, you are likely experiencing
GC thrashing.

**Step 3 — Check for GC log lines**:

```bash
su -c "grep -i 'gc\|memory' /data/local/tmp/dnscrypt_main.log | tail -20"
```

If you see repeated `memory limit adjusted` lines from the
WebUI's own logging (v1.1.0+), that is fine. If you see nothing
and are on v1.0.0, this confirms the hardcoded limit.

**Solution**:

**Option 1 — Update to v1.1.0+** (recommended):

The per-profile limit resolves this without any manual work:

- Switch to `ultimate`: limit becomes 220 MB.
- GC runs only when needed.
- CPU is freed for serving requests.

**Option 2 — If you cannot update, use a lighter profile**:

```bash
# Change to "pro" (120 MB effective on v1.1.0+, ~80 MB on v1.0.0)
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

This will not change the v1.0.0 soft limit (still 80 MB), but
a lighter profile generates less garbage and reduces GC pressure.

**Option 3 — Verify on v1.1.0+**:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info" \
    | jq '{profile_key, memory_limit_mb}'

# Expected if profile is "ultimate":
# {"profile_key": "ultimate", "memory_limit_mb": 220}

# Re-sample CPU
PID=$(su -c "pgrep -x dnscrypt-webui" | head -1)
su -c "top -b -n 5 -d 1 -p $PID | tail -5"
# Expected: idle CPU < 5%
```

**Related sections**:
- §4.12 — Memory limit issues (overview)
- §5.14 — Profile key problems
- §8.5 — Continuous auth I/O (related performance)
- §15.13 — Memory diagnostics helper (v1.1.0)

**Reference**: [SECURITY.md](SECURITY.md) §5.30.1; [ARCHITECTURE.md](ARCHITECTURE.md) §10.1, §11.22.

---

## 7. Blocklist Issues

### 7.1 "List is empty"

**Loop**:
```bash
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/blocklist*"

# If blocklist.raw is empty:
# → Open WebUI → select a list → Apply
```

### 7.2 "Apply" always fails

**Solution**:
```bash
# 1. Test the connection
su -c "curl -I https://cdn.jsdelivr.net"

# 2. Try a manual download
su -c "curl -o /tmp/test.txt https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
wc -l /tmp/test.txt

# 3. If manual works but WebUI fails
su -c "tail -100 /data/local/tmp/dnscrypt_main.log"
```

### 7.3 "Custom Rules are not applied"

**Solution**: ensure `v1.2.0` (or `v1.0.0+`).

### 7.4 "Allowlist does not exclude the domain"

**Solution**:
```bash
# 1. Verify the actual domain
# WebUI → Logs → search

# 2. Use the wildcard format:
*.googleadservices.com

# 3. Clear the DNS cache
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 7.5 Denylist does not block

**Loop**:
```bash
su -c "grep 'example.com' /data/adb/modules/dnscrypt-proxy-webui/proxy/blocklist.txt"
su -c "grep 'CUSTOM_DENYLIST' /data/adb/modules/dnscrypt-proxy-webui/proxy/blocklist.txt"
```

### 7.6 Conflict 409 when saving

**Solution**: reload the page (F5). The session will obtain a new hash.

### 7.7 Blocklist inconsistent on concurrent edit (RACE-1)

**Symptom**:
- Rare, but can happen:
  - `update_profile` is running (downloading a new list).
  - At the same time, you save the `allowlist` from the WebUI.
  - After both complete, `blocklist.txt` contains **inconsistent rules**:
    - deleted rules (that should have been deleted).
    - duplicated rules.
    - rules from an old `allowlist` + a new `blocklist.raw`.

**Sub-symptoms**:
- Some sites remain blocked even after being added to the allowlist.
- Some domains in the denylist are not blocked.
- `blocklist.txt` size looks odd.

**Cause (before v1.0.0)**:
```go
func rebuildBlocklist() error {
    // ← no lock!
    allowData, _ := os.ReadFile(ALLOWLIST_FILE)
    // ...
    atomicWriteStream(BLOCKLIST_FILE, ...)
    return nil
}
```

Two functions call `rebuildBlocklist`:
1. `updateProfile` (in a goroutine).
2. `atomicSaveRulesInternal` (in an HTTP handler).

**Without a lock**: interleaved reads → inconsistent `BLOCKLIST`.

**Solution**:
- Update to `v1.2.0` (or `v1.0.0+`).
- Now `rebuildBlocklist`:
  ```go
  var rebuildMu sync.Mutex

  func rebuildBlocklist() error {
      rebuildMu.Lock()
      defer rebuildMu.Unlock()
      // ...
  }
  ```

**How to verify?**
```bash
# 1. static audit
grep -qE 'rebuildMu[[:space:]]\+sync\.Mutex' proxy/main.go && echo "✅ declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"

# 2. Stress test on the device
# Open two browser tabs:
#   Tab 1: update_profile (apply a new list)
#   Tab 2: save_allowlist (add a domain)
# Do both at the same time
# Result: blocklist.txt is consistent (no corruption)
```

**Effect**:
- ✅ `BLOCKLIST` always consistent.
- ⚠️ Slight delay during concurrent edits (acceptable — rare operation).

**v1.2.0 parallel**: `backupMu` uses the same pattern for
`createAutoBackup`. See §4.14 and [`docs/BACKUP.md`](BACKUP.md) §12.5.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

### 7.8 append_denylist requires content (BUG-A — v1.2.0)

**Symptom**:
- You call `POST /api/append_denylist` (as in v1.1.0 or earlier):
  ```bash
  curl -X POST -b /tmp/cookies.txt \
      http://127.0.0.1:9090/api/append_denylist
  ```
- Result (v1.2.0):
  ```json
  {
    "status": "error",
    "message": "Missing or empty 'content' parameter"
  }
  ```

**Is this a bug?**
- No — intentional v1.2.0 change (BUG-A fix).
- In earlier drafts of v1.2.0, `appendDenylist` took no arguments
  and re-saved the current denylist unchanged, producing a no-op
  that still consumed a pre-critical backup. That behavior has
  been removed.

**The v1.2.0 contract**:

`POST /api/append_denylist` **requires** a `content` parameter.

**Response — rules applied (changed)**:

```json
{
  "status": "ok",
  "changed": true,
  "message": "Processed 250000 rules",
  "hash": "xyz789...",
  "allow_hash": "abc123...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Response — no change**:

```json
{
  "status": "ok",
  "changed": false,
  "message": "No changes detected",
  "hash": "xyz789...",
  "allow_hash": "abc123...",
  "deny_hash": "xyz789...",
  "entries": 250000
}
```

**Solution**:

**Send the `content` parameter** (URL-encoded):

```bash
# 1. With cURL
curl -X POST -b /tmp/cookies.txt \
    --data-urlencode "content=facebook.com
tiktok.com" \
    http://127.0.0.1:9090/api/append_denylist

# 2. From a script
CONTENT=$(cat new_domains.txt)
curl -X POST -b /tmp/cookies.txt \
    --data-urlencode "content=$CONTENT" \
    http://127.0.0.1:9090/api/append_denylist | jq
```

**Or use `POST /api/save_denylist`** with the full new content:

```bash
NEW_DENY=$(cat /data/adb/modules/dnscrypt-proxy-webui/proxy/denylist.txt)
NEW_DENY="${NEW_DENY}
facebook.com
tiktok.com"

curl -X POST -b /tmp/cookies.txt \
    --data-urlencode "denylist=$NEW_DENY" \
    http://127.0.0.1:9090/api/save_denylist | jq
```

**Note for WebUI users**: The current WebUI does **not yet** send a
`content` parameter. This means the WebUI itself does not use the
`append_denylist` endpoint — it uses `save_denylist` for full
content updates. The WebUI-side update to use `append_denylist`
is planned for v1.3.0.

**Reference**: [`docs/API.md`](API.md) §6.2.7;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §12.8.

---

## 8. Performance and Battery Issues

### 8.1 "Battery drains quickly"

**Loop**:
```bash
su -c "dumpsys batterystats | grep dnscrypt"

# Stop auto-restart if it causes loops
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# AUTO_RESTART_DNS=0
# AUTO_RESTART_WEBUI=0

su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 8.2 "Memory is full"

**Loop**:
```bash
su -c "cat /proc/\$(cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.pid)/status | grep VmRSS"
# Expected: < 20 MB for the DNS engine (dnscrypt-proxy)
```

**Note**: The WebUI process (`dnscrypt-webui`) has its own memory
profile. See §4.12 and §6.10 for the v1.1.0 dynamic memory limit.

### 8.3 Watchdog consumes CPU

**Solution**:
```bash
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/watchdog.sh"
# BACKOFF_BASE=60
```

### 8.4 "Device gets hot"

**Solution**:
- Use `Light` / `Normal` lists instead of `Ultimate`.

### 8.5 Continuous Auth/Config I/O (Fix NEW-6)

**Symptom**:
- Battery drains faster than expected.
- High file I/O (visible via `iotop` or `strace`).

**Cause (before v1.0.0)**:
- `getMonitoringAuth()` read the entire `dnscrypt-proxy.toml` on **every HTTP request**.
- ~5–10 ms per request (on Android).
- 100 req/s → ~1 MB/s I/O.

**Solution**: update to `v1.2.0` (or `v1.0.0+`).

Now:
- Auth cache (60 s TTL).
- ~0.05 ms per request after cache.

**Verify**:
```bash
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ Auth cache present"
```

**Effect**:
| Metric | Before | After |
|---|:---:|:---:|
| 100 req/s | ~1 MB/s I/O | ~0 MB/s |
| Response time | ~5–10 ms | ~0.05 ms |
| Battery consumption | High | Low |

**v1.2.0 note**: The backup layer adds negligible I/O. Rotation
keeps the total footprint under ~2.5 MB. Pre-critical backups
run < 5 s and are serialized by `backupMu`.

**Reference**: [SECURITY.md](SECURITY.md).

---

## 9. Network Issues

### 9.1 Hotspot DNS leak

**Solution**:
```bash
# 1. Add PREROUTING rules
su -c "iptables -t nat -I PREROUTING -i wlan+ -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"
su -c "iptables -t nat -I PREROUTING -i wlan+ -p tcp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"

# 2. USB Tethering
su -c "iptables -t nat -I PREROUTING -i rndis0 -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"

# 3. Bluetooth Tethering
su -c "iptables -t nat -I PREROUTING -i bt-pan0 -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"

# 4. Open the permission
su -c "iptables -I FORWARD -i wlan+ -p udp --dport 5354 -j ACCEPT"
su -c "iptables -I FORWARD -i wlan+ -p tcp --dport 5354 -j ACCEPT"

su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 9.2 Android < 11 — Hotspot bypass

**Loop**:
```bash
uname -r
su -c "ip link show | grep -E 'wlan|rndis|usb'"
su -c "iptables -t nat -I PREROUTING -i wlan0 -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"
```

### 9.3 dnsmasq conflict

**Loop**:
```bash
su -c "ps -ef | grep dnsmasq"
su -c "iptables -t nat -I OUTPUT -p udp --dport 53 -o lo -j ACCEPT"
su -c "iptables -t nat -I OUTPUT -p udp --dport 53 -d 127.0.0.1 -j ACCEPT"
```

### 9.4 VPN apps conflict

**Solution**: use only one of them.

### 9.5 Android 11+ Private DNS conflict

**Solution**:
```bash
su -c "settings delete global private_dns_mode"
```

### 9.6 USB Tethering does not work

**Loop**:
```bash
su -c "ip link show | grep -E 'rndis|usb'"
su -c "iptables -t nat -I PREROUTING -i <interface> -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"
```

### 9.7 "DNS over TLS" does not work

**Solution**: use DNSCrypt or DoH (port 443).

### 9.8 IPv6 leak

**Loop**:
```bash
su -c "cat /proc/net/if_inet6"
# Ensure the TOML has: ipv6_servers = false
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n -v"
```

---

## 10. Log Issues

### 10.1 "Log file is empty"

**Loop**:
```bash
su -c "ls -la /data/local/tmp/dnscrypt_main.log"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 10.2 "Log file too large"

**Solution**:
```bash
su -c "du -h /data/local/tmp/dnscrypt_main.log"
su -c "> /data/local/tmp/dnscrypt_main.log"
```

### 10.3 "Log rotation does not work"

**Loop**:
```bash
su -c "grep -E 'MAX_LOG_SIZE|LOG_LEVEL' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
```

### 10.4 Backup log lines (v1.2.0)

**What to look for**:

```bash
su -c "grep -iE 'auto-backup|backup|restore|rotate|orphan|txn-' \
    /data/local/tmp/dnscrypt_main.log | tail -30"
```

**Expected log lines** (examples):

```text
[2026-09-29T15:00:00Z] 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB
[2026-09-29T15:00:05Z] 📢 Restored 5 user files from backup
[2026-09-29T15:00:30Z] 🧹 cleanupOldTransactions: removed 1 COMMIT'd txn
[2026-09-29T15:30:00Z] 💾 auto-backup (reason=pre-allowlist-save): 5 file(s)
[2026-09-29T15:30:01Z] 🔄 rotate_backups: kept 21 snapshot(s)
```

**If backups are failing silently**:

- **Before BUG-2 fix**: `createAutoBackup` discarded stderr, so a
  failed shell command left no trace.
- **After BUG-2 fix (v1.2.0)**: stderr is captured and logged.
- If you see no backup lines at all after a save operation, check:
  ```bash
  su -c "grep -iE 'backup' /data/local/tmp/dnscrypt_main.log | tail -20"
  ```

---

## 11. Firewall Issues

### 11.1 "nftables not available"

**Solution**:
```bash
uname -r
# If < 4.14 → the system will fall back to iptables automatically
```

### 11.2 "iptables -t nat: Table does not exist"

**Loop**:
```bash
su -c "lsmod | grep -E 'nat|iptable'"
su -c "which nft"
```

### 11.3 "PERMISSION_DENIED"

**Solution**: use `su -c`.

### 11.4 "Rules are not persistent"

**Solution**:
- `service.sh` reapplies them on boot.
```bash
su -c "cat /data/local/tmp/dnscrypt_main.log | grep manage_firewall"
```

### 11.5 "DNS works on Wi-Fi only"

**Loop**:
```bash
su -c "ip route show table all"
su -c "iptables -t nat -I OUTPUT -o rmnet+ -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"
```

### 11.6 Custom Chains missing or corrupt (Orphan Fix)

**Symptom**:
- `DNSCRYPT_OUT` or `DNSCRYPT_OUT6` missing.
- Or: present but empty.
- Or: `iptables -t nat -L OUTPUT` contains direct DNAT/RETURN rules.
- DNS does not work even though the service "works".

**Verify**:
```bash
# 1. Show OUTPUT
su -c "iptables -t nat -L OUTPUT -n --line-numbers"
# Expected: only two rules (jump rules)

# 2. Show DNSCRYPT_OUT
su -c "iptables -t nat -L DNSCRYPT_OUT -n --line-numbers"
```

**Solution**:
```bash
# 1. Clean up manually
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

# 2. Rebuild
su -c ". /data/adb/modules/dnscrypt-proxy-webui/functions.sh; manage_firewall 1"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #17.

### 11.7 Orphans accumulated from older versions

**Symptom**:
- `OUTPUT` contains dozens of `RETURN` rules for different IPs.

**Solution**:
```bash
# Delete all RETURN rules in OUTPUT
while iptables -t nat -L OUTPUT -n | grep -q 'RETURN'; do
    line=$(iptables -t nat -L OUTPUT -n --line-numbers | grep 'RETURN' | head -1 | awk '{print $1}')
    su -c "iptables -t nat -D OUTPUT $line"
done

# Delete all DNAT rules
while iptables -t nat -L OUTPUT -n | grep -q 'DNAT'; do
    line=$(iptables -t nat -L OUTPUT -n --line-numbers | grep 'DNAT' | head -1 | awk '{print $1}')
    su -c "iptables -t nat -D OUTPUT $line"
done

# Rebuild
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 11.8 Test Custom Chains

```bash
# Show both chains side by side
su -c "iptables -t nat -L OUTPUT -n --line-numbers | head -10"
su -c "iptables -t nat -L DNSCRYPT_OUT -n --line-numbers"
```

### 11.9 "OUTPUT full of DNAT/RETURN rules" (quick summary)

```bash
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'DNAT|RETURN'"
# Expected: 0

su -c "iptables -t nat -L OUTPUT -n | grep -c 'DNSCRYPT_OUT'"
# Expected: 2 (udp + tcp)
```

### 11.10 Shell injection in MODDIR (Fix NEW-5)

**Symptom**:
- Very rare (theoretical), but:
  - WebUI fails in `isPortOpen` with no clear reason.
  - Or: with **spaces** in `MODDIR` (e.g. `/data/adb/modules/my module/`).
  - Or: with shell metacharacters in the path (`;`, `&`, `$`, ...).

**Cause (before v1.0.0)**:
```go
cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", MODDIR, port)
//    ↑ MODDIR unquoted
```

If `MODDIR = "/tmp/foo bar"`:
- The command fails: `. /tmp/foo bar/functions.sh` → `bar/functions.sh` not found.

If `MODDIR = "/tmp/evil;rm -rf/"`:
- **Full injection**: `. /tmp/evil;rm -rf//functions.sh` → runs!

**Impact**:
- Theoretically: `MODDIR` comes from `os.Executable()` — a normal user cannot change it.
- However, `defense in depth` is required.
- No practical vector today.

**Solution**:
- Update to `v1.2.0` (or `v1.0.0+`).
- v1.0.0 extended `shellQuote` covers 20 shell metacharacters.
- v1.1.0 extends it further to 24 (`{`, `}`, `\n`, `\t` added).
- v1.2.0's `copy_with_context` helper uses `shellQuote` for all
  dynamic paths during backup restore.

**Verify**:
```bash
# 1. static audit
grep -q 'func shellQuote' proxy/main.go && echo "✅ shellQuote present"
USAGE=$(grep -c 'shellQuote(MODDIR)' proxy/main.go)
[ "$USAGE" -ge 3 ] && echo "✅ shellQuote used $USAGE times"

# 2. v1.1.0 extended charset
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"

# 3. v1.2.0: copy_with_context uses shellQuote
su -c "grep -A5 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/functions.sh | \
       grep -q 'shellQuote' && echo '✅ copy uses shellQuote'"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #31 + §5.30.2.

---

## 12. Upgrade and CI Issues

### 12.1 Upgrade fails

**Loop**:
```bash
df -h /data
df -h /sdcard
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
# Reinstall from Magisk
```

### 12.2 "Credentials changed after upgrade"

**Solution**:
```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

### 12.3 "Settings lost"

**Solution**: 
- **v1.2.0**: The 10 defensive layers preserve all 5 config files
  automatically. See §12.7.
- **Before v1.2.0**: keep a manual backup before upgrade.

### 12.4 "Old modules detected"

**Solution**:
- From WebUI → Settings → Old Modules → Delete.
- Or manually:
  ```bash
  su -c "rm -rf /data/adb/modules/<old_module_folder>"
  ```

### 12.5 After upgrade, orphans in the firewall

**Solution**: see §11.7.

### 12.6 CI fails on Linux (Fix #2)

**Symptom**:
- CI on GitHub Actions fails continuously.
- Error message:
  ```text
  fork/exec /system/bin/sh: no such file or directory
  ```

**Cause (before v1.0.0)**:
```go
// runShell in main.go
command := exec.CommandContext(ctx, "/system/bin/sh", "-c", cmd)
//                                  ^^^^^^^^^^^^^^^^
//                                  Android-only path
```

- `/system/bin/sh` does **not exist** on Ubuntu/macOS.
- `exec` fails → CI fails.
- The problem meant **CI could never succeed**.

**Verify**:
```bash
# 1. Test locally on Linux
cd proxy
go build -buildvcs=false -trimpath -o /tmp/test-main main.go
# Before the fix:
# FAIL

# 2. Check for the path in the code
grep -n '/system/bin/sh' proxy/main.go
# Before the fix:
# 245: command := exec.CommandContext(ctx, "/system/bin/sh", "-c", cmd)
```

**Solution**:

**Option 1 — Update (recommended)**:
- Update to `v1.2.0` (or `v1.0.0+`).
- Now `runShell` uses:
  ```go
  func getSystemShell() string {
      systemShellOnce.Do(func() {
          candidates := []string{"/system/bin/sh", "/bin/sh", "/usr/bin/sh"}
          for _, c := range candidates {
              if _, err := os.Stat(c); err == nil {
                  systemShellPath = c
                  return
              }
          }
          systemShellPath = "sh"
      })
      return systemShellPath
  }

  func runShell(cmd string) error {
      command := exec.CommandContext(ctx, getSystemShell(), "-c", cmd)
      // ...
  }
  ```

**Option 2 — Verify the fix**:
```bash
# static audit
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix present"
! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' proxy/main.go && echo "✅ No hardcoded path"

# Build test
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go
```

**Effect after the fix**:
- ✅ CI passes on Ubuntu.
- ✅ Works on macOS (dev).
- ✅ Works on Android (as before).
- ✅ `getSystemShell` cached in `sync.Once` (no overhead).

**Reference**: [ARCHITECTURE.md](ARCHITECTURE.md).

### 12.7 Settings lost after upgrade (Fix #3 — superseded in v1.2.0)

**Symptom**:
- After upgrading the module, `webui.conf` is reset:
  - `PORT` back to `9090`.
  - `BIND_ADDR` back to `127.0.0.1`.
  - `LOG_LEVEL` back to `info`.
- Or `dnscrypt-proxy.toml` loses custom credentials.
- Or `allowlist.txt` / `denylist.txt` are reset (rare).

**Cause (before v1.0.0)**:

**Step 1**: `customize.sh` calls `unzip -o`.
```bash
unzip -o "$ZIPFILE" 'proxy/*' ...
# ← extracts the default webui.conf over the custom one
```

**Step 2**: `[13]` tries migration.
```bash
for mod in /data/adb/modules/*; do
    [ "$mod" = "$MODPATH" ] && continue  # ← never matches!
    for f in webui.conf dnscrypt-proxy.toml ...; do
        if [ -f "$mod/proxy/$f" ] && [ ! -f "$BIN_DIR/$f" ]; then
            # ^^^^^^^^^^^^^^^^^^^^^ ← false (file exists after unzip)
            cp -f "$mod/proxy/$f" "$BIN_DIR/"
        fi
    done
done
```

**Result**:
- `unzip` extracts defaults → `$BIN_DIR/webui.conf` **exists**.
- The condition `[ ! -f "$BIN_DIR/$f" ]` = **false**.
- **No copy** → user settings are lost.

**v1.0.0 solution**: `customize.sh` backs up 5 files before
`unzip` and restores them after (mechanism:
`/data/local/tmp/dnscrypt-upgrade-backup-$$`).

**v1.2.0 supersession**: The v1.0.0 mechanism is replaced by the
10 defensive layers (see [`docs/BACKUP.md`](BACKUP.md) §1.3).

The v1.0.0 mechanism had two limitations:
- `/data/local/tmp/` is **cleared on reboot**.
- `/data/local/tmp/` is **deleted on uninstall**.

The v1.2.0 persistent backup at
`/sdcard/dnscrypt-webui-backup/` survives reboot, uninstall, and
factory reset of `/data`.

**Verify v1.2.0 is active**:

```bash
su -c "grep -q 'CANDIDATE_SOURCES' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ Layer 1 (multi-source)'"
su -c "grep -q 'PERSISTENT_BACKUP' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ Layer 2 (persistent backup)'"
su -c "grep -q 'begin_transaction' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ Layer 4 (transaction)'"
su -c "grep -q 'copy_with_context' /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
       echo '✅ Layer 6 (SELinux)'"
```

**Test the fix**:

```bash
# 1. Save the current settings
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf" > /sdcard/before.txt

# 2. Change PORT to 9191
su -c "sed -i 's/^PORT=9090/PORT=9191/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 3. Install a new ZIP
# (via Magisk Manager)

# 4. After install, verify
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Before v1.0.0: PORT=9090 (lost!)
# v1.0.0+:      PORT=9191 (preserved ✅)
# v1.2.0+:      PORT=9191 (preserved + a snapshot exists)

# 5. v1.2.0: verify a snapshot was created
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
```

**Files preserved (5)**:
| File | Purpose |
|---|---|
| `webui.conf` | WebUI/Dashboard settings |
| `dnscrypt-proxy.toml` | DNSCrypt settings + credentials |
| `selected_profile.txt` | Active profile |
| `allowlist.txt` | Custom rules |
| `denylist.txt` | Custom rules |

**Not preserved (rebuilt)**:
- `blocklist.txt` — rebuilt from `blocklist.raw`.
- `blocklist.raw` — downloaded from the internet.
- `run/` — re-created.
- `public-resolvers.md` — cache regenerated.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #26 +
[`docs/BACKUP.md`](BACKUP.md) §1.

### 12.8 Backup layer fails after upgrade (v1.2.0)

**Symptom**:
- After upgrading to v1.2.0, the log contains:
  ```text
  ⚠️ auto-backup failed (continuing)
  ⚠️ PERSISTENT_BACKUP not writable
  ```
- Or `runtime_info.backups.available` is 0.
- Or `backups.last_backup_name` is null.

**Cause**:
- `/sdcard/` was not mounted when `customize.sh` ran.
- Or `/sdcard/` was full (< 10 MB free).
- Or the FUSE mount was slow on this ROM.

**Diagnosis**:

```bash
# 1. Check the backup directory
su -c "ls -la /sdcard/dnscrypt-webui-backup/ 2>&1"

# 2. Check available space
su -c "df -h /sdcard"

# 3. Check the install log
su -c "grep -iE 'backup|PERSISTENT' /data/local/tmp/dnscrypt_install.log | tail -20"

# 4. Check runtime_info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
```

**Solution**:

**Step 1 — Reboot** (to let `service.sh` retry):

```bash
su -c "reboot"
```

**Step 2 — Wait for boot and check again**:

```bash
sleep 60
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
# Expected: available >= 1
```

**Step 3 — If still failing, trigger a manual backup**:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Step 4 — If that fails, check the shell script**:

```bash
# Bash syntax
bash -n /data/adb/modules/dnscrypt-proxy-webui/functions.sh
# Should return no errors

# Function presence
su -c "grep -c 'backup_user_files\|rotate_backups\|ensure_backup_dir' \
    /data/adb/modules/dnscrypt-proxy-webui/functions.sh"
# Expected: >= 3
```

**Step 5 — As a last resort, create the directory manually**:

```bash
su -c "mkdir -p /sdcard/dnscrypt-webui-backup"
su -c "chmod 0700 /sdcard/dnscrypt-webui-backup"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §10.1, §10.2, §10.4;
§4.13 in this file.

### 12.9 Recovery mode correctness (FIX-1 — v1.2.0)

**Symptom**:
- You triggered recovery mode (`touch recovery && reboot`).
- After reboot, only 3 of the 5 config files are restored.
- `webui.conf` and `dnscrypt-proxy.toml` show the ZIP's defaults,
  not the preserved values.

**Cause (early v1.2.0 draft only)**:
- The ZIP extraction step (`customize.sh §[9]`) ran **after** the
  recovery restore (`§[8a]`).
- It overwrote the two files with the ZIP's defaults.
- The subsequent restore step (`§[9c]`) was skipped in recovery
  mode — the corrupted files were never re-fixed.

**The fix (FIX-1) — snapshot-and-reapply strategy**:

Rather than reordering the ZIP extraction steps (which would
require maintaining a duplicate exclusion list that depends on
knowing the ZIP's contents), the final v1.2.0 release uses a
**snapshot-and-reapply** approach:

| Phase | Section | What happens |
|---|---|---|
| **A** | `§[8a]` | Restore 5 files from `$RESTORE_SOURCE` into `$MODPATH/proxy/` **AND** copy each file to `$MODPATH/.recovery_snapshot/` |
| **B** | `§[9]` | Extract the ZIP normally. This overwrites `webui.conf` and `dnscrypt-proxy.toml` with the ZIP's defaults (unavoidable without knowing the ZIP's contents) |
| **C** | `§[9b]` | Move root-level web assets into `web/` |
| **D** | `§[9b2]` | Re-apply the 5 files from `$MODPATH/.recovery_snapshot/` back into `$MODPATH/proxy/` |
| **E** | `§[9c]` | Skipped when `RECOVERY_MODE=1` — already handled by A + D |

**Partial re-application**: If `[9b2]` re-applies fewer files
than were snapshotted (e.g. one file is missing or empty), the
snapshot directory is **preserved** at
`$MODPATH/.recovery_snapshot/` so the user can recover the
remaining files manually.

**Verify you are on the fixed version**:

```bash
# 1. Module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# → must be version=v1.2.0

# 2. The snapshot directory constant must be present
su -c "grep -q 'RECOVERY_SNAPSHOT_DIR' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (snapshot dir)'"

# 3. The re-apply block (§[9b2]) must be present
su -c "grep -q 'Re-applying recovery snapshot' \
    /data/adb/modules/dnscrypt-proxy-webui/customize.sh && \
    echo '✅ FIX-1 present (§[9b2] re-apply block)'"
```

**If the fix is missing**: reinstall the module from the v1.2.0 ZIP.

**Test procedure** (full):

See §14.5 (Recovery mode).

**Reference**: [`docs/SECURITY.md`](SECURITY.md) §5.32;
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §3.10.

---

## 13. Uninstall Issues

### 13.1 uninstall.sh did not clean files

**Loop**:
```bash
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
su -c "rm -rf /data/local/tmp/dnscrypt*"

# Delete Custom Chains
su -c "iptables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"

su -c "ip6tables -t nat -D OUTPUT -p udp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -D OUTPUT -p tcp --dport 53 -j DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -F DNSCRYPT_OUT6 2>/dev/null"
su -c "ip6tables -t nat -X DNSCRYPT_OUT6 2>/dev/null"

su -c "settings delete global private_dns_mode"
```

### 13.2 "DNS does not work after removal"

**Solution**:
```bash
while iptables -t nat -L OUTPUT -n | grep -qE 'RETURN|DNAT'; do
    line=$(iptables -t nat -L OUTPUT -n --line-numbers | grep -E 'RETURN|DNAT' | head -1 | awk '{print $1}')
    su -c "iptables -t nat -D OUTPUT $line"
done

su -c "svc data disable && svc data enable"
su -c "svc wifi disable && svc wifi enable"
```

### 13.3 "Backup directory remaining"

> **v1.2.0 note**: `uninstall.sh` **preserves** the persistent
> backup directory at `/sdcard/dnscrypt-webui-backup/`. This is
> intentional — a future reinstall can restore your settings
> automatically (via Layer 1 multi-source detection).

**Verify what survived**:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# Expected: current/, <ts>-<version>/, .last_stable, ...
```

**If you want to remove it**:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**If a legacy v1.0.0 backup dir is present**:

```bash
su -c "ls -la /data/local/tmp/dnscrypt_backup_uninstall/"
# This is a legacy artifact from v1.0.0
# uninstall.sh v1.2.0 removes it automatically
# To remove manually:
su -c "rm -rf /data/local/tmp/dnscrypt_backup_uninstall/"
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §5.6; §13.5 in this file.

### 13.4 Orphan-txn preserved on uninstall (v1.2.0)

**Symptom**:
- After uninstalling the module, an `orphan-txn-*/` directory
  appears under `/sdcard/dnscrypt-webui-backup/`.

**Is this a bug?**
- No — intentional.
- An `orphan-txn-*` directory is a **preserved unfinished
  transaction**.
- It was created when `uninstall.sh` found a `txn-*` directory
  with `.state=START` — a signal that an install was interrupted
  mid-flight.
- The orphan may contain the **only** copy of the user's data.

**Action**:

```bash
# 1. Inspect the state
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"
# Expected: START

# 2. Inspect the contents
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/"

# 3. Inspect the manifest (if present)
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.manifest.json 2>/dev/null | jq"
```

**DO NOT DELETE BLINDLY**.

**If you want to keep it long-term**:

```bash
# Move to a safe location
su -c "mkdir -p /sdcard/orphan-backup"
su -c "cp -a /sdcard/dnscrypt-webui-backup/orphan-txn-* /sdcard/orphan-backup/"
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §10.5;
[`docs/EMERGENCY.md`](EMERGENCY.md) §4.5.

### 13.5 Preserved backup directory after uninstall (v1.2.0)

**What survives**:

| Item | Preserved? |
|---|:---:|
| `current/` (live snapshot) | ✅ |
| All `<ts>-<version>/` snapshots | ✅ |
| `orphan-txn-*/` | ✅ |
| `.last_stable` pointer | ✅ |
| `.upgrade_history.json` | ✅ |
| `README.md` | ✅ |

**What is removed**:

| Item | Removed? |
|---|:---:|
| `txn-*` with `.state=COMMIT` | 🗑️ |
| `txn-*` with `.state=ROLLBACK` | 🗑️ |
| Legacy v1.0.0 backup dir | 🗑️ |
| External recovery trigger | 🗑️ |

**Why this design?** So a future reinstall can recover your 5
config files automatically (via Layer 1 multi-source detection).

**Verify after uninstall**:

```bash
su -c "ls -la /sdcard/dnscrypt-webui-backup/"
# Expected: current/, <ts>-<version>/…, .last_stable, …

su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
# Expected: <snapshot-name>
```

**To remove it manually**:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §5.6.

---

## 14. Emergency Situations

### 14.1 "Device does not boot after install (Bootloop)"

**Method 1: From Recovery**
```bash
adb shell
mount /data
rm -rf /data/adb/modules/dnscrypt-proxy-webui
# reboot
```

**Method 2: Safe Mode**
- Reboot into Safe Mode.
- Remove the module from Magisk.

**Method 3: ADB**
```bash
adb shell su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
adb reboot
```

**v1.2.0 alternative**: use recovery mode (§14.5) — it restores
the last known-good config without reinstalling.

### 14.2 "Wi-Fi does not work at all"

**Loop**:
```bash
su -c "iptables -t nat -F OUTPUT"
su -c "iptables -t nat -F DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -X DNSCRYPT_OUT 2>/dev/null"
su -c "iptables -t nat -F PREROUTING"
su -c "svc wifi disable && svc wifi enable"
```

### 14.3 "DNS works but no internet"

**Loop**:
```bash
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/disable"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 14.4 Orphans block the internet after uninstall

**Solution**:
```bash
su -c "iptables -t nat -F OUTPUT"
su -c "svc data disable && svc data enable"
su -c "svc wifi disable && svc wifi enable"
nslookup google.com
```

**Warning**: `iptables -t nat -F OUTPUT` clears all rules. If you have a VPN, delete the rules individually (§13.2).

### 14.5 Recovery mode (v1.2.0)

**When to use it**:

- The module is unbootable but you can run commands via ADB.
- User data is corrupted but the backup directory is intact.
- You want a "one-shot" recovery without manual file copying.
- You upgraded from a version with the v1.1.0 data-loss bug and
  want to recover from the persistent backup.

**Pre-flight checklist**:

- [ ] You have a recent snapshot: `su -c "ls /sdcard/dnscrypt-webui-backup/"`.
- [ ] `.last_stable` is set: `su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"`.
- [ ] You recorded the current profile:
  `su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"`.

**Procedure**:

```bash
# 1. Trigger recovery (module-specific)
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"
su -c "reboot"

# Or, if the module folder is inaccessible (external trigger)
su -c "touch /data/adb/dnscrypt-recovery"
su -c "reboot"
```

**On next boot**:

`customize.sh` runs in **recovery mode** and restores the last
known-good snapshot from `/sdcard/dnscrypt-webui-backup/`.

**Recovery source priority**:
1. `.last_stable` → the pointer file.
2. `current/` → the live snapshot.
3. In-place `proxy/` → fallback.

**Verify the recovery** (after boot, ~60s):

```bash
# 1. All 5 files present
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.conf"
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.toml"
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt"

# 2. Profile restored
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
# Expected: your original profile

# 3. Trigger files consumed
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>&1"
# Expected: No such file or directory
su -c "ls /data/adb/dnscrypt-recovery 2>&1"
# Expected: No such file or directory

# 4. Full diagnostic
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**If the trigger file reappears**: see [`docs/EMERGENCY.md`](EMERGENCY.md)
§3.4 (recovery mode runs twice on some devices).

**Full guide**: [`docs/EMERGENCY.md`](EMERGENCY.md) §9.

---

## 15. Helper Tools

### 15.1 status.sh

```bash
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --short
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose
```

**v1.1.0 note**: `status.sh` now also reports the active profile and
the expected memory limit.

**v1.2.0 addition**: `--diagnose` mode (Layer 10) — full diagnostic
report including the backup listing, in-flight transactions, and
recovery-mode state. See §15.14 for details.

### 15.2 action.sh

```bash
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --check
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --status
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup    # v1.2.0
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --diagnose  # v1.2.0
```

**v1.2.0 additions**:
- `--backup` — trigger a manual backup.
- `--diagnose` — full diagnostic report.

**Expected output of `--backup`**:

```text
╔══════════════════════════════════════════════════════════╗
║  💾 DNSCrypt – Manual Backup                           ║
╚══════════════════════════════════════════════════════════╝

  Source: /data/adb/modules/dnscrypt-proxy-webui/proxy
  Target: /sdcard/dnscrypt-webui-backup

  ✅ Backup created: .../<ts>-manual-<pid> (5 file(s))

  Current backup state:
    7 snapshot(s), latest 0s ago
```

### 15.3 Firewall Diagnostics

```bash
su -c "
echo '=== IPv4 OUTPUT ==='
iptables -t nat -L OUTPUT -n --line-numbers | head -10

echo ''
echo '=== IPv4 DNSCRYPT_OUT ==='
iptables -t nat -L DNSCRYPT_OUT -n --line-numbers 2>/dev/null || echo '(not present)'

echo ''
echo '=== IPv6 OUTPUT ==='
ip6tables -t nat -L OUTPUT -n --line-numbers 2>/dev/null | head -10

echo ''
echo '=== IPv6 DNSCRYPT_OUT6 ==='
ip6tables -t nat -L DNSCRYPT_OUT6 -n --line-numbers 2>/dev/null || echo '(not present)'

echo ''
echo '=== Orphan count ==='
iptables -t nat -L OUTPUT -n 2>/dev/null | grep -cE 'RETURN|DNAT' || echo 0
"
```

### 15.4 Dashboard Diagnostics

```bash
# 1. Check Content-Type
su -c "curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type"

# 2. Test JSON
su -c "curl -s -b /tmp/cookies.txt http://127.0.0.1:9091/api/metrics" | jq '.total_queries'

# 3. Test monitoring_ui directly
su -c "curl -s http://127.0.0.1:8080/api/metrics | head -5"
```

### 15.5 Runtime Info Diagnostics

```bash
# All fields
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq"

# Ports only (PORT-2)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port, bind_addr}'"

# Profile + memory (v1.1.0 — MEM-1)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'"

# Backups object (v1.2.0 — BAK-1, 7 fields)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
```

### 15.6 dnsleaktest

`https://www.dnsleaktest.com`

### 15.7 Check DNS

```bash
nslookup google.com 127.0.0.1
dig @127.0.0.1 google.com
```

### 15.8 Log Analysis

```bash
grep -c "$(date +%Y-%m-%d)" /data/local/tmp/dnscrypt-blocked.log
grep -i error /data/local/tmp/dnscrypt_main.log | tail -10
grep -i 'watchdog\|ensure_running' /data/local/tmp/dnscrypt_main.log | tail -10
grep -iE 'metrics|proxy|error' /data/local/tmp/dnscrypt_main.log | tail -10
grep -iE 'backup|restore|rotate|orphan|txn-' /data/local/tmp/dnscrypt_main.log | tail -20  # v1.2.0
```

### 15.9 Status File Check

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
# "ON"  → user wants the service running
# "OFF" → user stopped it manually
```

**Important**: `STATUS_FILE` is **read-only** — written only by `startService()` / `stopService()`.

### 15.10 CI Debugging

```bash
# Locally (before push)
cd proxy && go build -buildvcs=false -trimpath -o /tmp/main main.go

# Verify shell path
grep -n 'getSystemShell' proxy/main.go
```

### 15.11 Verification Commands

```bash
# Dashboard JSON
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix #1"

# Shell fallback
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix #2"

# Basic Auth rate limit
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Fix #8"

# Exact matching
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12"

# Login POST-only
grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅ NEW-1"

# readConfPort range
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅ NEW-3"

# /readyz localhost
grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅ NEW-4"

# shellQuote
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5"

# Auth cache
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6"

# RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# PORT-2 (runtime_info)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# MEM-1 (v1.1.0)
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1"

# BAK-1 (v1.2.0 — 7 fields)
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ BAK-1 in_flight_txn"
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'orphan_txn' && echo "✅ BAK-1 orphan_txn"

# BAK-2 (v1.2.0)
grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2"
grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 backupMu"

# BAK-3 / BAK-4 (v1.2.0)
grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"
grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"

# WD-TOKEN (v1.2.0)
grep -q 'loadOrCreateWatchdogToken' proxy/main.go && echo "✅ WD-TOKEN"
```

### 15.12 RACE-1 + PORT-2 Diagnostics

**RACE-1 — rebuildMu mutex**:
```bash
# 1. static audit
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ declared"
grep -A10 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A20 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"

# 2. Runtime check — stop the service, then start it
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
# No panic in /data/local/tmp/dnscrypt_main.log
```

**PORT-2 — runtime_info ports**:
```bash
# 1. static audit (backend)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ backend"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"dashboard_port"' && echo "✅ backend"

# 2. static audit (frontend)
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html"

# 3. Integration (with custom ports)
# change PORT=8081 in webui.conf
su -c "curl -s http://127.0.0.1:8081/api?action=runtime_info | jq '.webui_port'"
# Expected: "8081"
```

### 15.13 Memory Diagnostics Helper (v1.1.0 — MEM-1)

**Purpose**: one-shot script to dump the memory state of the
WebUI process for bug reports or verification.

```bash
#!/system/bin/sh
# memory-diagnostics.sh — v1.1.0+
# Collects: profile_key, memory_limit_mb, RSS, CPU sample, log tail.

echo "=== 1. runtime_info (v1.1.0 fields) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info \
    | jq '{profile_key, memory_limit_mb, version}'

echo ""
echo "=== 2. selected_profile.txt (raw) ==="
cat /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt

echo ""
echo "=== 3. WebUI process RSS ==="
PID=$(pgrep -x dnscrypt-webui | head -1)
if [ -n "$PID" ]; then
    grep VmRSS /proc/$PID/status
else
    echo "WebUI process not running"
fi

echo ""
echo "=== 4. CPU sample (5 s) ==="
if [ -n "$PID" ]; then
    top -b -n 5 -d 1 -p $PID | tail -5
fi

echo ""
echo "=== 5. GC / memory log lines ==="
grep -iE 'memory|gc' /data/local/tmp/dnscrypt_main.log | tail -10

echo ""
echo "=== 6. Expected values ==="
echo "light=80, normal=100, pro=120, proplus=160, ultimate=220 (MB)"
```

**Usage**:

```bash
# Save the script
su -c "cat > /data/local/tmp/memory-diagnostics.sh << 'EOF'
...paste script here...
EOF
chmod +x /data/local/tmp/memory-diagnostics.sh"

# Run it
su -c "sh /data/local/tmp/memory-diagnostics.sh"
```

**Sample output** (on a healthy pro profile):

```
=== 1. runtime_info (v1.1.0 fields) ===
{
  "profile_key": "pro",
  "memory_limit_mb": 120,
  "version": "v1.2.0"
}

=== 2. selected_profile.txt (raw) ===
pro

=== 3. WebUI process RSS ===
VmRSS:     18234 kB

=== 4. CPU sample (5 s) ===
  PID USER         PR  NI VIRT  RES  SHR S[%CPU] %MEM     TIME+ ARGS
 5678 u0_a123      20   0 1.2G  18M  12M S  0.5   0.9  0:12.34 dnscrypt-webui

=== 5. GC / memory log lines ===
2026-09-29 10:00:00 - 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB
2026-09-29 10:05:00 - memory limit adjusted: 80 MB → 120 MB (profile=pro, previous runtime value=120 MB)

=== 6. Expected values ===
light=80, normal=100, pro=120, proplus=160, ultimate=220 (MB)
```

**Interpretation**:

| Field | Healthy | Suspicious |
|---|---|---|
| `profile_key` | matches `selected_profile.txt` | mismatch → see §5.14 |
| `memory_limit_mb` | matches expected for profile | mismatch → see §4.12 |
| `VmRSS` | < 50 MB on light, < 200 MB on ultimate | > 200 MB → check for leak |
| CPU idle | < 5% | > 20% → see §6.10 (GC thrashing) |
| Log line | reported once at startup | repeated "adjusted" lines → check for rapid profile changes |

### 15.14 Backup Diagnostics Helper (v1.2.0 — new)

**Purpose**: one-shot script to dump the full backup state for bug
reports or verification.

```bash
#!/system/bin/sh
# backup-diagnostics.sh — v1.2.0
# Collects: 7-field backups object, directory listing, .last_stable,
# transaction states, recovery triggers, 10-layer function presence.

echo "=== 1. Backup state (7-field object) ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'

echo ""
echo "=== 2. Backup directory listing ==="
ls -la /sdcard/dnscrypt-webui-backup/ 2>&1

echo ""
echo "=== 3. .last_stable pointer ==="
cat /sdcard/dnscrypt-webui-backup/.last_stable 2>&1

echo ""
echo "=== 4. In-flight transactions ==="
ls -la /sdcard/dnscrypt-webui-backup/txn-* 2>&1

echo ""
echo "=== 5. Orphan transactions ==="
ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-* 2>&1
```

**Usage**:

```bash
# Save the script
su -c "cat > /data/local/tmp/backup-diagnostics.sh << 'EOF'
...paste script here...
EOF
chmod +x /data/local/tmp/backup-diagnostics.sh"

# Run it
su -c "sh /data/local/tmp/backup-diagnostics.sh"
```

**Sample output** (on a healthy v1.2.0 install):

```
=== 1. Backup state (7-field object) ===
{
  "available": 7,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-09-29 15:30:00",
  "last_backup_name": "20260929-153000-manual-12345",
  "last_stable": "20260929-095826-v1.2.0-12345",
  "path": "/sdcard/dnscrypt-webui-backup"
}

=== 2. Backup directory listing ===
drwx------  current/
drwx------  20260929-153000-manual-12345/
drwx------  20260929-095826-v1.2.0-12345/
-rw-------  .last_stable
-rw-------  .upgrade_history.json

=== 3. .last_stable pointer ===
20260929-095826-v1.2.0-12345

=== 4. In-flight transactions ===
ls: /sdcard/dnscrypt-webui-backup/txn-*: No such file or directory

=== 5. Orphan transactions ===
ls: /sdcard/dnscrypt-webui-backup/orphan-txn-*: No such file or directory
```

**Interpretation**:

| Field | Healthy | Suspicious |
|---|---|---|
| `available` | ≥ 1 | 0 → see §4.13 |
| `in_flight_txn` | 0 | > 0 → an install is running or interrupted |
| `orphan_txn` | 0 | > 0 → see §13.4 |
| `last_stable` | a valid snapshot name | `null` → see §4.14 |
| `.last_stable` | matches `last_stable` field | mismatch → version mismatch |
| Directory listing | `current/` + ≥ 1 snapshot | missing `current/` → see §4.13 |

### 15.15 Recovery Mode Test Helper (v1.2.0 — new)

**Purpose**: verify the FIX-1 snapshot-and-reapply mechanism on a
real device without reinstalling the module.

> **ℹ️ Portability note (N-4)**: the echoed "next steps" strings use
> the **literal path** (`/data/adb/modules/dnscrypt-proxy-webui`),
> not the `$MODPATH` shell variable. This makes every suggested
> command self-contained and safe to copy-paste into a fresh shell,
> independent of the script's environment.

```bash
#!/system/bin/sh
# recovery-mode-test.sh — v1.2.0
# Verifies FIX-1 by:
#   1. Recording the current PORT value
#   2. Taking a backup
#   3. Triggering recovery mode
#   4. Verifying PORT survived the ZIP extraction
#
# NOTE: all echoed "next steps" use the LITERAL module path
# (/data/adb/modules/dnscrypt-proxy-webui) so that copy-paste
# into a new shell works without a $MODPATH variable in scope.

set -e

MODPATH=/data/adb/modules/dnscrypt-proxy-webui
PERSISTENT_BACKUP=/sdcard/dnscrypt-webui-backup

echo "=== 0. Pre-flight: current state ==="
CURRENT_PORT=$(grep '^PORT=' $MODPATH/proxy/webui.conf | cut -d= -f2)
echo "Current PORT: $CURRENT_PORT"
echo "Current profile: $(cat $MODPATH/proxy/selected_profile.txt)"

echo ""
echo "=== 1. Record baseline ==="
echo "PORT=$CURRENT_PORT" > /sdcard/recovery-test-before.txt

echo ""
echo "=== 2. Take a manual backup ==="
sh $MODPATH/action.sh --backup

echo ""
echo "=== 3. Verify snapshot exists ==="
ls -la $PERSISTENT_BACKUP/
cat $PERSISTENT_BACKUP/.last_stable

echo ""
echo "=== 4. Verify FIX-1 markers in customize.sh ==="
grep -q 'RECOVERY_SNAPSHOT_DIR' $MODPATH/customize.sh && \
    echo "✅ RECOVERY_SNAPSHOT_DIR present"
grep -q 'Re-applying recovery snapshot' $MODPATH/customize.sh && \
    echo "✅ §[9b2] re-apply block present"

echo ""
echo "=== 5. Trigger recovery (manual step required) ==="
echo "Run these commands manually:"
echo "  su -c 'touch /data/adb/modules/dnscrypt-proxy-webui/recovery'"
echo "  su -c 'reboot'"
echo ""
echo "After reboot, run:"
echo "  su -c 'sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose'"
echo "  su -c 'grep \"^PORT=\" /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf'"
echo "  # Expected: PORT=$CURRENT_PORT (preserved)"
echo ""
echo "Also verify no leftover snapshot dir:"
echo "  su -c 'ls -la /data/adb/modules/dnscrypt-proxy-webui/.recovery_snapshot/ 2>&1'"
echo "  # Expected: No such file or directory (cleaned up by §[9b2])"

echo ""
echo "=== 6. Verify no orphan txn created ==="
ls -la $PERSISTENT_BACKUP/orphan-txn-* 2>&1 || \
    echo "(no orphan txn — good)"
```

**Usage**:

```bash
su -c "sh /data/local/tmp/recovery-mode-test.sh"
```

**Expected results**:

1. **Before reboot**: `PORT=9191` (or whatever you set), backup created.
2. **After reboot**:
   - `PORT=9191` still present (preserved by FIX-1).
   - `/data/adb/modules/dnscrypt-proxy-webui/.recovery_snapshot/` removed (cleaned up by §[9b2]).
   - No `orphan-txn-*` created.
   - `recovery` trigger file removed.

**If the test fails**:

- Check `PORT` value after reboot:
  - If it reverted to `9090`, FIX-1 may not be present → reinstall.
  - If it stayed but `.recovery_snapshot/` remains, partial re-apply
    happened → inspect the directory manually.

**Reference**: §12.9, [`docs/SECURITY.md`](SECURITY.md) §5.32,
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §3.10.

---

## 16. When All Else Fails

### 16.1 Collect and Submit a Report

If none of the above worked:

```bash
# 1. Full diagnostic (v1.2.0 — Layer 10)
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose" \
    > /sdcard/diagnose.txt 2>&1

# 2. JSON state
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" \
    > /sdcard/diagnose.json 2>&1

# 3. Backup state (v1.2.0)
su -c "sh /data/local/tmp/backup-diagnostics.sh" \
    > /sdcard/backup-diagnose.txt 2>&1

# 4. Logs
su -c "tail -200 /data/local/tmp/dnscrypt_main.log" \
    > /sdcard/logs.txt 2>&1

# 5. Module info
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop" \
    >> /sdcard/logs.txt 2>&1
```

### 16.2 Issue Template

When opening a GitHub Issue, include:

**Required**:

- Android version + API level
- Device model
- Kernel version
- Root solution (Magisk / KernelSU / APatch) + version
- Module version (`grep '^version=' module.prop`)
- Steps to reproduce
- Expected vs actual behavior

**Attachments**:

- `diagnose.txt` (from §16.1 step 1)
- `diagnose.json` (from §16.1 step 2)
- `logs.txt` (from §16.1 step 4)

**For backup-related issues, also include**:

- `backup-diagnose.txt` (from §16.1 step 3)
- The 7-field `backups` object:
  ```bash
  su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'"
  ```
- Directory listing:
  ```bash
  su -c "ls -la /sdcard/dnscrypt-webui-backup/"
  ```

**For recovery-mode issues, also include**:

- `customize.sh` version markers:
  ```bash
  su -c "grep -n 'RECOVERY_SNAPSHOT_DIR\|Re-applying recovery snapshot' \
      /data/adb/modules/dnscrypt-proxy-webui/customize.sh"
  ```
- The `.last_stable` pointer:
  ```bash
  su -c "cat /sdcard/dnscrypt-webui-backup/.last_stable"
  ```

**For watchdog issues, also include**:

- Token file state:
  ```bash
  su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/proxy/run/.watchdog_token"
  ```
- Watchdog log lines:
  ```bash
  su -c "grep -i 'watchdog' /data/local/tmp/dnscrypt_main.log | tail -20"
  ```

### 16.3 Support Links

- **Bug reports**: https://github.com/gasciljh/dnscrypt-proxy-webui/issues
- **Discussions**: https://github.com/gasciljh/dnscrypt-proxy-webui/discussions
- **Security issues**: https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new (do **not** open public issues for security)

---

*Last updated: 2026-09-29*
*Version: v1.2.0*
*Author: gasciljh*