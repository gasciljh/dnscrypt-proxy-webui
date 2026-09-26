# FAQ — Frequently Asked Questions

> Quick answers to 120+ common questions.

**Version**: v1.1.0
**Last updated**: 2026-09-26
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.1.0 changes**:
>   • Version bumped from v1.0.0 to v1.1.0.
>   • Added a new section: "v1.1.0 Specific Questions" (Q111–Q120),
>     covering the dynamic per-profile memory limit and the two
>     new `runtime_info` fields.
>   • Updated Q8 (What's new) to also describe v1.1.0.
>   • Updated Q37 (Dashboard links), Q43 (performance), Q59 (auth
>     cache), Q60 (`runtime_info`), Q78 (version verification), and
>     Q88 (`runtime_info` example) for v1.1.0.
>   • The v1.0.0-specific section (Q78–Q89) is preserved as-is, with
>     the version numbers updated to reference the current release.
>   • No questions were removed.

---

## Table of Contents

- [General](#general)
- [Installation](#installation)
- [Usage](#usage)
- [DNS & Blocking](#dns--blocking)
- [Dashboard & Monitoring](#dashboard--monitoring)
- [Performance & Battery](#performance--battery)
- [Security & Privacy](#security--privacy)
- [Updates & Maintenance](#updates--maintenance)
- [Problems & Solutions](#problems--solutions)
- [v1.0.0 Specific Questions](#v100-specific-questions)
- [v1.1.0 Specific Questions](#v110-specific-questions)
- [For Developers](#for-developers)
- [Contributing](#contributing)

---

## General

### 1. What is DNSCrypt Smart Filter?

A Magisk/KernelSU module that turns an Android device into a **system-wide encrypted and filtered DNS resolver**. It blocks ads and trackers in **every application** without needing a VPN.

### 2. How is it different from AdAway?

| Feature | AdAway | DNSCrypt Smart Filter |
|---|:---:|:---:|
| DNS-level blocking | ✅ | ✅ |
| DNS encryption | ❌ | ✅ (DNSCrypt + DoH) |
| HTTPS filtering | ❌ | ❌ |
| Arabic WebUI | ❌ | ✅ |
| Dashboard | ❌ | ✅ (JSON metrics) |
| Auto-updated lists | ⚠️ | ✅ (5 sources) |
| PWA | ❌ | ✅ |
| Zero telemetry | ⚠️ | ✅ |
| Dynamic memory limit | ❌ | ✅ (v1.1.0) |

### 3. How is it different from NextDNS / AdGuard DNS?

- **NextDNS / AdGuard**: **Cloud services** that send your queries to their servers for filtering.
- **DNSCrypt Smart Filter**: **Fully local** — no third-party connections except to standard, encrypted DNSCrypt/DoH servers.

### 4. Is it open source?

Yes — under the **MIT** license. Full source is available on [GitHub](https://github.com/gasciljh/dnscrypt-proxy-webui).

### 5. Is it free?

Yes, completely free. No paid version, no tracking, no ads.

### 6. Does it need a permanent internet connection?

No. It blocks ads from locally stored lists. Internet is only required when:
- Downloading a new list (rare).
- Running the DNS engine (needs to reach DNSCrypt servers).

### 7. What is "Zero Telemetry"?

The project does not connect to any analytics server, does not collect statistics, and does not send automatic error reports. All connections are limited to:
- DNSCrypt/DoH (for DNS encryption).
- Blocklist sources (e.g. HaGeZi via jsDelivr, for downloading lists).

### 8. What's new in v1.1.0?

**Polish release — documentation + three runtime improvements.**

**No breaking changes.** All v1.0.0 clients and configurations
continue to work without modification.

**Runtime changes** (see Q111–Q120 for details):

- **Dynamic memory limit per profile (MEM-1)** —
  `debug.SetMemoryLimit` is now computed from the active
  profile instead of being hardcoded to 80 MB. Prevents GC
  thrashing on the `ultimate` profile.
- **Extended `shellQuote` (MEM-2)** — the escape list grew from
  20 to 24 characters (`{`, `}`, `\n`, `\t` added).
- **`MONITORING_UI_PORT` constant (MEM-3)** — the metrics
  handler no longer contains the hardcoded string `"8080"`.

**Two new fields in `runtime_info`**:

- `profile_key` — the active blocklist profile.
- `memory_limit_mb` — the Go runtime soft memory limit for
  that profile.

**Documentation updates**:

- New section in this FAQ (Q111–Q120).
- Updated `docs/SECURITY.md` with §5.30, §14.22–14.24.
- Updated `docs/ARCHITECTURE.md` with §3.9, §4.9, §11.22.
- Updated `docs/TROUBLESHOOTING.md` with §4.12, §5.14, §6.10,
  §15.13.

See [CHANGELOG.md](../CHANGELOG.md) for details.

### 9. What is the release cadence?

- **Stable** (vX.Y.Z): ~monthly.
- **Hotfix** (vX.Y.Z-hotfixN): as needed (security/architectural).
- **Major** (vX.0.0): rare (~yearly).

---

## Installation

### 10. Do I need root?

**Yes**. Root is required to:
- Enable `iptables` (to redirect DNS traffic).
- Modify `private_dns_mode` in the system.
- Run services silently on boot.

### 11. Does it work with Magisk / KernelSU?

Yes — it supports:
- **Magisk** 20.4+
- **KernelSU** 0.9.0+
- **APatch**

### 12. What is the oldest supported Android version?

**Android 5.0** (API 21). Recommended: **Android 10+**.

### 13. What are the minimum requirements?

- Android 5.0+
- 1 GB RAM
- 20 MB storage
- Root (Magisk/KernelSU/APatch)
- Kernel 3.10+

### 14. How do I install the module?

See [`INSTALL.md`](INSTALL.md). In short:

1. Download `dnscrypt-webui-1.1.0-module.zip` from [Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases).
2. Install via Magisk Manager → Modules.
3. Reboot.
4. Open `http://127.0.0.1:9090` from a browser.

### 15. Can I install multiple DNS modules together?

**No**. DNSCrypt + AdAway → conflict.
DNSCrypt + VPN → conflict.

You can use:
- DNSCrypt Smart Filter **instead of** AdAway.
- DNSCrypt Smart Filter **with** AFWall+ (they do not conflict).

### 16. Are settings lost on upgrade?

**No** — since v1.0.0. See [Q57](#57-what-is-readconfport-range-check).

---

## Usage

### 17. How do I open the interface?

**From Magisk**:
- Open Magisk Manager → Modules → **Action**.

**Manually**:
- Open the browser at `http://127.0.0.1:9090`.

### 18. I forgot my password. What do I do?

```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

Or:

```bash
su -c "grep -A2 '\[monitoring_ui\]' /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"
```

### 19. How do I change the port?

Edit `webui.conf`:

```bash
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# PORT=9191
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

⚠️ **Warning**: Do not use port 8080 (reserved for monitoring_ui). The system will refuse to start.

⚠️ **Fix NEW-3**: Invalid values (`0`, `99999`, `-1`, `abc`) → automatic fallback to default.

### 20. How do I temporarily stop protection?

- **Method 1 (from WebUI)**:
  - Open `http://127.0.0.1:9090`.
  - Press ⏹️ Stop Service.
- **Method 2 (from Magisk)**:
  - Disable the module → reboot.
- **Method 3 (manually)**:
  ```bash
  su -c "touch /data/adb/modules/dnscrypt-proxy-webui/disable"
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```

### 21. How do I exclude a site from blocking?

1. Open the WebUI.
2. Go to ⚙️ Custom Rules.
3. In the Allowlist, add:
   ```text
   example.com
   *.example.com
   ```
4. Press 💾 Save.

### 22. How do I block an additional site?

Same as above, but add it to the **Denylist**.

### 23. What is the difference between Allowlist and Denylist?

| List | Purpose |
|---|---|
| **Allowlist** | Exception from blocking (always allow) |
| **Denylist** | Additional blocking (always block) |

---

## DNS & Blocking

### 24. Why do some ads still appear?

Possible reasons:

1. The ad is served from the same domain as content (e.g. YouTube, Facebook) → DNS cannot block it.
2. The application uses its own DoH servers (hardcoded) → bypasses system DNS.
3. Cache → restart the device or clear browser cache.
4. You are using a weak list → try "PRO" or "Ultimate".

### 25. How do I block YouTube ads?

It's difficult to block them via DNS for the following reasons:
- Ads come from the same domain as `youtube.com` and `googlevideo.com`.
- Blocking the entire domain would disable YouTube videos entirely.

**Solutions**:
- Use YouTube Vanced / ReVanced (modified versions).
- Or use a browser with a built-in AdBlock (e.g. Brave, Firefox).

### 26. How do I block Facebook / Instagram ads?

DNS can block:
- `graph.facebook.com` (API)
- `an.facebook.com` (ads)
- `connect.facebook.net`

**However**: Ads integrated into the Feed may not be blocked because they come from the same source as posts.

### 27. Why is DNS sometimes slow?

Reasons:

1. A slow remote resolver → DNSCrypt-proxy switches servers automatically but takes some time.
2. Using a very large list (Ultimate = 500K entries) delays engine startup.
3. Poor or interrupted internet connection.
4. Cache is full → restart the service.

### 28. Does Hotspot / Tethering work?

- On **Android 11+**: Yes, partially.
- On **Android < 11**: DNS leak may occur for Hotspot devices.

**Solution** (see `TROUBLESHOOTING.md`):

```bash
su -c "iptables -t nat -I PREROUTING -i wlan+ -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:5354"
```

### 29. Does it work with a VPN?

No. The VPN app routes all traffic through its own tunnel, bypassing `iptables`.

**Alternatives**:
- Use DNSCrypt inside a VPN app if it supports custom DNS (DNSCrypt-over-VPN).
- Or use only one of them.

### 30. What is the difference between DNSCrypt and DoH?

| Protocol | Port | Protocol | Encryption |
|---|:---:|:---:|---|
| **DNSCrypt** | 443 | UDP/TCP | X25519 + XSalsa20 |
| **DoH** | 443 | HTTPS | TLS 1.3 |
| **DoT** | 853 | TLS | TLS 1.3 |

Both are fully secure, but DNSCrypt is preferred on weak mobile networks due to its lower data overhead.

---

## Dashboard & Monitoring

### 31. What is the Dashboard?

A separate monitoring panel on `http://127.0.0.1:9091` that displays:
- Total + blocked queries.
- Cache hit ratio.
- Resolver health.
- Top queried domains.
- Last 30 queries.

### 32. Why doesn't the Dashboard show any data?

**Before v1.0.0**: This was a known issue (Dashboard broken) due to Prometheus text → JSON conversion.

**Now**: In v1.1.0 (and v1.0.0), it works correctly. Verify:

```bash
# 1. Version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.1.0

# 2. Binary updated
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null | grep -q 'buildDashboardJSON' && echo 'OK'"

# 3. JSON works
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -5
# Expected: JSON (not Prometheus text)
```

If it still fails → see `TROUBLESHOOTING.md` §4.8.

### 33. How do I view raw metrics (Prometheus text)?

`/api/metrics` now returns JSON. To get Prometheus text:

```bash
# Query monitoring_ui directly
su -c "curl -u \"user:pass\" http://127.0.0.1:8080/api/metrics"
```

**Difference**:

| Endpoint | Content-Type | Format |
|---|---|---|
| `http://127.0.0.1:9091/api/metrics` | `application/json` | JSON (schema) |
| `http://127.0.0.1:8080/api/metrics` | `text/plain` | Prometheus |

### 34. Why are some fields empty in the Dashboard?

- `resolver_health` → needs `enable_query_log` in TOML.
- `top_domains` → same reason.
- `recent_queries` → same reason.

**To enable them**:

```toml
# In dnscrypt-proxy.toml
[monitoring_ui]
  enabled = true
  enable_query_log = true  # ← enable recent_queries, top_domains
  privacy_level = 1        # ← 1 = log domains
```

Then:

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

### 35. Is there an API to access metrics?

Yes — `/api/metrics` on port 9091:

```bash
curl -s http://127.0.0.1:9091/api/metrics | jq
```

Full schema in [`API.md`](API.md).

### 36. How do I monitor from a PC?

- **Method 1**: Via ADB port forwarding:
  ```bash
  adb forward tcp:9091 tcp:9091
  # Now open http://127.0.0.1:9091 on the PC
  ```
- **Method 2**: `BIND_ADDR=0.0.0.0` (requires credentials).
- **Method 3**: Use the main WebUI on 9090.

### 37. Dashboard links are broken. Why?

**Before v1.0.0**: `index.html` and `dashboard.html` links were hardcoded (`127.0.0.1:9090/9091`) → broken when ports are changed.

**After v1.0.0 (PORT-2)**: Links are dynamically built from `runtime_info`:
- Uses `window.location.hostname` (supports LAN).
- Falls back to 9090/9091 before `runtime_info` loads.
- Works with any custom port.

**To verify**:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
```

**v1.1.0 addition**: The System Info panel in both WebUI and
Dashboard also shows the active profile and memory limit. See Q117.

---

## Performance & Battery

### 38. How much battery does it consume?

In normal use:
- ~1-2% / day (DNS queries processed locally).
- ~5-10% / day (when downloading new lists — rare).

**Conclusion**: Never drains the battery — it is not a VPN app and does not require a persistent connection.

### 39. How much memory does it consume?

- Idle WebUI: ~15 MB
- DNS Engine: ~5 MB
- **Total**: ~20-25 MB only.

**v1.1.0**: The WebUI now has a **dynamic soft memory limit**
per profile. This is not the actual RSS usage; it is the ceiling
at which the Go runtime starts GC more aggressively. See Q43 and
Q111.

### 40. Does it slow down the internet?

No. On the contrary:
- The local DNS cache provides faster responses for previously visited pages.
- DNSCrypt/DoH may be faster than the ISP's default DNS.

### 41. The device gets hot. Why?

Possible reasons:

1. The blocklist is huge (Ultimate) → takes a long time to load into memory.
2. Watchdog loop (service failing repeatedly) → but exponential backoff prevents this.
3. Old CPU → blocking 500K entries consumes resources on a weak processor.

**Solution**:
- Try "Light" or "Normal" instead of Ultimate.
- Disable `AUTO_RESTART_*` options in settings.

### 42. Are there performance improvements in v1.0.0?

Yes:

- **`isRunDirUsable` cache** (30 s) — prevents repeated I/O on every `/readyz`.
- **`isPortOpen` native Go** — instead of `fork/exec` (~30× faster).
- **`isPortOpenCached` per-port map** — correct cache per port.
- **`getSystemShell` sync.Once** — no overhead after first call.
- **Auth cache (60 s)** — `getMonitoringAuth` ~0.05ms instead of ~5-10ms.
- **`hasEndpoint` (string equality)** — <100 ns instead of O(n) `strings.Contains`.

**Impact**: Less CPU, faster response, less disk I/O.

### 43. What performance improvements came in v1.1.0?

**v1.1.0 introduces MEM-1 — dynamic memory limit per profile.**

**Before v1.1.0**: The Go runtime soft limit was hardcoded to
80 MB. On the `ultimate` profile, actual working set approaches
200 MB. This caused **GC thrashing** — the runtime spent CPU on
garbage collection instead of serving requests. Symptom:
WebUI becomes slow/unresponsive during heavy DNS activity.

**After v1.1.0**: The limit is computed per profile:

| Profile | Soft limit |
|---|---:|
| light | 80 MB |
| normal | 100 MB |
| pro | 120 MB |
| proplus | 160 MB |
| ultimate | 220 MB |

**Impact**:
- No more GC thrashing on `ultimate`.
- CPU stays low even under load.
- Memory remains bounded on lighter profiles.

**How to verify the limit is active**:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'"
# Expected: 120 for pro, 220 for ultimate, etc.
```

See Q111–Q120 for more details, and `TROUBLESHOOTING.md` §6.10
for GC thrashing diagnostics.

**Does `rebuildMu` slow down rebuildBlocklist?**

No. `rebuildBlocklist` takes ~200 ms (100K) or ~1 s (500K). The coarse-grained lock adds no noticeable overhead.

**However**: When `updateProfile` + `saveAllowlist` run simultaneously, they serialize — may seem slightly slower (acceptable — rare operation).

---

## Security & Privacy

### 44. Is my data safe?

Yes.
- Everything is processed locally.
- No third-party connections.
- Zero telemetry.
- Credentials are generated with high entropy.

### 45. Can a malicious app steal my data?

Very difficult for the following reasons:
- WebUI server is available only on `127.0.0.1` (no external network access).
- Authentication is mandatory.
- Rate limiting for login + Basic Auth.
- Session cookies protected with `HttpOnly`, `SameSite=Lax`.
- Secure cookies enforced.
- Login POST-only (prevents CSRF).
- `/readyz` localhost-only (prevents reconnaissance).

*Only exception*: Any app with full root privileges can read everything on the device.

### 46. What is BIND_ADDR?

The listening address for the WebUI.
- `127.0.0.1` (default): Local access only.
- `0.0.0.0`: Whole network → refuses to start unless strong credentials are set.

### 47. How do I expose the WebUI on the local network?

Edit `webui.conf`:

```text
BIND_ADDR=192.168.1.5  # Your device's IP
```

Then restart. You will need to set strong credentials.

*Warning*: Make sure your local network is secure (firewall).

### 48. Can I access it from my PC?

Yes (only if you changed `BIND_ADDR`):

```text
http://192.168.1.5:9090
```

Default (`127.0.0.1`) means it cannot be accessed from any external device.

### 49. Are my queries logged?

- **Locally**: Yes (saved in `dnscrypt-blocked.log` and `dnscrypt-query.log`). Can be disabled in `dnscrypt-proxy.toml`.
- **Externally**: No. The DNSCrypt/DoH provider does not know your identity.

### 50. Why was STATUS_FILE behavior changed?

In previous versions, `STATUS_FILE` was written by the read-only `getStatusUncached` function — causing loss of "user intent" when the DNS engine crashed.

**After v1.0.0**:
- `STATUS_FILE` = "User Intent" only.
- Written only by `startService()` / `stopService()`.
- Watchdog restarts reliably after any crash.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #18.

### 51. Why does the module refuse port 8080?

Port `8080` is reserved for `monitoring_ui` (dnscrypt-proxy's internal interface).
- `main.go` refuses to start if `PORT=8080` or `DASHBOARD_PORT=8080`.
- `customize.sh` automatically replaces any `8080` value in `webui.conf` with `9090` / `9091`.

**v1.1.0**: The reserved port is now also enforced as a Go
constant (`MONITORING_UI_PORT`) in `metricsProxyHandler`. See Q120.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #20.

### 52. Do Custom Chains pollute the firewall?

No. Since v1.0.0, the module uses Custom Chains (`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`) instead of writing directly to OUTPUT:
- Public `OUTPUT` contains only two static rules (jump rules).
- All dynamic rules are inside the dedicated chains.
- Cleanup = `-F` + `-X` (complete wipe in one shot).
- No orphans even if you change `bootstrap_resolvers` hundreds of times.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #17.

### 53. Why is Basic Auth now rate-limited?

**Before v1.0.0**:
- `handleLogin` (POST `/api/auth/login`) was protected by rate limiting.
- But `checkAuth` (accepts Basic Auth) **did not** record failed attempts.
- **Result**: An attacker on LAN could send unlimited Basic Auth requests.

**After v1.0.0**:
- Basic Auth is limited to **5 attempts / 15 minutes** (per IP).
- Protects against brute force.
- Successful Basic Auth resets the counter.
- Lockout duration: **15 minutes** (same `LOGIN_LOCKOUT_PERIOD`).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #22.

### 54. Is the 404 for unknown actions a breaking change?

Yes, **for API consumers**.

**Before**: `GET /api?action=unknown` → `200 OK` + `{"status": "unknown"}`.
**After**: `GET /api?action=unknown` → `404 Not Found` + a clear message.

**Solution**: Update scripts to expect `404` (see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #24.

### 55. What is `hasEndpoint`?

A function in `main.go` that applies **exact path matching**:

```go
func hasEndpoint(path, name string) bool {
    return path == "/api/"+name || path == "/api/"+name+"/"
}
```

**Before** (weak):
```go
if strings.Contains(r.URL.Path, "update_profile") {
    // ⚠️ Also matches /api/update_profile_evil
}
```

**After** (safe):
```go
if hasEndpoint(r.URL.Path, "update_profile") {
    // ✅ Only /api/update_profile
}
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #24.

### 56. What is `shellQuote`?

A function in `main.go` (Fix NEW-5) that wraps a path with safe quotes for use in `runShell`.

**Before**:
```go
cmd := fmt.Sprintf(". %s/functions.sh; ...", MODDIR)  // ⚠️ unquoted
```

**After**:
```go
cmd := fmt.Sprintf(". %s/functions.sh; ...", shellQuote(MODDIR))  // ✅ safe
```

**Impact**:
- ✅ Prevents shell injection.
- ✅ Supports spaces in `MODDIR`.

**v1.1.0**: The character set was extended to 24 characters
(`{`, `}`, `\n`, `\t` added). See Q115.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #31 + §5.30.2.

### 57. What is the `readConfPort` range check?

The `readConfPort` function in `main.go` (Fix NEW-3) verifies the range `[1, 65535]`:

```go
func readConfPort(key, defaultPort string) string {
    val := readConfValue(key, defaultPort)
    n, err := strconv.Atoi(val)
    if err != nil || n < 1 || n > 65535 {
        return defaultPort  // fallback
    }
    return val
}
```

**Impact**:

| Value | Before | After |
|-------|:---:|:---:|
| `PORT=9090` | ✅ | ✅ |
| `PORT=0` | ⚠️ random | ✅ fallback |
| `PORT=99999` | ⚠️ silent failure | ✅ fallback |
| `PORT=abc` | ✅ fallback | ✅ fallback |

**Reference**: [SECURITY.md](SECURITY.md) — Audit #29.

### 58. What is `rebuildMu` (RACE-1)?

A `sync.Mutex` that protects `rebuildBlocklist` from race conditions:

```go
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ...
}
```

**Before**: `updateProfile` + `saveAllowlist` concurrent → inconsistent BLOCKLIST.
**After**: Both operations serialized → BLOCKLIST always consistent.

**Constraint**: Rebuild may seem slower during concurrent edit (acceptable — rare operation).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

### 59. What is the Auth cache (60 s)?

`getMonitoringAuth` caches credentials for 60 seconds:

```go
const AUTH_CACHE_TTL = 60 * time.Second
```

**Before**: Every HTTP request reads the TOML (~5-10 ms).
**After**: Cache hit → ~0.05 ms.

**Constraint**: Changing credentials in the TOML → applies after ≤ 60 s.
**For immediate effect**: Restart the WebUI.

**Reference**: [SECURITY.md](SECURITY.md) — Fix NEW-6.

### 60. What is `runtime_info` ports (PORT-2)?

`buildRuntimeInfo` returns several fields including:

**v1.0.0 (PORT-2)**:

```json
{
  "webui_port": "9090",
  "dashboard_port": "9091"
}
```

**v1.1.0 (MEM-1)** — two additional fields:

```json
{
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

**Benefits**:
- HTML/JS updates links dynamically.
- Supports LAN access.
- Supports IPv6 loopback.
- No broken links when ports change.
- System Info panel shows profile + memory limit.

**Constraint**: PWA shortcuts (`manifest.json`) do not read `runtime_info` — they stay static (documented).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #33 + §5.30.1.

---

## Updates & Maintenance

### 61. How do I update the module?

1. **From Magisk**: Modules → DNSCrypt → Update (if auto-update is enabled).
2. **Manually**: Download the new ZIP → install over the old one.

### 62. How do I update the lists?

- **Automatically**: On every restart.
- **Manually**: From the WebUI → choose the desired list → Apply.

### 63. How do I copy settings to another device?

```bash
# Backup
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/*.txt /sdcard/backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf /sdcard/backup/"
su -c "cp /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml /sdcard/backup/"

# Restore on the new device
su -c "cp /sdcard/backup/* /data/adb/modules/dnscrypt-proxy-webui/proxy/"
```

### 64. How do I remove the module?

- **From Magisk**: Modules → DNSCrypt → Remove.
- **Manually**:
  ```bash
  su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
  ```

**v1.1.0 note**: `uninstall.sh` no longer creates a backup
directory. Any legacy backup from v1.0.0 is removed automatically.

### 65. Are settings preserved on upgrade?

**Yes** — since v1.0.0:
- ✅ `webui.conf` preserved.
- ✅ `dnscrypt-proxy.toml` preserved.
- ✅ `allowlist.txt` + `denylist.txt` preserved.
- ✅ `selected_profile.txt` preserved.

**How it works**:
1. `customize.sh [8b]` — Backup before `unzip -o`.
2. `customize.sh [9c]` — Restore after `unzip -o`.

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #26.

### 66. How do I roll back to a previous version?

```bash
# 1. Download the previous version's ZIP from GitHub Releases
# 2. Install over the new one from Magisk
# 3. Reboot
su -c "reboot"

# 4. Verify
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
```

**Note**: Settings are preserved on rollback (since v1.0.0).

**Rollback caveats** (from v1.1.0 to v1.0.0):
- ⚠️ Dynamic memory limit reverts to hardcoded 80 MB.
- ⚠️ `runtime_info` will no longer include `profile_key` / `memory_limit_mb`.
- ⚠️ System Info panel will not display profile / memory fields.
- ⚠️ `shellQuote` reverts to the 20-character set.

See [`UPGRADE.md`](UPGRADE.md) for details.

### 67. What is the versionCode for each version?

Formula:

```text
versionCode = MAJOR × 1,000,000 + MINOR × 10,000 + PATCH × 100 + HOTFIX
```

**Examples**:

| Version | versionCode |
|---|:---:|
| v1.0.0 | 1000000 |
| v1.0.1 | 1000001 |
| v1.1.0 | 1010000 |
| v2.0.0 | 2000000 |

**Note**: `hotfix` must be ≤ 99 (because `patch` uses ×100).

---

## Problems & Solutions

### 68. DNS does not work after installation. What do I do?

1. Check the command `status.sh`:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh"
   ```
2. If the DNS Engine is stopped → start it from the WebUI.
3. If port `5354` is closed → restart.
4. If `iptables` fails → see `TROUBLESHOOTING.md`.

### 69. WebUI does not open. What do I do?

1. Check the port status:
   ```bash
   su -c "ss -ltn | grep 9090"
   ```
2. If closed → start the service:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh"
   ```
3. If it still does not work → see `TROUBLESHOOTING.md`.

### 70. The device does not boot after installation (Bootloop). What do I do?

**Emergency**:
1. Reboot the device into Safe Mode.
2. Remove the module via ADB:
   ```bash
   adb shell su -c "rm -rf /data/adb/modules/dnscrypt-proxy-webui"
   ```
3. Reboot the device.

### 71. Dashboard does not display metrics. What do I do?

- **Symptom**: The Dashboard (`:9091`) opens, but Metrics tables are empty.
- **Cause (before v1.0.0)**: `metricsProxyHandler` returned Prometheus text with `Content-Type: application/json`.
- **Solution**: Update to `v1.1.0` (or v1.0.0).

**Verify**:

```bash
su -c "curl -s http://127.0.0.1:9091/api/metrics" | jq '.total_queries'
# Expected: a number
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #25.

### 72. Watchdog does not restart after a crash. What do I do?

- **Symptom**: DNS Engine crashes; Watchdog runs but does nothing.
- **Cause (before v1.0.0)**: WebUI called `getStatus` every 10 seconds, and `getStatusUncached` wrote `STATUS_FILE = "OFF"` on crash.
- **Solution**: Update to `v1.1.0` (or v1.0.0).

**Verify**:

```bash
su -c "pkill -9 dnscrypt-proxy"
sleep 60
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json" | jq .dns_engine.running
# Expected: true
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #18.

### 73. Settings were lost after upgrade. What do I do?

- **Symptom**: After upgrading the module, `webui.conf` is reset.
- **Cause (before v1.0.0)**: `unzip -o` extracted defaults over custom ones.
- **Solution**: Update to `v1.1.0` (or v1.0.0).

**Immediate recovery**:

```bash
# Find automatic backup (v1.0.0 only — v1.1.0 does not create backups)
BACKUP=$(ls -dt /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null | head -1)
su -c "cp $BACKUP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "cp $BACKUP/dnscrypt-proxy.toml /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #26.

### 74. Basic Auth is too restricted after upgrade. What do I do?

- **Symptom**: After upgrading to v1.1.0, Basic Auth fails after 5 attempts.
- **Cause**: Intentional — Basic Auth is rate-limited.
- **Solution**:
  - ✅ **Solution 1**: Use correct credentials (will not be locked).
  - ✅ **Solution 2**: Use Cookie auth (no rate limit).
  - ✅ **Solution 3**: Restart the WebUI to reset the counter.

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #22.

### 75. Build fails. What do I do?

- **Symptom**: `make build` fails, or `./build.sh` returns errors.
- **Cause**: Missing toolchain (Go, NDK).
- **Solution**: Verify the toolchain.

**Verify**:

```bash
go version          # Expected: 1.22+
echo $ANDROID_NDK_HOME

# Build a single binary to isolate the problem
cd proxy
./build.sh --single arm64 --verbose
```

### 76. Dashboard still broken after upgrade. What do I do?

- **Verify the binary is updated**:
  ```bash
  strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null | \
      grep -q "buildDashboardJSON" && echo "✅ binary updated"
  ```

- **Verify main.go** (in the repository):
  ```bash
  grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix present"
  ```

- **Test manually**:
  ```bash
  su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -5
  ```

- **If all else fails**: Reinstall.

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #25.

### 77. BLOCKLIST appears inconsistent. Why?

- **Symptom**: Some sites remain blocked even after being added to the allowlist.
- **Cause (before v1.0.0)**: `rebuildBlocklist` was not protected by a mutex → race condition with `updateProfile`.
- **Solution**: Update to `v1.1.0` (or v1.0.0).

**Verify**:

```bash
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1 present"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

---

## v1.0.0 Specific Questions

> **Note**: This section documents the v1.0.0 features and
> verifications. It is preserved for historical reference and for
> users upgrading from pre-v1.0.0 releases. Current version
> verification is in the next section (v1.1.0).

### 78. How do I know a version contains v1.0.0?

Verify:

1. `VERSION` file = `v1.0.0` (for v1.0.0) / `v1.1.0` (for v1.1.0).
2. `module.prop` → `version=v1.0.0` / `version=v1.1.0`.
3. `runtime_info` endpoint:
   ```bash
   curl -s http://127.0.0.1:9090/api/runtime_info | jq .version
   ```

**Quick tests (main.go)**:

```bash
# 1. Dashboard JSON
grep -q 'buildDashboardJSON' proxy/main.go && echo "✅ Fix #1"

# 2. Shell fallback
grep -q 'getSystemShell' proxy/main.go && echo "✅ Fix #2"

# 3. Preserve settings
grep -q 'BACKUP_TMP' proxy/customize.sh && echo "✅ Fix #3"

# 4. Basic Auth rate limit
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Fix #8"

# 5. Section header with comment
grep -q 'strings.Index(trimmed, "]")' proxy/main.go && echo "✅ Fix #10"

# 6. Per-port cache
grep -q 'portCacheMap' proxy/main.go && echo "✅ Fix #11"

# 7. Exact matching
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12"

# 8. Login POST-only
grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅ NEW-1"

# 9. readConfPort range
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅ NEW-3"

# 10. /readyz localhost-only
grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅ NEW-4"

# 11. shellQuote
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5"

# 12. Auth cache
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6"

# 13. RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# 14. PORT-2 (runtime_info ports)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"
```

### 79. Did the API change? What do I need to update?

**Yes** — 3 changes for API consumers (from pre-v1.0.0):

| # | Change | Action | Reference |
|:-:|---|---|---|
| 1 | Login POST-only (`/api/auth/login`) | Update GET → POST | [SECURITY.md](SECURITY.md) |
| 2 | Logout POST-only (`/api/auth/logout`) | Same | [SECURITY.md](SECURITY.md) |
| 3 | 404 for unknown action | Expect `404` instead of `200 + unknown` | [SECURITY.md](SECURITY.md) |

**Details**: See [`API.md`](API.md).

### 80. Did `runtime_info` change its format?

**v1.0.0**: **New fields** added only:

```json
{
  "webui_port": "9090",
  "dashboard_port": "9091"
}
```

**v1.1.0**: **Two more fields** added:

```json
{
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

All previous fields remain (`version`, `commit`, `run_dir`, ...).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #33 + §5.30.1.

### 81. Did `/api/metrics` change its format?

**Yes** — `/api/metrics` now returns **JSON** instead of Prometheus text (since v1.0.0):
- **Before**: Prometheus text with `Content-Type: application/json` (lies).
- **After**: JSON schema with `Content-Type: application/json; charset=utf-8`.

**v1.1.0**: The upstream URL is built from `MONITORING_UI_PORT`
constant instead of the hardcoded string. Behavior is unchanged.

**Details**: See [`API.md`](API.md).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #25.

### 82. How do I view the original Prometheus text?

```bash
# Query monitoring_ui directly (on port 8080)
su -c "curl -u \"user:pass\" http://127.0.0.1:8080/api/metrics"
```

**Difference between endpoints**:

| Endpoint | Port | Format | Auth |
|---|:---:|---|---|
| `/api/metrics` (main.go) | 9091 | JSON | Cookie/Bearer/Basic |
| `/api/metrics` (monitoring_ui) | 8080 | Prometheus | Basic |

**When to use each**:
- **`/api/metrics`** (9091): For the Dashboard + scripts using `jq`.
- **`/api/metrics`** (8080): For Prometheus scraping or raw analysis.

### 83. Did `.gitignore` change?

**Yes** — core fix (v1.0.0):
- **Before**: `proxy/run/` (result: `.gitkeep` was not uploaded).
- **After**: `proxy/run/*` + `!proxy/run/.gitkeep` (works correctly).

**Impact on users**: None (developers only).

### 84. Are there new sections in SECURITY.md?

**Yes** — 12 new sections (v1.0.0):

| Anchor | Topic |
|---|---|
| #518 | Basic Auth Rate Limit Bypass |
| #519 | Section header with comment |
| #520 | Exact endpoint matching (Dashboard JSON) |
| #521 | Preserve User Settings on Upgrade |
| #522 | `fuser` PID parsing |
| #523 | Login POST-only |
| #524 | `readConfPort` range check |
| #525 | `/readyz` localhost-only |
| #526 | `shellQuote` injection protection |
| #527 | Auth cache (60 s) |
| #528 | `rebuildMu` mutex (RACE-1) |
| #529 | `runtime_info` ports (PORT-2) |

**v1.1.0 adds**:

| Anchor | Topic |
|---|---|
| #530 | v1.1.0 runtime changes (MEM-1, MEM-2, MEM-3) |

**See** [`docs/SECURITY.md`](SECURITY.md) for full details.

### 85. What's new in `.pre-commit-config.yaml`?

**Updated** to support v1.1.0 checks. See the file itself for the exact hook list.

### 86. What's new in the Makefile?

The Makefile is intentionally minimal:

```bash
make build      # Build all 4 architectures
make package    # Build + package
make clean      # Clean outputs
make version    # Show version
make help       # Show help
```

### 87. How do I run all v1.0.0 checks?

Use grep-based verification:

```bash
# See Q78 for the full list
```

### 88. What is `runtime_info`?

`runtime_info` is an API endpoint that returns build info + runtime paths + actual ports.

**v1.1.0 example**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
```

```json
{
  "version": "v1.1.0",
  "commit": "a1b2c3d",
  "build_time": "1726987200",
  "build_time_human": "2026-09-26T10:00:00Z",
  "project_url": "https://github.com/gasciljh/dnscrypt-proxy-webui",
  "run_dir": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run",
  "status_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status",
  "pid_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.pid",
  "progress_file": "/data/adb/modules/dnscrypt-proxy-webui/proxy/run/update_progress.txt",
  "log_file": "/data/local/tmp/dnscrypt_main.log",
  "bind_addr": "127.0.0.1",
  "webui_port": "9090",
  "dashboard_port": "9091",
  "profile_key": "pro",
  "memory_limit_mb": 120
}
```

See [`API.md`](API.md) §6.1.7 for full details.

### 89. What is the Auth cache?

A 60-second in-memory cache for credentials, reducing file I/O on every HTTP request. See Q59.

---

## v1.1.0 Specific Questions

> **Note**: This section covers the v1.1.0 changes: dynamic memory
> limit per profile (MEM-1), extended `shellQuote` (MEM-2), and the
> `MONITORING_UI_PORT` constant (MEM-3).

### 111. What is the dynamic memory limit (MEM-1)?

**Definition**: `main.go` sets the Go runtime soft memory limit
dynamically based on the active blocklist profile.

**Values**:

| Profile | Soft limit |
|---|---:|
| light | 80 MB |
| normal | 100 MB |
| pro | 120 MB |
| proplus | 160 MB |
| ultimate | 220 MB |

**Important semantics**:
- `debug.SetMemoryLimit` is a **soft** limit.
- The Go runtime does **not** kill the process when the limit is
  reached — it runs GC more aggressively instead.
- Setting it too low → CPU waste (GC thrashing).
- Setting it too high → RAM waste.

**Why per-profile?** Because different blocklist profiles have
different working set sizes. A single value either wastes memory
on light profiles or starves the heavy ones.

**Reference**: [SECURITY.md](SECURITY.md) §5.30.1;
[ARCHITECTURE.md](ARCHITECTURE.md) §3.9, §11.22.

### 112. Why did we add the dynamic memory limit?

**Before v1.1.0**: The soft limit was hardcoded to 80 MB:

```go
debug.SetMemoryLimit(80 * 1024 * 1024)  // ← same for all profiles
```

**Problem**: The `ultimate` profile has a working set that
approaches 200 MB. With an 80 MB soft limit, the runtime ran GC
continuously — a condition called **GC thrashing**. On
low-RAM devices, this manifested as a frozen or very slow WebUI.

**After v1.1.0**: The limit is computed per profile. No more GC
thrashing on `ultimate`, no wasted RAM on `light`.

**Symptom before the fix**:
- WebUI responds, but every action takes 2-5 seconds.
- CPU on the WebUI process > 30% while idle.
- Battery drains faster.

**Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §6.10.

### 113. How do I check the current memory limit?

**Method 1 — Runtime Info endpoint**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.memory_limit_mb'
# Expected: 80 for light, 120 for pro, 220 for ultimate
```

**Method 2 — Both fields**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}
```

**Method 3 — Startup log**:

```bash
grep "dynamic memory limit" /data/local/tmp/dnscrypt_main.log | tail -1
# Expected: 🧠 v1.1.0: dynamic memory limit — profile=pro, limit=120 MB
```

**Method 4 — System Info panel**:

Open the WebUI or Dashboard → "System Info" → look for the
"Profile" and "Memory Limit" rows.

### 114. When does the memory limit change?

Two triggers:

1. **Startup** — `main()` calls `applyMemoryLimit()` once, using
   the profile read from `selected_profile.txt`.

2. **Profile change** — after a successful
   `POST /api/update_profile`, `updateProfile()` calls
   `applyMemoryLimit()` with the new profile key.

**What does NOT trigger a change**:

- Editing `selected_profile.txt` directly while the WebUI is
  running. You must restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```
- Changing `webui.conf` (unrelated to memory).
- Restarting the DNS engine alone (does not affect the WebUI's
  memory limit).

**Reference**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) §5.14.

### 115. What is the extended `shellQuote` (MEM-2)?

**Before v1.1.0** (20 characters):
`` ` ``, `"`, `'`, `$`, `` ` ``, `\`, `!`, `&`, `|`, `;`, `(`, `)`,
`<`, `>`, `*`, `?`, `[`, `]`, `#`, `~`.

**After v1.1.0** (24 characters — four added):

| Added char | Reason |
|---|---|
| `{` | Brace expansion in shells |
| `}` | Brace expansion |
| `\n` | Word splitting in embedded strings |
| `\t` | Word splitting |

**Why this matters**: A path containing `{` could be
brace-expanded by the shell before being passed to the actual
command. A path containing a literal newline could be
word-split.

**Practical impact today**: `MODDIR` is derived from
`os.Executable()`. A normal user cannot make it contain these
characters. **No known exploit existed**. This is defense in
depth.

**Verify**:

```bash
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ braces"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\n'" && echo "✅ newline"
grep -A8 'func shellQuote' proxy/main.go | grep -q "r == '\\\\t'" && echo "✅ tab"
```

**Reference**: [SECURITY.md](SECURITY.md) §5.30.2.

### 116. What is `profile_key` in `runtime_info`?

`profile_key` is a string identifying the active blocklist
profile. It is one of:

- `light`
- `normal`
- `pro` (default)
- `proplus`
- `ultimate`

**Where it comes from**: `main.go` reads
`proxy/selected_profile.txt` at startup via
`readSelectedProfile()`. If the file is missing or contains an
unknown value, the key defaults to `"pro"`.

**Why it exists**:
- **Observability** — a user reporting an issue can include it.
- **Verification** — the System Info panel displays it.
- **Consistency** — the UI can cross-check its own dropdown
  against the server's authoritative value.

**Example**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq -r '.profile_key'
# Expected: pro
```

**Reference**: [API.md](API.md) §6.1.7.

### 117. What does the System Info panel now show?

In v1.1.0, both the WebUI (`index.html`) and the Dashboard
(`dashboard.html`) show two additional rows in the System Info
panel:

- **Profile**: `pro` (for example)
- **Memory limit**: `120 MB` (for example)

The rows were added to the existing list (version, commit, build
time, ports, etc.). They are populated from the `runtime_info`
response — no extra API call.

**To see them**:

1. Open the WebUI at `http://127.0.0.1:9090`.
2. Scroll to "System Info".
3. Expand the section.
4. Look for the "Profile" and "Memory limit" rows.

**Reference**: [ARCHITECTURE.md](ARCHITECTURE.md) §16.7.

### 118. Does the memory limit affect the DNS engine?

**No**. The memory limit applies only to the **WebUI process**
(`dnscrypt-webui`), which is written in Go.

The **DNS engine** (`dnscrypt-proxy`) is a **separate upstream
binary** with its own memory management. It has its own
`cache_size` setting in `dnscrypt-proxy.toml`. The WebUI limit
has no effect on it.

**Analogy**:

| Process | Memory managed by |
|---|---|
| `dnscrypt-webui` | Go runtime (`debug.SetMemoryLimit`) — v1.1.0 |
| `dnscrypt-proxy` | Upstream (its own settings) — unchanged |

**To tune the DNS engine's cache**:

```toml
# dnscrypt-proxy.toml
cache_size = 10240  # ← adjust here
```

### 119. Should I change the memory limit manually?

**No.** The limit is computed automatically from the active
profile. There is no configuration knob for it. To change the
limit, change the profile:

```bash
# From the WebUI: select a profile → Apply
# Or from the terminal:
su -c "echo 'pro' > /data/adb/modules/dnscrypt-proxy-webui/proxy/selected_profile.txt"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

**Why not configurable?** Because the correct value is a
function of the profile, not a user preference. Making it
configurable would invite users to set it too low (GC thrashing)
or too high (RAM waste).

**If you must override** (advanced): you would need to modify
`main.go`, rebuild, and repackage. Not recommended.

### 120. What is MEM-3 (`MONITORING_UI_PORT` in metrics handler)?

**Definition**: The `metricsProxyHandler` function in `main.go`
builds the URL for the upstream `monitoring_ui` endpoint using
the Go constant `MONITORING_UI_PORT` instead of the hardcoded
string `"8080"`.

**Before v1.1.0**:

```go
req, err := http.NewRequestWithContext(r.Context(), "GET",
    "http://127.0.0.1:8080/api/metrics", nil)
//   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ hardcoded
```

**After v1.1.0**:

```go
monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"
req, err := http.NewRequestWithContext(r.Context(), "GET", monitoringURL, nil)
```

**Why this matters**:
- Single source of truth for the reserved port.
- Reduces the number of places to update if the port ever changes.
- Matches the pattern already used by `getWebUIPort()` and
  `getDashboardPort()`.

**Observable behavior**: unchanged. The API contract is
identical. Clients see no difference.

**Reference**: [SECURITY.md](SECURITY.md) §5.30.3.

---

## For Developers

### 90. How do I build from source?

```bash
git clone https://github.com/gasciljh/dnscrypt-proxy-webui.git
cd dnscrypt-proxy-webui
make build
```

See [`DEVELOPMENT.md`](DEVELOPMENT.md) for full details.

### 91. What tools are required?

- Go 1.22+
- Make
- shellcheck 0.10+
- shfmt 3.8+
- golangci-lint v2.5.0+
- markdownlint, yamllint, actionlint
- Android NDK r26b+ (for full build)

### 92. How do I verify the build?

```bash
# Build
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go

# Check for hardcoded shell path
! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' proxy/main.go && echo "✅ no hardcoded shell"

# Verify fixes present (see Q78 for the full list)
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12"
```

### 93. How do I verify v1.1.0 correctness?

```bash
# v1.0.0 checks (see Q78 for full list)
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix #1 (JSON)"
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix #2 (shell)"
grep -q 'BACKUP_TMP' proxy/customize.sh && echo "✅ Fix #3 (settings preserved)"
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Fix #8 (Basic Auth rate limit)"
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12 (exact matching)"
grep -q 'hasEndpoint(r.URL.Path, "auth/login")' proxy/main.go && echo "✅ NEW-1 (POST-only)"
grep -A20 'func readConfPort' proxy/main.go | grep -q 'n < 1\|n > 65535' && echo "✅ NEW-3 (range)"
grep -A30 'func handleReadyz' proxy/main.go | grep -q 'isLocalRequest(r)' && echo "✅ NEW-4 (localhost)"
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5 (quote)"
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6 (cache)"
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# v1.1.0 checks
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1 (function)"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ MEM-1 (apply)"
grep -q 'MEMORY_LIMIT_ULTIMATE' proxy/main.go && echo "✅ MEM-1 (constants)"
! grep -q 'debug.SetMemoryLimit(80 \* 1024 \* 1024)' proxy/main.go && echo "✅ MEM-1 (no hardcoded)"
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2 (braces)"
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"memory_limit_mb"' && echo "✅ MEM-1 (field)"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"profile_key"' && echo "✅ MEM-1 (field)"
```

### 94. What are the new Make targets?

None. The Makefile remains minimal:
- `make all`, `make help`, `make version`, `make build`, `make package`, `make clean`.

### 95. How do I diagnose Dashboard problems?

```bash
# 1. Content-Type
curl -sI http://127.0.0.1:9091/api/metrics | grep -i content-type
# Expected: application/json

# 2. JSON structure
curl -s http://127.0.0.1:9091/api/metrics | jq 'keys'

# 3. Verify upstream
curl -s http://127.0.0.1:8080/api/metrics | head -5

# 4. Verify fix presence
grep -q 'func metricsProxyHandler' proxy/main.go && echo "✅ present"
```

### 96. How do I diagnose Basic Auth rate limit problems?

```bash
# 1. Check logs
tail -20 /data/local/tmp/dnscrypt_main.log | grep -i "login\|rate"

# 2. Test 6 attempts
for i in {1..6}; do
    curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
        http://127.0.0.1:9090/api?action=status
done
# Expected: 401 × 5 then 401 (locked)

# 3. Verify fix presence
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ present"
```

**Reference**: [SECURITY.md](SECURITY.md).

### 97. How do I diagnose RACE-1?

```bash
# 1. Static audit
grep -qE 'rebuildMu[[:space:]]\+sync\.Mutex' proxy/main.go && echo "✅ declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"

# 2. Race detector (if you have Go tests)
cd proxy && go run -race main.go
```

**Reference**: [SECURITY.md](SECURITY.md).

### 98. How do I diagnose PORT-2?

```bash
# 1. runtime_info
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'

# 2. Static audit (backend)
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ backend"

# 3. Static audit (frontend)
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html"

# 4. v1.1.0 memory fields
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
```

**Reference**: [SECURITY.md](SECURITY.md).

### 99. How do I diagnose `getSystemShell` problems?

```bash
# 1. Static audit
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix present"
! grep -q 'exec.CommandContext(ctx, "/system/bin/sh"' proxy/main.go && echo "✅ No hardcoded"

# 2. On Linux/macOS
ls -la /bin/sh /usr/bin/sh 2>/dev/null

# 3. Verify sync.Once
grep -q 'systemShellOnce sync.Once' proxy/main.go && echo "✅ cached"
```

### 100. How do I know `runtime_info` returns correct values?

```bash
# 1. Change PORT to 8081
su -c "sed -i 's/^PORT=9090/PORT=8081/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"

# 2. Query
curl -s http://127.0.0.1:8081/api?action=runtime_info | jq '.webui_port'
# Expected: "8081"

# 3. Memory fields (v1.1.0)
curl -s http://127.0.0.1:8081/api?action=runtime_info | jq '{profile_key, memory_limit_mb}'
# Expected: {"profile_key": "pro", "memory_limit_mb": 120}

# 4. Restore original
su -c "sed -i 's/^PORT=8081/PORT=9090/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

---

## Contributing

### 101. How do I contribute?

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

### 102. How do I report a security vulnerability?

Do not open a public Issue. Use **GitHub Private Vulnerability Reporting**. See [`SECURITY.md`](SECURITY.md).

### 103. How do I translate the project?

- **README**: Add `README.<lang>.md`.
- **WebUI**: Add the required language in the `translations object` inside `index.html` and `dashboard.html`.
- **Docs**: Add `docs/<name>.<lang>.md`.

### 104. Is there a badge for contributors?

Yes! See [`HALL_OF_FAME.md`](HALL_OF_FAME.md).

**Available badges**:
- 🥇 Founder
- 🔥 Top Contributor
- 🛡️ Security Researcher
- 📖 Documentation
- 🌐 Translator
- 🧪 Testing Hero
- 💎 Compatibility Champ
- 🔍 Auditor
- 🔧 Platform Fixer
- 📊 Metrics Wizard
- ⚙️ Concurrency Guardian
- 🔌 Port Architect
- 🧠 Memory Architect (v1.1.0)

### 105. How do I add a question to the FAQ?

- Open an Issue titled `[FAQ] <your question>`.
- Or submit a PR directly on `docs/FAQ.md`.
- Make sure to add the appropriate number + correct section.
- Follow the existing answer pattern.

**Requirements**:
- ✅ New sequential number.
- ✅ Appropriate section (General, Installation, ...).
- ✅ Links to SECURITY.md / TROUBLESHOOTING.md where applicable.
- ✅ Practical example (bash or JSON).

### 106. How do I know the next Audit Correction number?

- Last Audit Correction: **#33** (runtime_info ports).
- Next expected: **#34** (v1.2.x).

**Note**: v1.1.0 did not add audit corrections. It introduced
three runtime improvements (MEM-1/2/3) that are documented
separately in SECURITY.md §17.1.

**See**: [`CHANGELOG.md`](../CHANGELOG.md).

### 107. How do I add a new verification for a fix?

Use grep-based verification in the CI workflow (`.github/workflows/ci.yml`).

**Patterns**:
- **Static audit** (shell): `grep -q 'pattern' file`
- **Build verification**: `go build -buildvcs=false -trimpath -o /tmp/main main.go`
- **Runtime check**: `curl -s http://127.0.0.1:9090/api?action=X | jq`

### 108. How do I add a RACE-1 verification?

```bash
# Static audit
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ mutex declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"
```

### 109. How do I add a PORT-2 verification?

```bash
# Backend audit
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ webui_port"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"dashboard_port"' && echo "✅ dashboard_port"

# Frontend audit
grep -q 'data.dashboard_port' web/index.html && echo "✅ index.html"
grep -q 'data.webui_port' web/dashboard.html && echo "✅ dashboard.html"
```

### 110. What is the difference between "Fix #N" and "NEW-N"?

**Fix #N** (N=1..12): v1.0.0 **original** fixes (Dashboard JSON, Shell fallback, Preserve settings, ..., CodeQL config).

**NEW-N** (N=1..6): **Additional** security fixes discovered later:
- NEW-1: Login POST-only (CSRF).
- NEW-2: `hasEndpoint` usage.
- NEW-3: `readConfPort` range check.
- NEW-4: `/readyz` localhost-only.
- NEW-5: `shellQuote` injection protection.
- NEW-6: Auth cache (60 s).

**RACE-1** + **PORT-2**: Two **architectural** fixes:
- RACE-1: `rebuildMu` mutex (concurrency).
- PORT-2: `runtime_info` ports (dynamic).

**MEM-1** + **MEM-2** + **MEM-3**: v1.1.0 **runtime improvements**
(not audit corrections):
- MEM-1: Dynamic memory limit per profile.
- MEM-2: Extended `shellQuote` character set.
- MEM-3: `MONITORING_UI_PORT` in metrics handler.

**Full numbering**: Fix #1-#12 + NEW-1..NEW-6 + RACE-1 + PORT-2 +
MEM-1/2/3.

---

## 📚 References

- [README.md](../README.md) — Overview
- [docs/INSTALL.md](INSTALL.md) — Installation guide
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/SECURITY.md](SECURITY.md) — Security policy + Audit Corrections
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — System architecture
- [docs/API.md](API.md) — HTTP API reference
- [docs/DEVELOPMENT.md](DEVELOPMENT.md) — Developer guide
- [docs/DNS_BINARIES.md](DNS_BINARIES.md) — DNS binaries management
- [docs/UPGRADE.md](UPGRADE.md) — Upgrade guide
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guide
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) — Contributors recognition
- [docs/ROADMAP.md](ROADMAP.md) — Project plan
- [CHANGELOG.md](../CHANGELOG.md) — Version history
- [GitHub Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues)

---

*Last updated: 2026-09-26*
*Version: v1.1.0*
*Author: gasciljh*