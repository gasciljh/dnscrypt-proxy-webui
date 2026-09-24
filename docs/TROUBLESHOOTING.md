# Troubleshooting Guide — DNSCrypt Smart Filter

> Comprehensive diagnostic guide: from symptoms to solutions.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

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
│   └── § 4.11 (Broken Dashboard links) ← PORT-2
│
├── Cannot log in
│   └── § 5 (Authentication)
│   ├── § 5.8 (IPv6 rate limit)
│   ├── § 5.9 (Credentials from wrong section)
│   ├── § 5.10 (404 for unknown action) ← Fix #12
│   ├── § 5.11 (Login GET rejected) ← NEW-1
│   ├── § 5.12 (Basic Auth locked) ← Fix #8
│   └── § 5.13 (Credentials change delay) ← NEW-6
│
├── DNS not working at all
│   └── § 6 (DNS)
│   └── § 6.9 (Watchdog does not restart)
│
├── Some sites are not blocked
│   └── § 7 (Blocklist)
│   └── § 7.7 (Blocklist inconsistent on concurrent edit) ← RACE-1
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
│   └── § 12.7 (Upgrade loses settings) ← Fix #3
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

# runtime_info (PORT-2)
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
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

# 6. Logs (last 50)
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
unzip -t /sdcard/dnscrypt-webui-1.0.0-module.zip

# 2. verify space
df -h /data

# 3. re-download from GitHub Releases
```

### 3.5 "Missing critical files"

**Solution**:
- Download a fresh ZIP.
- Verify SHA256:
  ```bash
  sha256sum -c dnscrypt-webui-1.0.0-module.zip.sha256
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

**Solution**: confirm version `v1.0.0`.

```bash
su -c "curl -I http://127.0.0.1:9090/icon-192.svg"
# Expected: 200 OK + Content-Type: image/svg+xml
```

### 4.6 Dashboard shows no metrics

**Symptom**:
- Dashboard at `http://127.0.0.1:9091` opens.
- But the Metrics tables are empty.

**Solution**: update to `v1.0.0`. `/api/metrics` now returns proper JSON.

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
#   "generated_at": "2026-09-24T10:30:00Z",
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
- Update to `v1.0.0`.
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
- No — intentional in v1.0.0.
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
- Update to `v1.0.0`.
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
- Update to `v1.0.0`.
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

**Solution**: v1.0.0 relies on `HttpOnly cookie` — session lasts 24h.

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

**Solution**: update to `v1.0.0`.

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

**Solution**: update to `v1.0.0`.

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
- No — intentional in v1.0.0.
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
- No — intentional in v1.0.0.
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
- No — intentional in v1.0.0.
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
- `invalidateAuthCache()` is available internally for immediate use (e.g. SIGHUP handler).

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

**Solution**: update to `v1.0.0`.

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

**Reference**: [SECURITY.md](SECURITY.md) — Audit #18.

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

**Solution**: ensure `v1.0.0+`.

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
- Update to `v1.0.0`.
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

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

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
# Expected: < 20 MB
```

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

**Solution**: update to `v1.0.0`.

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
- Update to `v1.0.0`.
- Now:
  ```go
  func shellQuote(s string) string {
      for _, r := range s {
          if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
              r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
              r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
              r == '?' || r == '[' || r == ']' || r == '#' || r == '~' {
              return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
          }
      }
      return s
  }

  cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", shellQuote(MODDIR), port)
  ```

**Security table**:

| Input | Before | After |
|-------|:---:|:---:|
| `/data/adb/modules/dnscrypt-proxy-webui` | ✅ works | ✅ works |
| `/tmp/foo bar` | ❌ fails | ✅ works |
| `/tmp/$HOME` | ⚠️ expansion | ✅ literal |
| `/tmp/evil;rm -rf/` | injection | ✅ literal |

**Verify**:
```bash
# 1. static audit
grep -q 'func shellQuote' proxy/main.go && echo "✅ shellQuote present"
USAGE=$(grep -c 'shellQuote(MODDIR)' proxy/main.go)
[ "$USAGE" -ge 3 ] && echo "✅ shellQuote used $USAGE times"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #31.

---

## 12. Upgrade and CI Issues

### 12.1 Upgrade fails

**Loop**:
```bash
df -h /data
su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
# Reinstall from Magisk
```

### 12.2 "Credentials changed after upgrade"

**Solution**:
```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

### 12.3 "Settings lost"

**Solution**: keep a backup before upgrade (should be automatic in v1.0.0).

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
- Update to `v1.0.0`.
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

### 12.7 Settings lost after upgrade (Fix #3)

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

**Verify the old behavior**:

**Method 1 — Monitor before/after upgrade**:
```bash
# 1. Save the current settings
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf" > /sdcard/before.txt

# 2. Change PORT to 9191
su -c "sed -i 's/^PORT=9090/PORT=9191/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 3. Install a new ZIP
# (via Magisk Manager)

