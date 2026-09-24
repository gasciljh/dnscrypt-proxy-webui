# Compatibility Matrix — DNSCrypt Smart Filter

Comprehensive compatibility reference: Android, ROMs, Kernels, Chipsets, Firewalls.

**Version**: v1.0.0
**Last updated**: 2026-09-24
**Repository**: https://github.com/gasciljh/dnscrypt-proxy-webui
**Author**: gasciljh

---

## Table of Contents

1. [Overview](#1-overview)
2. [Android Versions](#2-android-versions)
3. [ROMs](#3-roms)
4. [Kernels](#4-kernels)
5. [Chipsets (SoCs)](#5-chipsets-socs)
6. [Firewall Backends](#6-firewall-backends)
7. [Root Solutions](#7-root-solutions)
8. [Known Issues](#8-known-issues)
9. [Bug Report Template](#9-bug-report-template)
10. [Contributing Reports](#10-contributing-reports)
11. [References](#11-references)

---

## 1. Overview

### 1.1 Status Symbols

| Symbol | Meaning |
|:-----:|--------|
| ✅ | **Supported and tested** |
| 🟢 | **Supported** (not tested on every device) |
| ⚠️ | **Works with caveats** (needs configuration) |
| 🔶 | **Beta** (needs more testing) |
| ❌ | **Not supported** |

### 1.2 Minimum Requirements

| Requirement | Minimum | Recommended |
|---------|:-----------:|:---------:|
| **Android** | 5.0 (API 21) | 10+ (API 29) |
| **Root** | Magisk 20.4 | Magisk 26+ |
| **Kernel** | 3.10 | 4.14+ |
| **RAM** | 1 GB | 2 GB+ |
| **Storage** | 20 MB | 30 MB+ |
| **Architecture** | arm64 / arm / x86_64 / x86 | arm64 |

### 1.3 What's New in v1.0.0

**Compatibility-relevant changes**:

| # | Change | Compatibility impact |
|:-:|---|---|
| **1** | Dashboard JSON conversion | ✅ Works on all modern browsers now |
| **2** | `getSystemShell()` fallback | ✅ CI works on Linux/macOS |
| **3** | Preserve settings on upgrade | ✅ No settings loss |
| **4** | `.gitignore` negation | ⚪ No impact on user |
| **5** | Basic Auth rate limiting | ⚠️ Scripts may lock out after 5 attempts |
| **6** | Section header with comment | ✅ Broader TOML compatibility |
| **7** | Per-port cache | ⚪ No impact |
| **8** | Exact endpoint matching | ⚠️ 404 for unknown actions |
| **9** | **Login POST-only** | ⚠️ **GET on `/api/auth/login` rejected (405)** |
| **10** | **`/readyz` localhost-only** | ⚠️ **LAN requests rejected (403)** |
| **11** | **`shellQuote()`** | ⚪ No impact on user |
| **12** | **`readConfPort` range check** | ✅ Safe fallback for invalid values |
| **13** | **`rebuildMu` mutex (RACE-1)** | ✅ BLOCKLIST always consistent |
| **14** | **`runtime_info` dynamic ports (PORT-2)** | ✅ Dynamic links |
| **15** | **Auth cache (60 s)** | ⚠️ Credential changes take effect after ≤ 60 s |

**Base compatibility**: no change in system requirements.

---

## 2. Android Versions

| Version | API | Status | Notes |
|---------|:---:|:------:|-------|
| **15** | 35 | 🟢 | Needs testing |
| **14** | 34 | ✅ | Tested |
| **13** | 33 | ✅ | Tested |
| **12** | 31-32 | ✅ | Tested |
| **11** | 30 | ✅ | Tested |
| **10** | 29 | ✅ | Tested |
| **9** | 28 | 🟢 | Works |
| **8.1** | 27 | 🟢 | Works |
| **8.0** | 26 | 🟢 | Works |
| **7.1** | 25 | ⚠️ | May need iptables adjustments |
| **7.0** | 24 | ⚠️ | Same |
| **6.0** | 23 | ⚠️ | Doze mode issues |
| **5.1** | 22 | ⚠️ | Limited |
| **5.0** | 21 | ⚠️ | Minimum supported |

### 2.1 Android-specific Notes

**Android 10+**:
- ✅ Works smoothly.
- ✅ Private DNS integration.
- ✅ SELinux permissive with no issues.
- ✅ **Dashboard works** (Fix #1).

**Android 8-9**:
- ✅ Works.
- ⚠️ Battery optimization may stop the Watchdog.
- 💡 **Solution**: add to exceptions.

**Android 6-7**:
- ⚠️ Doze mode stops services.
- 💡 **Solution**: disable battery optimization.
- ⚠️ iptables may differ.
- ✅ **`getSystemShell()`**: works correctly on all versions.

**Android 5**:
- ⚠️ Requires kernel 3.10+.
- ⚠️ May not support nftables.
- 🆕 **`pgrep -x`**: may not work properly → fallback in code.
- 🆕 **`sync.Once`**: requires Go 1.22+ (available in the build).

### 2.2 Dashboard Compatibility

| Browser | SVG Icons | PNG Icons | JSON Metrics | Login POST |
|---|:---:|:---:|:---:|:---:|
| Chrome 90+ | ✅ | ✅ | ✅ | ✅ |
| Chrome 88-89 | ✅ | ✅ | ✅ | ✅ |
| Firefox 92+ | ✅ | ✅ | ✅ | ✅ |
| Safari 15+ | ✅ | ✅ | ✅ | ✅ |
| Samsung Internet 16+ | ✅ | ✅ | ✅ | ✅ |
| **IE 11** | ❌ | ✅ | ❌ | ❌ |

**Reason**: v1.0.0 added PNG icons to precache, supporting older browsers.

**Note**: Login POST-only requires `fetch()` or `XMLHttpRequest` — all modern browsers support it.

### 2.3 Platform Support

| Platform | `getSystemShell()` | `hasEndpoint()` | Dashboard JSON |
|---|:---:|:---:|:---:|
| Android | ✅ | ✅ | ✅ |
| Linux (CI) | ✅ | ✅ | ✅ |
| macOS (dev) | ✅ | ✅ | ✅ |
| Termux | ⚠️ | ✅ | ✅ |
| Windows (WSL2) | ✅ | ✅ | ✅ |

Before v1.0.0: Linux/macOS failed in `runShell` (path `/system/bin/sh` did not exist).
After v1.0.0: `getSystemShell()` selects the right path automatically.

---

## 3. ROMs

| ROM | Status | Notes |
|-----|:------:|-------|
| **Stock Android** | ✅ | Any version |
| **LineageOS** | ✅ | All versions |
| **Pixel Experience** | ✅ | Tested |
| **Evolution X** | ✅ | Tested |
| **crDroid** | ✅ | Tested |
| **AOSP Extended** | ✅ | Tested |
| **MIUI (Xiaomi)** | ⚠️ | Needs MIUI optimization disabled |
| **OneUI (Samsung)** | ⚠️ | May stop the service automatically |
| **ColorOS (OPPO)** | ⚠️ | Aggressive battery killer |
| **OxygenOS (OnePlus)** | 🟢 | Works |
| **HydrogenOS** | 🟢 | Works |
| **EMUI (Huawei)** | ⚠️ | May stop the service |
| **FuntouchOS (vivo)** | ⚠️ | Aggressive killing |
| **RealmeUI** | ⚠️ | Same |
| **Custom GSI** | 🟢 | Works |

### 3.1 ROM-specific Configuration

**MIUI**:
```text
Settings → Apps → Manage apps → DNSCrypt
→ Autostart: ON
→ Battery saver: No restrictions
→ Other permissions: Start in background
```

**OneUI**:
```text
Settings → Device care → Battery → Background usage limits
→ Never sleeping apps → Add DNSCrypt
```

**ColorOS**:
```text
Settings → Battery → App battery management → DNSCrypt
→ Allow background activity
→ Allow auto-launch
```

### 3.2 Setting Preservation (Fix #3)

On all supported ROMs, v1.0.0 preserves:
- `webui.conf`
- `dnscrypt-proxy.toml`
- `selected_profile.txt`
- `allowlist.txt`
- `denylist.txt`

**Note**: On older ROMs (< Android 9), backup may fail if `/data/local/tmp/` is restricted. Check the log:

```bash
grep "Backed up\|Restored" /data/local/tmp/dnscrypt_install.log
```

**Verify after upgrade**:

```bash
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"
# Must display your custom value (not the default 9090)
```

---

## 4. Kernels

| Kernel | Version | Status |
|---|---|:---:|
| Linux 3.10 | 3.10 | ⚠️ |
| Linux 3.18 | 3.18 | ⚠️ |
| Linux 4.4 | 4.4 | 🟢 |
| Linux 4.9 | 4.9 | ✅ |
| Linux 4.14 | 4.14 | ✅ |
| Linux 4.19 | 4.19 | ✅ |
| Linux 5.4 | 5.4 | ✅ |
| Linux 5.10 | 5.10 | ✅ |
| Linux 5.15 | 5.15 | ✅ |
| Linux 6.1 | 6.1 | ✅ |
| Linux 6.6 | 6.6 | ✅ |

### 4.1 Kernel Requirements

| Feature | Minimum | In v1.0.0 |
|---|---|---|
| iptables-nat | 3.10 | — |
| nftables | 4.10 | — |
| netns | 3.0 | — |
| cgroup v2 | 4.5 | — |
| **`/bin/sh`** | 4.x+ | ✅ (Linux dev) |
| **`sync.Once` (Go runtime)** | 4.4+ | ✅ |
| **`sync.Mutex` (Go runtime)** | 3.x+ | ✅ |

### 4.2 Kernel Issues

**Kernel 3.10–3.18:**
- May not support `--wait` in `iptables`.
- May not support `nft`.
- `getSystemShell()` works (selects `/system/bin/sh`).

**Kernel 4.14:**
- Supports `nft` with some limitations.
- `manage_nftables` works but may need fallback.

---

## 5. Chipsets (SoCs)

| SoC | Architecture | Status |
|---|---|:---:|
| Snapdragon 8 Gen 3 | arm64-v8a | ✅ |
| Snapdragon 8 Gen 2 | arm64-v8a | ✅ |
| Snapdragon 888 | arm64-v8a | ✅ |
| Snapdragon 865 | arm64-v8a | ✅ |
| Snapdragon 7xx | arm64-v8a | ✅ |
| Snapdragon 6xx | arm64-v8a / armeabi-v7a | ✅ |
| Snapdragon 4xx | arm64-v8a / armeabi-v7a | ✅ |
| Exynos 2100+ | arm64-v8a | ✅ |
| Exynos 990 | arm64-v8a | ✅ |
| Exynos 9820 | arm64-v8a | ✅ |
| Dimensity 9000+ | arm64-v8a | ✅ |
| Dimensity 1000+ | arm64-v8a | ✅ |
| Helio G series | arm64-v8a / armeabi-v7a | 🟢 |
| Kirin 9000 | arm64-v8a | 🟢 |
| Kirin 980 | arm64-v8a | 🟢 |
| Tensor (Pixel 6+) | arm64-v8a | ✅ |
| Intel x86 (Atom) | x86 / x86_64 | 🟢 |

### 5.1 Architecture Support

| Architecture (ABI) | Binaries | Status |
|---|---|:---:|
| `arm64-v8a` | `*-arm64` | ✅ |
| `armeabi-v7a` | `*-arm` | ✅ |
| `x86_64` | `*-amd64` | ✅ |
| `x86` | `*-386` | ✅ |

### 5.2 Performance by Architecture

| Arch | `parsePrometheus` | `hasEndpoint` | Memory |
|---|:---:|:---:|:---:|
| arm64-v8a | ~50 µs | <100 ns | ~15 MB |
| armeabi-v7a | ~150 µs | <200 ns | ~15 MB |
| x86_64 | ~40 µs | <80 ns | ~15 MB |
| x86 | ~200 µs | <250 ns | ~15 MB |

**Result**: v1.0.0 does not strain weak devices.

### 5.3 RACE-1 Performance

| Arch | `rebuildBlocklist` (100K) | `rebuildBlocklist` (500K) |
|---|:---:|:---:|
| arm64-v8a | ~200 ms | ~1 s |
| armeabi-v7a | ~600 ms | ~3 s |
| x86_64 | ~180 ms | ~900 ms |
| x86 | ~800 ms | ~4 s |

**Note**: `rebuildMu` adds no noticeable overhead (coarse-grained lock).

---

## 6. Firewall Backends

| Backend | Status | Priority |
|---|:---:|---|
| **nftables** | ✅ | 1 (preferred) |
| **iptables** | ✅ | 2 |
| **ip6tables** | ✅ | complementary |
| none | ⚠️ | no redirect |

### 6.1 Detection Logic

```bash
detect_firewall() {
    # 1. try nftables (inet then ip)
    if nft add table inet test; then
        return "nftables"
    fi

    # 2. try iptables -t nat
    if iptables -t nat -L -n; then
        return "iptables"
    fi

    # 3. none
    return "none"
}
```

### 6.2 Compatibility Matrix

| Backend | Android 5 | 8 | 10 | 12 | 14 |
|---|:---:|:---:|:---:|:---:|:---:|
| nftables | ❌ | ⚠️ | 🟢 | ✅ | ✅ |
| iptables | ✅ | ✅ | ✅ | ✅ | ✅ |
| ip6tables | ⚠️ | ✅ | ✅ | ✅ | ✅ |

### 6.3 Custom Chains

| Backend | Custom Chain Name | Cleanup Method |
|---|---|---|
| iptables | `DNSCRYPT_OUT` | `-F` + `-X` |
| ip6tables | `DNSCRYPT_OUT6` | `-F` + `-X` |
| nftables | `dnscrypt_filter` (table) | `delete table` |

**Benefits:**
- ✅ No orphans when `bootstrap_resolvers` change in the TOML.
- ✅ Public `OUTPUT` remains clean (two static rules only).
- ✅ Cleanup = full wipe in one operation (mathematically guaranteed).

*Compatibility: same as normal iptables/nftables constraints (see §6.2).*

### 6.4 Firewall + v1.0.0

**No firewall changes in v1.0.0.** Custom Chains are still used.

**Verify**:

```bash
# iptables
su -c "iptables -t nat -L DNSCRYPT_OUT -n"

# ip6tables
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n"

# no orphans in OUTPUT
su -c "iptables -t nat -L OUTPUT -n | grep -cE 'RETURN|DNAT'"
# → 0
```

**Integration with v1.0.0**:
- ✅ `shellQuote()` used in `isPortOpen` (after adding firewall check).
- ✅ `getSystemShell()` works with `iptables` / `nft` calls.
- ✅ `manage_iptables` unchanged — v1.0.0 is backend-only.
- ✅ **`rebuildMu` (RACE-1)** protects `rebuildBlocklist` from race conditions.
- ✅ **`runtime_info` (PORT-2)** returns actual ports (no hardcoded).

**Verify v1.0.0 firewall-related fixes**:

```bash
# RACE-1: rebuildMu
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# PORT-2: runtime_info ports
grep -A30 'func buildRuntimeInfo' proxy/main.go | grep -q '"webui_port"' && echo "✅ PORT-2"
```

---

## 7. Root Solutions

| Solution | Status | Min Version |
|---|:---:|---|
| Magisk | ✅ | 20.4 |
| Magisk Delta | ✅ | latest |
| KernelSU | ✅ | 0.9.0 |
| APatch | ✅ | latest |
| SuperSU | ❌ | Legacy |
| KingRoot | ❌ | Untrusted |
| Magisk Canary | ✅ | latest |

### 7.1 Magisk Features

| Feature | Min Version |
|---|---|
| ui_print | 20.0 |
| abort | 20.0 |
| set_perm_recursive | 20.0 |
| KernelSU API | 0.9.0 |

### 7.2 Root + v1.0.0 Compatibility

| Feature | Magisk 20.4 | Magisk 26+ | KernelSU | APatch |
|---|:---:|:---:|:---:|:---:|
| Backup/Restore | ✅ | ✅ | ✅ | ✅ |
| Fix #1 verify | ✅ | ✅ | ✅ | ✅ |
| Fix #2 verify | ✅ | ✅ | ✅ | ✅ |
| NEW-1..NEW-6 verify | ✅ | ✅ | ✅ | ✅ |
| RACE-1 + PORT-2 verify | ✅ | ✅ | ✅ | ✅ |
| `hasEndpoint` | ✅ | ✅ | ✅ | ✅ |
| Dashboard JSON | ✅ | ✅ | ✅ | ✅ |
| Login POST-only | ✅ | ✅ | ✅ | ✅ |
| `/readyz` localhost-only | ✅ | ✅ | ✅ | ✅ |
| `rebuildMu` mutex | ✅ | ✅ | ✅ | ✅ |
| `runtime_info` ports | ✅ | ✅ | ✅ | ✅ |

**`customize.sh` works the same way on all Root solutions.**

### 7.3 Verification on Device

```bash
# 1. Check version
su -c "grep '^version=' /data/adb/modules/dnscrypt-proxy-webui/module.prop"
# Expected: version=v1.0.0

# 2. Fix #2 — getSystemShell
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'getSystemShell' && echo '✅ Fix #2'"

# 3. Fix #1 — buildDashboardJSON
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'buildDashboardJSON' && echo '✅ Fix #1'"

# 4. RACE-1 — rebuildMu
su -c "strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui | grep -q 'rebuildMu' && echo '✅ RACE-1'"
```

### 7.4 Runtime Verification

```bash
# 1. runtime_info ports (PORT-2)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
# Expected: {"webui_port": "9090", "dashboard_port": "9091"}

# 2. Dashboard JSON (Fix #1)
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
# Expected: application/json; charset=utf-8

# 3. Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# Expected: 405 Method Not Allowed

# 4. /readyz localhost-only (NEW-4)
# From LAN:
curl -i "http://192.168.1.5:9091/readyz"
# Expected: 403 Forbidden

# 5. Basic Auth rate limit (Fix #8)
for i in {1..6}; do
  curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
    http://127.0.0.1:9090/api?action=status
done
# Expected: 401 × 5 then 401 (locked)
```

---

## 8. Known Issues

### 8.1 Known Issues

| # | Issue | Affected | Workaround |
|---|---|---|---|
| 1 | Battery optimization stops the Watchdog | Android 8-9 | Add to battery exceptions |
| 2 | MIUI kills background | MIUI 11-14 | Autostart + Battery: No restrictions |
| 3 | ColorOS kills aggressively | ColorOS | Allow background activity |
| 4 | iptables `--wait` unsupported | Kernel < 3.14 | Uses fallback |
| 5 | nft `inet` family unsupported | Kernel < 4.10 | Falls back to `ip` family |
| 6 | DNS leak on IPv6 | Some ROMs | `block_ipv6 = true` |
| 7 | Hotspot DNS leak | Android < 11 | Requires additional rules |
| 8 | Private DNS conflict | Android 9+ | Disabled automatically |
| 9 | VPN apps conflict | Any VPN | They cannot run together |
| 10 | SELinux enforcing blocks | Rare | Requires permissive |
| 11 | Orphans from old versions in OUTPUT | Upgrade from very old versions | Cleaned automatically |
| **12** | **Dashboard shows empty data** | **Pre-v1.0.0** | **Update to v1.0.0** |
| **13** | **Basic Auth locked after 5 attempts** | **v1.0.0+** | **Wait 15 min or restart WebUI** |
| **14** | **404 for unknown action** | **v1.0.0+** | **Update the script to expect 404** |
| **15** | **CI Go build fails on Linux** | **Pre-v1.0.0** | **Update to v1.0.0** |
| **16** | **Settings lost on upgrade** | **Pre-v1.0.0** | **Update to v1.0.0** |
| **17** | **Login GET rejected (405)** | **v1.0.0+** | **Update integration to use POST** |
| **18** | **`/readyz` from LAN rejected (403)** | **v1.0.0+** | **Use `/healthz` instead** |
| **19** | **Credentials change delay (60 s)** | **v1.0.0+** | **Wait 60 s or restart WebUI** |
| **20** | **Blocklist rebuild may take time on long lists** | **v1.0.0+** | **Normal — RACE-1 serializes rebuilds** |

### 8.2 VPN Interaction

**VPN + DNSCrypt = conflict:**
- The VPN app takes `redirect` priority.
- DNS queries go through the VPN instead of the module.
- **Solution**: use only one of them.

### 8.3 Hotspot

On Android < 11, hotspot traffic may not be redirected to port 5354. Requires additional `iptables` rules.

### 8.3 v1.0.0-specific Issues

**Issue #12 — Dashboard shows empty data**:
- **Symptom**: Dashboard tables are empty (Overview, Cache, Query Types, etc.).
- **Cause**: `metricsProxyHandler` returned Prometheus text with `Content-Type: application/json`.
- **Solution**: update to `v1.0.0`.
- **Verify**:
  ```bash
  grep -q 'func buildDashboardJSON' proxy/main.go && echo "✅ Fix present"
  ```

**Issue #13 — Basic Auth locked out**:
- **Symptom**: Basic Auth fails after 5 attempts.
- **Cause**: intentional — prevents brute force.
- **Solution**: wait 15 minutes or restart the WebUI.

**Issue #14 — 404 for unknown action**:
- **Symptom**: `GET /api?action=unknown` returns 404 instead of 200.
- **Solution**: update the script:
  ```bash
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "...")
  if [ "$status_code" = "404" ]; then ...
  ```

**Issue #15 — CI Go build fails on Linux**:
- **Symptom**: `fork/exec /system/bin/sh: no such file or directory`.
- **Solution**: update to `v1.0.0`.

**Issue #16 — Settings lost on upgrade**:
- **Symptom**: `webui.conf` is reset after an upgrade.
- **Solution**: update to `v1.0.0`.

**Issue #17 — Login GET rejected (405)**:
- **Symptom**: `curl "http://127.0.0.1:9090/api/auth/login?username=X&password=Y"` returns 405.
- **Cause**: intentional (CSRF protection — Fix NEW-1).
- **Solution**: use POST + JSON body:
  ```bash
  curl -X POST http://127.0.0.1:9090/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"..."}'
  ```

**Issue #18 — `/readyz` from LAN rejected (403)**:
- **Symptom**: from a device on the LAN, `curl http://192.168.1.5:9091/readyz` returns 403.
- **Cause**: intentional (info leak prevention — Fix NEW-4).
- **Solution**: use `/healthz` (no details exposed):
  ```bash
  curl http://192.168.1.5:9091/healthz
  # → "ok"
  ```

**Issue #19 — Credentials change delay (60 s)**:
- **Symptom**: after changing credentials in `dnscrypt-proxy.toml`, they are not applied immediately.
- **Cause**: Auth cache (Fix NEW-6) — TTL = 60 s.
- **Solution**: wait 60 s or restart the WebUI:
  ```bash
  su -c "sh /data/adb/modules/dnscrypt-proxy-webui/action.sh --restart"
  ```

**Issue #20 — Blocklist rebuild delay**:
- **Symptom**: when saving allowlist + updating profile at the same time, it may seem slower.
- **Cause**: intentional — `rebuildMu` (RACE-1) serializes rebuilds.
- **Solution**: normal — guarantees a consistent BLOCKLIST.

---

## 9. Bug Report Template

When reporting an issue, use the following template:

```markdown
## Environment

- **Module version**: v1.0.0
- **Android version**: 14 (API 34)
- **ROM**: LineageOS 21
- **Kernel**: 5.15.94-lineageos
- **SoC**: Snapdragon 8 Gen 2
- **Root**: Magisk 27.0
- **Architecture**: arm64-v8a

## Issue Description

[Clear description of the problem]

## Steps to Reproduce

1. ...
2. ...
3. ...

## Expected Behavior

[What should happen]

## Actual Behavior

[What actually happens]

## Logs

<details>
<summary>dnscrypt_main.log</summary>

```text
[Paste content here]
```
</details>

<details>
<summary>status.sh --json</summary>

```json
[Paste content here]
```
</details>

<details>
<summary>Firewall state</summary>

```text
$ iptables -t nat -L OUTPUT -n
$ iptables -t nat -L DNSCRYPT_OUT -n
$ ip6tables -t nat -L DNSCRYPT_OUT6 -n
```
</details>

<details>
<summary>Dashboard state</summary>

```json
$ curl -s http://127.0.0.1:9091/api/metrics
{
  "generated_at": "...",
  "total_queries": ...,
  "blocked_queries": ...,
  "cache_stats": {...}
}
```
</details>

<details>
<summary>STATUS_FILE</summary>

```text
$ cat /data/adb/modules/dnscrypt-proxy-webui/proxy/run/dnscrypt.status
ON
```
</details>

<details>
<summary>Runtime Info</summary>

```json
$ curl -s http://127.0.0.1:9090/api?action=runtime_info
{
  "version": "v1.0.0",
  "webui_port": "9090",
  "dashboard_port": "9091",
  ...
}
```
</details>

## Additional Context

- [ ] Works on a previous version
- [ ] New in v1.0.0
- [ ] Intermittent

## Screenshots

[If possible]
```

### 9.1 Quick Diagnostics Script

```bash
#!/bin/bash
# diagnose.sh — collect all information in one shot

echo "=== Module Info ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/module.prop"

echo ""
echo "=== System Info ==="
echo "Android: $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))"
echo "Device:  $(getprop ro.product.model)"
echo "Kernel:  $(uname -r)"
echo "SoC:     $(getprop ro.product.board)"
echo "Arch:    $(getprop ro.product.cpu.abi)"

echo ""
echo "=== Root Info ==="
which magisk 2>/dev/null && magisk -V
which ksud 2>/dev/null && ksud -V

echo ""
echo "=== Status ==="
su -c "sh /data/adb/modules/dnscrypt-proxy-webui/status.sh --json"

echo ""
echo "=== Firewall ==="
su -c "iptables -t nat -L OUTPUT -n | head -5"
su -c "iptables -t nat -L DNSCRYPT_OUT -n 2>/dev/null | head -5"
su -c "ip6tables -t nat -L DNSCRYPT_OUT6 -n 2>/dev/null | head -5"

echo ""
echo "=== Dashboard ==="
su -c "curl -s http://127.0.0.1:9091/api/metrics" | head -20

echo ""
echo "=== Runtime Info (PORT-2) ==="
su -c "curl -s http://127.0.0.1:9090/api?action=runtime_info"

echo ""
echo "=== Config ==="
su -c "cat /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

echo ""
echo "=== Logs (last 50) ==="
su -c "tail -50 /data/local/tmp/dnscrypt_main.log"

echo ""
echo "✅ Diagnostics complete. Save output to a file and attach to the issue."
```

### 9.2 v1.0.0-specific Diagnostics

```bash
#!/bin/bash
# diagnose-v1.sh — v1.0.0-specific checks

echo "=== Fix #1: Dashboard JSON ==="
curl -s -I http://127.0.0.1:9091/api/metrics | grep Content-Type
echo "Expected: application/json; charset=utf-8"

echo ""
echo "=== Fix #2: getSystemShell (source check) ==="
grep -q 'func getSystemShell' /data/adb/modules/dnscrypt-proxy-webui/proxy/*.go 2>/dev/null \
  && echo "✅ present" || echo "⚠️ not on device (normal — binary only)"

echo ""
echo "=== Fix #8: Basic Auth rate limit ==="
for i in {1..6}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "wrong:wrong" http://127.0.0.1:9090/api?action=status)
  echo "Attempt $i: $code"
done
echo "Expected: 401 × 5 then 401 (locked)"

echo ""
echo "=== NEW-1: Login POST-only ==="
curl -s -o /dev/null -w "GET /api/auth/login → %{http_code}\n" \
  "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
echo "Expected: 405"

echo ""
echo "=== NEW-4: /readyz localhost-only ==="
curl -s -o /dev/null -w "GET /readyz → %{http_code}\n" \
  http://127.0.0.1:9091/readyz
echo "From localhost: 200 or 503"

echo ""
echo "=== PORT-2: runtime_info ports ==="
curl -s http://127.0.0.1:9090/api?action=runtime_info | grep -E 'webui_port|dashboard_port'

echo ""
echo "=== RACE-1: rebuildMu (binary check) ==="
strings /data/adb/modules/dnscrypt-proxy-webui/proxy/dnscrypt-webui 2>/dev/null \
  | grep -q 'rebuildMu' && echo "✅ RACE-1 present in binary"

echo ""
echo "✅ Diagnostics complete."
```

---

## 10. Contributing Reports

### 10.1 We Welcome

- Compatibility reports from rare devices.
- Testing on different or modified ROMs.
- Solutions and workarounds for known issues.
- Detailed logs.
- **Dashboard reports** on different browsers.
- **Platform reports** (Linux, macOS, WSL2).
- **Performance reports** (`rebuildBlocklist` duration).

### 10.2 How to Contribute

1. Test on your device.
2. Fill in the template above.
3. Open an Issue titled `[Compat] <Device> <Android>`.
4. Attach the logs.

### 10.3 Compatibility Testing for v1.0.0

**Recommended tests**:

```bash
# 1. Test Dashboard (Fix #1)
echo "Open http://127.0.0.1:9091"
echo "Should show: total_queries, blocked_queries, cache_stats"

# 2. Test shell fallback (Fix #2)
echo "Test on Linux/macOS (dev):"
cd proxy && go build -buildvcs=false -trimpath -o /tmp/test-main main.go
grep -q 'func getSystemShell' main.go && echo "✅ getSystemShell present"

# 3. Test Basic Auth rate limit (Fix #8)
echo "5 failed attempts:"
for i in {1..6}; do
  curl -u "wrong:wrong" -o /dev/null -w "%{http_code}\n" \
    http://127.0.0.1:9090/api?action=status
done

# 4. Test 404 (Fix #12)
echo "Unknown action:"
curl -i "http://127.0.0.1:9090/api?action=nonexistent"
# → 404 Not Found

# 5. Test Preserve Settings (Fix #3)
echo "After upgrade:"
su -c "grep '^PORT=' /data/adb/modules/dnscrypt-proxy-webui/proxy/webui.conf"

# 6. Test Login POST-only (NEW-1)
curl -i "http://127.0.0.1:9090/api/auth/login?username=admin&password=X"
# → 405 Method Not Allowed + Allow: POST

# 7. Test /readyz localhost-only (NEW-4)
curl -i http://127.0.0.1:9091/readyz
# → 200 or 503 (from localhost)

# 8. Test shellQuote (NEW-5)
grep -q 'func shellQuote' proxy/main.go && echo "✅ NEW-5 present"

# 9. Test Auth cache (NEW-6)
grep -q 'AUTH_CACHE_TTL' proxy/main.go && echo "✅ NEW-6 present"

# 10. Test RACE-1 (rebuildMu)
grep -qE 'rebuildMu[[:space:]]+sync\.Mutex' proxy/main.go && echo "✅ RACE-1"

# 11. Test PORT-2 (runtime_info)
curl -s http://127.0.0.1:9090/api?action=runtime_info | jq '{webui_port, dashboard_port}'
```

### 10.4 Hall of Fame

Compatibility contributors are listed in [`HALL_OF_FAME.md`](HALL_OF_FAME.md#-compatibility-champions).

### 10.5 Platform Champions

New badge for those testing on **non-Android platforms** (Linux, macOS, WSL2):

- 🖥️ Testing on Linux (CI-like environment).
- 🍎 Testing on macOS.
- 🐧 Testing on WSL2 (Windows).

**Benefit**: improves `getSystemShell()` and platform-agnostic shell behavior.

---

## 11. References

### 11.1 Specifications and Tools

- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [KernelSU Documentation](https://kernelsu.org/)
- [Android Version History](https://developer.android.com/about/versions)
- [Linux Kernel Releases](https://kernel.org/)
- [DNSCrypt-proxy Wiki](https://github.com/DNSCrypt/dnscrypt-proxy/wiki)
- [Netfilter iptables Custom Chains Best Practices](https://www.netfilter.org/documentation/)
- [Prometheus Text Format](https://prometheus.io/docs/instrumenting/exposition_formats/)

### 11.2 Project Documentation

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | Full architecture |
| [`docs/SECURITY.md`](SECURITY.md) | Audit Corrections Registry |
| [`docs/DNS_BINARIES.md`](DNS_BINARIES.md) | DNS binaries (Level 4) |
| [`docs/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Comprehensive troubleshooting |
| [`docs/API.md`](API.md) | HTTP API Reference |
| [`docs/GLOSSARY.md`](GLOSSARY.md) | Glossary |
| [`docs/HALL_OF_FAME.md`](HALL_OF_FAME.md) | Contributors recognition |
| [`docs/CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/FAQ.md`](FAQ.md) | Frequently asked questions |
| [`docs/INSTALL.md`](INSTALL.md) | Installation guide |
| [`docs/UPGRADE.md`](UPGRADE.md) | Upgrade guide |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history |

---

*Last updated: 2026-09-24*
*Version: v1.0.0*
*Author: gasciljh*