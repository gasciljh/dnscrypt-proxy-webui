# FAQ — Frequently Asked Questions

> Quick answers to 150+ common questions.

**Version**: v1.4.0
**Last updated**: 2026-10-02
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

> **v1.4.0 changes**:
>   • Version bumped from v1.3.0 to v1.4.0.
>   • Added new section: **"v1.4.0 Specific Questions"** (Q141–Q150),
>     covering the companion Android app, CodeQL hardening, and
>     iOS PWA removal.
>   • Added new section: **"v1.3.0 Specific Questions"** (Q131–Q140),
>     covering the PWA install button, live status LED, and DNS
>     auto-start after boot.
>   • Updated Q8 (What's new) to describe v1.4.0.
>   • Updated Q14 (Installation) — new ZIP filename.
>   • Updated Q64 (Uninstall) — companion APK handling.
>   • Updated Q66 (Rollback) — v1.4.0 caveats.
>   • References updated to point at v1.4.0.
>   • **Global edition (English default + Arabic toggle)**: the
>     WebUI ships with English as the default language and an
>     in-page toggle (`langToggle`) that switches to Arabic. The
>     user's preference is stored client-side in
>     `localStorage['dnscrypt-lang']`. Documentation remains
>     English-only by project convention.

> **v1.3.0 changes (carried forward)**:
>   • Version bumped from v1.2.0 to v1.3.0.
>   • PWA install button added (dynamic, browser-aware).
>   • Live status LED added on the Today counter.
>   • Critical fix: DNS engine now starts automatically after boot
>     (via a direct API call from `service.sh`).
>   • No breaking changes.

> **v1.2.0 changes (carried forward)**:
>   • Version bumped from v1.1.0 to v1.2.0.
>   • Added section: **"v1.2.0 Specific Questions"** (Q121–Q130),
>     covering the 10 data-preservation layers, the persistent
>     backup directory, recovery mode, transactional upgrades,
>     and the `runtime_info.backups` 7-field schema.
>   • Updated Q8 (What's new) to also describe v1.2.0.
>   • Preserved the v1.0.0-specific section (Q78–Q89) and the
>     v1.1.0-specific section (Q111–Q120) as-is.
>   • No questions were removed.

> **📖 Related documents**:
> - Backup system reference → [`docs/BACKUP.md`](BACKUP.md)
> - Emergency recovery → [`docs/EMERGENCY.md`](EMERGENCY.md)
> - Version upgrade guide → [`docs/UPGRADE.md`](UPGRADE.md)
> - Branching strategy → [`docs/BRANCHING.md`](BRANCHING.md)
> - Release process → [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md)

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
- [v1.2.0 Specific Questions](#v120-specific-questions)
- [v1.3.0 Specific Questions](#v130-specific-questions)
- [v1.4.0 Specific Questions](#v140-specific-questions)
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
| WebUI (English + Arabic) | ❌ | ✅ |
| Dashboard | ❌ | ✅ (JSON metrics) |
| Auto-updated lists | ⚠️ | ✅ (5 sources) |
| PWA | ❌ | ✅ |
| Zero telemetry | ⚠️ | ✅ |
| Dynamic memory limit | ❌ | ✅ (v1.1.0) |
| Data preservation | ❌ | ✅ (v1.2.0) |
| **PWA install button** | ❌ | ✅ **(v1.3.0)** |
| **Live status LED** | ❌ | ✅ **(v1.3.0)** |
| **Companion Android app** | ❌ | ✅ **(v1.4.0)** |

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

### 8. What's new in v1.4.0?

**Integration release — companion Android app + CodeQL cleanup.**

**No breaking changes for users.** The WebUI remains bilingual
(English default + Arabic toggle).

**What's new**:

- **Companion Android app** — a native WebView wrapper (~3 MB) is
  now bundled into the module ZIP as an OPTIONAL asset
  (`web/app-debug.apk`). Served at `GET /app-debug.apk` by
  `main.go`. The WebUI install button is now a direct
  `<a download>` link.
- **CodeQL `go/path-injection` hardening** — `removeModule` in
  `main.go` now uses `filepath.Base()` sanitization. No outstanding
  CodeQL alerts.
- **iOS PWA logic removed** — Android-only project. Removed
  `isIOSDevice()`, iOS-specific translations, and iOS branches in
  the PWA install flow.

**What's carried forward from earlier releases**:

- **v1.3.0**: PWA install button, live status LED, DNS auto-start
  after boot.
- **v1.2.0**: 10 data-preservation layers, persistent backup
  directory, recovery mode, transactional upgrades,
  `runtime_info.backups` 7-field schema.

**See also**: [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0]. See
Q141–Q150 for the specifics of v1.4.0, Q131–Q140 for v1.3.0.

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

**v1.2.0 addition**: Full support for APatch's module folder
lifecycle (Layer 5). The installer checks `modules_update/` as a
fallback source when APatch has already deleted the old module
folder.

### 12. What is the oldest supported Android version?

**Android 5.0** (API 21). Recommended: **Android 10+**.

**v1.2.0 note**: On Android 5.x, the backup layer falls back to
size checks if `sha256sum` is missing. See
[`docs/COMPATIBILITY.md`](COMPATIBILITY.md) §5.5.

### 13. What are the minimum requirements?

- Android 5.0+
- 1 GB RAM
- 20 MB storage
- **10 MB on `/sdcard/`** (v1.2.0 backup)
- Root (Magisk/KernelSU/APatch)
- Kernel 3.10+

### 14. How do I install the module?

See [`INSTALL.md`](INSTALL.md). In short:

1. Download `dnscrypt-webui-1.4.0-module.zip` from
   [Releases](https://github.com/gasciljh/dnscrypt-proxy-webui/releases).
2. Install via Magisk Manager → Modules.
3. Reboot.
4. Open `http://127.0.0.1:9090` from a browser.

**Optional (v1.4.0)**: The module ZIP may contain the companion
Android app (`web/app-debug.apk`). You can install it from the
WebUI install button (a direct `<a download>` link) or by
navigating to `http://127.0.0.1:9090/app-debug.apk`.

### 15. Can I install multiple DNS modules together?

**No**. DNSCrypt + AdAway → conflict.
DNSCrypt + VPN → conflict.

You can use:
- DNSCrypt Smart Filter **instead of** AdAway.
- DNSCrypt Smart Filter **with** AFWall+ (they do not conflict).

### 16. Are settings lost on upgrade?

**No** — since v1.0.0, and greatly hardened in v1.2.0. See Q57,
Q73, and Q121.

**v1.2.0 difference**: The v1.0.0 mechanism used
`/data/local/tmp/`, which was cleared on reboot. v1.2.0 uses
`/sdcard/dnscrypt-webui-backup/`, which survives uninstall and
factory reset of `/data`.

**v1.3.0 and v1.4.0**: The backup layer is unchanged from v1.2.0.

---

## Usage

### 17. How do I open the interface?

**From Magisk**:
- Open Magisk Manager → Modules → **Action**.

**Manually**:
- Open the browser at `http://127.0.0.1:9090`.

**From the companion app (v1.4.0)**:
- If installed, the companion app opens the same WebUI in a native
  WebView wrapper.

### 18. I forgot my password. What do I do?

```bash
su -c "cat /data/local/tmp/dnscrypt_credentials.txt"
```

Or:

```bash
su -c "grep -A2 '\[monitoring_ui\]' /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-proxy.toml"
```

**v1.2.0 note**: The credentials are also in the persistent backup
at `/sdcard/dnscrypt-webui-backup/current/dnscrypt-proxy.toml`.

### 19. How do I change the port?

Edit `webui.conf`:

```bash
su -c "nano /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# PORT=9191
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

⚠️ **Warning**: Do not use port 8080 (reserved for monitoring_ui).
The system will refuse to start.

⚠️ **Fix NEW-3**: Invalid values (`0`, `99999`, `-1`, `abc`) →
automatic fallback to default.

**v1.2.0 note**: The new port is preserved by the 10 defensive
layers on the next upgrade.

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

**v1.2.0 addition**: A pre-critical backup is created
automatically before every save. See Q124.

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

1. The ad is served from the same domain as content (e.g. YouTube,
   Facebook) → DNS cannot block it.
2. The application uses its own DoH servers (hardcoded) → bypasses
   system DNS.
3. Cache → restart the device or clear browser cache.
4. You are using a weak list → try "PRO" or "Ultimate".

### 25. How do I block YouTube ads?

It's difficult to block them via DNS for the following reasons:
- Ads come from the same domain as `youtube.com` and
  `googlevideo.com`.
- Blocking the entire domain would disable YouTube videos entirely.

**Solutions**:
- Use YouTube Vanced / ReVanced (modified versions).
- Or use a browser with a built-in AdBlock (e.g. Brave, Firefox).

### 26. How do I block Facebook / Instagram ads?

DNS can block:
- `graph.facebook.com` (API)
- `an.facebook.com` (ads)
- `connect.facebook.net`

**However**: Ads integrated into the Feed may not be blocked
because they come from the same source as posts.

### 27. Why is DNS sometimes slow?

Reasons:

1. A slow remote resolver → DNSCrypt-proxy switches servers
   automatically but takes some time.
2. Using a very large list (Ultimate = 500K entries) delays engine
   startup.
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

No. The VPN app routes all traffic through its own tunnel,
bypassing `iptables`.

**Alternatives**:
- Use DNSCrypt inside a VPN app if it supports custom DNS
  (DNSCrypt-over-VPN).
- Or use only one of them.

### 30. What is the difference between DNSCrypt and DoH?

| Protocol | Port | Protocol | Encryption |
|---|:---:|:---:|---|
| **DNSCrypt** | 443 | UDP/TCP | X25519 + XSalsa20 |
| **DoH** | 443 | HTTPS | TLS 1.3 |
| **DoT** | 853 | TLS | TLS 1.3 |

Both are fully secure, but DNSCrypt is preferred on weak mobile
networks due to its lower data overhead.

---

## Dashboard & Monitoring

### 31. What is the Dashboard?

A separate monitoring panel on `http://127.0.0.1:9091` that
displays:
- Total + blocked queries.
- Cache hit ratio.
- Resolver health.
- Top queried domains.
- Last 30 queries.

### 32. Why doesn't the Dashboard show any data?

**Before v1.0.0**: This was a known issue (Dashboard broken) due
to Prometheus text → JSON conversion.

**Now**: In v1.4.0 (and v1.0.0+), it works correctly. Verify:

```bash
# 1. Version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.4.0

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

**Before v1.0.0**: `index.html` and `dashboard.html` links were
hardcoded (`127.0.0.1:9090/9091`) → broken when ports are changed.

**After v1.0.0 (PORT-2)**: Links are dynamically built from
`runtime_info`:
- Uses `window.location.hostname` (supports LAN).
- Falls back to 9090/9091 before `runtime_info` loads.
- Works with any custom port.

**To verify**:

```bash
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'"
```

**v1.1.0+ addition**: The System Info panel shows profile + memory.
See Q117.

**v1.2.0 addition**: The System Info panel also shows backup state
(6 user-facing fields). See Q127.

---

## Performance & Battery

### 38. How much battery does it consume?

In normal use:
- ~1-2% / day (DNS queries processed locally).
- ~5-10% / day (when downloading new lists — rare).

**Conclusion**: Never drains the battery — it is not a VPN app and
does not require a persistent connection.

### 39. How much memory does it consume?

- Idle WebUI: ~15 MB
- DNS Engine: ~5 MB
- **Total**: ~20-25 MB only.

**v1.1.0+**: The WebUI now has a **dynamic soft memory limit**
per profile. This is not the actual RSS usage; it is the ceiling
at which the Go runtime starts GC more aggressively. See Q43 and
Q111.

### 40. Does it slow down the internet?

No. On the contrary:
- The local DNS cache provides faster responses for previously
  visited pages.
- DNSCrypt/DoH may be faster than the ISP's default DNS.

### 41. The device gets hot. Why?

Possible reasons:

1. The blocklist is huge (Ultimate) → takes a long time to load
   into memory.
2. Watchdog loop (service failing repeatedly) → but exponential
   backoff prevents this.
3. Old CPU → blocking 500K entries consumes resources on a weak
   processor.

**Solution**:
- Try "Light" or "Normal" instead of Ultimate.
- Disable `AUTO_RESTART_*` options in settings.

### 42. Are there performance improvements in v1.0.0?

Yes:

- **`isRunDirUsable` cache** (30 s) — prevents repeated I/O on
  every `/readyz`.
- **`isPortOpen` native Go** — instead of `fork/exec` (~30×
  faster).
- **`isPortOpenCached` per-port map** — correct cache per port.
- **`getSystemShell` sync.Once** — no overhead after first call.
- **Auth cache (60 s)** — `getMonitoringAuth` ~0.05ms instead of
  ~5-10ms.
- **`hasEndpoint` (string equality)** — <100 ns instead of O(n)
  `strings.Contains`.

**Impact**: Less CPU, faster response, less disk I/O.

### 43. What performance improvements came in v1.1.0 / v1.2.0 / v1.3.0 / v1.4.0?

**v1.1.0 — MEM-1 (Dynamic memory limit per profile)**:

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
| proplus | 160 MB |
| ultimate | 220 MB |

**v1.2.0 — Backup layer storage metrics**:

| Metric | Value |
|---|---|
| Size per snapshot | ~30–100 KB (5 config files) |
| Total with rotation (21 snapshots) | ~2 MB max |
| Backup duration | < 5 seconds |
| Restore duration | < 3 seconds |
| Rotation policy | Keep 21 newest by directory name |
| Pre-critical backup frequency | On every destructive write |
| Periodic backup interval | 24 h (service.sh) |

**v1.3.0 — DNS auto-start after boot**:

- **Before**: DNS engine could take up to 60 s to start after
  reboot (Watchdog's first API call fires after a 30 s backoff,
  and the WebUI may not be ready yet).
- **After**: `service.sh` performs a direct, bounded wait for the
  WebUI to be ready (up to 60 s), then calls
  `POST /api/ensure_running_service` itself. DNS starts within a
  few seconds.

**v1.4.0 — No performance change**:

- The companion APK is a static asset, not a running process.
- The CodeQL fix in `removeModule` is internal and does not affect
  runtime performance.
- The removed iOS PWA logic was client-side only.

**Does `rebuildMu` slow down rebuildBlocklist?**

No. `rebuildBlocklist` takes ~200 ms (100K) or ~1 s (500K). The
coarse-grained lock adds no noticeable overhead.

**However**: When `updateProfile` + `saveAllowlist` run
simultaneously, they serialize — may seem slightly slower
(acceptable — rare operation).

**Does `backupMu` slow down save operations?**

No. `backupMu` serializes pre-critical backups, but each backup
takes < 5 s and runs in parallel with the main write operation
(both are best-effort). The user perceives no delay.

See Q121–Q130 for the full v1.2.0 picture, Q131–Q140 for v1.3.0,
Q141–Q150 for v1.4.0.

---

## Security & Privacy

### 44. Is my data safe?

Yes.
- Everything is processed locally.
- No third-party connections.
- Zero telemetry.
- Credentials are generated with high entropy.

**v1.2.0 addition**: Your **user configuration** is now preserved
in a persistent backup at `/sdcard/dnscrypt-webui-backup/`. See
Q123.

### 45. Can a malicious app steal my data?

Very difficult for the following reasons:
- WebUI server is available only on `127.0.0.1` (no external
  network access).
- Authentication is mandatory.
- Rate limiting for login + Basic Auth.
- Session cookies protected with `HttpOnly`, `SameSite=Lax`.
- Secure cookies enforced.
- Login POST-only (prevents CSRF).
- `/readyz` localhost-only (prevents reconnaissance).

*Only exception*: Any app with full root privileges can read
everything on the device.

**v1.2.0 note**: The persistent backup directory is owned by root
with mode `0700`. A malicious root app can still read it, but a
non-root app cannot. See [`docs/BACKUP.md`](BACKUP.md) §12.

**v1.4.0 note**: The companion APK is served at
`GET /app-debug.apk` subject to the same authentication as every
other protected route.

### 46. What is BIND_ADDR?

The listening address for the WebUI.
- `127.0.0.1` (default): Local access only.
- `0.0.0.0`: Whole network → refuses to start unless strong
  credentials are set.

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

Default (`127.0.0.1`) means it cannot be accessed from any external
device.

### 49. Are my queries logged?

- **Locally**: Yes (saved in `dnscrypt-blocked.log` and
  `dnscrypt-query.log`). Can be disabled in `dnscrypt-proxy.toml`.
- **Externally**: No. The DNSCrypt/DoH provider does not know your
  identity.

### 50. Why was STATUS_FILE behavior changed?

In previous versions, `STATUS_FILE` was written by the read-only
`getStatusUncached` function — causing loss of "user intent" when
the DNS engine crashed.

**After v1.0.0**:
- `STATUS_FILE` = "User Intent" only.
- Written only by `startService()` / `stopService()`.
- Watchdog restarts reliably after any crash.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #18.

### 51. Why does the module refuse port 8080?

Port `8080` is reserved for `monitoring_ui` (dnscrypt-proxy's
internal interface).
- `main.go` refuses to start if `PORT=8080` or
  `DASHBOARD_PORT=8080`.
- `customize.sh` automatically replaces any `8080` value in
  `webui.conf` with `9090` / `9091`.

**v1.1.0**: The reserved port is now also enforced as a Go
constant (`MONITORING_UI_PORT`) in `metricsProxyHandler`. See
Q120.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #20.

### 52. Do Custom Chains pollute the firewall?

No. Since v1.0.0, the module uses Custom Chains
(`DNSCRYPT_OUT` / `DNSCRYPT_OUT6`) instead of writing directly to
OUTPUT:
- Public `OUTPUT` contains only two static rules (jump rules).
- All dynamic rules are inside the dedicated chains.
- Cleanup = `-F` + `-X` (complete wipe in one shot).
- No orphans even if you change `bootstrap_resolvers` hundreds of
  times.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #17.

### 53. Why is Basic Auth now rate-limited?

**Before v1.0.0**:
- `handleLogin` (POST `/api/auth/login`) was protected by rate
  limiting.
- But `checkAuth` (accepts Basic Auth) **did not** record failed
  attempts.
- **Result**: An attacker on LAN could send unlimited Basic Auth
  requests.

**After v1.0.0**:
- Basic Auth is limited to **5 attempts / 15 minutes** (per IP).
- Protects against brute force.
- Successful Basic Auth resets the counter.
- Lockout duration: **15 minutes** (same `LOGIN_LOCKOUT_PERIOD`).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #22.

### 54. Is the 404 for unknown actions a breaking change?

Yes, **for API consumers**.

**Before**: `GET /api?action=unknown` → `200 OK` +
`{"status": "unknown"}`.
**After**: `GET /api?action=unknown` → `404 Not Found` + a clear
message.

**Solution**: Update scripts to expect `404` (see
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)).

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

A function in `main.go` (Fix NEW-5) that wraps a path with safe
quotes for use in `runShell`.

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

The `readConfPort` function in `main.go` (Fix NEW-3) verifies the
range `[1, 65535]`:

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

A `sync.Mutex` that protects `rebuildBlocklist` from race
conditions:

```go
var rebuildMu sync.Mutex

func rebuildBlocklist() error {
    rebuildMu.Lock()
    defer rebuildMu.Unlock()
    // ...
}
```

**Before**: `updateProfile` + `saveAllowlist` concurrent →
inconsistent BLOCKLIST.
**After**: Both operations serialized → BLOCKLIST always
consistent.

**Constraint**: Rebuild may seem slower during concurrent edit
(acceptable — rare operation).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

### 59. What is the Auth cache (60 s)?

`getMonitoringAuth` caches credentials for 60 seconds:

```go
const AUTH_CACHE_TTL = 60 * time.Second
```

**Before**: Every HTTP request reads the TOML (~5-10 ms).
**After**: Cache hit → ~0.05 ms.

**Constraint**: Changing credentials in the TOML → applies after
≤ 60 s.
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

**v1.2.0 (BAK-1)** — the `backups` object with **7 fields**:

```json
{
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-10-02 15:00:00",
    "last_backup_name": "20261002-150000-v1.4.0",
    "last_stable": "20261002-150000-v1.4.0",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

**Benefits**:
- HTML/JS updates links dynamically.
- Supports LAN access.
- Supports IPv6 loopback.
- No broken links when ports change.
- System Info panel shows profile + memory limit + backup state.

**Constraint**: PWA shortcuts (`manifest.json`) do not read
`runtime_info` — they stay static (documented).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #33 + §5.30.1 +
§5.31.4.

---

## Updates & Maintenance

### 61. How do I update the module?

1. **From Magisk**: Modules → DNSCrypt → Update (if auto-update is
   enabled).
2. **Manually**: Download the new ZIP → install over the old one.

**v1.2.0 note**: The installer now preserves all 5 user config
files across the update. See Q123.

**v1.4.0 note**: If the new ZIP contains a companion APK, it is
extracted to `web/app-debug.apk`. The existing APK (if any) is
replaced.

### 62. How do I update the lists?

- **Automatically**: On every restart.
- **Manually**: From the WebUI → choose the desired list → Apply.

### 63. How do I copy settings to another device?

**v1.2.0 (recommended)**:

```bash
# 1. Export the persistent backup directory
adb pull /sdcard/dnscrypt-webui-backup/ ./my-backup/

# 2. On the new device, push the backup
adb push ./my-backup/ /sdcard/dnscrypt-webui-backup/

# 3. Install the module on the new device — it will auto-restore
```

**Legacy (still works)**:

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

**v1.2.0 note**: `uninstall.sh` now **preserves** the persistent
backup directory (`/sdcard/dnscrypt-webui-backup/`) so you can
restore your settings if you reinstall later. See Q126.

**v1.4.0 note**: The companion APK (`web/app-debug.apk`) is a build
artifact of the module ZIP and is removed with the module folder.
However, the **separately-installed** companion app (if the user
installed it from the WebUI) remains on the device — just like any
other Android app.

To remove the backup directory manually:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

To remove the companion app (if installed):

- From the system's **Settings → Apps** → DNSCrypt Proxy → Uninstall.

### 65. Are settings preserved on upgrade?

**Yes** — since v1.0.0, and greatly hardened in v1.2.0:

- ✅ `webui.conf` preserved.
- ✅ `dnscrypt-proxy.toml` preserved.
- ✅ `allowlist.txt` + `denylist.txt` preserved.
- ✅ `selected_profile.txt` preserved.

**How it works (v1.2.0)**:

1. Layer 1 — multi-source detection finds the user data.
2. Layer 2 — persistent backup to `/sdcard/`.
3. Layer 3 — SHA256 verification.
4. Layer 4 — transactional install with rollback.
5. Layer 5 — root-solution compatibility (Magisk / KernelSU / APatch).
6. Layer 6 — SELinux context preservation.
7. Layer 7 — recovery mode (if triggered).
8. Layer 8 — config migrations.
9. Layer 9 — rotation (keep max 21 snapshots).
10. Layer 10 — observability.

See [`docs/BACKUP.md`](BACKUP.md) §1.3 for the full model.

**Reference**: [SECURITY.md](SECURITY.md) — Audit #26 (v1.0.0
mechanism, now superseded) + §5.31 (v1.2.0 model).

### 66. How do I roll back to a previous version?

```bash
# 1. Download the previous version's ZIP from GitHub Releases
# 2. Install over the new one from Magisk
# 3. Reboot
su -c "reboot"

# 4. Verify
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
```

**Note**: Settings are preserved on rollback (since v1.0.0,
hardened in v1.2.0).

**Rollback caveats**:

- **From v1.4.0 to v1.3.0**:
  - ⚠️ The companion APK (`web/app-debug.apk`) is removed with the
    module ZIP.
  - ⚠️ The WebUI install button reverts to the PWA-flow behavior
    (was a direct `<a download>` link in v1.4.0).
  - ⚠️ `removeModule` reverts to the pre-CodeQL-fix version
    (functionally equivalent, but CodeQL alerts may reappear).
  - ⚠️ iOS PWA logic is restored (iOS users see iOS instructions).
- **From v1.3.0 to v1.2.0**:
  - ⚠️ PWA install button reverts to a modal-based flow.
  - ⚠️ Live status LED on the Today counter is removed.
  - ⚠️ DNS auto-start after boot reverts to the Watchdog-only path
    (may take up to 60 s).
- **From v1.2.0 to v1.1.0**:
  - ⚠️ `runtime_info.backups` reverts to 5 fields.
  - ⚠️ `action.sh --backup` stops working.
  - ⚠️ `status.sh --diagnose` stops working.
  - ⚠️ The `/sdcard/dnscrypt-webui-backup/` directory is preserved
    (not touched).
- **From v1.1.0 to v1.0.0**:
  - ⚠️ Dynamic memory limit reverts to hardcoded 80 MB.
  - ⚠️ `runtime_info` loses `profile_key` / `memory_limit_mb`.
  - ⚠️ `shellQuote` reverts to 20 chars.
- **From v1.0.0 to pre-v1.0.0**: Not recommended (data loss
  possible).

See [`UPGRADE.md`](UPGRADE.md) for the full upgrade path.

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
| v1.2.0 | 1020000 |
| v1.2.1 | 1020001 |
| v1.3.0 | 1030000 |
| v1.4.0 | 1040000 |
| v1.4.1 | 1040001 |
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
5. **v1.2.0**: Run the full diagnostic:
   ```bash
   su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
   ```

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

**v1.2.0 alternative**: Use recovery mode (Q125) — it restores
the last known-good config without reinstalling.

### 71. Dashboard does not display metrics. What do I do?

- **Symptom**: The Dashboard (`:9091`) opens, but Metrics tables
  are empty.
- **Cause (before v1.0.0)**: `metricsProxyHandler` returned
  Prometheus text with `Content-Type: application/json`.
- **Solution**: Update to `v1.4.0` (or v1.0.0+).

**Verify**:

```bash
su -c "curl -s http://127.0.0.1:9091/api/metrics" | jq '.total_queries'
# Expected: a number
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #25.

### 72. Watchdog does not restart after a crash. What do I do?

- **Symptom**: DNS Engine crashes; Watchdog runs but does nothing.
- **Cause (before v1.0.0)**: WebUI called `getStatus` every 10
  seconds, and `getStatusUncached` wrote `STATUS_FILE = "OFF"` on
  crash.
- **Solution**: Update to `v1.4.0` (or v1.0.0+).

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
- **Cause (v1.1.0 only)**: A path-comparison check
  (`$_EXISTING_MODULE != $MODPATH`) silently failed on in-place
  upgrades. Result: the 5 user config files were lost on every
  upgrade from v1.1.0.
- **Solution**: Update to **v1.4.0** — the 10 defensive layers
  replace the broken check with multi-source detection (Layer 1)
  and persistent backup (Layer 2).

**If you lost settings on v1.1.0**:

```bash
# v1.2.0+ preserves the backup at /sdcard/dnscrypt-webui-backup/.
# After installing v1.4.0, the installer will restore them automatically.
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"
```

**Legacy recovery** (v1.0.0-style automatic backup):

```bash
# Look for the old backup in /data/local/tmp/
BACKUP=$(ls -dt /data/local/tmp/dnscrypt-upgrade-backup-* 2>/dev/null | head -1)
[ -n "$BACKUP" ] && su -c "cp $BACKUP/webui.conf /data/adb/modules/dnscrypt-proxy-webui/proxy/"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) §7.8.

**Reference**: [SECURITY.md](SECURITY.md) §5.31.1 (root cause) +
[`BACKUP.md`](BACKUP.md) §1.1.

### 74. Basic Auth is too restricted after upgrade. What do I do?

- **Symptom**: After upgrading, Basic Auth fails after 5 attempts.
- **Cause**: Intentional — Basic Auth is rate-limited.
- **Solution**:
  - ✅ **Solution 1**: Use correct credentials (will not be
    locked).
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

- **Symptom**: Some sites remain blocked even after being added to
  the allowlist.
- **Cause (before v1.0.0)**: `rebuildBlocklist` was not protected
  by a mutex → race condition with `updateProfile`.
- **Solution**: Update to `v1.4.0` (or v1.0.0+).

**Verify**:

```bash
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1 present"
```

**Reference**: [SECURITY.md](SECURITY.md) — Audit #32.

---

## v1.0.0 Specific Questions

> **Note**: This section documents the v1.0.0 features and
> verifications. It is preserved for historical reference and for
> users upgrading from pre-v1.0.0 releases.

### 78. How do I know a version contains v1.0.0?

Verify:

1. `VERSION` file = `v1.0.0` (for v1.0.0) / `v1.4.0` (for v1.4.0).
2. `module.prop` → `version=v1.0.0` / `version=v1.4.0`.
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

**v1.2.0**: **`backups` object** with 7 fields added:

```json
{
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-10-02 15:00:00",
    "last_backup_name": "20261002-150000-v1.4.0",
    "last_stable": "20261002-150000-v1.4.0",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

**v1.4.0**: No new fields added. The `/app-debug.apk` route is a
new **endpoint**, not a `runtime_info` field.

All previous fields remain (`version`, `commit`, `run_dir`, ...).

**Reference**: [SECURITY.md](SECURITY.md) — Audit #33 + §5.30.1 +
§5.31.4.

### 81. Did `/api/metrics` change its format?

**Yes** — `/api/metrics` now returns **JSON** instead of Prometheus
text (since v1.0.0):
- **Before**: Prometheus text with `Content-Type: application/json`
  (lies).
- **After**: JSON schema with `Content-Type: application/json;
  charset=utf-8`.

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
- **After**: `proxy/run/*` + `!proxy/run/.gitkeep` (works
  correctly).

**v1.2.0 addition**: New pattern for data-preservation test
artifacts (`/tmp/dnscrypt-*`, backup staging files, `txn-*/` for
local testing). See `.gitignore` §[19].

**v1.4.0 addition**: The companion APK is ignored via
`web/app-debug.apk` (see `.gitignore` §[20]).

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

**v1.2.0 adds**:

| Anchor | Topic |
|---|---|
| #531 | Data Preservation Security Model (10 layers + `backupMu`) |
| #532 | Recovery Mode Correctness Fix (§[8a] → §[9]) |

**v1.3.0 adds**: no new sections (correctness fix in
`service.sh` was runtime-only).

**v1.4.0 adds**: no new sections (CodeQL fix is internal).

**See** [`docs/SECURITY.md`](SECURITY.md) for full details.

### 85. What's new in `.pre-commit-config.yaml`?

**Updated** to support v1.2.0 checks. See the file itself for the
exact hook list.

**Note**: No new hook was added in v1.2.0, v1.3.0, or v1.4.0 — the
existing `shellcheck-py`, `go-fmt`, and `go-build` hooks already
cover the changes.

### 86. What's new in the Makefile?

The Makefile gained **5 new targets** since v1.0.0:

```bash
make build          # Build all 4 architectures
make package        # Build + package (depends on fetch-apk)
make clean          # Clean outputs
make version        # Show version
make help           # Show help
make fetch-apk            # Fetch companion APK into dist/ (v1.4.0)
make check-app-version    # Validate proxy/app-apk.version (v1.4.0)
make check-backup         # Validate backup shell functions (v1.2.0)
make check-all            # Run all local validations (v1.2.0)
make diagnose-help        # Show device-side diagnostics (v1.2.0)
```

### 87. How do I run all v1.0.0 checks?

Use grep-based verification:

```bash
# See Q78 for the full list
```

### 88. What is `runtime_info`?

`runtime_info` is an API endpoint that returns build info + runtime
paths + actual ports.

**v1.4.0 example**:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq
```

```json
{
  "version": "v1.4.0",
  "commit": "a1b2c3d",
  "build_time": "1727856000",
  "build_time_human": "2026-10-02T10:00:00Z",
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
  "memory_limit_mb": 120,
  "backups": {
    "available": 5,
    "in_flight_txn": 0,
    "orphan_txn": 0,
    "last_backup": "2026-10-02 15:00:00",
    "last_backup_name": "20261002-150000-v1.4.0",
    "last_stable": "20261002-150000-v1.4.0",
    "path": "/sdcard/dnscrypt-webui-backup"
  }
}
```

See [`API.md`](API.md) §6.1.7 for full details.

### 89. What is the Auth cache?

A 60-second in-memory cache for credentials, reducing file I/O on
every HTTP request. See Q59.

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
continuously — a condition called **GC thrashing**. On low-RAM
devices, this manifested as a frozen or very slow WebUI.

**After v1.1.0**: The limit is computed per profile. No more GC
thrashing on `ultimate`, no wasted RAM on `light`.

**Symptom before the fix**:
- WebUI responds, but every action takes 2-5 seconds.
- CPU on the WebUI process > 30% while idle.
- Battery drains faster.

**v1.2.0 note**: The memory limit is preserved by the 10
defensive layers via `selected_profile.txt`, which is one of the
5 backed-up files. If you restore from a backup, the restored
profile determines the memory limit at startup.

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

**v1.2.0 additions**: The System Info panel now also displays
**6 backup fields**:

- **Backups** — snapshot count
- **Latest Backup** — newest snapshot name
- **Last Stable** — pointer content
- **In-flight Txn** — number of `txn-*` dirs
- **Orphan Txn** — number of `orphan-txn-*` dirs
- **Backup Path** — `/sdcard/dnscrypt-webui-backup`

**To see them**:

1. Open the WebUI at `http://127.0.0.1:9090`.
2. Scroll to "System Info".
3. Expand the section.

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

## v1.2.0 Specific Questions

> **Note**: This section covers the v1.2.0 changes: the 10
> defensive layers, the persistent backup directory, recovery
> mode, transactional upgrades, and the `runtime_info.backups`
> 7-field schema.

### 121. What is new in v1.2.0?

**v1.2.0 is the Data Preservation Release** — the biggest
reliability improvement since v1.0.0.

**What it fixes**: A **data-loss bug** in v1.1.0 that silently
erased the 5 user config files on every in-place upgrade. This
was caused by a path-comparison check
(`$_EXISTING_MODULE != $MODPATH`) that always failed on
in-place upgrades, so the installer thought it was a fresh
install and overwrote the configs.

**What it adds** — the 10 defensive layers (see Q122).

**No breaking changes for users**: v1.2.0 remains **fully
backward compatible** with v1.1.0.

- The WebUI stays bilingual (English default + Arabic toggle).
- The API stays identical (the `backups` object is strictly
  additive — 2 new fields).
- The 5 preserved config files keep their format.
- The `runtime_info` response only gains fields.

**Two important correctness fixes** (in addition to the 10
layers):

1. **Recovery-mode reorder** — the ZIP extraction step no longer
   overwrites the two restored files at risk (see Q125).
2. **Service Worker update banner** — the [Reload] button now
   sends `SKIP_WAITING` to the correct worker.

**New tools**:

- `action.sh --backup` — trigger a manual backup.
- `status.sh --diagnose` — full diagnostic report.

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.2.0];
[`docs/BACKUP.md`](BACKUP.md); [`docs/UPGRADE.md`](UPGRADE.md) §3.1.

### 122. What are the 10 defensive layers?

The 10 layers protect the **5 user config files**:

- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

| # | Layer | What it does |
|:-:|---|---|
| 1 | **Multi-source detection** | Searches 7 candidate locations for user data — in-place, standard, legacy, APatch, persistent `current/`, persistent flat, tmp fallback |
| 2 | **Persistent backup** | Snapshots to `/sdcard/dnscrypt-webui-backup/`, which survives reboot + uninstall + `/data` reset |
| 3 | **SHA256 integrity verification** | Advisory check: every snapshot records per-file SHA256 in `.manifest.json` |
| 4 | **Transactional upgrades** | Atomic install with rollback — either fully succeeds or fully rolls back |
| 5 | **Root-solution compatibility** | Detects Magisk / KernelSU / APatch and adapts the candidate list |
| 6 | **SELinux context preservation** | `restorecon` (or `chcon` fallback) on every restored file |
| 7 | **Recovery mode** | A `recovery` trigger file restores the last known-good config on next boot |
| 8 | **Config migrations** | Version-aware transformations (e.g. `MEMORY_LIMIT_HINT=auto` added for v1.0.0 → v1.2.0) |
| 9 | **Automation + rotation** | Periodic (24 h) + pre-critical backups; rotation keeps max 21 snapshots |
| 10 | **Observability** | `.upgrade_history.json` + `status.sh --diagnose` + 7-field `runtime_info.backups` |

**Full details**: [`docs/BACKUP.md`](BACKUP.md) §1.3;
[`docs/SECURITY.md`](SECURITY.md) §5.31.

### 123. Where are backups stored?

**Location**: `/sdcard/dnscrypt-webui-backup/`

**Structure**:

```text
/sdcard/dnscrypt-webui-backup/
├── current/                         ← live snapshot, always up to date
├── 20261002-095826-v1.4.0/          ← historical snapshot
├── 20261002-140000-auto/            ← periodic snapshot
├── 20261002-150000-manual/          ← manual or pre-critical snapshot
├── txn-<timestamp>-<pid>/           ← in-flight transaction
├── orphan-txn-<timestamp>-<pid>/    ← preserved interrupted install
├── .last_stable                     ← pointer to last known-good
├── .last_auto_backup                ← periodic marker (mtime)
├── .upgrade_history.json            ← full upgrade log
├── .upgrade_history.txt             ← fallback log
└── README.md                        ← user guide
```

**Why this location?** It survives:
- ✅ Rebooting.
- ✅ Module uninstall.
- ✅ Factory reset of `/data`.
- ✅ Module renames.

**You can inspect it** with any file manager or over USB (MTP).

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §3.

### 124. Do I need to backup manually?

**No, but it is recommended before major upgrades.**

**Automatic backups happen**:

- **At install time** — every upgrade creates a snapshot
  (`<timestamp>-<version>/`).
- **On every boot** — if the last auto-backup is older than
  24 hours, `service.sh` creates a new one.
- **Before destructive operations** — every destructive write
  (profile change, allowlist/denylist save, etc.) triggers a
  pre-critical backup. See BAK-2 in
  [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §4.10.2.

**Manual backup** (v1.2.0):

```bash
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --backup"
```

This creates a snapshot at:
```
/sdcard/dnscrypt-webui-backup/<timestamp>-manual/
```

**When to take a manual backup**:

- ✅ Before a major upgrade (e.g. v1.4.0 → v1.5.0).
- ✅ Before a factory reset of `/data`.
- ✅ Before uninstalling the module.
- ✅ Before any destructive test.

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §4, §7.

### 125. What is recovery mode?

**Recovery mode** restores the last known-good configuration
from the persistent backup, triggered by an explicit file.

**Use it when**:

- The module is unbootable but you can run commands via ADB.
- Data is corrupted but the backup directory is intact.
- You want a "one-shot" recovery without manual file copying.

**Procedure**:

```bash
# 1. Create the trigger file (module-specific)
su -c "touch /data/adb/modules/dnscrypt-proxy-webui/recovery"

# Or, if the module folder is inaccessible (external trigger)
su -c "touch /data/adb/dnscrypt-recovery"

# 2. Reboot
su -c "reboot"

# 3. Wait for boot (~30-60 seconds)

# 4. Verify the recovery
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --diagnose"

# 5. Confirm the trigger file is gone
su -c "ls /data/adb/modules/dnscrypt-proxy-webui/recovery 2>/dev/null"
# Expected: (no output)
```

**Recovery source priority**:

| Priority | Source |
|:--------:|--------|
| 1 | `$PERSISTENT_BACKUP/<.last_stable>/` |
| 2 | `$PERSISTENT_BACKUP/current/` |
| 3 | In-place `proxy/` directory |

**What recovery does NOT do**:
- ❌ Does not reinstall the module from scratch.
- ❌ Does not rebuild the firewall.
- ❌ Does not restart the DNS engine.

After recovery, you may need to reboot again (or restart the
service) for the changes to take effect.

**Full guide**: [`docs/EMERGENCY.md`](EMERGENCY.md) §9.

### 126. Does the backup survive uninstall?

**Yes.** The v1.2.0 `uninstall.sh` **preserves** the persistent
backup directory at `/sdcard/dnscrypt-webui-backup/`.

**Why?** So you can reinstall the module later and recover your
settings automatically (via the multi-source detection in
Layer 1).

**What is preserved on uninstall**:

- ✅ `current/` directory.
- ✅ All `<timestamp>-<version>/` snapshots.
- ✅ `orphan-txn-*` directories.
- ✅ `.last_stable` pointer.
- ✅ `.upgrade_history.json`.
- ✅ `README.md`.

**What is cleaned up on uninstall**:

- 🗑️ `txn-*` directories with `.state=COMMIT` or `.state=ROLLBACK`.
- 🗑️ The legacy v1.0.0 backup directory
  (`/data/local/tmp/dnscrypt_backup_uninstall/`).

**What is renamed on uninstall**:

- 🔄 `txn-*` with `.state=START` → renamed to `orphan-txn-*` and
  preserved.

**To remove the backup directory manually**:

```bash
su -c "rm -rf /sdcard/dnscrypt-webui-backup"
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §5.6;
[`docs/EMERGENCY.md`](EMERGENCY.md) §4.5.

### 127. What is `runtime_info.backups`?

It is a JSON object with **7 fields** describing the backup
state. Accessible via:

```bash
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
```

**Schema**:

```json
{
  "available": 5,
  "in_flight_txn": 0,
  "orphan_txn": 0,
  "last_backup": "2026-10-02 15:00:00",
  "last_backup_name": "20261002-150000-v1.4.0",
  "last_stable": "20261002-150000-v1.4.0",
  "path": "/sdcard/dnscrypt-webui-backup"
}
```

**Field meanings**:

| Field | Type | Description |
|---|---|---|
| `available` | int | Snapshot count (excludes `current/`, `txn-*`, `orphan-txn-*`) |
| `in_flight_txn` | int | Number of `txn-*` directories |
| `orphan_txn` | int | Number of `orphan-txn-*` directories |
| `last_backup` | string \| null | Timestamp of the newest snapshot |
| `last_backup_name` | string \| null | Directory name of the newest snapshot |
| `last_stable` | string \| null | Content of `.last_stable` pointer |
| `path` | string | Absolute path of the backup directory |

**Compatibility with `status.sh --json`**: The two endpoints
agree on all 7 shared fields. `status.sh --json` additionally
exposes two diagnostic-only fields (`status` and
`last_backup_age_seconds`) that are not part of the API surface.
See [`docs/API.md`](API.md) §6.1.7 and §10.6.

**How to detect a degraded backup layer**:

```bash
# Non-zero in_flight_txn or orphan_txn means attention is needed
curl -s http://127.0.0.1:9090/api?action=runtime_info \
    | jq 'select(.backups.in_flight_txn > 0 or .backups.orphan_txn > 0)'
```

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §8.1.

### 128. What are `txn-*` and `orphan-txn-*`?

**`txn-*` — In-flight transaction directory**:

- Created by `customize.sh` (Layer 4) during every install.
- Format: `txn-<timestamp>-<pid>/`.
- Contains a `.state` file: `START`, `COMMIT`, or `ROLLBACK`.
- Also contains the copied user files (for rollback).
- Short-lived.

**`orphan-txn-*` — Preserved interrupted install**:

- Created by `uninstall.sh` renaming a `txn-*` with
  `.state=START`.
- Signals that an install was interrupted mid-flight.
- The directory may contain the **only copy** of the user's data.
- **Preserved on purpose**. Inspect before deleting.

**How to inspect**:

```bash
# 1. Read the state
su -c "cat /sdcard/dnscrypt-webui-backup/txn-*/.state"
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.state"

# 2. Read the contents
su -c "ls -la /sdcard/dnscrypt-webui-backup/txn-*/"
su -c "ls -la /sdcard/dnscrypt-webui-backup/orphan-txn-*/"

# 3. Read the manifest
su -c "cat /sdcard/dnscrypt-webui-backup/orphan-txn-*/.manifest.json 2>/dev/null | jq"
```

**Handling**:

| State | Action |
|---|---|
| `COMMIT` | Safe to remove (main.go does this at startup) |
| `ROLLBACK` | Safe to remove |
| `START` | **Preserve** — inspect manually before deleting |
| `orphan-txn-*` | **Preserve** — user-managed |

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §5.6, §10.5;
[`docs/EMERGENCY.md`](EMERGENCY.md) §4.5.

### 129. How do I earn the Data Guardian badge?

**Data Guardian** is a recognition badge for contributors who
test the backup/restore system across devices, root solutions,
and upgrade scenarios.

**Acceptance criteria** (from
[`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md)):

- ✅ Test the 10 data-preservation layers on **3+ devices** or
  **3+ root solutions** (Magisk / KernelSU / APatch).
- ✅ Verify that all 5 user config files survive an in-place
  upgrade.
- ✅ Verify that recovery mode restores all 5 files.
- ✅ Report the 7-field `backups` object before/after each
  scenario.
- ✅ Report any mismatch with concrete evidence (logs +
  reproduction steps).

**Recommended scenarios to test**:

| Scenario | Expected result |
|---|---|
| Fresh install | 5 files created; no backup (first install) |
| In-place upgrade from v1.1.0 | 5 files preserved; snapshot created |
| In-place upgrade from v1.0.0 | 5 files preserved; `MEMORY_LIMIT_HINT=auto` added |
| Reinstall after uninstall | 5 files restored from `/sdcard/` backup |
| Recovery mode | 5 files restored; trigger file consumed |
| Renamed module folder | 5 files found via multi-source detection |
| APatch install | 5 files found via `modules_update/` fallback |
| Concurrency | Two rapid `save_allowlist` calls → no corrupted snapshot |

**How to report**: Open an Issue titled `[Hall of Fame] Data
Guardian: <your name>` with:
- The scenarios tested.
- The 7-field `backups` object for each.
- The `status.sh --diagnose` output.
- The `dnscrypt_install.log` excerpts.

**Reference**: [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) — Data
Guardian; [`docs/BACKUP.md`](BACKUP.md) §12.

### 130. How is v1.2.0 backup different from v1.1.0?

**v1.1.0 backup** (legacy mechanism):

- Location: `/data/local/tmp/dnscrypt-upgrade-backup-$$`.
- Deleted on reboot.
- **Lost on uninstall.**
- No SHA256 verification.
- No transactions.
- No recovery mode.
- No rotation.
- No history log.
- **Bug**: silently erased user data on every in-place upgrade
  due to the path-comparison check.

**v1.2.0 backup** (current mechanism):

- Location: `/sdcard/dnscrypt-webui-backup/`.
- **Survives reboot.**
- **Survives uninstall.**
- **Survives factory reset of `/data`.**
- SHA256 verification (advisory).
- Transactional install with rollback.
- Recovery mode via trigger file.
- Rotation (max 21 snapshots).
- Full history log (`.upgrade_history.json`).
- **Fixed the data-loss bug** via multi-source detection.

**Side-by-side**:

| Aspect | v1.1.0 | v1.2.0 |
|---|---|---|
| Location | `/data/local/tmp/` | `/sdcard/dnscrypt-webui-backup/` |
| Survives reboot | ❌ | ✅ |
| Survives uninstall | ❌ | ✅ |
| Survives `/data` reset | ❌ | ✅ |
| SHA256 verification | ❌ | ✅ |
| Transactions with rollback | ❌ | ✅ |
| Recovery mode | ❌ | ✅ |
| Rotation | ❌ | ✅ (21 snapshots) |
| History log | ❌ | ✅ |
| Multi-source detection | ❌ | ✅ (7 candidates) |
| Root-solution detection | ❌ | ✅ |
| SELinux preservation | ❌ | ✅ |
| **Data-loss bug** | ✅ Bug present | ✅ Bug fixed |

**Migration**: Upgrading from v1.1.0 to v1.2.0 is automatic.
On the next boot after install, `service.sh` runs
`auto_backup_if_needed` and creates the first persistent snapshot.
See [`docs/UPGRADE.md`](UPGRADE.md) §3.1.

**Reference**: [`docs/BACKUP.md`](BACKUP.md) §1.1, §1.4;
[`docs/SECURITY.md`](SECURITY.md) §5.31.1.

---

## v1.3.0 Specific Questions

> **Note**: This section covers the v1.3.0 changes: the PWA
> install button, the live status LED, and the DNS auto-start
> fix after boot.

### 131. What is new in v1.3.0?

**v1.3.0 is the Feature Release** — PWA install button + live
status LED.

**What it adds**:

1. **PWA install button** — a smart, dynamic install button
   that is **always visible** in the WebUI (except when the app
   is already installed or running standalone). Its behavior
   adapts to the browser:
   - Chromium-based browsers → native `beforeinstallprompt`
     dialog.
   - iOS Safari → "Add to Home Screen" instructions.
   - Unsupported browsers → friendly modal with supported
     alternatives (Chrome, Edge, Brave) and Play Store links.
2. **Live status LED** — a 12×12 LED on the "Today" counter
   that pulses green when the DNS engine is running and turns
   solid red when the service is stopped.
3. **DNS auto-start after boot** — a **critical fix** in
   `service.sh` (see Q132).

**No breaking changes** — fully compatible with v1.2.0.

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.3.0].

### 132. What was the DNS auto-start bug?

**Symptom** (before v1.3.0): After a device reboot, the DNS
engine was not running — even though the user had left the
service in the ON state before rebooting. The user had to open
the WebUI manually to trigger DNS start.

**Root cause**:

- `watchdog.sh` waits a fixed 30-second interval before its
  first API call to `POST /api/ensure_running_service`.
- By the time it fires, the WebUI may not have finished binding
  to its port yet.
- The Watchdog would retry with exponential backoff
  (30s → 60s → 120s → ...), leaving DNS unavailable for minutes
  after boot.

**The fix**:

- `service.sh` now performs a direct, bounded wait for the
  WebUI to become ready (up to 60 seconds, checking for the
  watchdog token file + the WebUI TCP port).
- Once ready, `service.sh` calls
  `POST /api/ensure_running_service` itself.
- DNS starts within a few seconds of the WebUI coming up.

**Verified on-device**: DNS engine reaches "ON" state within
5 seconds of `service.sh` startup, with 3 processes running
(webui + proxy + watchdog).

**The watchdog backoff is unchanged** — it still handles crash
recovery during normal runtime; only the boot path now takes
the direct route.

**Reference**: `service.sh` section [19]; `docs/ARCHITECTURE.md`
§5.2.

### 133. Does the PWA install button still work in v1.4.0?

**No — it was replaced by a direct `<a download>` link.**

**v1.3.0**: The install button used the browser's
`beforeinstallprompt` event (PWA flow). It adapted its behavior
per browser.

**v1.4.0**: The button is now a direct
`<a id="pwaInstallBtn" href="/app-debug.apk" download="DNS-Proxy.apk">`
link. Clicking it downloads the companion Android app APK
(see Q142).

**Why the change**:

- The companion app provides a better user experience than a
  PWA shortcut (native WebView, no browser tab).
- The `<a download>` link is simpler and works in every browser
  without `beforeinstallprompt` support.
- The PWA manifest and Service Worker are unchanged — you can
  still install the WebUI as a PWA through the browser's menu.

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0];
`web/index.html` section [13c].

### 134. What is the live status LED?

A small 12×12 colored circle on the "Today" counter in the
WebUI stats area.

**Behavior**:

- **Green (pulsing)** — DNS engine is running.
- **Red (solid)** — DNS engine is stopped.
- **Paused indicator** — when the service is OFF, the label
  shows "(paused — service stopped)".

**How it works**:

- Pure CSS + JS. No image files.
- Aligned with the existing `.status-dot` styling.
- Updated by the `updateStatsDisplay()` handler in
  `web/index.html`.

**Reference**: `web/index.html` section [13c];
[CHANGELOG.md](../CHANGELOG.md) §[v1.3.0].

### 135. Which browsers support the PWA install button?

In v1.4.0, the button is a direct `<a download>` link — it works
in **every browser**, because downloading a file is a universal
browser feature.

In v1.3.0, the button adapted to the browser:

| Browser | Behavior |
|---|---|
| Chrome 90+ | Native install dialog |
| Edge 90+ | Native install dialog |
| Brave | Native install dialog |
| Samsung Internet (recent) | Native install dialog |
| Firefox | Modal with "Install" instructions |
| iOS Safari | "Add to Home Screen" instructions |
| Old browsers | Modal listing supported alternatives |

**v1.4.0 note**: The modal is no longer shown. The button always
downloads the APK.

### 136. How do I know if the DNS auto-start fix is present?

**On-device check**:

```bash
# 1. Confirm the module version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.4.0 (or v1.3.0+)

# 2. Check for the direct API call in service.sh
su -c "grep -q 'ensure_running_service' /data/adb/modules/dnscrypt-proxy-webui/service.sh && \
       echo '✅ Direct API call present'"

# 3. Check for the bounded wait loop
su -c "grep -q '_wait_webui' /data/adb/modules/dnscrypt-proxy-webui/service.sh && \
       echo '✅ Bounded wait present'"

# 4. Runtime test
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --check"
# Expected: DNS=UP within 5-10 seconds
```

**In the repository**:

```bash
grep -q 'ensure_running_service' proxy/service.sh && echo "✅ Fix present"
grep -q '_wait_webui' proxy/service.sh && echo "✅ Bounded wait present"
```

### 137. Did the WebUI layout change in v1.3.0?

**Yes** — two additions:

1. **PWA install button** — a new button below the WebUI title
   (in the header).
2. **Live status LED** — a small circle inside the "Today"
   counter in the stats area.

**No layout redesigns** — the existing structure is preserved.

**v1.4.0 update**: The PWA install button is now a direct
`<a download>` link (visual appearance unchanged).

### 138. Is v1.3.0 compatible with v1.2.0 backups?

**Yes.** The 10 defensive layers introduced in v1.2.0 are
**unchanged** in v1.3.0 and v1.4.0.

- The persistent backup directory still lives at
  `/sdcard/dnscrypt-webui-backup/`.
- The rotation policy is still 21 snapshots.
- The `runtime_info.backups` schema is still 7 fields.
- The `backupMu` serialization guarantee is unchanged.

**No new config migration was added** in v1.3.0.

### 139. Does the live status LED use network bandwidth?

**No.** The LED is updated by:
- The existing SSE stream (`/events`), which was already in use
  for status updates.
- The existing periodic `/api?action=status` polling.

**No new endpoint** was added.

### 140. Can I disable the PWA install button or the status LED?

**Not through the WebUI.** There is no user-facing setting for
either feature.

**Advanced (not recommended)**: You can hide them via a custom
CSS override in the browser's DevTools, but the change is not
persistent.

**v1.4.0 note**: Since the button is now a direct download link,
users who do not want the companion app can simply ignore it —
it does not interfere with normal usage.

---

## v1.4.0 Specific Questions

> **Note**: This section covers the v1.4.0 changes: the companion
> Android app, the CodeQL hardening, and the iOS PWA removal.

### 141. What is new in v1.4.0?

**v1.4.0 is the Integration Release** — companion Android app +
CodeQL cleanup.

**What it adds**:

1. **Companion Android app** — a native WebView wrapper (~3 MB)
   from the sister repository
   [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)
   is now bundled into the module ZIP as `web/app-debug.apk`
   (OPTIONAL).
2. **CodeQL `go/path-injection` fix** in `removeModule`
   (`main.go`).
3. **iOS PWA logic removed** — Android-only project.

**No breaking changes** — fully compatible with v1.3.0.

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0].