# 4. After install, verify
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Before the fix: PORT=9090 (lost!)
# After the fix: PORT=9191 (preserved ✅)
```

**Solution**:

**Option 1 — Update (recommended)**:
- Update to `v1.0.0`.
- New `customize.sh`:
  ```bash
  # [8b] Backup before extraction
  BACKUP_TMP="/data/local/tmp/dnscrypt-upgrade-backup-$$"
  mkdir -p "$BACKUP_TMP"
  for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
      [ -f "$_EXISTING_MODULE/proxy/$f" ] && cp -f "$_EXISTING_MODULE/proxy/$f" "$BACKUP_TMP/$f"
  done

  # [9] unzip -o ...
  # [9c] Restore after extraction
  for f in webui.conf dnscrypt-proxy.toml selected_profile.txt allowlist.txt denylist.txt; do
      [ -f "$BACKUP_TMP/$f" ] && cp -f "$BACKUP_TMP/$f" "$BIN_DIR/$f"
  done
  rm -rf "$BACKUP_TMP"
  ```

**Option 2 — Verify the fix**:
```bash
# static audit
grep -q 'BACKUP_TMP' proxy/customize.sh && echo "✅ Backup present"
grep -q 'Restoring user configuration' proxy/customize.sh && echo "✅ Restore present"
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

**Reference**: [SECURITY.md](SECURITY.md) — Audit #26.

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

**Solution**:
```bash
su -c "ls -la /data/local/tmp/dnscrypt_backup_uninstall/"
su -c "rm -rf /data/local/tmp/dnscrypt_backup_uninstall/"  # if certain
```

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

---

## 15. Helper Tools

### 15.1 status.sh

```bash
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check
sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --short
```

### 15.2 action.sh

```bash
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --check
sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --status
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
# Actual ports
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port, bind_addr}'"

# Full info
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq"
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
```

### 15.9 Status File Check

```bash
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status"
# "ON"  → user wants the service running
# "OFF" → user stopped it manually
```

**Important**: `STATUS_FILE` is **read-only** — written only by `startService()` / `stopService()`. Not written by `getStatusUncached()` (Fix A — Audit #18).

**Verify**:
```bash
grep -A5 'func getStatusUncached' proxy/main.go | grep -q 'atomicWriteFile' && echo "⚠️ writes!" || echo "✅ read-only"
```

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

---

## 16. When All Else Fails

### 16.1 Before Opening an Issue
- [ ] Read `docs/FAQ.md`.
- [ ] Read this file carefully.
- [ ] Try reinstalling the module.
- [ ] Tried `--restart`.
- [ ] Collected diagnostic logs.
- [ ] Checked Firewall: §15.3.
- [ ] Checked `STATUS_FILE`: §15.9.
- [ ] Checked Dashboard: §4.8.
- [ ] Checked RACE-1 if BLOCKLIST is inconsistent: §7.7.
- [ ] Checked PORT-2 if links are broken: §4.11.

### 16.2 Issue Template

```markdown
## Environment
- Module: v1.0.0
- Android: 14
- Device: Pixel 6
- Root: Magisk 27.0

## Problem
[Clear description]

## Steps
1. ...
2. ...

## Firewall State
```text
$ iptables -t nat -L OUTPUT -n
$ iptables -t nat -L DNSCRYPT_OUT -n
```

## Dashboard State
```text
$ curl -s http://127.0.0.1:9091/api/metrics | head -10
```

## Runtime Info
```text
$ curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
```

## Status File
```text
$ cat proxy/run/dnscrypt.status
ON
```

## Logs
[excerpt]

## Tried
- [x] status.sh
- [x] Reinstall
- [x] Restart
- [x] §11.6 (Custom Chains check)
- [x] §6.9 (Watchdog check)
- [x] §4.8 (Dashboard check)
- [x] §7.7 (RACE-1 check)
- [x] §4.11 (PORT-2 check)
```

### 16.3 Where to Ask

- **GitHub Issues**: [bug_report.yml](../.github/ISSUE_TEMPLATE/bug_report.yml)
- **GitHub Discussions**: community help
- **Private Advisory**: for security vulnerabilities

### 16.4 Useful Tips

- Do not open a public Issue for security vulnerabilities → [Private Reporting](https://github.com/gasciljh/dnscrypt-proxy-webui/security/advisories/new).
- Always attach logs.
- Be specific (not "DNS does not work").
- Mention what you tried.

---

## References

### Project Documentation

- [README.md](../README.md) — Overview
- [docs/INSTALL.md](INSTALL.md) — Installation guide
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/SECURITY.md](SECURITY.md) — Audit Corrections Registry
- [docs/API.md](API.md) — HTTP API Reference
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — Full architecture
- [docs/FAQ.md](FAQ.md) — Frequently asked questions
- [docs/DEVELOPMENT.md](DEVELOPMENT.md) — Developer guide
- [docs/UPGRADE.md](UPGRADE.md) — Upgrade guide
- [docs/DNS_BINARIES.md](DNS_BINARIES.md) — DNS binaries (Level 4)
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [CHANGELOG.md](../CHANGELOG.md) — Version history

### External Resources

- [dnscrypt-proxy Wiki](https://github.com/DNSCrypt/dnscrypt-proxy/wiki)
- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [Android DNS Architecture](https://source.android.com/docs/core/ota/modular-system/dns-resolver)
- [iptables Manual](https://ipset.netfilter.org/iptables.man.html)
- [Netfilter iptables Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)

---

**Last updated**: 2026-09-24
**Version**: v1.0.0
**Author**: gasciljh