### 142. What is the companion Android app?

A **native Android app** that loads the WebUI in a WebView
wrapper.

**Details**:

| Feature | Details |
|---|---|
| Size | ~3 MB |
| Stack | Kotlin + WebView |
| Min Android | 5.0 (API 21) |
| Browser required | ❌ No |
| Telemetry | ❌ None |
| Source | [gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app) |

**Useful if you don't want to keep a browser tab open.**

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0];
[`../README.md`](../README.md) §Optional Android App.

### 143. Is the companion app bundled into the module ZIP?

**Yes, but it is OPTIONAL.**

**Behavior**:

- If the release pipeline stages the APK before packaging, it is
  bundled into the ZIP at `web/app-debug.apk`.
- If the APK is missing (e.g. a local developer build without
  network access), the module ZIP is built without it.
- The build does not fail if the APK is absent.

**How to check if your module ZIP contains the APK**:

```bash
unzip -l dnscrypt-webui-1.4.0-module.zip | grep app-debug.apk
```

**On the device**, after install:

```bash
su -c "ls -la /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk"
# → Present (v1.4.0 with APK) or "No such file" (v1.4.0 without APK)
```

**Reference**: `scripts/package_module.sh` §[13], §[16], §[19].

### 144. How do I install the companion app?

**Method 1 — From the WebUI (recommended)**:

1. Open the WebUI at `http://127.0.0.1:9090`.
2. Click the **Install App** button (the direct
   `<a download>` link).
3. The browser downloads `DNS-Proxy.apk`.
4. Open the downloaded file to install it.
5. Android may prompt you to allow installation from unknown
   sources — this is normal for APKs outside the Play Store.

**Method 2 — Direct download URL**:

Open this URL in the browser:
```text
http://127.0.0.1:9090/app-debug.apk
```

**Method 3 — Via ADB** (advanced):

```bash
# 1. Fetch the APK from the device
adb shell su -c "cat /data/adb/modules/dnscrypt-proxy-webui/web/app-debug.apk" > DNS-Proxy.apk

# 2. Install via ADB
adb install DNS-Proxy.apk
```

**Reference**: `web/index.html` section [13c];
`main.go` `serveStaticAssets`.

### 145. Is the companion app verified / signed?

**Yes** — the companion app is built and signed in its own
repository ([gasciljh/dnscrypt-proxy-app](https://github.com/gasciljh/dnscrypt-proxy-app)),
which has its own release process.

**Version tracking**: The module tracks the companion app
version in `proxy/app-apk.version` (Single Source of Truth).
For v1.4.0, this file contains `1.0.0`.

**Verification**:

```bash
# On the device
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/app-apk.version"
# → 1.0.0

# In the repository
cat proxy/app-apk.version
# → 1.0.0
```

**Reference**: `proxy/app-apk.version`;
`scripts/fetch_app_apk.sh` §[8].

### 146. What is the CodeQL fix in v1.4.0?

**Two CodeQL alerts** were closed in `removeModule` (`main.go`):

- `go/path-injection` alert #1.
- `go/path-injection` alert #2.

**The vulnerability** (theoretical): The `removeModule` handler
accepted a caller-provided path and used it directly in
filesystem operations. A malicious path could potentially
traverse outside the intended directory.

**The fix**:

```go
// Extract the module name (last path component) via filepath.Base,
// which CodeQL recognizes as an effective path-injection sanitizer.
name := filepath.Base(modulePath)
if name == "" || name == "." || name == ".." || name == string(filepath.Separator) {
    return map[string]interface{}{
        "status":  "error",
        "message": "Invalid module name",
    }
}

// Reconstruct the full path from the trusted base directory and
// the sanitized name.
cleanPath := filepath.Join(MODULES_DIR, name)
```

**Why this is safe**:

- `filepath.Base()` returns only the final path component.
- `filepath.Join(MODULES_DIR, name)` rebuilds the path from a
  trusted base directory.
- No user-controlled data reaches any path expression.

**Defence-in-depth**: A prefix check (`strings.HasPrefix`) is
kept as a second layer.

**Reference**: `main.go` `removeModule`;
[CHANGELOG.md](../CHANGELOG.md) §[v1.4.0] → Security.

### 147. Why was iOS PWA logic removed?

**Because the project is Android-only.**

**What was removed from `web/index.html`**:

- `isIOSDevice()` helper.
- `pwaStepIos1`, `pwaStepIos2`, `pwaStepIos3` translations
  (English and Arabic).
- iOS branches in `getBrowserName()`, `isBrowserSupported()`,
  `getPWAInstallSteps()`, and `showPWAInstructionsModal()`.

**Impact on iOS users**:

- iOS users can still access the WebUI via Safari.
- The WebUI's bilingual toggle, dashboard, and all other
  features work normally.
- The specific "Add to Home Screen" instructions are no longer
  shown (iOS-specific).

**Why**:

- The project targets Android (Magisk/KernelSU/APatch).
- iOS-specific logic added complexity with no benefit for the
  target users.
- Removed ~35 lines of code.

**Reference**: [CHANGELOG.md](../CHANGELOG.md) §[v1.4.0]
→ Removed.

### 148. Does the companion app affect the module's security?

**No.** From a security standpoint:

- The APK is a static asset — it is not a running process.
- It is served at `GET /app-debug.apk` subject to the same
  authentication as every other protected route.
- The APK is **NOT** one of the 5 preserved config files, so a
  compromised APK cannot inject itself into the backup layer.
- On install, `customize.sh` extracts the APK from the ZIP with
  the same permissions as other web files (0644).

**The APK is NOT included in the persistent backup**:
- It is a build artifact of the module ZIP.
- It is re-extracted on every install.
- It is removed with the module folder on uninstall.

**Reference**: `docs/BACKUP.md` §12.7.

### 149. What is `proxy/app-apk.version`?

**Single Source of Truth** for the companion Android app version.

**Content**: `1.0.0` (for v1.4.0; no `v` prefix).

**Read by**: `scripts/fetch_app_apk.sh`.

**Update policy**: Manually when the companion app repository
ships a new release. It is **NOT** updated by the module's
`release.sh` — the two version schemes are independent.

**Verification**:

```bash
# In the repository
cat proxy/app-apk.version
# → 1.0.0

# Via the Makefile target
make check-app-version
# → ✅ proxy/app-apk.version: 1.0.0 (valid)
```

**Reference**: `proxy/app-apk.version`;
`scripts/fetch_app_apk.sh` §[8].

### 150. How do I remove the companion app separately?

The companion app is a **standard Android app**. Uninstalling it
does not affect the module.

**Method 1 — From Android Settings**:

1. Open **Settings → Apps → DNSCrypt Proxy**.
2. Tap **Uninstall**.

**Method 2 — From ADB**:

```bash
adb uninstall com.dnscrypt.webview
```

**Note**: The package name depends on the companion app's
`AndroidManifest.xml`. Confirm it before uninstalling.

**The module's WebUI and DNS engine are not affected** by the
companion app's presence or absence.

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

### 93. How do I verify v1.4.0 correctness?

```bash
# v1.0.0 checks (see Q78 for full list)
grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix #1 (JSON)"
grep -q 'func getSystemShell' proxy/main.go && echo "✅ Fix #2 (shell)"
grep -q 'recordLoginAttempt(ip, false)' proxy/main.go && echo "✅ Fix #8 (Basic Auth rate limit)"
grep -q 'func hasEndpoint' proxy/main.go && echo "✅ Fix #12 (exact matching)"
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"

# v1.1.0 checks
grep -q 'func memoryLimitForProfile' proxy/main.go && echo "✅ MEM-1 (function)"
grep -q 'func applyMemoryLimit' proxy/main.go && echo "✅ MEM-1 (apply)"
grep -A5 'func shellQuote' proxy/main.go | grep -q "'{'" && echo "✅ MEM-2 (braces)"
grep -A5 'func metricsProxyHandler' proxy/main.go | grep -q 'MONITORING_UI_PORT' && echo "✅ MEM-3"

# v1.2.0 checks
grep -q 'func createAutoBackup' proxy/main.go && echo "✅ BAK-2 (function)"
grep -q 'backupMu' proxy/main.go && echo "✅ BAK-2 (mutex)"
grep -q 'func cleanupOldTransactions' proxy/main.go && echo "✅ BAK-3"
grep -q 'func checkPendingNotifications' proxy/main.go && echo "✅ BAK-4"
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ BAK-1"

# v1.3.0 checks
grep -q 'ensure_running_service' proxy/service.sh && echo "✅ v1.3.0 DNS auto-start fix"
grep -q '_wait_webui' proxy/service.sh && echo "✅ v1.3.0 bounded wait"
grep -q 'led-on' web/index.html && echo "✅ v1.3.0 live status LED"

# v1.4.0 checks
grep -q 'APK_FILE' proxy/main.go && echo "✅ v1.4.0 APK_FILE constant"
grep -q 'app-debug.apk' proxy/main.go && echo "✅ v1.4.0 /app-debug.apk route"
grep -q 'filepath.Base(modulePath)' proxy/main.go && echo "✅ v1.4.0 CodeQL fix"
test -f scripts/fetch_app_apk.sh && echo "✅ v1.4.0 APK fetcher"
test -f proxy/app-apk.version && echo "✅ v1.4.0 version file"
```

### 94. What are the new Make targets?

**8 new targets have been added since v1.0.0**:

- `make check-backup` — validate the backup shell functions
  (v1.2.0).
- `make check-all` — run all local validations (v1.2.0).
- `make diagnose-help` — print device-side diagnostic commands
  (v1.2.0).
- `make fetch-apk` — fetch the companion APK into `dist/`
  (v1.4.0).
- `make check-app-version` — validate `proxy/app-apk.version`
  (v1.4.0).

See [`docs/DEVELOPMENT.md`](DEVELOPMENT.md) §9 for details.

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
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ declared"
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

# 5. v1.2.0 backups object
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '.backups'
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

# 4. Backups object (v1.2.0 — 7 fields)
curl -s http://127.0.0.1:8081/api?action=runtime_info | jq '.backups | keys'
# Expected: ["available","in_flight_txn","last_backup","last_backup_name","last_stable","orphan_txn","path"]

# 5. Restore original
su -c "sed -i 's/^PORT=8081/PORT=9090/' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
```

---

## Contributing

### 101. How do I contribute?

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

### 102. How do I report a security vulnerability?

Do not open a public Issue. Use **GitHub Private Vulnerability
Reporting**. See [`SECURITY.md`](SECURITY.md).

### 103. How do I translate the project?

**Global edition (English default + Arabic toggle)**:

- The **WebUI** ships bilingual (English default + Arabic
  toggle). Adding or changing strings requires updating **both**
  the `en` and `ar` entries in all three HTML files. See
  [`CONTRIBUTING.md`](CONTRIBUTING.md) §4.6.
- **Documentation translation is welcome** as separate files
  (`docs/*.<lang>.md`).
- **Additional WebUI languages** (FR, DE, ES, RU, ZH, ...) are
  deferred to a future release — see [`ROADMAP.md`](ROADMAP.md) §6.
- **Community forks** with additional languages are permitted
  (the MIT license allows this).

See [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) §FAQ Q9 for
the full language policy.

### 104. Is there a badge for contributors?

Yes! See [`HALL_OF_FAME.md`](HALL_OF_FAME.md).

**Available badges**:
- 🥇 Founder
- 🔥 Top Contributor
- 🛡️ Security Researcher
- 📖 Documentation
- 🌐 Translator (documentation + WebUI EN/AR contributions)
- 🧪 Testing Hero
- 💎 Compatibility Champ
- 🔍 Auditor
- 🔧 Platform Fixer
- 📊 Metrics Wizard
- ⚙️ Concurrency Guardian (covers `rebuildMu` and `backupMu`)
- 🔌 Port Architect
- 🧠 Memory Architect (v1.1.0)
- 🛡️ Data Guardian (v1.2.0)

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
- Next expected: **#34** (v1.5.x).

**Note**:
- v1.1.0 did not add audit corrections. It introduced three
  runtime improvements (MEM-1/2/3) documented in SECURITY.md
  §5.30.
- v1.2.0 did not add audit corrections either. It introduced 10
  data-preservation layers + 4 runtime additions (BAK-1..BAK-4)
  + 2 correctness fixes (FIX-1/2), documented in SECURITY.md
  §5.31 and §5.32.
- v1.3.0 did not add audit corrections. It introduced one
  correctness fix in `service.sh` (DNS auto-start after boot) and
  two UI features (PWA install button, live status LED).
- v1.4.0 did not add audit corrections. It introduced the
  companion Android app and two CodeQL `go/path-injection` fixes
  in `removeModule` (internal hardening).

**See**: [`CHANGELOG.md`](../CHANGELOG.md).

### 107. How do I add a new verification for a fix?

Use grep-based verification in the CI workflow
(`.github/workflows/ci.yml`).

**Patterns**:
- **Static audit** (shell): `grep -q 'pattern' file`
- **Build verification**:
  `go build -buildvcs=false -trimpath -o /tmp/main main.go`
- **Runtime check**: `curl -s http://127.0.0.1:9090/api?action=X | jq`

**v1.2.0 note**: The `backup-smoke-test` job in `ci.yml` uses
the same pattern for the 10 defensive layers.

**v1.4.0 note**: The `Verify companion app metadata` step
validates `proxy/app-apk.version` format and
`scripts/fetch_app_apk.sh` presence.

### 108. How do I add a RACE-1 verification?

```bash
# Static audit
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ mutex declared"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'rebuildMu.Lock()' && echo "✅ Lock"
grep -A5 'func rebuildBlocklist' proxy/main.go | grep -q 'defer rebuildMu.Unlock()' && echo "✅ Unlock"
```

**v1.2.0 addition** — for `backupMu`:

```bash
grep -q 'backupMu' proxy/main.go && echo "✅ backupMu declared"
grep -A10 'func createAutoBackup' proxy/main.go | grep -q 'backupMu.Lock()' && echo "✅ Lock"
grep -A15 'func createAutoBackup' proxy/main.go | grep -q 'defer backupMu.Unlock()' && echo "✅ Unlock"
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

**v1.2.0 addition** — for the `backups` object:

```bash
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'in_flight_txn' && echo "✅ in_flight_txn"
grep -A30 'func buildBackupInfo' proxy/main.go | grep -q 'orphan_txn' && echo "✅ orphan_txn"
```

**v1.4.0 addition** — for the APK route:

```bash
grep -q 'APK_FILE' proxy/main.go && echo "✅ APK_FILE constant"
grep -q 'app-debug.apk' proxy/main.go && echo "✅ /app-debug.apk route"
```

### 110. What is the difference between "Fix #N", "NEW-N", "MEM-N", "BAK-N", "FIX-N", and "v1.3.0/v1.4.0 fixes"?

**Fix #N** (N=1..12): v1.0.0 **original** fixes (Dashboard JSON,
Shell fallback, Preserve settings, ..., CodeQL config).

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

**BAK-N** (N=1..4): v1.2.0 **runtime additions** (not audit
corrections):
- BAK-1: 7-field `runtime_info.backups`.
- BAK-2: `createAutoBackup` + `backupMu`.
- BAK-3: `cleanupOldTransactions`.
- BAK-4: `checkPendingNotifications`.

**FIX-N** (N=1..2): v1.2.0 **correctness fixes** (not audit
corrections):
- FIX-1: Recovery-mode reorder (snapshot-and-reapply).
- FIX-2: Service Worker update-banner.

**v1.3.0 fixes** (not audit corrections):
- DNS auto-start after boot (`service.sh` section [19]).
- PWA install button (WebUI feature).
- Live status LED (WebUI feature).

**v1.4.0 fixes** (not audit corrections):
- CodeQL `go/path-injection` in `removeModule` (2 alerts closed).
- iOS PWA logic removed.
- Companion APK integration.

**Full numbering**: Fix #1-#12 + NEW-1..NEW-6 + RACE-1 + PORT-2 +
MEM-1/2/3 + BAK-1..BAK-4 + FIX-1/2 + v1.3.0 fixes + v1.4.0 fixes.

---

## 📚 References

- [README.md](../README.md) — Overview
- [docs/INSTALL.md](INSTALL.md) — Installation guide
- [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Troubleshooting
- [docs/SECURITY.md](SECURITY.md) — Security policy + Audit
  Corrections (§5.31, §5.32)
- [docs/BACKUP.md](BACKUP.md) — Backup system reference (v1.2.0)
- [docs/EMERGENCY.md](EMERGENCY.md) — Emergency recovery (v1.2.0)
- [docs/UPGRADE.md](UPGRADE.md) — Version upgrade guide (§3.0,
  §3.1, §3.2, §3.3)
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — System architecture
  (§3.10, §4.10)
- [docs/API.md](API.md) — HTTP API reference (§6.1.7)
- [docs/DEVELOPMENT.md](DEVELOPMENT.md) — Developer guide
- [docs/DNS_BINARIES.md](DNS_BINARIES.md) — DNS binaries management
- [docs/COMPATIBILITY.md](COMPATIBILITY.md) — Compatibility matrix
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guide
- [docs/GLOSSARY.md](GLOSSARY.md) — Glossary
- [docs/HALL_OF_FAME.md](HALL_OF_FAME.md) — Contributors
  recognition (Data Guardian)
- [docs/ROADMAP.md](ROADMAP.md) — Project plan
- [CHANGELOG.md](../CHANGELOG.md) — Version history (v1.0.0 →
  v1.4.0)
- [GitHub Issues](https://github.com/gasciljh/dnscrypt-proxy-webui/issues)

---

*Last updated: 2026-10-02*
*Version: v1.4.0*
*Author: gasciljh*